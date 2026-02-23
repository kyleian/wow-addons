# Addon Standards & Motif
## WoW TBC Anniversary — AI-Assisted Development Guide

This document defines the standard pattern for every addon in this repository.
Any user (or AI assistant) reading this file can generate new, ToS-compliant addons that match the established conventions.

---

## 1. File Structure Template

```
addons/<AddonName>/
    <AddonName>.toc          <- required: TOC descriptor
    <AddonName>.lua          <- required: core init, events, saved vars, slash commands
    UI.lua                   <- main frame construction
    Sets.lua                 <- (if applicable) data management layer
```

Only add more files if the addon genuinely needs them. Keep the footprint small.

---

## 2. TOC File Template

```
## Interface: 20504
## Title: My Addon Name
## Notes: Short one-line description of what this addon does.
## Version: 1.0.0
## Author: Custom
## SavedVariables: MyAddonNameDB

MyAddonName.lua
UI.lua
```

Rules:
- `Interface` MUST be `20504` for TBC Anniversary
- `Title` is the display name shown in the AddOns list
- `SavedVariables` uses `AddonNameDB` -- one global table per addon
- Files are listed in load order; core init always loads first

---

## 3. Core Lua Template (`<AddonName>.lua`)

```lua
-- ============================================================
-- <AddonName> — <Short description>
-- Interface: 20504 (WoW TBC Anniversary)
-- ============================================================

local ADDON_NAME = "AddonName"
local ADDON_VERSION = "1.0.0"

-- Default saved variable structure
local DB_DEFAULTS = {
    enabled = true,
    position = { point="CENTER", x=0, y=0 },
    -- add addon-specific keys here
}

-- Merge defaults into saved data (non-destructive)
local function ApplyDefaults(saved, defaults)
    for k, v in pairs(defaults) do
        if saved[k] == nil then
            if type(v) == "table" then
                saved[k] = {}
                ApplyDefaults(saved[k], v)
            else
                saved[k] = v
            end
        end
    end
end

-- Addon event frame
local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_LOGOUT")

f:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local name = ...
        if name == ADDON_NAME then
            -- Initialize saved variables
            AddonNameDB = AddonNameDB or {}
            ApplyDefaults(AddonNameDB, DB_DEFAULTS)
            -- Post-load init
            AddonName_Init()
        end
    elseif event == "PLAYER_LOGOUT" then
        AddonName_OnLogout()
    end
end)

function AddonName_Init()
    -- Register additional events, build UI, etc.
    AddonName_BuildUI()
    print("|cff00ccff[AddonName]|r v" .. ADDON_VERSION .. " loaded. Type /addonname for help.")
end

function AddonName_OnLogout()
    -- Persist frame position
    if AddonNameFrame and AddonNameFrame:IsShown() then
        local point, _, _, x, y = AddonNameFrame:GetPoint()
        AddonNameDB.position = { point=point, x=x, y=y }
    end
end

-- Slash commands
SLASH_ADDONNAME1 = "/addonname"
SlashCmdList["ADDONNAME"] = function(msg)
    msg = msg:lower():trim()
    if msg == "show" or msg == "" then
        AddonName_ToggleUI()
    elseif msg == "help" then
        print("|cff00ccff[AddonName]|r Commands:")
        print("  /addonname          -- toggle window")
        print("  /addonname help     -- this text")
    end
end
```

---

## 4. UI / Frame Conventions

### Draggable Frame Pattern
Every main window MUST be draggable using this pattern:

```lua
local frame = CreateFrame("Frame", "AddonNameFrame", UIParent, "BasicFrameTemplateWithInset")
frame:SetSize(400, 500)
frame:SetMovable(true)
frame:EnableMouse(true)
frame:RegisterForDrag("LeftButton")
frame:SetScript("OnDragStart", frame.StartMoving)
frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
frame:SetFrameStrata("DIALOG")
frame:Hide()

-- Restore saved position
local pos = AddonNameDB.position
frame:ClearAllPoints()
frame:SetPoint(pos.point or "CENTER", UIParent, pos.point or "CENTER", pos.x or 0, pos.y or 0)
```

### Color Constants
```lua
local COLOR = {
    HEADER  = {r=0.13, g=0.13, b=0.13, a=0.95},
    BG      = {r=0.07, g=0.07, b=0.07, a=0.9},
    BORDER  = {r=0.3,  g=0.3,  b=0.3,  a=1.0},
    GOLD    = {r=1.0,  g=0.82, b=0.0},
    TEXT    = {r=0.9,  g=0.9,  b=0.9},
    GREEN   = {r=0.2,  g=0.9,  b=0.2},
    RED     = {r=0.9,  g=0.2,  b=0.2},
}
```

### Helper: SetBackdrop-style background (TBC compatible)
```lua
local function SetPanelBackground(frame, r, g, b, a)
    frame:SetBackdrop({
        bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 16,
        insets = { left=4, right=4, top=4, bottom=4 },
    })
    frame:SetBackdropColor(r, g, b, a or 0.9)
end
```

---

## 5. SavedVariables Conventions

| Pattern | Usage |
|---------|-------|
| `AddonNameDB` | Top-level global, always one table |
| `AddonNameDB.sets` | Named data collections (gear sets, profiles, etc.) |
| `AddonNameDB.position` | Frame position: `{point, x, y}` |
| `AddonNameDB.options` | Runtime toggles / user preferences |
| `AddonNameDB.enabled` | Boolean master enable switch |

Never nest more than 3 levels deep. Flat tables are faster and easier to debug.

---

## 6. Event Handling Pattern

```lua
-- Always register events on a dedicated frame, not GameTooltip or other shared frames
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("UNIT_INVENTORY_CHANGED")
eventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_ENTERING_WORLD" then
        -- handle world entry
    elseif event == "UNIT_INVENTORY_CHANGED" then
        local unit = ...
        if unit == "player" then
            -- refresh gear display
        end
    end
end)
```

---

## 7. Tooltip Hooks

```lua
-- Safe tooltip hook (does not break other addons)
local origTooltipSetItem = GameTooltip:GetScript("OnTooltipSetItem")
GameTooltip:HookScript("OnTooltipSetItem", function(self)
    local name, link = self:GetItem()
    if not link then return end
    -- add lines to tooltip
    self:AddLine("My addon info here", 1, 1, 0)
    self:Show()
end)
```

---

## 8. Terms of Service Compliance Checklist

Before committing or uploading any addon, verify:

- [ ] No `RunScript()` calls with user-provided or dynamically constructed strings
- [ ] No `SendAddonMessage` calls to external services (only WoW guild/party/raid channels are ok)
- [ ] No automated casting, movement, or interaction without player input on each action
- [ ] No `loadstring()` or obfuscated code paths
- [ ] No reading/writing to files outside SavedVariables (`WriteFile` / file I/O APIs do not exist in WoW Lua -- this is a non-issue but never add hypothetical file access)
- [ ] No scraping or storing other players' data beyond standard inspection (tooltip / inspect API)
- [ ] Addon does not speed up GCDs, cooldowns, or casting sequences
- [ ] Addon does not auto-respond in chat without player triggering it
- [ ] SavedVariables do not store real-money economy data or auction prices for resale/exploit
- [ ] All slash commands produce visible feedback so the player understands what happened

---

## 9. Naming Conventions

| Thing | Convention | Example |
|-------|-----------|---------|
| Addon folder | PascalCase | `ItemRackRevived` |
| Global functions | `AddonName_FunctionName` | `ItemRack_SaveSet` |
| Local functions | camelCase | `buildSlotIcon` |
| Constants | UPPER_SNAKE | `SLOT_HEAD` |
| SavedVariables key | camelCase | `AddonNameDB.savedSets` |
| Frame names | `AddonNameFrameName` | `ItemRackRevivedFrame` |
| Events | UPPER_SNAKE (WoW standard) | `UNIT_INVENTORY_CHANGED` |

---

## 10. How to Prompt Claude for a New Addon

When starting a new addon, include this context in your prompt:

```
Context: WoW TBC Anniversary addon, Interface 20504.
No external libs. Pure Lua, no XML. SavedVariables: <AddonName>DB.
Follow standards in .claude/addon-standards.md.
Draggable frame using StartMoving/StopMovingOrSizing.
Slash command: /<shortname>

Goal: <describe what the addon does>
```

The AI will follow the patterns in this file to produce a compliant, self-contained addon.
