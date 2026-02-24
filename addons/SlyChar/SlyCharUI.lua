-- ============================================================
-- SlyCharUI.lua
-- Movable character sheet: gear slots, player model,
-- Stats tab (base + ECS), Gear Sets tab (IRR)
-- Left-click slot -> ItemRack-style gear picker popup
-- ============================================================

-- TBC Anniversary: C_Container is present on the anniv client;
-- remap bag APIs exactly like the real ItemRack addon does.
local _PickupContainerItem
local _GetContainerNumSlots
local _GetContainerItemID
if C_Container then
    _PickupContainerItem  = C_Container.PickupContainerItem
    _GetContainerNumSlots = C_Container.GetContainerNumSlots
    _GetContainerItemID   = function(bag, slot)
        local info = C_Container.GetContainerItemInfo(bag, slot)
        return info and info.itemID or nil
    end
else
    _PickupContainerItem  = PickupContainerItem
    _GetContainerNumSlots = GetContainerNumSlots
    _GetContainerItemID   = GetContainerItemID
end

SlyCharMainFrame = nil   -- global ref, set at end of SC_BuildMain

-- ---- Layout ----
local FRAME_W      = 732
local FRAME_H      = 448
local HDR_H        = 30
local FOOT_H       = 20
local CHAR_W       = 370
local BTN_STRIP_W  = 32
local SIDE_W       = FRAME_W - CHAR_W - BTN_STRIP_W  -- 330
local WING_W       = 360  -- expandable right-side wing panel
local PAD      = 8
local SLOT_S   = 38
local SLOT_GAP = 5
local SLOT_TOP = -8

local COL_L    = PAD
local COL_R    = CHAR_W - PAD - SLOT_S
local MODEL_X  = COL_L + SLOT_S + PAD
local MODEL_W  = COL_R - PAD - MODEL_X
local MODEL_H  = 280

local COL_H     = 8 * SLOT_S + 7 * SLOT_GAP
local WPN_Y     = SLOT_TOP - COL_H - 6
local WPN_GAP   = 10
local WPN_TOTAL = 3 * SLOT_S + 2 * WPN_GAP
local WPN_START = math.floor((CHAR_W - WPN_TOTAL) / 2)

-- ---- Slot lists ----
local LEFT_SLOTS = {
    {id=1,  label="Head"},    {id=2,  label="Neck"},
    {id=3,  label="Shoulder"},{id=15, label="Back"},
    {id=5,  label="Chest"},   {id=4,  label="Shirt"},
    {id=19, label="Tabard"},  {id=9,  label="Wrist"},
}
local RIGHT_SLOTS = {
    {id=10, label="Hands"},    {id=6,  label="Waist"},
    {id=7,  label="Legs"},     {id=8,  label="Feet"},
    {id=11, label="Ring 1"},   {id=12, label="Ring 2"},
    {id=13, label="Trinket 1"},{id=14, label="Trinket 2"},
}
local WEAPON_SLOTS = {
    {id=16, label="Main Hand"},
    {id=17, label="Off Hand"},
    {id=18, label="Ranged"},
}

local QUALITY_COLORS = {
    [0]={0.62,0.62,0.62}, [1]={1,1,1},
    [2]={0.12,1,0},       [3]={0,0.44,0.87},
    [4]={0.64,0.21,0.93}, [5]={1,0.5,0},
    [6]={0.9,0.8,0.5},
}
local CLASS_COLORS = {
    WARRIOR={0.78,0.61,0.43}, PALADIN={0.96,0.55,0.73},
    HUNTER ={0.67,0.83,0.45}, ROGUE  ={1,0.96,0.41},
    PRIEST ={1,1,1},          SHAMAN ={0,0.44,0.87},
    MAGE   ={0.41,0.8,0.94},  WARLOCK={0.58,0.51,0.79},
    DRUID  ={1,0.49,0.04},
}

-- invtype strings that fit each slot id
local SLOT_INVTYPES = {
    [1] ={INVTYPE_HEAD=true},
    [2] ={INVTYPE_NECK=true},
    [3] ={INVTYPE_SHOULDER=true},
    [4] ={INVTYPE_BODY=true},
    [5] ={INVTYPE_CHEST=true, INVTYPE_ROBE=true},
    [6] ={INVTYPE_WAIST=true},
    [7] ={INVTYPE_LEGS=true},
    [8] ={INVTYPE_FEET=true},
    [9] ={INVTYPE_WRIST=true},
    [10]={INVTYPE_HAND=true},
    [11]={INVTYPE_FINGER=true},
    [12]={INVTYPE_FINGER=true},
    [13]={INVTYPE_TRINKET=true},
    [14]={INVTYPE_TRINKET=true},
    [15]={INVTYPE_CLOAK=true},
    [16]={INVTYPE_WEAPON=true, INVTYPE_2HWEAPON=true, INVTYPE_WEAPONMAINHAND=true},
    [17]={INVTYPE_WEAPONOFFHAND=true, INVTYPE_SHIELD=true, INVTYPE_HOLDABLE=true, INVTYPE_WEAPON=true},
    [18]={INVTYPE_RANGED=true, INVTYPE_RANGEDRIGHT=true, INVTYPE_THROWN=true, INVTYPE_RELIC=true},
    [19]={INVTYPE_TABARD=true},
}

-- ---- Widget refs (module-level) ----
local slotWidgets   = {}
local tabFrames     = {}
local tabBtnWidgets = {}
local statRows      = {}
local setRowWidgets = {}
local repRows       = {}
local skillRows     = {}
local headerName    = nil
local headerInfo    = nil

local MAX_STAT_ROWS  = 60
local MAX_SET_ROWS   = 30
local MAX_REP_ROWS   = 80
local MAX_SKILL_ROWS = 60

-- Wing panel state (spellbook wing still built; side-panel tracker handles the rest)
local wingFrame       = nil
local wingPanes       = {}
local honorValues     = {}
local activeWingKey   = nil
local wingTitleTx     = nil
local currentSidePanel      = nil   -- currently open native side panel
local hookedPanels          = {}    -- frames we've already HookScript'd
local talentFrameHooked     = false -- kept for compat
local spellRows       = {}
local MAX_SPELL_ROWS  = 120
local TAL_SZ          = 32
local TAL_PAD         = 8
local TAL_STEP        = TAL_SZ + TAL_PAD
local TAL_ROWS        = 7
local TAL_COLS        = 4

-- ============================================================
-- Gear Picker (TOOLTIP strata, OnUpdate-based hide timer)
-- ============================================================
local picker              = nil
local pickerRows          = {}
local PICKER_W            = 248
local PICKER_ROW_H        = 26
local PICKER_MAX          = 18
local pickerHideCountdown = 0
local pickerTimerFrame    = nil

local function CancelPickerHide()
    pickerHideCountdown = 0
end

local function SchedulePickerHide()
    pickerHideCountdown = 0.3
end

function SC_HidePicker()
    CancelPickerHide()
    if picker then
        picker._slotId = nil
        picker:Hide()
    end
end

local function SC_BuildPicker()
    local f = CreateFrame("Frame", "SlyCharGearPicker", UIParent)
    f:SetWidth(PICKER_W)
    f:SetHeight(100)
    f:SetFrameStrata("TOOLTIP")
    f:EnableMouse(false)
    f:HookScript("OnShow", function(self) self:EnableMouse(true) end)
    f:HookScript("OnHide", function(self) self:EnableMouse(false) end)
    f:Hide()

    local bord = f:CreateTexture(nil, "OVERLAY")
    bord:SetAllPoints(f)
    bord:SetColorTexture(0.30, 0.30, 0.45, 1)

    local bg = f:CreateTexture(nil, "BACKGROUND")
    bg:SetPoint("TOPLEFT",     f, "TOPLEFT",      1, -1)
    bg:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -1,  1)
    bg:SetColorTexture(0.06, 0.06, 0.10, 0.97)

    local hdrBg = f:CreateTexture(nil, "BORDER")
    hdrBg:SetPoint("TOPLEFT",  f, "TOPLEFT",  1, -1)
    hdrBg:SetPoint("TOPRIGHT", f, "TOPRIGHT", -1, -1)
    hdrBg:SetHeight(20)
    hdrBg:SetColorTexture(0.10, 0.10, 0.18, 1)

    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    title:SetFont(title:GetFont(), 10, "")
    title:SetPoint("TOPLEFT", f, "TOPLEFT", 6, -5)
    title:SetTextColor(0.60, 0.82, 1.00)
    f.title = title

    local sep = f:CreateTexture(nil, "ARTWORK")
    sep:SetHeight(1)
    sep:SetPoint("TOPLEFT",  f, "TOPLEFT",  1, -21)
    sep:SetPoint("TOPRIGHT", f, "TOPRIGHT", -1, -21)
    sep:SetColorTexture(0.20, 0.20, 0.35, 1)

    local content = CreateFrame("Frame", nil, f)
    content:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -22)
    content:SetWidth(PICKER_W - 2)
    f.content = content

    for i = 1, PICKER_MAX do
        local row = CreateFrame("Button", nil, content)
        row:SetSize(PICKER_W - 4, PICKER_ROW_H)
        row:SetPoint("TOPLEFT", content, "TOPLEFT", 2, -((i-1)*PICKER_ROW_H))

        local hl = row:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints(row)
        hl:SetColorTexture(1, 1, 1, 0.10)

        local eqGlow = row:CreateTexture(nil, "BACKGROUND")
        eqGlow:SetAllPoints(row)
        eqGlow:SetColorTexture(0.80, 0.65, 0, 0.14)
        eqGlow:Hide()
        row.eqGlow = eqGlow

        local rowSep = row:CreateTexture(nil, "ARTWORK")
        rowSep:SetHeight(1)
        rowSep:SetPoint("BOTTOMLEFT",  row, "BOTTOMLEFT",  0, 0)
        rowSep:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, 0)
        rowSep:SetColorTexture(0.14, 0.14, 0.20, 1)

        local icn = row:CreateTexture(nil, "ARTWORK")
        icn:SetSize(22, 22)
        icn:SetPoint("LEFT", row, "LEFT", 4, 0)
        icn:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        row.icn = icn

        local nm = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        nm:SetFont(nm:GetFont(), 10, "")
        nm:SetPoint("TOPLEFT", icn, "TOPRIGHT", 4, -1)
        nm:SetWidth(PICKER_W - 80)
        nm:SetJustifyH("LEFT")
        row.nm = nm

        local sub = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        sub:SetFont(sub:GetFont(), 8, "")
        sub:SetPoint("BOTTOMLEFT", icn, "BOTTOMRIGHT", 4, 2)
        sub:SetTextColor(0.50, 0.50, 0.55)
        row.sub = sub

        local ilvl = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        ilvl:SetFont(ilvl:GetFont(), 9, "")
        ilvl:SetPoint("RIGHT", row, "RIGHT", -4, 0)
        ilvl:SetJustifyH("RIGHT")
        ilvl:SetTextColor(0.50, 0.50, 0.55)
        row.ilvl = ilvl

        row:SetScript("OnEnter", function(self)
            if self._itemId then
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetHyperlink("item:" .. self._itemId)
                GameTooltip:Show()
            end
        end)
        row:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)

        row:Hide()
        pickerRows[i] = row
    end

    f:SetScript("OnEnter", function() end)
    f:SetScript("OnLeave", function() end)
    f:SetScript("OnHide",  function(self) self._slotId = nil end)

    -- OnUpdate-based countdown timer (no C_Timer needed)
    pickerTimerFrame = CreateFrame("Frame", nil, UIParent)
    pickerTimerFrame:SetScript("OnUpdate", function(self, elapsed)
        if pickerHideCountdown > 0 then
            pickerHideCountdown = pickerHideCountdown - elapsed
            if pickerHideCountdown <= 0 then
                SC_HidePicker()
            end
        end
    end)

    picker = f
end

function SC_ShowGearPicker(slotId)
    if not picker then SC_BuildPicker() end
    CancelPickerHide()
    picker._slotId = slotId

    local validTypes = SLOT_INVTYPES[slotId]
    if not validTypes then return end
    local currentId  = GetInventoryItemID("player", slotId)

    local items = {}
    local seen  = {}
    seen[currentId or 0] = true

    -- Currently equipped
    if currentId then
        local n,_,q,ilvl,_,_,_,_,_,tex = GetItemInfo(currentId)
        if n then
            items[#items+1] = {
                itemId=currentId, name=n, qual=q or 1,
                ilvl=ilvl or 0, tex=tex, equipped=true,
                src="Equipped", bag=-1, bslot=-1,
            }
        end
    end

    -- Bags 0-4
    for bag = 0, 4 do
        for bs = 1, _GetContainerNumSlots(bag) do
            local id = _GetContainerItemID(bag, bs)
            if id and not seen[id] then
                local n,_,q,ilvl,_,_,_,_,eqLoc,tex = GetItemInfo(id)
                if n and validTypes[eqLoc] then
                    seen[id] = true
                    items[#items+1] = {
                        itemId=id, name=n, qual=q or 1,
                        ilvl=ilvl or 0, tex=tex, equipped=false,
                        src="Bag", bag=bag, bslot=bs,
                    }
                end
            end
        end
    end

    -- Other equipped slots (swap candidates)
    for sid = 1, 19 do
        if sid ~= slotId then
            local id = GetInventoryItemID("player", sid)
            if id and not seen[id] then
                local n,_,q,ilvl,_,_,_,_,eqLoc,tex = GetItemInfo(id)
                if n and validTypes[eqLoc] then
                    seen[id] = true
                    items[#items+1] = {
                        itemId=id, name=n, qual=q or 1,
                        ilvl=ilvl or 0, tex=tex, equipped=false,
                        src="Swap", bag=-1, bslot=-1, fromSlot=sid,
                    }
                end
            end
        end
    end

    -- Sort: equipped first, then ilvl descending
    table.sort(items, function(a, b)
        if a.equipped ~= b.equipped then return a.equipped end
        return (a.ilvl or 0) > (b.ilvl or 0)
    end)

    -- Slot name for title bar
    local slabel = "Slot " .. slotId
    for _,s in ipairs(LEFT_SLOTS)   do if s.id==slotId then slabel=s.label end end
    for _,s in ipairs(RIGHT_SLOTS)  do if s.id==slotId then slabel=s.label end end
    for _,s in ipairs(WEAPON_SLOTS) do if s.id==slotId then slabel=s.label end end
    picker.title:SetText(slabel)

    for i = 1, PICKER_MAX do pickerRows[i]:Hide() end

    local rowCount = 0
    if #items == 0 then
        local row = pickerRows[1]
        row._itemId = nil
        row.nm:SetText("|cff555555No matching items|r")
        row.sub:SetText("") ; row.ilvl:SetText("")
        row.icn:SetTexture("Interface\\PaperDoll\\UI-Backpack-EmptySlot")
        row.icn:SetTexCoord(0, 1, 0, 1)
        row.eqGlow:Hide()
        row:SetScript("OnClick", SC_HidePicker)
        row:Show() ; rowCount = 1
    else
        for i, item in ipairs(items) do
            if i > PICKER_MAX then break end
            local row = pickerRows[i]
            row._itemId = item.itemId
            row._slotId = slotId

            local qc = QUALITY_COLORS[item.qual] or QUALITY_COLORS[1]
            row.nm:SetText(string.format("|cff%02x%02x%02x%s|r",
                qc[1]*255, qc[2]*255, qc[3]*255, item.name))
            row.ilvl:SetText(item.ilvl > 0 and ("i"..item.ilvl) or "")
            row.sub:SetText(item.src)

            if item.tex then
                row.icn:SetTexture(item.tex)
                row.icn:SetTexCoord(0.07, 0.93, 0.07, 0.93)
            else
                row.icn:SetTexture("Interface\\PaperDoll\\UI-Backpack-EmptySlot")
                row.icn:SetTexCoord(0, 1, 0, 1)
            end

            if item.equipped then
                row.eqGlow:Show()
                row.sub:SetTextColor(0.90, 0.76, 0.12)
            else
                row.eqGlow:Hide()
                row.sub:SetTextColor(0.45, 0.45, 0.50)
            end

            local ci = item
            local cs = slotId
            row:SetScript("OnClick", function()
                GameTooltip:Hide()
                -- Guard: never equip if cursor is occupied or a spell is targeting
                if not ci.equipped and not GetCursorInfo() and not SpellIsTargeting() then
                    if ci.bag >= 0 then
                        -- Item in a bag: pick it up then swap into equip slot
                        _PickupContainerItem(ci.bag, ci.bslot)
                        PickupInventoryItem(cs)
                    elseif ci.fromSlot then
                        -- Item already in an equip slot: swap the two slots
                        PickupInventoryItem(ci.fromSlot)
                        PickupInventoryItem(cs)
                    end
                end
                SC_HidePicker()
            end)

            row:Show()
            rowCount = rowCount + 1
        end
    end

    local ch = rowCount * PICKER_ROW_H
    picker.content:SetHeight(ch)
    picker:SetHeight(22 + ch)

    -- Position at cursor (UIParent coords only -- safe across all strata)
    picker:ClearAllPoints()
    local cx, cy = GetCursorPosition()
    local sc     = UIParent:GetEffectiveScale()
    local ux     = cx / sc
    local uy     = cy / sc
    local sw     = GetScreenWidth()
    if ux + PICKER_W + 20 < sw then
        picker:SetPoint("TOPLEFT",  UIParent, "BOTTOMLEFT", ux + 16, uy + 10)
    else
        picker:SetPoint("TOPRIGHT", UIParent, "BOTTOMLEFT", ux - 16, uy + 10)
    end

    picker:Show()
    picker:Raise()
end

-- ============================================================
-- Slot button helpers
-- ============================================================
local function FillBg(f, r, g, b, a)
    local t = f:CreateTexture(nil, "BACKGROUND")
    t:SetAllPoints(f) ; t:SetColorTexture(r, g, b, a or 1)
    return t
end

local function UpdateSlot(w, slotId)
    local tex = GetInventoryItemTexture("player", slotId)
    if tex then
        w.icon:SetTexture(tex)
        w.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        w.icon:SetVertexColor(1, 1, 1, 1)
        local qual = GetInventoryItemQuality("player", slotId)
        local qc   = QUALITY_COLORS[qual or 1] or QUALITY_COLORS[1]
        w.border:SetColorTexture(qc[1], qc[2], qc[3], 1)
    else
        w.icon:SetTexture("Interface\\PaperDoll\\UI-Backpack-EmptySlot")
        w.icon:SetTexCoord(0, 1, 0, 1)
        w.icon:SetVertexColor(0.28, 0.28, 0.28, 0.7)
        w.border:SetColorTexture(0.18, 0.18, 0.22, 0.9)
    end
end

local function BuildSlot(parent, slotId, label, x, y)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetSize(SLOT_S, SLOT_S)
    btn:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)

    local border = btn:CreateTexture(nil, "BACKGROUND")
    border:SetAllPoints(btn)
    border:SetColorTexture(0.18, 0.18, 0.22, 0.9)

    local slotBg = btn:CreateTexture(nil, "BORDER")
    slotBg:SetPoint("TOPLEFT",     btn, "TOPLEFT",      1, -1)
    slotBg:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -1,  1)
    slotBg:SetColorTexture(0.04, 0.04, 0.05, 1)

    local icon = btn:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("TOPLEFT",     btn, "TOPLEFT",      2, -2)
    icon:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -2,  2)
    icon:SetTexture("Interface\\PaperDoll\\UI-Backpack-EmptySlot")
    icon:SetTexCoord(0, 1, 0, 1)
    icon:SetVertexColor(0.28, 0.28, 0.28, 0.7)

    btn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        if GetInventoryItemTexture("player", slotId) then
            GameTooltip:SetInventoryItem("player", slotId)
            GameTooltip:AddLine("Left-click: swap gear", 0.5, 0.5, 0.5)
            GameTooltip:AddLine("Shift+click: socket gems", 0.5, 0.5, 0.5)
            GameTooltip:AddLine("Drag: move to trade/bank", 0.5, 0.5, 0.5)
            GameTooltip:AddLine("Enchanting: use default char frame (C key)", 0.45, 0.45, 0.45)
        else
            GameTooltip:SetText(label, 0.65, 0.65, 0.65)
            GameTooltip:AddLine("Empty slot", 0.4, 0.4, 0.4)
        end
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    -- Drag OUT: lets the player drag equipped items to trade/bank/bags
    btn:RegisterForDrag("LeftButton")
    btn:SetScript("OnDragStart", function(self)
        -- Don't pick up while a weapon stone / spell is waiting for a target
        if SpellIsTargeting() or GetCursorInfo() then return end
        if IsInventoryItemLocked(slotId) then return end
        GameTooltip:Hide()
        SC_HidePicker()
        local ok = pcall(PickupInventoryItem, slotId)
        if ok then UpdateSlot(slotWidgets[slotId], slotId) end
    end)

    -- Drop ON: equip whatever is on the cursor (dragged from bags/bank)
    -- Skip if cursor holds an enchant — protected action; use default char frame.
    btn:SetScript("OnReceiveDrag", function(self)
        local ctype = GetCursorInfo()
        if not ctype then return end
        if ctype == "enchant" or ctype == "spell" then return end
        GameTooltip:Hide()
        local ok, err = pcall(PickupInventoryItem, slotId)
        if ok then UpdateSlot(slotWidgets[slotId], slotId) end
    end)

    btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    btn:SetScript("OnClick", function(self, mb)
        if mb == "LeftButton" then
            GameTooltip:Hide()
            -- Shift+click: open gem socketing UI if the slot has an item
            if IsShiftKeyDown() then
                if GetInventoryItemTexture("player", slotId) then
                    SC_HidePicker()
                    SocketInventoryItem(slotId)
                end
                return
            end
            -- Weapon stone / temp enchant: stone use triggers SpellIsTargeting.
            -- Apply it to this slot by targeting with PickupInventoryItem.
            if SpellIsTargeting() then
                local ok = pcall(PickupInventoryItem, slotId)
                if ok then UpdateSlot(slotWidgets[slotId], slotId) end
                return
            end
            -- If cursor has an item (dragged from bag), equip it.
            -- Skip enchant/spell cursors — those are protected; use default char frame.
            local ctype = GetCursorInfo()
            if ctype then
                if ctype == "enchant" or ctype == "spell" then return end
                local ok = pcall(PickupInventoryItem, slotId)
                if ok then UpdateSlot(slotWidgets[slotId], slotId) end
                return
            end
            -- Toggle picker
            if picker and picker:IsShown() and picker._slotId == slotId then
                SC_HidePicker()
            else
                SC_ShowGearPicker(slotId)
            end
        elseif mb == "RightButton" then
            local link = GetInventoryItemLink("player", slotId)
            if link and ChatFrame1EditBox then
                ChatFrame1EditBox:Show()
                ChatFrame1EditBox:SetText(link)
                ChatFrame1EditBox:SetFocus()
            end
        end
    end)

    local w = {frame=btn, icon=icon, border=border}
    slotWidgets[slotId] = w
    return w
end

function SC_RefreshSlots()
    for sid, w in pairs(slotWidgets) do
        UpdateSlot(w, sid)
    end
end

-- ============================================================
-- Header
-- ============================================================
local function RefreshHeader()
    if not headerName then return end
    local name   = UnitName("player") or "Unknown"
    local level  = UnitLevel("player") or 0
    local race   = UnitRace("player") or ""
    local _, cls = UnitClass("player")
    local cc     = (cls and CLASS_COLORS[cls]) or {1,1,1}
    headerName:SetFormattedText("|cff%02x%02x%02x%s|r",
        cc[1]*255, cc[2]*255, cc[3]*255, name)
    headerInfo:SetFormattedText("Level %d  %s  %s",
        level, race, cls and (cls:sub(1,1)..cls:sub(2):lower()) or "")
end

-- ============================================================
-- Stats tab
-- ============================================================
local function BuildStatRows(parent)
    for i = 1, MAX_STAT_ROWS do
        local row = CreateFrame("Frame", nil, parent)
        row:SetSize(SIDE_W - PAD*2 - 16, 16)
        row:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -((i-1)*16))

        local lbl = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        lbl:SetFont(lbl:GetFont(), 10, "")
        lbl:SetPoint("LEFT", row, "LEFT", 0, 0)
        lbl:SetJustifyH("LEFT")
        lbl:SetWidth((SIDE_W - PAD*2 - 16) * 0.60)

        local val = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        val:SetFont(val:GetFont(), 10, "")
        val:SetPoint("RIGHT", row, "RIGHT", 0, 0)
        val:SetJustifyH("RIGHT")

        row:Hide()
        statRows[i] = {row=row, lbl=lbl, val=val}
    end
end

function SC_RefreshStats()
    for _, w in ipairs(statRows) do
        w.row:Hide() ; w.lbl:SetText("") ; w.val:SetText("")
    end
    local ri = 0
    local function addRow(lbl, val, sec)
        ri = ri + 1
        local w = statRows[ri]
        if not w then return end
        if sec then
            w.lbl:SetText("|cff66d4ff" .. lbl .. "|r")
            w.val:SetText("")
        else
            w.lbl:SetText("|cffbbbbbb" .. lbl .. "|r")
            w.val:SetText("|cffffd700" .. (val or "n/a") .. "|r")
        end
        w.row:Show()
    end

    addRow("BASE STATS", nil, true)
    local NAMES = {"Strength","Agility","Stamina","Intellect","Spirit"}
    for i = 1, 5 do
        local base, pos, neg = UnitStat("player", i)
        addRow(NAMES[i], tostring((base or 0)+(pos or 0)-(neg or 0)))
    end
    addRow("Armor", tostring(UnitArmor("player") or 0))

    if ECS_GetStats then
        local ok, stats = pcall(ECS_GetStats)
        if ok and stats then
            local lastSec = nil
            for _, s in ipairs(stats) do
                if s.section and s.section ~= lastSec then
                    addRow(s.section, nil, true)
                    lastSec = s.section
                end
                if s.label then addRow(s.label, s.value) end
            end
        end
    end
end

-- ============================================================
-- Set Icon Picker
-- ============================================================
local IPICK_COLS  = 5
local IPICK_ROWS  = 5
local IPICK_PAGE  = IPICK_COLS * IPICK_ROWS   -- 25 icons per page
local IPICK_ICO_S = 30
local IPICK_GAP   = 2
local IPICK_PAD   = 6
local IPICK_HDR_H = 26
local IPICK_FOT_H = 26
local IPICK_W     = IPICK_COLS*(IPICK_ICO_S+IPICK_GAP) - IPICK_GAP + IPICK_PAD*2

local iconPickerFrame  = nil
local iconPickerTarget = nil
local iconBtnPool      = {}
local iconList         = {}
local iconCurrentPage  = 1

local STATIC_SET_ICONS = {
    -- Warrior
    "Interface\\Icons\\Ability_Warrior_BattleShout",
    "Interface\\Icons\\Ability_Warrior_Charge",
    "Interface\\Icons\\Ability_Warrior_Cleave",
    "Interface\\Icons\\Ability_Warrior_DefensiveStance",
    "Interface\\Icons\\Ability_Warrior_OffensiveStance",
    "Interface\\Icons\\Ability_Warrior_BerserkerStance",
    "Interface\\Icons\\Ability_Warrior_Revenge",
    "Interface\\Icons\\Ability_Warrior_ShieldBash",
    "Interface\\Icons\\Ability_Warrior_Sunderarmor",
    "Interface\\Icons\\Ability_Warrior_Whirlwind",
    "Interface\\Icons\\Ability_Warrior_Execute",
    "Interface\\Icons\\Ability_Warrior_Disarm",
    "Interface\\Icons\\Ability_Warrior_InnerRage",
    "Interface\\Icons\\Ability_DualWield",
    -- Weapons
    "Interface\\Icons\\INV_Sword_04",
    "Interface\\Icons\\INV_Sword_23",
    "Interface\\Icons\\INV_Sword_27",
    "Interface\\Icons\\INV_Axe_01",
    "Interface\\Icons\\INV_Axe_06",
    "Interface\\Icons\\INV_Axe_09",
    "Interface\\Icons\\INV_Mace_01",
    "Interface\\Icons\\INV_Mace_13",
    "Interface\\Icons\\INV_Staff_13",
    "Interface\\Icons\\INV_Weapon_ShortBlade_05",
    "Interface\\Icons\\INV_Weapon_Bow_01",
    "Interface\\Icons\\INV_Spear_04",
    -- Armor
    "Interface\\Icons\\INV_Chest_Plate04",
    "Interface\\Icons\\INV_Helmet_01",
    "Interface\\Icons\\INV_Helmet_03",
    "Interface\\Icons\\INV_Shoulder_01",
    "Interface\\Icons\\INV_Boots_05",
    "Interface\\Icons\\INV_Bracer_01",
    "Interface\\Icons\\INV_Gauntlets_01",
    "Interface\\Icons\\INV_Belt_01",
    "Interface\\Icons\\INV_Pants_01",
    "Interface\\Icons\\INV_Shield_06",
    "Interface\\Icons\\INV_Chest_Leather_01",
    "Interface\\Icons\\INV_Chest_Mail_01",
    "Interface\\Icons\\INV_Chest_Cloth_05",
    -- Jewelry
    "Interface\\Icons\\INV_Jewelry_Ring_01",
    "Interface\\Icons\\INV_Jewelry_Necklace_01",
    "Interface\\Icons\\INV_Jewelry_Trinket_01",
    "Interface\\Icons\\INV_Jewelry_Amulet_06",
    -- Other classes
    "Interface\\Icons\\Ability_Paladin_HolyBolt",
    "Interface\\Icons\\Ability_Hunter_SniperShot",
    "Interface\\Icons\\Ability_Rogue_Sprint",
    "Interface\\Icons\\Ability_Druid_Maul",
    "Interface\\Icons\\Ability_Mage_ArcaneMissiles",
    "Interface\\Icons\\Ability_Warlock_SoulLink",
    "Interface\\Icons\\Ability_Shaman_ThunderBolt",
    "Interface\\Icons\\Spell_Nature_LightningShield",
    "Interface\\Icons\\Spell_Holy_Devotion",
    "Interface\\Icons\\Spell_Fire_Fireball",
    "Interface\\Icons\\Spell_Shadow_ShadowBolt",
    "Interface\\Icons\\Spell_Frost_FrostBolt02",
    "Interface\\Icons\\Spell_Holy_GuardianSpirit",
    -- Misc
    "Interface\\Icons\\Ability_Rogue_MasterOfSubtlety",
    "Interface\\Icons\\INV_Misc_QuestionMark",
    "Interface\\Icons\\INV_Misc_Coin_01",
    "Interface\\Icons\\INV_Misc_Cape_05",
    "Interface\\Icons\\INV_Misc_Rune_01",
    "Interface\\Icons\\INV_Misc_Head_Dragon_01",
    "Interface\\Icons\\PVPCurrency_Honor_Alliance",
    "Interface\\Icons\\PVPCurrency_Honor_Horde",
    "Interface\\Icons\\Achievement_Character_Warrior_Male",
}

local function SC_HideIconPicker()
    if iconPickerFrame then iconPickerFrame:Hide() end
    iconPickerTarget = nil
end

local function SC_ShowPage(page) end  -- forward decl, defined after BuildIconPicker

local function BuildIconPicker()
    if iconPickerFrame then return end
    local gridH = IPICK_ROWS*(IPICK_ICO_S+IPICK_GAP) + IPICK_PAD*2
    local totalH = IPICK_HDR_H + gridH + IPICK_FOT_H
    local f = CreateFrame("Frame", "SlyCharIconPicker", UIParent)
    f:SetFrameStrata("FULLSCREEN_DIALOG")
    f:SetWidth(IPICK_W)
    f:SetHeight(totalH)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop",  f.StopMovingOrSizing)
    f:SetClampedToScreen(true)
    f:Hide()

    local bg = f:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints() ; bg:SetColorTexture(0.06, 0.06, 0.09, 0.97)
    local bord = f:CreateTexture(nil, "OVERLAY")
    bord:SetAllPoints() ; bord:SetColorTexture(0.28, 0.28, 0.40, 1)
    local inner = f:CreateTexture(nil, "BACKGROUND")
    inner:SetPoint("TOPLEFT",     f, "TOPLEFT",      1, -1)
    inner:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -1,  1)
    inner:SetColorTexture(0.07, 0.07, 0.10, 0.97)

    local hdr = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    hdr:SetFont(hdr:GetFont(), 10, "OUTLINE")
    hdr:SetPoint("TOPLEFT", f, "TOPLEFT", IPICK_PAD, -5)
    hdr:SetTextColor(0.70, 0.85, 1.00)
    hdr:SetText("Choose Icon")

    local xBtn = CreateFrame("Button", nil, f)
    xBtn:SetSize(16, 16) ; xBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -3, -3)
    xBtn:EnableMouse(true)
    xBtn:RegisterForClicks("LeftButtonUp")
    local xBg = xBtn:CreateTexture(nil, "BACKGROUND")
    xBg:SetAllPoints() ; xBg:SetColorTexture(0.40, 0.10, 0.10, 0.90)
    local xHl = xBtn:CreateTexture(nil, "HIGHLIGHT")
    xHl:SetAllPoints() ; xHl:SetColorTexture(0.70, 0.20, 0.20, 0.60)
    local xTx = xBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    xTx:SetAllPoints() ; xTx:SetJustifyH("CENTER") ; xTx:SetText("|cffff8888x|r")
    xBtn:SetScript("OnClick", function() SC_HideIconPicker() end)

    local sep = f:CreateTexture(nil, "ARTWORK")
    sep:SetPoint("TOPLEFT",  f, "TOPLEFT",  1, -IPICK_HDR_H)
    sep:SetPoint("TOPRIGHT", f, "TOPRIGHT", -1, -IPICK_HDR_H)
    sep:SetHeight(1) ; sep:SetColorTexture(0.25, 0.25, 0.38, 1)

    -- Icon buttons placed directly on frame (no scroll frame)
    for k = 1, IPICK_PAGE do
        local col = (k-1) % IPICK_COLS
        local row = math.floor((k-1) / IPICK_COLS)
        local btn = CreateFrame("Button", nil, f)
        btn:SetSize(IPICK_ICO_S, IPICK_ICO_S)
        btn:EnableMouse(true)
        btn:RegisterForClicks("LeftButtonUp")
        btn:SetPoint("TOPLEFT", f, "TOPLEFT",
            IPICK_PAD + col*(IPICK_ICO_S+IPICK_GAP),
            -(IPICK_HDR_H + IPICK_PAD + row*(IPICK_ICO_S+IPICK_GAP)))
        btn:Hide()
        local icTex = btn:CreateTexture(nil, "ARTWORK")
        icTex:SetAllPoints() ; icTex:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        btn._ic = icTex
        local hl = btn:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints() ; hl:SetColorTexture(1, 1, 1, 0.35)
        local selRing = btn:CreateTexture(nil, "OVERLAY")
        selRing:SetAllPoints() ; selRing:SetColorTexture(0, 0, 0, 0)
        btn._sel = selRing
        btn:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            local sn2 = (self._tex or ""):match("\\([^\\]+)$") or "?"
            GameTooltip:SetText(sn2, 1, 1, 1)
            GameTooltip:Show()
        end)
        btn:SetScript("OnLeave", function(self)
            self._sel:SetColorTexture(0, 0, 0, 0)
            GameTooltip:Hide()
        end)
        iconBtnPool[k] = btn
    end

    -- Footer: prev / page label / next
    local prevBtn = CreateFrame("Button", nil, f)
    prevBtn:SetSize(40, 20)
    prevBtn:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", IPICK_PAD, 4)
    prevBtn:EnableMouse(true)
    prevBtn:RegisterForClicks("LeftButtonUp")
    local prevBg = prevBtn:CreateTexture(nil, "BACKGROUND")
    prevBg:SetAllPoints() ; prevBg:SetColorTexture(0.18, 0.18, 0.28, 0.90)
    local prevHl = prevBtn:CreateTexture(nil, "HIGHLIGHT")
    prevHl:SetAllPoints() ; prevHl:SetColorTexture(1, 1, 1, 0.15)
    local prevTx = prevBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    prevTx:SetAllPoints() ; prevTx:SetJustifyH("CENTER") ; prevTx:SetText("< Prev")
    prevBtn:SetScript("OnClick", function()
        SC_ShowPage(iconCurrentPage - 1)
    end)

    local nextBtn = CreateFrame("Button", nil, f)
    nextBtn:SetSize(40, 20)
    nextBtn:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -IPICK_PAD, 4)
    nextBtn:EnableMouse(true)
    nextBtn:RegisterForClicks("LeftButtonUp")
    local nextBg = nextBtn:CreateTexture(nil, "BACKGROUND")
    nextBg:SetAllPoints() ; nextBg:SetColorTexture(0.18, 0.18, 0.28, 0.90)
    local nextHl = nextBtn:CreateTexture(nil, "HIGHLIGHT")
    nextHl:SetAllPoints() ; nextHl:SetColorTexture(1, 1, 1, 0.15)
    local nextTx = nextBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    nextTx:SetAllPoints() ; nextTx:SetJustifyH("CENTER") ; nextTx:SetText("Next >")
    nextBtn:SetScript("OnClick", function()
        SC_ShowPage(iconCurrentPage + 1)
    end)

    local pageLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    pageLabel:SetPoint("BOTTOM", f, "BOTTOM", 0, 8)
    pageLabel:SetTextColor(0.60, 0.60, 0.70)
    f._pageLabel = pageLabel
    f._prevBtn   = prevBtn
    f._nextBtn   = nextBtn
    iconPickerFrame = f
end

local function SC_PopulateIconPicker()
    local seen = {}
    iconList = {}
    local function addTex(tex)
        if not tex then return end
        tex = tostring(tex)
        if seen[tex] then return end
        seen[tex] = true ; iconList[#iconList+1] = tex
    end
    for slot = 1, 19 do addTex(GetInventoryItemTexture("player", slot)) end
    for bag = 0, 4 do
        for slot = 1, (GetContainerNumSlots(bag) or 0) do
            addTex((GetContainerItemInfo(bag, slot)))
        end
    end
    for _, tex in ipairs(STATIC_SET_ICONS) do addTex(tex) end
end

SC_ShowPage = function(page)
    local totalPages = math.max(1, math.ceil(#iconList / IPICK_PAGE))
    page = math.max(1, math.min(page, totalPages))
    iconCurrentPage = page

    local curIcon = iconPickerTarget and IRR_GetSetIcon and
        IRR_GetSetIcon(iconPickerTarget.name)

    for k = 1, IPICK_PAGE do
        local btn = iconBtnPool[k]
        local idx = (page-1)*IPICK_PAGE + k
        local tex = iconList[idx]
        if tex then
            btn._tex = tex
            btn._ic:SetTexture(tex)
            local isSelected = curIcon and curIcon == tex
            btn._sel:SetColorTexture(
                isSelected and 0.2 or 0,
                isSelected and 0.7 or 0,
                isSelected and 1.0 or 0,
                isSelected and 0.6 or 0)
            btn:SetScript("OnClick", function(self)
                if not iconPickerTarget then SC_HideIconPicker(); return end
                local sn = iconPickerTarget.name
                local ib = iconPickerTarget.btn
                if IRR_SetSetIcon then IRR_SetSetIcon(sn, self._tex) end
                if ib then
                    ib._icTex:SetTexture(self._tex)
                    ib._icTex:SetTexCoord(0.07, 0.93, 0.07, 0.93)
                end
                SC_HideIconPicker()
            end)
            btn:Show()
        else
            btn:Hide()
        end
    end

    iconPickerFrame._pageLabel:SetText(page .. " / " .. totalPages)
    iconPickerFrame._prevBtn:SetShown(page > 1)
    iconPickerFrame._nextBtn:SetShown(page < totalPages)
end

local function SC_ShowIconPicker(setName, anchorBtn)
    BuildIconPicker()
    iconPickerTarget = { name = setName, btn = anchorBtn }
    SC_PopulateIconPicker()
    iconCurrentPage = 1
    SC_ShowPage(1)
    iconPickerFrame:ClearAllPoints()
    iconPickerFrame:SetPoint("BOTTOMLEFT", anchorBtn, "TOPLEFT", 0, 4)
    iconPickerFrame:Show()
    iconPickerFrame:Raise()
end

-- ============================================================
-- Sets tab
-- ============================================================
local function BuildSetRows(parent)
    for i = 1, MAX_SET_ROWS do
        local row = CreateFrame("Frame", nil, parent)
        row:SetSize(SIDE_W - PAD*2 - 16, 22)
        row:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -((i-1)*22))

        local bg = row:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints(row)
        bg:SetColorTexture(0, 0, 0, i%2==0 and 0.12 or 0)

        -- Delete button (far right)
        local delBtn = CreateFrame("Button", nil, row)
        delBtn:SetSize(16, 16)
        delBtn:SetPoint("RIGHT", row, "RIGHT", -2, 0)
        delBtn:EnableMouse(false)
        delBtn:RegisterForClicks("LeftButtonUp")
        local delBg = delBtn:CreateTexture(nil, "BACKGROUND")
        delBg:SetAllPoints() ; delBg:SetColorTexture(0.45, 0.10, 0.10, 0.85)
        local delHl = delBtn:CreateTexture(nil, "HIGHLIGHT")
        delHl:SetAllPoints() ; delHl:SetColorTexture(0.70, 0.20, 0.20, 0.50)
        local delTx = delBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        delTx:SetFont(delTx:GetFont(), 9, "OUTLINE") ; delTx:SetAllPoints()
        delTx:SetJustifyH("CENTER") ; delTx:SetText("|cffff6666x|r")

        -- Save button
        local saveBtn = CreateFrame("Button", nil, row)
        saveBtn:SetSize(36, 16)
        saveBtn:SetPoint("RIGHT", delBtn, "LEFT", -2, 0)
        saveBtn:EnableMouse(false)
        saveBtn:RegisterForClicks("LeftButtonUp")
        local saveBg = saveBtn:CreateTexture(nil, "BACKGROUND")
        saveBg:SetAllPoints() ; saveBg:SetColorTexture(0.15, 0.38, 0.60, 0.85)
        local saveHl = saveBtn:CreateTexture(nil, "HIGHLIGHT")
        saveHl:SetAllPoints() ; saveHl:SetColorTexture(0.30, 0.55, 0.80, 0.50)
        local saveTx = saveBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        saveTx:SetFont(saveTx:GetFont(), 9, "OUTLINE") ; saveTx:SetAllPoints()
        saveTx:SetJustifyH("CENTER") ; saveTx:SetText("Save")

        -- Equip button
        local eqBtn = CreateFrame("Button", nil, row)
        eqBtn:SetSize(40, 16)
        eqBtn:SetPoint("RIGHT", saveBtn, "LEFT", -2, 0)
        eqBtn:EnableMouse(false)
        eqBtn:RegisterForClicks("LeftButtonUp")
        local eqBg = eqBtn:CreateTexture(nil, "BACKGROUND")
        eqBg:SetAllPoints() ; eqBg:SetColorTexture(0.15, 0.30, 0.15, 0.85)
        local eqHl = eqBtn:CreateTexture(nil, "HIGHLIGHT")
        eqHl:SetAllPoints() ; eqHl:SetColorTexture(0.25, 0.55, 0.25, 0.50)
        local eqTx = eqBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        eqTx:SetFont(eqTx:GetFont(), 9, "OUTLINE") ; eqTx:SetAllPoints()
        eqTx:SetJustifyH("CENTER") ; eqTx:SetText("Equip")

        -- Spec-link toggle button  (left of Equip)
        -- Clicking cycles: none → Spec 1 → Spec 2 → none
        local specBtn = CreateFrame("Button", nil, row)
        specBtn:SetSize(28, 16)
        specBtn:SetPoint("RIGHT", eqBtn, "LEFT", -2, 0)
        specBtn:EnableMouse(false)
        specBtn:RegisterForClicks("LeftButtonUp")
        local specBg = specBtn:CreateTexture(nil, "BACKGROUND")
        specBg:SetAllPoints() ; specBg:SetColorTexture(0.20, 0.20, 0.25, 0.85)
        specBtn.bg = specBg
        local specHl = specBtn:CreateTexture(nil, "HIGHLIGHT")
        specHl:SetAllPoints() ; specHl:SetColorTexture(1, 1, 1, 0.15)
        local specTx = specBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        specTx:SetFont(specTx:GetFont(), 8, "OUTLINE") ; specTx:SetAllPoints()
        specTx:SetJustifyH("CENTER") ; specTx:SetText("--")
        specBtn.tx = specTx

        -- Icon button (click opens icon picker)
        local iconBtn = CreateFrame("Button", nil, row)
        iconBtn:SetSize(20, 20)
        iconBtn:SetPoint("LEFT", row, "LEFT", 0, 0)
        iconBtn:EnableMouse(false)
        iconBtn:RegisterForClicks("LeftButtonUp")
        local iconBg2 = iconBtn:CreateTexture(nil, "BACKGROUND")
        iconBg2:SetAllPoints() ; iconBg2:SetColorTexture(0.12, 0.12, 0.16, 0.90)
        local iconTex = iconBtn:CreateTexture(nil, "ARTWORK")
        iconTex:SetAllPoints()
        iconTex:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
        iconTex:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        iconBtn._icTex = iconTex
        local iconHl = iconBtn:CreateTexture(nil, "HIGHLIGHT")
        iconHl:SetAllPoints() ; iconHl:SetColorTexture(1, 1, 1, 0.30)

        local nm = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        nm:SetFont(nm:GetFont(), 10, "")
        nm:SetPoint("LEFT", row, "LEFT", 24, 0)
        nm:SetJustifyH("LEFT")
        nm:SetWidth(138)

        local cnt = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        cnt:SetFont(cnt:GetFont(), 9, "")
        cnt:SetPoint("LEFT", nm, "RIGHT", 2, 0)
        cnt:SetJustifyH("LEFT")
        cnt:SetTextColor(0.4, 0.4, 0.4)

        row:Hide()
        setRowWidgets[i] = {row=row, nm=nm, cnt=cnt, iconBtn=iconBtn, specBtn=specBtn, eqBtn=eqBtn, saveBtn=saveBtn, delBtn=delBtn}
    end
end

function SC_RefreshSets()
    for _, w in ipairs(setRowWidgets) do w.row:Hide() end

    if not IRR_GetSetNames then
        local w = setRowWidgets[1]
        if w then
            w.nm:SetText("|cffff8800ItemRackRevived not loaded|r")
            w.cnt:SetText("") ; w.eqBtn:Hide() ; w.saveBtn:Hide() ; w.specBtn:Hide() ; w.delBtn:Hide()
            w.row:Show()
        end
        return
    end

    local names = IRR_GetSetNames()
    if not names or #names == 0 then
        local w = setRowWidgets[1]
        if w then
            w.nm:SetText("|cff666666No sets saved|r")
            w.cnt:SetText("") ; w.eqBtn:Hide() ; w.saveBtn:Hide() ; w.specBtn:Hide() ; w.delBtn:Hide()
            w.row:Show()
        end
        return
    end

    for i, name in ipairs(names) do
        local w = setRowWidgets[i]
        if not w then break end
        local setData = IRR and IRR.db and IRR.db.sets and IRR.db.sets[name]
        local n = 0
        if setData then for _ in pairs(setData) do n = n + 1 end end

        w.nm:SetText("|cffdddddd" .. name .. "|r")
        w.cnt:SetText(string.format("|cff555555(%d)|r", n))

        -- Icon button
        local ic = IRR_GetSetIcon and IRR_GetSetIcon(name)
        w.iconBtn._icTex:SetTexture(ic or "Interface\\Icons\\INV_Misc_QuestionMark")
        w.iconBtn._icTex:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        w.iconBtn:EnableMouse(true)
        w.iconBtn:SetScript("OnClick", function(self)
            SC_ShowIconPicker(name, self)
        end)
        w.iconBtn:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText("Set Icon", 1, 0.82, 0)
            GameTooltip:AddLine("Click to choose an icon for this set.", 0.8, 0.8, 0.8, true)
            GameTooltip:Show()
        end)
        w.iconBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
        w.iconBtn:Show()

        -- Spec-link toggle
        local function UpdateSpecBtn()
            local spec = IRR_GetSpecLink and IRR_GetSpecLink(name)
            local hasDualSpec = GetNumTalentGroups and GetNumTalentGroups() >= 2
            if not hasDualSpec then
                w.specBtn:Hide()
            else
                w.specBtn:EnableMouse(true)
                w.specBtn:Show()
                if spec == 1 then
                    w.specBtn.tx:SetText("|cffffd700S1|r")
                    w.specBtn.bg:SetColorTexture(0.40, 0.32, 0.05, 0.90)
                elseif spec == 2 then
                    w.specBtn.tx:SetText("|cff66ccffS2|r")
                    w.specBtn.bg:SetColorTexture(0.05, 0.25, 0.45, 0.90)
                else
                    w.specBtn.tx:SetText("|cff666666--|r")
                    w.specBtn.bg:SetColorTexture(0.20, 0.20, 0.25, 0.85)
                end
            end
        end
        UpdateSpecBtn()
        w.specBtn:SetScript("OnClick", function()
            if not IRR_SetSpecLink then return end
            local cur = IRR_GetSpecLink and IRR_GetSpecLink(name)
            local next = (cur == nil and 1) or (cur == 1 and 2) or nil
            IRR_SetSpecLink(name, next)
            UpdateSpecBtn()
        end)
        w.specBtn:SetScript("OnEnter", function(self)
            local spec = IRR_GetSpecLink and IRR_GetSpecLink(name)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText("Spec Link", 1, 0.82, 0)
            if spec then
                GameTooltip:AddLine("Equipping this set will switch to Spec " .. spec .. ".", 0.8, 0.8, 0.8, true)
            else
                GameTooltip:AddLine("Click to link a spec (1 or 2).\nWhen set is equipped, that spec activates.", 0.8, 0.8, 0.8, true)
            end
            GameTooltip:Show()
        end)
        w.specBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

        w.eqBtn:EnableMouse(true)
        w.eqBtn:SetScript("OnClick", function()
            if IRR_LoadSet then
                IRR_LoadSet(name)
                DEFAULT_CHAT_FRAME:AddMessage(
                    "|cff88bbff[SlyChar]|r Equipping: |cffffd700"..name.."|r")
            end
        end)

        w.saveBtn:EnableMouse(true)
        w.saveBtn:SetScript("OnClick", function()
            if IRR_SaveCurrentSet then
                IRR_SaveCurrentSet(name)
                SC_RefreshSets()
            end
        end)

        w.delBtn:EnableMouse(true)
        w.delBtn:SetScript("OnClick", function()
            if IRR_DeleteSet then IRR_DeleteSet(name) end
            SC_RefreshSets()
        end)

        w.row:SetScript("OnEnter", function()
            if not (IRR and IRR.db and IRR.db.sets and IRR.db.sets[name]) then return end
            GameTooltip:SetOwner(w.row, "ANCHOR_RIGHT")
            GameTooltip:SetText(name, 1, 0.84, 0)
            for _, itemId in pairs(IRR.db.sets[name]) do
                local n2 = GetItemInfo(itemId)
                if n2 then GameTooltip:AddLine(n2, 0.8, 0.8, 0.8) end
            end
            GameTooltip:Show()
        end)
        w.row:SetScript("OnLeave", function() GameTooltip:Hide() end)

        w.eqBtn:Show() ; w.saveBtn:Show() ; w.delBtn:Show()
        w.row:Show()
    end
end

-- ============================================================
-- Reputation tab
-- ============================================================
local STANDING_COLORS = {
    [1]={0.90,0.10,0.10}, [2]={0.90,0.35,0.00}, [3]={0.90,0.55,0.00},
    [4]={0.90,0.90,0.15}, [5]={0.30,0.90,0.30}, [6]={0.10,0.80,0.10},
    [7]={0.20,0.65,1.00}, [8]={1.00,0.85,0.25},
}
local STANDING_LABELS = {
    "Hated","Hostile","Unfriendly","Neutral",
    "Friendly","Honored","Revered","Exalted",
}

local function BuildRepRows(parent)
    local rowW = SIDE_W - PAD*2 - 16
    for i = 1, MAX_REP_ROWS do
        local row = CreateFrame("Frame", nil, parent)
        row:SetSize(rowW, 16)
        row:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -((i-1)*16))

        local bg = row:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints(row)
        bg:SetColorTexture(0, 0, 0, 0)
        row.bg = bg

        -- Col 1: faction name (~44% of row)
        local nm = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        nm:SetFont(nm:GetFont(), 9, "")
        nm:SetPoint("LEFT", row, "LEFT", 2, 2)
        nm:SetJustifyH("LEFT")
        nm:SetWidth(math.floor(rowW * 0.44))
        row.nm = nm

        -- Col 2: standing label (~22% of row)
        local st = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        st:SetFont(st:GetFont(), 9, "")
        st:SetPoint("LEFT", nm, "RIGHT", 4, 0)
        st:SetJustifyH("LEFT")
        st:SetWidth(math.floor(rowW * 0.22))
        row.st = st

        -- Col 3: numeric progress (right-aligned)
        local val = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        val:SetFont(val:GetFont(), 9, "")
        val:SetPoint("RIGHT", row, "RIGHT", -2, 2)
        val:SetJustifyH("RIGHT")
        val:SetTextColor(0.75, 0.75, 0.75)
        row.val = val

        -- thin progress bar at bottom of row
        local barBg = row:CreateTexture(nil, "ARTWORK")
        barBg:SetHeight(3)
        barBg:SetPoint("BOTTOMLEFT",  row, "BOTTOMLEFT",  2, 1)
        barBg:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -2, 1)
        barBg:SetColorTexture(0.12, 0.12, 0.15, 1)
        barBg:Hide()
        row.barBg = barBg

        local bar = row:CreateTexture(nil, "OVERLAY")
        bar:SetHeight(3)
        bar:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 2, 1)
        bar:SetWidth(1)
        bar:Hide()
        row.bar = bar

        row:Hide()
        repRows[i] = row
    end
end

function SC_RefreshReputation()
    for _, w in ipairs(repRows) do
        w:Hide() ; w.barBg:Hide() ; w.bar:Hide() ; w.val:SetText("") ; w.st:SetText("")
    end
    local ri  = 0
    local num = GetNumFactions and GetNumFactions() or 0
    local rowW = SIDE_W - PAD*2 - 20
    for i = 1, num do
        local name, _, standingId, barMin, barMax, barValue,
              _, _, isHeader, _, hasRep = GetFactionInfo(i)
        if name then
            ri = ri + 1
            local w = repRows[ri]
            if not w then break end
            w:Show()
            if isHeader then
                w.nm:SetText("|cff7799ff" .. name .. "|r")
                w.st:SetText("") ; w.val:SetText("")
                w.bg:SetColorTexture(0.09, 0.09, 0.16, 0.90)
                w.barBg:Hide() ; w.bar:Hide()
            else
                local sc2 = STANDING_COLORS[standingId] or {0.70,0.70,0.70}
                w.nm:SetText("|cffcccccc" .. name .. "|r")
                w.st:SetTextColor(sc2[1], sc2[2], sc2[3])
                w.st:SetText(STANDING_LABELS[standingId] or "?")
                w.bg:SetColorTexture(0, 0, 0, ri%2==0 and 0.12 or 0)
                if barMax and barMin and barMax > barMin then
                    local progress = barValue - barMin
                    local needed   = barMax - barMin
                    if standingId == 8 then  -- Exalted: no further progress
                        w.val:SetTextColor(sc2[1], sc2[2], sc2[3])
                        w.val:SetText("MAX")
                    else
                        w.val:SetTextColor(0.75, 0.75, 0.75)
                        w.val:SetText(string.format("%d / %d", progress, needed))
                    end
                    local pct = progress / needed
                    w.barBg:Show() ; w.bar:Show()
                    w.bar:SetWidth(math.max(1, pct * rowW))
                    w.bar:SetColorTexture(sc2[1]*0.65, sc2[2]*0.65, sc2[3]*0.65, 0.9)
                else
                    w.val:SetText("")
                    w.barBg:Hide() ; w.bar:Hide()
                end
            end
        end
    end
end

-- ============================================================
-- Skills tab
-- ============================================================
local function BuildSkillRows(parent)
    for i = 1, MAX_SKILL_ROWS do
        local row = CreateFrame("Frame", nil, parent)
        row:SetSize(SIDE_W - PAD*2 - 16, 14)
        row:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -((i-1)*14))

        local bg = row:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints(row)
        bg:SetColorTexture(0, 0, 0, 0)
        row.bg = bg

        local nm = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        nm:SetFont(nm:GetFont(), 9, "")
        nm:SetPoint("LEFT", row, "LEFT", 2, 0)
        nm:SetJustifyH("LEFT")
        nm:SetWidth((SIDE_W - PAD*2 - 16) * 0.68)
        row.nm = nm

        local rnk = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        rnk:SetFont(rnk:GetFont(), 9, "")
        rnk:SetPoint("RIGHT", row, "RIGHT", -2, 0)
        rnk:SetJustifyH("RIGHT")
        row.rnk = rnk

        row:Hide()
        skillRows[i] = row
    end
end

function SC_RefreshSkills()
    for _, w in ipairs(skillRows) do w:Hide() end
    local ri  = 0
    local num = GetNumSkillLines and GetNumSkillLines() or 0
    for i = 1, num do
        local skillName, isHeader, _, skillRank, numTempPoints,
              skillModifier, skillMaxRank = GetSkillLineInfo(i)
        if skillName then
            ri = ri + 1
            local w = skillRows[ri]
            if not w then break end
            w:Show()
            if isHeader then
                w.nm:SetText("|cff7799ff" .. skillName .. "|r")
                w.rnk:SetText("")
                w.bg:SetColorTexture(0.09, 0.09, 0.16, 0.90)
            else
                w.nm:SetText("|cffcccccc" .. skillName .. "|r")
                if skillMaxRank and skillMaxRank > 0 then
                    local eff = (skillRank or 0) + (numTempPoints or 0)
                        + (skillModifier or 0)
                    w.rnk:SetFormattedText(
                        "|cffc0c0c0%d|r/|cff666666%d|r", eff, skillMaxRank)
                else
                    w.rnk:SetText("|cff888888—|r")
                end
                w.bg:SetColorTexture(0, 0, 0, ri%2==0 and 0.10 or 0)
            end
        end
    end
end

-- ============================================================
-- Tab switching + master refresh
-- ============================================================
function SC_SwitchTab(name)
    SC.db.lastTab = name
    for k, tf in pairs(tabFrames) do tf:SetShown(k == name) end
    for k, tb in pairs(tabBtnWidgets) do
        local a = (k == name)
        tb.bg:SetColorTexture(
            a and 0.11 or 0.06, a and 0.16 or 0.06, a and 0.26 or 0.09, 1)
        tb.txt:SetTextColor(a and 1 or 0.55, a and 1 or 0.55, a and 1 or 0.60)
        tb.txt:SetFont(tb.txt:GetFont(), a and 11 or 10, a and "OUTLINE" or "")
    end
end

function SC_RefreshAll()
    RefreshHeader()
    SC_RefreshSlots()
    local tab = SC.db.lastTab or "stats"
    if     tab == "stats"  then SC_RefreshStats()
    elseif tab == "sets"   then SC_RefreshSets()
    elseif tab == "rep"    then SC_RefreshReputation()
    elseif tab == "skills" then SC_RefreshSkills()
    end
end

-- ============================================================
-- Native side-panel helper
-- Each strip button calls SC_ToggleSidePanel(frame).
-- Frames are shown via ShowUIPanel (or :Show()), then repositioned
-- one frame later via C_Timer.After(0) after the panel manager settles.
-- SetUserPlaced(true) stops subsequent repositioning.
-- ============================================================
local function SC_AnchorRight(tf)
    pcall(function() tf:SetUserPlaced(true) end)
    if SlyCharMainFrame then
        tf:ClearAllPoints()
        tf:SetPoint("TOPLEFT", SlyCharMainFrame, "TOPRIGHT", 4, 0)
    end
end

local function SC_EnsureHooked(tf)
    if not tf or hookedPanels[tf] then return end
    hookedPanels[tf] = true
    tf:HookScript("OnHide", function()
        if currentSidePanel == tf then
            currentSidePanel = nil
            pcall(function() tf:SetUserPlaced(false) end)
        end
    end)
end

function SC_CloseSidePanel()
    if not currentSidePanel then return end
    local tf = currentSidePanel
    currentSidePanel = nil
    pcall(function() tf:SetUserPlaced(false) end)
    tf:Hide()
end

local function SC_ToggleSidePanel(tf)
    if not tf then return end
    SC_EnsureHooked(tf)
    if tf == currentSidePanel and tf:IsShown() then
        SC_CloseSidePanel() ; return
    end
    if currentSidePanel and currentSidePanel ~= tf then
        SC_CloseSidePanel()
    end
    currentSidePanel = tf
    -- Use :Show() directly — never ShowUIPanel — so WoW's panel manager
    -- never gets a chance to reposition the frame.
    -- SC_AnchorRight sets position synchronously after OnShow fires.
    tf:Show()
    SC_AnchorRight(tf)
end

local function SC_GetTalentFrame()
    if PlayerTalentFrame then return PlayerTalentFrame end
    if TalentFrame       then return TalentFrame       end
    if LoadAddOn         then LoadAddOn("Blizzard_TalentUI") end
    return PlayerTalentFrame or TalentFrame or nil
end

-- Resolve a UI panel frame, loading its LoD addon if needed.
-- If the frame still doesn't exist, call fallbackFn() instead.
local function SC_OpenPanel(addonName, frameGlobal, fallbackFn)
    if not _G[frameGlobal] and LoadAddOn then
        LoadAddOn(addonName)
    end
    local tf = _G[frameGlobal]
    if tf then
        SC_ToggleSidePanel(tf)
    elseif fallbackFn then
        fallbackFn()
    end
end

-- Wing Panel — kept alive so BuildWingFrame's spellbook pane compiles cleanly;
-- no strip button currently opens it.
-- ============================================================
function SC_ToggleWing(key)
    if not wingFrame then return end
    if activeWingKey == key and wingFrame:IsShown() then
        wingFrame:Hide() ; activeWingKey = nil ; return
    end
    activeWingKey = key
    for k, p in pairs(wingPanes) do
        if k == key then p:Show() else p:Hide() end
    end
    if wingTitleTx then wingTitleTx:SetText(key) end
    wingFrame:Show()
    if key == "spells" then SC_RefreshSpells() end
    if key == "honor"  then SC_RefreshHonor()  end
end


function SC_RefreshSpells()
    for _, r in ipairs(spellRows) do r.frame:Hide() end
    local ri = 0
    local numTabs = GetNumSpellTabs and GetNumSpellTabs() or 0
    for tab = 1, numTabs do
        local tabName, _, offset, numSpells = GetSpellTabInfo(tab)
        ri = ri + 1 ; if ri > MAX_SPELL_ROWS then break end
        local rh = spellRows[ri]
        rh.frame:Show() ; rh.spellIdx = nil
        rh.lbl:SetText("|cff7799ff" .. (tabName or "?") .. "|r")
        rh.rank:SetText("")
        rh.frame:SetScript("OnEnter", nil) ; rh.frame:SetScript("OnLeave", nil)
        for s = offset + 1, offset + numSpells do
            local sName, sSubName = GetSpellBookItemName(s, BOOKTYPE_SPELL)
            local sType           = GetSpellBookItemInfo(s, BOOKTYPE_SPELL)
            if sName and sType ~= "FUTURESPELL" then
                ri = ri + 1 ; if ri > MAX_SPELL_ROWS then break end
                local rw = spellRows[ri]
                local spIdx = s
                rw.frame:Show() ; rw.spellIdx = spIdx
                rw.lbl:SetText("|cffdddddd" .. sName .. "|r")
                rw.rank:SetText(sSubName and ("|cff666666" .. sSubName .. "|r") or "")
                rw.frame:SetScript("OnEnter", function()
                    GameTooltip:SetOwner(rw.frame, "ANCHOR_LEFT")
                    GameTooltip:SetSpellBookItem(spIdx, BOOKTYPE_SPELL)
                    GameTooltip:Show()
                end)
                rw.frame:SetScript("OnLeave", function() GameTooltip:Hide() end)
            end
        end
    end
end

function SC_RefreshHonor()
    if not honorValues.currHonor then return end
    if LoadAddOn then LoadAddOn("Blizzard_PVPUI") end

    -- Scan _G for any function/number matching "honor" or "arena"
    local found = {}
    for k, v in pairs(_G) do
        local kl = string.lower(tostring(k))
        if (kl:find("honor") or kl:find("arena")) and type(v) == "function" then
            found[#found+1] = k
        end
    end
    table.sort(found)
    DEFAULT_CHAT_FRAME:AddMessage("|cffff8800[S-Hon globals]|r " .. table.concat(found, ", "))

    honorValues.currHonor:SetText("scan—see chat")
    honorValues.arena:SetText("scan—see chat")
end

local function BuildWingFrame(mainFrame)
    if wingFrame then return end
    -- Parent to UIParent to avoid child-frame strata/clipping issues;
    -- reposition whenever the main frame shows or moves.
    local f = CreateFrame("Frame", "SlyCharWingFrame", UIParent)
    f:SetSize(WING_W, FRAME_H)
    f:SetPoint("TOPLEFT", mainFrame, "TOPRIGHT", 0, 0)
    f:SetFrameStrata("DIALOG")
    f:SetFrameLevel(mainFrame:GetFrameLevel())
    f:Hide()
    wingFrame = f
    FillBg(f, 0.04, 0.04, 0.07, 1)

    -- Left join border
    local lbord = f:CreateTexture(nil, "ARTWORK")
    lbord:SetSize(2, FRAME_H)
    lbord:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
    lbord:SetColorTexture(0.25, 0.20, 0.38, 1)

    -- Header
    local hdr = CreateFrame("Frame", nil, f)
    hdr:SetSize(WING_W - 2, HDR_H)
    hdr:SetPoint("TOPLEFT", f, "TOPLEFT", 2, 0)
    FillBg(hdr, 0.07, 0.06, 0.12, 1)

    local htx = hdr:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    htx:SetFont(htx:GetFont(), 12, "OUTLINE")
    htx:SetPoint("LEFT", hdr, "LEFT", 10, 0)
    htx:SetTextColor(0.85, 0.70, 1.00)
    htx:SetText("Talents")
    wingTitleTx = htx

    local closeBtn = CreateFrame("Button", nil, hdr, "UIPanelCloseButton")
    closeBtn:SetSize(24, 24)
    closeBtn:SetPoint("RIGHT", hdr, "RIGHT", -4, 0)
    closeBtn:SetScript("OnClick", function()
        f:Hide() ; activeWingKey = nil
    end)

    local hdrSep = f:CreateTexture(nil, "ARTWORK")
    hdrSep:SetSize(WING_W, 1)
    hdrSep:SetPoint("TOPLEFT", f, "TOPLEFT", 2, -HDR_H)
    hdrSep:SetColorTexture(0.25, 0.20, 0.38, 1)

    -- ---- Talent Pane ----
    local talentPane = CreateFrame("Frame", nil, f)
    talentPane:SetPoint("TOPLEFT",     f, "TOPLEFT",     2, -(HDR_H + 1))
    talentPane:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, FOOT_H)
    FillBg(talentPane, 0.04, 0.04, 0.07, 1)
    wingPanes["talents"] = talentPane

    -- Talent pane is an empty backdrop; the native TalentFrame is reparented
    -- into it by SC_EmbedTalentFrame() each time the wing opens.

    -- ---- Spellbook Pane ----
    local spellPane = CreateFrame("Frame", nil, f)
    spellPane:SetPoint("TOPLEFT",     f, "TOPLEFT",     2, -(HDR_H + 1))
    spellPane:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, FOOT_H)
    spellPane:Hide()
    FillBg(spellPane, 0.04, 0.04, 0.07, 1)
    wingPanes["spells"] = spellPane

    local spellScroll = CreateFrame("ScrollFrame", nil, spellPane, "UIPanelScrollFrameTemplate")
    spellScroll:SetPoint("TOPLEFT",     spellPane, "TOPLEFT",     PAD, -4)
    spellScroll:SetPoint("BOTTOMRIGHT", spellPane, "BOTTOMRIGHT", -22,  4)
    local spellCont = CreateFrame("Frame", nil, spellScroll)
    spellCont:SetSize(WING_W - PAD*2 - 22, MAX_SPELL_ROWS * 16)
    spellScroll:SetScrollChild(spellCont)

    for i = 1, MAX_SPELL_ROWS do
        local row = CreateFrame("Frame", nil, spellCont)
        row:SetSize(WING_W - PAD*2 - 22, 16)
        row:SetPoint("TOPLEFT", spellCont, "TOPLEFT", 0, -(i-1)*16)
        row:EnableMouse(true) ; row:Hide()
        local rbg = row:CreateTexture(nil, "BACKGROUND")
        rbg:SetAllPoints(row)
        rbg:SetColorTexture(0, 0, 0, i%2==0 and 0.10 or 0)
        local lbl = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        lbl:SetFont(lbl:GetFont(), 9, "")
        lbl:SetPoint("LEFT", row, "LEFT", 4, 0)
        lbl:SetWidth((WING_W - PAD*2 - 22) * 0.70) ; lbl:SetJustifyH("LEFT")
        local rank = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        rank:SetFont(rank:GetFont(), 8, "")
        rank:SetPoint("RIGHT", row, "RIGHT", -2, 0) ; rank:SetJustifyH("RIGHT")
        spellRows[i] = {frame=row, lbl=lbl, rank=rank, spellIdx=nil}
    end

    -- ---- Honor Pane ----
    do
        local hp = CreateFrame("Frame", nil, f)
        hp:SetPoint("TOPLEFT",     f, "TOPLEFT",     2, -(HDR_H + 1))
        hp:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, FOOT_H)
        hp:Hide()
        FillBg(hp, 0.04, 0.04, 0.07, 1)
        wingPanes["honor"] = hp

        local function HL(y, text, r, g, b, valX)
            local lbl = hp:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            lbl:SetFont(lbl:GetFont(), 10, valX and "" or (r == 1 and g == 0.82 and "OUTLINE" or ""))
            lbl:SetPoint("TOPLEFT", hp, "TOPLEFT", valX or PAD, y)
            lbl:SetJustifyH("LEFT")
            lbl:SetTextColor(r or 0.9, g or 0.9, b or 0.9)
            lbl:SetText(text)
            return lbl
        end
        local vX = 170  -- x offset for value column

        HL( -6,  "Points",        1.00, 0.82, 0.20)
        HL(-24,  "Current Honor:", 0.65, 0.65, 0.70) ; honorValues.currHonor = HL(-24,  "—", 1,1,1, vX)
        HL(-42,  "Arena Points:",  0.65, 0.65, 0.70) ; honorValues.arena     = HL(-42,  "—", 1,1,1, vX)

        HL(-64,  "Kills",          1.00, 0.82, 0.20)
        HL(-82,  "Today:",         0.65, 0.65, 0.70) ; honorValues.todayHK   = HL(-82,  "—", 1,1,1, vX)
        HL(-100, "This Week:",     0.65, 0.65, 0.70) ; honorValues.weekHK    = HL(-100, "—", 1,1,1, vX)
        HL(-118, "Last Week:",     0.65, 0.65, 0.70) ; honorValues.lastHK    = HL(-118, "—", 1,1,1, vX)
        HL(-136, "Lifetime:",      0.65, 0.65, 0.70) ; honorValues.lifeHK    = HL(-136, "—", 1,1,1, vX)

        HL(-158, "Contribution",   1.00, 0.82, 0.20)
        HL(-176, "This Week:",     0.65, 0.65, 0.70) ; honorValues.weekContrib = HL(-176, "—", 1,1,1, vX)
        HL(-194, "Last Week:",     0.65, 0.65, 0.70) ; honorValues.lastContrib = HL(-194, "—", 1,1,1, vX)
    end

    -- Wing footer stripe
    local wingFoot = CreateFrame("Frame", nil, f)
    wingFoot:SetSize(WING_W, FOOT_H)
    wingFoot:SetPoint("BOTTOM", f, "BOTTOM", 0, 0)
    FillBg(wingFoot, 0.07, 0.07, 0.10, 1)
end

-- ============================================================
-- Build main frame (lazy, called once)
-- ============================================================
function SC_BuildMain()
    if SlyCharMainFrame then return end

    local f = CreateFrame("Frame", "SlyCharMainFrame", UIParent)
    f:SetSize(FRAME_W, FRAME_H)
    f:SetFrameStrata("DIALOG")
    f:SetMovable(true)
    f:EnableMouse(false)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local pt, _, _, x, y = self:GetPoint()
        SC.db.position = {point=pt or "CENTER", x=x or 0, y=y or 0}
    end)
    f:SetPoint("CENTER")
    f:Hide()

    FillBg(f, 0.05, 0.05, 0.07, 0.97)
    local bord = f:CreateTexture(nil, "OVERLAY")
    bord:SetAllPoints(f) ; bord:SetColorTexture(0.28, 0.28, 0.35, 1)
    local inner = f:CreateTexture(nil, "BACKGROUND")
    inner:SetPoint("TOPLEFT",     f, "TOPLEFT",      1, -1)
    inner:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -1,  1)
    inner:SetColorTexture(0.05, 0.05, 0.07, 0.97)

    -- Header
    local hdr = CreateFrame("Frame", nil, f)
    hdr:SetSize(FRAME_W, HDR_H)
    hdr:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
    FillBg(hdr, 0.09, 0.09, 0.14, 1)

    headerName = hdr:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    headerName:SetFont(headerName:GetFont(), 13, "OUTLINE")
    headerName:SetPoint("LEFT", hdr, "LEFT", PAD, 0)
    headerName:SetText("...")

    headerInfo = hdr:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    headerInfo:SetFont(headerInfo:GetFont(), 10, "")
    headerInfo:SetPoint("CENTER", hdr, "CENTER", 0, 0)
    headerInfo:SetTextColor(0.65, 0.65, 0.65)

    local closeBtn = CreateFrame("Button", nil, hdr, "UIPanelCloseButton")
    closeBtn:SetSize(24, 24)
    closeBtn:SetPoint("RIGHT", hdr, "RIGHT", -2, 0)
    closeBtn:SetScript("OnClick", function() f:Hide() end)

    local resetBtn = CreateFrame("Button", nil, hdr, "UIPanelButtonTemplate")
    resetBtn:SetSize(18, 18)
    resetBtn:SetPoint("RIGHT", closeBtn, "LEFT", -4, 0)
    resetBtn:SetText("o")
    resetBtn:SetScript("OnClick", function()
        SC.db.position = nil
        f:ClearAllPoints() ; f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end)
    resetBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:SetText("Reset position", 1,1,1) ; GameTooltip:Show()
    end)
    resetBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    local hdrSep = f:CreateTexture(nil, "ARTWORK")
    hdrSep:SetSize(FRAME_W, 1)
    hdrSep:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -HDR_H)
    hdrSep:SetColorTexture(0.25, 0.25, 0.32, 1)

    -- Character body (gear + model)
    local charBody = CreateFrame("Frame", nil, f)
    charBody:SetSize(CHAR_W, FRAME_H - HDR_H - FOOT_H)
    charBody:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -HDR_H)

    local div = f:CreateTexture(nil, "ARTWORK")
    div:SetSize(1, FRAME_H - HDR_H - FOOT_H)
    div:SetPoint("TOPLEFT", f, "TOPLEFT", CHAR_W, -HDR_H)
    div:SetColorTexture(0.20, 0.20, 0.27, 1)

    for i, s in ipairs(LEFT_SLOTS) do
        BuildSlot(charBody, s.id, s.label,
            COL_L, SLOT_TOP - (i-1)*(SLOT_S+SLOT_GAP))
    end
    for i, s in ipairs(RIGHT_SLOTS) do
        BuildSlot(charBody, s.id, s.label,
            COL_R, SLOT_TOP - (i-1)*(SLOT_S+SLOT_GAP))
    end
    for i, s in ipairs(WEAPON_SLOTS) do
        BuildSlot(charBody, s.id, s.label,
            WPN_START + (i-1)*(SLOT_S+WPN_GAP), WPN_Y)
    end

    -- Player model
    local modBg = charBody:CreateTexture(nil, "BACKGROUND")
    modBg:SetSize(MODEL_W, MODEL_H)
    modBg:SetPoint("TOPLEFT", charBody, "TOPLEFT", MODEL_X, SLOT_TOP - 12)
    modBg:SetColorTexture(0.03, 0.03, 0.04, 1)

    local model = CreateFrame("PlayerModel", "SlyCharModel", charBody)
    model:SetSize(MODEL_W, MODEL_H)
    model:SetPoint("TOPLEFT", charBody, "TOPLEFT", MODEL_X, SLOT_TOP - 12)
    model:SetUnit("player")
    model:EnableMouse(true)

    local rot, rotating, lastMX = 0, false, 0
    model:SetScript("OnMouseDown", function(self2, btn)
        if btn == "LeftButton" then
            rotating = true
            lastMX   = select(1, GetCursorPosition())
        end
    end)
    model:SetScript("OnMouseUp", function() rotating = false end)
    model:SetScript("OnUpdate", function(self2)
        if rotating then
            local cx2 = select(1, GetCursorPosition())
            rot    = rot - (cx2 - lastMX) * 0.01
            lastMX = cx2
            self2:SetRotation(rot)
        end
    end)

    -- Side panel
    local side = CreateFrame("Frame", nil, f)
    side:SetSize(SIDE_W, FRAME_H - HDR_H - FOOT_H)
    side:SetPoint("TOPLEFT", f, "TOPLEFT", CHAR_W + 1, -HDR_H)
    FillBg(side, 0.05, 0.05, 0.08, 1)

    local tabBar = CreateFrame("Frame", nil, side)
    tabBar:SetSize(SIDE_W, 24)
    tabBar:SetPoint("TOPLEFT", side, "TOPLEFT", 0, 0)
    FillBg(tabBar, 0.07, 0.07, 0.11, 1)

    local tbW = math.floor(SIDE_W / 4)
    local tabDefs = {
        {key="stats",  label="Stats"},
        {key="sets",   label="Sets"},
        {key="rep",    label="Rep"},
        {key="skills", label="Skills"},
    }
    for i, td in ipairs(tabDefs) do
        local btn = CreateFrame("Button", nil, tabBar)
        btn:SetSize(tbW, 24)
        btn:SetPoint("TOPLEFT", tabBar, "TOPLEFT", (i-1)*tbW, 0)

        local tbg = btn:CreateTexture(nil, "BACKGROUND")
        tbg:SetAllPoints(btn) ; tbg:SetColorTexture(0.06,0.06,0.09,1)

        local ttx = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        ttx:SetFont(ttx:GetFont(), 10, "")
        ttx:SetPoint("CENTER", btn, "CENTER", 0, 0)
        ttx:SetText(td.label) ; ttx:SetTextColor(0.55, 0.55, 0.60)

        btn:SetScript("OnClick", function()
            SC_SwitchTab(td.key) ; SC_RefreshAll()
        end)
        tabBtnWidgets[td.key] = {btn=btn, bg=tbg, txt=ttx}
    end

    local tabSep = side:CreateTexture(nil, "ARTWORK")
    tabSep:SetSize(SIDE_W, 1)
    tabSep:SetPoint("TOPLEFT", side, "TOPLEFT", 0, -24)
    tabSep:SetColorTexture(0.20, 0.20, 0.27, 1)

    local tcY = -25
    local tcH = FRAME_H - HDR_H - FOOT_H - 25

    local statsTab = CreateFrame("Frame", nil, side)
    statsTab:SetPoint("TOPLEFT",  side, "TOPLEFT",  0, tcY)
    statsTab:SetPoint("TOPRIGHT", side, "TOPRIGHT", 0, tcY)
    statsTab:SetHeight(tcH) ; statsTab:Hide()
    tabFrames["stats"] = statsTab

    local statsScroll = CreateFrame("ScrollFrame", nil, statsTab, "UIPanelScrollFrameTemplate")
    statsScroll:SetPoint("TOPLEFT",     statsTab, "TOPLEFT",      PAD,  -2)
    statsScroll:SetPoint("BOTTOMRIGHT", statsTab, "BOTTOMRIGHT", -22,    2)
    local statsCont = CreateFrame("Frame", nil, statsScroll)
    statsCont:SetSize(SIDE_W - PAD*2 - 22, MAX_STAT_ROWS * 16)
    statsScroll:SetScrollChild(statsCont)
    BuildStatRows(statsCont)

    local setsTab = CreateFrame("Frame", nil, side)
    setsTab:SetPoint("TOPLEFT",  side, "TOPLEFT",  0, tcY)
    setsTab:SetPoint("TOPRIGHT", side, "TOPRIGHT", 0, tcY)
    setsTab:SetHeight(tcH) ; setsTab:Hide()
    tabFrames["sets"] = setsTab

    local saveLbl = setsTab:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    saveLbl:SetFont(saveLbl:GetFont(), 9, "")
    saveLbl:SetPoint("TOPLEFT", setsTab, "TOPLEFT", PAD, -3)
    saveLbl:SetTextColor(0.5, 0.5, 0.55) ; saveLbl:SetText("Save current as:")

    local saveInput = CreateFrame("EditBox", nil, setsTab, "InputBoxTemplate")
    saveInput:SetSize(SIDE_W - PAD*2 - 52, 17)
    saveInput:SetPoint("TOPLEFT", saveLbl, "BOTTOMLEFT", 0, -1)
    saveInput:SetAutoFocus(false) ; saveInput:SetFontObject("GameFontNormalSmall")
    saveInput:SetScript("OnEscapePressed", function(self2) self2:ClearFocus() end)

    local saveBtn = CreateFrame("Button", nil, setsTab, "UIPanelButtonTemplate")
    saveBtn:SetSize(46, 17) ; saveBtn:SetPoint("LEFT", saveInput, "RIGHT", 3, 0)
    saveBtn:SetText("Save")
    local function doSave()
        local sn = saveInput:GetText()
        if sn and sn:trim() ~= "" and IRR_SaveCurrentSet then
            IRR_SaveCurrentSet(sn:trim())
            saveInput:SetText("") ; saveInput:ClearFocus()
            SC_RefreshSets()
            DEFAULT_CHAT_FRAME:AddMessage(
                "|cff88bbff[SlyChar]|r Saved: |cffffd700"..sn:trim().."|r")
        end
    end
    saveBtn:SetScript("OnClick", doSave)
    saveInput:SetScript("OnEnterPressed", doSave)

    local setSep = setsTab:CreateTexture(nil, "ARTWORK")
    setSep:SetSize(SIDE_W - PAD*2, 1)
    setSep:SetPoint("TOPLEFT", saveInput, "BOTTOMLEFT", 0, -4)
    setSep:SetColorTexture(0.18, 0.18, 0.24, 1)

    local setsScroll = CreateFrame("ScrollFrame", nil, setsTab)
    setsScroll:SetPoint("TOPLEFT",     setsTab, "TOPLEFT",     PAD, -48)
    setsScroll:SetPoint("BOTTOMRIGHT", setsTab, "BOTTOMRIGHT", -4,    2)
    local setsCont = CreateFrame("Frame", nil, setsScroll)
    setsCont:SetSize(SIDE_W - PAD*2 - 4, MAX_SET_ROWS * 22)
    setsScroll:SetScrollChild(setsCont)
    BuildSetRows(setsCont)

    -- Mouse-wheel scrolling (no template scrollbar needed)
    setsScroll:EnableMouseWheel(true)
    setsScroll:SetScript("OnMouseWheel", function(self, delta)
        local cur = self:GetVerticalScroll()
        local max = self:GetVerticalScrollRange()
        self:SetVerticalScroll(math.max(0, math.min(cur - delta * 22 * 3, max)))
    end)

    -- Reputation tab
    local repTab = CreateFrame("Frame", nil, side)
    repTab:SetPoint("TOPLEFT",  side, "TOPLEFT",  0, tcY)
    repTab:SetPoint("TOPRIGHT", side, "TOPRIGHT", 0, tcY)
    repTab:SetHeight(tcH) ; repTab:Hide()
    tabFrames["rep"] = repTab

    local repScroll = CreateFrame("ScrollFrame", nil, repTab, "UIPanelScrollFrameTemplate")
    repScroll:SetPoint("TOPLEFT",     repTab, "TOPLEFT",      PAD,  -2)
    repScroll:SetPoint("BOTTOMRIGHT", repTab, "BOTTOMRIGHT", -22,    2)
    local repCont = CreateFrame("Frame", nil, repScroll)
    repCont:SetSize(SIDE_W - PAD*2 - 22, MAX_REP_ROWS * 16)
    repScroll:SetScrollChild(repCont)
    BuildRepRows(repCont)

    -- Skills tab
    local skillsTab = CreateFrame("Frame", nil, side)
    skillsTab:SetPoint("TOPLEFT",  side, "TOPLEFT",  0, tcY)
    skillsTab:SetPoint("TOPRIGHT", side, "TOPRIGHT", 0, tcY)
    skillsTab:SetHeight(tcH) ; skillsTab:Hide()
    tabFrames["skills"] = skillsTab

    local skillScroll = CreateFrame("ScrollFrame", nil, skillsTab, "UIPanelScrollFrameTemplate")
    skillScroll:SetPoint("TOPLEFT",     skillsTab, "TOPLEFT",      PAD,  -2)
    skillScroll:SetPoint("BOTTOMRIGHT", skillsTab, "BOTTOMRIGHT", -22,    2)
    local skillCont = CreateFrame("Frame", nil, skillScroll)
    skillCont:SetSize(SIDE_W - PAD*2 - 22, MAX_SKILL_ROWS * 14)
    skillScroll:SetScrollChild(skillCont)
    BuildSkillRows(skillCont)

    -- Quick-launch button strip (right edge)
    local stripDiv = f:CreateTexture(nil, "ARTWORK")
    stripDiv:SetSize(1, FRAME_H - HDR_H - FOOT_H)
    stripDiv:SetPoint("TOPLEFT", f, "TOPLEFT", CHAR_W + 1 + SIDE_W, -HDR_H)
    stripDiv:SetColorTexture(0.20, 0.20, 0.27, 1)

    local btnStrip = CreateFrame("Frame", nil, f)
    btnStrip:SetSize(BTN_STRIP_W, FRAME_H - HDR_H - FOOT_H)
    btnStrip:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, -HDR_H)
    FillBg(btnStrip, 0.05, 0.04, 0.08, 1)

    local STRIP_BTNS = {
        { tip="Talents",   desc="Open Talent frame",          lbl="T",   r=0.75, g=0.50, b=1.00,
          fn=function()
              SC_ToggleSidePanel(SC_GetTalentFrame())
          end },
        { tip="Spellbook", desc="Open Spellbook",             lbl="Sp",  r=0.35, g=0.70, b=1.00,
          fn=function()
              SC_OpenPanel("Blizzard_SpellBookUI", "SpellBookFrame", ToggleSpellBook)
          end },
        { tip="Quest Log", desc="Open Quest Log",             lbl="Q",   r=1.00, g=0.78, b=0.15,
          fn=function()
              SC_OpenPanel("Blizzard_QuestLog", "QuestLogFrame", ToggleQuestLog)
          end },
        { tip="World Map", desc="Open World Map",             lbl="M",   r=0.25, g=0.85, b=0.30,
          fn=function()
              SC_OpenPanel("Blizzard_MapCanvas", "WorldMapFrame", ToggleWorldMap)
          end },
        { tip="Friends",   desc="Open Friends / Social",      lbl="Fr",  r=0.25, g=0.70, b=1.00,
          fn=function()
              SC_OpenPanel("Blizzard_SocialUI", "FriendsFrame", ToggleFriendsFrame)
          end },
        { tip="PvP",       desc="Open PvP frame",             lbl="PvP", r=1.00, g=0.30, b=0.20,
          fn=function()
              SC_OpenPanel("Blizzard_PVPUI", "PVPFrame", TogglePVPFrame)
          end },
        { tip="Guild",     desc="Open Guild panel",           lbl="G",   r=0.25, g=1.00, b=0.55,
          fn=function()
              if not GuildFrame then return end
              if GuildFrame:IsShown() then
                  HideUIPanel(GuildFrame)
              else
                  -- Must use ShowUIPanel/ToggleGuildFrame to initialise tabs
                  ShowUIPanel(GuildFrame)
                  -- Reposition next to SlyChar after Blizzard's panel manager settles
                  C_Timer.After(0, function()
                      SC_AnchorRight(GuildFrame)
                  end)
              end
          end },
        { tip="Achievements", desc="Open Achievements panel", lbl="A",   r=1.00, g=0.70, b=0.20,
          fn=function()
              SC_OpenPanel("Blizzard_AchievementUI", "AchievementFrame", ToggleAchievementFrame)
          end },
        { tip="Honor",        desc="View honor & PvP stats",  lbl="Hon", r=1.00, g=0.25, b=0.35,
          fn=function()
              SC_ToggleWing("honor")
          end },
    }

    local bSz = BTN_STRIP_W - 6  -- 26px buttons with 3px margin each side
    for i, bd in ipairs(STRIP_BTNS) do
        local b = CreateFrame("Button", nil, btnStrip)
        b:SetSize(bSz, bSz)
        b:SetPoint("TOP", btnStrip, "TOP", 0, -4 - (i-1)*(bSz + 3))
        b:EnableMouse(true)

        -- border layer (1px colored outline via slightly-larger BACKGROUND texture)
        local bord = b:CreateTexture(nil, "BACKGROUND")
        bord:SetAllPoints(b)
        bord:SetColorTexture(bd.r*0.45, bd.g*0.45, bd.b*0.45, 0.7)

        -- inner fill (ARTWORK inset 1px to reveal border)
        local bbg = b:CreateTexture(nil, "ARTWORK")
        bbg:SetPoint("TOPLEFT",     b, "TOPLEFT",      1, -1)
        bbg:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -1,  1)
        bbg:SetColorTexture(bd.r*0.12, bd.g*0.12, bd.b*0.12, 1)

        local lbl = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        lbl:SetFont(lbl:GetFont(), 8, "OUTLINE")
        lbl:SetPoint("CENTER", b, "CENTER", 0, 0)
        lbl:SetText(bd.lbl)
        lbl:SetTextColor(bd.r, bd.g, bd.b)

        b:SetScript("OnEnter", function()
            bbg:SetColorTexture(bd.r*0.30, bd.g*0.30, bd.b*0.30, 1)
            GameTooltip:SetOwner(b, "ANCHOR_LEFT")
            GameTooltip:SetText(bd.tip, 1, 1, 1)
            GameTooltip:AddLine(bd.desc, 0.7, 0.7, 0.7)
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave", function()
            bbg:SetColorTexture(bd.r*0.12, bd.g*0.12, bd.b*0.12, 1)
            GameTooltip:Hide()
        end)
        b:SetScript("OnClick", bd.fn)
    end

    -- Close-side-panel button (×) at bottom of strip
    do
        local numBtns = #STRIP_BTNS
        local bX = CreateFrame("Button", nil, btnStrip)
        bX:SetSize(bSz, bSz)
        bX:SetPoint("BOTTOM", btnStrip, "BOTTOM", 0, 4)
        bX:EnableMouse(true)
        local bordX = bX:CreateTexture(nil, "BACKGROUND")
        bordX:SetAllPoints(bX)
        bordX:SetColorTexture(0.55, 0.12, 0.12, 0.7)
        local bbgX = bX:CreateTexture(nil, "ARTWORK")
        bbgX:SetPoint("TOPLEFT",     bX, "TOPLEFT",      1, -1)
        bbgX:SetPoint("BOTTOMRIGHT", bX, "BOTTOMRIGHT", -1,  1)
        bbgX:SetColorTexture(0.20, 0.04, 0.04, 1)
        local lblX = bX:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        lblX:SetFont(lblX:GetFont(), 11, "OUTLINE")
        lblX:SetPoint("CENTER", bX, "CENTER", 0, 0)
        lblX:SetText("×")
        lblX:SetTextColor(1, 0.35, 0.35)
        bX:SetScript("OnEnter", function()
            bbgX:SetColorTexture(0.40, 0.08, 0.08, 1)
            GameTooltip:SetOwner(bX, "ANCHOR_LEFT")
            GameTooltip:SetText("Close panel", 1, 1, 1)
            GameTooltip:AddLine("Dismiss current side panel", 0.7, 0.7, 0.7)
            GameTooltip:Show()
        end)
        bX:SetScript("OnLeave", function()
            bbgX:SetColorTexture(0.20, 0.04, 0.04, 1)
            GameTooltip:Hide()
        end)
        bX:SetScript("OnClick", SC_CloseSidePanel)
    end

    -- Footer
    local footer = CreateFrame("Frame", nil, f)
    footer:SetSize(FRAME_W, FOOT_H)
    footer:SetPoint("BOTTOM", f, "BOTTOM", 0, 0)
    FillBg(footer, 0.07, 0.07, 0.10, 1)

    local ftxt = footer:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    ftxt:SetFont(ftxt:GetFont(), 8, "")
    ftxt:SetPoint("LEFT", footer, "LEFT", PAD, 0)
    ftxt:SetTextColor(0.3, 0.3, 0.38)
    ftxt:SetText("C or /slychar  |  left-click = gear picker  |  shift+click = socket  |  right-click = link  |  strip: T·Sp·Q·M·Fr·PvP·G·A·Hon·×")

    f:HookScript("OnShow", function(self) self:EnableMouse(true) end)
    f:HookScript("OnHide", function(self)
        self:EnableMouse(false)
        SC_HidePicker()
        SC_CloseSidePanel()
        if wingFrame then wingFrame:Hide() ; activeWingKey = nil end
    end)

    BuildWingFrame(f)
    SlyCharMainFrame = f

    SC_SwitchTab(SC.db.lastTab or "stats")
end