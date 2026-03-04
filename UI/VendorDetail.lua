--[[
    Whelp - VendorDetail
    Detailed view of a vendor with all their reviews
]]

local ADDON_NAME, Whelp = ...

Whelp.UI = Whelp.UI or {}
Whelp.UI.VendorDetail = {}
local VendorDetail = Whelp.UI.VendorDetail
local Templates = Whelp.UI.Templates

local frame = nil
local currentVendor = nil
local currentPage = 1

-- Create the detail frame
function VendorDetail:Create()
    if frame then return frame end

    frame = CreateFrame("Frame", "WhelpVendorDetailFrame", UIParent, "BackdropTemplate")
    frame:SetSize(Whelp.UI.DETAIL_FRAME_WIDTH, Whelp.UI.DETAIL_FRAME_HEIGHT)
    frame:SetPoint("CENTER", 200, 0)
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    frame:SetFrameStrata("DIALOG")
    frame:EnableMouse(true)

    Templates:CreateBackdrop(frame, Whelp.Colors.BACKGROUND, Whelp.Colors.BORDER)

    -- Title bar
    local titleBar, titleText = Templates:CreateTitleBar(frame, "Vendor Details", true)
    frame.titleText = titleText

    -- Close button
    Templates:CreateCloseButton(frame)

    -- Vendor info section
    self:CreateVendorInfoSection()

    -- Reviews section
    self:CreateReviewsSection()

    frame:Hide()
    tinsert(UISpecialFrames, "WhelpVendorDetailFrame")

    return frame
end

-- Create vendor info section
function VendorDetail:CreateVendorInfoSection()
    local infoSection = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    infoSection:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -35)
    infoSection:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -10, -35)
    infoSection:SetHeight(180)

    Templates:CreateBackdrop(infoSection, {r = 0.08, g = 0.08, b = 0.08, a = 0.9}, Whelp.Colors.BORDER)

    -- Category icon
    local categoryIcon = infoSection:CreateTexture(nil, "ARTWORK")
    categoryIcon:SetSize(48, 48)
    categoryIcon:SetPoint("TOPLEFT", infoSection, "TOPLEFT", 15, -15)
    frame.categoryIcon = categoryIcon

    -- Vendor name
    local nameText = infoSection:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    nameText:SetPoint("TOPLEFT", categoryIcon, "TOPRIGHT", 10, -5)
    nameText:SetPoint("RIGHT", infoSection, "RIGHT", -80, 0)
    nameText:SetJustifyH("LEFT")
    frame.vendorName = nameText

    -- Favorite button
    local favoriteBtn = CreateFrame("Button", nil, infoSection)
    favoriteBtn:SetSize(32, 32)
    favoriteBtn:SetPoint("TOPRIGHT", infoSection, "TOPRIGHT", -15, -15)

    local favoriteIcon = favoriteBtn:CreateTexture(nil, "ARTWORK")
    favoriteIcon:SetAllPoints()
    favoriteBtn.icon = favoriteIcon
    frame.favoriteBtn = favoriteBtn

    favoriteBtn:SetScript("OnClick", function()
        if not currentVendor then return end
        if Whelp.Database:IsFavorite(currentVendor.id) then
            Whelp.Database:RemoveFavorite(currentVendor.id)
            self:UpdateFavoriteIcon(false)
        else
            Whelp.Database:AddFavorite(currentVendor.id)
            self:UpdateFavoriteIcon(true)
        end
    end)

    -- Rating display
    local ratingContainer = CreateFrame("Frame", nil, infoSection)
    ratingContainer:SetSize(200, 30)
    ratingContainer:SetPoint("TOPLEFT", categoryIcon, "BOTTOMLEFT", 0, -10)

    local stars = Templates:CreateStarRating(ratingContainer, 0, 18)
    stars:SetPoint("LEFT", ratingContainer, "LEFT", 0, 0)
    frame.detailStars = stars

    local ratingText = ratingContainer:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    ratingText:SetPoint("LEFT", stars, "RIGHT", 10, 0)
    frame.ratingText = ratingText

    local reviewCountText = ratingContainer:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    reviewCountText:SetPoint("LEFT", ratingText, "RIGHT", 5, 0)
    frame.reviewCountText = reviewCountText

    -- Category and info
    local categoryText = infoSection:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    categoryText:SetPoint("TOPLEFT", ratingContainer, "BOTTOMLEFT", 0, -8)
    frame.categoryText = categoryText

    -- Description
    local descLabel = infoSection:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    descLabel:SetPoint("TOPLEFT", categoryText, "BOTTOMLEFT", 0, -10)
    descLabel:SetText("Description:")
    descLabel:SetTextColor(0.6, 0.6, 0.6)

    local descText = infoSection:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    descText:SetPoint("TOPLEFT", descLabel, "BOTTOMLEFT", 0, -4)
    descText:SetPoint("RIGHT", infoSection, "RIGHT", -15, 0)
    descText:SetJustifyH("LEFT")
    descText:SetJustifyV("TOP")
    frame.descText = descText

    -- Pricing (if available)
    local pricingLabel = infoSection:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    pricingLabel:SetPoint("TOPLEFT", descText, "BOTTOMLEFT", 0, -8)
    pricingLabel:SetText("Pricing:")
    pricingLabel:SetTextColor(0.6, 0.6, 0.6)
    frame.pricingLabel = pricingLabel

    local pricingText = infoSection:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    pricingText:SetPoint("TOPLEFT", pricingLabel, "BOTTOMLEFT", 0, -4)
    pricingText:SetPoint("RIGHT", infoSection, "RIGHT", -15, 0)
    pricingText:SetJustifyH("LEFT")
    pricingText:SetTextColor(1, 0.82, 0)
    frame.pricingText = pricingText

    frame.infoSection = infoSection
end

-- Create reviews section
function VendorDetail:CreateReviewsSection()
    local reviewSection = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    reviewSection:SetPoint("TOPLEFT", frame.infoSection, "BOTTOMLEFT", 0, -10)
    reviewSection:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -10, 45)

    Templates:CreateBackdrop(reviewSection, {r = 0.05, g = 0.05, b = 0.05, a = 0.5}, Whelp.Colors.BORDER)

    -- Reviews header
    local reviewsHeader = reviewSection:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    reviewsHeader:SetPoint("TOPLEFT", reviewSection, "TOPLEFT", 10, -10)
    reviewsHeader:SetText("Reviews")

    -- Write review button
    local writeReviewBtn = Templates:CreateButton(reviewSection, "Write Review", 100, 22, function()
        if currentVendor then
            Whelp.UI.ReviewForm:Show(currentVendor)
        end
    end)
    writeReviewBtn:SetPoint("TOPRIGHT", reviewSection, "TOPRIGHT", -10, -6)
    frame.writeReviewBtn = writeReviewBtn

    -- Scroll frame for reviews
    local scrollFrame, scrollContent = Templates:CreateScrollFrame(
        reviewSection,
        reviewSection:GetWidth() - 10,
        reviewSection:GetHeight() - 45
    )
    scrollFrame:SetPoint("TOPLEFT", reviewSection, "TOPLEFT", 5, -35)

    frame.reviewScrollFrame = scrollFrame
    frame.reviewScrollContent = scrollContent
    frame.reviewSection = reviewSection
    frame.reviewCards = {}

    -- Pagination
    local prevBtn = Templates:CreateButton(frame, "<", 30, 22, function()
        if currentPage > 1 then
            currentPage = currentPage - 1
            self:LoadReviews()
        end
    end)
    prevBtn:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 10, 10)
    frame.prevBtn = prevBtn

    local pageText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    pageText:SetPoint("LEFT", prevBtn, "RIGHT", 10, 0)
    frame.pageText = pageText

    local nextBtn = Templates:CreateButton(frame, ">", 30, 22, function()
        currentPage = currentPage + 1
        self:LoadReviews()
    end)
    nextBtn:SetPoint("LEFT", pageText, "RIGHT", 10, 0)
    frame.nextBtn = nextBtn
end

-- Show vendor detail
function VendorDetail:Show(vendor)
    if not frame then
        self:Create()
    end

    currentVendor = vendor
    currentPage = 1

    self:UpdateVendorInfo()
    self:LoadReviews()

    frame:Show()
end

-- Update vendor information display
function VendorDetail:UpdateVendorInfo()
    if not currentVendor or not frame then return end

    local vendor = currentVendor
    local category = Whelp.CategoryManager:GetCategory(vendor.category)

    -- Update title
    frame.titleText:SetText("|cff" .. Whelp.Colors.PRIMARY_HEX .. "Whelp|r - " .. vendor.name)

    -- Category icon
    frame.categoryIcon:SetTexture(category and category.icon or "Interface\\Icons\\INV_Misc_QuestionMark")

    -- Name
    frame.vendorName:SetText(vendor.name)

    -- Favorite
    self:UpdateFavoriteIcon(Whelp.Database:IsFavorite(vendor.id))

    -- Rating
    frame.detailStars:SetRating(vendor.averageRating or 0)

    local ratingColor = Whelp.Utils.GetRatingColor(vendor.averageRating)
    frame.ratingText:SetText(string.format("%.1f", vendor.averageRating or 0))
    frame.ratingText:SetTextColor(ratingColor.r, ratingColor.g, ratingColor.b)

    frame.reviewCountText:SetText(string.format("(%d reviews)", vendor.reviewCount or 0))
    frame.reviewCountText:SetTextColor(0.6, 0.6, 0.6)

    -- Category
    frame.categoryText:SetText(category and category.name or "Other Services")
    frame.categoryText:SetTextColor(0.8, 0.8, 0.8)

    -- Description
    frame.descText:SetText(vendor.description or "No description provided.")

    -- Pricing
    if vendor.pricing and vendor.pricing ~= "" then
        frame.pricingLabel:Show()
        frame.pricingText:Show()
        frame.pricingText:SetText(vendor.pricing)
    else
        frame.pricingLabel:Hide()
        frame.pricingText:Hide()
    end

    -- Check if user already reviewed
    local hasReviewed = Whelp.Database:HasReviewedVendor(vendor.id)
    if hasReviewed then
        frame.writeReviewBtn:SetText("Edit Review")
    else
        frame.writeReviewBtn:SetText("Write Review")
    end
end

-- Update favorite icon
function VendorDetail:UpdateFavoriteIcon(isFavorite)
    if isFavorite then
        frame.favoriteBtn.icon:SetTexture("Interface\\COMMON\\ReputationStar")
        frame.favoriteBtn.icon:SetTexCoord(0, 0.5, 0, 0.5)
        frame.favoriteBtn.icon:SetVertexColor(1, 0.2, 0.2)
    else
        frame.favoriteBtn.icon:SetTexture("Interface\\COMMON\\ReputationStar")
        frame.favoriteBtn.icon:SetTexCoord(0.5, 1, 0, 0.5)
        frame.favoriteBtn.icon:SetVertexColor(0.5, 0.5, 0.5)
    end
end

-- Load reviews for current vendor
function VendorDetail:LoadReviews()
    if not currentVendor or not frame then return end

    -- Clear existing review cards
    for _, card in pairs(frame.reviewCards) do
        card:Hide()
        card:SetParent(nil)
    end
    frame.reviewCards = {}

    -- Get paginated reviews
    local reviewData = Whelp.RatingSystem:GetReviewsForVendor(currentVendor.id, currentPage)

    local yOffset = 5
    for _, review in ipairs(reviewData.reviews) do
        local card = self:CreateReviewCard(frame.reviewScrollContent, review)
        card:SetPoint("TOPLEFT", frame.reviewScrollContent, "TOPLEFT", 5, -yOffset)
        yOffset = yOffset + card:GetHeight() + 10
        table.insert(frame.reviewCards, card)
    end

    -- Update content height
    frame.reviewScrollContent:SetHeight(math.max(yOffset, frame.reviewSection:GetHeight() - 50))

    -- Update pagination
    frame.pageText:SetText(string.format("%d / %d", currentPage, math.max(1, reviewData.totalPages)))
    frame.prevBtn:SetEnabled(reviewData.hasPrevPage)
    frame.nextBtn:SetEnabled(reviewData.hasNextPage)

    -- Show empty message if no reviews
    if #reviewData.reviews == 0 then
        if not frame.emptyReviewsText then
            frame.emptyReviewsText = frame.reviewScrollContent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            frame.emptyReviewsText:SetPoint("CENTER", frame.reviewScrollContent, "CENTER", 0, 0)
            frame.emptyReviewsText:SetTextColor(0.5, 0.5, 0.5)
        end
        frame.emptyReviewsText:SetText("No reviews yet.\nBe the first to leave a review!")
        frame.emptyReviewsText:Show()
    else
        if frame.emptyReviewsText then
            frame.emptyReviewsText:Hide()
        end
    end
end

-- Create a review card
function VendorDetail:CreateReviewCard(parent, review)
    local card = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    card:SetSize(parent:GetWidth() - 15, 100)
    card.review = review

    Templates:CreateBackdrop(card, {r = 0.1, g = 0.1, b = 0.1, a = 0.8}, Whelp.Colors.BORDER)

    -- Author name
    local authorText = card:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    authorText:SetPoint("TOPLEFT", card, "TOPLEFT", 10, -10)
    authorText:SetText(review.authorName)
    authorText:SetTextColor(Whelp.Colors.TEXT_HIGHLIGHT.r, Whelp.Colors.TEXT_HIGHLIGHT.g, Whelp.Colors.TEXT_HIGHLIGHT.b)

    -- Rating stars
    local stars = Templates:CreateStarRating(card, review.rating, 12)
    stars:SetPoint("LEFT", authorText, "RIGHT", 10, 0)

    -- Date
    local dateText = card:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    dateText:SetPoint("TOPRIGHT", card, "TOPRIGHT", -10, -10)
    dateText:SetText(Whelp.Utils.FormatRelativeTime(review.timestamp))
    dateText:SetTextColor(0.5, 0.5, 0.5)

    -- Title (if exists)
    local yOffset = -28
    if review.title and review.title ~= "" then
        local titleText = card:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        titleText:SetPoint("TOPLEFT", card, "TOPLEFT", 10, yOffset)
        titleText:SetText(review.title)
        titleText:SetTextColor(1, 1, 1)
        yOffset = yOffset - 16
    end

    -- Content
    local contentText = card:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    contentText:SetPoint("TOPLEFT", card, "TOPLEFT", 10, yOffset)
    contentText:SetPoint("RIGHT", card, "RIGHT", -10, 0)
    contentText:SetJustifyH("LEFT")
    contentText:SetJustifyV("TOP")
    contentText:SetText(review.content)
    contentText:SetTextColor(0.9, 0.9, 0.9)

    -- Calculate card height based on content
    local textHeight = contentText:GetStringHeight()
    local minHeight = 80
    local calculatedHeight = math.abs(yOffset) + textHeight + 20
    card:SetHeight(math.max(minHeight, calculatedHeight))

    -- Helpful button
    local helpfulBtn = CreateFrame("Button", nil, card)
    helpfulBtn:SetSize(60, 18)
    helpfulBtn:SetPoint("BOTTOMLEFT", card, "BOTTOMLEFT", 10, 8)

    local helpfulText = helpfulBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    helpfulText:SetAllPoints()
    helpfulText:SetText(string.format("Helpful (%d)", review.helpful or 0))
    helpfulText:SetTextColor(0.6, 0.6, 0.6)

    helpfulBtn:SetScript("OnEnter", function()
        helpfulText:SetTextColor(1, 0.82, 0)
    end)

    helpfulBtn:SetScript("OnLeave", function()
        helpfulText:SetTextColor(0.6, 0.6, 0.6)
    end)

    helpfulBtn:SetScript("OnClick", function()
        local success, err = Whelp.RatingSystem:MarkHelpful(review.id)
        if success then
            helpfulText:SetText(string.format("Helpful (%d)", (review.helpful or 0) + 1))
        end
    end)

    -- Edit/Delete buttons (if own review)
    local playerName = Whelp.Utils.GetPlayerFullName()
    if review.authorName == playerName then
        local editBtn = Templates:CreateButton(card, "Edit", 50, 18, function()
            Whelp.UI.ReviewForm:Show(currentVendor, review)
        end)
        editBtn:SetPoint("BOTTOMRIGHT", card, "BOTTOMRIGHT", -70, 8)

        local deleteBtn = Templates:CreateButton(card, "Delete", 55, 18, function()
            StaticPopupDialogs["WHELP_CONFIRM_DELETE_REVIEW"] = {
                text = "Are you sure you want to delete this review?",
                button1 = "Delete",
                button2 = "Cancel",
                OnAccept = function()
                    Whelp.RatingSystem:DeleteReview(review.id)
                    VendorDetail:LoadReviews()
                    VendorDetail:UpdateVendorInfo()
                end,
                timeout = 0,
                whileDead = true,
                hideOnEscape = true,
            }
            StaticPopup_Show("WHELP_CONFIRM_DELETE_REVIEW")
        end)
        deleteBtn:SetPoint("BOTTOMRIGHT", card, "BOTTOMRIGHT", -10, 8)
    end

    -- Vendor response (if exists)
    if review.response then
        local responseFrame = CreateFrame("Frame", nil, card, "BackdropTemplate")
        responseFrame:SetPoint("TOPLEFT", card, "BOTTOMLEFT", 10, -5)
        responseFrame:SetPoint("RIGHT", card, "RIGHT", -10, 0)
        responseFrame:SetHeight(50)

        Templates:CreateBackdrop(responseFrame, {r = 0.15, g = 0.15, b = 0.15, a = 0.9}, Whelp.Colors.BORDER)

        local responseLabel = responseFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        responseLabel:SetPoint("TOPLEFT", responseFrame, "TOPLEFT", 8, -5)
        responseLabel:SetText("Vendor Response:")
        responseLabel:SetTextColor(Whelp.Colors.PRIMARY.r, Whelp.Colors.PRIMARY.g, Whelp.Colors.PRIMARY.b)

        local responseText = responseFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        responseText:SetPoint("TOPLEFT", responseLabel, "BOTTOMLEFT", 0, -4)
        responseText:SetPoint("RIGHT", responseFrame, "RIGHT", -8, 0)
        responseText:SetJustifyH("LEFT")
        responseText:SetText(review.response.content)

        -- Adjust card height for response
        card:SetHeight(card:GetHeight() + responseFrame:GetHeight() + 10)
    end

    return card
end

-- Hide the detail frame
function VendorDetail:Hide()
    if frame then
        frame:Hide()
    end
end

-- Check if shown
function VendorDetail:IsShown()
    return frame and frame:IsShown()
end

-- Refresh current view
function VendorDetail:Refresh()
    if currentVendor then
        -- Reload vendor data
        currentVendor = Whelp.Database:GetVendor(currentVendor.id)
        if currentVendor then
            self:UpdateVendorInfo()
            self:LoadReviews()
        end
    end
end
