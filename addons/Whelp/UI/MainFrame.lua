--[[
    Whelp - MainFrame
    The main UI window for browsing and searching vendors
]]

local ADDON_NAME, Whelp = ...

Whelp.UI = Whelp.UI or {}
Whelp.UI.MainFrame = {}
local MainFrame = Whelp.UI.MainFrame
local Templates = Whelp.UI.Templates

local frame = nil
local contentFrame = nil
local vendorCards = {}
local currentPage = 1
local currentTab = "browse"

-- Create the main frame
function MainFrame:Create()
    if frame then return frame end

    -- Main container
    frame = CreateFrame("Frame", "WhelpMainFrame", UIParent, "BackdropTemplate")
    frame:SetSize(Whelp.UI.MAIN_FRAME_WIDTH, Whelp.UI.MAIN_FRAME_HEIGHT)
    frame:SetPoint("CENTER")
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    frame:SetFrameStrata("HIGH")
    frame:EnableMouse(true)

    Templates:CreateBackdrop(frame, Whelp.Colors.BACKGROUND, Whelp.Colors.BORDER)

    -- Title bar
    local titleBar, titleText = Templates:CreateTitleBar(frame, "Whelp - Vendor Ratings", true)
    titleText:SetText("|cff" .. Whelp.Colors.PRIMARY_HEX .. "Whelp|r - Vendor Ratings")

    -- Close button
    Templates:CreateCloseButton(frame)

    -- Version text
    local versionText = titleBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    versionText:SetPoint("RIGHT", titleBar, "RIGHT", -30, 0)
    versionText:SetText("v" .. Whelp.VERSION)
    versionText:SetTextColor(0.6, 0.6, 0.6)

    -- Create tabs
    self:CreateTabs()

    -- Create content area
    self:CreateContentArea()

    -- Create footer with pagination
    self:CreateFooter()

    -- Initially hidden
    frame:Hide()

    -- Register for escape key
    tinsert(UISpecialFrames, "WhelpMainFrame")

    return frame
end

-- Create tab buttons
function MainFrame:CreateTabs()
    local tabs = {
        {id = "browse", text = "Browse"},
        {id = "search", text = "Search"},
        {id = "favorites", text = "Favorites"},
        {id = "myreviews", text = "My Reviews"},
        {id = "addvendor", text = "+ Add Vendor"},
    }

    frame.tabs = {}
    local tabWidth = 130
    local xOffset = 10

    for i, tabData in ipairs(tabs) do
        local tab = Templates:CreateTabButton(frame, tabData.text, i, function(index)
            self:SelectTab(tabs[index].id)
        end)
        tab:SetSize(tabWidth, 26)
        tab:SetPoint("TOPLEFT", frame, "TOPLEFT", xOffset + (i-1) * (tabWidth + 5), -32)
        tab.tabId = tabData.id
        frame.tabs[tabData.id] = tab
    end

    -- Select first tab by default
    self:SelectTab("browse")
end

-- Select a tab
function MainFrame:SelectTab(tabId)
    currentTab = tabId

    -- Update tab appearance
    for id, tab in pairs(frame.tabs) do
        tab:SetActive(id == tabId)
    end

    -- Update content
    self:RefreshContent()
end

-- Create the main content area
function MainFrame:CreateContentArea()
    -- Content container
    contentFrame = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    contentFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -65)
    contentFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -10, 40)

    Templates:CreateBackdrop(contentFrame, {r = 0.05, g = 0.05, b = 0.05, a = 0.5}, Whelp.Colors.BORDER)

    -- Create scroll frame
    local scrollFrame, scrollContent = Templates:CreateScrollFrame(
        contentFrame,
        contentFrame:GetWidth() - 4,
        contentFrame:GetHeight() - 4
    )
    scrollFrame:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", 2, -2)

    contentFrame.scrollFrame = scrollFrame
    contentFrame.scrollContent = scrollContent

    -- Filter bar (only shown in browse/search tabs)
    self:CreateFilterBar()
end

-- Create filter bar
function MainFrame:CreateFilterBar()
    local filterBar = CreateFrame("Frame", nil, contentFrame, "BackdropTemplate")
    filterBar:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", 5, -5)
    filterBar:SetPoint("TOPRIGHT", contentFrame, "TOPRIGHT", -5, -5)
    filterBar:SetHeight(35)

    Templates:CreateBackdrop(filterBar, {r = 0.1, g = 0.1, b = 0.1, a = 0.8}, Whelp.Colors.BORDER)

    -- Category dropdown
    local categoryLabel = filterBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    categoryLabel:SetPoint("LEFT", filterBar, "LEFT", 10, 0)
    categoryLabel:SetText("Category:")

    local categoryOptions = Whelp.CategoryManager:GetDropdownOptions()
    local categoryDropdown = Templates:CreateDropdown(
        filterBar,
        120,
        categoryOptions,
        "all",
        function(value)
            if Whelp.db and Whelp.db.profile then
                Whelp.db.profile.filters.category = value
            end
            self:RefreshContent()
        end
    )
    categoryDropdown:SetPoint("LEFT", categoryLabel, "RIGHT", 0, -3)

    -- Sort dropdown
    local sortLabel = filterBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    sortLabel:SetPoint("LEFT", categoryDropdown, "RIGHT", 20, 3)
    sortLabel:SetText("Sort by:")

    local sortOptions = {
        {value = "rating", text = "Rating"},
        {value = "reviews", text = "Most Reviews"},
        {value = "recent", text = "Recently Reviewed"},
        {value = "name", text = "Name"},
    }
    local sortDropdown = Templates:CreateDropdown(
        filterBar,
        100,
        sortOptions,
        "rating",
        function(value)
            if Whelp.db and Whelp.db.profile then
                Whelp.db.profile.filters.sortBy = value
            end
            self:RefreshContent()
        end
    )
    sortDropdown:SetPoint("LEFT", sortLabel, "RIGHT", 0, -3)

    -- Minimum rating filter
    local minRatingLabel = filterBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    minRatingLabel:SetPoint("LEFT", sortDropdown, "RIGHT", 20, 3)
    minRatingLabel:SetText("Min Rating:")

    local minRatingStars = Templates:CreateStarRating(filterBar, 0, 14, true)
    minRatingStars:SetPoint("LEFT", minRatingLabel, "RIGHT", 5, 0)
    minRatingStars.OnRatingChanged = function(_, rating)
        if Whelp.db and Whelp.db.profile then
            Whelp.db.profile.filters.minRating = rating
        end
        self:RefreshContent()
    end

    contentFrame.filterBar = filterBar
    contentFrame.categoryDropdown = categoryDropdown
    contentFrame.sortDropdown = sortDropdown
end

-- Create footer with pagination
function MainFrame:CreateFooter()
    local footer = CreateFrame("Frame", nil, frame)
    footer:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 10, 10)
    footer:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -10, 10)
    footer:SetHeight(25)

    -- Stats text
    local statsText = footer:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    statsText:SetPoint("LEFT", footer, "LEFT", 5, 0)
    frame.statsText = statsText

    -- Pagination
    local prevButton = Templates:CreateButton(footer, "<", 30, 22, function()
        if currentPage > 1 then
            currentPage = currentPage - 1
            self:RefreshContent()
        end
    end)
    prevButton:SetPoint("RIGHT", footer, "RIGHT", -80, 0)
    frame.prevButton = prevButton

    local pageText = footer:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    pageText:SetPoint("RIGHT", footer, "RIGHT", -45, 0)
    frame.pageText = pageText

    local nextButton = Templates:CreateButton(footer, ">", 30, 22, function()
        currentPage = currentPage + 1
        self:RefreshContent()
    end)
    nextButton:SetPoint("RIGHT", footer, "RIGHT", -5, 0)
    frame.nextButton = nextButton
end

-- Refresh the content based on current tab
function MainFrame:RefreshContent()
    if not frame then return end

    -- Hide filter bar for some tabs
    if contentFrame.filterBar then
        if currentTab == "browse" or currentTab == "search" then
            contentFrame.filterBar:Show()
        else
            contentFrame.filterBar:Hide()
        end
    end

    -- Clear existing vendor cards
    for _, card in pairs(vendorCards) do
        card:Hide()
        card:SetParent(nil)
    end
    vendorCards = {}

    -- Load content based on tab
    if currentTab == "browse" then
        self:ShowBrowseContent()
    elseif currentTab == "search" then
        self:ShowSearchContent()
    elseif currentTab == "favorites" then
        self:ShowFavoritesContent()
    elseif currentTab == "myreviews" then
        self:ShowMyReviewsContent()
    elseif currentTab == "addvendor" then
        self:ShowAddVendorForm()
    end
end

-- Show browse tab content
function MainFrame:ShowBrowseContent()
    local filters = {}
    if Whelp.db and Whelp.db.profile then
        filters = Whelp.db.profile.filters
    end

    local vendors = Whelp.VendorManager:GetVendors(
        {
            category = filters.category ~= "all" and filters.category or nil,
            minRating = filters.minRating,
        },
        filters.sortBy
    )

    self:DisplayVendorList(vendors)
end

-- Show search content
function MainFrame:ShowSearchContent()
    -- Create search box if not exists
    if not contentFrame.searchBox then
        local searchBox = CreateFrame("EditBox", nil, contentFrame, "InputBoxTemplate")
        searchBox:SetSize(300, 24)
        searchBox:SetPoint("TOPLEFT", contentFrame.filterBar, "BOTTOMLEFT", 10, -10)
        searchBox:SetAutoFocus(false)

        local searchButton = Templates:CreateButton(contentFrame, "Search", 80, 24, function()
            self:PerformSearch(searchBox:GetText())
        end)
        searchButton:SetPoint("LEFT", searchBox, "RIGHT", 10, 0)

        searchBox:SetScript("OnEnterPressed", function(self)
            MainFrame:PerformSearch(self:GetText())
        end)

        contentFrame.searchBox = searchBox
        contentFrame.searchButton = searchButton
    end

    contentFrame.searchBox:Show()
    contentFrame.searchButton:Show()

    -- Show recent results or all vendors
    local vendors = Whelp.VendorManager:GetVendors({}, "rating")
    self:DisplayVendorList(vendors, 45) -- Extra offset for search box
end

-- Perform search
function MainFrame:PerformSearch(query)
    if not query or query == "" then
        self:ShowSearchContent()
        return
    end

    local filters = {}
    if Whelp.db and Whelp.db.profile then
        filters = Whelp.db.profile.filters
    end

    local vendors = Whelp.VendorManager:SearchVendors(query, {
        category = filters.category ~= "all" and filters.category or nil,
        minRating = filters.minRating,
    })

    self:DisplayVendorList(vendors, 45)
end

-- Show favorites content
function MainFrame:ShowFavoritesContent()
    if contentFrame.searchBox then
        contentFrame.searchBox:Hide()
        contentFrame.searchButton:Hide()
    end

    local favorites = Whelp.Database:GetFavorites()
    self:DisplayVendorList(favorites, 0)

    if #favorites == 0 then
        self:ShowEmptyMessage("No favorites yet.\nClick the heart icon on a vendor to add them to favorites!")
    end
end

-- Show my reviews content
function MainFrame:ShowMyReviewsContent()
    if contentFrame.searchBox then
        contentFrame.searchBox:Hide()
        contentFrame.searchButton:Hide()
    end

    local reviews = Whelp.RatingSystem:GetMyReviews()
    self:DisplayReviewList(reviews)

    if #reviews == 0 then
        self:ShowEmptyMessage("You haven't written any reviews yet.\nBrowse vendors and share your experiences!")
    end
end

-- Show add vendor form
function MainFrame:ShowAddVendorForm()
    if contentFrame.searchBox then
        contentFrame.searchBox:Hide()
        contentFrame.searchButton:Hide()
    end

    -- Create or show the add vendor form
    if not contentFrame.addVendorForm then
        self:CreateAddVendorForm()
    end

    contentFrame.addVendorForm:Show()

    -- Hide stats and pagination
    frame.statsText:SetText("")
    frame.pageText:SetText("")
    frame.prevButton:Hide()
    frame.nextButton:Hide()
end

-- Create add vendor form
function MainFrame:CreateAddVendorForm()
    local formFrame = CreateFrame("Frame", nil, contentFrame.scrollContent)
    formFrame:SetPoint("TOPLEFT", contentFrame.scrollContent, "TOPLEFT", 10, -10)
    formFrame:SetSize(contentFrame:GetWidth() - 40, 350)

    local yOffset = 0

    -- Title
    local formTitle = formFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    formTitle:SetPoint("TOPLEFT", formFrame, "TOPLEFT", 0, yOffset)
    formTitle:SetText("Add New Vendor")
    yOffset = yOffset - 30

    -- Vendor Name
    local nameLabel = formFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    nameLabel:SetPoint("TOPLEFT", formFrame, "TOPLEFT", 0, yOffset)
    nameLabel:SetText("Vendor Name (Name-Realm):")
    yOffset = yOffset - 20

    local nameInput = CreateFrame("EditBox", nil, formFrame, "InputBoxTemplate")
    nameInput:SetSize(250, 24)
    nameInput:SetPoint("TOPLEFT", formFrame, "TOPLEFT", 5, yOffset)
    nameInput:SetAutoFocus(false)
    formFrame.nameInput = nameInput
    yOffset = yOffset - 35

    -- Use target button
    local useTargetBtn = Templates:CreateButton(formFrame, "Use Current Target", 150, 22, function()
        local targetInfo = Whelp.VendorManager:CheckTargetAsVendor()
        if targetInfo then
            nameInput:SetText(targetInfo.name)
        else
            Whelp:Print("No valid player target selected.")
        end
    end)
    useTargetBtn:SetPoint("TOPLEFT", nameInput, "TOPRIGHT", 10, 0)

    -- Category
    local categoryLabel = formFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    categoryLabel:SetPoint("TOPLEFT", formFrame, "TOPLEFT", 0, yOffset)
    categoryLabel:SetText("Service Category:")
    yOffset = yOffset - 25

    local categoryOptions = {}
    for _, cat in ipairs(Whelp.CategoryManager:GetAllCategories()) do
        table.insert(categoryOptions, {value = cat.id, text = cat.name})
    end
    local categoryDropdown = Templates:CreateDropdown(formFrame, 180, categoryOptions, "other")
    categoryDropdown:SetPoint("TOPLEFT", formFrame, "TOPLEFT", -15, yOffset)
    formFrame.categoryDropdown = categoryDropdown
    yOffset = yOffset - 40

    -- Description
    local descLabel = formFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    descLabel:SetPoint("TOPLEFT", formFrame, "TOPLEFT", 0, yOffset)
    descLabel:SetText("Service Description:")
    yOffset = yOffset - 20

    local descScroll, descInput = Templates:CreateEditBox(formFrame, 400, 80, true)
    descScroll:SetPoint("TOPLEFT", formFrame, "TOPLEFT", 5, yOffset)
    formFrame.descInput = descInput
    yOffset = yOffset - 95

    -- Pricing
    local priceLabel = formFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    priceLabel:SetPoint("TOPLEFT", formFrame, "TOPLEFT", 0, yOffset)
    priceLabel:SetText("Pricing Information:")
    yOffset = yOffset - 20

    local priceInput = CreateFrame("EditBox", nil, formFrame, "InputBoxTemplate")
    priceInput:SetSize(250, 24)
    priceInput:SetPoint("TOPLEFT", formFrame, "TOPLEFT", 5, yOffset)
    priceInput:SetAutoFocus(false)
    formFrame.priceInput = priceInput
    yOffset = yOffset - 35

    -- Contact info
    local contactLabel = formFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    contactLabel:SetPoint("TOPLEFT", formFrame, "TOPLEFT", 0, yOffset)
    contactLabel:SetText("Contact Info (optional):")
    yOffset = yOffset - 20

    local contactInput = CreateFrame("EditBox", nil, formFrame, "InputBoxTemplate")
    contactInput:SetSize(250, 24)
    contactInput:SetPoint("TOPLEFT", formFrame, "TOPLEFT", 5, yOffset)
    contactInput:SetAutoFocus(false)
    formFrame.contactInput = contactInput
    yOffset = yOffset - 45

    -- Submit button
    local submitBtn = Templates:CreateButton(formFrame, "Add Vendor", 120, 28, function()
        self:SubmitNewVendor(formFrame)
    end)
    submitBtn:SetPoint("TOPLEFT", formFrame, "TOPLEFT", 0, yOffset)

    -- Clear button
    local clearBtn = Templates:CreateButton(formFrame, "Clear Form", 100, 28, function()
        nameInput:SetText("")
        descInput:SetText("")
        priceInput:SetText("")
        contactInput:SetText("")
    end)
    clearBtn:SetPoint("LEFT", submitBtn, "RIGHT", 10, 0)

    contentFrame.addVendorForm = formFrame
end

-- Submit new vendor
function MainFrame:SubmitNewVendor(formFrame)
    local name = formFrame.nameInput:GetText()
    local category = UIDropDownMenu_GetSelectedValue(formFrame.categoryDropdown) or "other"
    local description = formFrame.descInput:GetText()
    local pricing = formFrame.priceInput:GetText()
    local contactInfo = formFrame.contactInput:GetText()

    local vendor, err = Whelp.VendorManager:CreateVendor({
        name = name,
        category = category,
        description = description,
        pricing = pricing,
        contactInfo = contactInfo,
    })

    if vendor then
        Whelp:Print("Vendor '" .. vendor.name .. "' added successfully!")
        -- Clear form
        formFrame.nameInput:SetText("")
        formFrame.descInput:SetText("")
        formFrame.priceInput:SetText("")
        formFrame.contactInput:SetText("")
        -- Switch to browse tab
        self:SelectTab("browse")
    else
        Whelp:Print("Error: " .. (err or "Unknown error"))
    end
end

-- Display vendor list
function MainFrame:DisplayVendorList(vendors, extraYOffset)
    extraYOffset = extraYOffset or 0

    -- Hide add vendor form if visible
    if contentFrame.addVendorForm then
        contentFrame.addVendorForm:Hide()
    end

    local perPage = Whelp.VENDORS_PER_PAGE
    local totalVendors = #vendors
    local totalPages = math.ceil(totalVendors / perPage)

    -- Ensure current page is valid
    if currentPage > totalPages then
        currentPage = math.max(1, totalPages)
    end

    -- Get vendors for current page
    local startIndex = ((currentPage - 1) * perPage) + 1
    local endIndex = math.min(startIndex + perPage - 1, totalVendors)

    -- Update content height
    local cardHeight = 90
    local cardSpacing = 10
    local columns = 2
    local rows = math.ceil((endIndex - startIndex + 1) / columns)
    local contentHeight = (rows * (cardHeight + cardSpacing)) + 50 + extraYOffset

    contentFrame.scrollContent:SetHeight(math.max(contentHeight, contentFrame:GetHeight() - 50))

    -- Create vendor cards
    local col = 0
    local row = 0
    local filterBarHeight = contentFrame.filterBar:IsShown() and 45 or 5

    for i = startIndex, endIndex do
        local vendor = vendors[i]
        if vendor then
            local card = Whelp.UI.VendorCard:Create(contentFrame.scrollContent, vendor)
            card:SetPoint("TOPLEFT", contentFrame.scrollContent, "TOPLEFT",
                10 + (col * (Whelp.UI.VENDOR_CARD_WIDTH + 10)),
                -(filterBarHeight + extraYOffset + (row * (cardHeight + cardSpacing))))

            table.insert(vendorCards, card)

            col = col + 1
            if col >= columns then
                col = 0
                row = row + 1
            end
        end
    end

    -- Update stats
    frame.statsText:SetText(string.format("%d vendors found", totalVendors))

    -- Update pagination
    frame.pageText:SetText(string.format("%d / %d", currentPage, math.max(1, totalPages)))
    frame.prevButton:SetEnabled(currentPage > 1)
    frame.nextButton:SetEnabled(currentPage < totalPages)
    frame.prevButton:Show()
    frame.nextButton:Show()
end

-- Display review list
function MainFrame:DisplayReviewList(reviews)
    -- Similar to vendor list but for reviews
    local perPage = Whelp.REVIEWS_PER_PAGE
    local totalReviews = #reviews
    local totalPages = math.ceil(totalReviews / perPage)

    if currentPage > totalPages then
        currentPage = math.max(1, totalPages)
    end

    local startIndex = ((currentPage - 1) * perPage) + 1
    local endIndex = math.min(startIndex + perPage - 1, totalReviews)

    local yOffset = 10
    for i = startIndex, endIndex do
        local review = reviews[i]
        if review then
            local vendor = Whelp.Database:GetVendor(review.vendorId)
            local reviewCard = self:CreateReviewCard(contentFrame.scrollContent, review, vendor)
            reviewCard:SetPoint("TOPLEFT", contentFrame.scrollContent, "TOPLEFT", 10, -yOffset)
            yOffset = yOffset + 100
            table.insert(vendorCards, reviewCard)
        end
    end

    frame.statsText:SetText(string.format("%d reviews", totalReviews))
    frame.pageText:SetText(string.format("%d / %d", currentPage, math.max(1, totalPages)))
    frame.prevButton:SetEnabled(currentPage > 1)
    frame.nextButton:SetEnabled(currentPage < totalPages)
    frame.prevButton:Show()
    frame.nextButton:Show()
end

-- Create a review card
function MainFrame:CreateReviewCard(parent, review, vendor)
    local card = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    card:SetSize(parent:GetWidth() - 20, 90)

    Templates:CreateBackdrop(card, {r = 0.1, g = 0.1, b = 0.1, a = 0.8}, Whelp.Colors.BORDER)

    -- Vendor name
    local vendorName = card:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    vendorName:SetPoint("TOPLEFT", card, "TOPLEFT", 10, -10)
    vendorName:SetText(vendor and vendor.name or "Unknown Vendor")
    vendorName:SetTextColor(Whelp.Colors.TEXT_HIGHLIGHT.r, Whelp.Colors.TEXT_HIGHLIGHT.g, Whelp.Colors.TEXT_HIGHLIGHT.b)

    -- Rating
    local stars = Templates:CreateStarRating(card, review.rating, 14)
    stars:SetPoint("LEFT", vendorName, "RIGHT", 10, 0)

    -- Date
    local dateText = card:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    dateText:SetPoint("TOPRIGHT", card, "TOPRIGHT", -10, -10)
    dateText:SetText(Whelp.Utils.FormatRelativeTime(review.timestamp))
    dateText:SetTextColor(0.6, 0.6, 0.6)

    -- Review content
    local content = card:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    content:SetPoint("TOPLEFT", card, "TOPLEFT", 10, -35)
    content:SetPoint("BOTTOMRIGHT", card, "BOTTOMRIGHT", -10, 10)
    content:SetJustifyH("LEFT")
    content:SetJustifyV("TOP")
    content:SetText(Whelp.Utils.TruncateText(review.content, 200))

    return card
end

-- Show empty state message
function MainFrame:ShowEmptyMessage(message)
    if not contentFrame.emptyMessage then
        contentFrame.emptyMessage = contentFrame.scrollContent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        contentFrame.emptyMessage:SetPoint("CENTER", contentFrame.scrollContent, "CENTER", 0, 50)
        contentFrame.emptyMessage:SetTextColor(0.5, 0.5, 0.5)
    end

    contentFrame.emptyMessage:SetText(message)
    contentFrame.emptyMessage:Show()

    frame.statsText:SetText("")
    frame.pageText:SetText("")
    frame.prevButton:Hide()
    frame.nextButton:Hide()
end

-- Toggle visibility
function MainFrame:Toggle()
    if not frame then
        self:Create()
    end

    if frame:IsShown() then
        frame:Hide()
    else
        frame:Show()
        self:RefreshContent()
    end
end

-- Show the frame
function MainFrame:Show()
    if not frame then
        self:Create()
    end
    frame:Show()
    self:RefreshContent()
end

-- Hide the frame
function MainFrame:Hide()
    if frame then
        frame:Hide()
    end
end

-- Check if shown
function MainFrame:IsShown()
    return frame and frame:IsShown()
end
