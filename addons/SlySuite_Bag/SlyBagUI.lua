-- ============================================================
-- SlyBagUI.lua  �  Unified bag window, Baginator-style categories
-- Items are grouped by item type: Weapons, Armor, Consumables,
-- Trade Goods, Recipes, Quest Items, Bags, Keys, Misc.
-- ============================================================

local SLOT_SIZE   = 36
local SLOT_PAD    = 4
local CELL        = SLOT_SIZE + SLOT_PAD   -- 40
local COLS        = 10
local SIDE_PAD    = 8
local SECTION_H   = 20
local FRAME_W     = COLS * CELL + SIDE_PAD * 2   -- 408
local GRID_VIEW_H = 480
local HEADER_H    = 28
local SEARCH_H    = 28
local FOOTER_H    = 22
local FRAME_H     = HEADER_H + SEARCH_H + GRID_VIEW_H + FOOTER_H + 12

local QUAL_COLORS = {
    [0] = { 0.62, 0.62, 0.62 },
    [1] = { 1.00, 1.00, 1.00 },
    [2] = { 0.12, 1.00, 0.00 },
    [3] = { 0.00, 0.44, 0.87 },
    [4] = { 0.64, 0.21, 0.93 },
    [5] = { 1.00, 0.50, 0.00 },
    [6] = { 0.90, 0.80, 0.50 },
}

-- Category definitions (display order matters)
local CATEGORIES = {
    { id="WEAPON",     label="Weapons",          r=0.90, g=0.55, b=0.15, bg={0.22,0.12,0.04} },
    { id="ARMOR",      label="Armor",            r=0.30, g=0.60, b=1.00, bg={0.05,0.10,0.26} },
    { id="RESISTANCE", label="Resistance Gear",  r=0.20, g=0.90, b=0.80, bg={0.04,0.20,0.18} },
    { id="CONSUMABLE", label="Consumables",      r=0.20, g=0.90, b=0.40, bg={0.04,0.20,0.08} },
    { id="TRADESKILL", label="Trade Goods",      r=0.80, g=0.75, b=0.30, bg={0.20,0.18,0.04} },
    { id="RECIPE",     label="Recipes",          r=1.00, g=0.50, b=0.80, bg={0.22,0.05,0.14} },
    { id="QUEST",      label="Quest Items",      r=1.00, g=0.90, b=0.10, bg={0.24,0.20,0.02} },
    { id="CONTAINER",  label="Bags",             r=0.65, g=0.55, b=0.40, bg={0.14,0.11,0.07} },
    { id="KEY",        label="Keys",             r=1.00, g=0.82, b=0.00, bg={0.22,0.18,0.00} },
    { id="MISC",       label="Misc",             r=0.55, g=0.55, b=0.60, bg={0.10,0.10,0.14} },
    { id="JUNK",       label="Junk  (auto-sell)",        r=0.80, g=0.20, b=0.15, bg={0.20,0.04,0.04} },
}

-- Maps localized TBC item-type strings to category ids
local TYPE_MAP = {
    ["Weapon"]="WEAPON", ["Weapons"]="WEAPON",
    ["Armor"]="ARMOR",
    ["Consumable"]="CONSUMABLE", ["Consumables"]="CONSUMABLE",
    ["Food & Drink"]="CONSUMABLE", ["Potion"]="CONSUMABLE",
    ["Elixir"]="CONSUMABLE", ["Flask"]="CONSUMABLE", ["Bandage"]="CONSUMABLE",
    ["Trade Goods"]="TRADESKILL", ["Reagent"]="TRADESKILL",
    ["Metal & Stone"]="TRADESKILL", ["Cloth"]="TRADESKILL",
    ["Leather"]="TRADESKILL", ["Herb"]="TRADESKILL", ["Elemental"]="TRADESKILL",
    ["Enchanting"]="TRADESKILL", ["Parts"]="TRADESKILL", ["Devices"]="TRADESKILL",
    ["Projectile"]="TRADESKILL", ["Items"]="TRADESKILL",
    ["Recipe"]="RECIPE", ["Recipes"]="RECIPE", ["Book"]="RECIPE",
    ["Plans"]="RECIPE", ["Designs"]="RECIPE", ["Patterns"]="RECIPE",
    ["Schematics"]="RECIPE", ["Formulas"]="RECIPE",
    ["Quest"]="QUEST",
    ["Key"]="KEY", ["Keys"]="KEY",
    ["Container"]="CONTAINER", ["Bag"]="CONTAINER", ["Quiver"]="CONTAINER",
    ["Soul Bag"]="CONTAINER", ["Ammo Pouch"]="CONTAINER",
    ["Gem"]="MISC", ["Gems"]="MISC", ["Miscellaneous"]="MISC",
    ["Junk"]="JUNK",   -- grey items — SlyRepair auto-sells these
    ["Glyph"]="MISC", ["Companion Pets"]="MISC",
    ["Holiday"]="MISC", ["Other"]="MISC", ["WoW Token"]="MISC", ["Mount"]="MISC",
}

local function GetItemCategory(link)
    if not link then return "MISC" end
    local _, _, _, _, _, itemType = GetItemInfo(link)
    if not itemType then return "MISC" end
    return TYPE_MAP[itemType] or "MISC"
end

-- Resistance-item detection via hidden scanning tooltip (cached per itemId)
local _resScanTip
local _resCache = {}
local function IsResistanceItem(link)
    if not link then return false end
    local itemId = link:match("|Hitem:(%d+):")
    if not itemId then return false end
    if _resCache[itemId] ~= nil then return _resCache[itemId] end
    if not _resScanTip then
        _resScanTip = CreateFrame("GameTooltip", "SlyBagResistScan", nil, "GameTooltipTemplate")
        _resScanTip:SetOwner(WorldFrame, "ANCHOR_NONE")
    end
    _resScanTip:ClearLines()
    _resScanTip:SetHyperlink(link)
    local found = false
    for i = 2, _resScanTip:NumLines() do
        local lf = _G["SlyBagResistScanTextLeft"..i]
        if lf then
            local txt = lf:GetText() or ""
            if txt:find("Resistance") then found = true; break end
        end
    end
    _resCache[itemId] = found
    return found
end

-- Extract numeric item ID from a hyperlink
local function ItemIdFromLink(link)
    if not link then return nil end
    return tonumber(link:match("|Hitem:(%d+):"))
end

-- Build itemId -> list-of-set-names map from IRR gear sets
local function BuildSetMap()
    local map = {}
    local irrSets = IRR and IRR.db and IRR.db.sets
    if not irrSets then return map end
    for setName, slots in pairs(irrSets) do
        for _, itemId in pairs(slots) do
            if type(itemId) == "number" then
                if not map[itemId] then map[itemId] = {} end
                map[itemId][#map[itemId]+1] = setName
            end
        end
    end
    return map
end

-- Sorted list of gear set names for stable display order
local function GetSetNames()
    local irrSets = IRR and IRR.db and IRR.db.sets
    if not irrSets then return {} end
    local names = {}
    for name in pairs(irrSets) do names[#names+1] = name end
    table.sort(names)
    return names
end

-- Colour palette cycling across gear-set sections
local SET_TINTS = {
    { r=0.25, g=0.85, b=0.85, bg={0.04,0.18,0.20} },
    { r=0.80, g=0.40, b=0.90, bg={0.18,0.06,0.22} },
    { r=0.85, g=0.70, b=0.20, bg={0.20,0.16,0.04} },
    { r=0.30, g=0.85, b=0.45, bg={0.05,0.20,0.10} },
    { r=0.90, g=0.45, b=0.25, bg={0.22,0.10,0.05} },
    { r=0.45, g=0.65, b=1.00, bg={0.08,0.12,0.24} },
}

-- C_Container shims
local _NumSlots, _ItemLink, _ItemInfo, _UseItem, _PickupItem
if C_Container then
    _NumSlots   = C_Container.GetContainerNumSlots  or GetContainerNumSlots
    _ItemLink   = C_Container.GetContainerItemLink  or GetContainerItemLink
    _ItemInfo   = function(bag, slot)
        local info = C_Container.GetContainerItemInfo(bag, slot)
        if not info then return nil end
        return info.iconFileID, info.stackCount, info.isLocked, info.quality, info.hyperlink
    end
    _UseItem    = C_Container.UseContainerItem    or UseContainerItem
    _PickupItem = C_Container.PickupContainerItem or PickupContainerItem
else
    _NumSlots   = GetContainerNumSlots
    _ItemLink   = GetContainerItemLink
    _ItemInfo   = function(bag, slot)
        local tex, cnt, locked, qual, _, _, link = GetContainerItemInfo(bag, slot)
        return tex, cnt, locked, qual, link
    end
    _UseItem    = UseContainerItem
    _PickupItem = PickupContainerItem
end

local slotBtns    = {}
local sectionHdrs = {}
local searchText  = ""

local function NewSlotButton(parent, idx)
    local b = CreateFrame("Button", "SlyBagSlot" .. idx, parent)
    b:SetSize(SLOT_SIZE, SLOT_SIZE)
    local bg = b:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints() ; bg:SetColorTexture(0.10, 0.10, 0.13, 1) ; b.bg = bg
    local icon = b:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("TOPLEFT",     b, "TOPLEFT",     2, -2)
    icon:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -2,  2)
    b.icon = icon
    local cnt = b:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    cnt:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -2, 2) ; b.count = cnt
    local hl = b:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetTexture("Interface\\Buttons\\ButtonHilight-Square")
    hl:SetBlendMode("ADD")
    -- Quality border: 4 solid 2px edge textures (no texture file — avoids the
    -- UI-ActionButton-Border size mismatch that caused a small square artefact)
    local qTop = b:CreateTexture(nil, "OVERLAY")
    qTop:SetPoint("TOPLEFT",  b, "TOPLEFT",  0,  0)
    qTop:SetPoint("TOPRIGHT", b, "TOPRIGHT", 0,  0)
    qTop:SetHeight(2); qTop:Hide(); b.qTop = qTop
    local qBot = b:CreateTexture(nil, "OVERLAY")
    qBot:SetPoint("BOTTOMLEFT",  b, "BOTTOMLEFT",  0, 0)
    qBot:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 0, 0)
    qBot:SetHeight(2); qBot:Hide(); b.qBot = qBot
    local qLeft = b:CreateTexture(nil, "OVERLAY")
    qLeft:SetPoint("TOPLEFT",    b, "TOPLEFT",    0,  0)
    qLeft:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT", 0,  0)
    qLeft:SetWidth(2); qLeft:Hide(); b.qLeft = qLeft
    local qRight = b:CreateTexture(nil, "OVERLAY")
    qRight:SetPoint("TOPRIGHT",    b, "TOPRIGHT",    0, 0)
    qRight:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 0, 0)
    qRight:SetWidth(2); qRight:Hide(); b.qRight = qRight
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b:SetScript("OnEnter", function(self)
        if self.bag ~= nil then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetBagItem(self.bag, self.slot)
            GameTooltip:Show()
        end
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    b:SetScript("OnClick", function(self, btn)
        if self.bag == nil then return end
        if btn == "LeftButton" then
            if MerchantFrame and MerchantFrame:IsShown() then
                _UseItem(self.bag, self.slot)    -- sell at vendor
            else
                _PickupItem(self.bag, self.slot)
            end
            C_Timer.After(0.05, SlyBag_Refresh)
        elseif btn == "RightButton" then
            _UseItem(self.bag, self.slot)
            -- Check a frame later whether UseContainerItem placed the item on
            -- the cursor (armor kit, enchant scroll, stone, poison, etc.).
            -- If so, open SlyChar automatically so the player can click the
            -- equipped slot to apply the effect — the secure /use overlays in
            -- SlyChar handle all cursor-item interactions.
            C_Timer.After(0.025, function()
                local ctype = GetCursorInfo()
                if ctype then
                    -- Targeting mode: show the character sheet for slot clicking
                    if SC_ShowMain then SC_ShowMain() end
                    C_Timer.After(0.5, SlyBag_Refresh)
                else
                    C_Timer.After(0.03, SlyBag_Refresh)
                end
            end)
        end
    end)
    b:Hide()
    return b
end

local function NewSectionHeader(parent, idx)
    local f = CreateFrame("Frame", "SlyBagSection" .. idx, parent)
    f:SetHeight(SECTION_H)
    local bg = f:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints() ; f.bg = bg
    local accent = f:CreateTexture(nil, "ARTWORK")
    accent:SetSize(3, SECTION_H) ; accent:SetPoint("LEFT", f, "LEFT", 0, 0) ; f.accent = accent
    local lbl = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    lbl:SetPoint("LEFT", f, "LEFT", SIDE_PAD, 0) ; lbl:SetJustifyH("LEFT") ; f.lbl = lbl
    local cntLbl = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    cntLbl:SetPoint("RIGHT", f, "RIGHT", -SIDE_PAD, 0)
    cntLbl:SetJustifyH("RIGHT") ; cntLbl:SetTextColor(0.50, 0.50, 0.60) ; f.cntLbl = cntLbl
    f:Hide()
    return f
end

-- SlyBag_Refresh
function SlyBag_Refresh()
    if not SlyBagFrame then return end
    if not SlyBagFrame.content then return end
    local SlyBagContent = SlyBagFrame.content
    local filter = searchText:lower()

    -- Build New Items list from tracked acquisitions (expire after 75 seconds)
    local NEW_ITEM_TTL = 75
    local newItemList = {}
    local skipSlots   = {}  -- bag|slot keys in newItemList; excluded from normal buckets
    local staleKeys   = {}  -- keys to remove after iteration
    local now = GetTime()
    for key, loc in pairs(SlyBag.newItems or {}) do
        -- Expire old entries
        if loc.time and (now - loc.time) > NEW_ITEM_TTL then
            staleKeys[#staleKeys+1] = key
        else
            local tex, stackCnt, _, quality, link = _ItemInfo(loc.bag, loc.slot)
            if not link and tex then
                link = _ItemLink and _ItemLink(loc.bag, loc.slot) or nil
            end
            if tex then
                local itemName = (link and GetItemInfo(link)) or ""
                local passes = (filter == "") or itemName:lower():find(filter, 1, true)
                if passes then
                    newItemList[#newItemList+1] = {
                        bag=loc.bag, slot=loc.slot, texture=tex,
                        count=stackCnt or 0, quality=quality or -1, name=itemName,
                    }
                    skipSlots[loc.bag.."|"..loc.slot] = true
                end
            else
                staleKeys[#staleKeys+1] = key  -- item gone; retire after loop
            end
        end
    end
    for _, k in ipairs(staleKeys) do SlyBag.newItems[k] = nil end

    -- Collect and bucket all bag slots
    local buckets  = {}
    local setMap   = BuildSetMap()
    local setNames = GetSetNames()
    local total, used = 0, 0

    for bag = 0, 4 do
        local n = _NumSlots(bag) or 0
        for slot = 1, n do
            total = total + 1
            local tex, stackCnt, _, quality, link = _ItemInfo(bag, slot)
            if not link and tex then
                link = _ItemLink and _ItemLink(bag, slot) or nil
            end
            if tex then
                local itemName = ""
                if link then
                    itemName = GetItemInfo(link) or ""
                    used = used + 1
                end
                local passes = (filter == "")
                    or itemName:lower():find(filter, 1, true)
                if passes and not skipSlots[bag.."|"..slot] then
                    local it = {
                        bag=bag, slot=slot, texture=tex,
                        count=stackCnt or 0, quality=quality or -1, name=itemName,
                    }
                    if quality == 0 then
                        -- Grey / poor quality = junk, SlyRepair auto-sells these
                        if not buckets["JUNK"] then buckets["JUNK"] = {} end
                        buckets["JUNK"][#buckets["JUNK"]+1] = it
                    else
                        -- Check gear-set membership (takes priority over type cat)
                        local itemId = ItemIdFromLink(link)
                        local sets   = itemId and setMap[itemId]
                        if sets and #sets > 0 then
                            local key = "SET:"..sets[1]
                            if not buckets[key] then buckets[key] = {} end
                            buckets[key][#buckets[key]+1] = it
                        else
                            local cat
                            if link and IsResistanceItem(link) then
                                cat = "RESISTANCE"
                            else
                                cat = link and GetItemCategory(link) or "MISC"
                            end
                            if not buckets[cat] then buckets[cat] = {} end
                            buckets[cat][#buckets[cat]+1] = it
                        end
                    end
                end
            end
        end
    end

    -- Build visible sections: new items first, then gear sets, then type categories
    local visible = {}
    if #newItemList > 0 then
        visible[#visible+1] = {
            def = { label="New Items", r=1.00, g=0.85, b=0.15, bg={0.22,0.17,0.02} },
            items = newItemList,
        }
    end
    for i, setName in ipairs(setNames) do
        local items = buckets["SET:"..setName]
        if items and #items > 0 then
            local ti = SET_TINTS[((i-1) % #SET_TINTS) + 1]
            visible[#visible+1] = {
                def = { label="Set: "..setName, r=ti.r, g=ti.g, b=ti.b, bg=ti.bg },
                items = items,
            }
        end
    end
    for _, catDef in ipairs(CATEGORIES) do
        local items = buckets[catDef.id]
        if items and #items > 0 then
            visible[#visible+1] = { def=catDef, items=items }
        end
    end

    -- Build virtual row list
    local rows = {}
    for _, sec in ipairs(visible) do
        rows[#rows+1] = { type="header", sec=sec }
        for i = 1, #sec.items, COLS do
            local row = { type="items", slots={} }
            for j = i, math.min(i+COLS-1, #sec.items) do
                row.slots[#row.slots+1] = sec.items[j]
            end
            rows[#rows+1] = row
        end
    end

    -- Resize content frame
    local contentH = SLOT_PAD
    for _, row in ipairs(rows) do
        contentH = contentH + (row.type=="header" and (SECTION_H+2) or CELL)
    end
    SlyBagContent:SetHeight(math.max(GRID_VIEW_H, contentH))

    -- Render widgets
    local btnI, hdrI, curY = 0, 0, -SLOT_PAD

    for _, row in ipairs(rows) do
        if row.type == "header" then
            hdrI = hdrI + 1
            local h = sectionHdrs[hdrI]
            if not h then h = NewSectionHeader(SlyBagContent, hdrI); sectionHdrs[hdrI]=h end
            h:ClearAllPoints()
            h:SetPoint("TOPLEFT",  SlyBagContent, "TOPLEFT",  0, curY)
            h:SetPoint("TOPRIGHT", SlyBagContent, "TOPRIGHT", 0, curY)
            local def = row.sec.def
            local bg  = def.bg
            h.bg:SetColorTexture(bg[1], bg[2], bg[3], 0.92)
            h.accent:SetColorTexture(def.r, def.g, def.b, 1)
            h.lbl:SetText(string.format("|cff%02x%02x%02x%s|r",
                math.floor(def.r*255), math.floor(def.g*255), math.floor(def.b*255), def.label))
            local n = #row.sec.items
            h.cntLbl:SetText(n .. (n==1 and " item" or " items"))
            h:Show()
            curY = curY - (SECTION_H + 2)
        else
            for colPos, it in ipairs(row.slots) do
                btnI = btnI + 1
                local b = slotBtns[btnI]
                if not b then b = NewSlotButton(SlyBagContent, btnI); slotBtns[btnI]=b end
                b:ClearAllPoints()
                b:SetPoint("TOPLEFT", SlyBagContent, "TOPLEFT",
                    SIDE_PAD + (colPos-1)*CELL, curY)
                b.bag=it.bag ; b.slot=it.slot
                b.icon:SetTexture(it.texture) ; b.icon:SetAlpha(1)
                b.count:SetText(it.count > 1 and it.count or "")
                local qc = QUAL_COLORS[it.quality]
                if qc then
                    local r,g,bv = qc[1],qc[2],qc[3]
                    b.qTop:SetColorTexture(r,g,bv,1);   b.qTop:Show()
                    b.qBot:SetColorTexture(r,g,bv,1);   b.qBot:Show()
                    b.qLeft:SetColorTexture(r,g,bv,1);  b.qLeft:Show()
                    b.qRight:SetColorTexture(r,g,bv,1); b.qRight:Show()
                else
                    b.qTop:Hide(); b.qBot:Hide(); b.qLeft:Hide(); b.qRight:Hide()
                end
                b:Show()
            end
            curY = curY - CELL
        end
    end

    for i = btnI+1, #slotBtns    do slotBtns[i]:Hide()    end
    for i = hdrI+1, #sectionHdrs do sectionHdrs[i]:Hide() end

    -- Footer
    local gTx = SlyBagFrame and SlyBagFrame.goldTx
    local sTx = SlyBagFrame and SlyBagFrame.slotTx
    if gTx then
        local gold = GetMoney()
        gTx:SetFormattedText(
            "|cffffcc00%d|rg |cffc0c0c0%d|rs |cffcc7700%d|rc",
            math.floor(gold/10000), math.floor((gold%10000)/100), gold%100)
    end
    if sTx then
        sTx:SetText(used.."/"..total.." slots used")
    end
end

-- SlyBag_BuildUI
function SlyBag_BuildUI()
    if SlyBagFrame then return end
    local db = SlyBag.db
    local f = CreateFrame("Frame", "SlyBagFrame", UIParent)
    f:SetSize(FRAME_W, FRAME_H)
    f:SetPoint(db.position.point, UIParent, db.position.point, db.position.x, db.position.y)
    f:SetMovable(true) ; f:EnableMouse(true) ; f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local p,_,_,x,y = self:GetPoint()
        SlyBag.db.position = { point=p, x=x, y=y }
    end)
    -- Themed background — repainted automatically when user cycles theme in SlyChar.
    local function _repaintBagBg()
        local th = SlyStyle and SlyStyle.GetTheme() or nil
        local fr = th and th.frameBg or {0.07,0.07,0.10,0.96}
        local br = th and th.border  or {0.30,0.30,0.40,1}
        if f.SetBackdrop then
            f:SetBackdropColor(fr[1],fr[2],fr[3], fr[4] or 0.96)
            f:SetBackdropBorderColor(br[1],br[2],br[3],1)
        end
    end
    if f.SetBackdrop then
        f:SetBackdrop({ bgFile="Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",
            tile=true, tileSize=16, edgeSize=12,
            insets={left=3,right=3,top=3,bottom=3} })
        _repaintBagBg()
        if SlyStyle then SlyStyle.OnThemeChange(_repaintBagBg) end
    else
        local _bgTex = f:CreateTexture(nil,"BACKGROUND")
        _bgTex:SetAllPoints()
        if SlyStyle then
            SlyStyle.Paint(_bgTex, "frameBg")
            SlyStyle.OnThemeChange(function() SlyStyle.Paint(_bgTex, "frameBg") end)
        else
            _bgTex:SetColorTexture(0.07,0.07,0.10,0.96)
        end
    end

    -- Header
    local title = f:CreateFontString(nil,"OVERLAY","GameFontNormalLarge")
    title:SetPoint("TOPLEFT", f, "TOPLEFT", SIDE_PAD+2, -8)
    title:SetText("|cff00ccffSly|r Bags")
    local closeBtn = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", 2, 2)
    closeBtn:SetScript("OnClick", function() f:Hide() end)

    -- Search bar
    local sbarBg = f:CreateTexture(nil,"ARTWORK")
    sbarBg:SetPoint("TOPLEFT",  f,"TOPLEFT",  SIDE_PAD,  -(HEADER_H+4))
    sbarBg:SetPoint("TOPRIGHT", f,"TOPRIGHT", -SIDE_PAD, -(HEADER_H+4))
    sbarBg:SetHeight(SEARCH_H-4)
    if SlyStyle then
        SlyStyle.Paint(sbarBg, "headerBg")
        SlyStyle.OnThemeChange(function() SlyStyle.Paint(sbarBg, "headerBg") end)
    else
        sbarBg:SetColorTexture(0.13,0.13,0.17,1)
    end
    local sbox = CreateFrame("EditBox","SlyBagSearch",f)
    sbox:SetPoint("TOPLEFT",  f,"TOPLEFT",  SIDE_PAD+6,      -(HEADER_H+6))
    sbox:SetPoint("TOPRIGHT", f,"TOPRIGHT", -(SIDE_PAD+22),  -(HEADER_H+6))
    sbox:SetHeight(SEARCH_H-8) ; sbox:SetFontObject("ChatFontNormal")
    sbox:SetAutoFocus(false) ; sbox:SetMaxLetters(64)
    local hint = sbox:CreateFontString(nil,"OVERLAY","GameFontDisable")
    hint:SetPoint("LEFT", sbox,"LEFT", 0, 0) ; hint:SetText("Search items...")
    sbox:SetScript("OnTextChanged", function(self)
        local txt = self:GetText()
        hint:SetShown(txt=="") ; searchText=txt ; SlyBag_Refresh()
    end)
    sbox:SetScript("OnEscapePressed", function(self) self:SetText(""); self:ClearFocus() end)
    local clearBtn = CreateFrame("Button", nil, f)
    clearBtn:SetSize(16,16) ; clearBtn:SetPoint("RIGHT", sbarBg,"RIGHT", -4, 0)
    local clrTex = clearBtn:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
    clrTex:SetText("x") ; clrTex:SetPoint("CENTER") ; clrTex:SetTextColor(0.6,0.6,0.7)
    clearBtn:SetScript("OnClick", function() sbox:SetText("") end)

    -- Scroll frame
    local sf = CreateFrame("ScrollFrame","SlyBagScroll",f)
    sf:SetPoint("TOPLEFT",     f,"TOPLEFT",     SIDE_PAD, -(HEADER_H+SEARCH_H+4))
    sf:SetPoint("BOTTOMRIGHT", f,"BOTTOMRIGHT", -SIDE_PAD, FOOTER_H+6)
    sf:EnableMouseWheel(true)
    sf:SetScript("OnMouseWheel", function(self, delta)
        local cur = self:GetVerticalScroll()
        local max = self:GetVerticalScrollRange()
        self:SetVerticalScroll(math.max(0, math.min(max, cur - delta*CELL)))
    end)
    local content = CreateFrame("Frame","SlyBagContent",sf)
    content:SetWidth(FRAME_W - SIDE_PAD*2) ; content:SetHeight(GRID_VIEW_H)
    sf:SetScrollChild(content)
    f.content = content

    -- Footer
    local footLine = f:CreateTexture(nil,"ARTWORK")
    footLine:SetPoint("BOTTOMLEFT",  f,"BOTTOMLEFT",  SIDE_PAD,  FOOTER_H+4)
    footLine:SetPoint("BOTTOMRIGHT", f,"BOTTOMRIGHT", -SIDE_PAD, FOOTER_H+4)
    footLine:SetHeight(1)
    if SlyStyle then
        SlyStyle.Paint(footLine, "div")
        SlyStyle.OnThemeChange(function() SlyStyle.Paint(footLine, "div") end)
    else
        footLine:SetColorTexture(0.3,0.3,0.4,0.5)
    end
    local goldTx = f:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
    goldTx:SetPoint("BOTTOMLEFT", f,"BOTTOMLEFT", SIDE_PAD+2, 6)
    f.goldTx = goldTx
    local slotTx = f:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
    slotTx:SetPoint("BOTTOMRIGHT", f,"BOTTOMRIGHT", -(SIDE_PAD+2), 6)
    slotTx:SetTextColor(0.55,0.55,0.62)    f.slotTx = slotTx
    f:SetScript("OnShow", function() SlyBag_Refresh() end)
    f:SetScript("OnHide", function() SlyBag.newItems = {} end)
    f:Hide()
end
