-- Luacheck configuration for Whelp addon

-- Standard globals
std = "lua51"

-- WoW API globals
globals = {
    -- Whelp addon globals
    "Whelp",
    "WhelpDB",
    "WhelpCharDB",
    "Whelp_Toggle",
    "Whelp_Search",
    "WhelpMainFrame",
    "WhelpVendorDetailFrame",
    "WhelpReviewFormFrame",
    "WhelpSearchBar",
    "WhelpSearchResults",
    "WhelpEventFrame",
    "WhelpMinimapMenu",

    -- Binding globals
    "BINDING_HEADER_WHELP",
    "BINDING_NAME_WHELP_TOGGLE",
    "BINDING_NAME_WHELP_SEARCH",
}

read_globals = {
    -- Lua globals
    "table", "string", "math", "pairs", "ipairs", "next", "type",
    "tostring", "tonumber", "select", "unpack", "setmetatable",
    "getmetatable", "rawget", "rawset", "pcall", "error", "assert",
    "print", "date", "time", "strsplit", "strmatch", "format",
    "tinsert", "tremove", "wipe",

    -- WoW API - Frames
    "CreateFrame",
    "UIParent",
    "GameTooltip",
    "Minimap",
    "DEFAULT_CHAT_FRAME",
    "UISpecialFrames",
    "StaticPopup_Show",
    "StaticPopupDialogs",
    "EasyMenu",

    -- WoW API - Unit functions
    "UnitName",
    "UnitExists",
    "UnitIsPlayer",
    "UnitFactionGroup",

    -- WoW API - Player/Realm
    "GetRealmName",
    "GetCursorPosition",
    "GetMinimapShape",
    "IsShiftKeyDown",
    "IsControlKeyDown",
    "IsAltKeyDown",

    -- WoW API - Friends
    "C_FriendList",

    -- WoW API - Dropdown
    "UIDropDownMenu_Initialize",
    "UIDropDownMenu_CreateInfo",
    "UIDropDownMenu_AddButton",
    "UIDropDownMenu_SetWidth",
    "UIDropDownMenu_SetSelectedValue",
    "UIDropDownMenu_GetSelectedValue",
    "UIDropDownMenu_SetText",

    -- WoW API - Slash commands
    "SlashCmdList",
    "SLASH_WHELP1",
    "SLASH_WHELP2",

    -- Libraries
    "LibStub",
}

-- Ignore certain warnings
ignore = {
    "212", -- Unused argument
    "213", -- Unused loop variable
    "542", -- Empty if branch
}

-- Maximum line length
max_line_length = 150

-- Exclude external libraries from linting
exclude_files = {
    "Libs/**/*.lua",
    ".luacheckrc",
}
