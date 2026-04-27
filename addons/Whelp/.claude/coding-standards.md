# Whelp Coding Standards

## Lua Style Guide

### Naming Conventions

```lua
-- Constants: UPPER_SNAKE_CASE
local MAX_REVIEW_LENGTH = 500

-- Local variables: camelCase
local currentVendor = nil

-- Functions: PascalCase for public, camelCase for private
function Module:PublicFunction()
function privateHelper()

-- Tables/Modules: PascalCase
local VendorManager = {}

-- Boolean variables: use is/has/can prefix
local isLoaded = false
local hasReviewed = true
```

### Module Structure

```lua
--[[
    Whelp - ModuleName
    Brief description of module purpose
]]

local ADDON_NAME, Whelp = ...

Whelp.ModuleName = {}
local ModuleName = Whelp.ModuleName

-- Private variables
local privateVar = nil

-- Private functions
local function privateHelper()
end

-- Public functions
function ModuleName:PublicMethod()
end
```

### Documentation

```lua
-- Single line comments for brief explanations
local x = 1  -- inline comment

--[[
    Multi-line block comments for:
    - Function documentation
    - Complex logic explanation
    - Module headers
]]

-- Function documentation
-- @param name string The vendor's name
-- @param category string Service category ID
-- @return table|nil The created vendor or nil on error
-- @return string|nil Error message if failed
function VendorManager:CreateVendor(name, category)
```

### Indentation and Formatting

- Use 4 spaces for indentation (not tabs)
- Maximum line length: 120 characters
- One statement per line
- Blank lines between logical sections

```lua
-- Good
function Module:DoSomething()
    local result = self:Calculate()

    if result > 0 then
        self:ProcessPositive(result)
    else
        self:ProcessNegative(result)
    end

    return result
end

-- Bad
function Module:DoSomething()
local result=self:Calculate()
if result>0 then self:ProcessPositive(result) else self:ProcessNegative(result) end
return result
end
```

### Tables

```lua
-- Short tables: single line
local colors = {r = 1, g = 0.5, b = 0}

-- Long tables: multi-line with trailing comma
local vendor = {
    id = "uid_123",
    name = "VendorName",
    category = "profession_package",
    rating = 4.5,
}

-- Array tables
local items = {
    "item1",
    "item2",
    "item3",
}
```

### Control Flow

```lua
-- if/elseif/else
if condition1 then
    action1()
elseif condition2 then
    action2()
else
    defaultAction()
end

-- Guard clauses for early returns
function ProcessVendor(vendor)
    if not vendor then
        return nil, "Vendor required"
    end

    if not vendor.id then
        return nil, "Invalid vendor"
    end

    -- Main logic here
    return vendor, nil
end

-- Ternary-style (use sparingly)
local status = isActive and "active" or "inactive"
```

### Error Handling

```lua
-- Return multiple values for errors
function CreateVendor(data)
    if not data.name then
        return nil, "Name is required"
    end

    local vendor = { ... }
    return vendor, nil
end

-- Caller handles errors
local vendor, err = CreateVendor(data)
if not vendor then
    Whelp:Print("Error: " .. err)
    return
end

-- Use pcall for risky operations
local success, result = pcall(riskyFunction, arg1, arg2)
if not success then
    Whelp:Debug("Error: " .. tostring(result))
end
```

## WoW-Specific Patterns

### Frame Creation

```lua
-- Always use BackdropTemplate in TBC
local frame = CreateFrame("Frame", "GlobalName", parent, "BackdropTemplate")

-- Set up frame properties
frame:SetSize(width, height)
frame:SetPoint("CENTER")
frame:SetFrameStrata("HIGH")
frame:EnableMouse(true)

-- Enable dragging
frame:SetMovable(true)
frame:RegisterForDrag("LeftButton")
frame:SetScript("OnDragStart", frame.StartMoving)
frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
```

### Event Handling

```lua
-- Register events on frame
local eventFrame = CreateFrame("Frame")

eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")

eventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local addonName = ...
        if addonName == ADDON_NAME then
            OnAddonLoaded()
        end
    elseif event == "PLAYER_LOGIN" then
        OnPlayerLogin()
    end
end)
```

### Slash Commands

```lua
SLASH_MYADDON1 = "/cmd"
SLASH_MYADDON2 = "/alias"

SlashCmdList["MYADDON"] = function(msg)
    local args = {}
    for word in msg:gmatch("%S+") do
        table.insert(args, word:lower())
    end

    local cmd = args[1] or ""

    if cmd == "open" then
        OpenMainUI()
    elseif cmd == "help" then
        ShowHelp()
    else
        Whelp:Print("Unknown command. Type /cmd help")
    end
end
```

### SavedVariables

```lua
-- Initialize with defaults
function InitializeDB()
    if not MyAddonDB then
        MyAddonDB = DeepCopy(DefaultDB)
    else
        -- Merge new defaults
        MyAddonDB = MergeTables(DeepCopy(DefaultDB), MyAddonDB)
    end
end

-- Always access through functions for consistency
function GetSetting(key)
    return MyAddonDB.settings[key]
end

function SetSetting(key, value)
    MyAddonDB.settings[key] = value
end
```

## UI Patterns

### Tooltips

```lua
frame:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText("Title")
    GameTooltip:AddLine("Description", 1, 0.82, 0, true)
    GameTooltip:Show()
end)

frame:SetScript("OnLeave", function()
    GameTooltip:Hide()
end)
```

### Confirmation Dialogs

```lua
StaticPopupDialogs["MYADDON_CONFIRM"] = {
    text = "Are you sure?",
    button1 = "Yes",
    button2 = "No",
    OnAccept = function()
        DoConfirmedAction()
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
}

StaticPopup_Show("MYADDON_CONFIRM")
```

### Escape Key Closing

```lua
-- Add frame name to UISpecialFrames
tinsert(UISpecialFrames, "MyAddonFrame")
```

## Performance Guidelines

1. **Avoid creating tables in OnUpdate**: Pre-allocate or reuse tables
2. **Cache API calls**: Store frequently used results in locals
3. **Use frame pooling**: Reuse frames instead of creating/destroying
4. **Limit string concatenation**: Use string.format or table.concat
5. **Paginate large lists**: Don't render thousands of items at once

```lua
-- Bad: creates table every frame
frame:SetScript("OnUpdate", function()
    local data = {a = 1, b = 2}  -- New table every update!
end)

-- Good: reuse table
local updateData = {}
frame:SetScript("OnUpdate", function()
    wipe(updateData)
    updateData.a = 1
    updateData.b = 2
end)

-- Cache API calls
local GetTime = GetTime  -- Local lookup is faster
```
