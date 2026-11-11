-- ============================================================
-- SlyForever_CharTabs  (v0.4.0)
-- Adds a tab to the WoW Forever character sheet, placed directly UNDER the
-- native Reputation / Skills / Currency tabs, hosting ItemRackRevived gear sets
-- and SlySuite_Slot action bar profiles.
--
-- Taint-safety design:
--   * Our tab and pane are our own frames, children of CharacterFrame.
--   * We never write to Blizzard tables (numTabs / selectedTab / tab lists) and
--     never call Blizzard tab-switching functions; we only HOOK them to close
--     our pane when the user picks something native.
--   * Native tab visuals are toggled per-button via PanelTemplates helpers in pcall.
--
-- Self-diagnostics: the addon records the native tab layout and any Lua errors
-- into SlyForeverCharTabsDB.diag / .errors (written to SavedVariables on
-- /reload or logout) so problems can be fixed without screenshots.
-- ============================================================

local ADDON_NAME = ...

local SFC = { version = "0.5.0" }
SlyForeverCharTabs = SFC

local DB_DEFAULTS = { selectedSubTab = "gear", bars = {} }
local ROW_H       = 20
local MAX_ROWS    = 20
local CONTENT_W   = 360
local TAB_LABELS  = { "reput", "skill", "currenc", "honor" }   -- native tab text fragments

local ui = {
    host     = nil,   -- CharacterFrame
    tab      = nil,
    tabKind  = nil,   -- "template:<name>" | "manual"
    pane     = nil,
    built    = false,
    open     = false,
    deselected = {},  -- native tabs we visually deselected while open
    hooked   = {},    -- [frame] = { [script] = true }
}

-- -------------------------------------------------------
-- Helpers / diagnostics
-- -------------------------------------------------------
local function Msg(text)
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ccff[SlyForever]|r " .. tostring(text or ""))
end

local function EnsureDB()
    SlyForeverCharTabsDB = SlyForeverCharTabsDB or {}
    for k, v in pairs(DB_DEFAULTS) do
        if SlyForeverCharTabsDB[k] == nil then SlyForeverCharTabsDB[k] = v end
    end
end

local function LogError(where, err)
    EnsureDB()
    local e = SlyForeverCharTabsDB.errors
    if type(e) ~= "table" then e = {}; SlyForeverCharTabsDB.errors = e end
    e[#e + 1] = date("%H:%M:%S") .. " [" .. where .. "] " .. tostring(err)
    while #e > 30 do table.remove(e, 1) end
end

-- Wrap a function so Lua errors are recorded (and shown once) instead of vanishing.
local function Guard(where, fn)
    return function(...)
        local ok, err = pcall(fn, ...)
        if not ok then
            LogError(where, err)
            Msg("|cffff6060error in " .. where .. ":|r " .. tostring(err))
        end
    end
end

local function SafeCall(fn, ...)
    if type(fn) ~= "function" then return false end
    return pcall(fn, ...)
end

local function HookOnce(frame, script, fn)
    if not frame or not frame.HookScript then return end
    ui.hooked[frame] = ui.hooked[frame] or {}
    if ui.hooked[frame][script] then return end
    ui.hooked[frame][script] = true
    pcall(frame.HookScript, frame, script, fn)
end

local function MakeButton(parent, text, w, h)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(w, h)
    b:SetText(text)
    return b
end

-- -------------------------------------------------------
-- Native tab discovery
-- A "native tab" = a shown Button that is (a) named CharacterFrameTab<N>, or
-- (b) a direct child / grandchild of CharacterFrame whose text looks like
-- Reputation / Skills / Currency / Honor.
-- -------------------------------------------------------
local function LabelOf(f)
    local txt
    pcall(function()
        if f.GetText then txt = f:GetText() end
        if (type(txt) ~= "string" or txt == "") and f.Text and f.Text.GetText then txt = f.Text:GetText() end
        if (type(txt) ~= "string" or txt == "") and f.GetFontString then
            local fs = f:GetFontString()
            if fs then txt = fs:GetText() end
        end
    end)
    if type(txt) == "string" and txt ~= "" then return txt end
    return nil
end

local function LooksLikeTab(f)
    local name = f.GetName and f:GetName()
    if type(name) == "string" and name:match("^CharacterFrameTab%d+$") then return true end
    local label = LabelOf(f)
    if label then
        local ok, low = pcall(string.lower, label)
        if ok then
            for _, frag in ipairs(TAB_LABELS) do
                if low:find(frag, 1, true) then return true end
            end
        end
    end
    return false
end

-- Forever's redesigned sheet keeps its right-hand mode tabs inside CharacterFrameModeTabs.
local function ModeTabList()
    local mt = _G.CharacterFrameModeTabs
    if not (mt and mt.GetChildren) then return nil end
    local function filter(level)
        local out = {}
        for _, f in ipairs(level) do
            if f ~= ui.tab and f ~= ui.pane and f:IsShown() and (f:GetWidth() or 0) >= 16 and (f:GetHeight() or 0) >= 16 then
                out[#out + 1] = f
            end
        end
        return out
    end
    local shown = filter({ mt:GetChildren() })
    for _ = 1, 3 do
        if #shown ~= 1 then break end
        local deeper = filter({ shown[1]:GetChildren() })
        if #deeper == 0 then break end
        shown = deeper
    end
    return shown
end

local function NativeTabs()
    local host = ui.host or _G.CharacterFrame
    local list, seen = {}, {}
    if not host then return list end
    local modeTabs = ModeTabList()
    if modeTabs and #modeTabs > 0 then return modeTabs end
    local function consider(f)
        if f ~= ui.tab and f ~= ui.pane and not seen[f] then
            seen[f] = true
            local t = f.GetObjectType and f:GetObjectType()
            if (t == "Button" or t == "CheckButton") and f:IsShown() and LooksLikeTab(f) then
                list[#list + 1] = f
            end
        end
    end
    for _, c1 in ipairs({ host:GetChildren() }) do
        consider(c1)
        for _, c2 in ipairs({ c1:GetChildren() }) do consider(c2) end
    end
    return list
end

-- Pick the tab our button should sit under: the lowest one; ties -> leftmost.
local function PickAnchorTab(tabs)
    local best, bestBottom, bestLeft
    for _, t in ipairs(tabs) do
        local b, l = t:GetBottom(), t:GetLeft()
        if b and l then
            if not best or b < bestBottom - 2 or (math.abs(b - bestBottom) <= 2 and l < bestLeft) then
                best, bestBottom, bestLeft = t, b, l
            end
        end
    end
    return best
end

-- -------------------------------------------------------
-- Data providers
-- -------------------------------------------------------
local function GearAvailable()
    return type(IRR_GetSetNames) == "function" and type(IRR_SaveCurrentSet) == "function"
        and IRR ~= nil and IRR.chardata ~= nil
end

-- Bar profiles are self-contained (SlyForeverCharTabsDB.bars); no SlySuite_Slot needed.
local function BarsDB()
    EnsureDB()
    if type(SlyForeverCharTabsDB.bars) ~= "table" then SlyForeverCharTabsDB.bars = {} end
    return SlyForeverCharTabsDB.bars
end

local function BarsAvailable() return true end

local BAR_SLOTS = {}
for s = 1, 120 do BAR_SLOTS[#BAR_SLOTS + 1] = s end
for s = 145, 180 do BAR_SLOTS[#BAR_SLOTS + 1] = s end

local function IsSecret(v)
    return type(issecretvalue) == "function" and issecretvalue(v)
end

local function PickSpell(id)
    if C_Spell and C_Spell.PickupSpell then C_Spell.PickupSpell(id) elseif PickupSpell then PickupSpell(id) end
end

local function PickItem(id)
    if C_Item and C_Item.PickupItem then C_Item.PickupItem(id) elseif PickupItem then PickupItem(id) end
end

local function FindOrCreateMacro(name, icon, body)
    local numGlobal, numChar = GetNumMacros()
    for i = 1, (numGlobal or 0) + (numChar or 0) do
        if (GetMacroInfo(i)) == name then return i end
    end
    local ok, idx = pcall(CreateMacro, name, icon or "INV_Misc_QuestionMark", body or "", false)
    if ok then return idx end
    return nil
end

local function SaveBars(name)
    local slots, count = {}, 0
    for _, s in ipairs(BAR_SLOTS) do
        local ok, aType, aId = pcall(GetActionInfo, s)
        if ok and aType and aId and not IsSecret(aType) and not IsSecret(aId) then
            if aType == "spell" or aType == "item" then
                slots[s] = { type = aType, id = aId }; count = count + 1
            elseif aType == "macro" then
                local mName, mIcon, mBody = GetMacroInfo(aId)
                if mName then
                    slots[s] = { type = "macro", mName = mName, mIcon = mIcon, mBody = mBody or "" }
                    count = count + 1
                end
            end
        end
    end
    BarsDB()[name] = slots
    return count
end

local function LoadBars(name)
    local profile = BarsDB()[name]
    if not profile then return false, "Profile not found: " .. name end
    if name ~= "AutoBackup" then SaveBars("AutoBackup") end   -- one level of undo
    ClearCursor()
    for s in pairs(profile) do
        if HasAction(s) then PickupAction(s); ClearCursor() end
    end
    local placed = 0
    for s, e in pairs(profile) do
        local ok = false
        if e.type == "spell" then ok = pcall(PickSpell, e.id)
        elseif e.type == "item" then ok = pcall(PickItem, e.id)
        elseif e.type == "macro" then
            local idx = FindOrCreateMacro(e.mName, e.mIcon, e.mBody)
            if idx then ok = pcall(PickupMacro, idx) end
        end
        if ok then PlaceAction(s); placed = placed + 1 end
        ClearCursor()
    end
    return true, placed
end

local function GearNames()
    if not GearAvailable() then return {} end
    local ok, names = pcall(IRR_GetSetNames)
    return (ok and type(names) == "table") and names or {}
end

local function BarNames()
    local t = {}
    for n in pairs(BarsDB()) do
        if n ~= "AutoBackup" then t[#t + 1] = n end
    end
    table.sort(t)
    return t
end

local function FirstFreeName(prefix, names)
    local used = {}
    for _, n in ipairs(names) do used[n] = true end
    local i = 1
    while used[prefix .. " " .. i] do i = i + 1 end
    return prefix .. " " .. i
end

local MODES = {
    gear = {
        title       = "Gear Sets",
        hint        = "Saves the gear you are wearing right now.",
        openLabel   = "ItemRack",
        unavailable = "ItemRackRevived is not loaded.",
        prefix      = "Set",
        available   = GearAvailable,
        getNames    = GearNames,
        save = function(n)
            local ok, res = pcall(IRR_SaveCurrentSet, n)
            if not ok then LogError("IRR_SaveCurrentSet", res); Msg("Save failed: " .. tostring(res)); return false end
            return res and true or false      -- ItemRackRevived prints its own confirmation
        end,
        load = function(n)
            if InCombatLockdown() then Msg("Cannot swap gear in combat."); return end
            local ok, err = pcall(IRR_LoadSet, n)
            if not ok then LogError("IRR_LoadSet", err); Msg("Load failed: " .. tostring(err)) end
        end,
        delete = function(n)
            local ok, err = pcall(IRR_DeleteSet, n)
            if not ok then LogError("IRR_DeleteSet", err); Msg("Delete failed: " .. tostring(err)) end
        end,
        open = function()
            if type(IRR_ToggleUI) == "function" then IRR_ToggleUI() else Msg("ItemRack UI not available.") end
        end,
    },
    bars = {
        title       = "Bar Profiles",
        hint        = "Saves your current action bars.",
        openLabel   = "Undo Load",
        unavailable = "Bar profiles unavailable.",
        prefix      = "Bars",
        available   = BarsAvailable,
        getNames    = BarNames,
        save = function(n)
            local ok, count = pcall(SaveBars, n)
            if not ok then LogError("SaveBars", count); Msg("Save failed: " .. tostring(count)); return false end
            Msg("Bar profile |cffffcc00" .. n .. "|r saved (" .. count .. " actions).")
            return true
        end,
        load = function(n)
            if InCombatLockdown() then Msg("Cannot change action bars in combat."); return end
            local ok, res, placed = pcall(LoadBars, n)
            if not ok then LogError("LoadBars", res); Msg("Load failed: " .. tostring(res)); return end
            if not res then Msg(placed or "Load failed."); return end
            Msg("Bar profile |cffffcc00" .. n .. "|r loaded (" .. tostring(placed) .. " actions).")
        end,
        delete = function(n)
            BarsDB()[n] = nil
        end,
        open = function()
            if not BarsDB().AutoBackup then Msg("No previous bars to restore yet."); return end
            local ok, res, placed = pcall(LoadBars, "AutoBackup")
            if not ok then LogError("LoadBars", res); Msg("Undo failed: " .. tostring(res)); return end
            Msg("Restored your bars from before the last load (" .. tostring(placed) .. " actions).")
        end,
    },
}

-- -------------------------------------------------------
-- The pane (one frame, two modes). Overlays the character sheet content area.
-- -------------------------------------------------------
local function BuildPane(host)
    local pane = CreateFrame("Frame", "SlyForeverCharTabsPane", host)
    pane:SetFrameLevel(host:GetFrameLevel() + 200)
    pane:EnableMouse(true)          -- swallow clicks so nothing underneath reacts
    pane:EnableMouseWheel(true)
    pane.mode, pane.offset, pane.visible, pane.selected, pane.rows = "gear", 0, 8, nil, {}

    local bg = pane:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.04, 0.04, 0.06, 1)

    -- Centered content column (keeps controls readable when the sheet is wide).
    local c = CreateFrame("Frame", nil, pane)
    c:SetPoint("TOP", pane, "TOP", 0, 0)
    c:SetPoint("BOTTOM", pane, "BOTTOM", 0, 0)
    c:SetWidth(CONTENT_W)
    pane.content = c
    pane:SetScript("OnSizeChanged", function(self, w, h)
        c:SetWidth(math.max(220, math.min(CONTENT_W, (w or CONTENT_W) - 16)))
        self.visible = math.max(4, math.min(MAX_ROWS, math.floor(((h or 330) - 128) / ROW_H)))
        if self:IsShown() then self:Refresh() end
    end)

    -- mode toggle -----------------------------------------
    pane.gearBtn = MakeButton(c, "Gear Sets", 10, 24)
    pane.gearBtn:SetPoint("TOPLEFT",  c, "TOPLEFT", 6, -8)
    pane.gearBtn:SetPoint("TOPRIGHT", c, "TOP",    -2, -8)
    pane.barsBtn = MakeButton(c, "Bar Profiles", 10, 24)
    pane.barsBtn:SetPoint("TOPLEFT",  c, "TOP",      2, -8)
    pane.barsBtn:SetPoint("TOPRIGHT", c, "TOPRIGHT", -6, -8)

    pane.title = c:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    pane.title:SetPoint("TOPLEFT", c, "TOPLEFT", 10, -38)
    pane.count = c:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    pane.count:SetPoint("LEFT", pane.title, "RIGHT", 6, 0)
    pane.hint = c:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    pane.hint:SetPoint("TOPLEFT",  c, "TOPLEFT",  10, -58)
    pane.hint:SetPoint("TOPRIGHT", c, "TOPRIGHT", -10, -58)
    pane.hint:SetJustifyH("LEFT")
    pane.hint:SetWordWrap(false)

    -- name box + buttons ----------------------------------
    local ok, box = pcall(CreateFrame, "EditBox", nil, c, "InputBoxTemplate")
    if not (ok and box) then
        box = CreateFrame("EditBox", nil, c)
        box:SetFontObject("ChatFontNormal")
        box:SetTextInsets(4, 4, 0, 0)
        local ebg = box:CreateTexture(nil, "BACKGROUND")
        ebg:SetAllPoints()
        ebg:SetColorTexture(0, 0, 0, 0.6)
    end
    box:SetHeight(22)
    box:SetPoint("TOPLEFT",  c, "TOPLEFT",  16, -76)
    box:SetPoint("TOPRIGHT", c, "TOPRIGHT", -10, -76)
    box:SetAutoFocus(false)
    box:SetMaxLetters(40)
    box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    pane.nameBox = box

    pane.saveBtn = MakeButton(c, "Save Current", 10, 24)
    pane.saveBtn:SetPoint("TOPLEFT",  c, "TOPLEFT", 6, -102)
    pane.saveBtn:SetPoint("TOPRIGHT", c, "TOP",    -2, -102)
    pane.openBtn = MakeButton(c, "Open", 10, 24)
    pane.openBtn:SetPoint("TOPLEFT",  c, "TOP",      2, -102)
    pane.openBtn:SetPoint("TOPRIGHT", c, "TOPRIGHT", -6, -102)

    -- list ------------------------------------------------
    pane.empty = c:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    pane.empty:SetPoint("TOPLEFT",  c, "TOPLEFT",  12, -140)
    pane.empty:SetPoint("TOPRIGHT", c, "TOPRIGHT", -12, -140)
    pane.empty:SetJustifyH("LEFT")
    pane.empty:SetJustifyV("TOP")

    for i = 1, MAX_ROWS do
        local row = CreateFrame("Button", nil, c)
        row:SetHeight(ROW_H)
        row:SetPoint("TOPLEFT",  c, "TOPLEFT",  6,  -134 - (i - 1) * ROW_H)
        row:SetPoint("TOPRIGHT", c, "TOPRIGHT", -6, -134 - (i - 1) * ROW_H)

        local rbg = row:CreateTexture(nil, "BACKGROUND")
        rbg:SetAllPoints()
        rbg:SetColorTexture(1, 1, 1, (i % 2 == 0) and 0.05 or 0)
        row.sel = row:CreateTexture(nil, "BORDER")
        row.sel:SetAllPoints()
        row.sel:SetColorTexture(1, 0.82, 0, 0.18)
        row.sel:Hide()
        local hl = row:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints()
        hl:SetColorTexture(0.3, 0.5, 0.9, 0.2)

        row.del = MakeButton(row, "Del", 44, 18)
        row.del:SetPoint("RIGHT", row, "RIGHT", 0, 0)
        row.load = MakeButton(row, "Load", 44, 18)
        row.load:SetPoint("RIGHT", row.del, "LEFT", -2, 0)

        row.lbl = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        row.lbl:SetPoint("LEFT",  row, "LEFT", 4, 0)
        row.lbl:SetPoint("RIGHT", row.load, "LEFT", -4, 0)
        row.lbl:SetJustifyH("LEFT")
        row.lbl:SetWordWrap(false)

        -- click row = select + copy name into the box (easy overwrite)
        row:SetScript("OnClick", Guard("row click", function(self)
            if not self.name then return end
            pane.selected = self.name
            pane.nameBox:SetText(self.name)
            pane.nameBox:ClearFocus()
            pane:Refresh()
        end))
        row.load:SetScript("OnClick", Guard("load click", function()
            if row.name then MODES[pane.mode].load(row.name) end
        end))

        -- delete asks twice (first click arms it for 3s)
        row.del:SetScript("OnClick", Guard("delete click", function(self)
            if not row.name then return end
            if row.armed == row.name then
                row.armed = nil
                self:SetText("Del")
                MODES[pane.mode].delete(row.name)
                if pane.selected == row.name then pane.selected = nil end
                pane:Refresh()
            else
                local armedName = row.name
                row.armed = armedName
                self:SetText("Sure?")
                C_Timer.After(3, function()
                    if row.armed == armedName then
                        row.armed = nil
                        row.del:SetText("Del")
                    end
                end)
            end
        end))

        row:Hide()
        pane.rows[i] = row
    end

    -- behaviour ---------------------------------------
    local DoSave = Guard("save", function()
        local mode = MODES[pane.mode]
        if not mode.available() then Msg(mode.unavailable); return end
        local n = strtrim(pane.nameBox:GetText() or "")
        if n == "" then n = FirstFreeName(mode.prefix, mode.getNames()) end
        if mode.save(n) then
            pane.selected = n
            pane.nameBox:SetText(n)
            pane.nameBox:ClearFocus()
            pane:Refresh()
        end
    end)
    pane.saveBtn:SetScript("OnClick", DoSave)
    pane.nameBox:SetScript("OnEnterPressed", DoSave)
    pane.openBtn:SetScript("OnClick", Guard("open click", function() MODES[pane.mode].open() end))
    pane.gearBtn:SetScript("OnClick", Guard("gear mode", function() pane:SetMode("gear") end))
    pane.barsBtn:SetScript("OnClick", Guard("bars mode", function() pane:SetMode("bars") end))

    function pane:Refresh()
        local mode  = MODES[self.mode]
        local avail = mode.available()
        local names = avail and mode.getNames() or {}
        local vis   = self.visible
        local maxOff = math.max(0, #names - vis)
        if self.offset > maxOff then self.offset = maxOff end
        if self.offset < 0 then self.offset = 0 end

        for i = 1, MAX_ROWS do
            local row  = self.rows[i]
            local name = (i <= vis) and names[i + self.offset] or nil
            if name then
                row.name = name
                row.lbl:SetText(name)
                row.sel:SetShown(name == self.selected)
                row.armed = nil
                row.del:SetText("Del")
                row:Show()
            else
                row.name = nil
                row:Hide()
            end
        end

        self.count:SetText(avail and ("(" .. #names .. ")") or "")
        if not avail then
            self.empty:SetText("|cffff6060" .. mode.unavailable .. "|r")
        elseif #names == 0 then
            self.empty:SetText("Nothing saved yet. Optionally type a name above, then press Save Current.")
        else
            self.empty:SetText("")
        end
        self.saveBtn:SetEnabled(avail)
    end

    function pane:SetMode(key)
        if not MODES[key] then key = "gear" end
        self.mode, self.offset, self.selected = key, 0, nil
        if SlyForeverCharTabsDB then SlyForeverCharTabsDB.selectedSubTab = key end
        local mode = MODES[key]
        self.title:SetText(mode.title)
        self.hint:SetText(mode.hint)
        self.openBtn:SetText(mode.openLabel)
        self.nameBox:SetText("")
        self.gearBtn:SetEnabled(key ~= "gear")
        self.barsBtn:SetEnabled(key ~= "bars")
        self:Refresh()
    end

    pane:SetScript("OnMouseWheel", function(self, delta)
        self.offset = math.max(0, self.offset - delta)
        self:Refresh()
    end)

    pane:Hide()
    return pane
end

-- Cover only the right-hand panel (stats area) so the paper doll stays visible.
local function AnchorPane()
    local pane, host = ui.pane, ui.host
    if not (pane and host) then return end
    pane:ClearAllPoints()
    local rp = _G.CharacterFrameRightPaneHost
    if rp and rp.GetObjectType then
        pane:SetPoint("TOPLEFT", rp, "TOPLEFT", 0, 0)
        pane:SetPoint("BOTTOMRIGHT", rp, "BOTTOMRIGHT", 0, 0)
        return
    end
    pane:SetPoint("TOPRIGHT", host, "TOPRIGHT", -4, -20)
    pane:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT", -4, 4)
    pane:SetWidth(233)
end

-- -------------------------------------------------------
-- Tab visuals + open/close
-- -------------------------------------------------------
local function SelectOurTab()
    if not ui.tab then return end
    if ui.tab.sel then ui.tab.sel:Show() end
end

local function DeselectOurTab()
    if not ui.tab then return end
    if ui.tab.sel then ui.tab.sel:Hide() end
end

local function ClosePane(restoreNative)
    if not ui.open then return end
    ui.open = false
    if ui.pane then ui.pane:Hide() end
    DeselectOurTab()
    if restoreNative then
        for _, t in ipairs(ui.deselected) do SafeCall(PanelTemplates_SelectTab, t) end
    end
    ui.deselected = {}
end

local function OpenPane(mode)
    if not ui.built then return end
    if not ui.host:IsShown() then
        if InCombatLockdown() then Msg("Open the character sheet first."); return end
        SafeCall(ToggleCharacter, "PaperDollFrame")
        if not ui.host:IsShown() then Msg("Could not open the character sheet."); return end
    end
    if not ui.open then
        AnchorPane()
        ui.deselected = {}
        ui.open = true
        SelectOurTab()
        ui.pane:Show()
    end
    ui.pane:SetMode(mode or (SlyForeverCharTabsDB and SlyForeverCharTabsDB.selectedSubTab) or "gear")
end

-- -------------------------------------------------------
-- Tab creation / placement (underneath the native tabs)
-- -------------------------------------------------------
-- Our tab is a plain Button; its background is cloned from a native mode tab (see StyleLike)
-- so it looks native without depending on any Blizzard template.
local function CreateTab(host)
    local tab = CreateFrame("Button", "SlyForeverCharTab", host)
    ui.tabKind = "clone"
    tab:SetSize(64, 64)
    tab:SetID(100)
    tab.icon = tab:CreateTexture(nil, "ARTWORK")
    tab.icon:SetTexture("Interface\\Icons\\INV_Misc_Book_09")
    tab.icon:SetSize(32, 32)
    tab.icon:SetPoint("CENTER", tab, "CENTER", 0, 0)
    tab.sel = tab:CreateTexture(nil, "OVERLAY")
    tab.sel:SetAllPoints()
    tab.sel:SetColorTexture(1, 0.82, 0, 0.22)
    tab.sel:Hide()
    tab.hl = tab:CreateTexture(nil, "HIGHLIGHT")
    tab.hl:SetAllPoints()
    tab.hl:SetColorTexture(1, 1, 1, 0.12)
    tab:SetScript("OnClick", Guard("tab click", function()
        if ui.open then ClosePane(true) else OpenPane() end
    end))
    tab:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Gear Sets & Bar Profiles", 1, 1, 1)
        GameTooltip:AddLine("Save and load ItemRack gear sets and action bar layouts.", 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    tab:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return tab
end

-- Copy the visible background textures of a native tab onto ours (best effort).
local function StyleLike(tab, src)
    if ui.styled == src then return end
    ui.styled = src
    local w, h = tab:GetWidth(), tab:GetHeight()
    local n = 0
    pcall(function()
        local hlTex = src.GetHighlightTexture and src:GetHighlightTexture()
        for _, r in ipairs({ src:GetRegions() }) do
            if r ~= hlTex and r.GetObjectType and r:GetObjectType() == "Texture" and r:IsShown() then
                local atlas = r.GetAtlas and r:GetAtlas()
                local rw, rh = r:GetSize()
                if type(atlas) == "string" and atlas:find("sidetab", 1, true) and rw and rh and rw >= w * 0.6 and rh >= h * 0.6 then
                    local layer, sub = r:GetDrawLayer()
                    local t = tab:CreateTexture(nil, layer == "HIGHLIGHT" and "BACKGROUND" or layer, nil, math.min(sub or 0, 6))
                    t:SetAtlas(atlas)
                    t:SetAllPoints(tab)
                    n = n + 1
                end
            end
        end
        for _, r in ipairs({ src:GetRegions() }) do   -- mirror the native icon's size/position
            if r ~= hlTex and r.GetObjectType and r:GetObjectType() == "Texture" and r:IsShown() then
                local atlas = r.GetAtlas and r:GetAtlas()
                local rw, rh = r:GetSize()
                if not (type(atlas) == "string" and atlas:find("sidetab", 1, true)) and rw and rh and rw > 8 and rw < w * 0.95 then
                    tab.icon:SetSize(rw, rh)
                    local p, rel, rp, x, y = r:GetPoint(1)
                    if p and rel == src then
                        tab.icon:ClearAllPoints()
                        tab.icon:SetPoint(p, tab, rp, x or 0, y or 0)
                    end
                    break
                end
            end
        end
        local hlAtlas = hlTex and hlTex.GetAtlas and hlTex:GetAtlas()
        if hlAtlas then
            tab.hl:SetAtlas(hlAtlas)
            tab.hl:SetAlpha(1)
        end
    end)
    if n == 0 then                                  -- nothing to copy: simple dark plate
        local bg = tab:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetColorTexture(0.08, 0.08, 0.1, 0.9)
    end
end

local PositionTab = Guard("PositionTab", function()
    local tab, host = ui.tab, ui.host
    if not (tab and host) then return end

    local tabs = NativeTabs()
    for _, t in ipairs(tabs) do                      -- close our pane when a native tab is used
        HookOnce(t, "OnClick",     function() ClosePane(false) end)
        HookOnce(t, "OnMouseDown", function() ClosePane(false) end)
        HookOnce(t, "OnShow",      function() C_Timer.After(0, ui.reposition) end)
        HookOnce(t, "OnHide",      function() C_Timer.After(0, ui.reposition) end)
    end

    tab:ClearAllPoints()
    local anchor = PickAnchorTab(tabs)
    if not anchor then
        local mt = _G.CharacterFrameModeTabs
        if mt then
            tab:SetPoint("TOPLEFT", mt, "TOPLEFT", 0, 0)
        else
            tab:SetPoint("TOPLEFT", host, "TOPRIGHT", 0, -30)
        end
        return
    end

    -- Match the native tabs' size and the vertical spacing between them.
    local w, h = anchor:GetWidth(), anchor:GetHeight()
    if w and h and w > 10 and h > 10 then tab:SetSize(w, h) end
    StyleLike(tab, anchor)

    local gap = nil
    for _, t in ipairs(tabs) do                      -- spacing to the nearest tab above anchor
        if t ~= anchor then
            local tb, tl = t:GetBottom(), t:GetLeft()
            local at, al = anchor:GetTop(), anchor:GetLeft()
            if tb and tl and at and al and math.abs(tl - al) <= 2 and tb >= at - 1 then
                local d = math.max(0, tb - at)
                if not gap or d < gap then gap = d end
            end
        end
    end
    gap = math.min(gap or 2, 12)
    tab:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -gap)
    tab:SetFrameLevel(anchor:GetFrameLevel())
end)
ui.reposition = PositionTab

-- -------------------------------------------------------
-- Diagnostics (recorded into SavedVariables for offline inspection)
-- -------------------------------------------------------
local function Describe(f)
    local parts = {}
    local function add(s) parts[#parts + 1] = s end
    pcall(function()
        add(("%s <%s>"):format(tostring(f:GetName() or "(anon)"), tostring(f:GetObjectType())))
        add(("shown=%s"):format(tostring(f:IsShown())))
        add(("size=%.0fx%.0f"):format(f:GetWidth() or 0, f:GetHeight() or 0))
        add(("L=%s B=%s"):format(tostring(f:GetLeft() and math.floor(f:GetLeft())), tostring(f:GetBottom() and math.floor(f:GetBottom()))))
        add(("id=%s"):format(tostring(f.GetID and f:GetID())))
        add(("text=%s"):format(tostring(LabelOf(f))))
        local par = f:GetParent()
        add(("parent=%s"):format(tostring(par and (par:GetName() or par:GetObjectType()))))
        if f.IsEnabled then add(("enabled=%s"):format(tostring(f:IsEnabled()))) end
        for i = 1, (f.GetNumPoints and f:GetNumPoints() or 0) do
            local p, rel, rp, x, y = f:GetPoint(i)
            add(("pt%d=%s>%s:%s(%.0f,%.0f)"):format(i, tostring(p), rel and tostring(rel:GetName() or rel:GetObjectType()) or "nil", tostring(rp), x or 0, y or 0))
        end
        local regs = {}
        for _, r in ipairs({ f:GetRegions() }) do
            if r.GetObjectType and r:GetObjectType() == "Texture" then
                regs[#regs + 1] = tostring(r.GetAtlas and r:GetAtlas() or r:GetTexture())
            end
            if #regs >= 4 then break end
        end
        if #regs > 0 then add("tex=" .. table.concat(regs, ",")) end
    end)
    return table.concat(parts, "  ")
end

local CollectDiag = Guard("CollectDiag", function()
    EnsureDB()
    local host = _G.CharacterFrame
    local d = { "v" .. SFC.version .. "  " .. date("%Y-%m-%d %H:%M:%S") }
    local function add(s) d[#d + 1] = s end
    if not host then add("CharacterFrame = nil"); SlyForeverCharTabsDB.diag = d; return end

    add("CharacterFrame: " .. Describe(host))
    add(("TabSystem=%s Inset=%s InsetRight=%s PaperDollFrame=%s numTabs=%s selectedTab=%s tabKind=%s open=%s"):format(
        tostring(host.TabSystem ~= nil), tostring((host.Inset or _G.CharacterFrameInset) ~= nil),
        tostring(host.InsetRight ~= nil), tostring(_G.PaperDollFrame ~= nil),
        tostring(host.numTabs), tostring(host.selectedTab), tostring(ui.tabKind), tostring(ui.open)))
    local i = 1
    while _G["CharacterFrameTab" .. i] do
        add("  CharacterFrameTab" .. i .. ": " .. Describe(_G["CharacterFrameTab" .. i]))
        i = i + 1
    end
    add("-- candidate native tabs (shown, label/name match) --")
    for _, t in ipairs(NativeTabs()) do add("  " .. Describe(t)) end
    add("-- direct children of CharacterFrame --")
    local n = 0
    for _, c in ipairs({ host:GetChildren() }) do
        n = n + 1
        if n <= 40 then add("  " .. Describe(c)) end
    end
    local mt = _G.CharacterFrameModeTabs
    if mt then
        add("-- CharacterFrameModeTabs tree --")
        local count = 0
        local function walk(f, depth)
            for _, c in ipairs({ f:GetChildren() }) do
                count = count + 1
                if count <= 60 then add(("  "):rep(depth) .. Describe(c)) end
                if depth < 3 then walk(c, depth + 1) end
            end
        end
        walk(mt, 1)
    end
    if ui.tab then add("OURTAB: " .. Describe(ui.tab)) end
    if ui.pane then add("OURPANE: " .. Describe(ui.pane)) end
    add(("gearAvailable=%s barsAvailable=%s bars=%s IRR.chardata=%s"):format(
        tostring(GearAvailable()), tostring(BarsAvailable()),
        tostring(#BarNames()), tostring(IRR and IRR.chardata ~= nil)))
    SlyForeverCharTabsDB.diag = d
end)

-- -------------------------------------------------------
-- Build
-- -------------------------------------------------------
local Build = Guard("Build", function()
    if ui.built then return end
    local host = _G.CharacterFrame
    if not host then return end
    ui.host = host
    ui.tab  = CreateTab(host)
    ui.pane = BuildPane(host)
    ui.built = true

    PositionTab()
    HookOnce(host, "OnShow", function()
        PositionTab()
        C_Timer.After(0, PositionTab)
        C_Timer.After(0.5, CollectDiag)
    end)
    HookOnce(host, "OnHide", function() ClosePane(true) end)
    for _, nm in ipairs({ "PaperDollFrame", "ReputationFrame", "SkillsFrame", "TokenFrame", "PVPRankFrame", "StatisticsFrame" }) do
        local sub = _G[nm]
        if sub then HookOnce(sub, "OnShow", function() ClosePane(false) end) end
    end
    if type(_G.CharacterFrame_ShowSubFrame) == "function" then
        hooksecurefunc("CharacterFrame_ShowSubFrame", function() ClosePane(false) end)
    end
    if type(_G.ToggleCharacter) == "function" then
        hooksecurefunc("ToggleCharacter", function() if ui.open and ui.host:IsShown() then ClosePane(false) end end)
    end
    CollectDiag()
end)

-- -------------------------------------------------------
-- Events / slash
-- -------------------------------------------------------
local ef = CreateFrame("Frame")
ef:RegisterEvent("ADDON_LOADED")
ef:RegisterEvent("PLAYER_LOGIN")
ef:RegisterEvent("PLAYER_ENTERING_WORLD")
ef:RegisterEvent("PLAYER_LOGOUT")
ef:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 == ADDON_NAME then
            EnsureDB()
            if _G.CharacterFrame then Build() end
        elseif not ui.built and _G.CharacterFrame then
            C_Timer.After(0, Build)
        end
    elseif event == "PLAYER_LOGOUT" then
        CollectDiag()
    else
        EnsureDB()
        if not ui.built then C_Timer.After(0.5, Build) end
        C_Timer.After(1.0, PositionTab)
    end
end)

SLASH_SLYFOREVERTABS1 = "/slytabs"
SlashCmdList["SLYFOREVERTABS"] = Guard("slash", function(msg)
    msg = strtrim(msg or ""):lower()
    Build()
    if not ui.built then Msg("CharacterFrame not available yet."); return end
    if msg == "dump" then
        PositionTab()
        CollectDiag()
        Msg("Layout recorded; /reload to write it to SavedVariables.")
    elseif msg == "gear" or msg == "bars" then
        OpenPane(msg)
    elseif ui.open then
        ClosePane(true)
    else
        OpenPane()
    end
end)
