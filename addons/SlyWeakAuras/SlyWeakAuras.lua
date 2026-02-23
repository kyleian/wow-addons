-- ============================================================
-- Sly WeakAuras — SlyWeakAuras.lua
-- Core init, SavedVariables, and SlySuite registration.
-- Bridges the Sly Suite to the WeakAuras (TBC) addon for
-- managing named packs of aura export strings.
-- ToS: UI management only. Uses WeakAuras' own import dialog.
--      No automation. No packet injection. No external calls.
-- ============================================================

local ADDON_NAME    = "SlyWeakAuras"
local ADDON_VERSION = "1.0.0"

SlyWA = SlyWA or {}
SlyWA.version = ADDON_VERSION

-- -------------------------------------------------------
-- Default saved variables
-- -------------------------------------------------------
local DB_DEFAULTS = {
    -- Stored packs: [packName] = { ...fields }
    packs    = {},
    -- Any WA export strings queued for import on next session
    pendingImports = {},
    position = { point="CENTER", x=200, y=0 },
    options  = {
        autoImportOnLoad = false,   -- import pending on login (disabled by default)
        confirmDelete   = true,
        showSourceBadge = true,
    },
}

-- Template for a new pack record
function SlyWA_NewPackRecord(name, auraString, source, description, tags)
    return {
        name        = name or "Unnamed Pack",
        auraString  = auraString or "",
        source      = source or "Unknown",
        description = description or "",
        tags        = tags or {},
        addedDate   = time(),
        lastImported = nil,
        importCount  = 0,
        -- Populated lazily by SlyWA_EstimateCount()
        estimatedCount = nil,
    }
end

-- -------------------------------------------------------
-- Default packs shipped with the addon
-- (These are empty placeholders until Yabba exports his auras)
-- To populate: in-game /slywa -> "Add Pack", paste WA export string
-- -------------------------------------------------------
local BUILTIN_PACK_STUBS = {
    {
        name        = "Foji — Core",
        source      = "Yabba / FojjiCore v1.6.7",
        description = "Core Foji suite auras (all classes). Export from Yabba's WA and paste here.",
        tags        = {"foji","core"},
        auraString  = "",   -- populated by user via in-game paste
    },
    {
        name        = "Foji — Rogue",
        source      = "Yabba / FojjiCore v1.6.7",
        description = "Foji rogue-specific WeakAuras. Export from Yabba's WA and paste here.",
        tags        = {"foji","rogue","class"},
        auraString  = "",
    },
    {
        name        = "Foji — Hunter",
        source      = "Yabba / FojjiCore v1.6.7",
        description = "Foji hunter-specific WeakAuras. Export from Yabba's WA and paste here.",
        tags        = {"foji","hunter","class"},
        auraString  = "",
    },
}

-- Apply defaults non-destructively
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

-- Seed builtin stubs if not already present
local function SeedBuiltinStubs()
    for _, stub in ipairs(BUILTIN_PACK_STUBS) do
        if not SlyWA.db.packs[stub.name] then
            SlyWA.db.packs[stub.name] = SlyWA_NewPackRecord(
                stub.name, stub.auraString, stub.source,
                stub.description, stub.tags)
        end
    end
end

-- -------------------------------------------------------
-- Init (called by SlySuite or standalone ADDON_LOADED)
-- -------------------------------------------------------
function SlyWA_Init()
    SlyWA_BuildUI()

    -- Check WA immediately and report
    if SlyWA_IsWeakAurasLoaded() then
        local ver = SlyWA_GetWAVersion()
        if SlyWA.db.options.autoImportOnLoad then
            SlyWA_ProcessPendingImports()
        end
    end
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
            SlyWeakAurasDB = SlyWeakAurasDB or {}
            ApplyDefaults(SlyWeakAurasDB, DB_DEFAULTS)
            SlyWA.db = SlyWeakAurasDB
            SeedBuiltinStubs()

            if SlySuite_Register then
                SlySuite_Register(
                    "SlyWeakAuras",
                    ADDON_VERSION,
                    function() SlyWA_Init() end,
                    {
                        description = "WeakAura pack manager. Import/capture Foji & custom aura sets.",
                        slash       = "/slywa",
                        icon        = "Interface\\Icons\\Spell_Holy_MindVision",
                    }
                )
            else
                SlyWA_Init()
                print("|cff00ccff[SlyWeakAuras]|r v" .. ADDON_VERSION
                    .. " loaded.  |cffffcc00/slywa|r to open.")
            end

        elseif name == "WeakAuras" then
            -- WA finished loading after us; refresh the status panel if open
            if SlyWAFrame and SlyWAFrame:IsShown() then
                SlyWA_UIRefreshStatus()
            end
        end

    elseif event == "PLAYER_LOGOUT" then
        if SlyWAFrame then
            local point, _, _, x, y = SlyWAFrame:GetPoint()
            if point then
                SlyWA.db.position = { point=point, x=x or 0, y=y or 0 }
            end
        end
    end
end)

-- -------------------------------------------------------
-- Slash commands
-- -------------------------------------------------------
SLASH_SLYWEAKAURAS1 = "/slywa"
SLASH_SLYWEAKAURAS2 = "/slyweakauras"
SlashCmdList["SLYWEAKAURAS"] = function(msg)
    msg = strtrim(msg):lower()
    if msg == "" or msg == "toggle" then
        if SlyWAFrame then
            if SlyWAFrame:IsShown() then SlyWAFrame:Hide()
            else SlyWA_UIRefreshAll(); SlyWAFrame:Show() end
        end
    elseif msg == "status" then
        if SlyWA_IsWeakAurasLoaded() then
            print("|cff00ccff[SlyWeakAuras]|r WeakAuras |cff44ff44ACTIVE|r — "
                .. SlyWA_GetWAVersion())
        else
            print("|cff00ccff[SlyWeakAuras]|r WeakAuras |cffff4444NOT LOADED|r")
        end
        local count = 0
        for _ in pairs(SlyWA.db.packs) do count = count + 1 end
        print("|cff00ccff[SlyWeakAuras]|r " .. count .. " pack(s) stored.")
    elseif msg == "packs" then
        print("|cff00ccff[SlyWeakAuras]|r Stored packs:")
        for name, pack in pairs(SlyWA.db.packs) do
            local hasStr = pack.auraString and #pack.auraString > 10
            local flag   = hasStr and "|cff44ff44[has data]|r" or "|cffff4444[empty]|r"
            print("  " .. flag .. " " .. name
                .. (pack.lastImported and "  last imported: "
                    .. date("%Y-%m-%d", pack.lastImported) or ""))
        end
    elseif msg == "help" then
        print("|cff00ccff[SlyWeakAuras]|r Commands:")
        print("  |cffffcc00/slywa|r           — toggle the pack manager")
        print("  |cffffcc00/slywa status|r    — WeakAuras connection + pack count")
        print("  |cffffcc00/slywa packs|r     — list all stored packs")
        print("  |cffffcc00/slywa help|r       — this text")
    end
end
