--[[
    Whelp - UI Templates
    Reusable UI components and helper functions
]]

local ADDON_NAME, Whelp = ...

Whelp.UI = Whelp.UI or {}
Whelp.UI.Templates = {}
local Templates = Whelp.UI.Templates

-- Create a standard backdrop for frames
function Templates:CreateBackdrop(frame, bgColor, borderColor)
    -- When SlyStyle is loaded and no explicit colour override is given, use the
    -- active theme palette so all Whelp panels match the SlyChar theme.
    local useSlyStyle = (SlyStyle ~= nil) and (bgColor == nil) and (borderColor == nil)
    if useSlyStyle then
        local fr = SlyStyle.Get("frameBg")
        local br = SlyStyle.Get("border")
        bgColor    = { r=fr[1], g=fr[2], b=fr[3], a=fr[4] or 0.9 }
        borderColor = { r=br[1], g=br[2], b=br[3] }
    end
    bgColor     = bgColor     or Whelp.Colors.BACKGROUND
    borderColor = borderColor or Whelp.Colors.BORDER

    -- TBC Anniversary (20505): CreateFrame'd frames don't have SetBackdrop by
    -- default; it lives in BackdropTemplateMixin. Mix it in on demand.
    if not frame.SetBackdrop then
        if BackdropTemplateMixin then
            Mixin(frame, BackdropTemplateMixin)
        else
            return  -- client too old to support backdrop API; bail silently
        end
    end

    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
        insets = {left = 1, right = 1, top = 1, bottom = 1},
    })

    frame:SetBackdropColor(bgColor.r, bgColor.g, bgColor.b, bgColor.a or 0.9)
    frame:SetBackdropBorderColor(borderColor.r, borderColor.g, borderColor.b, 1)

    -- Register for automatic repainting when the theme cycles in SlyChar.
    if useSlyStyle then
        SlyStyle.OnThemeChange(function()
            local fr2 = SlyStyle.Get("frameBg")
            local br2 = SlyStyle.Get("border")
            if frame.SetBackdropColor then
                frame:SetBackdropColor(fr2[1],fr2[2],fr2[3],fr2[4] or 0.9)
                frame:SetBackdropBorderColor(br2[1],br2[2],br2[3],1)
            end
        end)
    end
end

-- Create a standard button
function Templates:CreateButton(parent, text, width, height, onClick)
    width = width or 100
    height = height or 24

    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(width, height)
    button:SetText(text)

    if onClick then
        button:SetScript("OnClick", onClick)
    end

    return button
end

-- Create a close button
function Templates:CreateCloseButton(parent, onClose)
    local closeButton = CreateFrame("Button", nil, parent, "UIPanelCloseButton")
    closeButton:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -2, -2)

    if onClose then
        closeButton:SetScript("OnClick", function()
            onClose()
        end)
    else
        closeButton:SetScript("OnClick", function()
            parent:Hide()
        end)
    end

    return closeButton
end

-- Create a title bar
function Templates:CreateTitleBar(parent, title, movable)
    local titleBar = CreateFrame("Frame", nil, parent)
    titleBar:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
    titleBar:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, 0)
    titleBar:SetHeight(28)

    self:CreateBackdrop(titleBar, Whelp.Colors.SECONDARY, Whelp.Colors.BORDER)
    -- Repaint title bar with headerBg if SlyStyle is loaded
    if titleBar.SetBackdropColor and SlyStyle then
        local function _repaintTitleBar()
            local hb = SlyStyle.Get("headerBg")
            local br = SlyStyle.Get("border")
            titleBar:SetBackdropColor(hb[1],hb[2],hb[3],hb[4] or 1)
            titleBar:SetBackdropBorderColor(br[1],br[2],br[3],1)
        end
        _repaintTitleBar()
        SlyStyle.OnThemeChange(_repaintTitleBar)
    end

    local titleText = titleBar:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    titleText:SetPoint("LEFT", titleBar, "LEFT", 10, 0)
    titleText:SetText(title)
    titleText:SetTextColor(
        Whelp.Colors.PRIMARY.r,
        Whelp.Colors.PRIMARY.g,
        Whelp.Colors.PRIMARY.b
    )

    if movable then
        titleBar:EnableMouse(true)
        titleBar:RegisterForDrag("LeftButton")
        titleBar:SetScript("OnDragStart", function()
            parent:StartMoving()
        end)
        titleBar:SetScript("OnDragStop", function()
            parent:StopMovingOrSizing()
            -- Save position
            local point, _, relativePoint, xOfs, yOfs = parent:GetPoint()
            if Whelp.db and Whelp.db.profile then
                Whelp.db.profile.ui.position = {point, "UIParent", relativePoint, xOfs, yOfs}
            end
        end)
    end

    return titleBar, titleText
end

-- Create a text input field
function Templates:CreateEditBox(parent, width, height, multiLine)
    width = width or 200
    height = height or 24

    local editBox
    if multiLine then
        editBox = CreateFrame("EditBox", nil, parent)
        editBox:SetMultiLine(true)
        editBox:SetAutoFocus(false)
        editBox:SetMaxLetters(Whelp.MAX_REVIEW_LENGTH)
    else
        editBox = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
        editBox:SetAutoFocus(false)
    end

    editBox:SetSize(width, height)
    editBox:SetFontObject("ChatFontNormal")

    if multiLine then
        -- Create a scroll frame for multiline
        local scrollFrame = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
        scrollFrame:SetSize(width, height)

        self:CreateBackdrop(scrollFrame, {r = 0.05, g = 0.05, b = 0.05, a = 0.8}, Whelp.Colors.BORDER)

        editBox:SetWidth(width - 20)
        scrollFrame:SetScrollChild(editBox)

        -- Add padding
        editBox:SetPoint("TOPLEFT", scrollFrame, "TOPLEFT", 5, -5)
        editBox:SetPoint("TOPRIGHT", scrollFrame, "TOPRIGHT", -25, -5)

        return scrollFrame, editBox
    end

    return editBox
end

-- Create a dropdown menu
function Templates:CreateDropdown(parent, width, options, defaultValue, onChange)
    width = width or 150

    local dropdown = CreateFrame("Frame", nil, parent, "UIDropDownMenuTemplate")
    dropdown:SetPoint("CENTER")

    UIDropDownMenu_SetWidth(dropdown, width)

    local function Initialize(self, level)
        local info = UIDropDownMenu_CreateInfo()

        for _, option in ipairs(options) do
            info.text = option.text
            info.value = option.value
            info.func = function(self)
                UIDropDownMenu_SetSelectedValue(dropdown, self.value)
                UIDropDownMenu_SetText(dropdown, option.text)
                if onChange then
                    onChange(self.value)
                end
            end
            info.checked = option.value == defaultValue
            UIDropDownMenu_AddButton(info, level)
        end
    end

    UIDropDownMenu_Initialize(dropdown, Initialize)

    if defaultValue then
        UIDropDownMenu_SetSelectedValue(dropdown, defaultValue)
        for _, option in ipairs(options) do
            if option.value == defaultValue then
                UIDropDownMenu_SetText(dropdown, option.text)
                break
            end
        end
    end

    return dropdown
end

-- Create star rating display
function Templates:CreateStarRating(parent, rating, size, interactive)
    size = size or 16
    rating = rating or 0

    local container = CreateFrame("Frame", nil, parent)
    container:SetSize(size * 5 + 4, size)

    container.stars = {}
    container.rating = rating

    for i = 1, 5 do
        local star = container:CreateTexture(nil, "ARTWORK")
        star:SetSize(size, size)
        star:SetPoint("LEFT", container, "LEFT", (i - 1) * (size + 1), 0)

        -- Use built-in reputation star texture
        star:SetTexture("Interface\\COMMON\\ReputationStar")

        if rating >= i then
            -- Full star
            star:SetTexCoord(0, 0.5, 0, 0.5)
            star:SetVertexColor(
                Whelp.Colors.STAR_FILLED.r,
                Whelp.Colors.STAR_FILLED.g,
                Whelp.Colors.STAR_FILLED.b
            )
        elseif rating >= i - 0.5 then
            -- Half star - show full but use overlay
            star:SetTexCoord(0, 0.5, 0, 0.5)
            star:SetVertexColor(
                Whelp.Colors.STAR_FILLED.r,
                Whelp.Colors.STAR_FILLED.g,
                Whelp.Colors.STAR_FILLED.b,
                0.5
            )
        else
            -- Empty star
            star:SetTexCoord(0.5, 1, 0, 0.5)
            star:SetVertexColor(
                Whelp.Colors.STAR_EMPTY.r,
                Whelp.Colors.STAR_EMPTY.g,
                Whelp.Colors.STAR_EMPTY.b
            )
        end

        container.stars[i] = star
    end

    -- Update rating function
    function container:SetRating(newRating)
        self.rating = newRating
        for i = 1, 5 do
            local star = self.stars[i]
            if newRating >= i then
                star:SetTexCoord(0, 0.5, 0, 0.5)
                star:SetVertexColor(
                    Whelp.Colors.STAR_FILLED.r,
                    Whelp.Colors.STAR_FILLED.g,
                    Whelp.Colors.STAR_FILLED.b
                )
            elseif newRating >= i - 0.5 then
                star:SetTexCoord(0, 0.5, 0, 0.5)
                star:SetVertexColor(
                    Whelp.Colors.STAR_FILLED.r,
                    Whelp.Colors.STAR_FILLED.g,
                    Whelp.Colors.STAR_FILLED.b,
                    0.5
                )
            else
                star:SetTexCoord(0.5, 1, 0, 0.5)
                star:SetVertexColor(
                    Whelp.Colors.STAR_EMPTY.r,
                    Whelp.Colors.STAR_EMPTY.g,
                    Whelp.Colors.STAR_EMPTY.b
                )
            end
        end
    end

    if interactive then
        container:EnableMouse(true)

        for i = 1, 5 do
            local starButton = CreateFrame("Button", nil, container)
            starButton:SetSize(size, size)
            starButton:SetPoint("LEFT", container, "LEFT", (i - 1) * (size + 1), 0)
            starButton.index = i

            starButton:SetScript("OnEnter", function(self)
                for j = 1, 5 do
                    local star = container.stars[j]
                    if j <= self.index then
                        star:SetTexCoord(0, 0.5, 0, 0.5)
                        star:SetVertexColor(
                            Whelp.Colors.STAR_FILLED.r,
                            Whelp.Colors.STAR_FILLED.g,
                            Whelp.Colors.STAR_FILLED.b
                        )
                    else
                        star:SetTexCoord(0.5, 1, 0, 0.5)
                        star:SetVertexColor(
                            Whelp.Colors.STAR_EMPTY.r,
                            Whelp.Colors.STAR_EMPTY.g,
                            Whelp.Colors.STAR_EMPTY.b
                        )
                    end
                end
            end)

            starButton:SetScript("OnLeave", function()
                container:SetRating(container.rating)
            end)

            starButton:SetScript("OnClick", function(self)
                container.rating = self.index
                container:SetRating(self.index)
                if container.OnRatingChanged then
                    container:OnRatingChanged(self.index)
                end
            end)
        end
    end

    return container
end

-- Create a scroll frame with content
function Templates:CreateScrollFrame(parent, width, height)
    local scrollFrame = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
    scrollFrame:SetSize(width, height)

    local content = CreateFrame("Frame", nil, scrollFrame)
    content:SetSize(width - 20, 1) -- Height will be set dynamically
    scrollFrame:SetScrollChild(content)

    return scrollFrame, content
end

-- Create a tab button
function Templates:CreateTabButton(parent, text, index, onClick)
    local tab = CreateFrame("Button", nil, parent)
    tab:SetSize(100, 28)
    tab.index = index

    self:CreateBackdrop(tab, Whelp.Colors.SECONDARY, Whelp.Colors.BORDER)

    local tabText = tab:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    tabText:SetPoint("CENTER")
    tabText:SetText(text)
    tab.text = tabText

    tab:SetScript("OnClick", function(self)
        if onClick then
            onClick(self.index)
        end
    end)

    tab:SetScript("OnEnter", function(self)
        if not self.isActive then
            self:SetBackdropColor(0.3, 0.3, 0.3, 1)
        end
    end)

    tab:SetScript("OnLeave", function(self)
        if not self.isActive then
            self:SetBackdropColor(
                Whelp.Colors.SECONDARY.r,
                Whelp.Colors.SECONDARY.g,
                Whelp.Colors.SECONDARY.b,
                1
            )
        end
    end)

    function tab:SetActive(active)
        self.isActive = active
        if active then
            self:SetBackdropColor(
                Whelp.Colors.PRIMARY.r,
                Whelp.Colors.PRIMARY.g,
                Whelp.Colors.PRIMARY.b,
                1
            )
            self.text:SetTextColor(1, 1, 1)
        else
            self:SetBackdropColor(
                Whelp.Colors.SECONDARY.r,
                Whelp.Colors.SECONDARY.g,
                Whelp.Colors.SECONDARY.b,
                1
            )
            self.text:SetTextColor(0.8, 0.8, 0.8)
        end
    end

    return tab
end

-- Create a checkbox
function Templates:CreateCheckbox(parent, text, checked, onChange)
    local checkbox = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    checkbox:SetChecked(checked or false)

    local label = checkbox:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("LEFT", checkbox, "RIGHT", 2, 0)
    label:SetText(text)

    checkbox:SetScript("OnClick", function(self)
        local isChecked = self:GetChecked()
        if onChange then
            onChange(isChecked)
        end
    end)

    return checkbox, label
end

-- Create a tooltip
function Templates:ShowTooltip(frame, title, lines)
    GameTooltip:SetOwner(frame, "ANCHOR_RIGHT")
    GameTooltip:SetText(title, 1, 1, 1)

    if lines then
        for _, line in ipairs(lines) do
            if type(line) == "table" then
                GameTooltip:AddLine(line.text, line.r or 1, line.g or 1, line.b or 1, line.wrap)
            else
                GameTooltip:AddLine(line, 1, 0.82, 0, true)
            end
        end
    end

    GameTooltip:Show()
end

function Templates:HideTooltip()
    GameTooltip:Hide()
end

-- Create a separator line
function Templates:CreateSeparator(parent, width)
    local separator = parent:CreateTexture(nil, "ARTWORK")
    separator:SetSize(width or parent:GetWidth() - 20, 1)
    separator:SetColorTexture(
        Whelp.Colors.BORDER.r,
        Whelp.Colors.BORDER.g,
        Whelp.Colors.BORDER.b,
        0.5
    )
    return separator
end

-- Create a category icon button
function Templates:CreateCategoryButton(parent, category, size, onClick)
    size = size or 32

    local button = CreateFrame("Button", nil, parent)
    button:SetSize(size, size)

    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints()
    icon:SetTexture(category.icon)
    button.icon = icon

    local highlight = button:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints()
    highlight:SetTexture("Interface\\Buttons\\ButtonHilight-Square")
    highlight:SetBlendMode("ADD")

    button:SetScript("OnEnter", function(self)
        Templates:ShowTooltip(self, category.name, {category.description})
    end)

    button:SetScript("OnLeave", function()
        Templates:HideTooltip()
    end)

    if onClick then
        button:SetScript("OnClick", function()
            onClick(category)
        end)
    end

    return button
end
