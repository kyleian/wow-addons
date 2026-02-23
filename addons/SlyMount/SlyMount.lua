-- SlyMount.lua
-- Favorite mount manager with zone-aware random pick.
-- /slymount [random|add <name>|remove <name>|list]

local ADDON_NAME    = "SlyMount"
local ADDON_VERSION = "1.0.0"

SlyMount = {}
local SM = SlyMount

-- ── Defaults ─────────────────────────────────────────────────────────────────
local DB_DEFAULTS = {
    ground   = {},  -- list of ground mount spell names
    flying   = {},  -- list of flying mount spell names
    position = { point = "CENTER", x = -200, y = 0 },
}

local function ApplyDefaults(saved, defaults)
    for k, v in pairs(defaults) do
        if saved[k] == nil then
            if type(v) == "table" then saved[k] = {}; ApplyDefaults(saved[k], v)
            else saved[k] = v end
        end
    end
end

-- ── Zone detection ────────────────────────────────────────────────────────────
-- Flying is only available in Outland (TBC). Check zone name.
local OUTLAND_ZONES = {
    ["Hellfire Peninsula"]   = true,
    ["Zangarmarsh"]          = true,
    ["Terokkar Forest"]      = true,
    ["Nagrand"]              = true,
    ["Blade's Edge Mountains"] = true,
    ["Netherstorm"]          = true,
    ["Shadowmoon Valley"]    = true,
    ["Shattrath City"]       = true,
    ["The Botanica"]         = true,
    ["The Mechanar"]         = true,
    ["The Arcatraz"]         = true,
    ["Tempest Keep"]         = true,
    ["Caverns of Time"]      = false,  -- Outland map but actually a different zone system
}

function SM:InOutland()
    local zone = GetRealZoneText()
    return OUTLAND_ZONES[zone] == true
end

function SM:CanMount()
    if IsMounted() then return false, "already mounted" end
    -- Check combat, falling, swimming etc.
    if UnitIsDeadOrGhost("player") then return false, "dead" end
    return true, nil
end

-- ── Favorites management ──────────────────────────────────────────────────────
function SM:AddMount(mountType, name)
    name = name:match("^%s*(.-)%s*$")  -- trim
    if name == "" then SM:Print("Usage: /slymount add ground|flying <Spell Name>"); return end
    local list = SlyMountDB[mountType]
    for _, v in ipairs(list) do
        if v:lower() == name:lower() then SM:Print(name .. " already in " .. mountType .. " list."); return end
    end
    table.insert(list, name)
    SM:Print("Added to " .. mountType .. ": " .. name)
    if SM.uiRefresh then SM.uiRefresh() end
end

function SM:RemoveMount(mountType, name)
    name = name:lower():match("^%s*(.-)%s*$")
    local list = SlyMountDB[mountType]
    for i, v in ipairs(list) do
        if v:lower() == name then
            table.remove(list, i)
            SM:Print("Removed from " .. mountType .. ": " .. v)
            if SM.uiRefresh then SM.uiRefresh() end
            return
        end
    end
    SM:Print("Not found in " .. mountType .. " list: " .. name)
end

-- ── Mount casting ─────────────────────────────────────────────────────────────
function SM:CastMount(spellName)
    local ok, reason = SM:CanMount()
    if not ok then SM:Print("Cannot mount: " .. reason); return end
    CastSpellByName(spellName)
end

function SM:RandomMount()
    local ok, reason = SM:CanMount()
    if not ok then SM:Print("Cannot mount: " .. reason); return end

    local pool = {}
    if SM:InOutland() and #SlyMountDB.flying > 0 then
        -- Prefer flying in Outland
        for _, v in ipairs(SlyMountDB.flying) do pool[#pool+1] = v end
    else
        for _, v in ipairs(SlyMountDB.ground) do pool[#pool+1] = v end
        -- Also include flying mounts as ground-capable in Outland when no flying exists
        if SM:InOutland() then
            for _, v in ipairs(SlyMountDB.flying) do pool[#pool+1] = v end
        end
    end

    if #pool == 0 then
        SM:Print("No favorite mounts configured! Use /slymount add ground|flying <Spell Name>")
        return
    end

    local pick = pool[math.random(1, #pool)]
    SM:Print("Mounting: " .. pick .. (SM:InOutland() and " (Outland)" or " (Azeroth)"))
    CastSpellByName(pick)
end

-- ── Print ─────────────────────────────────────────────────────────────────────
function SM:Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cffa335ee[SlyMount]|r " .. msg)
end

-- ── Init ──────────────────────────────────────────────────────────────────────
function SM:Init()
    SlyMountDB = SlyMountDB or {}
    ApplyDefaults(SlyMountDB, DB_DEFAULTS)

    SLASH_SLYMOUNT1 = "/slymount"
    SLASH_SLYMOUNT2 = "/slymt"
    SlashCmdList["SLYMOUNT"] = function(raw)
        local cmd, rest = (raw or ""):match("^%s*(%S*)%s*(.*)")
        cmd = (cmd or ""):lower()
        if cmd == "" then
            if SlyMountPanel and SlyMountPanel:IsShown() then SlyMountPanel:Hide()
            else if SM_BuildUI then SM_BuildUI() end end
        elseif cmd == "random" or cmd == "r" then
            SM:RandomMount()
        elseif cmd == "add" then
            local mountType, name = rest:match("^(%S+)%s+(.*)")
            mountType = (mountType or ""):lower()
            if mountType ~= "ground" and mountType ~= "flying" then
                SM:Print("Usage: /slymount add ground|flying <Spell Name>")
            else
                SM:AddMount(mountType, name or "")
            end
        elseif cmd == "remove" or cmd == "rm" then
            local mountType, name = rest:match("^(%S+)%s+(.*)")
            mountType = (mountType or ""):lower()
            if mountType ~= "ground" and mountType ~= "flying" then
                SM:Print("Usage: /slymount remove ground|flying <Spell Name>")
            else
                SM:RemoveMount(mountType, name or "")
            end
        elseif cmd == "list" then
            SM:Print("Ground: " .. (#SlyMountDB.ground > 0 and table.concat(SlyMountDB.ground, ", ") or "(none)"))
            SM:Print("Flying: " .. (#SlyMountDB.flying > 0 and table.concat(SlyMountDB.flying, ", ") or "(none)"))
        else
            SM:Print("Commands: /slymount [random | add ground|flying <Name> | remove ground|flying <Name> | list]")
        end
    end
end

-- ── Boot ──────────────────────────────────────────────────────────────────────
local boot = CreateFrame("Frame")
boot:RegisterEvent("ADDON_LOADED")
boot:SetScript("OnEvent", function(self, event, name)
    if name ~= ADDON_NAME then return end
    self:UnregisterEvent("ADDON_LOADED")
    if SlySuite_Register then
        SlySuite_Register(ADDON_NAME, ADDON_VERSION, function() SM:Init() end, {
            description = "Favorite mounts with zone-aware random pick (ground/flying).",
            slash       = "/slymount",
            icon        = "Interface\\Icons\\Ability_Mount_RidingHorse",
        })
    else
        SM:Init()
    end
end)
