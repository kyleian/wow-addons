-- ============================================================
-- SlySlot.lua  —  Action bar profile manager
-- Save / load / export / import action bar layouts per character.
-- Replaces Myslot. /slyslot to toggle.
-- ============================================================

local ADDON_NAME    = "SlySlot"
local ADDON_VERSION = "1.0.0"
local NUM_SLOTS     = 120    -- covers all 10 action bars (10 × 12)

SlySlot = SlySlot or {}

local DB_DEFAULTS = {
    profiles = {},    -- [name] = serialized profile table
    position = { point = "CENTER", x = 200, y = 0 },
}

local function ApplyDefaults(dest, src)
    for k, v in pairs(src) do
        if dest[k] == nil then
            dest[k] = type(v) == "table" and {} or v
        end
        if type(v) == "table" and type(dest[k]) == "table" then
            ApplyDefaults(dest[k], v)
        end
    end
end

-- -------------------------------------------------------
-- Encode / decode helpers for export strings
-- Special chars:  ^ separates slots,  ; separates fields
-- We escape ^ → \1 and ; → \2 in user-provided strings
-- -------------------------------------------------------
local function Enc(s)
    s = tostring(s or "")
    return (s:gsub("%^", "\1"):gsub(";", "\2"))
end
local function Dec(s)
    s = tostring(s or "")
    return (s:gsub("\1", "^"):gsub("\2", ";"))
end

-- -------------------------------------------------------
-- FindOrCreateMacro(name, icon, body)  →  macroIndex
-- -------------------------------------------------------
local function FindOrCreateMacro(name, icon, body)
    local numGlobal, numChar = GetNumMacros()
    local total = numGlobal + numChar
    for i = 1, total do
        local mName = (GetMacroInfo(i))
        if mName == name then return i end
    end
    -- Not found — create it (global macro)
    local ok, idx = pcall(CreateMacro, name, icon or "INV_Misc_QuestionMark", body or "", false)
    if ok then return idx end
    return nil
end

-- -------------------------------------------------------
-- SlySlot_SaveProfile(name)
-- Captures current action bar state into a named profile.
-- -------------------------------------------------------
function SlySlot_SaveProfile(name)
    if not name or name == "" then return false, "Name is empty." end
    local db = SlySlot.db

    local slots = {}
    for s = 1, NUM_SLOTS do
        local aType, aId = GetActionInfo(s)
        if aType == "spell" then
            slots[s] = { type = "spell", id = aId }
        elseif aType == "item" then
            slots[s] = { type = "item", id = aId }
        elseif aType == "macro" then
            local mName, mIcon, mBody = GetMacroInfo(aId)
            slots[s] = {
                type    = "macro",
                id      = aId,
                mName   = mName or "",
                mIcon   = mIcon or "INV_Misc_QuestionMark",
                mBody   = mBody or "",
            }
        elseif aType == "companion" or aType == "flyout" then
            slots[s] = { type = aType, id = aId }
        end
    end

    db.profiles[name] = slots
    return true
end

-- -------------------------------------------------------
-- SlySlot_LoadProfile(name)
-- Restores a saved profile onto the action bars.
-- Must be called outside combat.
-- -------------------------------------------------------
function SlySlot_LoadProfile(name)
    if not name then return false, "No name given." end
    local profile = SlySlot.db.profiles[name]
    if not profile then return false, "Profile not found: " .. name end

    if UnitAffectingCombat("player") then
        return false, "Cannot change action bars in combat."
    end

    -- 1. Clear all slots we're about to fill
    ClearCursor()
    for s = 1, NUM_SLOTS do
        if profile[s] and HasAction(s) then
            PickupAction(s)
            ClearCursor()
        end
    end

    -- 2. Place saved actions
    ClearCursor()
    for s = 1, NUM_SLOTS do
        local entry = profile[s]
        if entry then
            local ok = false
            if entry.type == "spell" then
                pcall(PickupSpell, entry.id)
                ok = true
            elseif entry.type == "item" then
                pcall(PickupItem, entry.id)
                ok = true
            elseif entry.type == "macro" then
                local idx = FindOrCreateMacro(entry.mName, entry.mIcon, entry.mBody)
                if idx then
                    pcall(PickupMacro, idx)
                    ok = true
                end
            end
            if ok then
                PlaceAction(s)
                ClearCursor()
            end
        end
    end

    return true
end

-- -------------------------------------------------------
-- SlySlot_DeleteProfile(name)
-- -------------------------------------------------------
function SlySlot_DeleteProfile(name)
    SlySlot.db.profiles[name] = nil
end

-- -------------------------------------------------------
-- SlySlot_ExportProfile(name)  →  exportString
-- Format: SLYSLOT:v1:profileName^slotNum;type;id[;mName;mIcon;mBody]^...
-- -------------------------------------------------------
function SlySlot_ExportProfile(name)
    local profile = SlySlot.db.profiles[name]
    if not profile then return nil, "Profile not found." end

    local parts = { "SLYSLOT:v1:" .. Enc(name) }
    for s = 1, NUM_SLOTS do
        local e = profile[s]
        if e then
            if e.type == "macro" then
                table.insert(parts, table.concat({
                    s, "macro", Enc(e.mName), Enc(e.mIcon), Enc(e.mBody)
                }, ";"))
            else
                table.insert(parts, s .. ";" .. e.type .. ";" .. (e.id or 0))
            end
        end
    end
    return table.concat(parts, "^")
end

-- -------------------------------------------------------
-- SlySlot_ImportProfile(exportString)  →  profileName
-- Parses the export string and saves it as a new profile.
-- -------------------------------------------------------
function SlySlot_ImportProfile(str)
    if not str or str == "" then return nil, "Empty string." end

    -- Strip whitespace
    str = str:match("^%s*(.-)%s*$")

    if not str:match("^SLYSLOT:v1:") then
        return nil, "Not a valid SlySlot export string."
    end

    -- Split on ^
    local chunks = {}
    for chunk in str:gmatch("[^^]+") do
        table.insert(chunks, chunk)
    end

    -- First chunk: header with profile name
    local header = chunks[1]   -- "SLYSLOT:v1:profileName"
    local profileName = Dec(header:match("^SLYSLOT:v1:(.+)$") or "Imported")
    -- Ensure unique name
    local base = profileName
    local suffix = 1
    while SlySlot.db.profiles[profileName] do
        profileName = base .. "_" .. suffix
        suffix = suffix + 1
    end

    local slots = {}
    for i = 2, #chunks do
        local fields = {}
        for f in chunks[i]:gmatch("[^;]+") do
            table.insert(fields, f)
        end
        local slotNum = tonumber(fields[1])
        local aType   = fields[2]
        if slotNum and aType then
            if aType == "macro" then
                slots[slotNum] = {
                    type  = "macro",
                    mName = Dec(fields[3] or ""),
                    mIcon = Dec(fields[4] or "INV_Misc_QuestionMark"),
                    mBody = Dec(fields[5] or ""),
                }
            else
                slots[slotNum] = { type = aType, id = tonumber(fields[3]) or 0 }
            end
        end
    end

    SlySlot.db.profiles[profileName] = slots
    return profileName
end

-- -------------------------------------------------------
-- Events
-- -------------------------------------------------------
local ef = CreateFrame("Frame")
ef:RegisterEvent("ADDON_LOADED")

ef:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == ADDON_NAME then
        SlySlotDB = SlySlotDB or {}
        ApplyDefaults(SlySlotDB, DB_DEFAULTS)
        SlySlot.db = SlySlotDB

        SlySlot_BuildUI()

        if SlySuite_Register then
            SlySuite_Register(ADDON_NAME, ADDON_VERSION, function() end, {
                description = "Action bar profile manager — save/load/export/import.",
                slash       = "/slyslot",
                icon        = "Interface\\Icons\\Ability_Warrior_StrategicStrike",
            })
        end
    end
end)

-- -------------------------------------------------------
-- Slash commands
-- -------------------------------------------------------
SLASH_SLYSLOT1 = "/slyslot"
SlashCmdList["SLYSLOT"] = function(msg)
    msg = strtrim(msg or ""):lower()
    if msg == "" or msg == "toggle" then
        if SlySlotFrame then
            if SlySlotFrame:IsShown() then SlySlotFrame:Hide()
            else SlySlot_UIRefresh() ; SlySlotFrame:Show() end
        end
    elseif msg:sub(1, 5) == "save " then
        local name = strtrim(msg:sub(6))
        local ok, err = SlySlot_SaveProfile(name)
        if ok then print("|cff00ccff[SlySlot]|r Saved profile: |cffffcc00" .. name .. "|r")
        else   print("|cffff4444[SlySlot]|r " .. (err or "Unknown error")) end
    elseif msg:sub(1, 5) == "load " then
        local name = strtrim(msg:sub(6))
        local ok, err = SlySlot_LoadProfile(name)
        if ok then print("|cff00ccff[SlySlot]|r Loaded profile: |cffffcc00" .. name .. "|r")
        else   print("|cffff4444[SlySlot]|r " .. (err or "Unknown error")) end
    elseif msg == "list" then
        print("|cff00ccff[SlySlot]|r Profiles:")
        for name in pairs(SlySlot.db.profiles) do
            print("  |cffffcc00" .. name .. "|r")
        end
    elseif msg == "help" then
        print("|cff00ccff[SlySlot]|r Commands:")
        print("  |cffffcc00/slyslot|r              — toggle UI")
        print("  |cffffcc00/slyslot save <name>|r  — save current bars")
        print("  |cffffcc00/slyslot load <name>|r  — load a profile")
        print("  |cffffcc00/slyslot list|r          — list all profiles")
    end
end
