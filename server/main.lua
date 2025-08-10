local QBCore = exports['qb-core']:GetCoreObject()

local function DebugPrint(msg)
    print("[Motel] DEBUG: " .. msg)
end

CreateThread(function()
    MySQL.execute([[
        CREATE TABLE IF NOT EXISTS motel_rooms (
            id INT AUTO_INCREMENT PRIMARY KEY,
            citizenid VARCHAR(50) UNIQUE NOT NULL,
            room_bucket INT NOT NULL,
            entry_door_index INT DEFAULT 1,
            is_inside BOOLEAN DEFAULT FALSE,
            purchased_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            INDEX idx_citizenid (citizenid),
            INDEX idx_bucket (room_bucket)
        )
    ]])
end)

local PlayerRooms = {}
local UsedBuckets = {}
local PlayerBuckets = {} 
local PlayerInsideStatus = {}

CreateThread(function()
    local result = MySQL.query.await('SELECT citizenid, room_bucket, entry_door_index, is_inside FROM motel_rooms')
    if result then
        for i = 1, #result do
            local data = result[i]
            PlayerRooms[data.citizenid] = {
                bucket = data.room_bucket,
                entryDoor = data.entry_door_index or 1,
                isInside = data.is_inside or false
            }
            UsedBuckets[data.room_bucket] = true
            
            local stashId = 'motel_room_' .. data.citizenid
            DebugPrint("Registering existing stash: " .. stashId)
            exports.ox_inventory:RegisterStash(stashId, Config.StashName, Config.StashSlots, Config.StashMaxWeight, true)
        end
    end
end)

local function GetNextRoomBucket()
    local bucket = 1000
    while UsedBuckets[bucket] do
        bucket = bucket + 1
    end
    return bucket
end

QBCore.Functions.CreateCallback('motel:server:hasRoom', function(source, cb)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return cb(false) end
    
    cb(PlayerRooms[Player.PlayerData.citizenid] ~= nil)
end)

QBCore.Functions.CreateCallback('motel:server:isPlayerInside', function(source, cb)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return cb(false) end
    
    local roomData = PlayerRooms[Player.PlayerData.citizenid]
    if roomData then
        cb(roomData.isInside)
    else
        cb(false)
    end
end)

QBCore.Functions.CreateCallback('motel:server:purchaseRoom', function(source, cb)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return cb(false, Config.Messages.playerNotFound) end
    
    local citizenid = Player.PlayerData.citizenid
    
    if PlayerRooms[citizenid] then
        return cb(false, Config.Messages.alreadyOwnsRoom)
    end
    
    if Player.PlayerData.money[Config.Currency] < Config.RoomPrice then
        return cb(false, Config.Messages.notEnoughMoney)
    end
    
    local roomBucket = GetNextRoomBucket()
    
    Player.Functions.RemoveMoney(Config.Currency, Config.RoomPrice, "motel-room-purchase")
    
    MySQL.insert('INSERT INTO motel_rooms (citizenid, room_bucket, entry_door_index, is_inside) VALUES (?, ?, ?, ?)', {
        citizenid, roomBucket, 1, false
    }, function(insertId)
        if insertId then
            PlayerRooms[citizenid] = {
                bucket = roomBucket,
                entryDoor = 1,
                isInside = false
            }
            UsedBuckets[roomBucket] = true
            
            local stashId = 'motel_room_' .. citizenid
            DebugPrint("Registering new stash: " .. stashId)
            exports.ox_inventory:RegisterStash(stashId, Config.StashName, Config.StashSlots, Config.StashMaxWeight, true)
            
            cb(true, Config.Messages.purchaseSuccess)
        else
            Player.Functions.AddMoney(Config.Currency, Config.RoomPrice, "motel-room-purchase-refund")
            cb(false, Config.Messages.purchaseFailed)
        end
    end)
end)

QBCore.Functions.CreateCallback('motel:server:getRoomData', function(source, cb)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return cb(nil) end
    
    local citizenid = Player.PlayerData.citizenid
    local roomData = PlayerRooms[citizenid]
    
    if not roomData then return cb(nil) end
    
    local stashId = 'motel_room_' .. citizenid
    
    local stashData = exports.ox_inventory:GetInventory(stashId)
    if not stashData then
        DebugPrint("Stash does not exist, registering: " .. stashId)
        exports.ox_inventory:RegisterStash(stashId, Config.StashName, Config.StashSlots, Config.StashMaxWeight, true)
        Wait(100)
    end
    
    cb({
        bucket = roomData.bucket,
        stashId = stashId,
        entryDoor = roomData.entryDoor,
        isInside = roomData.isInside,
        interiorCoords = Config.InteriorSystem.baseCoords
    })
end)

RegisterNetEvent('motel:server:enterRoom', function(doorIndex)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    
    local citizenid = Player.PlayerData.citizenid
    local roomData = PlayerRooms[citizenid]
    
    if roomData then
        roomData.entryDoor = doorIndex or 1
        roomData.isInside = true
        PlayerInsideStatus[src] = true
        
        MySQL.update('UPDATE motel_rooms SET entry_door_index = ?, is_inside = ? WHERE citizenid = ?', {
            doorIndex or 1, true, citizenid
        })
        
        SetPlayerRoutingBucket(src, roomData.bucket)
        PlayerBuckets[src] = roomData.bucket
        
        DebugPrint("Player " .. GetPlayerName(src) .. " entered bucket " .. roomData.bucket .. " through door " .. (doorIndex or 1))
        
        local stashId = 'motel_room_' .. citizenid
        local stashData = exports.ox_inventory:GetInventory(stashId)
        if not stashData then
            DebugPrint("Re-registering stash in bucket: " .. stashId)
            exports.ox_inventory:RegisterStash(stashId, Config.StashName, Config.StashSlots, Config.StashMaxWeight, true)
        end
    end
end)

RegisterNetEvent('motel:server:exitRoom', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    
    local citizenid = Player.PlayerData.citizenid
    local roomData = PlayerRooms[citizenid]
    
    if roomData then
        roomData.isInside = false
        PlayerInsideStatus[src] = false
        
        MySQL.update('UPDATE motel_rooms SET is_inside = ? WHERE citizenid = ?', {
            false, citizenid
        })
    end
    
    SetPlayerRoutingBucket(src, 0)
    PlayerBuckets[src] = nil
    
    DebugPrint("Player " .. GetPlayerName(src) .. " exited private bucket")
end)

RegisterNetEvent('motel:server:openStash', function(stashId)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    
    local citizenid = Player.PlayerData.citizenid
    local expectedStashId = 'motel_room_' .. citizenid
    
    if stashId ~= expectedStashId then
        print("WARNING: Player tried to access invalid stash:", stashId)
        return
    end
    
    DebugPrint("Opening stash via server event: " .. stashId)
    
    local stashData = exports.ox_inventory:GetInventory(stashId)
    if not stashData then
        DebugPrint("Stash does not exist, creating: " .. stashId)
        exports.ox_inventory:RegisterStash(stashId, Config.StashName, Config.StashSlots, Config.StashMaxWeight, true)
        Wait(100)
    end
    
    TriggerClientEvent('ox_inventory:openInventory', src, 'stash', stashId)
end)

RegisterNetEvent('QBCore:Server:PlayerLoaded', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    
    local citizenid = Player.PlayerData.citizenid
    local roomData = PlayerRooms[citizenid]
    
    if roomData then
        local stashId = 'motel_room_' .. citizenid
        DebugPrint("Player connected, registering stash: " .. stashId)
        exports.ox_inventory:RegisterStash(stashId, Config.StashName, Config.StashSlots, Config.StashMaxWeight, true)
        
        if roomData.isInside then
            DebugPrint("Player was inside room, restoring state...")
            SetPlayerRoutingBucket(src, roomData.bucket)
            PlayerBuckets[src] = roomData.bucket
            PlayerInsideStatus[src] = true
            
            TriggerClientEvent('motel:client:restoreInsideState', src, {
                bucket = roomData.bucket,
                stashId = stashId,
                entryDoor = roomData.entryDoor,
                isInside = roomData.isInside,
                interiorCoords = Config.InteriorSystem.baseCoords
            })
        end
    end
end)

RegisterNetEvent('QBCore:Server:OnPlayerUnload', function()
    local src = source
    if PlayerBuckets[src] then
        SetPlayerRoutingBucket(src, 0)
        PlayerBuckets[src] = nil
        PlayerInsideStatus[src] = nil
    end
end)

RegisterCommand('checkbuckets', function(source, args, rawCommand)
    local src = source
    if src == 0 then
        print("=== MOTEL BUCKETS ===")
        for playerId, bucket in pairs(PlayerBuckets) do
            print("Player " .. GetPlayerName(playerId) .. " (ID: " .. playerId .. ") - Bucket: " .. bucket)
        end
        print("====================")
    end
end, true)

RegisterCommand('checkstashes', function(source, args, rawCommand)
    local src = source
    if src == 0 then
        print("=== MOTEL STASHES ===")
        for citizenid, roomData in pairs(PlayerRooms) do
            local stashId = 'motel_room_' .. citizenid
            local stashData = exports.ox_inventory:GetInventory(stashId)
            print("CitizenID: " .. citizenid .. " - Bucket: " .. roomData.bucket .. " - Inside: " .. tostring(roomData.isInside) .. " - Stash: " .. tostring(stashData ~= nil))
        end
        print("====================")
    end
end, true)
