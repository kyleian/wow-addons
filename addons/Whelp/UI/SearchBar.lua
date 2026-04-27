--[[
    Whelp - SearchBar
    Quick search functionality that can be accessed anywhere
]]

local ADDON_NAME, Whelp = ...

Whelp.UI = Whelp.UI or {}
Whelp.UI.SearchBar = {}
local SearchBar = Whelp.UI.SearchBar
local Templates = Whelp.UI.Templates

local frame = nil
local resultsFrame = nil

-- Create the search bar
function SearchBar:Create()
    if frame then return frame end

    frame = CreateFrame("Frame", "WhelpSearchBar", UIParent, "BackdropTemplate")
    frame:SetSize(350, 35)
    frame:SetPoint("TOP", UIParent, "TOP", 0, -100)
    frame:SetFrameStrata("DIALOG")
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)

    Templates:CreateBackdrop(frame, {r = 0.1, g = 0.1, b = 0.1, a = 0.95}, Whelp.Colors.PRIMARY)

    -- Enable dragging
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)

    -- Icon
    local icon = frame:CreateTexture(nil, "ARTWORK")
    icon:SetSize(20, 20)
    icon:SetPoint("LEFT", frame, "LEFT", 8, 0)
    icon:SetTexture("Interface\\Icons\\INV_Misc_Spyglass_03")

    -- Search input
    local searchInput = CreateFrame("EditBox", nil, frame)
    searchInput:SetSize(250, 24)
    searchInput:SetPoint("LEFT", icon, "RIGHT", 8, 0)
    searchInput:SetFontObject("ChatFontNormal")
    searchInput:SetAutoFocus(false)

    local placeholder = searchInput:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    placeholder:SetPoint("LEFT", searchInput, "LEFT", 2, 0)
    placeholder:SetText("Search vendors...")
    placeholder:SetTextColor(0.5, 0.5, 0.5)
    frame.placeholder = placeholder

    searchInput:SetScript("OnTextChanged", function(self)
        local text = self:GetText()
        placeholder:SetShown(text == "")
        SearchBar:OnSearchChanged(text)
    end)

    searchInput:SetScript("OnEnterPressed", function(self)
        SearchBar:PerformSearch(self:GetText())
    end)

    searchInput:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
        SearchBar:Hide()
    end)

    frame.searchInput = searchInput

    -- Close button
    local closeBtn = CreateFrame("Button", nil, frame)
    closeBtn:SetSize(20, 20)
    closeBtn:SetPoint("RIGHT", frame, "RIGHT", -8, 0)
    closeBtn:SetNormalTexture("Interface\\Buttons\\UI-StopButton")

    closeBtn:SetScript("OnClick", function()
        SearchBar:Hide()
    end)

    -- Create results dropdown
    self:CreateResultsFrame()

    frame:Hide()

    return frame
end

-- Create results dropdown
function SearchBar:CreateResultsFrame()
    resultsFrame = CreateFrame("Frame", "WhelpSearchResults", frame, "BackdropTemplate")
    resultsFrame:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", 0, -2)
    resultsFrame:SetPoint("TOPRIGHT", frame, "BOTTOMRIGHT", 0, -2)
    resultsFrame:SetHeight(200)
    resultsFrame:SetFrameStrata("DIALOG")
    resultsFrame:SetFrameLevel(frame:GetFrameLevel() + 1)

    Templates:CreateBackdrop(resultsFrame, {r = 0.1, g = 0.1, b = 0.1, a = 0.95}, Whelp.Colors.BORDER)

    -- Results scroll frame
    local scrollFrame, scrollContent = Templates:CreateScrollFrame(resultsFrame, resultsFrame:GetWidth() - 4, 196)
    scrollFrame:SetPoint("TOPLEFT", resultsFrame, "TOPLEFT", 2, -2)

    resultsFrame.scrollFrame = scrollFrame
    resultsFrame.scrollContent = scrollContent
    resultsFrame.resultItems = {}

    resultsFrame:Hide()
end

-- Handle search input change (live search)
function SearchBar:OnSearchChanged(text)
    if not resultsFrame then return end

    -- Clear existing results
    for _, item in pairs(resultsFrame.resultItems) do
        item:Hide()
    end
    resultsFrame.resultItems = {}

    if text == "" or string.len(text) < 2 then
        resultsFrame:Hide()
        return
    end

    -- Search vendors
    local results = Whelp.VendorManager:SearchVendors(text, {})

    if #results == 0 then
        resultsFrame:Hide()
        return
    end

    -- Show max 8 results
    local maxResults = math.min(8, #results)
    local yOffset = 5

    for i = 1, maxResults do
        local vendor = results[i]
        local item = self:CreateResultItem(resultsFrame.scrollContent, vendor)
        item:SetPoint("TOPLEFT", resultsFrame.scrollContent, "TOPLEFT", 5, -yOffset)
        yOffset = yOffset + 45
        table.insert(resultsFrame.resultItems, item)
    end

    -- Show more option if there are more results
    if #results > maxResults then
        local moreItem = self:CreateMoreResultsItem(resultsFrame.scrollContent, #results, text)
        moreItem:SetPoint("TOPLEFT", resultsFrame.scrollContent, "TOPLEFT", 5, -yOffset)
        table.insert(resultsFrame.resultItems, moreItem)
        yOffset = yOffset + 30
    end

    resultsFrame.scrollContent:SetHeight(yOffset)
    resultsFrame:SetHeight(math.min(yOffset + 10, 250))
    resultsFrame:Show()
end

-- Create a result item
function SearchBar:CreateResultItem(parent, vendor)
    local item = CreateFrame("Button", nil, parent, "BackdropTemplate")
    item:SetSize(parent:GetWidth() - 25, 40)
    item.vendor = vendor

    Templates:CreateBackdrop(item, {r = 0.15, g = 0.15, b = 0.15, a = 0.9}, {r = 0.2, g = 0.2, b = 0.2})

    -- Category icon
    local category = Whelp.CategoryManager:GetCategory(vendor.category)
    local icon = item:CreateTexture(nil, "ARTWORK")
    icon:SetSize(28, 28)
    icon:SetPoint("LEFT", item, "LEFT", 6, 0)
    icon:SetTexture(category and category.icon or "Interface\\Icons\\INV_Misc_QuestionMark")

    -- Name
    local name = item:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    name:SetPoint("TOPLEFT", icon, "TOPRIGHT", 8, -2)
    name:SetText(vendor.name)

    -- Rating
    local stars = Templates:CreateStarRating(item, vendor.averageRating or 0, 10)
    stars:SetPoint("TOPLEFT", name, "BOTTOMLEFT", 0, -4)

    local ratingText = item:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    ratingText:SetPoint("LEFT", stars, "RIGHT", 5, 0)
    ratingText:SetText(string.format("%.1f (%d)", vendor.averageRating or 0, vendor.reviewCount or 0))
    ratingText:SetTextColor(0.6, 0.6, 0.6)

    -- Hover effect
    item:SetScript("OnEnter", function(self)
        self:SetBackdropBorderColor(Whelp.Colors.PRIMARY.r, Whelp.Colors.PRIMARY.g, Whelp.Colors.PRIMARY.b)
    end)

    item:SetScript("OnLeave", function(self)
        self:SetBackdropBorderColor(0.2, 0.2, 0.2)
    end)

    -- Click to view vendor
    item:SetScript("OnClick", function(self)
        SearchBar:Hide()
        Whelp.UI.VendorDetail:Show(self.vendor)
    end)

    return item
end

-- Create "View more results" item
function SearchBar:CreateMoreResultsItem(parent, totalResults, searchText)
    local item = CreateFrame("Button", nil, parent)
    item:SetSize(parent:GetWidth() - 25, 25)
    item.searchText = searchText

    local text = item:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    text:SetPoint("CENTER", item, "CENTER")
    text:SetText(string.format("View all %d results...", totalResults))
    text:SetTextColor(Whelp.Colors.PRIMARY.r, Whelp.Colors.PRIMARY.g, Whelp.Colors.PRIMARY.b)

    item:SetScript("OnEnter", function()
        text:SetTextColor(1, 1, 1)
    end)

    item:SetScript("OnLeave", function()
        text:SetTextColor(Whelp.Colors.PRIMARY.r, Whelp.Colors.PRIMARY.g, Whelp.Colors.PRIMARY.b)
    end)

    item:SetScript("OnClick", function(self)
        SearchBar:Hide()
        Whelp.UI.MainFrame:Show()
        Whelp.UI.MainFrame:SelectTab("search")
        -- TODO: Pass search text to main frame search
    end)

    return item
end

-- Perform full search (opens main UI)
function SearchBar:PerformSearch(text)
    if text == "" then return end

    self:Hide()
    Whelp.UI.MainFrame:Show()
    Whelp.UI.MainFrame:SelectTab("search")
end

-- Toggle visibility
function SearchBar:Toggle()
    if not frame then
        self:Create()
    end

    if frame:IsShown() then
        self:Hide()
    else
        self:Show()
    end
end

-- Show the search bar
function SearchBar:Show()
    if not frame then
        self:Create()
    end

    frame:Show()
    frame.searchInput:SetFocus()
end

-- Hide the search bar
function SearchBar:Hide()
    if frame then
        frame.searchInput:SetText("")
        frame.searchInput:ClearFocus()
        frame:Hide()
    end
    if resultsFrame then
        resultsFrame:Hide()
    end
end

-- Check if shown
function SearchBar:IsShown()
    return frame and frame:IsShown()
end
