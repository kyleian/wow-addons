-- ============================================================
-- ItemRack Revived — Sets.lua
-- Gear set CRUD: save, load, delete, query
-- ToS note: equipping items is player-initiated via button press.
--           No automation; each swap requires an explicit UI action.
-- ============================================================

-- TBC Anniversary: C_Container replaces the old global bag API.
-- Mirror the same shim pattern used in ItemRack itself.
local _PickupContainerItem
local _GetContainerNumSlots
local _GetContainerItemID
if C_Container then
    _PickupContainerItem  = C_Container.PickupContainerItem
    _GetContainerNumSlots = C_Container.GetContainerNumSlots
    _GetContainerItemID   = function(bag, slot)
        local info = C_Container.GetContainerItemInfo(bag, slot)
        return info and info.itemID or nil
    end
else
    _PickupContainerItem  = PickupContainerItem
    _GetContainerNumSlots = GetContainerNumSlots
    _GetContainerItemID   = GetContainerItemID
end

-- -------------------------------------------------------
-- IRR_SaveCurrentSet(name)
-- Captures all currently equipped items into a named set.
-- Overwrites an existing set of the same name.
-- -------------------------------------------------------
function IRR_SaveCurrentSet(name)
    if not name or name == "" then
        print("|cff00ccff[ItemRack Revived]|r Set name cannot be empty.")
        return false
    end
    if not IRR.db then
        print("|cff00ccff[ItemRack Revived]|r DB not ready — try again in a moment.")
        return false
    end

    local setData = {}
    local count = 0
    for _, slotDef in ipairs(IRR.SLOTS) do
        if slotDef.id ~= 0 then  -- skip ammo slot (id=0, not a valid equip slot)
            local itemId = GetInventoryItemID("player", slotDef.id)
            if itemId then
                setData[slotDef.id] = itemId
                count = count + 1
            end
        end
    end

    if count == 0 then
        print("|cff00ccff[ItemRack Revived]|r |cffff8800Warning:|r No equipped items found — set saved empty.")
    end

    IRR.chardata.sets[name] = setData
    print("|cff00ccff[ItemRack Revived]|r Set |cffffcc00" .. name .. "|r saved (" .. count .. " slot" .. (count == 1 and "" or "s") .. ").")
    IRR_UpdateSetsList()
    -- Also refresh SlyChar sets panel if it is open
    if SC_RefreshSets then SC_RefreshSets() end
    return true
end

-- -------------------------------------------------------
-- IRR_DeleteSet(name)
-- Removes a named set.
-- -------------------------------------------------------
function IRR_DeleteSet(name)
    if not IRR.chardata.sets[name] then
        print("|cff00ccff[ItemRack Revived]|r Set |cffff4444" .. name .. "|r not found.")
        return false
    end
    IRR.chardata.sets[name] = nil
    print("|cff00ccff[ItemRack Revived]|r Set |cffffcc00" .. name .. "|r deleted.")
    IRR_UpdateSetsList()
    -- Also refresh SlyChar sets panel if it is open
    if SC_RefreshSets then SC_RefreshSets() end
    return true
end

-- -------------------------------------------------------
-- IRR_GetSetNames()
-- Returns a sorted list of saved set names.
-- -------------------------------------------------------
function IRR_GetSetNames()
    if not (IRR.chardata and IRR.chardata.sets) then return {} end
    local names = {}
    for name in pairs(IRR.chardata.sets) do
        table.insert(names, name)
    end
    table.sort(names)
    return names
end

-- -------------------------------------------------------
-- IRR_EquipItemInSlot(targetItemId, slotId)
-- Searches the player's bags for an item with targetItemId
-- and equips it to slotId. Returns true on success.
-- Player must trigger this via a UI button (not automated).
-- -------------------------------------------------------
local _UseContainerItem = C_Container and C_Container.UseContainerItem or UseContainerItem

local function IRR_EquipItemInSlot(targetItemId, slotId)
    -- Ammo slot (0): PickupInventoryItem(0) is not a valid API in TBC Anniversary.
    -- Ammo is equipped by right-clicking the stack (UseContainerItem).
    -- Just scan bags and UseContainerItem on the matching stack.
    if slotId == 0 then
        local currentId = GetInventoryItemID and GetInventoryItemID("player", 0)
        if currentId == targetItemId then return true end
        for bag = 0, 4 do
            local slots = _GetContainerNumSlots(bag)
            for bslot = 1, slots do
                if _GetContainerItemID(bag, bslot) == targetItemId then
                    _UseContainerItem(bag, bslot)
                    return true
                end
            end
        end
        return false
    end

    -- Already wearing it?
    local currentId = GetInventoryItemID("player", slotId)
    if currentId == targetItemId then return true end

    -- Never touch items while cursor is occupied or a spell is targeting
    if GetCursorInfo() or SpellIsTargeting() then return false end

    -- Search bag slots 0-4 using C_Container-safe API
    for bag = 0, 4 do
        local slots = _GetContainerNumSlots(bag)
        for bslot = 1, slots do
            if _GetContainerItemID(bag, bslot) == targetItemId then
                -- Pick up from bag, equip to slot; any displaced item lands on
                -- cursor — drop it back into the now-empty bag slot so the
                -- cursor is clean for the next swap in the same loop.
                _PickupContainerItem(bag, bslot)
                local ok = pcall(PickupInventoryItem, slotId)
                if not ok then
                    -- equip failed (e.g. item locked); clear cursor to unblock future swaps
                    ClearCursor()
                    return false
                end
                if GetCursorInfo() then
                    -- Displaced item is on cursor; drop it into the now-empty bag slot.
                    -- If that also fails, force-clear to keep cursor clean.
                    local ok2 = pcall(_PickupContainerItem, bag, bslot)
                    if not ok2 or GetCursorInfo() then ClearCursor() end
                end
                return true
            end
        end
    end

    -- Item may already be equipped in a different slot (swap scenario).
    -- Skip slot 0 — ammo can't be swapped via PickupInventoryItem.
    for _, slotDef in ipairs(IRR.SLOTS) do
        if slotDef.id ~= 0 and GetInventoryItemID("player", slotDef.id) == targetItemId then
            local ok = pcall(PickupInventoryItem, slotDef.id)
            if not ok then ClearCursor(); return false end
            local ok2 = pcall(PickupInventoryItem, slotId)
            if not ok2 then ClearCursor(); return false end
            if GetCursorInfo() then
                local ok3 = pcall(PickupInventoryItem, slotDef.id)
                if not ok3 or GetCursorInfo() then ClearCursor() end
            end
            return true
        end
    end

    return false  -- not found
end

-- -------------------------------------------------------
-- IRR_LoadSet(name)
-- Equips all items in the named set that are available
-- in the player's bags or already equipped elsewhere.
-- Reports any missing items.
-- -------------------------------------------------------
function IRR_LoadSet(name)
    local setData = IRR.chardata.sets[name]
    if not setData then
        print("|cff00ccff[ItemRack Revived]|r Set |cffff4444" .. name .. "|r not found.")
        return
    end
    print("|cff00ccff[ItemRack Revived]|r Loading set: |cffffcc00" .. name .. "|r")

    local equipped  = 0
    local missing   = {}

    -- Build a target list: slot -> itemId
    for slotId, itemId in pairs(setData) do
        local ok = IRR_EquipItemInSlot(itemId, tonumber(slotId))
        if ok then
            equipped = equipped + 1
        else
            local itemName = GetItemInfo(itemId) or ("Item #" .. itemId)
            table.insert(missing, itemName)
        end
    end

    -- Auto-equip ammo if a ranged weapon (bow/gun/crossbow) is equipped but
    -- the set had no explicit ammo entry (slot 0).  INVTYPE_RANGED covers
    -- bows, guns and crossbows; wands (INVTYPE_RANGEDRIGHT) don't use ammo.
    if not setData[0] then
        local rangedId = GetInventoryItemID("player", 18)
        if rangedId then
            local _, _, _, _, _, _, _, _, rangedInvType = GetItemInfo(rangedId)
            if rangedInvType == "INVTYPE_RANGED" then
                for bag = 0, 4 do
                    local bagSlots = _GetContainerNumSlots(bag)
                    local found = false
                    for bslot = 1, bagSlots do
                        local ammoId = _GetContainerItemID(bag, bslot)
                        if ammoId then
                            local _, _, _, _, _, _, _, _, ammoInvType = GetItemInfo(ammoId)
                            if ammoInvType == "INVTYPE_AMMO" then
                                if GetInventoryItemID("player", 0) ~= ammoId then
                                    _UseContainerItem(bag, bslot)
                                end
                                found = true
                                break
                            end
                        end
                    end
                    if found then break end
                end
            end
        end
    end

    -- Switch dual spec if linked.
    -- CRITICAL ORDER: spec switch must happen FIRST, then we re-equip gear
    -- in a one-shot ACTIVE_TALENT_GROUP_CHANGED handler.  If we equip first,
    -- TBC's dual-spec system restores its own saved gear for the new spec and
    -- overwrites everything IRR just put on.
    local linkedSpec = IRR_GetSpecLink(name)
    if linkedSpec
        and SetActiveTalentGroup
        and GetNumTalentGroups and GetNumTalentGroups() >= 2 then
        local active = GetActiveTalentGroup and GetActiveTalentGroup() or 1
        if active ~= linkedSpec then
            -- Wipe whatever IRR equipped above — the spec swap will trash it
            -- anyway, so don't bother reporting those as "equipped".
            equipped = 0 ; missing = {}

            -- One-shot frame: listens for ACTIVE_TALENT_GROUP_CHANGED then
            -- re-equips the set after TBC has finished restoring its own gear.
            local reEquipFrame = CreateFrame("Frame")
            local watchdog = 0
            reEquipFrame:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED")
            reEquipFrame:SetScript("OnEvent", function(self, ev)
                self:UnregisterAllEvents()
                -- Wait one extra frame so TBC's own gear-restore finishes first.
                C_Timer.After(0.3, function()
                    local eq2, miss2 = 0, {}
                    for slotId, itemId in pairs(setData) do
                        local ok2 = IRR_EquipItemInSlot(itemId, tonumber(slotId))
                        if ok2 then eq2 = eq2 + 1
                        else
                            local iName = GetItemInfo(itemId) or ("Item #" .. itemId)
                            table.insert(miss2, iName)
                        end
                    end
                    if #miss2 == 0 then
                        print("|cff00ccff[ItemRack Revived]|r Set |cffffcc00" .. name
                            .. "|r equipped after spec switch (" .. eq2 .. " items).")
                    else
                        print("|cff00ccff[ItemRack Revived]|r Set |cffffcc00" .. name
                            .. "|r: " .. eq2 .. " equipped, "
                            .. #miss2 .. " not found in bags:")
                        for _, iName in ipairs(miss2) do
                            print("  |cffff4444- " .. iName .. "|r")
                        end
                    end
                end)
            end)

            -- Now initiate the spec switch.  TBC will show a confirmation popup.
            local ok, err = pcall(SetActiveTalentGroup, linkedSpec)
            if not ok then
                reEquipFrame:UnregisterAllEvents()
                print("|cffff4444[ItemRack Revived]|r Spec switch failed: " .. tostring(err))
            else
                local attempts = 0
                local function tryConfirm()
                    attempts = attempts + 1
                    for i = 1, 4 do
                        local popup = _G["StaticPopup" .. i]
                        if popup and popup:IsShown() and popup.which then
                            local w = popup.which:upper()
                            if w:find("TALENT") or w:find("GROUP") or w:find("SPEC") then
                                local btn = _G["StaticPopup" .. i .. "Button1"]
                                if btn and btn:IsShown() then
                                    btn:Click()
                                    return
                                end
                            end
                        end
                    end
                    if attempts < 6 then C_Timer.After(0.2, tryConfirm) end
                end
                C_Timer.After(0.15, tryConfirm)
                -- Safety: un-register listener after 10 s in case event never fires
                C_Timer.After(10, function() reEquipFrame:UnregisterAllEvents() end)
            end
            return   -- gear equip + report handled by the one-shot handler above
        end
    end

    -- Report (no spec switch path)
    if #missing == 0 then
        print("|cff00ccff[ItemRack Revived]|r Set |cffffcc00" .. name
            .. "|r equipped (" .. equipped .. " items).")
    else
        print("|cff00ccff[ItemRack Revived]|r Set |cffffcc00" .. name
            .. "|r: " .. equipped .. " equipped, "
            .. #missing .. " not found in bags:")
        for _, itemName in ipairs(missing) do
            print("  |cffff4444- " .. itemName .. "|r")
        end
    end
end

-- -------------------------------------------------------
-- IRR_SetSpecLink(name, spec)
-- Links a dual-spec group (1 or 2) to a set, or clears it (nil).
-- When IRR_LoadSet is called the linked spec is activated.
-- -------------------------------------------------------
function IRR_SetSpecLink(name, spec)
    IRR.chardata.specLinks[name] = spec  -- nil clears the link
end

-- Returns 1, 2, or nil.
function IRR_GetSpecLink(name)
    return IRR.chardata and IRR.chardata.specLinks[name] or nil
end

-- -------------------------------------------------------
-- IRR_SetSetIcon(name, icon) / IRR_GetSetIcon(name)
-- Store or retrieve a texture path for a set's display icon.
-- -------------------------------------------------------
function IRR_SetSetIcon(name, icon)
    if not IRR or not IRR.chardata then return end
    IRR.chardata.setIcons[name] = icon
end

function IRR_GetSetIcon(name)
    if not IRR or not IRR.chardata then return nil end
    return IRR.chardata.setIcons[name]
end

-- -------------------------------------------------------
-- IRR_SetExists(name)
-- Returns true if a set with that name is saved.
-- -------------------------------------------------------
function IRR_SetExists(name)
    return IRR.chardata.sets[name] ~= nil
end

-- -------------------------------------------------------
-- IRR_GetSetItemCount(name)
-- Returns the number of items stored in a set.
-- -------------------------------------------------------
function IRR_GetSetItemCount(name)
    local count = 0
    if IRR.chardata.sets[name] then
        for _ in pairs(IRR.chardata.sets[name]) do count = count + 1 end
    end
    return count
end
