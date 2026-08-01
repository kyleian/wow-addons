-- ============================================================
-- SlyChar.lua  (full rewrite â€” movable character sheet)
-- â€¢ Intercepts C key: hides CharacterFrame, shows our panel
-- â€¢ SC_BuildMain() builds a full equipped-gear + model panel
-- â€¢ Stats tab (base stats + ECS extended) + Sets tab (IRR)
-- ============================================================

SC  = SC  or {}
SC.version = "2.7.7"
local ADDON_NAME = "SlySuite_Char"

-- Flags shared with SlyCharUI.lua (same global table, different file)
SC._skipHook        = false   -- true while Chr button is showing CharacterFrame directly
SC._pendingBuild    = false   -- true when SC_BuildMain() was blocked by combat lockdown
SC._mainVisible     = false   -- true when user has logically opened SlyCharMainFrame
SC._refreshPending  = false   -- true when a deferred SC_RefreshAll is already queued
SC._pendingCharFrame = false  -- true when CHR was clicked in combat, open after

-- --------------------------------------------------------
-- Debug ring-buffer  (/slychar debug)
-- --------------------------------------------------------
local _DBG = {}        -- ring buffer of strings
local _DBG_MAX = 80
local function dbg(msg)
    local ts = string.format("%.1f", GetTime())
    local line = "[" .. ts .. "] " .. tostring(msg)
    if #_DBG >= _DBG_MAX then table.remove(_DBG, 1) end
    _DBG[#_DBG + 1] = line
    -- Mirror to SavedVariables so the log survives without any manual command --
    -- it's on disk automatically after the next /reload or logout, in
    -- WTF/.../SavedVariables/SlyCharDB.lua under ["debugLog"].
    if SC.db then SC.db.debugLog = _DBG end
end
-- Expose so SlyCharUI.lua (same addon, different file) can log too.
SC.dbg = dbg

-- SC_SuppressCharacterFrame(): the ONE place that makes the native
-- CharacterFrame invisible/non-interactive in slychar modes.
--
-- IMPORTANT: this must NEVER call HideUIPanel()/Hide() on CharacterFrame.
-- Doing that was tried (v2.7.0) and broke the C-key toggle entirely: forcing
-- CharacterFrame's real IsShown() back to false right after every open meant
-- Blizzard's own ToggleCharacter() ALWAYS saw "currently closed" on the next
-- press and ALWAYS took its show-branch, so its close-branch (which is what
-- calls the real HideUIPanel(CharacterFrame) that our HideUIPanel hook
-- listens for) could never run -- SlyChar could open but never close, and
-- CharacterFrame could end up genuinely shown+interactive at its own native
-- screen position whenever the feedback loop desynced.
--
-- So instead: let CharacterFrame's real Show()/Hide() state track whatever
-- ToggleCharacter naturally decides (that's what makes it alternate
-- correctly, open/close/open/close). We just force it alpha=0 and
-- mouse/keyboard-disabled EVERY time, regardless of its real shown state, so
-- it's never visible and never intercepts a click no matter what.
--
-- CRITICAL: EnableMouse(false) on CharacterFrame itself does NOT stop its
-- CHILDREN (equipment slot buttons, tabs, stat sub-frames) from receiving
-- hover/click events -- each frame's mouse-enabled state is independent of
-- its parent's. That's what caused equipped-item tooltips to "bleed
-- through" on hover and blocked real right-clicks meant for SlyChar's own
-- overlaid buttons: CharacterFrame's invisible-but-still-mouse-active child
-- buttons were intercepting the events. So mouse must be disabled
-- recursively across every descendant, not just the top frame.
local function SC_SetMouseRecursive(frame, enabled)
    if not frame then return end
    if frame.EnableMouse then frame:EnableMouse(enabled) end
    local kids = { frame:GetChildren() }
    for _, kid in ipairs(kids) do
        SC_SetMouseRecursive(kid, enabled)
    end
end

-- 3D PlayerModel content (the rotating character mesh) does NOT reliably
-- respect ancestor SetAlpha(0) -- it's rendered on a separate compositing
-- path from normal 2D frame textures/text on this client, so an alpha=0
-- parent can still show a fully-opaque floating model. Must Hide() the
-- model frame itself, explicitly, to actually remove it from the screen.
local function SC_HideNativeModel()
    if CharacterModelFrame then CharacterModelFrame:Hide() end
end
local function SC_ShowNativeModel()
    if CharacterModelFrame then CharacterModelFrame:Show() end
end

local function SC_SuppressCharacterFrame()
    if not CharacterFrame then return end
    CharacterFrame:SetAlpha(0)
    CharacterFrame:EnableKeyboard(false)
    SC_SetMouseRecursive(CharacterFrame, false)
    SC_HideNativeModel()
end
SC.SuppressCharacterFrame = SC_SuppressCharacterFrame


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

-- Set true whenever WE call HideUIPanel(CF) for cleanup so the HideUIPanel hook
-- does not interpret it as a user close-press.
function SC_ShowMain()
    if not SlyCharMainFrame then
        -- Frame creation is not combat-restricted (no secure templates).
        -- Always build immediately so C works regardless of combat state.
        local ok, err = pcall(SC_BuildMain)
        if not ok then
            dbg("SC_BuildMain FAILED: "..tostring(err))
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
    -- Real combat-test debug data proved Frame:Show()/:Hide() silently fail to
    -- stick on this frame during combat (Show() fires, IsShown() reads false
    -- immediately after, every single tick, reverting the instant combat
    -- ends). So SlyCharMainFrame is Show()n exactly once, permanently, at
    -- creation (see SC_BuildMain) and NEVER Hidden again -- all visual
    -- show/hide from here on is done purely via alpha/mouse/keyboard, which
    -- has no such combat dependency. SC._mainVisible is the single source of
    -- truth for "is it logically open", not SlyCharMainFrame:IsShown().
    SlyCharMainFrame:SetAlpha(1)
    SlyCharMainFrame:EnableMouse(true)
    SlyCharMainFrame:EnableKeyboard(true)
    -- EnableMouse(true) on the top frame alone does NOT cascade to its own
    -- children (equipment slot buttons etc.) any more than it does for
    -- CharacterFrame -- re-enable recursively so slot buttons actually
    -- receive hover/click again.
    SC_SetMouseRecursive(SlyCharMainFrame, true)
    -- PlayerModel 3D content doesn't reliably respect ancestor SetAlpha(0)
    -- (see SC_HideNativeModel comment) -- Show() it explicitly too.
    if SlyCharModel then SlyCharModel:Show() end
    SC._mainVisible = true
    dbg("SC_ShowMain: mainVisible=true combat="..tostring(InCombatLockdown()))
    -- Close the >> flyout menu if it was left open.
    local fm = _G["SlyCharStripFlyout"]
    if fm then fm:Hide() end
    SC_RefreshAll()
    -- Restore the last-active tab (and in slychar_flyout mode, open its wing).
    -- Slash commands use SC_SwitchTab directly to jump to a specific tab.
    if SC_SwitchTab then
        SC_SwitchTab(SC.db.lastTab or "stats")
    end
end

-- Unconditional hide -- the counterpart to SC_ShowMain(). Alpha-based (see
-- comment in SC_ShowMain for why); this is also where the equivalent of the
-- old OnHide cleanup (side panel / picker / wing / flyout-menu) now lives,
-- since we no longer rely on a real Hide() call to trigger it.
function SC_HideMain()
    if not SlyCharMainFrame then return end
    SlyCharMainFrame:SetAlpha(0)
    SlyCharMainFrame:EnableMouse(false)
    SlyCharMainFrame:EnableKeyboard(false)
    -- Same recursive-mouse-disable requirement as CharacterFrame: our own
    -- equipment slot buttons (children of SlyCharMainFrame) stay
    -- individually mouse-enabled otherwise, so they keep receiving hover
    -- events (item tooltip bleed-through) even after the window is alpha=0.
    SC_SetMouseRecursive(SlyCharMainFrame, false)
    -- Explicit Hide() -- SetAlpha(0) alone doesn't reliably remove 3D
    -- PlayerModel content from the screen on this client.
    if SlyCharModel then SlyCharModel:Hide() end
    SC._mainVisible = false
    dbg("SC_HideMain: mainVisible=false combat="..tostring(InCombatLockdown()))
    if SC_HidePicker then SC_HidePicker() end
    if SC_CloseSidePanel then SC_CloseSidePanel() end
    local wf = _G["SlyCharWingFrame"]
    if wf then wf:Hide() end
    local fm = _G["SlyCharStripFlyout"]
    if fm then fm:Hide() end
end

-- Real toggle, based on current visibility. Only used by discrete user
-- actions that need to decide for themselves (slash command, minimap/LDB
-- button) -- NOT by the ShowUIPanel/HideUIPanel hooks, which already know
-- (from the native code they're mirroring) whether to show or hide and so
-- call SC_ShowMain()/SC_HideMain() directly instead of toggling.
function SC_ToggleMain()
    local isOpen = SC._mainVisible
    dbg("SC_ToggleMain isOpen="..tostring(isOpen).." mode="..(SC.db and SC.db.mode or "?"))
    if isOpen then
        SC_HideMain()
    else
        SC_ShowMain()
    end
end

-- --------------------------------------------------------
-- Debounced refresh: coalesces rapid UNIT_INVENTORY_CHANGED / talent
-- events that flood in during combat into a single SC_RefreshAll call.
-- Direct calls from SC_ShowMain / SC_SwitchTab stay immediate.
-- --------------------------------------------------------
local _REFRESH_DELAY = 0.35
function SC_DeferRefresh()
    if SC._refreshPending then return end
    SC._refreshPending = true
    C_Timer.After(_REFRESH_DELAY, function()
        SC._refreshPending = false
        if SC._mainVisible and SC_RefreshAll then SC_RefreshAll() end
    end)
end

-- --------------------------------------------------------
-- Hook CharacterFrame: suppress it in slychar modes.
-- SC_ToggleMain is NOT called from here — that is handled by the
-- hooksecurefunc("ShowUIPanel") in ADDON_LOADED, which fires on every
-- C-key press regardless of CharacterFrame's current visibility state.
-- --------------------------------------------------------
local function HookCharacterFrame()
    if not CharacterFrame then return end

    CharacterFrame:HookScript("OnShow", function(self)
        local mode = (SC.db and SC.db.mode) or "native_flyout"

        if mode == "native_flyout" then
            if SC_ShowNativeCompanion then SC_ShowNativeCompanion() end
            return
        end

        if SC._skipHook then return end

        -- Safety net for whatever path just showed CharacterFrame (raw keypress,
        -- macro, other addon) that isn't already covered by the ShowUIPanel hook
        -- below -- force it alpha=0/non-interactive immediately, without ever
        -- touching its real shown-state (see SC_SuppressCharacterFrame comment).
        dbg("OnShow:CharacterFrame combat="..tostring(InCombatLockdown()))
        SC_SuppressCharacterFrame()
    end)

    CharacterFrame:HookScript("OnHide", function(self)
        local mode = (SC.db and SC.db.mode) or "native_flyout"
        if mode == "native_flyout" then
            if SC_HideNativeCompanion then SC_HideNativeCompanion() end
        else
            self:SetAlpha(1)
            self:EnableKeyboard(true)
            self:SetFrameStrata("MEDIUM")
            SC_SetMouseRecursive(self, true)
            SC_ShowNativeModel()
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
    elseif msg == "debug" then
        -- Dump the combat/CharacterFrame event ring-buffer to chat.
        if #_DBG == 0 then
            DEFAULT_CHAT_FRAME:AddMessage("|cff88bbff[SlyChar Debug]|r No events logged yet.")
        else
            DEFAULT_CHAT_FRAME:AddMessage("|cff88bbff[SlyChar Debug]|r Last " .. #_DBG .. " events:")
            for i = math.max(1, #_DBG - 29), #_DBG do
                DEFAULT_CHAT_FRAME:AddMessage("|cffaaaaaa" .. _DBG[i] .. "|r")
            end
        end
        DEFAULT_CHAT_FRAME:AddMessage("|cff88bbff[SlyChar Debug]|r combat=" .. tostring(InCombatLockdown())
            .. " cfShown=" .. tostring(CharacterFrame and CharacterFrame:IsShown())
            .. " cfAlpha=" .. string.format("%.2f", CharacterFrame and CharacterFrame:GetAlpha() or 0)
            .. " mainVis=" .. tostring(SC._mainVisible)
            .. " pendCF=" .. tostring(SC._pendingCharFrame))
    elseif msg == "debug clear" then
        _DBG = {}
        DEFAULT_CHAT_FRAME:AddMessage("|cff88bbff[SlyChar Debug]|r Log cleared.")
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
evFrame:RegisterEvent("UPDATE_BATTLEFIELD_SCORE")  -- fires after BG ends; used to refresh honor

evFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local name = ...
        if name == "SlySuite_Char" then
            SlyCharDB = SlyCharDB or {}
            ApplyDefaults(SlyCharDB, DB_DEFAULTS)
            SC.db = SlyCharDB

            -- Unmistakable, always-visible proof that THIS build is the one
            -- actually loaded -- no need to wait for a SavedVariables round
            -- trip to check. Bump SC.version whenever this file changes.
            DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99[SlyChar]|r v"..SC.version.." loaded")

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

            -- ==========================================================
            -- SINGLE toggle path, deliberately.
            --
            -- A previous attempt used a second, separate path: a custom
            -- SetBindingClick button bound directly to "C", bypassing
            -- ToggleCharacter/ShowUIPanel/HideUIPanel entirely. Debug logs with
            -- stack traces proved that path works fine out of combat, but goes
            -- COMPLETELY silent in combat (no click, no hook, nothing) for the
            -- entire duration of every fight -- almost certainly because
            -- SetBindingClick/SetBinding are themselves combat-protected, so
            -- whatever silently reverted our override at combat-start could
            -- never be re-won until combat ended, leaving "C" dead the whole fight.
            --
            -- The ORIGINAL path below (hooksecurefunc on ToggleCharacter /
            -- ShowUIPanel / HideUIPanel) is proven reliable in combat by that
            -- same debug data (it's how every earlier in-combat toggle was
            -- actually happening). It reacts to whatever invoked the native
            -- action -- real "C" keypress, macro, other addon -- without ever
            -- needing to own or fight over the keybinding itself. That's why
            -- it survives combat: it doesn't depend on "C" pointing at anything
            -- in particular.
            -- ==========================================================
            hooksecurefunc("ToggleCharacter", function(which)
                local mode = (SC.db and SC.db.mode) or "native_flyout"
                if mode == "native_flyout" then return end
                -- Only side effect handled here: opening the honor wing.
                -- The actual show/hide of SlyCharMainFrame is driven entirely
                -- by the ShowUIPanel/HideUIPanel hooks below (ToggleCharacter
                -- always calls one of those internally before returning, so by
                -- the time this hook runs the panel is already in the right
                -- state) -- see note above about why we don't duplicate that
                -- call here.
                if which == "HonorFrame" or which == "PVPFrame" then
                    if SC_ToggleWing then SC_ToggleWing("honor") end
                end
            end)

            -- ── ShowUIPanel / HideUIPanel hooks: the ONE source of truth ──────────
            -- ToggleCharacter(), macros, micro-menu clicks, and other addons can
            -- all end up calling ShowUIPanel(CharacterFrame)/HideUIPanel(CharacterFrame)
            -- directly. Rather than trying to also react to every possible caller
            -- (which previously meant BOTH the ToggleCharacter hook and this hook
            -- firing for the same single keypress -- a real double-toggle race that
            -- only a 100ms debounce papered over), these two hooks are now the only
            -- place that shows/hides SlyCharMainFrame. Each one is a plain, direct
            -- mirror of what the native code just decided (show -> show, hide ->
            -- hide), never a toggle, so there is nothing to race.
            --
            -- CharacterFrame itself must never actually be visible/clickable in
            -- slychar modes -- SC_SuppressCharacterFrame() forces it
            -- alpha=0/mouse=false/keyboard=false every time, WITHOUT ever calling
            -- HideUIPanel/Hide() on it. That's deliberate: forcing its real
            -- shown-state back to false ourselves (tried in v2.7.0) broke the
            -- native ToggleCharacter()'s own IsShown() check, so it could never
            -- detect "already open" and take its close-branch -- SlyChar could
            -- open but never close. Letting CharacterFrame's real shown-state
            -- track ToggleCharacter's natural intent (and only suppressing it
            -- visually/interactively) keeps that native alternation working.
            hooksecurefunc("ShowUIPanel", function(frame)
                if frame ~= CharacterFrame then return end
                local mode = (SC.db and SC.db.mode) or "native_flyout"
                if mode == "native_flyout" then return end
                dbg("ShowUIPanel:hook combat="..tostring(InCombatLockdown()))
                SC_ShowMain()
                SC_SuppressCharacterFrame()
            end)

            -- ── HideUIPanel hook: catches close-C press when CF is in the UIPanel stack ──
            -- A "close C" press routes through HideUIPanel (not ShowUIPanel) once
            -- CharacterFrame is already in the UIPanel stack. Forward it to our
            -- panel's hide so close-C always works. This now fires naturally and
            -- reliably because SC_SuppressCharacterFrame() no longer forces
            -- CharacterFrame's real shown-state back to false -- ToggleCharacter's
            -- own internal IsShown() check genuinely alternates true/false, so its
            -- close-branch (which is what calls this HideUIPanel) actually runs.
            hooksecurefunc("HideUIPanel", function(frame)
                if frame ~= CharacterFrame then return end
                local mode = (SC.db and SC.db.mode) or "native_flyout"
                if mode == "native_flyout" then return end
                dbg("HideUIPanel:hook combat="..tostring(InCombatLockdown()))
                SC_HideMain()
            end)

            -- ── CharacterFrame suppression enforcer (self-healing, always on) ─────
            -- Continuously re-asserts suppression while CharacterFrame is
            -- genuinely shown, not just as an alpha-drift safety net. Blizzard's
            -- own paperdoll code re-enables mouse on individual item slot
            -- buttons whenever it refreshes them (equip/unequip, inventory
            -- update, stat refresh, etc.) -- that happens on a schedule we
            -- don't control and isn't caught by the one-time suppression call
            -- in the ShowUIPanel/OnShow hooks. That silent re-enable on
            -- individual children (not CharacterFrame itself) is what let
            -- equipped-item tooltips bleed through on hover and stole
            -- right-clicks meant for whatever was underneath. So every tick,
            -- while CharacterFrame is shown, re-run the full recursive
            -- suppression unconditionally (cheap enough at 0.2s intervals).
            if SC.db.mode ~= "native_flyout" then
                local _lastEnforceLog = 0
                SC._enforceTicker = C_Timer.NewTicker(0.2, function()
                    local mode = (SC.db and SC.db.mode) or "native_flyout"
                    if mode == "native_flyout" then return end
                    if CharacterFrame and CharacterFrame:IsShown() then
                        if CharacterFrame:GetAlpha() > 0 then
                            local now = GetTime()
                            if now - _lastEnforceLog > 1 then
                                dbg("ENFORCE: CharacterFrame visible+alpha>0 — forcing suppress + SlyChar open")
                                _lastEnforceLog = now
                            end
                            if not SC._mainVisible then
                                SC_ShowMain()
                            end
                        end
                        SC_SuppressCharacterFrame()
                    end
                end)
            end

            -- ── Panel alpha enforcer (self-healing, always on) ────────────────────
            -- SlyCharMainFrame's own visibility is alpha-driven now (see
            -- SC_ShowMain/SC_HideMain), not Show()/Hide()-driven, specifically
            -- because Show()/Hide() were proven to silently fail to stick on
            -- this frame during combat. Alpha isn't known to have that problem,
            -- but this stays as a cheap safety net in case some other code path
            -- (another addon, a future edit) calls :SetAlpha() directly and
            -- drifts it out of sync with SC._mainVisible.
            SC._panelEnforceTicker = C_Timer.NewTicker(0.5, function()
                if not SlyCharMainFrame then return end
                local mode = (SC.db and SC.db.mode) or "native_flyout"
                if mode == "native_flyout" then return end
                local want   = SC._mainVisible
                local actual = SlyCharMainFrame:GetAlpha() > 0
                if want ~= actual then
                    dbg("PANEL-ENFORCE: alpha out of sync (want="..tostring(want)..", actual="..tostring(actual)..") -- correcting")
                    SlyCharMainFrame:SetAlpha(want and 1 or 0)
                    SlyCharMainFrame:EnableMouse(want)
                    SlyCharMainFrame:EnableKeyboard(want)
                end
            end)

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
            SC_DeferRefresh()
        end

    elseif event == "PLAYER_TALENT_UPDATE"
        or event == "CHARACTER_POINTS_CHANGED" then
        if SC._mainVisible then
            SC_DeferRefresh()
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
            SC_DeferRefresh()
        end

    elseif event == "TRADE_SHOW" then
        -- Trade opened: do nothing. SlyChar stays open (they coexist).
        -- User can close SlyChar manually if it's in the way.

    elseif event == "UPDATE_BATTLEFIELD_SCORE" then
        -- Fires when BG score updates (end of BG, periodic updates).
        -- Always update cache; also re-render if honor wing is open.
        if SC_FetchHonorCache then SC_FetchHonorCache() end
        if SC_RefreshHonor    then SC_RefreshHonor()    end

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
        -- Honor/PvP data arrives asynchronously from the server after zone-in.
        -- Poll at 2.5 s, 6 s, and 12 s; stop early once we receive any data.
        -- SC_DeferRefresh is only needed when the panel is already visible.
        SC._honorRetrying = false   -- reset retry guard for SC_RefreshHonor
        local _honorFetched = false
        local function _tryFetchHonor()
            if _honorFetched then return end
            if not SC_FetchHonorCache then return end
            local c = SC_FetchHonorCache()
            if (c.honorCurr or 0) > 0 or (c.twHK or 0) > 0 or (c.lfHK or 0) > 0 then
                -- Keep retrying (don't set _honorFetched) until arena bracket data
                -- also loads — GetPersonalRatedInfo returns 0 for several seconds
                -- after zone-in.  All 3 timers (2.5/6/12s) are allowed to fire.
                local hasArena = c.arenaRatings and next(c.arenaRatings) ~= nil
                if hasArena then _honorFetched = true end
                if SC_RefreshHonor then SC_RefreshHonor() end
            end
        end
        C_Timer.After(2.5,  function()
            _tryFetchHonor()
            if SC._mainVisible and SC_DeferRefresh then SC_DeferRefresh() end
        end)
        C_Timer.After(6.0,  _tryFetchHonor)
        C_Timer.After(12.0, _tryFetchHonor)

    elseif event == "PLAYER_REGEN_DISABLED" then
        local cfShown = CharacterFrame and CharacterFrame:IsShown()
        dbg("REGEN_DISABLED cfShown="..tostring(cfShown).." mainVis="..tostring(SC._mainVisible))
        -- SlyCharMainFrame intentionally stays open during combat — the player
        -- may want to review gear/stats mid-fight.  Only suppress CharacterFrame
        -- (the Blizzard managed frame that can't safely stay open in combat).
        if cfShown then SC_SuppressCharacterFrame() end

    elseif event == "PLAYER_REGEN_ENABLED" then
        dbg("REGEN_ENABLED pendingCF="..tostring(SC._pendingCharFrame))
        -- If the user clicked CHR during combat, open CharacterFrame now.
        if SC._pendingCharFrame then
            SC._pendingCharFrame = false
            C_Timer.After(0.1, function()
                if not CharacterFrame:IsShown() then
                    SC._skipHook = true
                    CharacterFrame:Show()
                    CharacterFrame:SetFrameStrata("DIALOG")
                    CharacterFrame:Raise()
                    if CharacterFrame_ShowPanel then
                        CharacterFrame_ShowPanel("PaperDollFrame")
                    end
                    SC._skipHook = false
                end
            end)
        end
        -- If player pressed C during combat before the frame was built, open it now.
        if SC._pendingBuild then
            SC._pendingBuild = false
            SC_ShowMain()
        end
    end
end)
