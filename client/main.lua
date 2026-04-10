local QBCore = exports['qb-core']:GetCoreObject()

-- ── State ────────────────────────────────────────────────────

local isInRoom            = false
local currentRoomData     = nil
local doorPoints          = {}
local insidePoints        = {}
local isEntering          = false
local motelBlip           = nil
local entryDoorIndex      = nil
local playerLoaded        = false
local infiniteHealthThread = nil

local preservedHealth  = nil
local preservedArmor   = nil
local preservedHunger  = nil
local preservedThirst  = nil

-- ── Helpers ──────────────────────────────────────────────────

local function DebugPrint(text)
    if Config.Debug then
        print("[Motel] " .. tostring(text))
    end
end

-- ── Infinite Health system ───────────────────────────────────

local function StartInfiniteHealth()
    if infiniteHealthThread then return end

    DebugPrint("Starting stat preservation system...")

    local ped = PlayerPedId()
    preservedHealth = GetEntityHealth(ped)
    preservedArmor  = GetPedArmour(ped)

    QBCore.Functions.TriggerCallback('motel:server:getPlayerNeeds', function(needs)
        if needs then
            preservedHunger = needs.hunger
            preservedThirst = needs.thirst
            DebugPrint(string.format(
                "Stats preserved — Health: %s, Armor: %s, Hunger: %s, Thirst: %s",
                preservedHealth, preservedArmor, preservedHunger, preservedThirst
            ))
        else
            preservedHunger = 50
            preservedThirst = 50
            DebugPrint("Using fallback values for hunger and thirst.")
        end
    end)

    infiniteHealthThread = CreateThread(function()
        while isInRoom and preservedHealth and preservedArmor do
            local p = PlayerPedId()

            if GetEntityHealth(p) < preservedHealth then
                SetEntityHealth(p, preservedHealth)
            end

            if GetPedArmour(p) < preservedArmor then
                SetPedArmour(p, preservedArmor)
            end

            if preservedHunger and preservedThirst then
                TriggerServerEvent('motel:server:maintainNeeds', preservedHunger, preservedThirst)
            end

            Wait(Config.InfiniteHealth.checkInterval)
        end

        DebugPrint("Stat preservation system stopped.")
        infiniteHealthThread = nil
    end)
end

local function StopInfiniteHealth()
    preservedHealth = nil
    preservedArmor  = nil
    preservedHunger = nil
    preservedThirst = nil
    infiniteHealthThread = nil

    local ped = PlayerPedId()
    SetEntityInvincible(ped, false)

    DebugPrint("Stat preservation fully stopped — player can lose stats normally.")
end

-- ── Blip setup ───────────────────────────────────────────────

CreateThread(function()
    motelBlip = AddBlipForCoord(
        Config.MotelBlip.coords.x,
        Config.MotelBlip.coords.y,
        Config.MotelBlip.coords.z
    )

    SetBlipSprite(motelBlip, Config.MotelBlip.sprite)
    SetBlipDisplay(motelBlip, Config.MotelBlip.display)
    SetBlipScale(motelBlip, Config.MotelBlip.scale)
    SetBlipColour(motelBlip, Config.MotelBlip.colour)
    SetBlipAsShortRange(motelBlip, true)

    BeginTextCommandSetBlipName("STRING")
    AddTextComponentSubstringPlayerName(Config.MotelBlip.name)
    EndTextCommandSetBlipName(motelBlip)

    DebugPrint("Motel blip created.")
end)

-- ── Player loaded ─────────────────────────────────────────────

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    playerLoaded = true
    DebugPrint("Player loaded, checking motel state...")

    Wait(3000)

    QBCore.Functions.TriggerCallback('motel:server:getRoomData', function(roomData)
        if roomData and roomData.isInside then
            DebugPrint("Player should be inside room, restoring...")
            RestoreInsideState(roomData)
        else
            DebugPrint("Player was not inside a room.")
        end
    end)
end)

-- Fallback check in case OnPlayerLoaded fires before this resource starts.
CreateThread(function()
    Wait(5000)

    if not playerLoaded then
        DebugPrint("Manual motel state check...")
        QBCore.Functions.TriggerCallback('motel:server:getRoomData', function(roomData)
            if roomData then
                DebugPrint("Forcing state restore...")
                RestoreInsideState(roomData)
            end
        end)
    end
end)

-- ── Door interaction points ───────────────────────────────────

CreateThread(function()
    for i, door in ipairs(Config.MotelDoors) do
        local point = lib.points.new({
            coords   = door.coords,
            distance = 2.0,

            onEnter = function()
                if not isEntering and not isInRoom then
                    QBCore.Functions.TriggerCallback('motel:server:hasRoom', function(hasRoom)
                        if hasRoom then
                            lib.showTextUI(Locale('textui_enter'))
                        else
                            lib.showTextUI(Locale('textui_purchase', Config.RoomPrice))
                        end
                    end)
                end
            end,

            onExit = function()
                lib.hideTextUI()
            end,

            nearby = function()
                if IsControlJustReleased(0, 38) and not isEntering then
                    HandleDoorInteraction(i)
                end
            end,
        })
        doorPoints[i] = point
    end
end)

-- ── Door / purchase logic ─────────────────────────────────────

function HandleDoorInteraction(doorIndex)
    if isEntering or isInRoom then return end

    lib.hideTextUI()

    QBCore.Functions.TriggerCallback('motel:server:hasRoom', function(hasRoom)
        if hasRoom then
            entryDoorIndex = doorIndex
            DebugPrint("Entering through door: " .. doorIndex)
            EnterRoom()
        else
            PurchaseRoom()
        end
    end)
end

function PurchaseRoom()
    if isEntering then return end

    lib.hideTextUI()

    local alert = lib.alertDialog({
        header  = Locale('dialog_header'),
        content = Locale('dialog_content', Config.RoomPrice),
        centered = true,
        cancel   = true,
        labels   = {
            confirm = Locale('dialog_confirm'),
            cancel  = Locale('dialog_cancel'),
        },
    })

    if alert == 'confirm' then
        QBCore.Functions.TriggerCallback('motel:server:purchaseRoom', function(success, message)
            if success then
                QBCore.Functions.Notify(message, 'success')
            else
                QBCore.Functions.Notify(message, 'error')
            end
        end)
    end
end

-- ── Enter / exit room ─────────────────────────────────────────

function EnterRoom()
    if isEntering or isInRoom then return end

    isEntering = true
    lib.hideTextUI()

    QBCore.Functions.TriggerCallback('motel:server:getRoomData', function(roomData)
        if not roomData then
            QBCore.Functions.Notify(Locale('roomDataError'), 'error')
            isEntering = false
            return
        end

        currentRoomData = roomData
        entryDoorIndex  = entryDoorIndex or roomData.entryDoor

        if Config.Debug then
            print("[Motel] DEBUG: Room data received:")
            print("  bucket:",    roomData.bucket)
            print("  stashId:",   roomData.stashId)
            print("  entryDoor:", roomData.entryDoor)
            print("  isInside:",  roomData.isInside)
        end

        LoadMLOInterior(roomData)
    end)
end

function LoadMLOInterior(roomData)
    DebugPrint("Loading MLO interior...")

    DoScreenFadeOut(500)
    Wait(500)

    TriggerServerEvent('motel:server:enterRoom', entryDoorIndex)
    Wait(500)

    local ped         = PlayerPedId()
    local spawnCoords = Config.InteriorSystem.interactionPoints.spawn

    SetEntityCoords(ped, spawnCoords.x, spawnCoords.y, spawnCoords.z, false, false, false, true)
    SetEntityHeading(ped, 0.0)

    Wait(2000)
    DoScreenFadeIn(500)

    isInRoom   = true
    isEntering = false

    StartInfiniteHealth()
    SetupInteriorInteractions()

    QBCore.Functions.Notify(Locale('welcomeRoom'), 'success')
    DebugPrint("MLO interior entry complete.")
end

function RestoreInsideState(roomData)
    DebugPrint("Restoring inside-room state...")
    DebugPrint("Room data: " .. json.encode(roomData))

    currentRoomData = roomData
    entryDoorIndex  = roomData.entryDoor
    isInRoom        = true

    Wait(1000)

    local ped         = PlayerPedId()
    local spawnCoords = Config.InteriorSystem.interactionPoints.spawn

    SetEntityCoords(ped, spawnCoords.x, spawnCoords.y, spawnCoords.z, false, false, false, true)
    SetEntityHeading(ped, 0.0)

    Wait(1000)

    StartInfiniteHealth()
    SetupInteriorInteractions()

    QBCore.Functions.Notify(Locale('roomRestored'), 'success')
    DebugPrint("State restored successfully.")
end

function ExitRoom()
    if not isInRoom then return end

    DebugPrint("Exiting room...")
    lib.hideTextUI()

    StopInfiniteHealth()

    for k, point in pairs(insidePoints) do
        if point then point:remove() end
        insidePoints[k] = nil
    end

    TriggerServerEvent('motel:server:exitRoom')

    DoScreenFadeOut(500)
    Wait(500)

    local exitCoords, exitHeading

    if entryDoorIndex and Config.MotelDoors[entryDoorIndex] then
        exitCoords   = Config.MotelDoors[entryDoorIndex].coords
        exitHeading  = Config.MotelDoors[entryDoorIndex].heading
        DebugPrint("Exiting through door: " .. entryDoorIndex)
    else
        exitCoords  = Config.MotelDoors[1].coords
        exitHeading = Config.MotelDoors[1].heading
        DebugPrint("Using fallback door (1).")
    end

    local ped = PlayerPedId()
    SetEntityCoords(ped, exitCoords.x, exitCoords.y, exitCoords.z, false, false, false, true)
    SetEntityHeading(ped, exitHeading)

    Wait(500)
    DoScreenFadeIn(500)

    isInRoom        = false
    currentRoomData = nil
    entryDoorIndex  = nil

    QBCore.Functions.Notify(Locale('exitRoom'), 'success')
    DebugPrint("Room exit complete.")
end

-- ── Interior interaction points ───────────────────────────────

function SetupInteriorInteractions()
    DebugPrint("Setting up MLO interior interaction points...")

    -- Clear any leftover points from a previous session.
    for k, point in pairs(insidePoints) do
        if point then point:remove() end
        insidePoints[k] = nil
    end

    -- Exit point
    insidePoints.exit = lib.points.new({
        coords   = Config.InteriorSystem.interactionPoints.exit,
        distance = 2.5,

        onEnter = function()
            DebugPrint("Entered exit zone.")
            lib.showTextUI(Locale('textui_exit'))
        end,
        onExit = function()
            DebugPrint("Left exit zone.")
            lib.hideTextUI()
        end,
        nearby = function()
            if IsControlJustReleased(0, 38) then
                DebugPrint("Pressed E at exit.")
                ExitRoom()
            end
        end,
    })

    -- Storage / stash point
    insidePoints.storage = lib.points.new({
        coords   = Config.InteriorSystem.interactionPoints.stash,
        distance = 1.2,

        onEnter = function()
            DebugPrint("Entered storage zone.")
            lib.showTextUI(Locale('textui_storage'))
        end,
        onExit = function()
            DebugPrint("Left storage zone.")
            lib.hideTextUI()
        end,
        nearby = function()
            if IsControlJustReleased(0, 38) then
                DebugPrint("Pressed E at storage.")
                lib.hideTextUI()
                local success = exports.ox_inventory:openInventory('stash', currentRoomData.stashId)
                if not success then
                    TriggerServerEvent('motel:server:openStash', currentRoomData.stashId)
                end
            end
        end,
    })

    -- Wardrobe point
    insidePoints.wardrobe = lib.points.new({
        coords   = Config.InteriorSystem.interactionPoints.wardrobe,
        distance = 2.5,

        onEnter = function()
            DebugPrint("Entered wardrobe zone.")
            lib.showTextUI(Locale('textui_wardrobe'))
        end,
        onExit = function()
            DebugPrint("Left wardrobe zone.")
            lib.hideTextUI()
        end,
        nearby = function()
            if IsControlJustReleased(0, 38) then
                DebugPrint("Pressed E at wardrobe.")
                lib.hideTextUI()
                OpenAppearance()
            end
        end,
    })

    DebugPrint("Interaction points set up.")
    DebugPrint("Exit coords:    " .. json.encode(Config.InteriorSystem.interactionPoints.exit))
    DebugPrint("Stash coords:   " .. json.encode(Config.InteriorSystem.interactionPoints.stash))
    DebugPrint("Wardrobe coords:" .. json.encode(Config.InteriorSystem.interactionPoints.wardrobe))

    -- Post-setup distance diagnostics (debug only).
    if Config.Debug then
        CreateThread(function()
            Wait(2000)
            local coords = GetEntityCoords(PlayerPedId())
            print(string.format("[Motel] Player coords after setup: %s", json.encode(coords)))
            print(string.format("[Motel] Distance to exit:    %.2f", #(coords - Config.InteriorSystem.interactionPoints.exit)))
            print(string.format("[Motel] Distance to stash:   %.2f", #(coords - Config.InteriorSystem.interactionPoints.stash)))
            print(string.format("[Motel] Distance to wardrobe:%.2f", #(coords - Config.InteriorSystem.interactionPoints.wardrobe)))
        end)
    end
end

-- ── Appearance ───────────────────────────────────────────────

function OpenAppearance()
    DebugPrint("Opening illenium-appearance outfit menu...")

    if GetResourceState('illenium-appearance') ~= 'started' then
        DebugPrint("illenium-appearance is not started.")
        QBCore.Functions.Notify(Locale('appearanceUnavailable'), 'error')
        return
    end

    local ok = pcall(function()
        exports['illenium-appearance']:openOutfitMenu()
    end)

    if ok then
        DebugPrint("Outfit menu opened via export.")
    else
        DebugPrint("Export failed, trying event fallback...")
        local ok2 = pcall(function()
            TriggerEvent('illenium-appearance:client:openOutfitMenu')
        end)

        if ok2 then
            DebugPrint("Outfit menu opened via event fallback.")
        else
            DebugPrint("Both methods failed.")
            QBCore.Functions.Notify(Locale('appearanceError'), 'error')
        end
    end
end

-- ── Net Events ───────────────────────────────────────────────

RegisterNetEvent('motel:client:restoreInsideState', function(roomData)
    DebugPrint("Server requested state restore.")
    RestoreInsideState(roomData)
end)

-- ── Commands ─────────────────────────────────────────────────

-- Emergency exit command in case interaction points break.
RegisterCommand('exitmotel', function()
    if Config.Debug then
        print("[Motel] /exitmotel called")
        print("  isInRoom:", isInRoom)
        print("  currentRoomData:", json.encode(currentRoomData or {}))
    end

    if isInRoom or currentRoomData then
        ExitRoom()
    else
        QBCore.Functions.TriggerCallback('motel:server:getRoomData', function(roomData)
            if roomData and roomData.isInside then
                DebugPrint("Server says player is inside — forcing exit...")
                currentRoomData = roomData
                entryDoorIndex  = roomData.entryDoor
                isInRoom        = true
                ExitRoom()
            else
                QBCore.Functions.Notify(Locale('notInRoom'), 'error')
            end
        end)
    end
end, false)

-- Prints full client state to the F8 console.
RegisterCommand('debugmotel', function()
    print("=== MOTEL DEBUG ===")
    print("isInRoom:",       isInRoom)
    print("isEntering:",     isEntering)
    print("entryDoorIndex:", entryDoorIndex)
    print("playerLoaded:",   playerLoaded)
    print("currentRoomData:", json.encode(currentRoomData or {}))

    local coords = GetEntityCoords(PlayerPedId())
    print("Player coords:", coords)

    if isInRoom then
        print("=== INTERACTION POINTS ===")
        for k, point in pairs(insidePoints) do
            print(k .. " point:", point and "ACTIVE" or "INACTIVE")
        end

        print("=== DISTANCES ===")
        print("Exit:",     #(coords - Config.InteriorSystem.interactionPoints.exit))
        print("Stash:",    #(coords - Config.InteriorSystem.interactionPoints.stash))
        print("Wardrobe:", #(coords - Config.InteriorSystem.interactionPoints.wardrobe))
    end
    print("===================")
end, false)

-- Forces a state restore from the server (useful after a desync).
RegisterCommand('restoremotel', function()
    DebugPrint("/restoremotel called.")
    QBCore.Functions.TriggerCallback('motel:server:getRoomData', function(roomData)
        if roomData then
            DebugPrint("Forcing restore...")
            RestoreInsideState(roomData)
        else
            DebugPrint("No room data to restore.")
        end
    end)
end, false)

-- ── Resource cleanup ──────────────────────────────────────────

AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end

    StopInfiniteHealth()

    if motelBlip then
        RemoveBlip(motelBlip)
        motelBlip = nil
    end

    for _, point in ipairs(doorPoints) do
        if point then point:remove() end
    end

    for _, point in pairs(insidePoints) do
        if point then point:remove() end
    end

    if isInRoom then
        TriggerServerEvent('motel:server:exitRoom')
    end

    lib.hideTextUI()
    DoScreenFadeIn(500)
end)