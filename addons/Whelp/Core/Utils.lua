--[[
    Whelp - Utils
    Utility functions used throughout the addon
]]

local ADDON_NAME, Whelp = ...

Whelp.Utils = {}
local Utils = Whelp.Utils

-- Deep copy a table
function Utils.DeepCopy(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in next, orig, nil do
            copy[Utils.DeepCopy(orig_key)] = Utils.DeepCopy(orig_value)
        end
        setmetatable(copy, Utils.DeepCopy(getmetatable(orig)))
    else
        copy = orig
    end
    return copy
end

-- Merge two tables (second overwrites first)
function Utils.MergeTables(t1, t2)
    for k, v in pairs(t2) do
        if type(v) == "table" and type(t1[k]) == "table" then
            Utils.MergeTables(t1[k], v)
        else
            t1[k] = v
        end
    end
    return t1
end

-- Generate a unique ID
function Utils.GenerateUID()
    local timestamp = time()
    local random = math.random(100000, 999999)
    return string.format("%d_%d", timestamp, random)
end

-- Format a timestamp into a readable date
function Utils.FormatDate(timestamp)
    if not timestamp or timestamp == 0 then
        return "Unknown"
    end
    return date("%Y-%m-%d %H:%M", timestamp)
end

-- Format a timestamp into relative time (e.g., "2 days ago")
function Utils.FormatRelativeTime(timestamp)
    if not timestamp or timestamp == 0 then
        return "Unknown"
    end

    local diff = time() - timestamp

    if diff < 60 then
        return "Just now"
    elseif diff < 3600 then
        local minutes = math.floor(diff / 60)
        return minutes == 1 and "1 minute ago" or minutes .. " minutes ago"
    elseif diff < 86400 then
        local hours = math.floor(diff / 3600)
        return hours == 1 and "1 hour ago" or hours .. " hours ago"
    elseif diff < 604800 then
        local days = math.floor(diff / 86400)
        return days == 1 and "1 day ago" or days .. " days ago"
    elseif diff < 2592000 then
        local weeks = math.floor(diff / 604800)
        return weeks == 1 and "1 week ago" or weeks .. " weeks ago"
    elseif diff < 31536000 then
        local months = math.floor(diff / 2592000)
        return months == 1 and "1 month ago" or months .. " months ago"
    else
        local years = math.floor(diff / 31536000)
        return years == 1 and "1 year ago" or years .. " years ago"
    end
end

-- Format a rating number to display with one decimal place
function Utils.FormatRating(rating)
    if not rating or rating == 0 then
        return "N/A"
    end
    return string.format("%.1f", rating)
end

-- Get color for a rating value
function Utils.GetRatingColor(rating)
    if not rating or rating == 0 then
        return Whelp.Colors.TEXT_DISABLED
    elseif rating >= 4.5 then
        return Whelp.Colors.RATING_EXCELLENT
    elseif rating >= 3.5 then
        return Whelp.Colors.RATING_GOOD
    elseif rating >= 2.5 then
        return Whelp.Colors.RATING_AVERAGE
    elseif rating >= 1.5 then
        return Whelp.Colors.RATING_POOR
    else
        return Whelp.Colors.RATING_TERRIBLE
    end
end

-- Get colored rating text
function Utils.GetColoredRating(rating)
    local color = Utils.GetRatingColor(rating)
    local ratingText = Utils.FormatRating(rating)
    return string.format("|cff%02x%02x%02x%s|r",
        color.r * 255, color.g * 255, color.b * 255, ratingText)
end

-- Truncate text with ellipsis
function Utils.TruncateText(text, maxLength)
    if not text then return "" end
    if string.len(text) <= maxLength then
        return text
    end
    return string.sub(text, 1, maxLength - 3) .. "..."
end

-- Escape special characters for pattern matching
function Utils.EscapePattern(text)
    return text:gsub("([%%%^%$%(%)%.%[%]%*%+%-%?])", "%%%1")
end

-- Case-insensitive string search
function Utils.StringContains(haystack, needle)
    if not haystack or not needle then return false end
    return string.find(string.lower(haystack), string.lower(needle), 1, true) ~= nil
end

-- Split a string by delimiter
function Utils.SplitString(str, delimiter)
    local result = {}
    local pattern = string.format("([^%s]+)", delimiter)
    for match in string.gmatch(str, pattern) do
        table.insert(result, match)
    end
    return result
end

-- Trim whitespace from string
function Utils.Trim(str)
    if not str then return "" end
    return str:match("^%s*(.-)%s*$")
end

-- Validate a player name (Name-Realm format)
function Utils.ValidatePlayerName(name)
    if not name or name == "" then
        return false, "Name cannot be empty"
    end

    -- Check for Name-Realm format
    local playerName, realm = strsplit("-", name)

    if not playerName or playerName == "" then
        return false, "Invalid player name"
    end

    -- Check name length
    if string.len(playerName) < 2 or string.len(playerName) > 12 then
        return false, "Player name must be 2-12 characters"
    end

    -- Check for valid characters (letters only, first letter capitalized)
    if not playerName:match("^%u%l+$") then
        return false, "Player name must start with capital letter followed by lowercase letters"
    end

    return true, nil
end

-- Get current player's full name (Name-Realm)
function Utils.GetPlayerFullName()
    local name = UnitName("player")
    local realm = GetRealmName():gsub(" ", "")
    return name .. "-" .. realm
end

-- Get faction of current player
function Utils.GetPlayerFaction()
    local faction = UnitFactionGroup("player")
    return faction
end

-- Check if a unit is online
function Utils.IsPlayerOnline(name)
    -- This is a simple implementation; could be expanded with guild/friends check
    local friendInfo = C_FriendList and C_FriendList.GetFriendInfo(name)
    if friendInfo then
        return friendInfo.connected
    end
    return nil -- Unknown
end

-- Calculate average rating from a list of reviews
function Utils.CalculateAverageRating(reviews)
    if not reviews or #reviews == 0 then
        return 0
    end

    local total = 0
    for _, review in ipairs(reviews) do
        total = total + (review.rating or 0)
    end

    return total / #reviews
end

-- Sort vendors by various criteria
function Utils.SortVendors(vendors, sortBy, ascending)
    ascending = ascending or false

    local sortFunctions = {
        rating = function(a, b)
            local ratingA = a.averageRating or 0
            local ratingB = b.averageRating or 0
            if ascending then
                return ratingA < ratingB
            else
                return ratingA > ratingB
            end
        end,
        recent = function(a, b)
            local timeA = a.lastReviewTime or 0
            local timeB = b.lastReviewTime or 0
            if ascending then
                return timeA < timeB
            else
                return timeA > timeB
            end
        end,
        reviews = function(a, b)
            local countA = a.reviewCount or 0
            local countB = b.reviewCount or 0
            if ascending then
                return countA < countB
            else
                return countA > countB
            end
        end,
        name = function(a, b)
            local nameA = a.name or ""
            local nameB = b.name or ""
            if ascending then
                return nameA < nameB
            else
                return nameA > nameB
            end
        end,
    }

    local sortFunc = sortFunctions[sortBy] or sortFunctions.rating
    table.sort(vendors, sortFunc)

    return vendors
end

-- Filter vendors by criteria
function Utils.FilterVendors(vendors, filters)
    local filtered = {}

    for _, vendor in ipairs(vendors) do
        local include = true

        -- Filter by category
        if filters.category and filters.category ~= "all" then
            if vendor.category ~= filters.category then
                include = false
            end
        end

        -- Filter by minimum rating
        if filters.minRating and filters.minRating > 0 then
            if (vendor.averageRating or 0) < filters.minRating then
                include = false
            end
        end

        -- Filter by search query
        if filters.searchQuery and filters.searchQuery ~= "" then
            local query = string.lower(filters.searchQuery)
            local nameMatch = Utils.StringContains(vendor.name, query)
            local descMatch = Utils.StringContains(vendor.description, query)
            if not nameMatch and not descMatch then
                include = false
            end
        end

        -- Filter by faction
        if filters.faction then
            if vendor.faction ~= filters.faction and vendor.faction ~= "Neutral" then
                include = false
            end
        end

        if include then
            table.insert(filtered, vendor)
        end
    end

    return filtered
end

-- Create a simple hash of a string (for validation purposes)
function Utils.SimpleHash(str)
    local hash = 0
    for i = 1, string.len(str) do
        hash = ((hash * 31) + string.byte(str, i)) % 2147483647
    end
    return hash
end

-- Safely call a function with error handling
function Utils.SafeCall(func, ...)
    local success, result = pcall(func, ...)
    if not success then
        Whelp:Debug("Error in SafeCall: " .. tostring(result))
        return nil
    end
    return result
end
