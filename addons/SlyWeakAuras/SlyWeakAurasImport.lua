-- ============================================================
-- Sly WeakAuras — SlyWeakAurasImport.lua
-- Bridge between our pack storage and the WeakAuras addon.
-- ALL imports go through WeakAuras' own Import() dialog so the
-- player explicitly confirms before any auras are added.
-- ============================================================

-- -------------------------------------------------------
-- WeakAuras detection
-- -------------------------------------------------------

function SlyWA_IsWeakAurasLoaded()
    return WeakAuras ~= nil and WeakAuras.GetData ~= nil
end

function SlyWA_GetWAVersion()
    if not SlyWA_IsWeakAurasLoaded() then return "not loaded" end
    -- WA exposes version through its options or constants
    if WeakAuras.versionString then return WeakAuras.versionString end
    if WeakAurasSaved and WeakAurasSaved.dbVersion then
        return "db v" .. tostring(WeakAurasSaved.dbVersion)
    end
    return "loaded (version unknown)"
end

-- Returns count of displays currently registered in WeakAurasSaved
function SlyWA_GetInstalledAuraCount()
    if not WeakAurasSaved or not WeakAurasSaved.displays then return 0 end
    local count = 0
    for _ in pairs(WeakAurasSaved.displays) do count = count + 1 end
    return count
end

-- -------------------------------------------------------
-- Pack validation
-- -------------------------------------------------------

-- WeakAuras export strings start with !WA:2! or the older !WA:1!
-- Returns "ok", "empty", or "invalid"
function SlyWA_ValidateAuraString(str)
    if not str or #str < 10 then return "empty" end
    local trimmed = strtrim(str)
    if trimmed:sub(1, 4) == "!WA:" then return "ok" end
    -- Some WA strings are raw base64 without the prefix (older format)
    if #trimmed > 20 then return "unknown_format" end
    return "invalid"
end

-- Rough estimate of how many auras are in a WA export string
-- by counting occurrences of the "id" key pattern in the raw compressed string.
-- Not precise — just a display hint.
function SlyWA_EstimateCount(str)
    if not str or #str < 10 then return 0 end
    local validity = SlyWA_ValidateAuraString(str)
    if validity == "empty" or validity == "invalid" then return 0 end
    -- Count header markers — very rough heuristic on raw string
    local count = 0
    for _ in str:gmatch('"id"') do count = count + 1 end
    if count == 0 then
        -- Compressed string: estimate from size (~300 bytes per aura heuristic)
        count = math.max(1, math.floor(#str / 300))
    end
    return count
end

-- -------------------------------------------------------
-- Import a pack into WeakAuras via its native Import dialog.
-- The player sees WA's own confirmation UI before any auras
-- are added — ToS compliant: player approves every import.
-- -------------------------------------------------------
function SlyWA_ImportPack(packName)
    local pack = SlyWA.db.packs[packName]
    if not pack then
        print("|cff00ccff[SlyWeakAuras]|r Pack |cffff4444" .. packName .. "|r not found.")
        return false
    end

    local validity = SlyWA_ValidateAuraString(pack.auraString)
    if validity == "empty" then
        print("|cff00ccff[SlyWeakAuras]|r Pack |cffffcc00" .. packName
            .. "|r has no aura data yet. Paste a WeakAuras export string first.")
        return false
    end
    if validity == "invalid" then
        print("|cff00ccff[SlyWeakAuras]|r Pack |cffff4444" .. packName
            .. "|r contains an invalid aura string (must start with !WA:).")
        return false
    end

    if not SlyWA_IsWeakAurasLoaded() then
        print("|cff00ccff[SlyWeakAuras]|r WeakAuras is not loaded. Enable it and /reload first.")
        return false
    end

    -- Use WeakAuras' own import pathway (shows WA's native import dialog)
    local ok, err = pcall(function()
        WeakAuras.Import(pack.auraString)
    end)

    if not ok then
        print("|cff00ccff[SlyWeakAuras]|r |cffff4444Import error for " .. packName .. ": " .. tostring(err) .. "|r")
        return false
    end

    -- Record the import attempt (WA dialog may still be cancelled by player)
    pack.lastImported = time()
    pack.importCount  = (pack.importCount or 0) + 1
    print("|cff00ccff[SlyWeakAuras]|r WeakAuras import dialog opened for |cffffcc00"
        .. packName .. "|r. Confirm in the WA window.")
    SlyWA_UIRefreshAll()
    return true
end

-- -------------------------------------------------------
-- Capture currently installed auras into a pack.
-- Scans WeakAurasSaved.displays for top-level groups matching
-- the filter, then exports them via the WA transmission module.
-- -------------------------------------------------------
function SlyWA_CapturePack(packName, filterPattern, description, source)
    if not SlyWA_IsWeakAurasLoaded() then
        print("|cff00ccff[SlyWeakAuras]|r WeakAuras is not loaded.")
        return false
    end
    if not WeakAurasSaved or not WeakAurasSaved.displays then
        print("|cff00ccff[SlyWeakAuras]|r No WeakAura displays found in SavedVariables.")
        return false
    end

    filterPattern = filterPattern or ""

    -- Collect matching top-level group/aura IDs
    local matched = {}
    for id, data in pairs(WeakAurasSaved.displays) do
        if filterPattern == "" or id:lower():find(filterPattern:lower(), 1, true) then
            -- Only export top-level items (parent == nil means top-level)
            if not data.parent or data.parent == "" then
                table.insert(matched, id)
            end
        end
    end

    if #matched == 0 then
        print("|cff00ccff[SlyWeakAuras]|r No auras matched filter: |cffffcc00"
            .. (filterPattern ~= "" and filterPattern or "(all top-level)") .. "|r")
        return false
    end

    -- Use WeakAuras' own export serialization if available
    -- WA 5.x Transmission module exposes table-to-string via WeakAuras.SerializeTable
    local auraString = ""
    local exportData = {}

    for _, id in ipairs(matched) do
        local data = WeakAuras.GetData(id)
        if data then
            exportData[id] = data
        end
    end

    -- Attempt to use WA's internal serialization (safest)
    local ok, result = pcall(function()
        if WeakAuras.SerializeDisplay then
            -- WA 5.x: `SerializeDisplay` creates a WA-format string for one display
            -- For groups we serialize the group + children together
            local parts = {}
            for _, id in ipairs(matched) do
                local s = WeakAuras.SerializeDisplay(id)
                if s then table.insert(parts, s) end
            end
            return table.concat(parts, "\n")
        end
        return nil
    end)

    if ok and result and #result > 10 then
        auraString = result
    else
        -- Fallback: store the display IDs as a manifest and instruct the user
        -- to export them manually from WA, then paste back here
        local manifest = "SLYWA_MANIFEST:1.0\n"
        for _, id in ipairs(matched) do
            manifest = manifest .. id .. "\n"
        end
        auraString = manifest
        print("|cff00ccff[SlyWeakAuras]|r WeakAuras serializer not available. "
            .. "Storing a manifest of " .. #matched .. " aura ID(s). "
            .. "Export them from WA and paste the string into the pack editor.")
    end

    -- Save / overwrite the pack
    SlyWA.db.packs[packName] = SlyWA_NewPackRecord(
        packName, auraString, source or "Captured via SlyWA",
        description or ("Captured: " .. (filterPattern ~= "" and filterPattern or "all top-level")),
        {}
    )
    SlyWA.db.packs[packName].estimatedCount = #matched

    print("|cff00ccff[SlyWeakAuras]|r Captured " .. #matched
        .. " aura(s) into pack |cffffcc00" .. packName .. "|r.")
    SlyWA_UIRefreshAll()
    return true
end

-- -------------------------------------------------------
-- Process any pending imports queued from a previous session
-- (only runs if options.autoImportOnLoad == true)
-- -------------------------------------------------------
function SlyWA_ProcessPendingImports()
    if not SlyWA.db.pendingImports then return end
    local count = 0
    for _, packName in ipairs(SlyWA.db.pendingImports) do
        SlyWA_ImportPack(packName)
        count = count + 1
    end
    SlyWA.db.pendingImports = {}
    if count > 0 then
        print("|cff00ccff[SlyWeakAuras]|r Auto-imported " .. count .. " pending pack(s).")
    end
end

-- -------------------------------------------------------
-- Queue a pack to be auto-imported next session
-- -------------------------------------------------------
function SlyWA_QueueImport(packName)
    if not SlyWA.db.pendingImports then SlyWA.db.pendingImports = {} end
    for _, n in ipairs(SlyWA.db.pendingImports) do
        if n == packName then return end  -- already queued
    end
    table.insert(SlyWA.db.pendingImports, packName)
    print("|cff00ccff[SlyWeakAuras]|r Pack |cffffcc00" .. packName
        .. "|r queued for import on next login.")
end

-- -------------------------------------------------------
-- Store / update a pack from a raw WA export string
-- (called from the in-game paste UI)
-- -------------------------------------------------------
function SlyWA_StorePack(packName, auraString, source, description, tags)
    if not packName or packName == "" then
        print("|cff00ccff[SlyWeakAuras]|r Pack name required.")
        return false
    end
    local validity = SlyWA_ValidateAuraString(auraString)
    if validity == "invalid" then
        print("|cff00ccff[SlyWeakAuras]|r Invalid aura string — must start with !WA: .")
        return false
    end

    local existing = SlyWA.db.packs[packName]
    if existing then
        -- Update in place, preserve import history
        existing.auraString      = auraString or existing.auraString
        existing.source          = source or existing.source
        existing.description     = description or existing.description
        existing.tags            = tags or existing.tags
        existing.estimatedCount  = nil  -- will be recalculated
    else
        SlyWA.db.packs[packName] = SlyWA_NewPackRecord(
            packName, auraString, source, description, tags)
    end

    print("|cff00ccff[SlyWeakAuras]|r Pack |cffffcc00" .. packName
        .. "|r " .. (existing and "updated" or "added") .. ".")
    SlyWA_UIRefreshAll()
    return true
end

-- -------------------------------------------------------
-- Delete a pack
-- -------------------------------------------------------
function SlyWA_DeletePack(packName)
    if not SlyWA.db.packs[packName] then
        print("|cff00ccff[SlyWeakAuras]|r Pack not found: " .. packName)
        return false
    end
    SlyWA.db.packs[packName] = nil
    print("|cff00ccff[SlyWeakAuras]|r Pack |cffffcc00" .. packName .. "|r deleted.")
    SlyWA_UIRefreshAll()
    return true
end

-- -------------------------------------------------------
-- Get sorted pack name list
-- -------------------------------------------------------
function SlyWA_GetPackNames()
    local names = {}
    for name in pairs(SlyWA.db.packs) do table.insert(names, name) end
    table.sort(names)
    return names
end

-- -------------------------------------------------------
-- Tag helpers
-- -------------------------------------------------------
function SlyWA_GetTagString(pack)
    if not pack or not pack.tags or #pack.tags == 0 then return "" end
    return table.concat(pack.tags, "  ")
end
