-- ============================================================
-- SlyChar.lua  (full rewrite â€” movable character sheet)
-- â€¢ Intercepts C key: hides CharacterFrame, shows our panel
-- â€¢ SC_BuildMain() builds a full equipped-gear + model panel
-- â€¢ Stats tab (base stats + ECS extended) + Sets tab (IRR)
-- ============================================================

SC  = SC  or {}
SC.version = "2.0.0"
local ADDON_NAME = "SlySuite_Char"

-- Flags shared with SlyCharUI.lua (same global table, different file)
SC._skipHook        = false   -- true while Chr button is showing CharacterFrame directly
SC._pendingHideChar = false   -- true when CharacterFrame was left open in combat
SC._hiddenByCombat  = false   -- true when we suppressed the panel at combat start
SC._pendingBuild    = false   -- true when SC_BuildMain() was blocked by combat lockdown

-- --------------------------------------------------------
-- SavedVariables defaults
-- --------------------------------------------------------
local DB_DEFAULTS = {
    position  = nil,     -- {point, x, y} for SlyCharMainFrame
    lastTab   = "stats",
    theme     = "shadow",
    mode      = "slychar_flyout",  -- "native_flyout" | "slychar" | "slychar_flyout"
    collapsed = {},      -- {[sectionKey]=true} for collapsed stat sections
    hidden    = {},      -- {[sectionKey]=true} for fully hidden stat sections
}

SC.db = {}

-- --------------------------------------------------------
-- Helpers
-- --------------------------------------------------------
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

-- --------------------------------------------------------
-- Show / Toggle our main panel
-- --------------------------------------------------------
function SC_ShowMain()
    if not SlyCharMainFrame then
        if InCombatLockdown() then
            DEFAULT_CHAT_FRAME:AddMessage("|cff88bbff[SlyChar]|r Open the character sheet once out of combat first.")
            return
        end
        local ok, err = pcall(SC_BuildMain)
        if not ok then
            DEFAULT_CHAT_FRAME:AddMessage("|cffff4444[SlyChar] Build error:|r " .. tostring(err))
            return
        end
    end
    -- Re-anchor wing to main frame in case it was displaced by native_flyout mode
    if SC_ReparentWing then SC_ReparentWing(SlyCharMainFrame) end
    local pos = SC.db.position
    if pos and pos.point then
        SlyCharMainFrame:ClearAllPoints()
        SlyCharMainFrame:SetPoint(pos.point, UIParent, pos.point, pos.x or 0, pos.y or 0)
    end
    SlyCharMainFrame:Show()
    SlyCharMainFrame:SetAlpha(1)
    -- Close the >> flyout menu if it was left open.
    local fm = _G["SlyCharStripFlyout"]
    if fm then fm:Hide() end
    SC_RefreshAll()
    -- Restore the active tab (and in slychar_flyout mode, open its wing).
    -- SC_SwitchTab handles both: tab-frame visibility for slychar mode, and
    -- wing auto-open for slychar_flyout mode.
    if SC_SwitchTab then
        SC_SwitchTab(SC.db.lastTab or "stats")
    end
end

function SC_ToggleMain()
    if SlyCharMainFrame and SlyCharMainFrame:IsShown() then
        SlyCharMainFrame:Hide()
    else
        SC_ShowMain()
    end
end

-- --------------------------------------------------------
-- Hook CharacterFrame: C key -> suppress default, use ours
-- The C keybinding fires ShowUIPanel(CharacterFrame).
-- HookScript on OnShow immediately hides it and toggles ours.
-- Since CharacterFrame is always instantly hidden,
-- ToggleCharacter() always thinks it's closed and calls Show --
-- so we toggle based on our own panel state.
-- --------------------------------------------------------
local function HookCharacterFrame()
    if not CharacterFrame then return end

    CharacterFrame:HookScript("OnShow", function(self)
        local mode = (SC.db and SC.db.mode) or "native_flyout"

        if mode == "native_flyout" then
            -- Let native CharacterFrame show; attach our companion alongside it
            if SC_ShowNativeCompanion then SC_ShowNativeCompanion() end
            return
        end

        -- slychar / slychar_flyout: intercept and redirect to SlyChar panel
        if SC._skipHook then return end
        if GetCursorInfo() then return end

        if InCombatLockdown() then
            if SlyCharMainFrame then
                self:Hide()
                SlyCharMainFrame:Show()
                SlyCharMainFrame:SetAlpha(1)
                SC_RefreshAll()
            else
                SC._pendingBuild = true
                DEFAULT_CHAT_FRAME:AddMessage(
                    "|cff88bbff[SlyChar]|r Opening after combat ends...")
            end
            return
        end
        self:Hide()
        SC_ToggleMain()
    end)

    -- In native_flyout mode: hide companion when CharacterFrame closes
    CharacterFrame:HookScript("OnHide", function(self)
        if (SC.db and SC.db.mode) == "native_flyout" then
            if SC_HideNativeCompanion then SC_HideNativeCompanion() end
        end
    end)
end

-- --------------------------------------------------------
-- Slash commands
-- --------------------------------------------------------
local function SC_Slash(msg)
    msg = (msg or ""):lower():trim()
    if msg == "reset" then
        SC.db.position = nil
        if SlyCharMainFrame then
            SlyCharMainFrame:ClearAllPoints()
            SlyCharMainFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        end
        DEFAULT_CHAT_FRAME:AddMessage("|cff88bbff[SlyChar]|r Position reset.")
    elseif msg == "stats reset" then
        if SC.db then SC.db.hidden = {} ; SC.db.collapsed = {} end
        if SC_RefreshStats then SC_RefreshStats() end
        DEFAULT_CHAT_FRAME:AddMessage("|cff88bbff[SlyChar]|r Stats sections reset.")
    elseif msg == "stats" then
        SC_ShowMain()
        SC_SwitchTab("stats")
    elseif msg == "sets" then
        SC_ShowMain()
        if SC_SetSetsSubTab then SC_SetSetsSubTab("gear") end
        SC_SwitchTab("sets")
        if SC_RefreshSetsSub then SC_RefreshSetsSub() end
    elseif msg == "bars" then
        SC_ShowMain()
        if SC_SetSetsSubTab then SC_SetSetsSubTab("bars") end
        SC_SwitchTab("sets")
        if SC_RefreshSetsSub then SC_RefreshSetsSub() end
    elseif msg == "rep" then
        SC_ShowMain()
        if SC_SetMiscSubTab then SC_SetMiscSubTab("rep") end
        SC_SwitchTab("misc")
        if SC_RefreshMisc then SC_RefreshMisc() end
    elseif msg == "skills" then
        SC_ShowMain()
        if SC_SetMiscSubTab then SC_SetMiscSubTab("skills") end
        SC_SwitchTab("misc")
        if SC_RefreshMisc then SC_RefreshMisc() end
    elseif msg == "debug" then
        -- Print raw talent API data + which frame exists.
        local numTabs = GetNumTalentTabs and GetNumTalentTabs() or 0
        print("|cff88bbff[SlyChar Debug]|r numTabs=" .. numTabs ..
              "  PlayerTalentFrame=" .. tostring(PlayerTalentFrame ~= nil) ..
              "  TalentFrame=" .. tostring(TalentFrame ~= nil))
        for tab = 1, numTabs do
            local tname, _, spent = GetTalentTabInfo(tab)
            local n = GetNumTalents and GetNumTalents(tab) or 0
            print("|cff88bbff Tab"..tab.."|r " .. (tname or "?") ..
                  " spent="..tostring(spent) .. " numTalents="..n)
            for i = 1, math.min(n, 3) do
                local tn, _, tier, col, cr, mr = GetTalentInfo(tab, i)
                print("  ["..i.."] "..tostring(tn)..
                      " tier="..tostring(tier)..
                      " col="..tostring(col)..
                      " rank="..tostring(cr).."/"..tostring(mr))
            end
        end
    elseif msg == "honor" then
        -- Collect everything into SlyCharDB.honorDebug so the user can read the
        -- SavedVariables file directly after /reload instead of copying chat output.
        SlyCharDB = SlyCharDB or {}
        local dbg = {}
        SlyCharDB.honorDebug = dbg

        local function rec(label, ...)
            local parts = {label}
            local args = {...}
            if #args == 0 then parts[#parts+1] = "(no return)"
            else for i = 1, #args do parts[#parts+1] = tostring(args[i]) end end
            dbg[#dbg+1] = table.concat(parts, "  ")
        end

        -- 1. Broad scan: every global function with honor/pvp/hk/arena in the name
        local found = {}
        for k, v in pairs(_G) do
            if type(v) == "function" then
                local lk = k:lower()
                if lk:find("honor") or lk:find("pvp") or lk:find("hk") or lk:find("arena") then
                    found[#found+1] = k
                end
            end
        end
        table.sort(found)
        rec("=== Global functions (honor/pvp/hk/arena) ===")
        for _, k in ipairs(found) do rec("  fn: "..k) end

        -- 2. Known candidates — full multi-value return dump
        rec("=== Known API returns ===")
        local candidates = {
            "GetHonorCurrency","GetHonorInfo","GetArenaCurrency",
            "GetPVPThisWeekStats","GetPVPYesterdayStats",
            "GetPVPLastWeekStats","GetPVPLifetimeStats",
            "GetHonorStat","GetHonorAmount","UnitHonor",
        }
        for _, name in ipairs(candidates) do
            local fn = _G[name]
            if type(fn) == "function" then
                -- try with "player" arg first, then no-arg
                local ok, a,b,c,d,e,f,g,h,i,j = pcall(fn, "player")
                if ok then rec(name.."(player):", a,b,c,d,e,f,g,h,i,j)
                else
                    ok,a,b,c,d,e,f,g,h,i,j = pcall(fn)
                    if ok then rec(name.."():", a,b,c,d,e,f,g,h,i,j) end
                end
            else
                rec(name..": "..type(fn))
            end
        end

        -- 3. Extra API calls not in the candidates list
        rec("=== Extra PVP API calls ===")
        local extras = { "GetPVPSessionStats", "GetPVPRankProgress", "GetPVPRoles",
                         "GetPVPTimer", "HonorSystemEnabled" }
        for _, name in ipairs(extras) do
            local fn = _G[name]
            if type(fn) == "function" then
                local ok, a,b,c,d,e,f = pcall(fn)
                if ok then rec(name.."():", a,b,c,d,e,f) end
                ok,a,b,c,d,e,f = pcall(fn, "player")
                if ok then rec(name.."(player):", a,b,c,d,e,f) end
            end
        end
        -- 4. TBC currency list API (index-based, not ID-based)
        rec("=== TBC Currency list (GetNumCurrencies / GetCurrencyListInfo) ===")
        rec("GetNumCurrencies type: "..type(GetNumCurrencies))
        rec("GetCurrencyListInfo type: "..type(GetCurrencyListInfo))
        if GetNumCurrencies then
            local n = GetNumCurrencies()
            rec("  count: "..tostring(n))
            for i = 1, (n or 0) do
                local ok, nm, isHeader, isExpanded, isUnused, isWatched, count, icon, maximum =
                    pcall(GetCurrencyListInfo, i)
                if ok and nm then
                    rec("  ["..i.."] "..tostring(nm).." isHeader="..tostring(isHeader)
                        .." count="..tostring(count).." max="..tostring(maximum))
                end
            end
        end

        DEFAULT_CHAT_FRAME:AddMessage("|cff88bbff[SC]|r Honor debug saved. /reload then open WTF/.../SavedVariables/SlySuite_Char.lua and search for honorDebug")
    elseif msg:match("^mode") then
        local m = (msg:match("^mode%s+(.+)$") or ""):trim()
        local MODES = {
            native_flyout  = "Native paper doll + SlyChar flyouts",
            slychar        = "Full SlyChar panel",
            slychar_flyout = "SlyChar panel + detached flyouts",
        }
        if MODES[m] then
            if SC.db then SC.db.mode = m end
            DEFAULT_CHAT_FRAME:AddMessage("|cff88bbff[SlyChar]|r Mode set to |cffffdd22" .. m .. "|r — /reload to apply.")
        else
            local cur = (SC.db and SC.db.mode) or "native_flyout"
            DEFAULT_CHAT_FRAME:AddMessage("|cff88bbff[SlyChar]|r Mode: |cffffdd22" .. cur .. "|r  (" .. (MODES[cur] or "?") .. ")")
            DEFAULT_CHAT_FRAME:AddMessage("  /slychar mode native_flyout   — native paper doll + SlyChar flyouts  (default)")
            DEFAULT_CHAT_FRAME:AddMessage("  /slychar mode slychar          — full SlyChar panel replaces CharacterFrame")
            DEFAULT_CHAT_FRAME:AddMessage("  /slychar mode slychar_flyout   — SlyChar panel + detached flyouts")
        end
    else
        SC_ToggleMain()
    end
end

-- --------------------------------------------------------
-- Event frame
-- --------------------------------------------------------
local evFrame = CreateFrame("Frame", "SlyCharEventFrame", UIParent)
evFrame:RegisterEvent("ADDON_LOADED")
evFrame:RegisterEvent("PLAYER_LOGOUT")
evFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
evFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
evFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
evFrame:RegisterEvent("UNIT_INVENTORY_CHANGED")
evFrame:RegisterEvent("PLAYER_TALENT_UPDATE")
evFrame:RegisterEvent("CHARACTER_POINTS_CHANGED")
evFrame:RegisterEvent("UPDATE_FACTION")
evFrame:RegisterEvent("SKILL_LINES_CHANGED")
evFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
evFrame:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
evFrame:RegisterEvent("GUILD_ROSTER_UPDATE")
evFrame:RegisterEvent("FRIENDLIST_UPDATE")
evFrame:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED")
evFrame:RegisterEvent("TRADE_SHOW")

evFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local name = ...
        if name == "SlySuite_Char" then
            SlyCharDB = SlyCharDB or {}
            ApplyDefaults(SlyCharDB, DB_DEFAULTS)
            SC.db = SlyCharDB

            -- Wrap key refresh functions with error guard so failures are
            -- logged to SlyErrorDB (visible via /slyerror) rather than silently
            -- breaking the UI.
            if SlyError and SlyError.guard then
                SC_RefreshStats  = SlyError.guard(SC_RefreshStats,  "SlyChar:RefreshStats")
                SC_RefreshSlots  = SlyError.guard(SC_RefreshSlots,  "SlyChar:RefreshSlots")
                SC_RefreshSets   = SlyError.guard(SC_RefreshSets,   "SlyChar:RefreshSets")
                if SC_RefreshMisc then
                    SC_RefreshMisc = SlyError.guard(SC_RefreshMisc, "SlyChar:RefreshMisc")
                end
                if SC_RefreshAll then
                    SC_RefreshAll  = SlyError.guard(SC_RefreshAll,  "SlyChar:RefreshAll")
                end
            end

            HookCharacterFrame()

            -- Intercept the H key (ToggleCharacter("HonorFrame")) so it opens
            -- the SlyChar panel with the honor wing rather than the native PvP frame.
            -- Must be done here (after SC.db is set) so the mode check works.
            if ToggleCharacter then
                local _origToggleChar = ToggleCharacter
                ToggleCharacter = function(which)
                    if (which == "HonorFrame" or which == "PVPFrame") then
                        local mode = (SC.db and SC.db.mode) or "native_flyout"
                        if mode ~= "native_flyout" then
                            SC_ShowMain()
                            if SC_ToggleWing then SC_ToggleWing("honor") end
                            return
                        end
                    end
                    return _origToggleChar(which)
                end
            end

            SLASH_SLYCHAR1 = "/slychar"
            SlashCmdList["SLYCHAR"] = SC_Slash

            if SlySuiteDataFrame and SlySuiteDataFrame.Register then
                SlySuiteDataFrame.Register(ADDON_NAME, SC.version, function() end, {
                    description = "Movable character sheet: gear, model, stats, sets, reputation, skills. Press C.",
                    slash       = "/slychar",
                    icon        = "Interface\\Icons\\INV_Misc_PocketWatch_01",
                })
            end
        end

    elseif event == "PLAYER_LOGOUT" then
        if SlyCharMainFrame then
            local pt, _, _, x, y = SlyCharMainFrame:GetPoint()
            SC.db.position = { point = pt or "CENTER", x = x or 0, y = y or 0 }
        end

    elseif event == "UNIT_INVENTORY_CHANGED" then
        if SlyCharMainFrame and SlyCharMainFrame:IsShown() then
            SC_RefreshAll()
        end

    elseif event == "PLAYER_TALENT_UPDATE"
        or event == "CHARACTER_POINTS_CHANGED" then
        if SlyCharMainFrame and SlyCharMainFrame:IsShown() then
            SC_RefreshAll()
        end

    elseif event == "UPDATE_FACTION" then
        if SlyCharMainFrame and SlyCharMainFrame:IsShown()
            and SC.db.lastTab == "misc" then
            if SC_RefreshMisc then SC_RefreshMisc() end
        end

    elseif event == "SKILL_LINES_CHANGED" then
        if SlyCharMainFrame and SlyCharMainFrame:IsShown()
            and SC.db.lastTab == "misc" then
            if SC_RefreshMisc then SC_RefreshMisc() end
        end

    elseif event == "PLAYER_TARGET_CHANGED" then
        if SlyCharMainFrame and SlyCharMainFrame:IsShown()
            and SC.db.lastTab == "social" then
            if SC_UpdateNITLayer then SC_UpdateNITLayer("target") end
        end

    elseif event == "UPDATE_MOUSEOVER_UNIT" then
        -- Only bother with mouseover if NWB hasn't already set a layer value
        if SlyCharMainFrame and SlyCharMainFrame:IsShown()
            and SC.db.lastTab == "social"
            and (not NWB_CurrentLayer or NWB_CurrentLayer == 0) then
            if SC_UpdateNITLayer then SC_UpdateNITLayer("mouseover") end
        end

    elseif event == "GUILD_ROSTER_UPDATE" then
        if SlyCharMainFrame and SlyCharMainFrame:IsShown()
            and SC.db.lastTab == "social" then
            if SC_RefreshNITGuild then SC_RefreshNITGuild() end
        end

    elseif event == "FRIENDLIST_UPDATE" then
        if SlyCharMainFrame and SlyCharMainFrame:IsShown()
            and SC.db.lastTab == "social" then
            if SC_RefreshNITFriends then SC_RefreshNITFriends() end
        end

    elseif event == "ACTIVE_TALENT_GROUP_CHANGED" then
        if SlyCharMainFrame and SlyCharMainFrame:IsShown() then
            if SC_RefreshAll then SC_RefreshAll() end
        end

    elseif event == "TRADE_SHOW" then
        -- Trade opened: do nothing. SlyChar stays open (they coexist).
        -- User can close SlyChar manually if it's in the way.

    elseif event == "PLAYER_ENTERING_WORLD" then
        local mode = (SC.db and SC.db.mode) or "native_flyout"
        -- Pre-build the main frame only for slychar modes (native_flyout builds lazily on demand)
        if mode ~= "native_flyout" then
            if not SlyCharMainFrame and SC.db and not InCombatLockdown() then
                local ok, err = pcall(SC_BuildMain)
                if not ok then
                    DEFAULT_CHAT_FRAME:AddMessage("|cffff4444[SlyChar] Build error:|r " .. tostring(err))
                elseif SlyCharMainFrame then
                    SlyCharMainFrame:Hide()
                end
            end
        end

    elseif event == "PLAYER_REGEN_DISABLED" then
        -- Combat started: close the character sheet.
        -- Frames with SecureActionButtonTemplate children cannot always be
        -- hidden via :Hide() during lockdown — disable mouse and zero alpha
        -- first so it cannot block the screen even if Hide() silently fails.
        if SlyCharMainFrame and SlyCharMainFrame:IsShown() then
            SlyCharMainFrame:EnableMouse(false)
            SlyCharMainFrame:SetAlpha(0)
            SC._hiddenByCombat = true
            pcall(function() SlyCharMainFrame:Hide() end)
        end

    elseif event == "PLAYER_REGEN_ENABLED" then
        -- Combat ended.
        if SC._hiddenByCombat then
            SC._hiddenByCombat = false
            if SlyCharMainFrame then
                -- If Hide() failed during combat the frame is still "shown"
                -- but invisible — fully hide it now lockdown is lifted.
                if SlyCharMainFrame:IsShown() then
                    SlyCharMainFrame:Hide()
                else
                    -- Restore alpha in case user re-opens manually next time.
                    SlyCharMainFrame:SetAlpha(1)
                end
            end
        end
        -- Hide the native CharacterFrame we couldn't suppress earlier.
        if SC._pendingHideChar then
            SC._pendingHideChar = false
            if CharacterFrame and CharacterFrame:IsShown() then
                CharacterFrame:EnableMouse(true)
                CharacterFrame:EnableKeyboard(true)
                CharacterFrame:Hide()
            end
        end
        -- If player pressed C during combat before the frame was built, open it now.
        if SC._pendingBuild and SlyCharMainFrame then
            SC._pendingBuild = false
            SC_ShowMain()
        end
    end
end)
