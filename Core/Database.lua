--[[
    Whelp - Database
    SavedVariables management and data persistence
]]

local ADDON_NAME, Whelp = ...

Whelp.Database = {}
local Database = Whelp.Database
local Utils = Whelp.Utils

-- Initialize the database with defaults
function Database:Initialize()
    -- Initialize global database
    if not WhelpDB then
        WhelpDB = Utils.DeepCopy(Whelp.DefaultDB)
        Whelp:Debug("Created new global database")
    else
        -- Merge with defaults to add any new fields
        WhelpDB = Utils.MergeTables(Utils.DeepCopy(Whelp.DefaultDB), WhelpDB)
        Whelp:Debug("Loaded existing global database")
    end

    -- Initialize character database
    if not WhelpCharDB then
        WhelpCharDB = Utils.DeepCopy(Whelp.DefaultCharDB)
        Whelp:Debug("Created new character database")
    else
        WhelpCharDB = Utils.MergeTables(Utils.DeepCopy(Whelp.DefaultCharDB), WhelpCharDB)
        Whelp:Debug("Loaded existing character database")
    end

    -- Check for database version migration
    self:MigrateDatabase()

    -- Create easy references
    Whelp.db = WhelpDB
    Whelp.charDb = WhelpCharDB

    Whelp:Debug("Database initialized successfully")
end

-- Migrate database if version has changed
function Database:MigrateDatabase()
    local currentVersion = WhelpDB.dbVersion or 0

    if currentVersion < Whelp.DB_VERSION then
        Whelp:Debug("Migrating database from version " .. currentVersion .. " to " .. Whelp.DB_VERSION)

        -- Version 1 migration (initial)
        if currentVersion < 1 then
            -- Ensure all required tables exist
            WhelpDB.global = WhelpDB.global or {}
            WhelpDB.global.vendors = WhelpDB.global.vendors or {}
            WhelpDB.global.reviews = WhelpDB.global.reviews or {}
            WhelpDB.profile = WhelpDB.profile or {}
        end

        -- Add future migrations here
        -- if currentVersion < 2 then ... end

        WhelpDB.dbVersion = Whelp.DB_VERSION
        Whelp:Print("Database migrated to version " .. Whelp.DB_VERSION)
    end
end

-- Get a value from the global database
function Database:GetGlobal(key)
    return WhelpDB.global[key]
end

-- Set a value in the global database
function Database:SetGlobal(key, value)
    WhelpDB.global[key] = value
end

-- Get a value from the profile database
function Database:GetProfile(key)
    return WhelpDB.profile[key]
end

-- Set a value in the profile database
function Database:SetProfile(key, value)
    WhelpDB.profile[key] = value
end

-- Get a value from the character database
function Database:GetChar(key)
    return WhelpCharDB[key]
end

-- Set a value in the character database
function Database:SetChar(key, value)
    WhelpCharDB[key] = value
end

-- Get all vendors
function Database:GetVendors()
    return WhelpDB.global.vendors or {}
end

-- Get a specific vendor by ID
function Database:GetVendor(vendorId)
    return WhelpDB.global.vendors[vendorId]
end

-- Save a vendor
function Database:SaveVendor(vendor)
    if not vendor or not vendor.id then
        Whelp:Debug("Cannot save vendor: missing ID")
        return false
    end

    WhelpDB.global.vendors[vendor.id] = vendor
    Whelp:Debug("Saved vendor: " .. vendor.name)
    return true
end

-- Delete a vendor
function Database:DeleteVendor(vendorId)
    if not vendorId then return false end

    local vendor = WhelpDB.global.vendors[vendorId]
    if vendor then
        WhelpDB.global.vendors[vendorId] = nil
        -- Also delete associated reviews
        self:DeleteReviewsForVendor(vendorId)
        Whelp:Debug("Deleted vendor: " .. vendorId)
        return true
    end
    return false
end

-- Get all reviews
function Database:GetReviews()
    return WhelpDB.global.reviews or {}
end

-- Get reviews for a specific vendor
function Database:GetReviewsForVendor(vendorId)
    local allReviews = self:GetReviews()
    local vendorReviews = {}

    for reviewId, review in pairs(allReviews) do
        if review.vendorId == vendorId then
            review.id = reviewId
            table.insert(vendorReviews, review)
        end
    end

    -- Sort by timestamp (newest first)
    table.sort(vendorReviews, function(a, b)
        return (a.timestamp or 0) > (b.timestamp or 0)
    end)

    return vendorReviews
end

-- Get a specific review by ID
function Database:GetReview(reviewId)
    return WhelpDB.global.reviews[reviewId]
end

-- Save a review
function Database:SaveReview(review)
    if not review or not review.id then
        Whelp:Debug("Cannot save review: missing ID")
        return false
    end

    WhelpDB.global.reviews[review.id] = review

    -- Track in character's reviews
    WhelpCharDB.myReviews[review.id] = true

    -- Update vendor's average rating and review count
    self:UpdateVendorStats(review.vendorId)

    Whelp:Debug("Saved review: " .. review.id)
    return true
end

-- Delete a review
function Database:DeleteReview(reviewId)
    if not reviewId then return false end

    local review = WhelpDB.global.reviews[reviewId]
    if review then
        local vendorId = review.vendorId
        WhelpDB.global.reviews[reviewId] = nil
        WhelpCharDB.myReviews[reviewId] = nil

        -- Update vendor stats
        self:UpdateVendorStats(vendorId)

        Whelp:Debug("Deleted review: " .. reviewId)
        return true
    end
    return false
end

-- Delete all reviews for a vendor
function Database:DeleteReviewsForVendor(vendorId)
    local reviews = self:GetReviewsForVendor(vendorId)
    for _, review in ipairs(reviews) do
        WhelpDB.global.reviews[review.id] = nil
        WhelpCharDB.myReviews[review.id] = nil
    end
end

-- Update a vendor's statistics (average rating, review count, etc.)
function Database:UpdateVendorStats(vendorId)
    local vendor = self:GetVendor(vendorId)
    if not vendor then return end

    local reviews = self:GetReviewsForVendor(vendorId)
    local totalRating = 0
    local latestTime = 0

    for _, review in ipairs(reviews) do
        totalRating = totalRating + (review.rating or 0)
        if (review.timestamp or 0) > latestTime then
            latestTime = review.timestamp
        end
    end

    vendor.reviewCount = #reviews
    vendor.averageRating = #reviews > 0 and (totalRating / #reviews) or 0
    vendor.lastReviewTime = latestTime

    self:SaveVendor(vendor)
end

-- Check if the current player has reviewed a vendor
function Database:HasReviewedVendor(vendorId)
    local playerName = Utils.GetPlayerFullName()
    local reviews = self:GetReviewsForVendor(vendorId)

    for _, review in ipairs(reviews) do
        if review.authorName == playerName then
            return true, review
        end
    end
    return false, nil
end

-- Get player's review for a vendor
function Database:GetPlayerReviewForVendor(vendorId)
    local _, review = self:HasReviewedVendor(vendorId)
    return review
end

-- Favorites management
function Database:AddFavorite(vendorId)
    WhelpCharDB.favorites[vendorId] = true
end

function Database:RemoveFavorite(vendorId)
    WhelpCharDB.favorites[vendorId] = nil
end

function Database:IsFavorite(vendorId)
    return WhelpCharDB.favorites[vendorId] == true
end

function Database:GetFavorites()
    local favorites = {}
    for vendorId, _ in pairs(WhelpCharDB.favorites) do
        local vendor = self:GetVendor(vendorId)
        if vendor then
            table.insert(favorites, vendor)
        end
    end
    return favorites
end

-- Recently viewed management
function Database:AddRecentlyViewed(vendorId)
    -- Remove if already exists
    for i, id in ipairs(WhelpCharDB.recentlyViewed) do
        if id == vendorId then
            table.remove(WhelpCharDB.recentlyViewed, i)
            break
        end
    end

    -- Add to front
    table.insert(WhelpCharDB.recentlyViewed, 1, vendorId)

    -- Keep only last 20
    while #WhelpCharDB.recentlyViewed > 20 do
        table.remove(WhelpCharDB.recentlyViewed)
    end
end

function Database:GetRecentlyViewed()
    local recent = {}
    for _, vendorId in ipairs(WhelpCharDB.recentlyViewed) do
        local vendor = self:GetVendor(vendorId)
        if vendor then
            table.insert(recent, vendor)
        end
    end
    return recent
end

-- Block list management
function Database:BlockVendor(vendorId)
    WhelpCharDB.blockedVendors[vendorId] = true
end

function Database:UnblockVendor(vendorId)
    WhelpCharDB.blockedVendors[vendorId] = nil
end

function Database:IsBlocked(vendorId)
    return WhelpCharDB.blockedVendors[vendorId] == true
end

-- Get vendor count
function Database:GetVendorCount()
    local count = 0
    for _ in pairs(WhelpDB.global.vendors) do
        count = count + 1
    end
    return count
end

-- Get review count
function Database:GetReviewCount()
    local count = 0
    for _ in pairs(WhelpDB.global.reviews) do
        count = count + 1
    end
    return count
end

-- Export data (for sharing/backup)
function Database:ExportData()
    local exportData = {
        version = Whelp.DB_VERSION,
        timestamp = time(),
        vendors = WhelpDB.global.vendors,
        reviews = WhelpDB.global.reviews,
    }
    -- In a real implementation, you'd serialize this to a string
    return exportData
end

-- Import data
function Database:ImportData(data)
    if not data or not data.version then
        return false, "Invalid import data"
    end

    if data.version > Whelp.DB_VERSION then
        return false, "Import data is from a newer version"
    end

    -- Merge vendors
    for id, vendor in pairs(data.vendors or {}) do
        if not WhelpDB.global.vendors[id] then
            WhelpDB.global.vendors[id] = vendor
        end
    end

    -- Merge reviews
    for id, review in pairs(data.reviews or {}) do
        if not WhelpDB.global.reviews[id] then
            WhelpDB.global.reviews[id] = review
        end
    end

    -- Recalculate all vendor stats
    for vendorId in pairs(WhelpDB.global.vendors) do
        self:UpdateVendorStats(vendorId)
    end

    return true, "Import successful"
end

-- Clear all data (use with caution!)
function Database:ClearAllData()
    WhelpDB = Utils.DeepCopy(Whelp.DefaultDB)
    WhelpCharDB = Utils.DeepCopy(Whelp.DefaultCharDB)
    Whelp.db = WhelpDB
    Whelp.charDb = WhelpCharDB
    Whelp:Print("All data has been cleared.")
end
