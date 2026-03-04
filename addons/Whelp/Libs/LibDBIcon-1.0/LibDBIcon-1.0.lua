--[[
    LibDBIcon-1.0 - Minimap icon library
    https://www.curseforge.com/wow/addons/libdbicon-1-0
]]

local MAJOR, MINOR = "LibDBIcon-1.0", 47
local lib = LibStub:NewLibrary(MAJOR, MINOR)

if not lib then return end

lib.objects = lib.objects or {}
lib.callbackRegistered = lib.callbackRegistered or nil
lib.callbacks = lib.callbacks or LibStub("CallbackHandler-1.0"):New(lib)
lib.radius = lib.radius or 5
local callbacks = lib.callbacks

local math_sin, math_cos = math.sin, math.cos
local minimapShapes = {
    ["ROUND"] = {true, true, true, true},
    ["SQUARE"] = {false, false, false, false},
    ["CORNER-TOPLEFT"] = {false, false, false, true},
    ["CORNER-TOPRIGHT"] = {false, false, true, false},
    ["CORNER-BOTTOMLEFT"] = {false, true, false, false},
    ["CORNER-BOTTOMRIGHT"] = {true, false, false, false},
    ["SIDE-LEFT"] = {false, true, false, true},
    ["SIDE-RIGHT"] = {true, false, true, false},
    ["SIDE-TOP"] = {false, false, true, true},
    ["SIDE-BOTTOM"] = {true, true, false, false},
    ["TRICORNER-TOPLEFT"] = {false, true, true, true},
    ["TRICORNER-TOPRIGHT"] = {true, false, true, true},
    ["TRICORNER-BOTTOMLEFT"] = {true, true, false, true},
    ["TRICORNER-BOTTOMRIGHT"] = {true, true, true, false},
}

local function getMinimapShape()
    return GetMinimapShape and GetMinimapShape() or "ROUND"
end

local function updatePosition(button, position)
    local angle = math.rad(position or 225)
    local x, y
    local rounding = 10
    local cos = math_cos(angle)
    local sin = math_sin(angle)
    local q = 1

    if cos < 0 then q = q + 1 end
    if sin > 0 then q = q + 2 end

    local minimapShape = minimapShapes[getMinimapShape()]
    if minimapShape and minimapShape[q] then
        x = cos * 80
        y = sin * 80
    else
        local diagRadius = math.sqrt(2 * 80^2) - rounding
        x = math.max(-80, math.min(cos * diagRadius, 80))
        y = math.max(-80, math.min(sin * diagRadius, 80))
    end

    button:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

local function onClick(self, button)
    local obj = self.dataObject
    if obj.OnClick then
        obj.OnClick(self, button)
    end
end

local function onMouseDown(self)
    self.icon:SetTexCoord(0.05, 0.95, 0.05, 0.95)
end

local function onMouseUp(self)
    self.icon:SetTexCoord(0, 1, 0, 1)
end

local function onEnter(self)
    if self.dataObject.OnTooltipShow then
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        self.dataObject.OnTooltipShow(GameTooltip)
        GameTooltip:Show()
    elseif self.dataObject.OnEnter then
        self.dataObject.OnEnter(self)
    end
end

local function onLeave(self)
    GameTooltip:Hide()
    if self.dataObject.OnLeave then
        self.dataObject.OnLeave(self)
    end
end

local function onDragStart(self)
    self:LockHighlight()
    self.isMoving = true
    self:SetScript("OnUpdate", function(self)
        local mx, my = Minimap:GetCenter()
        local px, py = GetCursorPosition()
        local scale = Minimap:GetEffectiveScale()
        px, py = px / scale, py / scale
        local pos = math.deg(math.atan2(py - my, px - mx)) % 360
        self.db.minimapPos = pos
        updatePosition(self, pos)
    end)
end

local function onDragStop(self)
    self:SetScript("OnUpdate", nil)
    self.isMoving = nil
    self:UnlockHighlight()
end

local defaultCoords = {0, 1, 0, 1}
local function createButton(name, object, db)
    local button = CreateFrame("Button", "LibDBIcon10_"..name, Minimap)
    button:SetFrameStrata("MEDIUM")
    button:SetSize(32, 32)
    button:SetFrameLevel(8)
    button:RegisterForClicks("anyUp")
    button:RegisterForDrag("LeftButton")
    button:SetHighlightTexture(136477) -- Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight

    local overlay = button:CreateTexture(nil, "OVERLAY")
    overlay:SetSize(56, 56)
    overlay:SetTexture(136430) -- Interface\\Minimap\\MiniMap-TrackingBorder
    overlay:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)

    local background = button:CreateTexture(nil, "BACKGROUND")
    background:SetSize(24, 24)
    background:SetTexture(136467) -- Interface\\Minimap\\UI-Minimap-Background
    background:SetPoint("CENTER", button, "CENTER", 0, 1)

    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetSize(20, 20)
    icon:SetPoint("CENTER", button, "CENTER", 0, 1)
    if object.icon then
        icon:SetTexture(object.icon)
    end

    button.icon = icon
    button.dataObject = object
    button.db = db

    button:SetScript("OnClick", onClick)
    button:SetScript("OnMouseDown", onMouseDown)
    button:SetScript("OnMouseUp", onMouseUp)
    button:SetScript("OnEnter", onEnter)
    button:SetScript("OnLeave", onLeave)
    button:SetScript("OnDragStart", onDragStart)
    button:SetScript("OnDragStop", onDragStop)

    lib.objects[name] = button

    if db.hide then
        button:Hide()
    else
        button:Show()
    end

    updatePosition(button, db.minimapPos)

    lib.callbacks:Fire("LibDBIcon_IconCreated", button, name)

    return button
end

function lib:Register(name, object, db)
    if not object.icon then
        error("Can't register LDB objects without icons set!")
    end
    if lib.objects[name] then
        return
    end
    db = db or {}
    db.minimapPos = db.minimapPos or 225
    return createButton(name, object, db)
end

function lib:Show(name)
    if lib.objects[name] then
        lib.objects[name]:Show()
        lib.objects[name].db.hide = nil
    end
end

function lib:Hide(name)
    if lib.objects[name] then
        lib.objects[name]:Hide()
        lib.objects[name].db.hide = true
    end
end

function lib:IsRegistered(name)
    return lib.objects[name] and true or false
end

function lib:Refresh(name, db)
    local button = lib.objects[name]
    if button then
        if db then button.db = db end
        updatePosition(button, button.db.minimapPos)
        if button.db.hide then
            button:Hide()
        else
            button:Show()
        end
    end
end

function lib:GetMinimapButton(name)
    return lib.objects[name]
end
