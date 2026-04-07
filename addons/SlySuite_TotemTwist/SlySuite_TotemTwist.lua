-- ============================================================
-- SlySuite_TotemTwist
-- WFT <-> GoAT totem twist timer for TBC Anniversary Shamans.
--
-- Drop Windfury Totem → 10-second buff window starts.
-- Alert at 8.5 s: drop Grace of Air, immediately re-drop WFT
-- to clip the 9-second mark and maintain continuous WFT coverage
-- while briefly applying the GoAT agility bonus.
--
-- /slytwist          toggle show/hide
-- /slytwist lock     lock in place
-- /slytwist unlock   allow dragging
-- /slytwist reset    move to default position
-- ============================================================

local ADDON_NAME = "SlySuite_TotemTwist"
local VERSION    = "1.5.1"

-- ────────────────────────────────────────────────────────────
-- Timing constants
-- WFT buff in TBC lasts 10 s.  Twist by dropping GoAT at ~8.5 s,
-- then immediately WFT to clip at the 9-second mark.
-- ────────────────────────────────────────────────────────────
local WFT_DURATION  = 10.0   -- full buff window (seconds)
local WARN_AT       = 7.0    -- yellow caution phase starts
local TWIST_AT      = 8.5    -- red/flash TWIST phase starts
local GOAT_FLASH_DUR = 1.0   -- how long "DROP WFT!" stays on screen

-- ────────────────────────────────────────────────────────────
-- Spell name matching (all ranks auto-match via prefix)
-- ────────────────────────────────────────────────────────────
local WFT_PATTERN  = "Windfury Totem"
local GOAT_PATTERN = "Grace of Air Totem"

-- ────────────────────────────────────────────────────────────
-- Module state
-- ────────────────────────────────────────────────────────────
local TT = {}
TT.db = nil

local state        = "idle"   -- idle | wft | goat | expired
local wftDropTime  = 0
local goatFlashEnd = 0
local pulseT       = 0        -- for red-phase pulse

-- DB defaults
local DB_DEFAULTS = {
    locked   = false,
    shown    = true,
    position = { point = "CENTER", x = 0, y = -200 },
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

-- ────────────────────────────────────────────────────────────
-- Theme helper — falls back to shadow palette if SlyStyle absent
-- ────────────────────────────────────────────────────────────
local function TC(key)
    if SlyStyle and SlyStyle.Get then
        local c = SlyStyle.Get(key)
        if c then return c[1], c[2], c[3], c[4] or 1 end
    end
    -- shadow palette fallback
    local shadow = {
        frameBg  = {0.05, 0.05, 0.07, 0.97},
        border   = {0.28, 0.28, 0.35, 1},
        headerBg = {0.09, 0.09, 0.14, 1},
        sep      = {0.25, 0.25, 0.32, 1},
    }
    local c = shadow[key] or {0.1, 0.1, 0.1, 1}
    return c[1], c[2], c[3], c[4] or 1
end

-- ────────────────────────────────────────────────────────────
-- UI construction
-- ────────────────────────────────────────────────────────────
local FRAME_W  = 210
local FRAME_H  = 58
local HDR_H    = 22
local BAR_H    = 10
local PAD      = 6

local mainFrame   = nil
local barBg       = nil    -- dark bar background
local barFill     = nil    -- colored progress fill
local barSpark    = nil    -- bright leading edge
local timeText    = nil    -- "8.3s" countdown
local stateLabel  = nil    -- "TWIST!" / "READY" / etc.
local wftIcon     = nil
local goatIcon    = nil

-- Texture paths
local TEX_WFT  = "Interface\\Icons\\Spell_Nature_Windfury"
local TEX_GOAT = "Interface\\Icons\\Spell_Nature_InvisibilityTotem"

local function BuildUI()
    if mainFrame then return end

    local f = CreateFrame("Frame", "SlyTotemTwistFrame", UIParent)
    f:SetSize(FRAME_W, FRAME_H)
    f:SetFrameStrata("HIGH")
    f:SetMovable(true)
    f:EnableMouse(false)   -- toggled by lock/unlock

    -- Restore position
    local pos = TT.db.position
    f:ClearAllPoints()
    f:SetPoint(pos.point or "CENTER", UIParent, pos.point or "CENTER",
        pos.x or 0, pos.y or -200)

    -- Frame background
    local bg = f:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(TC("frameBg"))

    -- Border
    local border = f:CreateTexture(nil, "BACKGROUND")
    border:SetAllPoints()
    border:SetColorTexture(TC("border"))
    local inner = f:CreateTexture(nil, "BACKGROUND")
    inner:SetPoint("TOPLEFT",     f, "TOPLEFT",      1, -1)
    inner:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -1,  1)
    inner:SetColorTexture(TC("frameBg"))

    -- ─── Header strip ───────────────────────────────────────
    local hdr = CreateFrame("Frame", nil, f)
    hdr:SetSize(FRAME_W, HDR_H)
    hdr:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
    local hdrBg = hdr:CreateTexture(nil, "BACKGROUND")
    hdrBg:SetAllPoints()
    hdrBg:SetColorTexture(TC("headerBg"))

    -- WFT icon (left)
    wftIcon = hdr:CreateTexture(nil, "ARTWORK")
    wftIcon:SetSize(16, 16)
    wftIcon:SetPoint("LEFT", hdr, "LEFT", 4, 0)
    wftIcon:SetTexture(TEX_WFT)
    wftIcon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

    -- GoAT icon (beside WFT, initially dim)
    goatIcon = hdr:CreateTexture(nil, "ARTWORK")
    goatIcon:SetSize(14, 14)
    goatIcon:SetPoint("LEFT", wftIcon, "RIGHT", 3, 0)
    goatIcon:SetTexture(TEX_GOAT)
    goatIcon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    goatIcon:SetAlpha(0.30)

    -- Title
    local title = hdr:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    title:SetFont(title:GetFont(), 9, "OUTLINE")
    title:SetPoint("LEFT", goatIcon, "RIGHT", 5, 0)
    title:SetText("|cff88bbffTOTEM TWIST|r")

    -- State label (right-aligned in header)
    stateLabel = hdr:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    stateLabel:SetFont(stateLabel:GetFont(), 10, "OUTLINE")
    stateLabel:SetPoint("RIGHT", hdr, "RIGHT", -6, 0)
    stateLabel:SetText("|cff555566IDLE|r")

    -- Separator
    local sep = f:CreateTexture(nil, "ARTWORK")
    sep:SetSize(FRAME_W - 2, 1)
    sep:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -HDR_H)
    sep:SetColorTexture(TC("sep"))

    -- ─── Bar area ───────────────────────────────────────────
    local barY = -(HDR_H + PAD)

    barBg = f:CreateTexture(nil, "ARTWORK")
    barBg:SetSize(FRAME_W - PAD*2, BAR_H)
    barBg:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, barY)
    barBg:SetColorTexture(0.10, 0.10, 0.13, 1)

    barFill = f:CreateTexture(nil, "ARTWORK")
    barFill:SetSize(0, BAR_H)
    barFill:SetPoint("TOPLEFT", barBg, "TOPLEFT", 0, 0)
    barFill:SetColorTexture(0.25, 0.75, 0.25, 1)

    barSpark = f:CreateTexture(nil, "OVERLAY")
    barSpark:SetSize(3, BAR_H + 2)
    barSpark:SetPoint("TOPLEFT", barBg, "TOPLEFT", 0, 1)
    barSpark:SetColorTexture(1, 1, 1, 0.7)
    barSpark:Hide()

    -- Time countdown text (inside bar area)
    timeText = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    timeText:SetFont(timeText:GetFont(), 10, "OUTLINE")
    timeText:SetPoint("TOP", barBg, "BOTTOM", 0, -2)
    timeText:SetText("")

    -- Drag handle (invisible) across whole frame
    local drag = CreateFrame("Frame", nil, f)
    drag:SetAllPoints()
    drag:EnableMouse(true)
    drag:RegisterForDrag("LeftButton")
    drag:SetScript("OnDragStart", function()
        if not TT.db.locked then f:StartMoving() end
    end)
    drag:SetScript("OnDragStop", function()
        f:StopMovingOrSizing()
        local pt, _, _, x, y = f:GetPoint()
        TT.db.position = { point = pt or "CENTER", x = x or 0, y = y or 0 }
    end)

    mainFrame = f

    if not TT.db.shown then f:Hide() end

    -- Register for theme changes
    if SlyStyle and SlyStyle.OnThemeChange then
        SlyStyle.OnThemeChange(function()
            bg:SetColorTexture(TC("frameBg"))
            border:SetColorTexture(TC("border"))
            inner:SetColorTexture(TC("frameBg"))
            hdrBg:SetColorTexture(TC("headerBg"))
            sep:SetColorTexture(TC("sep"))
        end)
    end
end

-- ────────────────────────────────────────────────────────────
-- Visual update (called every OnUpdate tick)
-- ────────────────────────────────────────────────────────────
local BAR_MAX_W = FRAME_W - PAD * 2

local function UpdateVisuals(now)
    if not mainFrame or not mainFrame:IsShown() then return end

    if state == "idle" then
        barFill:SetWidth(0.01)
        barSpark:Hide()
        stateLabel:SetText("|cff444455IDLE|r")
        timeText:SetText("")
        goatIcon:SetAlpha(0.3)
        wftIcon:SetAlpha(0.4)
        return
    end

    local elapsed = now - wftDropTime
    local remaining = WFT_DURATION - elapsed

    -- GoAT flash overrides rest of display briefly
    if state == "goat" and now < goatFlashEnd then
        stateLabel:SetText("|cffffd700DROP WFT!|r")
        barFill:SetColorTexture(0.9, 0.7, 0.0, 1)
        barFill:SetWidth(BAR_MAX_W)
        barSpark:Hide()
        goatIcon:SetAlpha(1.0)
        wftIcon:SetAlpha(0.4)
        timeText:SetText("|cffffd700GoAT active — WFT NOW!|r")
        return
    elseif state == "goat" then
        -- flash time ended but WFT not re-dropped
        state = "expired"
    end

    if state == "expired" or elapsed >= WFT_DURATION then
        state = "expired"
        barFill:SetColorTexture(0.7, 0.1, 0.1, 1)
        barFill:SetWidth(BAR_MAX_W)
        barSpark:Hide()
        stateLabel:SetText("|cffff3333DROP WFT|r")
        timeText:SetText("|cffff4444WFT expired — re-drop!|r")
        goatIcon:SetAlpha(0.3)
        wftIcon:SetAlpha(1.0)
        return
    end

    -- Active WFT countdown
    local frac   = math.min(elapsed / WFT_DURATION, 1)
    local fillW  = math.max(1, math.floor(frac * BAR_MAX_W))
    barFill:SetWidth(fillW)

    -- Spark
    barSpark:SetPoint("TOPLEFT", barBg, "TOPLEFT", fillW - 2, 1)
    barSpark:Show()

    -- Time display
    timeText:SetText(string.format("|cffcccccc%.1f / %.1f s|r", elapsed, WFT_DURATION))

    if elapsed >= TWIST_AT then
        -- Pulsing red — TWIST NOW
        pulseT = pulseT + 0.033
        local pulse = 0.6 + math.abs(math.sin(pulseT * 6)) * 0.4
        barFill:SetColorTexture(pulse, 0.1, 0.1, 1)
        stateLabel:SetText("|cffff2222TWIST!|r")
        wftIcon:SetAlpha(pulse)
        goatIcon:SetAlpha(pulse)
    elseif elapsed >= WARN_AT then
        -- Yellow caution
        local warnFrac = (elapsed - WARN_AT) / (TWIST_AT - WARN_AT)
        barFill:SetColorTexture(0.9, 0.7 - warnFrac * 0.5, 0.0, 1)
        stateLabel:SetText("|cffffcc00READY|r")
        wftIcon:SetAlpha(1.0)
        goatIcon:SetAlpha(0.6 + warnFrac * 0.4)
    else
        -- Green safe phase
        local safeFrac = elapsed / WARN_AT
        barFill:SetColorTexture(
            0.1 + safeFrac * 0.6,
            0.7 - safeFrac * 0.1,
            0.1,
            1)
        stateLabel:SetText(string.format("|cff44cc44%.1fs|r", remaining))
        wftIcon:SetAlpha(1.0)
        goatIcon:SetAlpha(0.3)
    end
end

-- ────────────────────────────────────────────────────────────
-- OnUpdate ticker
-- ────────────────────────────────────────────────────────────
local tickFrame = CreateFrame("Frame")
local elapsed_acc = 0
tickFrame:SetScript("OnUpdate", function(self, dt)
    elapsed_acc = elapsed_acc + dt
    if elapsed_acc < 0.033 then return end   -- ~30 fps
    elapsed_acc = 0
    pulseT = pulseT + 0.033
    UpdateVisuals(GetTime())
end)

-- ────────────────────────────────────────────────────────────
-- Spell cast detection
-- ────────────────────────────────────────────────────────────
local castFrame = CreateFrame("Frame")
castFrame:RegisterEvent("ADDON_LOADED")
castFrame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
castFrame:RegisterEvent("PLAYER_LOGOUT")

castFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local name = ...
        if name == ADDON_NAME then
            SlyTotemTwistDB = SlyTotemTwistDB or {}
            ApplyDefaults(SlyTotemTwistDB, DB_DEFAULTS)
            TT.db = SlyTotemTwistDB

            SLASH_SLYTWIST1 = "/slytwist"
            SlashCmdList["SLYTWIST"] = function(msg)
                msg = (msg or ""):lower():trim()
                if msg == "lock" then
                    TT.db.locked = true
                    if mainFrame then mainFrame:EnableMouse(false) end
                    DEFAULT_CHAT_FRAME:AddMessage("|cff88bbff[TotemTwist]|r Locked.")
                elseif msg == "unlock" then
                    TT.db.locked = false
                    if mainFrame then mainFrame:EnableMouse(true) end
                    DEFAULT_CHAT_FRAME:AddMessage("|cff88bbff[TotemTwist]|r Unlocked — drag to reposition.")
                elseif msg == "reset" then
                    TT.db.position = { point = "CENTER", x = 0, y = -200 }
                    if mainFrame then
                        mainFrame:ClearAllPoints()
                        mainFrame:SetPoint("CENTER", UIParent, "CENTER", 0, -200)
                    end
                    DEFAULT_CHAT_FRAME:AddMessage("|cff88bbff[TotemTwist]|r Position reset.")
                else
                    -- toggle
                    if not mainFrame then BuildUI() end
                    if mainFrame:IsShown() then
                        mainFrame:Hide()
                        TT.db.shown = false
                    else
                        mainFrame:Show()
                        TT.db.shown = true
                    end
                end
            end

            BuildUI()

            DEFAULT_CHAT_FRAME:AddMessage(
                "|cff88bbff[TotemTwist]|r v" .. VERSION ..
                " loaded. |cffffcc00/slytwist|r to toggle.")
        end

    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        -- TBC API: UNIT_SPELLCAST_SUCCEEDED(unit, spellName, spellRank, spellID)
        local unit, spellName = ...
        if unit ~= "player" then return end
        if not spellName then return end

        if spellName:find(WFT_PATTERN, 1, true) then
            -- Fresh WFT drop — reset timer
            state       = "wft"
            wftDropTime = GetTime()
            pulseT      = 0
            if mainFrame and not mainFrame:IsShown() and TT.db.shown then
                mainFrame:Show()
            end

        elseif spellName:find(GOAT_PATTERN, 1, true) then
            -- GoAT dropped — only meaningful as a mid-twist if WFT is active
            local now = GetTime()
            if state == "wft" and (now - wftDropTime) >= WARN_AT then
                state       = "goat"
                goatFlashEnd = now + GOAT_FLASH_DUR
            end
        end

    elseif event == "PLAYER_LOGOUT" then
        if mainFrame then
            local pt, _, _, x, y = mainFrame:GetPoint()
            if TT.db then
                TT.db.position = { point = pt or "CENTER", x = x or 0, y = y or 0 }
                TT.db.shown    = mainFrame:IsShown()
            end
        end
    end
end)
