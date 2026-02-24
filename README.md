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

## Suite management

All addons are controlled through the **SlySuite** panel (`/sly`). Each sub-addon registers itself with SlySuite; from the panel you can:

- **Toggle** any sub-addon on/off at runtime
- See **status** (OK / Error / Disabled / Loading) per addon
- View **error details** and retry failed addons
- Open any addon's panel directly via its **Open ▶** button

Disabling an addon in the panel suppresses its initialization — a full `/reload` is needed to truly unload its code from memory (same behaviour as DBM modules).

## Installation

### Option A — GitHub Releases (recommended, no CurseForge needed)

1. Go to the [Releases page](../../releases) and click the latest release
2. Under **Assets**, download `SlySuite-x.x.x.zip`
3. Extract the zip — you'll get a folder called `SlySuite-x.x.x/` containing all the `Sly*` addon folders inside it
4. Copy **the contents** of that folder (all the `Sly*` folders) into your AddOns directory:

   **Windows (most common):**
   ```
   C:\Program Files (x86)\World of Warcraft\_anniversary_\Interface\AddOns\
   ```
   After copying it should look like:
   ```
   AddOns\
     SlySuite\
     SlyChar\
     SlyBag\
     SlyMount\
     ... etc
   ```
5. Launch (or reload) WoW — you should see **Sly Suite** in your addon list
6. Type `/sly` in-game to open the suite manager and enable/disable individual modules

> **Tip:** If you see "Out of date" warnings in the addon list, tick **"Load out of date AddOns"** — TBC Anniversary sometimes bumps the interface version between patches.

---

### Option B — CurseForge App

Install via the CurseForge desktop app by searching for **Sly Suite** in the WoW addon browser.

---

### Option C — Manual (from source)

```bash
git clone https://github.com/kyleian/wow-addons.git
```
Then copy all folders from `addons/` into your AddOns directory (same destination as above).

## Releasing

Tag a commit to trigger the GitHub Action, which automatically builds `SlySuite-{tag}.zip` and attaches it to a GitHub Release:

```bash
git tag -a "1.0.0" -m "Release 1.0.0"
git push origin 1.0.0
```

To also publish to CurseForge automatically, add two repo secrets (**Settings → Secrets → Actions**):

| Secret | Value |
|---|---|
| `CF_API_KEY` | Your CurseForge API token (authors.curseforge.com → My API Tokens) |
| `CF_PROJECT_ID` | Numeric project ID from your CurseForge project URL |

## License

All original **Sly\*** addons are released under [MIT License](LICENSE).  
Remixed addons (ExtendedCharStats, GearScore, ItemRackRevived) retain their original authors' licenses.
