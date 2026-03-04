--[[
    Whelp - EventHandler
    Handles WoW events for the addon
]]

local ADDON_NAME, Whelp = ...

Whelp.EventHandler = {}
local EventHandler = Whelp.EventHandler

-- Create the event frame
local eventFrame = CreateFrame("Frame", "WhelpEventFrame")
EventHandler.frame = eventFrame

-- Event callbacks table (populated by RegisterEvent)
local eventCallbacks = {}

-- Register an event with a callback
function EventHandler:RegisterEvent(event, callback)
    if not eventCallbacks[event] then
        eventCallbacks[event] = {}
        eventFrame:RegisterEvent(event)
    end
    table.insert(eventCallbacks[event], callback)
end

-- Unregister an event callback
function EventHandler:UnregisterEvent(event, callback)
    if eventCallbacks[event] then
        for i, cb in ipairs(eventCallbacks[event]) do
            if cb == callback then
                table.remove(eventCallbacks[event], i)
                break
            end
        end
        if #eventCallbacks[event] == 0 then
            eventFrame:UnregisterEvent(event)
            eventCallbacks[event] = nil
        end
    end
end

-- Single unified OnEvent handler.
-- Boots the addon on ADDON_LOADED (before Initialize() is ever called),
-- then dispatches all subsequent events via eventCallbacks.
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local addonName = ...
        if addonName == ADDON_NAME then
            eventFrame:UnregisterEvent("ADDON_LOADED")
            Whelp:OnAddonLoaded()   -- calls EventHandler:Initialize() -> registers PLAYER_LOGIN etc.
        end
        return
    end
    if eventCallbacks[event] then
        for _, callback in ipairs(eventCallbacks[event]) do
            callback(event, ...)
        end
    end
end)

-- Initialize event handling for the addon
function EventHandler:Initialize()
    -- Register core events (ADDON_LOADED already handled by bootstrap above)
    self:RegisterEvent("PLAYER_LOGIN", function()
        Whelp:OnPlayerLogin()
    end)

    self:RegisterEvent("PLAYER_LOGOUT", function()
        Whelp:OnPlayerLogout()
    end)

    -- Register player target changed for quick vendor lookup
    self:RegisterEvent("PLAYER_TARGET_CHANGED", function()
        Whelp:OnTargetChanged()
    end)

    Whelp:Debug("Event handler initialized")
end

-- Custom events for inter-module communication
local customCallbacks = {}

function EventHandler:RegisterCustomEvent(eventName, callback)
    if not customCallbacks[eventName] then
        customCallbacks[eventName] = {}
    end
    table.insert(customCallbacks[eventName], callback)
end

function EventHandler:UnregisterCustomEvent(eventName, callback)
    if customCallbacks[eventName] then
        for i, cb in ipairs(customCallbacks[eventName]) do
            if cb == callback then
                table.remove(customCallbacks[eventName], i)
                break
            end
        end
    end
end

function EventHandler:FireCustomEvent(eventName, ...)
    if customCallbacks[eventName] then
        for _, callback in ipairs(customCallbacks[eventName]) do
            callback(eventName, ...)
        end
    end
end

-- Define custom events
EventHandler.CustomEvents = {
    VENDOR_ADDED = "WHELP_VENDOR_ADDED",
    VENDOR_UPDATED = "WHELP_VENDOR_UPDATED",
    VENDOR_DELETED = "WHELP_VENDOR_DELETED",
    REVIEW_ADDED = "WHELP_REVIEW_ADDED",
    REVIEW_UPDATED = "WHELP_REVIEW_UPDATED",
    REVIEW_DELETED = "WHELP_REVIEW_DELETED",
    FAVORITE_ADDED = "WHELP_FAVORITE_ADDED",
    FAVORITE_REMOVED = "WHELP_FAVORITE_REMOVED",
    UI_REFRESH = "WHELP_UI_REFRESH",
}
