-- ============================================================
-- SlyChar.lua  (full rewrite â€” movable character sheet)
-- â€¢ Intercepts C key: hides CharacterFrame, shows our panel
-- â€¢ SC_BuildMain() builds a full equipped-gear + model panel
-- â€¢ Stats tab (base stats + ECS extended) + Sets tab (IRR)
-- ============================================================

SC  = SC  or {}
SC.version = "2.1.0"
local ADDON_NAME = "SlySuite_Char"

-- Flags shared with SlyCharUI.lua (same global table, different file)
SC._skipHook        = false   -- true while Chr button is showing CharacterFrame directly
SC._pendingHideChar = false   -- true when CharacterFrame was left open in combat
SC._hiddenByCombat  = false   -- true when we suppressed the panel at combat start
SC._pendingBuild    = false   -- true when SC_BuildMain() was blocked by combat lockdown
SC._mainVisible     = false   -- true when user has logically opened SlyCharMainFrame

-- --------------------------------------------------------
-- SavedVariables defaults
-- --------------------------------------------------------
local DB_DEFAULTS = {
    position      = nil,     -- {point, x, y} for SlyCharMainFrame
    lastTab       = "stats",
    theme         = "shadow",
    mode          = "slychar_flyout",  -- "native_flyout" | "slychar" | "slychar_flyout"
    collapsed     = {},      -- {[sectionKey]=true} for collapsed stat sections
    hidden        = {},      -- {[sectionKey]=true} for fully hidden stat sections
    minimap       = { hide = false, minimapPos = 225 },
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
            SC._pendingBuild = true
            DEFAULT_CHAT_FRAME:AddMessage("|cff88bbff[SlyChar]|r Opening after combat ends...")
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
    -- sBtn frames are parented to UIParent so Show()/Hide() are unrestricted.
    SlyCharMainFrame:Show()
    SlyCharMainFrame:EnableMouse(true)
    SC._mainVisible    = true
    SC._hiddenByCombat = false
    -- Close the >> flyout menu if it was left open.
    local fm = _G["SlyCharStripFlyout"]
    if fm then fm:Hide() end
    SC_RefreshAll()
    -- Restore the active tab (and in slychar_flyout mode, open its wing).
    if SC_SwitchTab then
        SC_SwitchTab(SC.db.lastTab or "stats")
    end
end

function SC_ToggleMain()
    if SlyCharMainFrame and SC._mainVisible then
        SlyCharMainFrame:Hide()
        SlyCharMainFrame:EnableMouse(false)
        SC._mainVisible = false
        SC._hiddenByCombat = false
        -- Also collapse any open wing
        local wf = _G["SlyCharWingFrame"]
        if wf and wf:IsShown() then wf:Hide() end
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
            self:Hide()
            -- sBtn frames are parented to UIParent so SlyCharMainFrame:Show()
            -- is no longer combat-restricted.  SC_ShowMain guards SC_BuildMain
            -- (which sets attributes and remains combat-restricted).
            SC_ShowMain()
            return
        end
        HideUIPanel(self)  -- properly removes CharacterFrame from the UIPanel stack
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

        -- 5. Arena (TBC Anniversary = personal rating, no teams)
        rec("=== Arena ===")
        rec("GetCurrentArenaSeasonUsesTeams type: "..type(GetCurrentArenaSeasonUsesTeams))
        if GetCurrentArenaSeasonUsesTeams then
            local ok, v = pcall(GetCurrentArenaSeasonUsesTeams)
            rec("GetCurrentArenaSeasonUsesTeams(): ok="..tostring(ok).." v="..tostring(v))
        end
        if GetCurrentArenaSeason then
            local ok, v = pcall(GetCurrentArenaSeason)
            rec("GetCurrentArenaSeason(): ok="..tostring(ok).." v="..tostring(v))
        end
        rec("GetPersonalRatedInfo type: "..type(GetPersonalRatedInfo))
        if GetPersonalRatedInfo then
            for i = 1, 3 do
                local ok, a,b,c,d,e,f,g,h,ii,j,k = pcall(GetPersonalRatedInfo, i)
                rec("  GetPersonalRatedInfo("..i.."): ok="..tostring(ok).." rating="..tostring(a).." seasonPlayed="..tostring(b).." seasonWon="..tostring(c).." weeklyPlayed="..tostring(d).." weeklyWon="..tostring(e))
            end
        end
        -- Also try C_PvP namespace
        rec("C_PvP type: "..type(C_PvP))
        if type(C_PvP) == "table" then
            for k2, v in pairs(C_PvP) do
                rec("  C_PvP."..tostring(k2).." = "..type(v))
            end
        end

        DEFAULT_CHAT_FRAME:AddMessage("|cff88bbff[SC]|r Honor debug saved. /reload then open WTF/.../SavedVariables/SlySuite_Char.lua and search for honorDebug")
    elseif msg:match("^mode") then
        local m = (msg:match("^mode%s+(.+)$") or ""):trim()
        -- Short aliases → internal key
        local ALIASES = { flyout = "slychar_flyout", docked = "slychar", native = "native_flyout" }
        m = ALIASES[m] or m
        local MODE_LABEL = {
            slychar_flyout = "Flyout",
            slychar        = "Docked",
            native_flyout  = "Native",
        }
        if MODE_LABEL[m] then
            if SC.db then SC.db.mode = m end
            DEFAULT_CHAT_FRAME:AddMessage("|cff88bbff[SlyChar]|r Mode → |cffffdd22" .. MODE_LABEL[m] .. "|r — /reload to apply.")
        else
            local cur = (SC.db and SC.db.mode) or "native_flyout"
            DEFAULT_CHAT_FRAME:AddMessage("|cff88bbff[SlyChar]|r Mode: |cffffdd22" .. (MODE_LABEL[cur] or cur) .. "|r")
            DEFAULT_CHAT_FRAME:AddMessage("  /slychar mode flyout   — SlyChar panel with detached flyouts")
            DEFAULT_CHAT_FRAME:AddMessage("  /slychar mode docked   — SlyChar panel, tabs docked")
            DEFAULT_CHAT_FRAME:AddMessage("  /slychar mode native   — native WoW character frame")
        end
    else
        SC_ToggleMain()
    end
end

-- --------------------------------------------------------
-- Minimap button (LibDBIcon)
-- --------------------------------------------------------
local function SC_CreateMinimapButton()
    local LDB     = LibStub and LibStub("LibDataBroker-1.1", true)
    local LDBIcon = LibStub and LibStub("LibDBIcon-1.0", true)
    if not LDB or not LDBIcon then return end
    if LDBIcon:IsRegistered("SlyChar") then return end

    local MODE_LABEL = { slychar_flyout="Flyout", slychar="Docked", native_flyout="Native" }

    local dataObj = LDB:NewDataObject("SlyChar", {
        type = "launcher",
        text = "SlyChar",
        icon = "Interface\\Icons\\INV_Misc_PocketWatch_01",
        OnClick = function(_, btn)
            if btn == "LeftButton" then
                SC_ToggleMain()
            elseif btn == "RightButton" then
                local order  = { "slychar_flyout", "slychar", "native_flyout" }
                local labels = { "Flyout",          "Docked",  "Native" }
                if SC.db then
                    local cur = SC.db.mode or "slychar_flyout"
                    for i, m in ipairs(order) do
                        if m == cur then
                            local ni = (i % #order) + 1
                            SC.db.mode = order[ni]
                            DEFAULT_CHAT_FRAME:AddMessage(
                                "|cff88bbff[SlyChar]|r Mode \226\134\146 |cffffdd22" .. labels[ni] .. "|r \226\128\148 /reload to apply")
                            break
                        end
                    end
                end
            end
        end,
        OnTooltipShow = function(tip)
            tip:SetText("|cff00ccffSlyChar|r v" .. SC.version)
            tip:AddLine("Left-click: toggle panel", 1, 1, 1)
            tip:AddLine("Right-click: cycle mode", 1, 1, 1)
            local cur = (SC.db and SC.db.mode) or "?"
            tip:AddLine("Mode: " .. (MODE_LABEL[cur] or cur), 1, 0.85, 0.1)
        end,
    })

    LDBIcon:Register("SlyChar", dataObj, SC.db.minimap)
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
                    local mode = (SC.db and SC.db.mode) or "native_flyout"
                    if mode ~= "native_flyout" then
                        if which == "PaperDollFrame" or which == nil then
                            -- C key / micro-menu: bypass CharacterFrame entirely
                            SC_ToggleMain()
                            return
                        elseif which == "HonorFrame" or which == "PVPFrame" then
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
        if SC._mainVisible then
            SC_RefreshAll()
        end

    elseif event == "PLAYER_TALENT_UPDATE"
        or event == "CHARACTER_POINTS_CHANGED" then
        if SC._mainVisible then
            SC_RefreshAll()
        end

    elseif event == "UPDATE_FACTION" then
        if SC._mainVisible and SC.db.lastTab == "misc" then
            if SC_RefreshMisc then SC_RefreshMisc() end
        end

    elseif event == "SKILL_LINES_CHANGED" then
        if SC._mainVisible and SC.db.lastTab == "misc" then
            if SC_RefreshMisc then SC_RefreshMisc() end
        end

    elseif event == "PLAYER_TARGET_CHANGED" then
        if SC._mainVisible and SC.db.lastTab == "social" then
            if SC_UpdateNITLayer then SC_UpdateNITLayer("target") end
        end

    elseif event == "UPDATE_MOUSEOVER_UNIT" then
        -- Only bother with mouseover if NWB hasn't already set a layer value
        if SC._mainVisible and SC.db.lastTab == "social"
            and (not NWB_CurrentLayer or NWB_CurrentLayer == 0) then
            if SC_UpdateNITLayer then SC_UpdateNITLayer("mouseover") end
        end

    elseif event == "GUILD_ROSTER_UPDATE" then
        if SC._mainVisible and SC.db.lastTab == "social" then
            if SC_RefreshNITGuild then SC_RefreshNITGuild() end
        end

    elseif event == "FRIENDLIST_UPDATE" then
        if SC._mainVisible and SC.db.lastTab == "social" then
            if SC_RefreshNITFriends then SC_RefreshNITFriends() end
        end

    elseif event == "ACTIVE_TALENT_GROUP_CHANGED" then
        if SC._mainVisible then
            if SC_RefreshAll then SC_RefreshAll() end
        end

    elseif event == "TRADE_SHOW" then
        -- Trade opened: do nothing. SlyChar stays open (they coexist).
        -- User can close SlyChar manually if it's in the way.

    elseif event == "PLAYER_ENTERING_WORLD" then
        local mode = (SC.db and SC.db.mode) or "native_flyout"
        -- Pre-build for slychar modes.  SC_BuildMain ends with f:Hide() so no
        -- pre-show or alpha tricks are needed; the frame starts truly hidden.
        if mode ~= "native_flyout" then
            if not SlyCharMainFrame and SC.db and not InCombatLockdown() then
                local ok, err = pcall(SC_BuildMain)
                if not ok then
                    DEFAULT_CHAT_FRAME:AddMessage("|cffff4444[SlyChar] Build error:|r " .. tostring(err))
                end
            end
        end
        SC_CreateMinimapButton()

    elseif event == "PLAYER_REGEN_DISABLED" then
        -- Auto-hide on combat start; PLAYER_REGEN_ENABLED restores it.
        -- Hide() is now unrestricted: sBtn frames are parented to UIParent.
        if SlyCharMainFrame and SC._mainVisible then
            SlyCharMainFrame:Hide()
            SlyCharMainFrame:EnableMouse(false)
            SC._mainVisible = false
            SC._hiddenByCombat = true
        end

    elseif event == "PLAYER_REGEN_ENABLED" then
        -- Combat ended: restore panel if we auto-hid it at combat start.
        if SC._hiddenByCombat then
            SC._hiddenByCombat = false
            SC_ShowMain()
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
        if SC._pendingBuild then
            SC._pendingBuild = false
            SC_ShowMain()
        end
    end
end)
