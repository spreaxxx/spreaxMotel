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
    
    DebugPrint("Blip do motel criado com sucesso!")
end)

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    playerLoaded = true
    DebugPrint("Jogador carregado, a verificar estado do motel...")
    
    Wait(3000)
    
    QBCore.Functions.TriggerCallback('motel:server:getRoomData', function(roomData)
        if roomData and roomData.isInside then
            DebugPrint("Jogador deve estar dentro do quarto, a restaurar...")
            RestoreInsideState(roomData)
        else
            DebugPrint("Jogador não estava dentro do quarto")
        end
    end)
end)

CreateThread(function()
    Wait(5000) 
    
    if not playerLoaded then
        DebugPrint("Verificação manual do estado do motel...")
        QBCore.Functions.TriggerCallback('motel:server:getRoomData', function(roomData)
            if roomData and roomData.isInside then
                DebugPrint("Jogador deve estar dentro do quarto (verificação manual)")
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
            DebugPrint("Entrando pela porta: " .. doorIndex)
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
            print("DEBUG: Dados do quarto recebidos:")
            print("bucket:", roomData.bucket)
            print("stashId:", roomData.stashId)
            print("entryDoor:", roomData.entryDoor)
            print("isInside:", roomData.isInside)
        end
        
        LoadMLOInterior(roomData)
    end)
end

function LoadMLOInterior(roomData)
    DebugPrint("A carregar interior MLO...")
    
    DoScreenFadeOut(500)
    Wait(500)
    
    TriggerServerEvent('motel:server:enterRoom', entryDoorIndex)
    Wait(500)
    
    local ped = PlayerPedId()
    local spawnCoords = Config.InteriorSystem.interactionPoints.spawn
    
    SetEntityCoords(ped, spawnCoords.x, spawnCoords.y, spawnCoords.z, false, false, false, true)
    SetEntityHeading(ped, 0.0)
    
    -- Wait for MLO to load
    Wait(2000)
    DoScreenFadeIn(500)
    
    isInRoom = true
    isEntering = false

    SetupInteriorInteractions()
    
    QBCore.Functions.Notify(Config.Messages.welcomeRoom, 'success')
    DebugPrint("Entrada no interior MLO concluída!")
end

function RestoreInsideState(roomData)
    DebugPrint("A restaurar estado dentro do quarto...")
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
    
    QBCore.Functions.Notify("Estado do quarto restaurado! Podes usar /sairmotel se necessário.", 'success')
    DebugPrint("Estado restaurado com sucesso!")
end

RegisterNetEvent('motel:client:restoreInsideState', function(roomData)
    RestoreInsideState(roomData)
end)

function SetupInteriorInteractions()
    DebugPrint("A configurar pontos de interação do interior MLO...")
    
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
            DebugPrint("Entrou na zona de saída")
            lib.showTextUI(Config.TextUI.exit)
        end,
        onExit = function()
            DebugPrint("Saiu da zona de saída")
            lib.hideTextUI()
        end,
        nearby = function()
            if IsControlJustReleased(0, 38) then
                DebugPrint("Pressionou E na saída")
                ExitRoom()
            end
        end
    })
    
    insidePoints.storage = lib.points.new({
        coords = Config.InteriorSystem.interactionPoints.stash,
        distance = 1.2, 
        onEnter = function()
            DebugPrint("Entrou na zona de armazenamento")
            lib.showTextUI(Config.TextUI.storage)
        end,
        onExit = function()
            DebugPrint("Saiu da zona de armazenamento")
            lib.hideTextUI()
        end,
        nearby = function()
            if IsControlJustReleased(0, 38) then
                DebugPrint("Pressionou E no armazenamento")
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
            DebugPrint("Entrou na zona do guarda-roupa")
            lib.showTextUI(Config.TextUI.wardrobe)
        end,
        onExit = function()
            DebugPrint("Saiu da zona do guarda-roupa")
            lib.hideTextUI()
        end,
        nearby = function()
            if IsControlJustReleased(0, 38) then
                DebugPrint("Pressionou E no guarda-roupa")
                lib.hideTextUI()
                OpenAppearance()
            end
        end
    })
    
    DebugPrint("Pontos de interação configurados!")
    DebugPrint("Exit: " .. json.encode(Config.InteriorSystem.interactionPoints.exit))
    DebugPrint("Stash: " .. json.encode(Config.InteriorSystem.interactionPoints.stash))
    DebugPrint("Wardrobe: " .. json.encode(Config.InteriorSystem.interactionPoints.wardrobe))
    
    CreateThread(function()
        Wait(2000)
        local ped = PlayerPedId()
        local coords = GetEntityCoords(ped)
        DebugPrint("Player coords após setup: " .. json.encode(coords))
        DebugPrint("Distância para exit: " .. tostring(#(coords - Config.InteriorSystem.interactionPoints.exit)))
        DebugPrint("Distância para stash: " .. tostring(#(coords - Config.InteriorSystem.interactionPoints.stash)))
        DebugPrint("Distância para wardrobe: " .. tostring(#(coords - Config.InteriorSystem.interactionPoints.wardrobe)))
    end)
end

function ExitRoom()
    if not isInRoom then return end
    
    DebugPrint("A sair do quarto...")
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
        DebugPrint("Saindo pela porta: " .. entryDoorIndex)
    else
        exitCoords = Config.MotelDoors[1].coords
        exitHeading = Config.MotelDoors[1].heading
        DebugPrint("Usando porta fallback (1)")
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
    DebugPrint("Saída do quarto concluída!")
end


function OpenAppearance()
    DebugPrint("A abrir menu de outfits do illenium-appearance...")
    
    if GetResourceState('illenium-appearance') ~= 'started' then
        DebugPrint("illenium-appearance não está iniciado")
        QBCore.Functions.Notify("Sistema de aparência não disponível", 'error')
        return
    end
    
    local success = pcall(function()
        exports['illenium-appearance']:openOutfitMenu()
    end)
    
    if success then
        DebugPrint("Menu de outfits aberto com sucesso")
    else
        DebugPrint("Erro ao abrir menu de outfits, tentando método alternativo...")
        
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
                print("DEBUG: Server says it's in, forcing it out...")
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
