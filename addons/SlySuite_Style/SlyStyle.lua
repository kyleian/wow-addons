-- ============================================================
-- SlyStyle.lua  —  Canonical theme / style module for SlySuite
--
-- Exports global SlyStyle with the full palette database and
-- helper functions every Sly addon can use:
--
--   SlyStyle.themes             – all theme palette tables
--   SlyStyle.themeOrder         – cycle order list
--   SlyStyle.GetThemeName()     – currently-active theme name
--   SlyStyle.GetTheme()         – active theme table
--   SlyStyle.Get(key)           – colour array {r,g,b[,a]} from active theme
--   SlyStyle.Paint(tex, key)    – SetColorTexture using theme colour
--   SlyStyle.SetTheme(name)     – change theme, sync SavedVars, fire callbacks
--   SlyStyle._fire(name)        – internal: sync + fire without re-entering SC
--   SlyStyle.OnThemeChange(fn)  – register repaint callback
--
-- Thin frame helpers (auto-repaint via OnThemeChange):
--   SlyStyle.FillBg(parent, key)             – fills entire parent with key colour
--   SlyStyle.MakeRect(parent, key, layer)    – themed texture (caller sets points)
--   SlyStyle.MakeHLine(parent, key)          – 1-px full-width separator
--   SlyStyle.BuildFrame(parent, w, h)        – border+inner panel frame
--   SlyStyle.BuildHeader(parent, w, h, text) – header strip frame
-- ============================================================

SlyStyle = SlyStyle or {}
SlyStyle._listeners = SlyStyle._listeners or {}  -- list of fn(themeName)

-- ──────────────────────────────────────────────────────────────────────────────
-- Theme palettes
-- Each colour value is an {r, g, b[, a]} array.
-- Keys: frameBg, border, headerBg, sep, div, sideBg, tabBarBg, footBg, modelBg,
--       tabActiveBg, tabInactiveBg, tabActiveTxt, tabInactiveTxt
-- ──────────────────────────────────────────────────────────────────────────────
SlyStyle.themes = {
    shadow = {
        name="Shadow",
        frameBg  = {0.05, 0.05, 0.07, 0.97},
        border   = {0.28, 0.28, 0.35, 1},
        headerBg = {0.09, 0.09, 0.14, 1},
        sep      = {0.25, 0.25, 0.32, 1},
        div      = {0.20, 0.20, 0.27, 1},
        sideBg   = {0.05, 0.05, 0.08, 1},
        tabBarBg = {0.07, 0.07, 0.11, 1},
        footBg   = {0.07, 0.07, 0.10, 1},
        modelBg  = {0.03, 0.03, 0.04, 1},
        tabActiveBg   = {0.11, 0.16, 0.26},
        tabInactiveBg = {0.06, 0.06, 0.09},
        tabActiveTxt  = {1.00, 1.00, 1.00},
        tabInactiveTxt= {0.55, 0.55, 0.60},
    },
    midnight = {
        name="Midnight",
        frameBg  = {0.04, 0.06, 0.14, 0.97},
        border   = {0.30, 0.42, 0.72, 1},
        headerBg = {0.06, 0.09, 0.22, 1},
        sep      = {0.20, 0.30, 0.55, 1},
        div      = {0.15, 0.22, 0.44, 1},
        sideBg   = {0.04, 0.06, 0.16, 1},
        tabBarBg = {0.06, 0.09, 0.20, 1},
        footBg   = {0.05, 0.08, 0.18, 1},
        modelBg  = {0.02, 0.03, 0.08, 1},
        tabActiveBg   = {0.15, 0.24, 0.52},
        tabInactiveBg = {0.05, 0.07, 0.17},
        tabActiveTxt  = {0.75, 0.90, 1.00},
        tabInactiveTxt= {0.42, 0.52, 0.70},
    },
    crimson = {
        name="Crimson",
        frameBg  = {0.10, 0.04, 0.04, 0.97},
        border   = {0.55, 0.18, 0.18, 1},
        headerBg = {0.16, 0.06, 0.06, 1},
        sep      = {0.38, 0.10, 0.10, 1},
        div      = {0.28, 0.08, 0.08, 1},
        sideBg   = {0.11, 0.04, 0.04, 1},
        tabBarBg = {0.15, 0.05, 0.05, 1},
        footBg   = {0.13, 0.05, 0.05, 1},
        modelBg  = {0.05, 0.02, 0.02, 1},
        tabActiveBg   = {0.42, 0.10, 0.10},
        tabInactiveBg = {0.12, 0.04, 0.04},
        tabActiveTxt  = {1.00, 0.72, 0.72},
        tabInactiveTxt= {0.62, 0.38, 0.38},
    },
    emerald = {
        name="Emerald",
        frameBg  = {0.04, 0.09, 0.05, 0.97},
        border   = {0.20, 0.52, 0.24, 1},
        headerBg = {0.05, 0.13, 0.07, 1},
        sep      = {0.12, 0.34, 0.14, 1},
        div      = {0.08, 0.24, 0.10, 1},
        sideBg   = {0.03, 0.10, 0.05, 1},
        tabBarBg = {0.05, 0.13, 0.07, 1},
        footBg   = {0.04, 0.11, 0.06, 1},
        modelBg  = {0.02, 0.05, 0.03, 1},
        tabActiveBg   = {0.10, 0.38, 0.14},
        tabInactiveBg = {0.04, 0.10, 0.05},
        tabActiveTxt  = {0.68, 1.00, 0.70},
        tabInactiveTxt= {0.38, 0.62, 0.40},
    },
    gold = {
        name="Gold",
        frameBg  = {0.12, 0.10, 0.04, 0.97},
        border   = {0.68, 0.52, 0.14, 1},
        headerBg = {0.18, 0.15, 0.06, 1},
        sep      = {0.46, 0.36, 0.10, 1},
        div      = {0.32, 0.24, 0.07, 1},
        sideBg   = {0.13, 0.10, 0.04, 1},
        tabBarBg = {0.18, 0.14, 0.05, 1},
        footBg   = {0.16, 0.13, 0.05, 1},
        modelBg  = {0.06, 0.05, 0.02, 1},
        tabActiveBg   = {0.44, 0.32, 0.08},
        tabInactiveBg = {0.14, 0.11, 0.04},
        tabActiveTxt  = {1.00, 0.92, 0.50},
        tabInactiveTxt= {0.68, 0.58, 0.28},
    },
    storm = {
        name="Storm",
        frameBg  = {0.08, 0.09, 0.13, 0.97},
        border   = {0.46, 0.50, 0.64, 1},
        headerBg = {0.11, 0.12, 0.18, 1},
        sep      = {0.30, 0.34, 0.46, 1},
        div      = {0.22, 0.25, 0.34, 1},
        sideBg   = {0.08, 0.09, 0.14, 1},
        tabBarBg = {0.11, 0.12, 0.18, 1},
        footBg   = {0.10, 0.11, 0.16, 1},
        modelBg  = {0.04, 0.04, 0.07, 1},
        tabActiveBg   = {0.24, 0.28, 0.46},
        tabInactiveBg = {0.09, 0.10, 0.15},
        tabActiveTxt  = {0.82, 0.90, 1.00},
        tabInactiveTxt= {0.48, 0.54, 0.68},
    },
    void = {
        name="Void",
        frameBg  = {0.06, 0.03, 0.12, 0.97},
        border   = {0.50, 0.22, 0.70, 1},
        headerBg = {0.10, 0.05, 0.18, 1},
        sep      = {0.34, 0.14, 0.50, 1},
        div      = {0.24, 0.10, 0.36, 1},
        sideBg   = {0.07, 0.04, 0.14, 1},
        tabBarBg = {0.10, 0.05, 0.18, 1},
        footBg   = {0.08, 0.04, 0.16, 1},
        modelBg  = {0.03, 0.01, 0.07, 1},
        tabActiveBg   = {0.36, 0.12, 0.52},
        tabInactiveBg = {0.08, 0.04, 0.14},
        tabActiveTxt  = {0.90, 0.68, 1.00},
        tabInactiveTxt= {0.52, 0.36, 0.66},
    },
    frost = {
        name="Frost",
        frameBg  = {0.05, 0.09, 0.14, 0.97},
        border   = {0.55, 0.72, 0.88, 1},
        headerBg = {0.08, 0.14, 0.22, 1},
        sep      = {0.36, 0.52, 0.68, 1},
        div      = {0.22, 0.38, 0.52, 1},
        sideBg   = {0.06, 0.10, 0.16, 1},
        tabBarBg = {0.08, 0.14, 0.22, 1},
        footBg   = {0.07, 0.12, 0.20, 1},
        modelBg  = {0.03, 0.05, 0.09, 1},
        tabActiveBg   = {0.22, 0.44, 0.62},
        tabInactiveBg = {0.06, 0.11, 0.18},
        tabActiveTxt  = {0.82, 0.96, 1.00},
        tabInactiveTxt= {0.44, 0.60, 0.74},
    },
    obsidian = {
        name="Obsidian",
        frameBg  = {0.03, 0.03, 0.04, 0.98},
        border   = {0.22, 0.22, 0.28, 1},
        headerBg = {0.05, 0.05, 0.07, 1},
        sep      = {0.16, 0.16, 0.20, 1},
        div      = {0.12, 0.12, 0.16, 1},
        sideBg   = {0.03, 0.03, 0.05, 1},
        tabBarBg = {0.05, 0.05, 0.07, 1},
        footBg   = {0.04, 0.04, 0.06, 1},
        modelBg  = {0.01, 0.01, 0.02, 1},
        tabActiveBg   = {0.18, 0.18, 0.26},
        tabInactiveBg = {0.04, 0.04, 0.07},
        tabActiveTxt  = {0.90, 0.90, 0.96},
        tabInactiveTxt= {0.40, 0.40, 0.46},
    },
    copper = {
        name="Copper",
        frameBg  = {0.11, 0.07, 0.03, 0.97},
        border   = {0.72, 0.44, 0.18, 1},
        headerBg = {0.17, 0.11, 0.04, 1},
        sep      = {0.48, 0.28, 0.10, 1},
        div      = {0.34, 0.20, 0.06, 1},
        sideBg   = {0.12, 0.07, 0.03, 1},
        tabBarBg = {0.16, 0.10, 0.04, 1},
        footBg   = {0.14, 0.09, 0.04, 1},
        modelBg  = {0.05, 0.03, 0.01, 1},
        tabActiveBg   = {0.46, 0.26, 0.06},
        tabInactiveBg = {0.13, 0.08, 0.03},
        tabActiveTxt  = {1.00, 0.82, 0.48},
        tabInactiveTxt= {0.62, 0.48, 0.28},
    },
    rose = {
        name="Rose",
        frameBg  = {0.12, 0.04, 0.07, 0.97},
        border   = {0.70, 0.28, 0.46, 1},
        headerBg = {0.18, 0.06, 0.10, 1},
        sep      = {0.46, 0.16, 0.28, 1},
        div      = {0.32, 0.10, 0.20, 1},
        sideBg   = {0.13, 0.04, 0.08, 1},
        tabBarBg = {0.18, 0.06, 0.10, 1},
        footBg   = {0.16, 0.05, 0.09, 1},
        modelBg  = {0.06, 0.02, 0.04, 1},
        tabActiveBg   = {0.48, 0.14, 0.26},
        tabInactiveBg = {0.14, 0.04, 0.08},
        tabActiveTxt  = {1.00, 0.70, 0.82},
        tabInactiveTxt= {0.64, 0.38, 0.48},
    },
    venom = {
        name="Venom",
        frameBg  = {0.07, 0.10, 0.03, 0.97},
        border   = {0.48, 0.68, 0.12, 1},
        headerBg = {0.10, 0.16, 0.04, 1},
        sep      = {0.30, 0.46, 0.08, 1},
        div      = {0.20, 0.32, 0.05, 1},
        sideBg   = {0.08, 0.11, 0.03, 1},
        tabBarBg = {0.10, 0.16, 0.04, 1},
        footBg   = {0.09, 0.14, 0.04, 1},
        modelBg  = {0.03, 0.05, 0.01, 1},
        tabActiveBg   = {0.28, 0.46, 0.06},
        tabInactiveBg = {0.08, 0.12, 0.03},
        tabActiveTxt  = {0.80, 1.00, 0.30},
        tabInactiveTxt= {0.48, 0.62, 0.26},
    },
}

SlyStyle.themeOrder = {
    "shadow","midnight","crimson","emerald","gold","storm",
    "void","frost","obsidian","copper","rose","venom",
}

-- ──────────────────────────────────────────────────────────────────────────────
-- Accessors
-- ──────────────────────────────────────────────────────────────────────────────

function SlyStyle.GetThemeName()
    return (SlyStyleDB and SlyStyleDB.theme) or "shadow"
end

function SlyStyle.GetTheme()
    return SlyStyle.themes[SlyStyle.GetThemeName()] or SlyStyle.themes.shadow
end

--- Returns the colour array {r,g,b[,a]} for @key from the active theme.
function SlyStyle.Get(key)
    local th = SlyStyle.GetTheme()
    return th[key] or SlyStyle.themes.shadow[key]
end

--- Paints @tex with the colour stored at @key in the active theme.
function SlyStyle.Paint(tex, key)
    if not tex then return end
    local c = SlyStyle.Get(key)
    if c then tex:SetColorTexture(c[1], c[2], c[3], c[4] or 1) end
end

-- ──────────────────────────────────────────────────────────────────────────────
-- Theme change
-- ──────────────────────────────────────────────────────────────────────────────

--- Internal: update SavedVars and fire all registered listeners WITHOUT
--- re-entering SC_ApplyTheme. Called by SC_ApplyTheme after it has already
--- handled SlyChar's own textures.
function SlyStyle._fire(name)
    SlyStyleDB = SlyStyleDB or {}
    SlyStyleDB.theme = name
    for _, fn in ipairs(SlyStyle._listeners) do
        local ok, err = pcall(fn, name)
        if not ok then
            if SlyError then SlyError.Log("SlyStyle:_fire", tostring(err)) end
        end
    end
end

--- Public theme setter. When SlyChar is loaded, delegates to SC_ApplyTheme so
--- SlyChar's own textures are repainted. When SlyChar is not loaded, fires
--- listeners directly. Safe to call from any addon.
function SlyStyle.SetTheme(name)
    if not SlyStyle.themes[name] then name = "shadow" end
    if SC_ApplyTheme then
        SC_ApplyTheme(name)  -- SC_ApplyTheme calls SlyStyle._fire in turn
    else
        SlyStyle._fire(name)
    end
end

--- Register a callback fn(themeName) that is called whenever the theme changes.
--- Use this to repaint textures in your addon.
function SlyStyle.OnThemeChange(fn)
    if type(fn) == "function" then
        table.insert(SlyStyle._listeners, fn)
    end
end

-- ──────────────────────────────────────────────────────────────────────────────
-- Frame-building helpers
-- All helpers auto-register an OnThemeChange repaint so consumer frames stay
-- in sync when the user cycles themes in SlyChar.
-- ──────────────────────────────────────────────────────────────────────────────

--- Fill a frame's entire background area with a theme colour.
--- @param parent Frame
--- @param key    string  theme colour key  (default "sideBg")
--- @return Texture  the created background texture
function SlyStyle.FillBg(parent, key)
    key = key or "sideBg"
    local tex = parent:CreateTexture(nil, "BACKGROUND")
    tex:SetAllPoints(parent)
    SlyStyle.Paint(tex, key)
    SlyStyle.OnThemeChange(function() SlyStyle.Paint(tex, key) end)
    return tex
end

--- Create a single-colour texture whose points the caller must set.
--- @param parent Frame
--- @param key    string  theme colour key
--- @param layer  string  draw layer (default "BACKGROUND")
--- @return Texture
function SlyStyle.MakeRect(parent, key, layer)
    local tex = parent:CreateTexture(nil, layer or "BACKGROUND")
    SlyStyle.Paint(tex, key)
    SlyStyle.OnThemeChange(function() SlyStyle.Paint(tex, key) end)
    return tex
end

--- Create a full-width 1-pixel horizontal line.
--- Caller must anchor vertical position; left/right edges span the parent.
--- @param parent  Frame
--- @param key     string  colour key  (default "sep")
--- @return Texture
function SlyStyle.MakeHLine(parent, key)
    key = key or "sep"
    local tex = parent:CreateTexture(nil, "ARTWORK")
    tex:SetHeight(1)
    tex:SetPoint("LEFT",  parent, "LEFT",  0, 0)
    tex:SetPoint("RIGHT", parent, "RIGHT", 0, 0)
    SlyStyle.Paint(tex, key)
    SlyStyle.OnThemeChange(function() SlyStyle.Paint(tex, key) end)
    return tex
end

--- Build a standard bordered panel frame (border + inner background).
--- @param parent  Frame
--- @param w       number
--- @param h       number
--- @return frame, bgTex, borderTex
function SlyStyle.BuildFrame(parent, w, h)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(w, h)

    -- Outer border (one-pixel solid colour, drawn behind inner bg)
    local bordTex = f:CreateTexture(nil, "BACKGROUND")
    bordTex:SetAllPoints(f)
    SlyStyle.Paint(bordTex, "border")
    SlyStyle.OnThemeChange(function() SlyStyle.Paint(bordTex, "border") end)

    -- Inner background (inset by 1 px)
    local bgTex = f:CreateTexture(nil, "BACKGROUND")
    bgTex:SetPoint("TOPLEFT",     f, "TOPLEFT",      1, -1)
    bgTex:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -1,  1)
    SlyStyle.Paint(bgTex, "frameBg")
    SlyStyle.OnThemeChange(function() SlyStyle.Paint(bgTex, "frameBg") end)

    return f, bgTex, bordTex
end

--- Build a header strip frame with themed background.
--- @param parent  Frame
--- @param w       number  (pass 0 to let caller set width via anchors)
--- @param h       number
--- @param text    string|nil  optional title text
--- @param tColor  table|nil   {r,g,b[,a]} override for title colour
--- @return frame  (frame._titleTx = FontString if text provided)
function SlyStyle.BuildHeader(parent, w, h, text, tColor)
    local hdr = CreateFrame("Frame", nil, parent)
    if w and w > 0 then hdr:SetSize(w, h) else hdr:SetHeight(h) end

    local bgTex = hdr:CreateTexture(nil, "BACKGROUND")
    bgTex:SetAllPoints(hdr)
    SlyStyle.Paint(bgTex, "headerBg")
    SlyStyle.OnThemeChange(function() SlyStyle.Paint(bgTex, "headerBg") end)

    -- 1-px separator below the header
    local sep = hdr:CreateTexture(nil, "ARTWORK")
    sep:SetHeight(1)
    sep:SetPoint("BOTTOMLEFT",  hdr, "BOTTOMLEFT",  0, 0)
    sep:SetPoint("BOTTOMRIGHT", hdr, "BOTTOMRIGHT", 0, 0)
    SlyStyle.Paint(sep, "sep")
    SlyStyle.OnThemeChange(function() SlyStyle.Paint(sep, "sep") end)

    if text then
        local tx = hdr:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        tx:SetFont(tx:GetFont(), 12, "OUTLINE")
        tx:SetPoint("LEFT", hdr, "LEFT", 8, 0)
        if tColor then
            tx:SetTextColor(tColor[1], tColor[2], tColor[3], tColor[4] or 1)
        end
        tx:SetText(text)
        hdr._titleTx = tx
    end

    return hdr
end

--- Build a standard footer strip frame.
--- @param parent  Frame
--- @param w       number
--- @param h       number
--- @return frame
function SlyStyle.BuildFooter(parent, w, h)
    local foot = CreateFrame("Frame", nil, parent)
    if w and w > 0 then foot:SetSize(w, h) else foot:SetHeight(h) end

    local bgTex = foot:CreateTexture(nil, "BACKGROUND")
    bgTex:SetAllPoints(foot)
    SlyStyle.Paint(bgTex, "footBg")
    SlyStyle.OnThemeChange(function() SlyStyle.Paint(bgTex, "footBg") end)

    -- 1-px separator above the footer
    local sep = foot:CreateTexture(nil, "ARTWORK")
    sep:SetHeight(1)
    sep:SetPoint("TOPLEFT",  foot, "TOPLEFT",  0, 0)
    sep:SetPoint("TOPRIGHT", foot, "TOPRIGHT", 0, 0)
    SlyStyle.Paint(sep, "div")
    SlyStyle.OnThemeChange(function() SlyStyle.Paint(sep, "div") end)

    return foot
end

-- ──────────────────────────────────────────────────────────────────────────────
-- Slash command  /slystyle [themeName]
-- ──────────────────────────────────────────────────────────────────────────────
local function SlashHandler(msg)
    msg = (msg or ""):lower():match("^%s*(.-)%s*$")
    if msg == "" then
        -- List themes
        local cur = SlyStyle.GetThemeName()
        DEFAULT_CHAT_FRAME:AddMessage("|cff88ccff[SlyStyle]|r Available themes:")
        for _, k in ipairs(SlyStyle.themeOrder) do
            local marker = (k == cur) and " |cffffd700(active)|r" or ""
            DEFAULT_CHAT_FRAME:AddMessage("  " .. k .. marker)
        end
        DEFAULT_CHAT_FRAME:AddMessage("Use |cff88ccff/slystyle <name>|r to switch.")
    elseif SlyStyle.themes[msg] then
        SlyStyle.SetTheme(msg)
        DEFAULT_CHAT_FRAME:AddMessage("|cff88ccff[SlyStyle]|r Theme set to: " .. msg)
    else
        DEFAULT_CHAT_FRAME:AddMessage("|cffff6060[SlyStyle]|r Unknown theme: " .. msg)
    end
end

-- ──────────────────────────────────────────────────────────────────────────────
-- ADDON_LOADED – initialise SavedVariables
-- ──────────────────────────────────────────────────────────────────────────────
local _ev = CreateFrame("Frame")
_ev:RegisterEvent("ADDON_LOADED")
_ev:SetScript("OnEvent", function(self, event, name)
    if name ~= "SlySuite_Style" then return end
    self:UnregisterEvent("ADDON_LOADED")

    SlyStyleDB = SlyStyleDB or {}
    -- Backward-compat: inherit theme from SlyChar SavedVars if first run
    if not SlyStyleDB.theme then
        SlyStyleDB.theme = (SlyCharDB and SlyCharDB.theme) or "shadow"
    end

    SLASH_SLYSTYLE1 = "/slystyle"
    SlashCmdList["SLYSTYLE"] = SlashHandler
end)
