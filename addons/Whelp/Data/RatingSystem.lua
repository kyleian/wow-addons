--[[
    Whelp - RatingSystem
    Handles reviews, ratings, and feedback
]]

local ADDON_NAME, Whelp = ...

Whelp.RatingSystem = {}
local RatingSystem = Whelp.RatingSystem
local Utils = Whelp.Utils
local Database = Whelp.Database
local EventHandler = Whelp.EventHandler

-- Review data structure template
RatingSystem.ReviewTemplate = {
    id = nil,              -- Unique identifier
    vendorId = nil,        -- Associated vendor ID
    authorName = "",       -- Reviewer's character name
    rating = 0,            -- Star rating (1-5)
    title = "",            -- Review title
    content = "",          -- Review text
    timestamp = 0,         -- When review was created
    updatedAt = 0,         -- When review was last updated
    serviceCategory = "",  -- Which service was used
    helpful = 0,           -- Helpful votes count
    reported = false,      -- Whether review has been reported
    response = nil,        -- Vendor's response to review
}

-- Create a new review
function RatingSystem:CreateReview(vendorId, data)
    -- Validate vendor exists
    local vendor = Database:GetVendor(vendorId)
    if not vendor then
        return nil, "Vendor not found"
    end

    -- Validate rating
    local rating = tonumber(data.rating)
    if not rating or rating < Whelp.MIN_RATING or rating > Whelp.MAX_RATING then
        return nil, "Rating must be between " .. Whelp.MIN_RATING .. " and " .. Whelp.MAX_RATING
    end

    -- Check if user already reviewed this vendor
    local hasReviewed, existingReview = Database:HasReviewedVendor(vendorId)
    if hasReviewed then
        return nil, "You have already reviewed this vendor. Edit your existing review instead."
    end

    -- Validate content
    local content = Utils.Trim(data.content or "")
    if content == "" then
        return nil, "Review content is required"
    end

    if string.len(content) > Whelp.MAX_REVIEW_LENGTH then
        return nil, "Review content exceeds maximum length of " .. Whelp.MAX_REVIEW_LENGTH .. " characters"
    end

    -- Create review object
    local review = Utils.DeepCopy(self.ReviewTemplate)
    review.id = Utils.GenerateUID()
    review.vendorId = vendorId
    review.authorName = Utils.GetPlayerFullName()
    review.rating = rating
    review.title = Utils.Trim(data.title or "")
    review.content = content
    review.timestamp = time()
    review.updatedAt = time()
    review.serviceCategory = data.serviceCategory or vendor.category

    -- Save to database
    local success = Database:SaveReview(review)
    if success then
        EventHandler:FireCustomEvent(EventHandler.CustomEvents.REVIEW_ADDED, review)
        Whelp:Debug("Created review for vendor: " .. vendor.name)
        return review, nil
    else
        return nil, "Failed to save review"
    end
end

-- Update an existing review
function RatingSystem:UpdateReview(reviewId, data)
    local review = Database:GetReview(reviewId)
    if not review then
        return nil, "Review not found"
    end

    -- Only author can update
    local currentPlayer = Utils.GetPlayerFullName()
    if review.authorName ~= currentPlayer then
        return nil, "You can only edit your own reviews"
    end

    -- Validate rating if provided
    if data.rating then
        local rating = tonumber(data.rating)
        if not rating or rating < Whelp.MIN_RATING or rating > Whelp.MAX_RATING then
            return nil, "Rating must be between " .. Whelp.MIN_RATING .. " and " .. Whelp.MAX_RATING
        end
        review.rating = rating
    end

    -- Validate content if provided
    if data.content then
        local content = Utils.Trim(data.content)
        if content == "" then
            return nil, "Review content is required"
        end
        if string.len(content) > Whelp.MAX_REVIEW_LENGTH then
            return nil, "Review content exceeds maximum length"
        end
        review.content = content
    end

    -- Update other fields
    if data.title then
        review.title = Utils.Trim(data.title)
    end

    review.updatedAt = time()

    -- Save to database
    local success = Database:SaveReview(review)
    if success then
        -- Recalculate vendor stats
        Database:UpdateVendorStats(review.vendorId)
        EventHandler:FireCustomEvent(EventHandler.CustomEvents.REVIEW_UPDATED, review)
        Whelp:Debug("Updated review: " .. reviewId)
        return review, nil
    else
        return nil, "Failed to update review"
    end
end

-- Delete a review
function RatingSystem:DeleteReview(reviewId)
    local review = Database:GetReview(reviewId)
    if not review then
        return false, "Review not found"
    end

    -- Only author can delete
    local currentPlayer = Utils.GetPlayerFullName()
    if review.authorName ~= currentPlayer then
        return false, "You can only delete your own reviews"
    end

    local vendorId = review.vendorId
    local success = Database:DeleteReview(reviewId)
    if success then
        EventHandler:FireCustomEvent(EventHandler.CustomEvents.REVIEW_DELETED, reviewId, vendorId)
        Whelp:Debug("Deleted review: " .. reviewId)
        return true, nil
    else
        return false, "Failed to delete review"
    end
end

-- Get reviews for a vendor with pagination
function RatingSystem:GetReviewsForVendor(vendorId, page, perPage)
    page = page or 1
    perPage = perPage or Whelp.REVIEWS_PER_PAGE

    local allReviews = Database:GetReviewsForVendor(vendorId)
    local totalReviews = #allReviews
    local totalPages = math.ceil(totalReviews / perPage)

    -- Calculate slice
    local startIndex = ((page - 1) * perPage) + 1
    local endIndex = math.min(startIndex + perPage - 1, totalReviews)

    local reviews = {}
    for i = startIndex, endIndex do
        table.insert(reviews, allReviews[i])
    end

    return {
        reviews = reviews,
        page = page,
        perPage = perPage,
        totalReviews = totalReviews,
        totalPages = totalPages,
        hasNextPage = page < totalPages,
        hasPrevPage = page > 1,
    }
end

-- Get reviews by a specific author
function RatingSystem:GetReviewsByAuthor(authorName)
    local allReviews = Database:GetReviews()
    local authorReviews = {}

    for _, review in pairs(allReviews) do
        if review.authorName == authorName then
            table.insert(authorReviews, review)
        end
    end

    -- Sort by timestamp (newest first)
    table.sort(authorReviews, function(a, b)
        return (a.timestamp or 0) > (b.timestamp or 0)
    end)

    return authorReviews
end

-- Get current player's reviews
function RatingSystem:GetMyReviews()
    return self:GetReviewsByAuthor(Utils.GetPlayerFullName())
end

-- Mark a review as helpful
function RatingSystem:MarkHelpful(reviewId)
    local review = Database:GetReview(reviewId)
    if not review then
        return false, "Review not found"
    end

    -- Can't mark own review as helpful
    local currentPlayer = Utils.GetPlayerFullName()
    if review.authorName == currentPlayer then
        return false, "You cannot mark your own review as helpful"
    end

    review.helpful = (review.helpful or 0) + 1
    Database:SaveReview(review)

    return true, nil
end

-- Report a review
function RatingSystem:ReportReview(reviewId, reason)
    local review = Database:GetReview(reviewId)
    if not review then
        return false, "Review not found"
    end

    review.reported = true
    review.reportReason = reason
    review.reportedBy = Utils.GetPlayerFullName()
    review.reportedAt = time()

    Database:SaveReview(review)
    Whelp:Print("Review has been reported. Thank you for your feedback.")

    return true, nil
end

-- Get rating statistics for a vendor
function RatingSystem:GetRatingStats(vendorId)
    local reviews = Database:GetReviewsForVendor(vendorId)

    if #reviews == 0 then
        return {
            averageRating = 0,
            totalReviews = 0,
            distribution = {0, 0, 0, 0, 0},
            percentages = {0, 0, 0, 0, 0},
        }
    end

    local distribution = {0, 0, 0, 0, 0}
    local totalRating = 0

    for _, review in ipairs(reviews) do
        local rating = math.floor(review.rating)
        if rating >= 1 and rating <= 5 then
            distribution[rating] = distribution[rating] + 1
        end
        totalRating = totalRating + review.rating
    end

    local percentages = {}
    for i = 1, 5 do
        percentages[i] = math.floor((distribution[i] / #reviews) * 100)
    end

    return {
        averageRating = totalRating / #reviews,
        totalReviews = #reviews,
        distribution = distribution,
        percentages = percentages,
    }
end

-- Add vendor response to a review
function RatingSystem:AddVendorResponse(reviewId, response)
    local review = Database:GetReview(reviewId)
    if not review then
        return false, "Review not found"
    end

    -- Get vendor to check if current player is the vendor
    local vendor = Database:GetVendor(review.vendorId)
    if not vendor then
        return false, "Vendor not found"
    end

    local currentPlayer = Utils.GetPlayerFullName()
    if vendor.name ~= currentPlayer then
        return false, "Only the vendor can respond to reviews"
    end

    response = Utils.Trim(response)
    if response == "" then
        return false, "Response cannot be empty"
    end

    review.response = {
        content = response,
        timestamp = time(),
    }

    Database:SaveReview(review)

    return true, nil
end

-- Calculate weighted rating (considers number of reviews)
function RatingSystem:CalculateWeightedRating(averageRating, reviewCount)
    -- Wilson score confidence interval for ranking
    -- This helps balance between high-rated vendors with few reviews
    -- and slightly lower-rated vendors with many reviews

    if reviewCount == 0 then
        return 0
    end

    -- Constants
    local z = 1.96 -- 95% confidence
    local n = reviewCount
    local phat = averageRating / 5 -- Normalize to 0-1

    -- Wilson score lower bound
    local lower = (phat + z*z/(2*n) - z * math.sqrt((phat*(1-phat)+z*z/(4*n))/n)) / (1+z*z/n)

    -- Return as 0-5 scale
    return lower * 5
end

-- Get trending vendors (high activity + good ratings recently)
function RatingSystem:GetTrendingVendors(limit, days)
    limit = limit or 10
    days = days or 7

    local cutoffTime = time() - (days * 86400)
    local allVendors = Whelp.VendorManager:GetAllVendorsAsList()
    local trending = {}

    for _, vendor in ipairs(allVendors) do
        local reviews = Database:GetReviewsForVendor(vendor.id)
        local recentReviews = 0
        local recentRatingSum = 0

        for _, review in ipairs(reviews) do
            if review.timestamp >= cutoffTime then
                recentReviews = recentReviews + 1
                recentRatingSum = recentRatingSum + review.rating
            end
        end

        if recentReviews > 0 then
            table.insert(trending, {
                vendor = vendor,
                recentReviews = recentReviews,
                recentAverage = recentRatingSum / recentReviews,
                trendScore = recentReviews * (recentRatingSum / recentReviews),
            })
        end
    end

    -- Sort by trend score
    table.sort(trending, function(a, b)
        return a.trendScore > b.trendScore
    end)

    -- Extract vendors
    local result = {}
    for i = 1, math.min(limit, #trending) do
        table.insert(result, trending[i].vendor)
    end

    return result
end
