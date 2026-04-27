--[[
    Whelp - MinimapButton
    Minimap button using LibDBIcon
]]

local ADDON_NAME, Whelp = ...

Whelp.UI = Whelp.UI or {}
Whelp.UI.MinimapButton = {}
local MinimapButton = Whelp.UI.MinimapButton

local LDB = LibStub("LibDataBroker-1.1", true)
local LDBIcon = LibStub("LibDBIcon-1.0", true)

local dataObj = nil

-- Initialize the minimap button
function MinimapButton:Initialize()
    if not LDB or not LDBIcon then
        Whelp:Debug("LibDataBroker or LibDBIcon not found")
        return
    end

    -- Create LDB data object
    dataObj = LDB:NewDataObject("Whelp", {
        type = "launcher",
        text = "Whelp",
        icon = "Interface\\Icons\\INV_Misc_Book_09",
        OnClick = function(_, button)
            if button == "LeftButton" then
                if IsShiftKeyDown() then
                    Whelp.UI.SearchBar:Toggle()
                else
                    Whelp.UI.MainFrame:Toggle()
                end
            elseif button == "RightButton" then
                self:ShowContextMenu()
            end
        end,
        OnTooltipShow = function(tooltip)
            tooltip:SetText("|cff" .. Whelp.Colors.PRIMARY_HEX .. "Whelp|r v" .. Whelp.VERSION)
            tooltip:AddLine(" ")
            tooltip:AddLine("|cffffffffLeft-click:|r Open Whelp", 0.8, 0.8, 0.8)
            tooltip:AddLine("|cffffffffShift+Left-click:|r Quick Search", 0.8, 0.8, 0.8)
            tooltip:AddLine("|cffffffffRight-click:|r Options", 0.8, 0.8, 0.8)
            tooltip:AddLine(" ")

            -- Show stats
            local vendorCount = Whelp.Database:GetVendorCount()
            local reviewCount = Whelp.Database:GetReviewCount()
            tooltip:AddLine(string.format("%d vendors | %d reviews", vendorCount, reviewCount), 0.6, 0.6, 0.6)
        end,
    })

    -- Register with LibDBIcon
    if Whelp.db and Whelp.db.profile then
        LDBIcon:Register("Whelp", dataObj, Whelp.db.profile.minimap)
    end

    Whelp:Debug("Minimap button initialized")
end

-- Show context menu
function MinimapButton:ShowContextMenu()
    local menu = {
        {
            text = "|cff" .. Whelp.Colors.PRIMARY_HEX .. "Whelp|r",
            isTitle = true,
            notCheckable = true,
        },
        {
            text = "Browse Vendors",
            notCheckable = true,
            func = function()
                Whelp.UI.MainFrame:Show()
                Whelp.UI.MainFrame:SelectTab("browse")
            end,
        },
        {
            text = "Quick Search",
            notCheckable = true,
            func = function()
                Whelp.UI.SearchBar:Toggle()
            end,
        },
        {
            text = "My Favorites",
            notCheckable = true,
            func = function()
                Whelp.UI.MainFrame:Show()
                Whelp.UI.MainFrame:SelectTab("favorites")
            end,
        },
        {
            text = "My Reviews",
            notCheckable = true,
            func = function()
                Whelp.UI.MainFrame:Show()
                Whelp.UI.MainFrame:SelectTab("myreviews")
            end,
        },
        {
            text = " ",
            isTitle = true,
            notCheckable = true,
        },
        {
            text = "Add Vendor",
            notCheckable = true,
            func = function()
                Whelp.UI.MainFrame:Show()
                Whelp.UI.MainFrame:SelectTab("addvendor")
            end,
        },
        {
            text = " ",
            isTitle = true,
            notCheckable = true,
        },
        {
            text = "Hide Minimap Button",
            notCheckable = true,
            func = function()
                MinimapButton:Hide()
                Whelp:Print("Minimap button hidden. Type /whelp minimap to show it again.")
            end,
        },
        {
            text = " ",
            isTitle = true,
            notCheckable = true,
        },
        {
            text = "Close",
            notCheckable = true,
            func = function() end,
        },
    }

    -- Create dropdown if not exists
    if not WhelpMinimapMenu then
        CreateFrame("Frame", "WhelpMinimapMenu", UIParent, "UIDropDownMenuTemplate")
    end

    EasyMenu(menu, WhelpMinimapMenu, "cursor", 0, 0, "MENU")
end

-- Show the minimap button
function MinimapButton:Show()
    if LDBIcon and Whelp.db and Whelp.db.profile then
        Whelp.db.profile.minimap.hide = false
        LDBIcon:Show("Whelp")
    end
end

-- Hide the minimap button
function MinimapButton:Hide()
    if LDBIcon and Whelp.db and Whelp.db.profile then
        Whelp.db.profile.minimap.hide = true
        LDBIcon:Hide("Whelp")
    end
end

-- Toggle minimap button visibility
function MinimapButton:Toggle()
    if Whelp.db and Whelp.db.profile and Whelp.db.profile.minimap.hide then
        self:Show()
    else
        self:Hide()
    end
end

-- Check if hidden
function MinimapButton:IsHidden()
    return Whelp.db and Whelp.db.profile and Whelp.db.profile.minimap.hide
end

-- Update the button text (for showing notifications, etc.)
function MinimapButton:UpdateText(text)
    if dataObj then
        dataObj.text = text or "Whelp"
    end
end
