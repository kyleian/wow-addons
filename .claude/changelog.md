# Changelog — WoW Addon Suite

All changes across all addons in this repository are logged here.
Format: `[YYYY-MM-DD] Addon vX.Y.Z — Description`

---

## 2026-02-22 (rev 3)

### Bugfix — Wrong WoW Client Directory
- Corrected `config.json` `clientDir` from `_classic_` (Cataclysm) to `_anniversary_` (TBC Anniversary)
- Updated `addonsPath` and `wtfPath` in config to match `_anniversary_` folder
- Redeployed all 5 addons to the correct client; confirmed TOCs visible in-game addon list
- Installed WeakAuras 5.21.2 + FojjiCore v1.6.7 + WeakAuras sub-addons from Yabba's folder into `_anniversary_`
- Patched all `## Interface: 20505` TOC lines to `20504` across WeakAuras family and existing anniversary addons

### SlyWeakAuras v1.0.0 — Initial Release
- New SlySuite sub-mod for managing WeakAura export-string packs
- Import packs via `WeakAuras.Import()` (shows native WA confirmation dialog)
- Capture installed auras from `WeakAurasSaved.displays` into named packs
- Ships with empty Foji stub packs (Core, Rogue, Hunter) — populate by pasting `!WA:2!` export strings
- Paste panel: name a pack + paste a `!WA:2!` string → [Store Pack] to save, [▶ Import to WA] to push to WeakAuras
- Slash: `/slywa` (toggle panel), `/slywa status`, `/slywa packs`
- Registered with SlySuite; standalone fallback included
- SavedVariables: `SlyWeakAurasDB`

---

## 2026-02-22 (rev 2)

### SlySuite v1.0.0 — Initial Release
- New top-level addon manager and error sandbox for all Sly-family addons
- Sub-mod registration API: `SlySuite_Register(name, version, initFn, options)`
- All sub-mod init calls wrapped in `xpcall` + `debugstack` — failures isolated per mod
- Per-mod enable/disable toggle persisted in `SlySuiteDB.subMods[name].enabled`
- Inline error viewer: click "Error ▾" on any failed row to see full stack trace
- Retry button: `/sly retry <name>` re-runs init without needing /reload
- Disable only affects future loads; `/reload` required to fully unload a running mod
- Slash commands: `/sly` (toggle), `/sly status`, `/sly retry <name>`, `/sly help`
- SavedVariables: `SlySuiteDB`

### ExtendedCharStats v1.0.1 — SlySuite Integration
- Added `## OptionalDependencies: SlySuite` to TOC (loads after SlySuite when present)
- ADDON_LOADED now calls `SlySuite_Register()` when SlySuite is available
- Standalone fallback preserved: works identically when SlySuite is not installed

---

## 2026-02-22

### ItemRackRevived v1.0.0 — Initial Release
- Created from scratch as a TBC-native replacement for the original ItemRack addon
- Draggable main panel (TSM-style, position persisted via SavedVariables)
- 19-slot gear display grid with live item icons and quality-colored borders
- Gear set save / load / delete with named sets
- Equip logic: scans bags for items and equips to correct slot
- Tooltip passthrough on slot hover (native GameTooltip)
- Slash command: `/itemrack` (toggle), `/itemrack help`
- SavedVariables: `ItemRackRevivedDB` (sets, position, options)
- ToS compliant: no automation, no external calls, player-initiated equips only

### GearScore v1.0.0 — Stub Created
- TOC and skeleton Lua created, targeting Interface 20504
- Tooltip hook registered for future item scoring logic

### ExtendedCharStats v1.0.0 — Stub Created
- TOC and skeleton Lua created, targeting Interface 20504
- Panel structure scaffolded for spell power, crit, hit, haste, expertise, resilience, armor pen

### Infrastructure
- `config.json` — master project config with addon registry and WoW paths
- `scripts/deploy.ps1` — deploys all enabled addons to `_anniversary_\Interface\AddOns`
- `scripts/backup-wtf.ps1` — snapshots WTF folder to `wtf-backups\YYYY-MM-DD_HHMMSS\`
- `.claude/project-context.md` — completed with full API reference and directory layout
- `.claude/addon-standards.md` — coding motif, ToS checklist, prompt template for new addons

---

## How to Add a Changelog Entry

When making changes, prepend a new section at the top:

```
## YYYY-MM-DD

### AddonName vX.Y.Z — Change Title
- Bullet point describing each change
- Reference ToS items if relevant
- Note any API compatibility concerns
```
