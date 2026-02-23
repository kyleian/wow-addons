# GitHub Copilot Session Context — WoW TBC Anniversary Addons

> Paste the block below into a new GitHub Copilot Chat session to resume where we left off.

---

## ► PASTE THIS TO START A NEW SESSION ◄

```
I am working on a set of World of Warcraft TBC Anniversary custom addons in VS Code.
Workspace root: D:\code\wow-addons
Deploy command: cd D:\code\wow-addons ; powershell -ExecutionPolicy Bypass -File scripts\deploy.ps1 -AddonName <Name>

--- CRITICAL TECHNICAL FACTS ---

Client: WoW TBC Anniversary, Interface 20505 (_anniversary_ client directory).
WoW install: C:\Program Files (x86)\World of Warcraft\_anniversary_
AddOns path: ...\Interface\AddOns
WTF path:    ...\WTF

C_Container is PRESENT on this client. Old globals PickupContainerItem /
GetContainerNumSlots / GetContainerItemID are no-ops. Every bag-API file uses a
shim block at the top (same pattern as real ItemRack):

    if C_Container then
        _PickupContainerItem  = C_Container.PickupContainerItem
        _GetContainerNumSlots = C_Container.GetContainerNumSlots
        _GetContainerItemID   = function(bag,slot)
            local info = C_Container.GetContainerItemInfo(bag,slot)
            return info and info.itemID or nil
        end
    else
        _PickupContainerItem  = PickupContainerItem
        ...
    end

Real ItemRack equip pattern (EquipCursorItem is WRONG; use this):
    _PickupContainerItem(bag, bslot)   -- pick up from bag
    PickupInventoryItem(destSlot)       -- swap into equip slot
Always guard with: if GetCursorInfo() or SpellIsTargeting() then return end

Weapon stones: SpellIsTargeting() is true while a stone's use-effect is pending.
Left-clicking a gear slot when SpellIsTargeting() calls PickupInventoryItem(slotId)
to apply the stone (handled in SlyCharUI.lua OnClick).

Shift+click a gear slot → SocketInventoryItem(slotId) (gem socketing).
Drag-start on gear slot → PickupInventoryItem(slotId) for trade/bank drag.

--- ADDON FAMILY: "Sly Suite" ---

All addons in D:\code\wow-addons\addons\<AddonName>\

SlyChar       — Primary character panel (C key / /slychar)
               D:\code\wow-addons\addons\SlyChar\SlyCharUI.lua  (~1600 lines)
               D:\code\wow-addons\addons\SlyChar\SlyChar.lua    (~170 lines)
               Frame: 732px wide, 462px tall, DIALOG strata, movable.
               Layout: CHAR_W=370 (gear slots + PlayerModel) | SIDE_W=330 (4 tabs)
                       BTN_STRIP_W=32 (icon button strip, far right)
               4 tabs in side panel: Stats · Sets · Rep · Skills
               Stats tab: base stats (Str/Agi/Sta/Int/Spi) + Armor, then feeds
                          ECS_GetStats() from ExtendedCharStats for extended stats.
               Sets tab: gear set manager UI backed by ItemRackRevived.
               Rep tab: scrollable 3-column list (Name | Standing | progress/max),
                        color-coded by standing, thin progress bar per row.
               Skills tab: scrollable skill list grouped by header.
               Strip buttons (far right, 32px): T (Talents wing) · Sp (Spellbook wing)
                 · Q (Quest Log) · M (World Map) · Fr (Friends) · PvP · G (Guild) · A (Achievements)
               Wing panel (SlyCharWingFrame, UIParent child, 360px wide):
                 Anchored TOPLEFT to SlyChar's TOPRIGHT. Toggle via SC_ToggleWing(key).
                 Talent wing: 3-tree tab bar, 4×7 icon grid per tree, click to LearnTalent,
                              hover tooltip via GameTooltip:SetTalent.
                 Spellbook wing: scrollable spell list grouped by spell book tab,
                                 hover tooltip via GameTooltip:SetSpellBookItem.

ItemRackRevived — Gear set CRUD (IRR_SaveCurrentSet / IRR_LoadSet / IRR_DeleteSet)
               D:\code\wow-addons\addons\ItemRackRevived\Sets.lua
               Uses C_Container shims. IRR_EquipItemInSlot uses correct
               PickupInventoryItem pattern (NOT EquipCursorItem).
               Save/Delete call SC_RefreshSets() to cross-refresh SlyChar panel.

ExtendedCharStats — Extended stat panel + ECS_GetStats() API used by SlyChar.
               D:\code\wow-addons\addons\ExtendedCharStats\ExtendedCharStats.lua
               Sections: OFFENSE · RANGED · SPELL · DEFENSE · CRUSH CAP
               Defense = UnitDefense("player") + GetCombatRatingBonus(CR.DEFENSE)
               CRUSH CAP section: Miss + Dodge + Parry + Block vs 102.4% threshold,
               crit-immune check at 490 defense. Color-coded green/red.

SlyRepair     — Auto-repair at merchants. /slyrepair
SlyLoot       — Master looter roll tracker. /slyloot
SlyMount      — Zone-aware random mount picker. /slymount
SlyItemizer   — Tooltip DPS delta + enchant/gem suggestions. /slyitem
SlyAtlasLoot  — AtlasLoot tooltip drop rates. /slyatlas
SlyWeakAuras  — WeakAura pack import/manage. /slywa
GearScore     — GearScore on tooltips.
SlySuite      — Top-level error sandbox frame.

--- CURRENT STATE / BACKLOG ---

All recently requested features are implemented and deployed:
✅ SlyChar 4-tab side panel (Stats/Sets/Rep/Skills) with scrollable content
✅ Rep tab — 3-column (name, standing, progress/max), correct values showing
✅ Stats tab — feeds ExtendedCharStats including CRUSH CAP section
✅ Gear picker — left-click toggle, C_Container-safe equip, drag support
✅ Gem socketing — shift+click gear slot → SocketInventoryItem
✅ Weapon stone support — SpellIsTargeting() guard on slot OnClick
✅ Sets tab — save/equip/delete all working; cross-refreshes SlyChar panel
✅ Quick-launch button strip (T/Sp/Q/M/Fr/PvP/G/A)
✅ Talent wing — fixed two bugs: (1) GameTooltip:SetTalent does NOT exist in TBC
               Anniversary; replaced with manual tooltip built from GetTalentInfo.
               (2) PLAYER_TALENT_UPDATE event now also calls SC_RefreshTalents() so
               the wing updates live after spending a point.
               Click-to-learn (LearnTalent) unchanged — it is correct and hardware-
               event gated via RegisterForClicks("LeftButtonUp").
✅ Spellbook wing — embedded scrollable list with tooltips
✅ Workspace copied to D:\code (C:\code had only 1GB free, D: has 1.2TB)

📋 BACKLOG:
- Warrior WeakAuras from wago.io (battle/commanding shout timers, rend tracker,
  cooldowns TBC). Must be manually searched at wago.io and pasted for import —
  wago.io blocks automated fetching.

--- CHARACTERS ---
Realm: Nightslayer
Characters: Slyw, Slysh
```
