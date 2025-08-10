Config = {}

-- Motel Configuration
Config.MotelName = "Motel"
Config.RoomPrice = 100000 -- $100,000
Config.Currency = 'bank' -- Payment method (bank/cash)

-- Debug Configuration
Config.Debug = false -- Enable Debug prints (client/server)

-- Debug function helper
function DebugPrint(message)
    if Config.Debug then
        print("DEBUG: " .. tostring(message))
    end
end

-- Pinkcage Motel Door Locations
Config.MotelDoors = {
    {coords = vector3(312.87, -218.61, 54.22), heading = 161.74}, -- Door 1
    {coords = vector3(310.81, -218.02, 54.22), heading = 166.19}, -- Door 2
    {coords = vector3(307.23, -216.66, 54.22), heading = 161.6}, -- Door 3
    {coords = vector3(307.48, -213.27, 54.22), heading = 80.82}, -- Door 4
    {coords = vector3(309.69, -208.11, 54.22), heading = 73.53}, -- Door 5
    {coords = vector3(311.33, -203.41, 54.22), heading = 67.57}, -- Door 6
    {coords = vector3(313.25, -198.09, 54.22), heading = 68.10}, -- Door 7
    {coords = vector3(315.80, -194.82, 54.22), heading = 345.52}, -- Door 8
    {coords = vector3(319.38, -196.21, 54.22), heading = 344.83}, -- Door 9
    {coords = vector3(321.42, -196.98, 54.22), heading = 343.62}, -- Door 10
    {coords = vector3(343.02, -209.59, 54.22), heading = 247.83}, -- Door 11
    {coords = vector3(340.95, -214.95, 54.22), heading = 244.02}, -- Door 12
    {coords = vector3(339.13, -219.53, 54.22), heading = 246.37}, -- Door 13
    {coords = vector3(337.09, -224.78, 54.22), heading = 259.29}, -- Door 14
    {coords = vector3(334.96, -227.31, 54.22), heading = 157.54}, -- Door 15
    {coords = vector3(331.35, -226.02, 54.22), heading = 157.14}, -- Door 16
    {coords = vector3(329.33, -225.22, 54.22), heading = 154.23}, -- Door 17
    {coords = vector3(344.74, -205.03, 54.22), heading = 154.23}, -- Door 18 
    {coords = vector3(346.76, -199.74, 54.22), heading = 154.23}, -- Door 19 
    ----- 2nd Floor
    {coords = vector3(312.87, -218.61, 58.01), heading = 161.74}, -- Door 1
    {coords = vector3(310.81, -218.02, 58.01), heading = 166.19}, -- Door 2
    {coords = vector3(307.23, -216.66, 58.01), heading = 161.6}, -- Door 3
    {coords = vector3(307.48, -213.27, 58.01), heading = 80.82}, -- Door 4
    {coords = vector3(309.69, -208.11, 58.01), heading = 73.53}, -- Door 5
    {coords = vector3(311.33, -203.41, 58.01), heading = 67.57}, -- Door 6
    {coords = vector3(313.25, -198.09, 58.01), heading = 68.10}, -- Door 7
    {coords = vector3(315.80, -194.82, 58.01), heading = 345.52}, -- Door 8
    {coords = vector3(319.38, -196.21, 58.01), heading = 344.83}, -- Door 9
    {coords = vector3(321.42, -196.98, 58.01), heading = 343.62}, -- Door 10
    {coords = vector3(343.02, -209.59, 58.01), heading = 247.83}, -- Door 11
    {coords = vector3(340.95, -214.95, 58.01), heading = 244.02}, -- Door 12
    {coords = vector3(339.13, -219.53, 58.01), heading = 246.37}, -- Door 13
    {coords = vector3(337.09, -224.78, 58.01), heading = 259.29}, -- Door 14
    {coords = vector3(334.96, -227.31, 58.01), heading = 157.54}, -- Door 15
    {coords = vector3(331.35, -226.02, 58.01), heading = 157.14}, -- Door 16
    {coords = vector3(329.33, -225.22, 58.01), heading = 154.23}, -- Door 17
    {coords = vector3(344.74, -205.03, 58.01), heading = 154.23}, -- Door 18 
    {coords = vector3(346.76, -199.74, 58.01), heading = 154.23}, -- Door 19 

}

-- Motel Blip Configuration
Config.MotelBlip = {
    coords = vector3(317.0, -220.0, 54.22), -- Motel blip coords
    sprite = 475, -- Ícon type
    display = 4, -- Display type
    scale = 0.5, -- Blip Size
    colour = 3, -- Blip color
    name = "Motel" -- Motel Name on Map
}

-- IPL Interior Configuration -> MLO Interior Configuration
Config.InteriorSystem = {
    -- Using MLO instead of IPL
    useMLO = true, -- True = MLO, false = IPL
    baseCoords = vector3(151.38, -1007.91, -99.00), -- Default coords MLO
    
    -- Pontos de interação dentro do quarto do MLO
    interactionPoints = {
        spawn = vector3(151.38, -1007.91, -99.00), -- Room Spawn Point
        exit = vector3(151.38, -1007.91, -99.00), -- Exit Point (same as spawn)
        stash = vector3(154.47, -1007.33, -99.00), -- Storage
        wardrobe = vector3(151.74, -1001.49, -99.00), -- Clothing
    },
    
    -- Use Routing Buckets system (don't change this if you don't know what you're doing)
    useRoutingBuckets = true
}

-- TextUI Messages
Config.TextUI = {
    purchase = "[E] Buy Motel Room ($100,000)",
    enter = "[E] Enter Motel Room",
    exit = "[E] Exit Motel Room",
    appearance = "[E] Open Outfits Menu",
    storage = "[E] Open Storage",
    wardrobe = "[E] Clothing"
}

-- Messages
Config.Messages = {
    purchaseSuccess = "Room purchased successfully!",
    purchaseFailed = "Failed to purchase the room. Please try again.",
    alreadyOwnsRoom = "You already own a room in the motel!",
    notEnoughMoney = "You don't have enough money! You need $100,000.",
    welcomeRoom = "Welcome to your room!",
    exitRoom = "You have left your room.",
    appearanceSaved = "Appearance saved!",
    appearanceCancelled = "Appearance change cancelled.",
    roomDataError = "Error retrieving room data.",
    playerNotFound = "Player not found.",
    notInMotelRoom = "You are not in a motel room",
    failedOutfitsMenu = "Failed to open outfits menu",
    motelRestoreSuccess = "Room state restored! You can use /exitmotel if needed.",
    appearanceError = "Appearance system not available"
}

-- Dialogs
Config.Dialogs = {
    purchaseHeader = "Pinkcage Motel",
    purchaseContent = "Do you want to buy a room in the motel for $100,000?",
    confirmButton = "Confirm",
    cancelButton = "Cancel"
}
