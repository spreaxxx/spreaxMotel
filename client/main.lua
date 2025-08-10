local QBCore = exports['qb-core']:GetCoreObject()

local isInRoom = false
local currentRoomData = nil
local doorPoints = {}
local insidePoints = {}
local isEntering = false
local motelBlip = nil
local entryDoorIndex = nil
local playerLoaded = false

local function DebugPrint(text)
    if Config.Debug then
        print(text)
    end
end

CreateThread(function()
    motelBlip = AddBlipForCoord(Config.MotelBlip.coords.x, Config.MotelBlip.coords.y, Config.MotelBlip.coords.z)
    
    SetBlipSprite(motelBlip, Config.MotelBlip.sprite)
    SetBlipDisplay(motelBlip, Config.MotelBlip.display)
    SetBlipScale(motelBlip, Config.MotelBlip.scale)
    SetBlipColour(motelBlip, Config.MotelBlip.colour)
    SetBlipAsShortRange(motelBlip, true)
    
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentSubstringPlayerName(Config.MotelBlip.name)
    EndTextCommandSetBlipName(motelBlip)
    
    DebugPrint("Motel blip created successfully!")
end)

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    playerLoaded = true
    DebugPrint("Player loaded, checking motel state...")
    
    Wait(3000)
    
    QBCore.Functions.TriggerCallback('motel:server:getRoomData', function(roomData)
        if roomData and roomData.isInside then
            DebugPrint("Player inside motel, restoring...")
            RestoreInsideState(roomData)
        else
            DebugPrint("Player is outside")
        end
    end)
end)

CreateThread(function()
    Wait(5000) 
    
    if not playerLoaded then
        DebugPrint("Manual verify motel state...")
        QBCore.Functions.TriggerCallback('motel:server:getRoomData', function(roomData)
            if roomData and roomData.isInside then
                DebugPrint("Player outside (manual verify)")
                RestoreInsideState(roomData)
            end
        end)
    end
end)

CreateThread(function()
    for i, door in ipairs(Config.MotelDoors) do
        local point = lib.points.new({
            coords = door.coords,
            distance = 2.0,
            onEnter = function()
                if not isEntering and not isInRoom then
                    QBCore.Functions.TriggerCallback('motel:server:hasRoom', function(hasRoom)
                        if hasRoom then
                            lib.showTextUI(Config.TextUI.enter)
                        else
                            lib.showTextUI(Config.TextUI.purchase)
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
            end
        })
        doorPoints[i] = point
    end
end)

function HandleDoorInteraction(doorIndex)
    if isEntering or isInRoom then return end
    
    lib.hideTextUI()
    
    QBCore.Functions.TriggerCallback('motel:server:hasRoom', function(hasRoom)
        if hasRoom then
            entryDoorIndex = doorIndex
            DebugPrint("Entering door: " .. doorIndex)
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
        header = Config.Dialogs.purchaseHeader,
        content = Config.Dialogs.purchaseContent,
        centered = true,
        cancel = true,
        labels = {
            confirm = Config.Dialogs.confirmButton,
            cancel = Config.Dialogs.cancelButton
        }
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

function EnterRoom()
    if isEntering or isInRoom then return end
    
    isEntering = true
    lib.hideTextUI()
    
    QBCore.Functions.TriggerCallback('motel:server:getRoomData', function(roomData)
        if not roomData then
            QBCore.Functions.Notify(Config.Messages.roomDataError, 'error')
            isEntering = false
            return
        end
        
        currentRoomData = roomData
        entryDoorIndex = entryDoorIndex or roomData.entryDoor
        
        if Config.Debug then
            print("DEBUG: Motel data received:")
            print("bucket:", roomData.bucket)
            print("stashId:", roomData.stashId)
            print("entryDoor:", roomData.entryDoor)
            print("isInside:", roomData.isInside)
        end
        
        LoadMLOInterior(roomData)
    end)
end

function LoadMLOInterior(roomData)
    DebugPrint("Loading interior MLO...")
    
    DoScreenFadeOut(500)
    Wait(500)
    
    TriggerServerEvent('motel:server:enterRoom', entryDoorIndex)
    Wait(500)
    
    local ped = PlayerPedId()
    local spawnCoords = Config.InteriorSystem.interactionPoints.spawn
    
    SetEntityCoords(ped, spawnCoords.x, spawnCoords.y, spawnCoords.z, false, false, false, true)
    SetEntityHeading(ped, 0.0)
    
    Wait(2000)
    DoScreenFadeIn(500)
    
    isInRoom = true
    isEntering = false

    SetupInteriorInteractions()
    
    QBCore.Functions.Notify(Config.Messages.welcomeRoom, 'success')
    DebugPrint("Successfully entered the room!")
end

function RestoreInsideState(roomData)
    DebugPrint("Restoring motel data...")
    DebugPrint("Room data: " .. json.encode(roomData))
    
    currentRoomData = roomData
    entryDoorIndex = roomData.entryDoor
    isInRoom = true
    
    Wait(1000)
    
    local ped = PlayerPedId()
    local spawnCoords = Config.InteriorSystem.interactionPoints.spawn
    
    SetEntityCoords(ped, spawnCoords.x, spawnCoords.y, spawnCoords.z, false, false, false, true)
    SetEntityHeading(ped, 0.0)
    
    Wait(1000)
    
    SetupInteriorInteractions()
    
    QBCore.Functions.Notify(Config.Messages.motelRestoreSuccess, 'success')
    DebugPrint("State restored successfully!")
end

RegisterNetEvent('motel:client:restoreInsideState', function(roomData)
    RestoreInsideState(roomData)
end)

function SetupInteriorInteractions()
    DebugPrint("Setting up interior MLO interaction points...")
    
    for k, point in pairs(insidePoints) do
        if point then
            point:remove()
        end
        insidePoints[k] = nil
    end
    
    insidePoints.exit = lib.points.new({
        coords = Config.InteriorSystem.interactionPoints.exit,
        distance = 2.5,
        onEnter = function()
            DebugPrint("Entered exit zone")
            lib.showTextUI(Config.TextUI.exit)
        end,
        onExit = function()
            DebugPrint("Exited exit zone")
            lib.hideTextUI()
        end,
        nearby = function()
            if IsControlJustReleased(0, 38) then
                DebugPrint("Pressed E at exit")
                ExitRoom()
            end
        end
    })
    
    insidePoints.storage = lib.points.new({
        coords = Config.InteriorSystem.interactionPoints.stash,
        distance = 1.2, 
        onEnter = function()
            DebugPrint("Entered storage zone")
            lib.showTextUI(Config.TextUI.storage)
        end,
        onExit = function()
            DebugPrint("Exited storage zone")
            lib.hideTextUI()
        end,
        nearby = function()
            if IsControlJustReleased(0, 38) then
                DebugPrint("Pressed E at storage")
                lib.hideTextUI()
                local success = exports.ox_inventory:openInventory('stash', currentRoomData.stashId)
                if not success then
                    TriggerServerEvent('motel:server:openStash', currentRoomData.stashId)
                end
            end
        end
    })
    
    insidePoints.wardrobe = lib.points.new({
        coords = Config.InteriorSystem.interactionPoints.wardrobe,
        distance = 2.5,
        onEnter = function()
            DebugPrint("Entered wardrobe zone")
            lib.showTextUI(Config.TextUI.wardrobe)
        end,
        onExit = function()
            DebugPrint("Exited wardrobe zone")
            lib.hideTextUI()
        end,
        nearby = function()
            if IsControlJustReleased(0, 38) then
                DebugPrint("Pressed E at wardrobe")
                lib.hideTextUI()
                OpenAppearance()
            end
        end
    })
    
    DebugPrint("Interaction points set up!")
    DebugPrint("Exit: " .. json.encode(Config.InteriorSystem.interactionPoints.exit))
    DebugPrint("Stash: " .. json.encode(Config.InteriorSystem.interactionPoints.stash))
    DebugPrint("Wardrobe: " .. json.encode(Config.InteriorSystem.interactionPoints.wardrobe))
    
    CreateThread(function()
        Wait(2000)
        local ped = PlayerPedId()
        local coords = GetEntityCoords(ped)
        DebugPrint("Player coords after setup: " .. json.encode(coords))
        DebugPrint("Distance to exit: " .. tostring(#(coords - Config.InteriorSystem.interactionPoints.exit)))
        DebugPrint("Distance to stash: " .. tostring(#(coords - Config.InteriorSystem.interactionPoints.stash)))
        DebugPrint("Distance to wardrobe: " .. tostring(#(coords - Config.InteriorSystem.interactionPoints.wardrobe)))
    end)
end

function ExitRoom()
    if not isInRoom then return end
    
    DebugPrint("Exiting the room...")
    lib.hideTextUI()
    
    for k, point in pairs(insidePoints) do
        if point then
            point:remove()
        end
        insidePoints[k] = nil
    end
    
    TriggerServerEvent('motel:server:exitRoom')
    
    DoScreenFadeOut(500)
    Wait(500)
    
    local exitCoords, exitHeading
    
    if entryDoorIndex and Config.MotelDoors[entryDoorIndex] then
        exitCoords = Config.MotelDoors[entryDoorIndex].coords
        exitHeading = Config.MotelDoors[entryDoorIndex].heading
        DebugPrint("Exiting through door: " .. entryDoorIndex)
    else
        exitCoords = Config.MotelDoors[1].coords
        exitHeading = Config.MotelDoors[1].heading
        DebugPrint("Using fallback door (1)")
    end
    
    local ped = PlayerPedId()
    SetEntityCoords(ped, exitCoords.x, exitCoords.y, exitCoords.z, false, false, false, true)
    SetEntityHeading(ped, exitHeading)
    
    Wait(500)
    DoScreenFadeIn(500)
    
    isInRoom = false
    currentRoomData = nil
    entryDoorIndex = nil
    
    QBCore.Functions.Notify(Config.Messages.exitRoom, 'success')
    DebugPrint("Room exit completed!")
end

function OpenAppearance()
    DebugPrint("Opening illenium-appearance outfit menu...")
    
    if GetResourceState('illenium-appearance') ~= 'started' then
        DebugPrint("illenium-appearance is not started")
        QBCore.Functions.Notify(Config.Messages.appearanceError, 'error')
        return
    end
    
    local success = pcall(function()
        exports['illenium-appearance']:openOutfitMenu()
    end)
    
    if success then
        DebugPrint("Outfit menu opened successfully")
    else
        DebugPrint("Error opening outfit menu, trying alternative method...")
        
        local success2 = pcall(function()
            TriggerEvent('illenium-appearance:client:openOutfitMenu')
        end)
        
        if success2 then
            DebugPrint("Outfits menu open successfully via event")
        else
            DebugPrint("Failed both methods")
            QBCore.Functions.Notify(Config.Messages.failedOutfitsMenu, 'error')
        end
    end
end

RegisterCommand('exitmotel', function()
    print("DEBUG: /exitmotel command triggered")
    print("DEBUG: isInRoom:", isInRoom)
    print("DEBUG: currentRoomData:", json.encode(currentRoomData or {}))
    
    if isInRoom or currentRoomData then
        ExitRoom()
    else
        QBCore.Functions.TriggerCallback('motel:server:getRoomData', function(roomData)
            if roomData and roomData.isInside then
                print("DEBUG: Server says player is inside, forcing exit...")
                currentRoomData = roomData
                entryDoorIndex = roomData.entryDoor
                isInRoom = true
                ExitRoom()
            else
                QBCore.Functions.Notify(Config.Messages.notInMotelRoom, 'error')
            end
        end)
    end
end, false)

RegisterCommand('debugmotel', function()
    print("=== DEBUG MOTEL ===")
    print("isInRoom:", isInRoom)
    print("isEntering:", isEntering)
    print("entryDoorIndex:", entryDoorIndex)
    print("playerLoaded:", playerLoaded)
    print("currentRoomData:", json.encode(currentRoomData or {}))
    
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    print("Player coords:", coords)
    
    if isInRoom then
        print("=== INTERACTION POINTS ===")
        for k, point in pairs(insidePoints) do
            if point then
                print(k .. " point: ACTIVE")
            else
                print(k .. " point: INACTIVE")
            end
        end
        
        print("=== DISTANCES ===")
        print("Exit:", #(coords - Config.InteriorSystem.interactionPoints.exit))
        print("Stash:", #(coords - Config.InteriorSystem.interactionPoints.stash))
        print("Wardrobe:", #(coords - Config.InteriorSystem.interactionPoints.wardrobe))
    end
    print("==================")
end, false)

RegisterCommand('restoremotel', function()
    DebugPrint("/restormotel command triggered")
    QBCore.Functions.TriggerCallback('motel:server:getRoomData', function(roomData)
        if roomData then
            DebugPrint("Forcing restore...")
            RestoreInsideState(roomData)
        else
            DebugPrint("No data found")
        end
    end)
end, false)

AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() == resourceName then
        if motelBlip then
            RemoveBlip(motelBlip)
            motelBlip = nil
        end
        
        for i, point in ipairs(doorPoints) do
            if point then
                point:remove()
            end
        end
        
        for k, point in pairs(insidePoints) do
            if point then
                point:remove()
            end
        end
        
        if isInRoom then
            TriggerServerEvent('motel:server:exitRoom')
        end
        
        lib.hideTextUI()
        DoScreenFadeIn(500)
    end
end)
