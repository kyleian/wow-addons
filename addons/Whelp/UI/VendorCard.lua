--[[
    Whelp - VendorCard
    A compact card showing vendor summary information
]]

local ADDON_NAME, Whelp = ...

Whelp.UI = Whelp.UI or {}
Whelp.UI.VendorCard = {}
local VendorCard = Whelp.UI.VendorCard
local Templates = Whelp.UI.Templates

-- Create a vendor card
function VendorCard:Create(parent, vendor)
    local card = CreateFrame("Button", nil, parent, "BackdropTemplate")
    card:SetSize(Whelp.UI.VENDOR_CARD_WIDTH, Whelp.UI.VENDOR_CARD_HEIGHT)
    card.vendor = vendor

    Templates:CreateBackdrop(card, {r = 0.12, g = 0.12, b = 0.12, a = 0.95}, Whelp.Colors.BORDER)

    -- Category icon
    local category = Whelp.CategoryManager:GetCategory(vendor.category)
    local categoryIcon = card:CreateTexture(nil, "ARTWORK")
    categoryIcon:SetSize(36, 36)
    categoryIcon:SetPoint("TOPLEFT", card, "TOPLEFT", 8, -8)
    categoryIcon:SetTexture(category and category.icon or "Interface\\Icons\\INV_Misc_QuestionMark")

    -- Vendor name
    local nameText = card:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    nameText:SetPoint("TOPLEFT", categoryIcon, "TOPRIGHT", 8, -2)
    nameText:SetPoint("RIGHT", card, "RIGHT", -40, 0)
    nameText:SetJustifyH("LEFT")
    nameText:SetText(Whelp.Utils.TruncateText(vendor.name, 25))
    nameText:SetTextColor(1, 1, 1)
    card.nameText = nameText

    -- Star rating
    local stars = Templates:CreateStarRating(card, vendor.averageRating or 0, 12)
    stars:SetPoint("TOPLEFT", nameText, "BOTTOMLEFT", 0, -4)

    -- Rating text
    local ratingText = card:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    ratingText:SetPoint("LEFT", stars, "RIGHT", 6, 0)
    local ratingColor = Whelp.Utils.GetRatingColor(vendor.averageRating)
    ratingText:SetText(string.format("%.1f", vendor.averageRating or 0))
    ratingText:SetTextColor(ratingColor.r, ratingColor.g, ratingColor.b)

    -- Review count
    local reviewCount = card:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    reviewCount:SetPoint("LEFT", ratingText, "RIGHT", 4, 0)
    reviewCount:SetText(string.format("(%d reviews)", vendor.reviewCount or 0))
    reviewCount:SetTextColor(0.6, 0.6, 0.6)

    -- Category name
    local categoryText = card:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    categoryText:SetPoint("TOPLEFT", stars, "BOTTOMLEFT", 0, -4)
    categoryText:SetText(category and category.name or "Other")
    categoryText:SetTextColor(0.7, 0.7, 0.7)

    -- Description snippet
    local descText = card:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    descText:SetPoint("TOPLEFT", categoryText, "BOTTOMLEFT", 0, -4)
    descText:SetPoint("BOTTOMRIGHT", card, "BOTTOMRIGHT", -10, 8)
    descText:SetJustifyH("LEFT")
    descText:SetJustifyV("TOP")
    descText:SetText(Whelp.Utils.TruncateText(vendor.description or "", 80))
    descText:SetTextColor(0.8, 0.8, 0.8)

    -- Favorite button
    local favoriteBtn = CreateFrame("Button", nil, card)
    favoriteBtn:SetSize(24, 24)
    favoriteBtn:SetPoint("TOPRIGHT", card, "TOPRIGHT", -8, -8)

    local favoriteIcon = favoriteBtn:CreateTexture(nil, "ARTWORK")
    favoriteIcon:SetAllPoints()
    favoriteBtn.icon = favoriteIcon

    local isFavorite = Whelp.Database:IsFavorite(vendor.id)
    self:UpdateFavoriteIcon(favoriteBtn, isFavorite)

    favoriteBtn:SetScript("OnClick", function(self)
        local vendorId = card.vendor.id
        if Whelp.Database:IsFavorite(vendorId) then
            Whelp.Database:RemoveFavorite(vendorId)
            VendorCard:UpdateFavoriteIcon(self, false)
        else
            Whelp.Database:AddFavorite(vendorId)
            VendorCard:UpdateFavoriteIcon(self, true)
        end
    end)

    favoriteBtn:SetScript("OnEnter", function(self)
        local isFav = Whelp.Database:IsFavorite(card.vendor.id)
        Templates:ShowTooltip(self, isFav and "Remove from Favorites" or "Add to Favorites")
    end)

    favoriteBtn:SetScript("OnLeave", function()
        Templates:HideTooltip()
    end)

    -- Hover effect
    card:SetScript("OnEnter", function(self)
        self:SetBackdropBorderColor(
            Whelp.Colors.PRIMARY.r,
            Whelp.Colors.PRIMARY.g,
            Whelp.Colors.PRIMARY.b
        )
    end)

    card:SetScript("OnLeave", function(self)
        self:SetBackdropBorderColor(
            Whelp.Colors.BORDER.r,
            Whelp.Colors.BORDER.g,
            Whelp.Colors.BORDER.b
        )
    end)

    -- Click to open detail view
    card:SetScript("OnClick", function(self)
        Whelp.UI.VendorDetail:Show(self.vendor)
        -- Track recently viewed
        Whelp.Database:AddRecentlyViewed(self.vendor.id)
    end)

    return card
end

-- Update favorite icon state
function VendorCard:UpdateFavoriteIcon(button, isFavorite)
    if isFavorite then
        button.icon:SetTexture("Interface\\COMMON\\ReputationStar")
        button.icon:SetTexCoord(0, 0.5, 0, 0.5)
        button.icon:SetVertexColor(1, 0.2, 0.2)
    else
        button.icon:SetTexture("Interface\\COMMON\\ReputationStar")
        button.icon:SetTexCoord(0.5, 1, 0, 0.5)
        button.icon:SetVertexColor(0.5, 0.5, 0.5)
    end
end
