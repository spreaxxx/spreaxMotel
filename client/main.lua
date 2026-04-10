local QBCore = exports['qb-core']:GetCoreObject()

local isInRoom = false
local currentRoomData = nil
local doorPoints = {}
local insidePoints = {}
local isEntering = false
local motelBlip = nil
local entryDoorIndex = nil
local playerLoaded = false
local infiniteHealthThread = nil

local preservedHealth = nil
local preservedArmor = nil
local preservedHunger = nil
local preservedThirst = nil

local function DebugPrint(text)
    if Config.Debug then
        print(text)
    end
end

local function StartInfiniteHealth()
    if infiniteHealthThread then return end
    
    DebugPrint("Iniciando sistema de preservação de stats no motel...")
    
    local ped = PlayerPedId()
    preservedHealth = GetEntityHealth(ped)
    preservedArmor = GetPedArmour(ped)
    
    QBCore.Functions.TriggerCallback('motel:server:getPlayerNeeds', function(needs)
        if needs then
            preservedHunger = needs.hunger
            preservedThirst = needs.thirst
            DebugPrint("Stats preservados - Vida: " .. preservedHealth .. ", Armadura: " .. preservedArmor .. ", Fome: " .. preservedHunger .. ", Sede: " .. preservedThirst)
        else
            preservedHunger = 50
            preservedThirst = 50
            DebugPrint("Usando valores fallback para fome e sede")
        end
    end)
    
    infiniteHealthThread = CreateThread(function()
        while isInRoom and preservedHealth and preservedArmor do
            local ped = PlayerPedId()
            
            if GetEntityHealth(ped) < preservedHealth then
                SetEntityHealth(ped, preservedHealth)
            end
            
            if GetPedArmour(ped) < preservedArmor then
                SetPedArmour(ped, preservedArmor)
            end
            
            if preservedHunger and preservedThirst then
                TriggerServerEvent('motel:server:maintainNeeds', preservedHunger, preservedThirst)
            end
            
            Wait(1000)
        end
        
        DebugPrint("Sistema de preservação de stats desativado")
        infiniteHealthThread = nil
    end)
end

local function StopInfiniteHealth()
    preservedHealth = nil
    preservedArmor = nil
    preservedHunger = nil
    preservedThirst = nil
    
    infiniteHealthThread = nil
    
    local ped = PlayerPedId()
    SetEntityInvincible(ped, false)
    
    DebugPrint("Sistema de preservação de stats completamente desativado - jogador pode agora perder stats normalmente")
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
            if roomData then
                DebugPrint("A forçar restauração...")
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
    
    Wait(2000)
    DoScreenFadeIn(500)
    
    isInRoom = true
    isEntering = false
    
    StartInfiniteHealth()
    
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
    
    StartInfiniteHealth()
    
    SetupInteriorInteractions()
    
    QBCore.Functions.Notify("Estado do quarto restaurado! Podes usar /sairmotel se necessário.", 'success')
    DebugPrint("Estado restaurado com sucesso!")
end

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
    
    StopInfiniteHealth()
    
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
            DebugPrint("Menu de outfits aberto com método alternativo")
        else
            DebugPrint("Falha em ambos os métodos")
            QBCore.Functions.Notify("Erro ao abrir menu de outfits", 'error')
        end
    end
end

RegisterCommand('sairmotel', function()
    print("DEBUG: Comando /sairmotel executado")
    print("DEBUG: isInRoom:", isInRoom)
    print("DEBUG: currentRoomData:", json.encode(currentRoomData or {}))
    
    if isInRoom or currentRoomData then
        ExitRoom()
    else
        QBCore.Functions.TriggerCallback('motel:server:getRoomData', function(roomData)
            if roomData and roomData.isInside then
                print("DEBUG: Servidor diz que estás dentro, a forçar saída...")
                currentRoomData = roomData
                entryDoorIndex = roomData.entryDoor
                isInRoom = true
                ExitRoom()
            else
                QBCore.Functions.Notify("Não estás num quarto do motel", 'error')
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
        print("=== PONTOS DE INTERAÇÃO ===")
        for k, point in pairs(insidePoints) do
            if point then
                print(k .. " point: ATIVO")
            else
                print(k .. " point: INATIVO")
            end
        end
        
        print("=== DISTÂNCIAS ===")
        print("Exit:", #(coords - Config.InteriorSystem.interactionPoints.exit))
        print("Stash:", #(coords - Config.InteriorSystem.interactionPoints.stash))
        print("Wardrobe:", #(coords - Config.InteriorSystem.interactionPoints.wardrobe))
    end
    print("==================")
end, false)

RegisterCommand('restoremotel', function()
    DebugPrint("Comando /restoremotel executado")
    QBCore.Functions.TriggerCallback('motel:server:getRoomData', function(roomData)
        if roomData then
            DebugPrint("A forçar restauração...")
            RestoreInsideState(roomData)
        else
            DebugPrint("Sem dados de quarto para restaurar")
        end
    end)
end, false)

AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() == resourceName then
        StopInfiniteHealth()
        
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