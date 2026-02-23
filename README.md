# Sly WoW Addons

A suite of custom World of Warcraft addons for **TBC Anniversary** (Interface 20505), built around the **SlySuite** addon family.

## Addons

| Addon | Description |
|---|---|
| **SlySuite** | Addon manager and error sandbox for the Sly family. `/sly` |
| **SlyChar** | Enhanced character sheet — gear picker, stats, gear sets, reputation, skills, honor. `/slychar` |
| **SlyBag** | Unified bag window — all bags in one view with search. `/slybag` |
| **SlyLoot** | Master looter assistant — announces drops, tracks /roll, declares winners. `/slyloot` |
| **SlyMount** | Favourite mounts list with random-pick keybind, zone-aware. `/slymount` |
| **SlyRepair** | Auto-repair at any merchant and reports the cost. `/slyrepair` |
| **SlySlot** | Action bar profile manager — save/load/export/import bar layouts. `/slyslot` |
| **SlyUF** | Clean unit frames — player, target, target-of-target, party. `/slyuf` |
| **SlyItemizer** | Item comparison with DPS score delta and enchant/gem suggestions. `/slyitem` |
| **SlyMetrics** | Damage + threat meter in one draggable window. `/slymetrics` |
| **SlyAtlasLoot** | AtlasLoot drop-rate integration — tooltip %, target-aware rates, item search. |
| **SlyWeakAuras** | WeakAura package manager — import/capture Foji-suite style packages. `/slywa` |

## Requirements

- World of Warcraft: TBC Anniversary (Interface 20505)
- Optional: [AtlasLootClassic](https://www.curseforge.com/wow/addons/atlaslootclassic) for SlyAtlasLoot
- Optional: [WeakAuras 2](https://www.curseforge.com/wow/addons/weakauras-2) for SlyWeakAuras
- Optional: ItemRackRevived for SlyChar gear sets / SlyItemizer

## Installation

### From CurseForge / GitHub Releases
Download the latest zip from the [Releases](../../releases) page and extract to:
```
World of Warcraft\_anniversary_\Interface\AddOns\
```

### Manual
Clone this repo and copy the addon folders from `addons/` into your AddOns directory.

## Releasing

Releases are automated via GitHub Actions using the [BigWigs Packager](https://github.com/BigWigsMods/packager). Tag a commit to trigger a build:

```bash
git tag -a "1.0.0" -m "Release 1.0.0"
git push origin 1.0.0
```

Each addon is packaged and uploaded to CurseForge automatically (requires `CF_API_KEY` secret set in the repo settings).

## License

All original **Sly\*** addons are released under [MIT License](LICENSE).  
Remixed addons (ExtendedCharStats, GearScore, ItemRackRevived) retain their original authors' licenses.
