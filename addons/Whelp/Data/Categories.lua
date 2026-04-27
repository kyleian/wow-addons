--[[
    Whelp - Categories
    Category definitions and management for vendor services
]]

local ADDON_NAME, Whelp = ...

Whelp.CategoryManager = {}
local CategoryManager = Whelp.CategoryManager

-- Get all categories as an ordered list
function CategoryManager:GetAllCategories()
    local categories = {}

    -- Define order
    local order = {
        "profession_package",
        "enchanting",
        "crafting",
        "boost",
        "gold_services",
        "portals",
        "arena",
        "raid",
        "other",
    }

    for _, id in ipairs(order) do
        local category = Whelp.CategoryLookup[id]
        if category then
            table.insert(categories, category)
        end
    end

    return categories
end

-- Get a category by ID
function CategoryManager:GetCategory(categoryId)
    return Whelp.CategoryLookup[categoryId]
end

-- Get category name by ID
function CategoryManager:GetCategoryName(categoryId)
    local category = self:GetCategory(categoryId)
    return category and category.name or "Unknown"
end

-- Get category icon by ID
function CategoryManager:GetCategoryIcon(categoryId)
    local category = self:GetCategory(categoryId)
    return category and category.icon or "Interface\\Icons\\INV_Misc_QuestionMark"
end

-- Get category description by ID
function CategoryManager:GetCategoryDescription(categoryId)
    local category = self:GetCategory(categoryId)
    return category and category.description or ""
end

-- Get vendors by category
function CategoryManager:GetVendorsByCategory(categoryId)
    local allVendors = Whelp.Database:GetVendors()
    local categoryVendors = {}

    for _, vendor in pairs(allVendors) do
        if vendor.category == categoryId then
            table.insert(categoryVendors, vendor)
        end
    end

    return categoryVendors
end

-- Get vendor count per category
function CategoryManager:GetVendorCountByCategory()
    local counts = {}
    local allVendors = Whelp.Database:GetVendors()

    -- Initialize counts
    for _, category in ipairs(self:GetAllCategories()) do
        counts[category.id] = 0
    end

    -- Count vendors
    for _, vendor in pairs(allVendors) do
        if counts[vendor.category] then
            counts[vendor.category] = counts[vendor.category] + 1
        end
    end

    return counts
end

-- Validate category ID
function CategoryManager:IsValidCategory(categoryId)
    return Whelp.CategoryLookup[categoryId] ~= nil
end

-- Get category dropdown options (for UI)
function CategoryManager:GetDropdownOptions()
    local options = {
        {value = "all", text = "All Categories"},
    }

    for _, category in ipairs(self:GetAllCategories()) do
        table.insert(options, {
            value = category.id,
            text = category.name,
            icon = category.icon,
        })
    end

    return options
end

-- Service subcategories for profession packages
CategoryManager.ProfessionSubcategories = {
    {id = "alchemy", name = "Alchemy", icon = "Interface\\Icons\\Trade_Alchemy"},
    {id = "blacksmithing", name = "Blacksmithing", icon = "Interface\\Icons\\Trade_BlackSmithing"},
    {id = "cooking", name = "Cooking", icon = "Interface\\Icons\\INV_Misc_Food_15"},
    {id = "enchanting", name = "Enchanting", icon = "Interface\\Icons\\Trade_Engraving"},
    {id = "engineering", name = "Engineering", icon = "Interface\\Icons\\Trade_Engineering"},
    {id = "first_aid", name = "First Aid", icon = "Interface\\Icons\\Spell_Holy_SealOfSacrifice"},
    {id = "fishing", name = "Fishing", icon = "Interface\\Icons\\Trade_Fishing"},
    {id = "herbalism", name = "Herbalism", icon = "Interface\\Icons\\Trade_Herbalism"},
    {id = "jewelcrafting", name = "Jewelcrafting", icon = "Interface\\Icons\\INV_Misc_Gem_01"},
    {id = "leatherworking", name = "Leatherworking", icon = "Interface\\Icons\\Trade_LeatherWorking"},
    {id = "mining", name = "Mining", icon = "Interface\\Icons\\Trade_Mining"},
    {id = "skinning", name = "Skinning", icon = "Interface\\Icons\\INV_Misc_Pelt_Wolf_01"},
    {id = "tailoring", name = "Tailoring", icon = "Interface\\Icons\\Trade_Tailoring"},
}

-- Get profession subcategories
function CategoryManager:GetProfessionSubcategories()
    return self.ProfessionSubcategories
end

-- Enchanting categories
CategoryManager.EnchantingSubcategories = {
    {id = "weapon", name = "Weapon Enchants", icon = "Interface\\Icons\\INV_Sword_04"},
    {id = "head", name = "Head Enchants", icon = "Interface\\Icons\\INV_Helmet_08"},
    {id = "shoulder", name = "Shoulder Enchants", icon = "Interface\\Icons\\INV_Shoulder_02"},
    {id = "chest", name = "Chest Enchants", icon = "Interface\\Icons\\INV_Chest_Chain"},
    {id = "bracer", name = "Bracer Enchants", icon = "Interface\\Icons\\INV_Bracer_07"},
    {id = "gloves", name = "Glove Enchants", icon = "Interface\\Icons\\INV_Gauntlets_05"},
    {id = "boots", name = "Boot Enchants", icon = "Interface\\Icons\\INV_Boots_05"},
    {id = "cloak", name = "Cloak Enchants", icon = "Interface\\Icons\\INV_Misc_Cape_02"},
    {id = "ring", name = "Ring Enchants", icon = "Interface\\Icons\\INV_Jewelry_Ring_01"},
}

-- Boosting categories
CategoryManager.BoostSubcategories = {
    {id = "dungeon", name = "Dungeon Boosts", icon = "Interface\\Icons\\INV_Misc_Key_07"},
    {id = "leveling", name = "Leveling Boosts", icon = "Interface\\Icons\\Spell_Holy_Crusade"},
    {id = "reputation", name = "Reputation Grinds", icon = "Interface\\Icons\\INV_Misc_Token_ArgentDawn"},
    {id = "attunement", name = "Attunements", icon = "Interface\\Icons\\INV_Misc_Key_13"},
}

-- Get subcategories for a main category
function CategoryManager:GetSubcategories(categoryId)
    if categoryId == "profession_package" then
        return self.ProfessionSubcategories
    elseif categoryId == "enchanting" then
        return self.EnchantingSubcategories
    elseif categoryId == "boost" then
        return self.BoostSubcategories
    end
    return {}
end
