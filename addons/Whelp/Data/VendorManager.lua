--[[
    Whelp - VendorManager
    Handles vendor data operations (CRUD)
]]

local ADDON_NAME, Whelp = ...

Whelp.VendorManager = {}
local VendorManager = Whelp.VendorManager
local Utils = Whelp.Utils
local Database = Whelp.Database
local EventHandler = Whelp.EventHandler
local CategoryManager = Whelp.CategoryManager

-- Vendor data structure template
VendorManager.VendorTemplate = {
    id = nil,              -- Unique identifier
    name = "",             -- Vendor's character name (Name-Realm format)
    category = "other",    -- Service category
    subcategory = nil,     -- Optional subcategory
    description = "",      -- Service description
    services = {},         -- List of specific services offered
    pricing = "",          -- Price information
    faction = "Neutral",   -- Alliance, Horde, or Neutral
    realm = "",            -- Realm name
    createdAt = 0,         -- Creation timestamp
    updatedAt = 0,         -- Last update timestamp
    createdBy = "",        -- Character who added the vendor
    averageRating = 0,     -- Calculated average rating
    reviewCount = 0,       -- Total number of reviews
    lastReviewTime = 0,    -- Timestamp of most recent review
    isVerified = false,    -- Whether vendor has been verified
    contactInfo = "",      -- How to contact (discord, in-game, etc.)
    schedule = "",         -- When they're usually available
}

-- Create a new vendor
function VendorManager:CreateVendor(data)
    -- Validate required fields
    if not data.name or data.name == "" then
        return nil, "Vendor name is required"
    end

    -- Validate name format
    local isValid, validationError = Utils.ValidatePlayerName(data.name)
    if not isValid then
        return nil, validationError
    end

    -- Check if vendor already exists
    local existingVendor = self:FindVendorByName(data.name)
    if existingVendor then
        return nil, "A vendor with this name already exists"
    end

    -- Validate category
    if data.category and not CategoryManager:IsValidCategory(data.category) then
        return nil, "Invalid category"
    end

    -- Create vendor object
    local vendor = Utils.DeepCopy(self.VendorTemplate)
    vendor.id = Utils.GenerateUID()
    vendor.name = data.name
    vendor.category = data.category or "other"
    vendor.subcategory = data.subcategory
    vendor.description = Utils.Trim(data.description or "")
    vendor.services = data.services or {}
    vendor.pricing = Utils.Trim(data.pricing or "")
    vendor.faction = data.faction or Utils.GetPlayerFaction()
    vendor.realm = data.realm or GetRealmName()
    vendor.createdAt = time()
    vendor.updatedAt = time()
    vendor.createdBy = Utils.GetPlayerFullName()
    vendor.contactInfo = Utils.Trim(data.contactInfo or "")
    vendor.schedule = Utils.Trim(data.schedule or "")

    -- Save to database
    local success = Database:SaveVendor(vendor)
    if success then
        EventHandler:FireCustomEvent(EventHandler.CustomEvents.VENDOR_ADDED, vendor)
        Whelp:Debug("Created vendor: " .. vendor.name)
        return vendor, nil
    else
        return nil, "Failed to save vendor"
    end
end

-- Update an existing vendor
function VendorManager:UpdateVendor(vendorId, data)
    local vendor = Database:GetVendor(vendorId)
    if not vendor then
        return nil, "Vendor not found"
    end

    -- Only allow updates to certain fields
    local allowedFields = {
        "category", "subcategory", "description", "services",
        "pricing", "contactInfo", "schedule", "faction"
    }

    for _, field in ipairs(allowedFields) do
        if data[field] ~= nil then
            if field == "description" or field == "pricing" or
               field == "contactInfo" or field == "schedule" then
                vendor[field] = Utils.Trim(data[field])
            else
                vendor[field] = data[field]
            end
        end
    end

    vendor.updatedAt = time()

    -- Save to database
    local success = Database:SaveVendor(vendor)
    if success then
        EventHandler:FireCustomEvent(EventHandler.CustomEvents.VENDOR_UPDATED, vendor)
        Whelp:Debug("Updated vendor: " .. vendor.name)
        return vendor, nil
    else
        return nil, "Failed to update vendor"
    end
end

-- Delete a vendor
function VendorManager:DeleteVendor(vendorId)
    local vendor = Database:GetVendor(vendorId)
    if not vendor then
        return false, "Vendor not found"
    end

    -- Only allow deletion by the creator (or admin in future)
    local currentPlayer = Utils.GetPlayerFullName()
    if vendor.createdBy ~= currentPlayer then
        return false, "You can only delete vendors you created"
    end

    local success = Database:DeleteVendor(vendorId)
    if success then
        EventHandler:FireCustomEvent(EventHandler.CustomEvents.VENDOR_DELETED, vendorId)
        Whelp:Debug("Deleted vendor: " .. vendor.name)
        return true, nil
    else
        return false, "Failed to delete vendor"
    end
end

-- Find vendor by character name
function VendorManager:FindVendorByName(name)
    local vendors = Database:GetVendors()
    local searchName = string.lower(name)

    for _, vendor in pairs(vendors) do
        if string.lower(vendor.name) == searchName then
            return vendor
        end
    end

    return nil
end

-- Search vendors by query
function VendorManager:SearchVendors(query, filters)
    filters = filters or {}
    filters.searchQuery = query

    local vendors = self:GetAllVendorsAsList()
    return Utils.FilterVendors(vendors, filters)
end

-- Get all vendors as a list (sorted)
function VendorManager:GetAllVendorsAsList()
    local vendorsTable = Database:GetVendors()
    local vendorsList = {}

    for _, vendor in pairs(vendorsTable) do
        table.insert(vendorsList, vendor)
    end

    return vendorsList
end

-- Get vendors with filters and sorting
function VendorManager:GetVendors(filters, sortBy, ascending)
    filters = filters or {}
    sortBy = sortBy or "rating"

    local vendors = self:GetAllVendorsAsList()

    -- Apply filters
    if filters.category or filters.minRating or filters.searchQuery or filters.faction then
        vendors = Utils.FilterVendors(vendors, filters)
    end

    -- Exclude blocked vendors
    local finalVendors = {}
    for _, vendor in ipairs(vendors) do
        if not Database:IsBlocked(vendor.id) then
            table.insert(finalVendors, vendor)
        end
    end

    -- Sort
    Utils.SortVendors(finalVendors, sortBy, ascending)

    return finalVendors
end

-- Get top rated vendors
function VendorManager:GetTopRatedVendors(limit, categoryId)
    limit = limit or 10

    local filters = {
        minRating = 1, -- Only vendors with at least one review
    }

    if categoryId and categoryId ~= "all" then
        filters.category = categoryId
    end

    local vendors = self:GetVendors(filters, "rating", false)

    -- Trim to limit
    local topVendors = {}
    for i = 1, math.min(limit, #vendors) do
        table.insert(topVendors, vendors[i])
    end

    return topVendors
end

-- Get recently reviewed vendors
function VendorManager:GetRecentlyReviewedVendors(limit)
    limit = limit or 10

    local vendors = self:GetVendors({}, "recent", false)

    -- Filter to only those with reviews
    local reviewedVendors = {}
    for _, vendor in ipairs(vendors) do
        if vendor.reviewCount and vendor.reviewCount > 0 then
            table.insert(reviewedVendors, vendor)
            if #reviewedVendors >= limit then
                break
            end
        end
    end

    return reviewedVendors
end

-- Get vendors by category
function VendorManager:GetVendorsByCategory(categoryId)
    return self:GetVendors({category = categoryId}, "rating", false)
end

-- Add a service to a vendor
function VendorManager:AddService(vendorId, service)
    local vendor = Database:GetVendor(vendorId)
    if not vendor then
        return false, "Vendor not found"
    end

    if not vendor.services then
        vendor.services = {}
    end

    table.insert(vendor.services, {
        name = service.name,
        description = service.description or "",
        price = service.price or "",
    })

    vendor.updatedAt = time()
    Database:SaveVendor(vendor)

    return true, nil
end

-- Remove a service from a vendor
function VendorManager:RemoveService(vendorId, serviceIndex)
    local vendor = Database:GetVendor(vendorId)
    if not vendor then
        return false, "Vendor not found"
    end

    if not vendor.services or not vendor.services[serviceIndex] then
        return false, "Service not found"
    end

    table.remove(vendor.services, serviceIndex)
    vendor.updatedAt = time()
    Database:SaveVendor(vendor)

    return true, nil
end

-- Check if current player can edit a vendor
function VendorManager:CanEditVendor(vendorId)
    local vendor = Database:GetVendor(vendorId)
    if not vendor then
        return false
    end

    local currentPlayer = Utils.GetPlayerFullName()
    return vendor.createdBy == currentPlayer
end

-- Get vendor statistics
function VendorManager:GetVendorStats(vendorId)
    local vendor = Database:GetVendor(vendorId)
    if not vendor then
        return nil
    end

    local reviews = Database:GetReviewsForVendor(vendorId)

    -- Calculate rating distribution
    local distribution = {0, 0, 0, 0, 0} -- 1-5 stars
    for _, review in ipairs(reviews) do
        local rating = math.floor(review.rating)
        if rating >= 1 and rating <= 5 then
            distribution[rating] = distribution[rating] + 1
        end
    end

    return {
        totalReviews = #reviews,
        averageRating = vendor.averageRating or 0,
        ratingDistribution = distribution,
        newestReviewTime = vendor.lastReviewTime or 0,
        isFavorite = Database:IsFavorite(vendorId),
        createdAt = vendor.createdAt,
    }
end

-- Verify if a target is a potential vendor (for quick add feature)
function VendorManager:CheckTargetAsVendor()
    if not UnitExists("target") or not UnitIsPlayer("target") then
        return nil
    end

    local name, realm = UnitName("target")
    if not name then
        return nil
    end

    realm = realm or GetRealmName()
    local fullName = name .. "-" .. realm:gsub(" ", "")

    -- Check if already a vendor
    local existingVendor = self:FindVendorByName(fullName)

    return {
        name = fullName,
        isExistingVendor = existingVendor ~= nil,
        vendor = existingVendor,
        faction = UnitFactionGroup("target"),
    }
end
