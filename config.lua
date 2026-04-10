Config = {}

-- ── Language ─────────────────────────────────────────────────
-- Which locale key to use from locales.lua ('en', 'pt', etc.)
Config.Locale = 'en'

-- ── General ──────────────────────────────────────────────────

-- Display name of the motel (used for blip label, dialogs, etc.)
Config.MotelName = "Motel"

-- Price to purchase a room. Set to 0 for free.
Config.RoomPrice = 0

-- Economy account to charge / refund when buying a room.
-- Common values: 'bank', 'cash', 'black_money'
Config.Currency = 'bank'

-- Enable verbose debug prints in the server/client console.
Config.Debug = false

-- ── Infinite Health (inside room) ────────────────────────────
Config.InfiniteHealth = {
    -- Master toggle. When false the entire system is disabled.
    enabled = true,

    -- Reset hunger and thirst to 100 while the player is inside.
    resetNeeds = true,

    -- Block incoming damage events while the player is inside.
    preventDamage = true,

    -- How often (in ms) the health / needs check runs.
    -- Lower = more responsive but more CPU cost.
    checkInterval = 1000,
}

-- ── Stash (ox_inventory) ─────────────────────────────────────
Config.Stash = {
    -- Maximum number of inventory slots per room stash.
    slots = 100,

    -- Maximum combined weight (grams) the stash can hold.
    -- 10 000 000 g = 10 000 kg — effectively unlimited.
    maxWeight = 10000000,

    -- Whether the stash is shared between players.
    -- Keep true so only the room owner can open it.
    isPersonal = true,
}

-- ── Routing Buckets ──────────────────────────────────────────
Config.Buckets = {
    -- First bucket ID assigned to rooms.
    -- Rooms are allocated sequentially from this number upward.
    -- Avoid 0 (public world) and any buckets your server already uses.
    startId = 1000,
}

-- ── Interior System ──────────────────────────────────────────
Config.InteriorSystem = {
    -- Set to true if you are using an MLO interior instead of
    -- the default IPL / shell approach.
    useMLO = false,

    -- Base coordinates of the interior shell that all rooms share.
    -- Players are teleported here when entering their room.
    baseCoords = vector3(152.31, -1004.18, -100.0),

    -- Named interaction points inside the room shell.
    interactionPoints = {
        spawn    = vector3(151.39, -1007.74, -100.0),  -- where the player spawns on entry
        exit     = vector3(151.39, -1007.74, -100.0),  -- where the exit prompt appears
        stash    = vector3(151.28, -1004.02, -100.0),  -- stash / storage interaction
        wardrobe = vector3(151.79, -1000.99, -100.0),  -- wardrobe / appearance interaction
    },

    -- Use routing buckets to isolate players in their own instance.
    -- Disable only if your server manages instances another way.
    useRoutingBuckets = true,
}

-- ── Motel Blip ───────────────────────────────────────────────
Config.MotelBlip = {
    -- World position of the map blip.
    coords  = vector3(317.0, -220.0, 54.22),

    -- GTA blip sprite ID. 475 = motel icon.
    sprite  = 475,

    -- Blip display mode (4 = show on minimap and full map).
    display = 4,

    -- Scale of the blip on the map (0.1 – 1.0).
    scale   = 0.6,

    -- Blip colour ID. 3 = blue.
    colour  = 3,

    -- Label shown when the player hovers the blip.
    name    = "Motel",
}

-- ── Door Coordinates ─────────────────────────────────────────
-- Each entry is one motel room door in the world.
-- 'coords'   – world position of the door interaction sphere.
-- 'heading'  – direction the player faces when the prompt appears.
-- The index of each entry is used as the door / room identifier.
Config.MotelDoors = {
    -- Ground floor 
    { coords = vector3(312.87, -218.61, 54.22), heading = 161.74 },
    { coords = vector3(310.81, -218.02, 54.22), heading = 166.19 },
    { coords = vector3(307.23, -216.66, 54.22), heading = 161.60 },
    { coords = vector3(307.48, -213.27, 54.22), heading =  80.82 },
    { coords = vector3(309.69, -208.11, 54.22), heading =  73.53 },
    { coords = vector3(311.33, -203.41, 54.22), heading =  67.57 },
    { coords = vector3(313.25, -198.09, 54.22), heading =  68.10 },
    { coords = vector3(315.80, -194.82, 54.22), heading = 345.52 },
    { coords = vector3(319.38, -196.21, 54.22), heading = 344.83 },
    { coords = vector3(321.42, -196.98, 54.22), heading = 343.62 },
    { coords = vector3(343.02, -209.59, 54.22), heading = 247.83 },
    { coords = vector3(340.95, -214.95, 54.22), heading = 244.02 },
    { coords = vector3(339.13, -219.53, 54.22), heading = 246.37 },
    { coords = vector3(337.09, -224.78, 54.22), heading = 259.29 },
    { coords = vector3(334.96, -227.31, 54.22), heading = 157.54 },
    { coords = vector3(331.35, -226.02, 54.22), heading = 157.14 },
    { coords = vector3(329.33, -225.22, 54.22), heading = 154.23 },
    { coords = vector3(344.74, -205.03, 54.22), heading = 154.23 },
    { coords = vector3(346.76, -199.74, 54.22), heading = 154.23 },

    -- First floor
    { coords = vector3(312.87, -218.61, 58.01), heading = 161.74 },
    { coords = vector3(310.81, -218.02, 58.01), heading = 166.19 },
    { coords = vector3(307.23, -216.66, 58.01), heading = 161.60 },
    { coords = vector3(307.48, -213.27, 58.01), heading =  80.82 },
    { coords = vector3(309.69, -208.11, 58.01), heading =  73.53 },
    { coords = vector3(311.33, -203.41, 58.01), heading =  67.57 },
    { coords = vector3(313.25, -198.09, 58.01), heading =  68.10 },
    { coords = vector3(315.80, -194.82, 58.01), heading = 345.52 },
    { coords = vector3(319.38, -196.21, 58.01), heading = 344.83 },
    { coords = vector3(321.42, -196.98, 58.01), heading = 343.62 },
    { coords = vector3(343.02, -209.59, 58.01), heading = 247.83 },
    { coords = vector3(340.95, -214.95, 58.01), heading = 244.02 },
    { coords = vector3(339.13, -219.53, 58.01), heading = 246.37 },
    { coords = vector3(337.09, -224.78, 58.01), heading = 259.29 },
    { coords = vector3(334.96, -227.31, 58.01), heading = 157.54 },
    { coords = vector3(331.35, -226.02, 58.01), heading = 157.14 },
    { coords = vector3(329.33, -225.22, 58.01), heading = 154.23 },
    { coords = vector3(344.74, -205.03, 58.01), heading = 154.23 },
    { coords = vector3(346.76, -199.74, 58.01), heading = 154.23 },
}