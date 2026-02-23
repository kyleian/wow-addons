-- ============================================================
-- Sly Suite — SlySuite.lua
-- Top-level addon manager and error sandbox for the Sly addon family.
-- Sub-mods register via SlySuite_Register(); all init calls are
-- wrapped in xpcall so one broken mod can't crash the whole suite.
-- ToS: UI only. No automation. No external calls.
-- ============================================================

local ADDON_NAME    = "SlySuite"
local ADDON_VERSION = "1.0.0"

-- Public namespace
SS = SS or {}
SS.version  = ADDON_VERSION
SS.registry = {}   -- ordered list preserving registration sequence
SS.index    = {}   -- [name] = registry entry (same table reference)
SS.ready    = false

-- Sub-mod status constants
SS.STATUS = {
    OK       = "OK",
    ERROR    = "ERROR",
    DISABLED = "DISABLED",
    LOADING  = "LOADING",
}

-- -------------------------------------------------------
-- Default saved variables structure
-- -------------------------------------------------------
local DB_DEFAULTS = {
    subMods  = {},   -- [name] = { enabled=true, lastError=nil, lastErrorTime=nil }
    position = { point="CENTER", x=0, y=200 },
    options  = {
        showOnLoad     = false,   -- auto-open panel on login
        showLoadPrint  = true,    -- print summary line on load
    },
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
-- Error handler — appends a trimmed stack trace
-- -------------------------------------------------------
local function SS_ErrorHandler(err)
    local stack = debugstack(2, 10, 3)
    return tostring(err) .. "\n" .. tostring(stack)
end

-- -------------------------------------------------------
-- SS_CallSafe(entry, fn)
-- Runs fn() inside xpcall, records result on entry.
-- Returns true on success.
-- -------------------------------------------------------
local function SS_CallSafe(entry, fn)
    entry.status = SS.STATUS.LOADING
    local ok, err = xpcall(fn, SS_ErrorHandler)
    if ok then
        entry.status            = SS.STATUS.OK
        entry.lastError         = nil
        if SS.db and SS.db.subMods[entry.name] then
            SS.db.subMods[entry.name].lastError     = nil
            SS.db.subMods[entry.name].lastErrorTime = nil
        end
        return true
    else
        entry.status            = SS.STATUS.ERROR
        entry.lastError         = err
        entry.lastErrorTime     = time()
        if SS.db and SS.db.subMods[entry.name] then
            SS.db.subMods[entry.name].lastError     = err
            SS.db.subMods[entry.name].lastErrorTime = entry.lastErrorTime
        end
        print("|cffff4444[Sly Suite]|r ERROR in |cffffcc00"
            .. entry.name .. "|r — use |cffffcc00/sly|r to view details.")
        return false
    end
end

-- -------------------------------------------------------
-- SS_InitEntry(entry)
-- Called when a sub-mod should be (re-)initialized.
-- Skipped if disabled.
-- -------------------------------------------------------
local function SS_InitEntry(entry)
    if entry.status == SS.STATUS.DISABLED then return end
    SS_CallSafe(entry, entry.initFn)
    -- Refresh UI row if panel exists
    if SS_UIRefreshRow then SS_UIRefreshRow(entry.name) end
end

-- -------------------------------------------------------
-- SlySuite_Register(name, version, initFn, options)
-- Public API — called by sub-mods to join the suite.
--
--   name    : string  — unique addon name
--   version : string  — version string for display
--   initFn  : function — called (once) to initialize the sub-mod
--   options : table (optional)
--     .description : string — one-line description
--     .slash       : string — primary slash command, e.g. "/estats"
--     .icon        : string — texture path for icon
-- -------------------------------------------------------
function SlySuite_Register(name, version, initFn, options)
    if not name or not initFn then
        print("|cffff4444[Sly Suite]|r SlySuite_Register: name and initFn are required.")
        return
    end

    if SS.index[name] then
        print("|cff00ccff[Sly Suite]|r Sub-mod |cffffcc00" .. name
            .. "|r re-registered (replacing previous entry).")
    end

    options = options or {}

    -- Retrieve or create the persisted sub-mod record
    local dbRecord
    if SS.db then
        SS.db.subMods[name] = SS.db.subMods[name] or {}
        ApplyDefaults(SS.db.subMods[name], { enabled=true, lastError=nil, lastErrorTime=nil })
        dbRecord = SS.db.subMods[name]
    else
        dbRecord = { enabled=true, lastError=nil, lastErrorTime=nil }
    end

    local entry = {
        name        = name,
        version     = version or "?",
        initFn      = initFn,
        description = options.description or "",
        slash       = options.slash or "",
        icon        = options.icon or "Interface\\Icons\\INV_Misc_QuestionMark",
        status      = dbRecord.enabled and SS.STATUS.LOADING or SS.STATUS.DISABLED,
        lastError   = dbRecord.lastError,
        lastErrorTime = dbRecord.lastErrorTime,
        dbRecord    = dbRecord,
    }

    -- Remove old entry from ordered list if re-registering
    if SS.index[name] then
        for i, e in ipairs(SS.registry) do
            if e.name == name then table.remove(SS.registry, i); break end
        end
    end

    table.insert(SS.registry, entry)
    SS.index[name] = entry

    -- Immediately init if suite is ready and mod is enabled
    if SS.ready then
        if dbRecord.enabled then
            SS_InitEntry(entry)
        end
        if SS_UIRefreshAll then SS_UIRefreshAll() end
    end
end

-- -------------------------------------------------------
-- SS_EnableSubMod(name)   /  SS_DisableSubMod(name)
-- Called from the UI toggle buttons.
-- -------------------------------------------------------
function SS_EnableSubMod(name)
    local entry = SS.index[name]
    if not entry then return end

    entry.dbRecord.enabled = true
    entry.status = SS.STATUS.LOADING

    -- Re-run init so the mod activates immediately  
    SS_InitEntry(entry)
    if SS_UIRefreshAll then SS_UIRefreshAll() end
end

function SS_DisableSubMod(name)
    local entry = SS.index[name]
    if not entry then return end

    entry.dbRecord.enabled = false
    entry.status = SS.STATUS.DISABLED
    if SS_UIRefreshAll then SS_UIRefreshAll() end

    print("|cff00ccff[Sly Suite]|r |cffffcc00" .. name
        .. "|r disabled. Type |cffffcc00/reload|r to fully unload.")
end

-- -------------------------------------------------------
-- SS_RetrySubMod(name)
-- Attempts to re-run the init function for an errored mod.
-- -------------------------------------------------------
function SS_RetrySubMod(name)
    local entry = SS.index[name]
    if not entry then return end
    if not entry.dbRecord.enabled then
        print("|cff00ccff[Sly Suite]|r Enable |cffffcc00" .. name .. "|r first.")
        return
    end
    print("|cff00ccff[Sly Suite]|r Retrying |cffffcc00" .. name .. "|r...")
    SS_InitEntry(entry)
    if SS_UIRefreshAll then SS_UIRefreshAll() end
end

-- -------------------------------------------------------
-- Events
-- -------------------------------------------------------
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGOUT")

eventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local name = ...
        if name == ADDON_NAME then
            -- Init saved variables
            SlySuiteDB = SlySuiteDB or {}
            ApplyDefaults(SlySuiteDB, DB_DEFAULTS)
            SS.db = SlySuiteDB

            -- Back-fill dbRecord references for any early registrations
            for _, entry in ipairs(SS.registry) do
                SS.db.subMods[entry.name] = SS.db.subMods[entry.name] or {}
                ApplyDefaults(SS.db.subMods[entry.name],
                    { enabled=true, lastError=nil, lastErrorTime=nil })
                entry.dbRecord = SS.db.subMods[entry.name]
            end

            SS.ready = true

            -- Build the UI panel
            SS_BuildUI()

            -- Init any mods that registered before ADDON_LOADED fired (edge case)
            for _, entry in ipairs(SS.registry) do
                if entry.dbRecord.enabled then
                    SS_InitEntry(entry)
                else
                    entry.status = SS.STATUS.DISABLED
                end
            end

            SS_UIRefreshAll()

            if SS.db.options.showLoadPrint then
                local total    = #SS.registry
                local enabled  = 0
                for _, e in ipairs(SS.registry) do
                    if e.status ~= SS.STATUS.DISABLED then enabled = enabled + 1 end
                end
                print("|cff00ccff[Sly Suite]|r v" .. ADDON_VERSION
                    .. " — " .. enabled .. "/" .. total .. " sub-mod(s) active."
                    .. "  |cffffcc00/sly|r to manage.")
            end

            if SS.db.options.showOnLoad then
                SlyFrame:Show()
            end
        end

    elseif event == "PLAYER_LOGOUT" then
        if SlyFrame then
            local point, _, _, x, y = SlyFrame:GetPoint()
            if point then
                SS.db.position = { point=point, x=x or 0, y=y or 0 }
            end
        end
    end
end)

-- -------------------------------------------------------
-- Slash commands
-- -------------------------------------------------------
SLASH_SLYSUITE1 = "/sly"
SLASH_SLYSUITE2 = "/slysuite"
SlashCmdList["SLYSUITE"] = function(msg)
    msg = strtrim(msg):lower()

    if msg == "" or msg == "toggle" then
        if SlyFrame then
            if SlyFrame:IsShown() then SlyFrame:Hide()
            else SS_UIRefreshAll(); SlyFrame:Show() end
        end

    elseif msg == "status" then
        print("|cff00ccff[Sly Suite]|r Sub-mod status:")
        for _, entry in ipairs(SS.registry) do
            local color = entry.status == SS.STATUS.OK       and "|cff44ff44"
                       or entry.status == SS.STATUS.ERROR    and "|cffff4444"
                       or entry.status == SS.STATUS.DISABLED and "|cffaaaaaa"
                       or "|cffffcc00"
            print("  " .. color .. entry.name .. "|r "
                .. entry.version .. " — " .. entry.status)
        end

    elseif msg:sub(1, 6) == "retry " then
        SS_RetrySubMod(strtrim(msg:sub(7)))

    elseif msg == "help" then
        print("|cff00ccff[Sly Suite]|r Commands:")
        print("  |cffffcc00/sly|r               — toggle the manager panel")
        print("  |cffffcc00/sly status|r         — print all sub-mod statuses")
        print("  |cffffcc00/sly retry <name>|r   — retry an errored sub-mod")
        print("  |cffffcc00/sly help|r            — this text")
    end
end
