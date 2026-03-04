--[[
    Whelp - ReviewForm
    Form for creating and editing reviews
]]

local ADDON_NAME, Whelp = ...

Whelp.UI = Whelp.UI or {}
Whelp.UI.ReviewForm = {}
local ReviewForm = Whelp.UI.ReviewForm
local Templates = Whelp.UI.Templates

local frame = nil
local currentVendor = nil
local currentReview = nil
local isEditing = false

-- Create the review form
function ReviewForm:Create()
    if frame then return frame end

    frame = CreateFrame("Frame", "WhelpReviewFormFrame", UIParent, "BackdropTemplate")
    frame:SetSize(Whelp.UI.REVIEW_FORM_WIDTH, Whelp.UI.REVIEW_FORM_HEIGHT)
    frame:SetPoint("CENTER")
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    frame:SetFrameStrata("DIALOG")
    frame:SetFrameLevel(100)
    frame:EnableMouse(true)

    Templates:CreateBackdrop(frame, Whelp.Colors.BACKGROUND, Whelp.Colors.BORDER)

    -- Title bar
    local titleBar, titleText = Templates:CreateTitleBar(frame, "Write Review", true)
    frame.titleText = titleText

    -- Close button
    Templates:CreateCloseButton(frame, function()
        self:Hide()
    end)

    -- Content
    local yOffset = -40

    -- Vendor name display
    local vendorLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    vendorLabel:SetPoint("TOPLEFT", frame, "TOPLEFT", 15, yOffset)
    vendorLabel:SetText("Reviewing:")
    vendorLabel:SetTextColor(0.6, 0.6, 0.6)

    local vendorName = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    vendorName:SetPoint("TOPLEFT", vendorLabel, "BOTTOMLEFT", 0, -4)
    vendorName:SetTextColor(1, 1, 1)
    frame.vendorNameText = vendorName
    yOffset = yOffset - 45

    -- Rating
    local ratingLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    ratingLabel:SetPoint("TOPLEFT", frame, "TOPLEFT", 15, yOffset)
    ratingLabel:SetText("Your Rating:")

    local ratingStars = Templates:CreateStarRating(frame, 0, 24, true)
    ratingStars:SetPoint("TOPLEFT", ratingLabel, "BOTTOMLEFT", 0, -8)
    frame.ratingStars = ratingStars

    local ratingHint = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    ratingHint:SetPoint("LEFT", ratingStars, "RIGHT", 10, 0)
    ratingHint:SetText("Click a star to rate")
    ratingHint:SetTextColor(0.5, 0.5, 0.5)
    frame.ratingHint = ratingHint

    ratingStars.OnRatingChanged = function(_, rating)
        local hints = {
            "Terrible experience",
            "Poor service",
            "Average",
            "Good service",
            "Excellent!",
        }
        ratingHint:SetText(hints[rating] or "")
    end
    yOffset = yOffset - 60

    -- Title input (optional)
    local titleLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    titleLabel:SetPoint("TOPLEFT", frame, "TOPLEFT", 15, yOffset)
    titleLabel:SetText("Title (optional):")

    local titleInput = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
    titleInput:SetSize(frame:GetWidth() - 45, 24)
    titleInput:SetPoint("TOPLEFT", titleLabel, "BOTTOMLEFT", 5, -4)
    titleInput:SetAutoFocus(false)
    titleInput:SetMaxLetters(100)
    frame.titleInput = titleInput
    yOffset = yOffset - 55

    -- Content input
    local contentLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    contentLabel:SetPoint("TOPLEFT", frame, "TOPLEFT", 15, yOffset)
    contentLabel:SetText("Your Review:")

    local charCount = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    charCount:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -15, yOffset)
    charCount:SetTextColor(0.5, 0.5, 0.5)
    frame.charCount = charCount

    local contentScroll, contentInput = Templates:CreateEditBox(frame, frame:GetWidth() - 45, 100, true)
    contentScroll:SetPoint("TOPLEFT", contentLabel, "BOTTOMLEFT", 5, -4)
    frame.contentInput = contentInput
    frame.contentScroll = contentScroll

    contentInput:SetScript("OnTextChanged", function(self)
        local text = self:GetText()
        local len = string.len(text)
        charCount:SetText(len .. "/" .. Whelp.MAX_REVIEW_LENGTH)

        if len > Whelp.MAX_REVIEW_LENGTH then
            charCount:SetTextColor(1, 0.2, 0.2)
        else
            charCount:SetTextColor(0.5, 0.5, 0.5)
        end
    end)

    yOffset = yOffset - 130

    -- Buttons
    local submitBtn = Templates:CreateButton(frame, "Submit Review", 120, 28, function()
        self:SubmitReview()
    end)
    submitBtn:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 15, 15)
    frame.submitBtn = submitBtn

    local cancelBtn = Templates:CreateButton(frame, "Cancel", 80, 28, function()
        self:Hide()
    end)
    cancelBtn:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -15, 15)

    frame:Hide()
    tinsert(UISpecialFrames, "WhelpReviewFormFrame")

    return frame
end

-- Show the review form
function ReviewForm:Show(vendor, existingReview)
    if not frame then
        self:Create()
    end

    currentVendor = vendor
    currentReview = existingReview
    isEditing = existingReview ~= nil

    -- Update title
    frame.titleText:SetText("|cff" .. Whelp.Colors.PRIMARY_HEX .. "Whelp|r - " ..
        (isEditing and "Edit Review" or "Write Review"))

    -- Set vendor name
    frame.vendorNameText:SetText(vendor.name)

    -- Pre-populate if editing
    if isEditing and existingReview then
        frame.ratingStars:SetRating(existingReview.rating)
        frame.titleInput:SetText(existingReview.title or "")
        frame.contentInput:SetText(existingReview.content or "")
        frame.submitBtn:SetText("Update Review")

        local hints = {
            "Terrible experience",
            "Poor service",
            "Average",
            "Good service",
            "Excellent!",
        }
        frame.ratingHint:SetText(hints[existingReview.rating] or "")
    else
        frame.ratingStars:SetRating(0)
        frame.titleInput:SetText("")
        frame.contentInput:SetText("")
        frame.submitBtn:SetText("Submit Review")
        frame.ratingHint:SetText("Click a star to rate")
    end

    -- Update character count
    local len = string.len(frame.contentInput:GetText())
    frame.charCount:SetText(len .. "/" .. Whelp.MAX_REVIEW_LENGTH)

    frame:Show()
end

-- Submit the review
function ReviewForm:SubmitReview()
    local rating = frame.ratingStars.rating
    local title = frame.titleInput:GetText()
    local content = frame.contentInput:GetText()

    -- Validation
    if rating == 0 then
        Whelp:Print("Please select a rating.")
        return
    end

    if Whelp.Utils.Trim(content) == "" then
        Whelp:Print("Please write a review.")
        return
    end

    if string.len(content) > Whelp.MAX_REVIEW_LENGTH then
        Whelp:Print("Review is too long. Maximum " .. Whelp.MAX_REVIEW_LENGTH .. " characters.")
        return
    end

    local success, result

    if isEditing and currentReview then
        -- Update existing review
        result, success = Whelp.RatingSystem:UpdateReview(currentReview.id, {
            rating = rating,
            title = title,
            content = content,
        })

        if result then
            Whelp:Print("Review updated successfully!")
        else
            Whelp:Print("Error: " .. (success or "Failed to update review"))
            return
        end
    else
        -- Create new review
        result, success = Whelp.RatingSystem:CreateReview(currentVendor.id, {
            rating = rating,
            title = title,
            content = content,
        })

        if result then
            Whelp:Print("Review submitted successfully!")
        else
            Whelp:Print("Error: " .. (success or "Failed to submit review"))
            return
        end
    end

    -- Close form
    self:Hide()

    -- Refresh vendor detail if open
    if Whelp.UI.VendorDetail:IsShown() then
        Whelp.UI.VendorDetail:Refresh()
    end

    -- Refresh main frame if open
    if Whelp.UI.MainFrame:IsShown() then
        Whelp.UI.MainFrame:RefreshContent()
    end
end

-- Hide the review form
function ReviewForm:Hide()
    if frame then
        frame:Hide()
    end
    currentVendor = nil
    currentReview = nil
    isEditing = false
end

-- Check if shown
function ReviewForm:IsShown()
    return frame and frame:IsShown()
end
