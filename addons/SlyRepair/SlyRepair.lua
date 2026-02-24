-- SlyRepair.lua
-- Auto-repair all gear when a merchant opens. Reports cost to chat.
-- /slyrepair   -> toggle panel
-- /slyrepair auto | party | raid | say | none  -> set announce channel

local ADDON_NAME    = "SlyRepair"
local ADDON_VERSION = "1.0.0"

local SR = {}
SR.frame = nil

-- ── Defaults ────────────────────────────────────────────────────────────────
local DB_DEFAULTS = {
    enabled   = true,
    sellJunk  = true,     -- auto-sell grey (quality 0) items
    announce  = "auto",   -- auto | party | raid | say | none
    position  = { point = "CENTER", x = 0, y = 120 },
}

local function ApplyDefaults(saved, defaults)
    for k, v in pairs(defaults) do
        if saved[k] == nil then
            if type(v) == "table" then
                saved[k] = {}
                ApplyDefaults(saved[k], v)
            else
                saved[k] = v
            end
        end
    end
end

-- ── Helpers ──────────────────────────────────────────────────────────────────
local function CopperToString(copper)
    local g = math.floor(copper / 10000)
    local s = math.floor((copper % 10000) / 100)
    local c = copper % 100
    local parts = {}
    if g > 0 then parts[#parts+1] = "|cffd4af37" .. g .. "g|r" end
    if s > 0 then parts[#parts+1] = "|cffc0c0c0" .. s .. "s|r" end
    if c > 0 or #parts == 0 then parts[#parts+1] = "|ffb87333" .. c .. "c|r" end
    return table.concat(parts, " ")
end

local function GetAnnounceChannel()
    local ch = SlyRepairDB.announce
    if ch == "auto" then
        if IsInRaid and IsInRaid() then return "RAID"
        elseif IsInGroup and IsInGroup() then return "PARTY"
        else return "SAY" end
    elseif ch == "party" then return "PARTY"
    elseif ch == "raid"  then return "RAID"
    elseif ch == "say"   then return "SAY"
    else return nil end
end

local function Announce(msg)
    local ch = GetAnnounceChannel()
    if ch then
        SendChatMessage("[SlyRepair] " .. msg, ch)
    end
end

-- ── C_Container shims (TBC Anniversary uses C_Container API) ─────────────────
local _GetNumSlots = C_Container and C_Container.GetContainerNumSlots or GetContainerNumSlots
local _GetItemInfo = C_Container and function(bag, slot)
    local info = C_Container.GetContainerItemInfo(bag, slot)
    if not info then return nil end
    return info.iconFileID, info.stackCount, info.isLocked, info.quality, nil, nil, info.hyperlink
end or GetContainerItemInfo
local _GetItemLink = C_Container and C_Container.GetContainerItemLink or GetContainerItemLink
local _UseItem     = C_Container and C_Container.UseContainerItem     or UseContainerItem

-- ── Core logic ──────────────────────────────────────────────────────────────
local function DoSellJunk()
    if not SlyRepairDB.sellJunk then return end
    local total = 0
    local count = 0
    for bag = 0, 4 do
        local slots = _GetNumSlots(bag) or 0
        for slot = 1, slots do
            -- Get the item link first; skip empty slots
            local link = _GetItemLink(bag, slot)
            if link then
                -- GetItemInfo from the link is authoritative for quality and
                -- sell price — avoids the C_Container quality=nil caching issue
                local _, _, quality, _, _, _, _, _, _, _, sellPrice = GetItemInfo(link)
                if quality == 0 and sellPrice and sellPrice > 0 then
                    -- Count from container info (stack size)
                    local stackSize = 1
                    if C_Container then
                        local info = C_Container.GetContainerItemInfo(bag, slot)
                        if info then stackSize = info.stackCount or 1 end
                    else
                        local _, sc = GetContainerItemInfo(bag, slot)
                        stackSize = sc or 1
                    end
                    total = total + sellPrice * stackSize
                    count = count + 1
                    _UseItem(bag, slot)
                end
            end
        end
    end
    if count > 0 then
        local msg = "Sold " .. count .. " junk item" .. (count == 1 and "" or "s") .. " for " .. CopperToString(total)
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff96[SlyRepair]|r " .. msg)
        Announce(msg)
    end
end

local function DoRepair()
    if not SlyRepairDB.enabled then return end

    local cost, canRepair = GetRepairAllCost()
    if not canRepair then
        -- canRepair is false when the vendor doesn't repair, or the data
        -- hasn't loaded yet (try increasing the C_Timer delay if you see this).
        -- Silently ignore if cost is also nil or 0 (most vendors don't repair).
        if cost and cost > 0 then
            DEFAULT_CHAT_FRAME:AddMessage("|cffff6060[SlyRepair]|r Vendor cannot repair -- GetRepairAllCost returned canRepair=false (cost=" .. tostring(cost) .. ").")
        end
        return
    end
    if cost == 0 then return end  -- gear is undamaged, nothing to do

    local myGold = GetMoney()
    if myGold < cost then
        DEFAULT_CHAT_FRAME:AddMessage("|cffff6060[SlyRepair]|r Not enough gold to repair. Need " .. CopperToString(cost) .. ", have " .. CopperToString(myGold))
        return
    end

    RepairAllItems()
    local msg = "Repaired all gear for " .. CopperToString(cost)
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ff96[SlyRepair]|r " .. msg)
    Announce(msg)
end

-- ── UI ───────────────────────────────────────────────────────────────────────
local function BuildUI()
    if SR.frame then SR.frame:Show(); return end

    local f = CreateFrame("Frame", "SlyRepairPanel", UIParent)
    f:SetSize(280, 210)
    f:SetFrameStrata("HIGH")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local pt, _, _, x, y = self:GetPoint()
        SlyRepairDB.position = { point = pt, x = x, y = y }
    end)
    SR.frame = f

    -- Background
    f:SetBackdrop({
        bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 16,
        insets = { left=4, right=4, top=4, bottom=4 },
    })

    -- Title
    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", f, "TOP", 0, -10)
    title:SetText("|cff00ff96Sly|r Repair")

    -- Close button
    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, 0)
    close:SetScript("OnClick", function() f:Hide() end)

    -- Enabled checkbox
    local enableCB = CreateFrame("CheckButton", "SlyRepairEnableCB", f, "UICheckButtonTemplate")
    enableCB:SetPoint("TOPLEFT", f, "TOPLEFT", 16, -40)
    enableCB:SetSize(24, 24)
    SlyRepairEnableCBText:SetText("Auto-repair on merchant open")
    enableCB:SetChecked(SlyRepairDB.enabled)
    enableCB:SetScript("OnClick", function(self)
        SlyRepairDB.enabled = self:GetChecked()
    end)

    -- Sell junk checkbox
    local sellJunkCB = CreateFrame("CheckButton", "SlyRepairSellJunkCB", f, "UICheckButtonTemplate")
    sellJunkCB:SetPoint("TOPLEFT", f, "TOPLEFT", 16, -66)
    sellJunkCB:SetSize(24, 24)
    SlyRepairSellJunkCBText:SetText("Auto-sell junk (grey items)")
    sellJunkCB:SetChecked(SlyRepairDB.sellJunk)
    sellJunkCB:SetScript("OnClick", function(self)
        SlyRepairDB.sellJunk = self:GetChecked()
    end)

    -- Announce label
    local annLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    annLabel:SetPoint("TOPLEFT", f, "TOPLEFT", 16, -106)
    annLabel:SetText("Announce channel:")

    -- Channel buttons
    local channels = { "auto", "party", "raid", "say", "none" }
    local btns = {}
    for i, ch in ipairs(channels) do
        local btn = CreateFrame("Button", "SlyRepairCh_"..ch, f, "UIPanelButtonTemplate")
        btn:SetSize(46, 22)
        btn:SetPoint("TOPLEFT", f, "TOPLEFT", 8 + (i-1)*52, -128)
        btn:SetText(ch)
        btn.ch = ch
        btn:SetScript("OnClick", function(self)
            SlyRepairDB.announce = self.ch
            for _, b in ipairs(btns) do
                b:SetNormalFontObject(SlyRepairDB.announce == b.ch and "GameFontHighlightSmall" or "GameFontNormalSmall")
                b:GetNormalTexture():SetVertexColor(SlyRepairDB.announce == b.ch and 0.3 or 1, SlyRepairDB.announce == b.ch and 1 or 1, SlyRepairDB.announce == b.ch and 0.3 or 1)
            end
        end)
        btns[i] = btn
    end

    -- Repair Now button
    local repairBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    repairBtn:SetSize(120, 26)
    repairBtn:SetPoint("BOTTOM", f, "BOTTOM", 0, 18)
    repairBtn:SetText("Repair Now")
    repairBtn:SetScript("OnClick", function()
        if not MerchantFrame or not MerchantFrame:IsShown() then
            DEFAULT_CHAT_FRAME:AddMessage("|cffff6060[SlyRepair]|r Open a merchant first.")
        else
            DoRepair()
        end
    end)

    -- Restore position
    local p = SlyRepairDB.position
    f:ClearAllPoints()
    f:SetPoint(p.point, UIParent, p.point, p.x, p.y)
    f:Show()
end

-- ── Event handling ────────────────────────────────────────────────────────────
local function Init()
    SlyRepairDB = SlyRepairDB or {}
    ApplyDefaults(SlyRepairDB, DB_DEFAULTS)

    local ev = CreateFrame("Frame")

    ev:RegisterEvent("MERCHANT_SHOW")
    ev:SetScript("OnEvent", function(self, event)
        if event == "MERCHANT_SHOW" then
            -- Small delay: merchant frame initialises repair data one frame
            -- after MERCHANT_SHOW fires, so GetRepairAllCost() is 0 if called
            -- immediately.
            C_Timer.After(0.3, function()
                -- Protect independently: a junk-sell error must not prevent repair
                local ok, err = pcall(DoSellJunk)
                if not ok then
                    DEFAULT_CHAT_FRAME:AddMessage("|cffff6060[SlyRepair]|r DoSellJunk error: " .. tostring(err))
                end
                DoRepair()
            end)
        end
    end)

    SLASH_SLYREPAIR1 = "/slyrepair"
    SlashCmdList["SLYREPAIR"] = function(msg)
        msg = (msg or ""):lower():match("^%s*(.-)%s*$")
        if msg == "" then
            if SR.frame and SR.frame:IsShown() then SR.frame:Hide()
            else BuildUI() end
        elseif msg == "auto" or msg == "party" or msg == "raid" or msg == "say" or msg == "none" then
            SlyRepairDB.announce = msg
            DEFAULT_CHAT_FRAME:AddMessage("|cff00ff96[SlyRepair]|r Announce set to: " .. msg)
        elseif msg == "enable" or msg == "on" then
            SlyRepairDB.enabled = true
            DEFAULT_CHAT_FRAME:AddMessage("|cff00ff96[SlyRepair]|r Auto-repair enabled.")
        elseif msg == "disable" or msg == "off" then
            SlyRepairDB.enabled = false
            DEFAULT_CHAT_FRAME:AddMessage("|cff00ff96[SlyRepair]|r Auto-repair disabled.")
        elseif msg == "junk" then
            SlyRepairDB.sellJunk = not SlyRepairDB.sellJunk
            DEFAULT_CHAT_FRAME:AddMessage("|cff00ff96[SlyRepair]|r Auto-sell junk " .. (SlyRepairDB.sellJunk and "enabled" or "disabled") .. ".")
        else
            DEFAULT_CHAT_FRAME:AddMessage("|cff00ff96[SlyRepair]|r Commands: /slyrepair | auto | party | raid | say | none | enable | disable | junk")
        end
    end
end

-- ── SlySuite registration (with standalone fallback) ─────────────────────────
local bootFrame = CreateFrame("Frame")
bootFrame:RegisterEvent("ADDON_LOADED")
bootFrame:SetScript("OnEvent", function(self, event, name)
    if name ~= ADDON_NAME then return end
    self:UnregisterEvent("ADDON_LOADED")
    if SlySuite_Register then
        SlySuite_Register(ADDON_NAME, ADDON_VERSION, Init, {
            description = "Auto-repair gear at merchants. Reports cost to chat.",
            slash       = "/slyrepair",
            icon        = "Interface\\Icons\\INV_Hammer_20",
        })
    else
        Init()
    end
end)
