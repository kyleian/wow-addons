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

    local setData = {}
    for _, slotDef in ipairs(IRR.SLOTS) do
        local itemId = GetInventoryItemID("player", slotDef.id)
        if itemId then
            setData[slotDef.id] = itemId
        end
    end

    IRR.db.sets[name] = setData
    print("|cff00ccff[ItemRack Revived]|r Set |cffffcc00" .. name .. "|r saved.")
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
    if not IRR.db.sets[name] then
        print("|cff00ccff[ItemRack Revived]|r Set |cffff4444" .. name .. "|r not found.")
        return false
    end
    IRR.db.sets[name] = nil
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
    local names = {}
    for name in pairs(IRR.db.sets) do
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
local function IRR_EquipItemInSlot(targetItemId, slotId)
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
                -- Pick up from bag, then swap into equip slot
                -- (matches real ItemRack: PickupContainerItem + PickupInventoryItem)
                _PickupContainerItem(bag, bslot)
                PickupInventoryItem(slotId)
                return true
            end
        end
    end

    -- Item may be in another equipment slot (swap scenario)
    for _, slotDef in ipairs(IRR.SLOTS) do
        if GetInventoryItemID("player", slotDef.id) == targetItemId then
            PickupInventoryItem(slotDef.id)
            PickupInventoryItem(slotId)
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
    local setData = IRR.db.sets[name]
    if not setData then
        print("|cff00ccff[ItemRack Revived]|r Set |cffff4444" .. name .. "|r not found.")
        return
    end

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

    -- Switch dual spec if linked
    local linkedSpec = IRR_GetSpecLink(name)
    if linkedSpec and GetNumTalentGroups and GetNumTalentGroups() >= 2 then
        local active = GetActiveTalentGroup and GetActiveTalentGroup() or 1
        if active ~= linkedSpec then
            SetActiveTalentGroup(linkedSpec)
            print("|cff00ccff[ItemRack Revived]|r Switched to Spec " .. linkedSpec .. ".")
        end
    end

    -- Report
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
    if not IRR.db.specLinks then IRR.db.specLinks = {} end
    IRR.db.specLinks[name] = spec  -- nil clears the link
end

-- Returns 1, 2, or nil.
function IRR_GetSpecLink(name)
    return IRR.db.specLinks and IRR.db.specLinks[name] or nil
end

-- -------------------------------------------------------
-- IRR_SetExists(name)
-- Returns true if a set with that name is saved.
-- -------------------------------------------------------
function IRR_SetExists(name)
    return IRR.db.sets[name] ~= nil
end

-- -------------------------------------------------------
-- IRR_GetSetItemCount(name)
-- Returns the number of items stored in a set.
-- -------------------------------------------------------
function IRR_GetSetItemCount(name)
    local count = 0
    if IRR.db.sets[name] then
        for _ in pairs(IRR.db.sets[name]) do count = count + 1 end
    end
    return count
end
