# Project Context -- WoW Addon Suite

## Overview
Custom World of Warcraft **Burning Crusade Anniversary** addon suite.
Managed in this repository for source control, deployment automation, and persistent AI-assisted development.
New addons must comply with Blizzard's Addon Policy and the WoW Terms of Service.

## Game Environment
| Key | Value |
|-----|-------|
| Game | World of Warcraft: Burning Crusade Anniversary |
| Client | `_anniversary_` |
| Interface # | `20505` |
| Install Path | `C:\Program Files (x86)\World of Warcraft` |
| Addons Path | `C:\Program Files (x86)\World of Warcraft\_anniversary_\Interface\AddOns` |
| WTF Path | `C:\Program Files (x86)\World of Warcraft\_anniversary_\WTF` |
| Mod Manager | CurseForge (requires approval before public upload) |
| Dev/Test Environment | Local -- deploy via `scripts\deploy.ps1` |

## Characters
| Realm | Character | Notes |
|-------|-----------|-------|
| Nightslayer | Slyw | Primary |
| Nightslayer | Slysh | Alt |

## Addon Registry
| Addon | Folder | Slash Cmd | Status | Purpose |
|-------|--------|-----------|--------|---------|
| SlySuite | `addons\SlySuite` | `/sly` | Active | Addon manager + error sandbox; registers and sandboxes all sub-mods |
| ItemRackRevived | `addons\ItemRackRevived` | `/itemrack` | Active | Draggable gear set manager + character sheet integration |
| GearScore | `addons\GearScore` | `/gs` | Active | Per-item & total gear score on tooltips + character frame |
| ExtendedCharStats | `addons\ExtendedCharStats` | `/estats` | Active | Extended stats panel (spell power, crit, hit, haste, expertise, resilience, armor pen) |
| SlyWeakAuras | `addons\SlyWeakAuras` | `/slywa` | Active | SlySuite sub-mod: manage, import, and capture WeakAura export-string packs (e.g. Yabba/Foji suite) |

## Key Decisions
- All addons target interface `20504` (TBC 2.4.x / Anniversary)
- SavedVariables follow `AddonNameDB` naming convention
- All addons register `/addonname` slash commands (see registry above)
- UI is XML-less: pure Lua frame creation only -- no `.xml` files
- No external libraries: AceDB, LibStub, etc. are NOT used -- addons are fully self-contained
- Frames are draggable by default (StartMoving / StopMovingOrSizing pattern)
- Position persistence: frames save/restore their position via SavedVariables on PLAYER_LOGOUT
- Deploy: `scripts\deploy.ps1` copies addon folders to the WoW AddOns path
- WTF backup: `scripts\backup-wtf.ps1` snapshots the WTF folder

## Directory Layout
```
wow-addons/
|-- .claude/
|   |-- project-context.md       <- this file
|   |-- addon-standards.md       <- coding motif, conventions, ToS checklist
|   `-- changelog.md             <- version history across all addons
|-- addons/
|   |-- ItemRackRevived/
|   |-- GearScore/
|   `-- ExtendedCharStats/
|-- scripts/
|   |-- deploy.ps1
|   `-- backup-wtf.ps1
`-- config.json
```

## WoW TBC API Reference (Interface 20504)

### Equipment Slot IDs
```
AMMO=0, HEAD=1, NECK=2, SHOULDER=3, SHIRT=4, CHEST=5, WAIST=6,
LEGS=7, FEET=8, WRIST=9, HANDS=10, FINGER0=11, FINGER1=12,
TRINKET0=13, TRINKET1=14, BACK=15, MAINHAND=16, OFFHAND=17,
RANGED=18, TABARD=19
```

### Key API Functions
```lua
GetInventorySlotInfo(slotName)           -- returns slotId, textureName
GetInventoryItemID(unit, slotId)         -- returns itemId or nil
GetInventoryItemLink(unit, slotId)       -- returns itemLink or nil
GetItemInfo(itemIdOrLink)                -- name, link, quality, level, type, subtype, stackCount, equipLoc, texture
GetItemStats(itemLink, statTable)        -- populates statTable with stat keys
UnitStat(unit, statIndex)                -- base + effective stat values
UnitAttackPower(unit)                    -- returns base, posBuff, negBuff
UnitSpellHaste(unit)                     -- returns haste %
GetCombatRating(ratingId)                -- CR_* constants
GetCombatRatingBonus(ratingId)           -- returns % bonus from rating
```

### Item Quality Colors
```lua
ITEM_QUALITY_COLORS[quality].hex  -- "ff9d9d9d" (Poor) through "ffe6cc80" (Legendary)
-- quality: 0=Poor 1=Common 2=Uncommon 3=Rare 4=Epic 5=Legendary
```

### Frame Strata Order
`BACKGROUND < LOW < MEDIUM < HIGH < DIALOG < FULLSCREEN < FULLSCREEN_DIALOG < TOOLTIP`

## ToS / Policy Summary
See `.claude/addon-standards.md` for the full checklist. Core rules:
- No automation of player actions (no bot behavior, no auto-casting without explicit player input)
- No reading memory outside the Lua API
- No external network calls (no HTTP, no external sockets)
- Addon code must not be obfuscated
- Must not gather data on other players beyond what the API exposes
- All addons must be free to use