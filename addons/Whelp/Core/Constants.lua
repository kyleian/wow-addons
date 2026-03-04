--[[
    Whelp - Constants
    Core constants and configuration values used throughout the addon
]]

local ADDON_NAME, Whelp = ...

-- Version info
Whelp.VERSION = "1.0.0"
Whelp.DB_VERSION = 1

-- Addon namespace
Whelp.ADDON_NAME = ADDON_NAME

-- Color scheme (hex and RGB values)
Whelp.Colors = {
    -- Primary colors
    PRIMARY = {r = 0.85, g = 0.2, b = 0.2},      -- Whelp red
    PRIMARY_HEX = "d93333",
    SECONDARY = {r = 0.2, g = 0.2, b = 0.2},    -- Dark gray
    SECONDARY_HEX = "333333",

    -- Rating colors (star colors)
    STAR_FILLED = {r = 1.0, g = 0.82, b = 0.0}, -- Gold
    STAR_EMPTY = {r = 0.4, g = 0.4, b = 0.4},   -- Gray

    -- Rating level colors
    RATING_EXCELLENT = {r = 0.0, g = 0.8, b = 0.0},   -- Green (4.5-5.0)
    RATING_GOOD = {r = 0.5, g = 0.8, b = 0.0},        -- Yellow-green (3.5-4.49)
    RATING_AVERAGE = {r = 1.0, g = 0.82, b = 0.0},    -- Yellow (2.5-3.49)
    RATING_POOR = {r = 1.0, g = 0.5, b = 0.0},        -- Orange (1.5-2.49)
    RATING_TERRIBLE = {r = 0.8, g = 0.0, b = 0.0},    -- Red (0-1.49)

    -- UI colors
    BACKGROUND = {r = 0.1, g = 0.1, b = 0.1, a = 0.9},
    BORDER = {r = 0.3, g = 0.3, b = 0.3},
    TEXT_NORMAL = {r = 1.0, g = 1.0, b = 1.0},
    TEXT_HIGHLIGHT = {r = 1.0, g = 0.82, b = 0.0},
    TEXT_DISABLED = {r = 0.5, g = 0.5, b = 0.5},

    -- Faction colors
    ALLIANCE = {r = 0.0, g = 0.44, b = 0.87},
    HORDE = {r = 0.77, g = 0.12, b = 0.23},
    NEUTRAL = {r = 0.9, g = 0.7, b = 0.0},
}

-- Service categories
Whelp.Categories = {
    PROFESSION_PACKAGE = {
        id = "profession_package",
        name = "Profession Packages",
        description = "1-300 or 1-375 profession leveling kits",
        icon = "Interface\\Icons\\INV_Misc_Book_09",
    },
    ENCHANTING = {
        id = "enchanting",
        name = "Enchanting Services",
        description = "Weapon and armor enchantments",
        icon = "Interface\\Icons\\Trade_Engraving",
    },
    CRAFTING = {
        id = "crafting",
        name = "Crafting Services",
        description = "Crafted items and gear",
        icon = "Interface\\Icons\\Trade_BlackSmithing",
    },
    BOOST = {
        id = "boost",
        name = "Boosting Services",
        description = "Dungeon runs, leveling boosts, etc.",
        icon = "Interface\\Icons\\Spell_Holy_Crusade",
    },
    GOLD_SERVICES = {
        id = "gold_services",
        name = "Gold Services",
        description = "Gold buying/selling, GDKP runs",
        icon = "Interface\\Icons\\INV_Misc_Coin_01",
    },
    PORTALS = {
        id = "portals",
        name = "Portal Services",
        description = "Mage portals and summons",
        icon = "Interface\\Icons\\Spell_Arcane_PortalStormwind",
    },
    ARENA = {
        id = "arena",
        name = "Arena Services",
        description = "Arena carries and coaching",
        icon = "Interface\\Icons\\INV_Sword_48",
    },
    RAID = {
        id = "raid",
        name = "Raid Services",
        description = "Raid carries, attunements, etc.",
        icon = "Interface\\Icons\\Spell_Shadow_SummonInfernal",
    },
    OTHER = {
        id = "other",
        name = "Other Services",
        description = "Miscellaneous services",
        icon = "Interface\\Icons\\INV_Misc_QuestionMark",
    },
}

-- Category lookup by ID
Whelp.CategoryLookup = {}
for key, data in pairs(Whelp.Categories) do
    Whelp.CategoryLookup[data.id] = data
end

-- Maximum values
Whelp.MAX_RATING = 5
Whelp.MIN_RATING = 1
Whelp.MAX_REVIEW_LENGTH = 500
Whelp.MAX_VENDOR_NAME_LENGTH = 50
Whelp.MAX_SERVICE_DESCRIPTION_LENGTH = 200
Whelp.REVIEWS_PER_PAGE = 10
Whelp.VENDORS_PER_PAGE = 20

-- UI dimensions
Whelp.UI = {
    MAIN_FRAME_WIDTH = 700,
    MAIN_FRAME_HEIGHT = 500,
    VENDOR_CARD_WIDTH = 320,
    VENDOR_CARD_HEIGHT = 100,
    DETAIL_FRAME_WIDTH = 400,
    DETAIL_FRAME_HEIGHT = 550,
    REVIEW_FORM_WIDTH = 350,
    REVIEW_FORM_HEIGHT = 300,
}

-- Textures
Whelp.Textures = {
    STAR_FILLED = "Interface\\AddOns\\Whelp\\Media\\star_filled",
    STAR_EMPTY = "Interface\\AddOns\\Whelp\\Media\\star_empty",
    STAR_HALF = "Interface\\AddOns\\Whelp\\Media\\star_half",
    LOGO = "Interface\\AddOns\\Whelp\\Media\\whelp_logo",
    -- Fallback to built-in textures if custom ones aren't available
    STAR_FILLED_FALLBACK = "Interface\\COMMON\\ReputationStar",
    STAR_EMPTY_FALLBACK = "Interface\\COMMON\\ReputationStar",
}

-- Default saved variables structure
Whelp.DefaultDB = {
    global = {
        vendors = {},           -- All vendor data
        reviews = {},           -- All reviews
        lastSyncTime = 0,       -- Last data sync timestamp
    },
    profile = {
        minimap = {
            hide = false,
            minimapPos = 225,
        },
        ui = {
            scale = 1.0,
            locked = false,
            position = {},
        },
        filters = {
            category = "all",
            minRating = 0,
            sortBy = "rating",  -- rating, recent, reviews
            showOnlyOnline = false,
        },
    },
}

Whelp.DefaultCharDB = {
    myReviews = {},             -- Reviews written by this character
    favorites = {},             -- Favorited vendors
    recentlyViewed = {},        -- Recently viewed vendors
    blockedVendors = {},        -- Vendors this character has blocked
}

-- Slash commands
Whelp.SlashCommands = {
    "whelp",
    "yelp",
}

-- Events to register
Whelp.Events = {
    "ADDON_LOADED",
    "PLAYER_LOGIN",
    "PLAYER_LOGOUT",
    "CHAT_MSG_WHISPER",
    "CHAT_MSG_CHANNEL",
    "PLAYER_TARGET_CHANGED",
}

-- Print formatted addon message
function Whelp:Print(msg)
    local prefix = "|cff" .. self.Colors.PRIMARY_HEX .. "Whelp|r: "
    DEFAULT_CHAT_FRAME:AddMessage(prefix .. msg)
end

-- Debug print (only when debug mode is enabled)
function Whelp:Debug(msg)
    if self.db and self.db.profile and self.db.profile.debug then
        local prefix = "|cff" .. self.Colors.PRIMARY_HEX .. "Whelp|r |cff888888[Debug]|r: "
        DEFAULT_CHAT_FRAME:AddMessage(prefix .. msg)
    end
end
