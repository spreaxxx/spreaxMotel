Config = {}

Config.MotelName = "Motel"
Config.RoomPrice = 0
Config.Currency = 'bank'

Config.Debug = false

Config.InfiniteHealth = {
    enabled = true,
    resetNeeds = true,
    preventDamage = true,
    checkInterval = 1000
}

function DebugPrint(message)
    if Config.Debug then
        print("DEBUG: " .. tostring(message))
    end
end

Config.MotelDoors = {
    {coords = vector3(312.87, -218.61, 54.22), heading = 161.74},
    {coords = vector3(310.81, -218.02, 54.22), heading = 166.19},
    {coords = vector3(307.23, -216.66, 54.22), heading = 161.6},
    {coords = vector3(307.48, -213.27, 54.22), heading = 80.82},
    {coords = vector3(309.69, -208.11, 54.22), heading = 73.53},
    {coords = vector3(311.33, -203.41, 54.22), heading = 67.57},
    {coords = vector3(313.25, -198.09, 54.22), heading = 68.10},
    {coords = vector3(315.80, -194.82, 54.22), heading = 345.52},
    {coords = vector3(319.38, -196.21, 54.22), heading = 344.83},
    {coords = vector3(321.42, -196.98, 54.22), heading = 343.62},
    {coords = vector3(343.02, -209.59, 54.22), heading = 247.83},
    {coords = vector3(340.95, -214.95, 54.22), heading = 244.02},
    {coords = vector3(339.13, -219.53, 54.22), heading = 246.37},
    {coords = vector3(337.09, -224.78, 54.22), heading = 259.29},
    {coords = vector3(334.96, -227.31, 54.22), heading = 157.54},
    {coords = vector3(331.35, -226.02, 54.22), heading = 157.14},
    {coords = vector3(329.33, -225.22, 54.22), heading = 154.23},
    {coords = vector3(344.74, -205.03, 54.22), heading = 154.23},
    {coords = vector3(346.76, -199.74, 54.22), heading = 154.23},
    {coords = vector3(312.87, -218.61, 58.01), heading = 161.74},
    {coords = vector3(310.81, -218.02, 58.01), heading = 166.19},
    {coords = vector3(307.23, -216.66, 58.01), heading = 161.6},
    {coords = vector3(307.48, -213.27, 58.01), heading = 80.82},
    {coords = vector3(309.69, -208.11, 58.01), heading = 73.53},
    {coords = vector3(311.33, -203.41, 58.01), heading = 67.57},
    {coords = vector3(313.25, -198.09, 58.01), heading = 68.10},
    {coords = vector3(315.80, -194.82, 58.01), heading = 345.52},
    {coords = vector3(319.38, -196.21, 58.01), heading = 344.83},
    {coords = vector3(321.42, -196.98, 58.01), heading = 343.62},
    {coords = vector3(343.02, -209.59, 58.01), heading = 247.83},
    {coords = vector3(340.95, -214.95, 58.01), heading = 244.02},
    {coords = vector3(339.13, -219.53, 58.01), heading = 246.37},
    {coords = vector3(337.09, -224.78, 58.01), heading = 259.29},
    {coords = vector3(334.96, -227.31, 58.01), heading = 157.54},
    {coords = vector3(331.35, -226.02, 58.01), heading = 157.14},
    {coords = vector3(329.33, -225.22, 58.01), heading = 154.23},
    {coords = vector3(344.74, -205.03, 58.01), heading = 154.23},
    {coords = vector3(346.76, -199.74, 58.01), heading = 154.23},
}

Config.MotelBlip = {
    coords = vector3(317.0, -220.0, 54.22),
    sprite = 475,
    display = 4,
    scale = 0.6,
    colour = 3,
    name = "Motel"
}

Config.InteriorSystem = {
    useMLO = false,
    baseCoords = vector3(152.31, -1004.18, -100.0),
    
    interactionPoints = {
        spawn = vector3(151.39, -1007.74, -100.0),
        exit = vector3(151.39, -1007.74, -100.0),
        stash = vector3(151.28, -1004.02, -100.0),
        wardrobe = vector3(151.79, -1000.99, -100.0),
    },
    
    useRoutingBuckets = true
}

Config.TextUI = {
    purchase = "[E] Comprar Quarto do Motel (0€)",
    enter = "[E] Entrar no Teu Quarto",
    exit = "[E] Sair do Quarto",
    appearance = "[E] Alterar Aparência",
    storage = "[E] Abrir Armazenamento",
    wardrobe = "[E] Guarda-Roupa"
}

Config.Messages = {
    purchaseSuccess = "Quarto comprado com sucesso!",
    purchaseFailed = "Falha ao comprar o quarto. Tenta novamente.",
    alreadyOwnsRoom = "Já possuis um quarto no motel!",
    notEnoughMoney = "Não tens dinheiro suficiente! Precisas de 0€",
    welcomeRoom = "Bem-vindo ao teu quarto! Aqui estás protegido e não podes morrer.",
    exitRoom = "Saíste do teu quarto",
    appearanceSaved = "Aparência guardada!",
    appearanceCancelled = "Alteração de aparência cancelada",
    roomDataError = "Erro ao obter dados do quarto",
    playerNotFound = "Jogador não encontrado"
}

Config.Dialogs = {
    purchaseHeader = "Motel Pinkcage",
    purchaseContent = "Queres comprar um quarto no motel de graça?",
    confirmButton = "Confirmar",
    cancelButton = "Cancelar"
}