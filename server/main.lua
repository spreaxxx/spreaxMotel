local QBCore = exports['qb-core']:GetCoreObject()

-- ── Helpers ──────────────────────────────────────────────────

local function DebugPrint(msg)
    if Config.Debug then
        print("[Motel] DEBUG: " .. tostring(msg))
    end
end

-- ── Database setup ───────────────────────────────────────────

CreateThread(function()
    MySQL.execute([[
        CREATE TABLE IF NOT EXISTS motel_rooms (
            id              INT AUTO_INCREMENT PRIMARY KEY,
            citizenid       VARCHAR(50) UNIQUE NOT NULL,
            room_bucket     INT NOT NULL,
            entry_door_index INT DEFAULT 1,
            is_inside       BOOLEAN DEFAULT FALSE,
            purchased_at    TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            INDEX idx_citizenid (citizenid),
            INDEX idx_bucket    (room_bucket)
        )
    ]])
end)

-- ── In-memory state ──────────────────────────────────────────

local PlayerRooms        = {}   -- [citizenid] = { bucket, entryDoor, isInside }
local UsedBuckets        = {}   -- [bucketId]  = true
local PlayerBuckets      = {}   -- [src]       = bucketId
local PlayerInsideStatus = {}   -- [src]       = bool

-- ── Load persisted data on resource start ────────────────────

CreateThread(function()
    local result = MySQL.query.await(
        'SELECT citizenid, room_bucket, entry_door_index, is_inside FROM motel_rooms'
    )

    if result then
        for i = 1, #result do
            local data = result[i]

            PlayerRooms[data.citizenid] = {
                bucket    = data.room_bucket,
                entryDoor = data.entry_door_index or 1,
                isInside  = data.is_inside or false,
            }
            UsedBuckets[data.room_bucket] = true

            -- Pre-register every known stash so inventory data survives restarts.
            local stashId = 'motel_room_' .. data.citizenid
            exports.ox_inventory:RegisterStash(
                stashId,
                'Storage',
                Config.Stash.slots,
                Config.Stash.maxWeight,
                Config.Stash.isPersonal
            )
        end
    end
end)

-- ── Bucket allocation ────────────────────────────────────────

local function GetNextRoomBucket()
    local bucket = Config.Buckets.startId
    while UsedBuckets[bucket] do
        bucket = bucket + 1
    end
    return bucket
end

-- ── Stash helpers ─────────────────────────────────────────────

local function EnsureStashExists(stashId)
    local stashData = exports.ox_inventory:GetInventory(stashId)
    if not stashData then
        DebugPrint(Locale('stash_reregister', stashId))
        exports.ox_inventory:RegisterStash(
            stashId,
            'Storage',
            Config.Stash.slots,
            Config.Stash.maxWeight,
            Config.Stash.isPersonal
        )
        Wait(100)
    end
end

-- ── Callbacks ────────────────────────────────────────────────

-- Returns whether the calling player owns a room.
QBCore.Functions.CreateCallback('motel:server:hasRoom', function(source, cb)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return cb(false) end

    cb(PlayerRooms[Player.PlayerData.citizenid] ~= nil)
end)

-- Returns whether the calling player is currently inside their room.
QBCore.Functions.CreateCallback('motel:server:isPlayerInside', function(source, cb)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return cb(false) end

    local roomData = PlayerRooms[Player.PlayerData.citizenid]
    cb(roomData and roomData.isInside or false)
end)

-- Handles a room purchase request from the client.
QBCore.Functions.CreateCallback('motel:server:purchaseRoom', function(source, cb)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return cb(false, Locale('playerNotFound')) end

    local citizenid = Player.PlayerData.citizenid

    -- Already owns a room?
    if PlayerRooms[citizenid] then
        return cb(false, Locale('alreadyOwnsRoom'))
    end

    -- Enough money?
    if Player.PlayerData.money[Config.Currency] < Config.RoomPrice then
        return cb(false, Locale('notEnoughMoney', Config.RoomPrice))
    end

    local roomBucket = GetNextRoomBucket()

    -- Deduct cost before the async insert to prevent double-spending.
    Player.Functions.RemoveMoney(Config.Currency, Config.RoomPrice, "motel-room-purchase")

    MySQL.insert(
        'INSERT INTO motel_rooms (citizenid, room_bucket, entry_door_index, is_inside) VALUES (?, ?, ?, ?)',
        { citizenid, roomBucket, 1, false },
        function(insertId)
            if insertId then
                PlayerRooms[citizenid] = {
                    bucket    = roomBucket,
                    entryDoor = 1,
                    isInside  = false,
                }
                UsedBuckets[roomBucket] = true

                local stashId = 'motel_room_' .. citizenid
                exports.ox_inventory:RegisterStash(
                    stashId,
                    'Storage',
                    Config.Stash.slots,
                    Config.Stash.maxWeight,
                    Config.Stash.isPersonal
                )

                cb(true, Locale('purchaseSuccess'))
            else
                -- Refund on DB failure.
                Player.Functions.AddMoney(Config.Currency, Config.RoomPrice, "motel-room-purchase-refund")
                cb(false, Locale('purchaseFailed'))
            end
        end
    )
end)

-- Returns full room data needed by the client to enter / interact.
QBCore.Functions.CreateCallback('motel:server:getRoomData', function(source, cb)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return cb(nil) end

    local citizenid = Player.PlayerData.citizenid
    local roomData  = PlayerRooms[citizenid]
    if not roomData then return cb(nil) end

    local stashId = 'motel_room_' .. citizenid
    EnsureStashExists(stashId)

    cb({
        bucket        = roomData.bucket,
        stashId       = stashId,
        entryDoor     = roomData.entryDoor,
        isInside      = roomData.isInside,
        interiorCoords = Config.InteriorSystem.baseCoords,
    })
end)

-- ── Net Events ───────────────────────────────────────────────

-- Client signals that the player is entering their room.
RegisterNetEvent('motel:server:enterRoom', function(doorIndex)
    local src    = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local citizenid = Player.PlayerData.citizenid
    local roomData  = PlayerRooms[citizenid]
    if not roomData then return end

    roomData.entryDoor         = doorIndex or 1
    roomData.isInside          = true
    PlayerInsideStatus[src]    = true

    MySQL.update(
        'UPDATE motel_rooms SET entry_door_index = ?, is_inside = ? WHERE citizenid = ?',
        { doorIndex or 1, true, citizenid }
    )

    SetPlayerRoutingBucket(src, roomData.bucket)
    PlayerBuckets[src] = roomData.bucket

    local stashId = 'motel_room_' .. citizenid
    EnsureStashExists(stashId)
end)

-- Client signals that the player is leaving their room.
RegisterNetEvent('motel:server:exitRoom', function()
    local src    = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local citizenid = Player.PlayerData.citizenid
    local roomData  = PlayerRooms[citizenid]

    if roomData then
        roomData.isInside       = false
        PlayerInsideStatus[src] = false

        MySQL.update(
            'UPDATE motel_rooms SET is_inside = ? WHERE citizenid = ?',
            { false, citizenid }
        )
    end

    SetPlayerRoutingBucket(src, 0)
    PlayerBuckets[src] = nil
end)

-- Client requests to open the room stash.
-- Validates ownership before forwarding the open event to ox_inventory.
RegisterNetEvent('motel:server:openStash', function(stashId)
    local src    = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local citizenid      = Player.PlayerData.citizenid
    local expectedStashId = 'motel_room_' .. citizenid

    -- Security check – players may only open their own stash.
    if stashId ~= expectedStashId then
        print(Locale('warn_invalid_stash', stashId))
        return
    end

    EnsureStashExists(stashId)
    TriggerClientEvent('ox_inventory:openInventory', src, 'stash', stashId)
end)

-- Client signals that hunger / thirst should be reset (InfiniteHealth system).
-- Only runs when all guards pass: feature enabled, player inside, server confirms state.
RegisterNetEvent('motel:server:resetNeeds', function()
    local src    = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    -- Guard: feature must be enabled in config.
    if not Config.InfiniteHealth.enabled or not Config.InfiniteHealth.resetNeeds then return end

    local citizenid = Player.PlayerData.citizenid
    local roomData  = PlayerRooms[citizenid]

    -- Guard: server must also agree the player is inside.
    if not (roomData and roomData.isInside and PlayerInsideStatus[src]) then return end

    Player.Functions.SetMetaData('hunger', 100)
    Player.Functions.SetMetaData('thirst', 100)
    TriggerClientEvent('hud:client:UpdateNeeds', src, 100, 100)
end)

-- ── QBCore player lifecycle ──────────────────────────────────

RegisterNetEvent('QBCore:Server:PlayerLoaded', function()
    local src    = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local citizenid = Player.PlayerData.citizenid
    local roomData  = PlayerRooms[citizenid]

    if not roomData then return end

    local stashId = 'motel_room_' .. citizenid
    DebugPrint(Locale('player_connected', stashId))
    exports.ox_inventory:RegisterStash(
        stashId,
        'Storage',
        Config.Stash.slots,
        Config.Stash.maxWeight,
        Config.Stash.isPersonal
    )

    -- If the player was inside when they disconnected, restore that state.
    if roomData.isInside then
        DebugPrint(Locale('player_restoring'))
        SetPlayerRoutingBucket(src, roomData.bucket)
        PlayerBuckets[src]      = roomData.bucket
        PlayerInsideStatus[src] = true

        TriggerClientEvent('motel:client:restoreInsideState', src, {
            bucket         = roomData.bucket,
            stashId        = stashId,
            entryDoor      = roomData.entryDoor,
            isInside       = roomData.isInside,
            interiorCoords = Config.InteriorSystem.baseCoords,
        })
    end
end)

RegisterNetEvent('QBCore:Server:OnPlayerUnload', function()
    local src = source
    if PlayerBuckets[src] then
        SetPlayerRoutingBucket(src, 0)
        PlayerBuckets[src]      = nil
        PlayerInsideStatus[src] = nil
    end
end)

-- ── Admin commands ────────────────────────────────────────────

-- Lists every player currently assigned to a motel bucket.
-- Console only (source == 0).
RegisterCommand('checkbuckets', function(source)
    if source ~= 0 then return end

    print("=== MOTEL BUCKETS ===")
    for playerId, bucket in pairs(PlayerBuckets) do
        print(string.format(
            "Player %s (ID: %s) — Bucket: %s",
            GetPlayerName(playerId), playerId, bucket
        ))
    end
    print("=====================")
end, true)

-- Lists every room stash and whether it is currently registered.
-- Console only (source == 0).
RegisterCommand('checkstashes', function(source)
    if source ~= 0 then return end

    print("=== MOTEL STASHES ===")
    for citizenid, roomData in pairs(PlayerRooms) do
        local stashId   = 'motel_room_' .. citizenid
        local stashData = exports.ox_inventory:GetInventory(stashId)
        print(string.format(
            "CitizenID: %s | Bucket: %s | Inside: %s | Stash registered: %s",
            citizenid,
            roomData.bucket,
            tostring(roomData.isInside),
            tostring(stashData ~= nil)
        ))
    end
    print("=====================")
end, true)