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
-- Helper: extract { id, link } from a stored slot value (handles old bare-number format).
local function UnpackSlot(v)
    if type(v) == "table" then
        return v.id, v.link
    else
        return v, nil   -- legacy: bare itemId
    end
end

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
                -- Store the full item link so gem/enchant variants are distinguishable.
                local link = GetInventoryItemLink("player", slotDef.id)
                setData[slotDef.id] = { id = itemId, link = link }
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
-- IRR_EquipItemInSlot(targetItemId, slotId, protectedSlots)
-- Searches the player's bags for an item with targetItemId
-- and equips it to slotId. Returns true on success.
-- protectedSlots: optional { [slotId]=true } table of slots that are
--   target slots in the current LoadSet call — the "equipped elsewhere"
--   fallback will never steal from these, preventing duplicate-itemID
--   ping-pong between two rings/trinkets with the same itemID.
-- Player must trigger this via a UI button (not automated).
-- -------------------------------------------------------
local _UseContainerItem = C_Container and C_Container.UseContainerItem or UseContainerItem

-- Returns the item link for a bag slot (C_Container-safe).
local function GetBagItemLink(bag, slot)
    if C_Container and C_Container.GetContainerItemInfo then
        local info = C_Container.GetContainerItemInfo(bag, slot)
        return info and info.hyperlink or nil
    end
    return GetContainerItemLink and GetContainerItemLink(bag, slot) or nil
end

-- Returns true if the bag slot's link matches targetLink, or if no targetLink
-- is provided, falls back to id-only comparison.
local function BagSlotMatches(bag, slot, targetItemId, targetLink)
    local id = _GetContainerItemID(bag, slot)
    if id ~= targetItemId then return false end
    if not targetLink then return true end  -- legacy / ammo: id-only match
    local slotLink = GetBagItemLink(bag, slot)
    -- Exact link match preferred; fall back to id-only if link unavailable
    return (not slotLink) or (slotLink == targetLink)
end

local function IRR_EquipItemInSlot(targetItemId, slotId, protectedSlots, targetLink)
    -- Ammo slot (0): PickupInventoryItem(0) is not a valid API in TBC Anniversary.
    -- Ammo is equipped by right-clicking the stack (UseContainerItem).
    -- Just scan bags and UseContainerItem on the matching stack.
    if slotId == 0 then
        local currentId = GetInventoryItemID and GetInventoryItemID("player", 0)
        if currentId == targetItemId then return true end
        for bag = 0, 4 do
            local slots = _GetContainerNumSlots(bag)
            for bslot = 1, slots do
                if BagSlotMatches(bag, bslot, targetItemId, targetLink) then
                    _UseContainerItem(bag, bslot)
                    return true
                end
            end
        end
        return false
    end

    -- Already wearing it in the target slot?
    local currentId = GetInventoryItemID("player", slotId)
    if currentId == targetItemId then
        -- If we have a link, verify it matches (different enchant/gem = wrong copy)
        if not targetLink then return true end
        local equippedLink = GetInventoryItemLink("player", slotId)
        if not equippedLink or equippedLink == targetLink then return true end
        -- Wrong variant is in the slot — fall through to find the right one in bags
    end

    -- Never touch items while cursor is occupied or a spell is targeting
    if GetCursorInfo() or SpellIsTargeting() then return false end

    -- Search bag slots 0-4 using C_Container-safe API.
    -- First pass: prefer exact link match (different gem/enchant = different item).
    -- Second pass: fall back to id-only match if no exact match found.
    local fallbackBag, fallbackSlot
    for bag = 0, 4 do
        local slots = _GetContainerNumSlots(bag)
        for bslot = 1, slots do
            local id = _GetContainerItemID(bag, bslot)
            if id == targetItemId then
                local slotLink = targetLink and GetBagItemLink(bag, bslot)
                local exactMatch = (not targetLink) or (not slotLink) or (slotLink == targetLink)
                if exactMatch then
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
                elseif not fallbackBag then
                    -- Record first id-only match as fallback
                    fallbackBag, fallbackSlot = bag, bslot
                end
            end
        end
    end

    -- No exact link match found — use id-only fallback if available
    if fallbackBag then
        _PickupContainerItem(fallbackBag, fallbackSlot)
        local ok = pcall(PickupInventoryItem, slotId)
        if not ok then ClearCursor() ; return false end
        if GetCursorInfo() then
            local ok2 = pcall(_PickupContainerItem, fallbackBag, fallbackSlot)
            if not ok2 or GetCursorInfo() then ClearCursor() end
        end
        return true
    end

    -- Item may already be equipped in a different slot (swap scenario).
    -- Skip slot 0 — ammo can't be swapped via PickupInventoryItem.
    -- Also skip any slot that is itself a target in this LoadSet call
    -- (protectedSlots), because that item will be handled — or is already
    -- correct — in its own iteration.  Without this guard, two identical
    -- rings would steal from each other, leaving one slot empty.
    for _, slotDef in ipairs(IRR.SLOTS) do
        if slotDef.id ~= 0
            and GetInventoryItemID("player", slotDef.id) == targetItemId
            and not (protectedSlots and protectedSlots[slotDef.id])
        then
            -- If we have a link, verify the equipped copy is the right variant
            local wrongVariant = false
            if targetLink then
                local eqLink = GetInventoryItemLink("player", slotDef.id)
                if eqLink and eqLink ~= targetLink then
                    wrongVariant = true  -- keep looking; right copy may be in bags
                end
            end
            if not wrongVariant then
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

    -- Build the set of slot IDs that this set is trying to fill.
    -- Passed to IRR_EquipItemInSlot so the "equipped elsewhere" fallback
    -- never steals an item from a slot that the set itself owns — this
    -- prevents duplicate-itemID ping-pong (e.g. two identical rings).
    local protectedSlots = {}
    for slotId in pairs(setData) do
        protectedSlots[tonumber(slotId)] = true
    end

    -- Pre-pass: resolve mutual cross-slot swaps before the main equip loop.
    -- Case: ring A is in slot 11, ring B is in slot 12, but the set wants A in 12 and B in 11.
    -- Both slots are protectedSlots so the normal path can't steal from either.
    -- We detect A↔B pairs and do a direct slot-to-slot swap here so the main loop
    -- finds each slot already correct and skips it.
    local swappedSlots = {}
    for slotId, slotVal in pairs(setData) do
        local sid = tonumber(slotId)
        if not swappedSlots[sid] then
            local targetId, targetLink = UnpackSlot(slotVal)
            local curId   = GetInventoryItemID("player", sid)
            local curLink = curId and GetInventoryItemLink("player", sid)
            -- Already correct — no swap needed.
            local alreadyOK = curId == targetId and
                ((not targetLink) or (not curLink) or curLink == targetLink)
            if not alreadyOK then
                -- Search other target slots for the item we need.
                for otherSlotId, otherSlotVal in pairs(setData) do
                    local osid = tonumber(otherSlotId)
                    if osid ~= sid and not swappedSlots[osid] then
                        local otherCurId   = GetInventoryItemID("player", osid)
                        local otherCurLink = otherCurId and GetInventoryItemLink("player", osid)
                        -- Does the other slot hold exactly what this slot needs?
                        local otherHasOurs = otherCurId == targetId and
                            ((not targetLink) or (not otherCurLink) or otherCurLink == targetLink)
                        if otherHasOurs then
                            -- Does this slot hold exactly what the other slot needs?
                            local otherTargetId, otherTargetLink = UnpackSlot(otherSlotVal)
                            local weHaveTheirs = curId == otherTargetId and
                                ((not otherTargetLink) or (not curLink) or curLink == otherTargetLink)
                            if weHaveTheirs then
                                -- Mutual swap: pick up from sid, click osid to swap.
                                local ok1 = pcall(PickupInventoryItem, sid)
                                if ok1 then
                                    local ok2 = pcall(PickupInventoryItem, osid)
                                    if ok2 then
                                        if GetCursorInfo() then ClearCursor() end
                                        swappedSlots[sid]  = true
                                        swappedSlots[osid] = true
                                    else
                                        -- Undo: put back
                                        pcall(PickupInventoryItem, sid)
                                        if GetCursorInfo() then ClearCursor() end
                                    end
                                end
                                break
                            end
                        end
                    end
                end
            end
        end
    end

    -- Equip each slot.  Pass protectedSlots so the fallback path is safe.
    -- Slots resolved by the pre-pass will be detected as "already correct" and counted.
    equipped = 0
    for slotId, slotVal in pairs(setData) do
        local itemId, itemLink = UnpackSlot(slotVal)
        local ok = IRR_EquipItemInSlot(itemId, tonumber(slotId), protectedSlots, itemLink)
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
                    for slotId, slotVal in pairs(setData) do
                        local itemId2, itemLink2 = UnpackSlot(slotVal)
                        local ok2 = IRR_EquipItemInSlot(itemId2, tonumber(slotId), protectedSlots, itemLink2)
                        if ok2 then eq2 = eq2 + 1
                        else
                            local iName = GetItemInfo(itemId2) or ("Item #" .. itemId2)
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
