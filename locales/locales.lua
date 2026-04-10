Locales = {}

Locales['en'] = {

    -- ── Notifications ────────────────────────────────────────
    purchaseSuccess     = "Room purchased successfully!",
    purchaseFailed      = "Failed to purchase the room. Please try again.",
    alreadyOwnsRoom     = "You already own a motel room!",
    notEnoughMoney      = "You don't have enough money! You need $%s",   -- %s = price
    welcomeRoom         = "Welcome to your room! You are protected here and cannot die.",
    exitRoom            = "You have left your room.",
    appearanceSaved     = "Appearance saved!",
    appearanceCancelled = "Appearance change cancelled.",
    roomDataError       = "Error retrieving room data.",
    playerNotFound      = "Player not found.",
    roomRestored        = "Room state restored! Use /sairmotel if needed.",
    notInRoom           = "You are not in a motel room.",
    appearanceUnavailable = "Appearance system is not available.",
    appearanceError     = "Error opening the outfit menu.",

    -- ── DrawText / TextUI prompts ─────────────────────────────
    textui_purchase     = "[E] Buy Motel Room ($%s)",   -- %s = price
    textui_enter        = "[E] Enter Your Room",
    textui_exit         = "[E] Exit Room",
    textui_appearance   = "[E] Change Appearance",
    textui_storage      = "[E] Open Storage",
    textui_wardrobe     = "[E] Wardrobe",

    -- ── Dialog (purchase confirmation) ───────────────────────
    dialog_header       = "Motel",
    dialog_content      = "Do you want to rent a motel room for $%s?",  -- %s = price
    dialog_confirm      = "Confirm",
    dialog_cancel       = "Cancel",

    -- ── Server / debug messages (visible in server console) ──
    stash_reregister    = "Re-registering stash in bucket: %s",
    stash_notfound      = "Stash not found, creating: %s",
    player_connected    = "Player connected, registering stash: %s",
    player_restoring    = "Player was inside room, restoring state...",
    warn_invalid_stash  = "WARNING: Player attempted to access invalid stash: %s",
}

-- ── Helper ───────────────────────────────────────────────────
-- Usage: Locale('welcomeRoom')  or  Locale('notEnoughMoney', price)
function Locale(key, ...)
    local lang = Config and Config.Locale or 'en'
    local t    = Locales[lang] or Locales['en']
    local str  = t[key] or ('[MISSING LOCALE: ' .. tostring(key) .. ']')
    if select('#', ...) > 0 then
        return string.format(str, ...)
    end
    return str
end