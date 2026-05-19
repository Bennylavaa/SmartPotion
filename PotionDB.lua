-- PotionDB.lua
-- Default potion lists for SmartPotion (mana + healing)
-- Verified for TBC Classic Anniversary 2.5.5

-- zone codes:
--   "tk"  = Tempest Keep complex (The Eye, Arcatraz, Botanica, Mechanar)
--   "ssc" = Coilfang complex (Serpentshrine Cavern, Underbog, Steamvaults, Slave Pens)
--   nil   = usable anywhere

SmartPotion_DefaultManaPotions = {
    { name = "Cenarion Mana Salve",      id = 32903, zone = "ssc" },
    { name = "Bottled Nethergon Energy", id = 32902, zone = "tk"  },
    { name = "Super Mana Potion",        id = 22832, zone = nil   },
}

SmartPotion_DefaultHealPotions = {
    { name = "Cenarion Healing Salve",   id = 32904, zone = "ssc" },
    { name = "Bottled Nethergon Vapor",  id = 32905, zone = "tk"  },
    { name = "Super Healing Potion",     id = 22829, zone = nil   },
}

-- Each zone code matches GetRealZoneText() against any of these zones
SmartPotion_ZoneNames = {
    tk = {
        "Tempest Keep",  -- Anniversary returns this for the raid
        "The Eye",       -- in case other clients return this
        "The Arcatraz",
        "The Botanica",
        "The Mechanar",
    },
    ssc = {
        "Coilfang Reservoir", -- parent name in case Anniversary uses it
        "Serpentshrine Cavern",
        "The Underbog",
        "The Steamvault",  -- singular form
        "The Steamvaults", -- plural form (some clients)
        "The Slave Pens",
    },
}

-- Auto-applied zone restrictions when a potion is added by name
SmartPotion_KnownZones = {
    ["Cenarion Mana Salve"]      = "ssc",
    ["Bottled Nethergon Energy"] = "tk",
    ["Cenarion Healing Salve"]   = "ssc",
    ["Bottled Nethergon Vapor"]  = "tk",
}

-- Force-corrected IDs for known potions. Applied on every load so stale
-- saved-variable IDs from older versions of this addon get fixed up.
SmartPotion_KnownIds = {
    ["Cenarion Mana Salve"]      = 32903,
    ["Bottled Nethergon Energy"] = 32902,
    ["Cenarion Healing Salve"]   = 32904,
    ["Bottled Nethergon Vapor"]  = 32905,
    ["Super Mana Potion"]        = 22832,
    ["Super Healing Potion"]     = 22829,
}
