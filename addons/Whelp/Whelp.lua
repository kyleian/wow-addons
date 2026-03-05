--[[
    Whelp - A Yelp-style Vendor Rating System for WoW TBC

    Version: 1.0.0
    Author: Kyle

    Whelp allows players to rate and review in-game service vendors,
    including profession package sellers, enchanters, boosters, and more.

    Usage:
        /whelp - Open the main interface
        /whelp search <query> - Quick search for vendors
        /whelp add - Open the add vendor form
        /whelp help - Show help information
]]

local ADDON_NAME, Whelp = ...

-- Make Whelp globally accessible
_G.Whelp = Whelp

-- Addon loaded state
local isLoaded = false
local isInitialized = false

-- Called when addon is loaded
function Whelp:OnAddonLoaded()
    if isLoaded then return end
    isLoaded = true

    -- Initialize database
    local ok, err = pcall(function() self.Database:Initialize() end)
    if not ok then
        DEFAULT_CHAT_FRAME:AddMessage("|cffff4444[Whelp]|r Database init error: " .. tostring(err))
    end

    -- Initialize event handler (registers PLAYER_ENTERING_WORLD etc.)
    self.EventHandler:Initialize()
end

-- Called when player enters world (fires on both fresh login AND /reload)
function Whelp:OnPlayerLogin()
    if isInitialized then return end
    isInitialized = true

    -- Initialize UI components
    self.UI.MainFrame:Create()
    self.UI.MinimapButton:Initialize()

    -- Welcome message
    local vendorCount = self.Database:GetVendorCount()
    local reviewCount = self.Database:GetReviewCount()

    self:Print("Loaded! " .. vendorCount .. " vendors, " .. reviewCount .. " reviews.")
    self:Print("Type |cff" .. self.Colors.PRIMARY_HEX .. "/whelp|r to open, or click the minimap button.")
end

-- Called when player logs out
function Whelp:OnPlayerLogout()
    -- Save any pending data
    self:Debug("Saving data on logout")
end

-- Called when target changes
function Whelp:OnTargetChanged()
    -- Check if target is a known vendor
    local targetInfo = self.VendorManager:CheckTargetAsVendor()

    if targetInfo and targetInfo.isExistingVendor then
        -- Could show a subtle notification or tooltip enhancement
        self:Debug("Target is a known vendor: " .. targetInfo.name)
    end
end

-- Handle slash commands
function Whelp:HandleSlashCommand(msg)
    -- Lazy UI init in case PLAYER_ENTERING_WORLD hasn't fired yet
    if not isInitialized then
        local ok, err = pcall(function()
            self.UI.MainFrame:Create()
            self.UI.MinimapButton:Initialize()
        end)
        if ok then isInitialized = true end
    end

    local args = {}
    for word in msg:gmatch("%S+") do
        table.insert(args, word:lower())
    end

    local cmd = args[1] or ""

    if cmd == "" or cmd == "open" or cmd == "show" then
        -- Open the Whelp flyout panel docked to SlyChar if available,
        -- otherwise fall back to the standalone Whelp window.
        local wp = _G["SlyWhelpPanelFrame"]
        if wp then
            if wp:IsShown() then wp:Hide()
            else
                -- Ensure SlyChar is visible first
                if SC_ShowMain then SC_ShowMain() end
                wp:Show()
            end
        elseif self.UI and self.UI.MainFrame then
            local mf = self.UI.MainFrame:Create()
            mf:Show()
        end

    elseif cmd == "search" then
        -- Open search
        table.remove(args, 1)
        local query = table.concat(args, " ")
        if query ~= "" then
            self.UI.MainFrame:Show()
            self.UI.MainFrame:SelectTab("search")
            -- The main frame will handle the search
        else
            self.UI.SearchBar:Toggle()
        end

    elseif cmd == "add" then
        -- Open add vendor form
        self.UI.MainFrame:Show()
        self.UI.MainFrame:SelectTab("addvendor")

    elseif cmd == "favorites" or cmd == "fav" then
        -- Show favorites
        self.UI.MainFrame:Show()
        self.UI.MainFrame:SelectTab("favorites")

    elseif cmd == "reviews" or cmd == "myreviews" then
        -- Show my reviews
        self.UI.MainFrame:Show()
        self.UI.MainFrame:SelectTab("myreviews")

    elseif cmd == "minimap" then
        -- Toggle minimap button
        self.UI.MinimapButton:Toggle()
        if self.UI.MinimapButton:IsHidden() then
            self:Print("Minimap button hidden.")
        else
            self:Print("Minimap button shown.")
        end

    elseif cmd == "target" or cmd == "rate" then
        -- Rate current target
        local targetInfo = self.VendorManager:CheckTargetAsVendor()
        if targetInfo then
            if targetInfo.isExistingVendor then
                -- Open vendor detail
                self.UI.VendorDetail:Show(targetInfo.vendor)
            else
                -- Open add vendor with target info pre-filled
                self.UI.MainFrame:Show()
                self.UI.MainFrame:SelectTab("addvendor")
                self:Print("Target '" .. targetInfo.name .. "' is not registered. Add them as a new vendor!")
            end
        else
            self:Print("No valid player target selected.")
        end

    elseif cmd == "stats" then
        -- Show statistics
        local vendorCount = self.Database:GetVendorCount()
        local reviewCount = self.Database:GetReviewCount()
        local myReviews = #self.RatingSystem:GetMyReviews()
        local favorites = #self.Database:GetFavorites()

        self:Print("=== Whelp Statistics ===")
        self:Print("Total vendors: " .. vendorCount)
        self:Print("Total reviews: " .. reviewCount)
        self:Print("Your reviews: " .. myReviews)
        self:Print("Your favorites: " .. favorites)

    elseif cmd == "debug" then
        -- Toggle debug mode
        if not self.db.profile.debug then
            self.db.profile.debug = true
            self:Print("Debug mode enabled.")
        else
            self.db.profile.debug = false
            self:Print("Debug mode disabled.")
        end

    elseif cmd == "reset" then
        -- Reset data (with confirmation)
        if args[2] == "confirm" then
            self.Database:ClearAllData()
            self:Print("All data has been reset.")
        else
            self:Print("WARNING: This will delete all your Whelp data!")
            self:Print("Type |cffff0000/whelp reset confirm|r to proceed.")
        end

    elseif cmd == "help" or cmd == "?" then
        -- Show help
        self:ShowHelp()

    else
        -- Unknown command
        self:Print("Unknown command: " .. cmd)
        self:Print("Type |cff" .. self.Colors.PRIMARY_HEX .. "/whelp help|r for available commands.")
    end
end

-- Show help information
function Whelp:ShowHelp()
    self:Print("=== Whelp Commands ===")
    print("|cff" .. self.Colors.PRIMARY_HEX .. "/whelp|r - Open the main interface")
    print("|cff" .. self.Colors.PRIMARY_HEX .. "/whelp search|r - Open quick search")
    print("|cff" .. self.Colors.PRIMARY_HEX .. "/whelp add|r - Add a new vendor")
    print("|cff" .. self.Colors.PRIMARY_HEX .. "/whelp favorites|r - View your favorites")
    print("|cff" .. self.Colors.PRIMARY_HEX .. "/whelp reviews|r - View your reviews")
    print("|cff" .. self.Colors.PRIMARY_HEX .. "/whelp target|r - Rate your current target")
    print("|cff" .. self.Colors.PRIMARY_HEX .. "/whelp minimap|r - Toggle minimap button")
    print("|cff" .. self.Colors.PRIMARY_HEX .. "/whelp stats|r - Show statistics")
    print("|cff" .. self.Colors.PRIMARY_HEX .. "/whelp help|r - Show this help")
end

-- Expose toggle function globally for keybindings
function Whelp_Toggle()
    Whelp.UI.MainFrame:Toggle()
end

function Whelp_Search()
    Whelp.UI.SearchBar:Toggle()
end

-- -------------------------------------------------------
-- Slash commands - registered at file scope so they work
-- on both fresh login AND /reload with no event chain needed.
-- -------------------------------------------------------
SLASH_WHELP1 = "/whelp"
SLASH_WHELP2 = "/yelp"
SlashCmdList["WHELP"] = function(msg)
    Whelp:HandleSlashCommand(msg or "")
end
-- Keybinding names
BINDING_HEADER_WHELP = "Whelp"
BINDING_NAME_WHELP_TOGGLE = "Toggle Whelp"
BINDING_NAME_WHELP_SEARCH = "Quick Search"
