# ============================================================
# update-bis.ps1  — Wowhead TBC BIS scraper
# Generates addons/ItemRackRevived/BIS_Data.lua
#
# Usage:
#   powershell -ExecutionPolicy Bypass -File scripts/update-bis.ps1
#   powershell -ExecutionPolicy Bypass -File scripts/update-bis.ps1 -Spec fury
#   powershell -ExecutionPolicy Bypass -File scripts/update-bis.ps1 -Phase 5
# ============================================================

param(
    [string]$Spec  = "",     # empty = all specs
    [int]   $Phase = 0,      # 0 = all phases
    [switch]$Dry               # dry run: print but don't write file
)

Set-StrictMode -Off
$ErrorActionPreference = "Continue"

$BASE_URL  = "https://www.wowhead.com"
$UA        = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"
$OUT_FILE  = Join-Path $PSScriptRoot "..\addons\ItemRackRevived\BIS_Data.lua"

# -- WoW slot-id map ----------------------------------------------------------
$SLOT_ID = @{
    "head"       = 1;  "neck"      = 2;  "shoulder"  = 3;  "shoulders" = 3
    "back"       = 15; "cloak"     = 15; "chest"     = 5;  "body"      = 5
    "wrist"      = 9;  "wrists"    = 9;  "bracer"    = 9;  "bracers"   = 9
    "hands"      = 10; "gloves"    = 10; "waist"     = 6;  "belt"      = 6
    "legs"       = 7;  "leggings"  = 7;  "pants"     = 7
    "feet"       = 8;  "boots"     = 8;  "shoes"     = 8
    "finger"     = 11; "ring"      = 11; "ring 1"    = 11; "finger 1"  = 11
    "ring 2"     = 12; "finger 2"  = 12
    "trinket"    = 13; "trinket 1" = 13
    "trinket 2"  = 14
    "hand"       = 10; "leg"       = 7;  "trinkets"  = 13
    "main-hand"  = 16; "mainhand"  = 16; "one-hand"  = 16; "weapon"     = 16
    "main hand"  = 16; "main"      = 16
    "two-hand"   = 16; "two-handed"= 16; "staff"     = 16; "polearm"   = 16
    "off-hand"   = 17; "offhand"   = 17; "shield"    = 17
    "off hand"   = 17; "off"       = 17
    "ranged"     = 18; "wand"      = 18; "bow"       = 18; "gun"       = 18
    "thrown"     = 18; "crossbow"  = 18
}

# -- Spec definitions ---------------------------------------------------------
# key = scraper key  class/spec/role/tab for WoW detection
$SPECS = @(
    @{key="fury_warrior";        class="WARRIOR"; spec="fury";          specTab=2; role="melee_dps";  label="Fury Warrior";         slug="fury-warrior-dps";            p2Path="classes/warrior/fury/dps-bis-gear-pve-phase-2";           preRaidPath="classes/warrior/dps-bis-gear-pve-pre-raid"}
    @{key="arms_warrior";        class="WARRIOR"; spec="arms";          specTab=1; role="melee_dps";  label="Arms Warrior";          slug="arms-warrior-dps";            p2Path="classes/warrior/arms/dps-bis-gear-pve-phase-2";           preRaidPath="classes/warrior/dps-bis-gear-pve-pre-raid"}
    @{key="prot_warrior";        class="WARRIOR"; spec="protection";    specTab=3; role="tank";       label="Prot Warrior";          slug="protection-warrior-tank";     p2Path="classes/warrior/protection/tank-bis-gear-pve-phase-2";   preRaidPath=""}  # no pre-raid guide
    @{key="holy_paladin";        class="PALADIN"; spec="holy";          specTab=1; role="healer";     label="Holy Paladin";          slug="holy-paladin-healer";         p2Path="classes/paladin/holy/healer-bis-gear-pve-phase-2";       preRaidPath=""}  # no pre-raid guide
    @{key="prot_paladin";        class="PALADIN"; spec="protection";    specTab=2; role="tank";       label="Prot Paladin";          slug="paladin-tank";                p2Path="";                                                        preRaidPath="classes/paladin/tank-bis-gear-pve-pre-raid"}  # no TBC P2 guide
    @{key="ret_paladin";         class="PALADIN"; spec="retribution";   specTab=3; role="melee_dps";  label="Ret Paladin";           slug="retribution-paladin-dps";    p2Path="classes/paladin/retribution/dps-bis-gear-pve-phase-2";  preRaidPath=""}  # no pre-raid guide
    @{key="bm_hunter";           class="HUNTER";  spec="beast_mastery"; specTab=1; role="ranged_dps"; label="BM Hunter";             slug="beast-mastery-hunter-dps";   p2Path="classes/hunter/beast-mastery/dps-bis-gear-pve-phase-2"; preRaidPath="classes/hunter/dps-bis-gear-pve-pre-raid"}
    @{key="mm_hunter";           class="HUNTER";  spec="marksmanship";  specTab=2; role="ranged_dps"; label="MM Hunter";             slug="marksmanship-hunter-dps";    p2Path="classes/hunter/marksmanship/dps-bis-gear-pve-phase-2";  preRaidPath="classes/hunter/dps-bis-gear-pve-pre-raid"}
    @{key="surv_hunter";         class="HUNTER";  spec="survival";      specTab=3; role="ranged_dps"; label="Survival Hunter";       slug="survival-hunter-dps";        p2Path="classes/hunter/survival/dps-bis-gear-pve-phase-2";       preRaidPath="classes/hunter/dps-bis-gear-pve-pre-raid"}
    @{key="combat_rogue";        class="ROGUE";   spec="combat";        specTab=2; role="melee_dps";  label="Combat Rogue";          slug="rogue-dps";                  p2Path="";                                                        preRaidPath="classes/rogue/dps-bis-gear-pve-pre-raid"}  # no TBC P2 guide
    @{key="shadow_priest";       class="PRIEST";  spec="shadow";        specTab=3; role="caster_dps"; label="Shadow Priest";         slug="shadow-priest-dps";          p2Path="classes/priest/shadow/dps-bis-gear-pve-phase-2";         preRaidPath="classes/priest/shadow/dps-bis-gear-pve-pre-raid"}
    @{key="holy_priest";         class="PRIEST";  spec="holy";          specTab=2; role="healer";     label="Holy Priest";           slug="priest-healer";              p2Path="";                                                        preRaidPath="classes/priest/healer-bis-gear-pve-pre-raid"}  # no TBC P2 guide
    @{key="elemental_shaman";    class="SHAMAN";  spec="elemental";     specTab=1; role="caster_dps"; label="Elemental Shaman";      slug="elemental-shaman-dps";       p2Path="classes/shaman/elemental/dps-bis-gear-pve-phase-2";      preRaidPath="classes/shaman/elemental/dps-bis-gear-pve-pre-raid"}
    @{key="enhance_shaman";      class="SHAMAN";  spec="enhancement";   specTab=2; role="melee_dps";  label="Enhance Shaman";        slug="enhancement-shaman-dps";     p2Path="classes/shaman/enhancement/dps-bis-gear-pve-phase-2";   preRaidPath="classes/shaman/enhancement/dps-bis-gear-pve-pre-raid"}
    @{key="resto_shaman";        class="SHAMAN";  spec="restoration";   specTab=3; role="healer";     label="Resto Shaman";          slug="shaman-healer";              p2Path="";                                                        preRaidPath="classes/shaman/healer-bis-gear-pve-pre-raid"}  # no TBC P2 guide
    @{key="arcane_mage";         class="MAGE";    spec="arcane";        specTab=1; role="caster_dps"; label="Arcane Mage";           slug="arcane-mage-dps";            p2Path="classes/mage/arcane/dps-bis-gear-pve-phase-2";           preRaidPath="classes/mage/dps-bis-gear-pve-pre-raid"}
    @{key="fire_mage";           class="MAGE";    spec="fire";          specTab=2; role="caster_dps"; label="Fire Mage";             slug="fire-mage-dps";              p2Path="classes/mage/fire/dps-bis-gear-pve-phase-2";             preRaidPath="classes/mage/dps-bis-gear-pve-pre-raid"}
    @{key="frost_mage";          class="MAGE";    spec="frost";         specTab=3; role="caster_dps"; label="Frost Mage";            slug="frost-mage-dps";             p2Path="classes/mage/frost/dps-bis-gear-pve-phase-2";            preRaidPath="classes/mage/dps-bis-gear-pve-pre-raid"}
    @{key="affliction_warlock";  class="WARLOCK"; spec="affliction";    specTab=1; role="caster_dps"; label="Affliction Warlock";    slug="affliction-warlock-dps";     p2Path="classes/warlock/affliction/dps-bis-gear-pve-phase-2";   preRaidPath="classes/warlock/dps-bis-gear-pve-pre-raid"}
    @{key="destro_warlock";      class="WARLOCK"; spec="destruction";   specTab=3; role="caster_dps"; label="Destro Warlock";        slug="destruction-warlock-dps";    p2Path="classes/warlock/destruction/dps-bis-gear-pve-phase-2";  preRaidPath="classes/warlock/dps-bis-gear-pve-pre-raid"}
    @{key="demo_warlock";        class="WARLOCK"; spec="demonology";    specTab=2; role="caster_dps"; label="Demo Warlock";          slug="demonology-warlock-dps";     p2Path="classes/warlock/demonology/dps-bis-gear-pve-phase-2";   preRaidPath="classes/warlock/dps-bis-gear-pve-pre-raid"}
    @{key="balance_druid";       class="DRUID";   spec="balance";       specTab=1; role="caster_dps"; label="Balance Druid";         slug="balance-druid-dps";          p2Path="classes/druid/balance/dps-bis-gear-pve-phase-2";         preRaidPath="classes/druid/balance/dps-bis-gear-pve-pre-raid"}
    @{key="feral_dps_druid";     class="DRUID";   spec="feral";         specTab=2; role="melee_dps";  label="Feral DPS Druid";       slug="feral-druid-dps";            p2Path="classes/druid/feral/dps-bis-gear-pve-phase-2";           preRaidPath="classes/druid/feral/dps-bis-gear-pve-pre-raid"}
    @{key="feral_tank_druid";    class="DRUID";   spec="feral_tank";    specTab=2; role="tank";       label="Feral Tank Druid";      slug="feral-druid-tank";           p2Path="classes/druid/feral/tank-bis-gear-pve-phase-2";          preRaidPath="classes/druid/feral/tank-bis-gear-pve-pre-raid"}
    @{key="resto_druid";         class="DRUID";   spec="restoration";   specTab=3; role="healer";     label="Resto Druid";           slug="druid-healer";               p2Path="";                                                        preRaidPath="classes/druid/healer-bis-gear-pve-pre-raid"}  # no TBC P2 guide
)

# Phase URL suffixes to try (in order)  P2 is handled per-spec via p2Path
$PHASE_SUFFIXES = @{
    1 = @(
        "-karazhan-best-in-slot-gear-burning-crusade-classic-wow"
        "-karazhan-best-in-slot-gear-burning-crusade"
    )
    3 = @(
        "-bt-hyjal-phase-3-best-in-slot-gear-burning-crusade"
        "-black-temple-hyjal-phase-3-best-in-slot-gear-burning-crusade"
    )
    4 = @(
        "-za-phase-4-best-in-slot-gear-burning-crusade"
        "-zul-aman-phase-4-best-in-slot-gear-burning-crusade"
    )
    5 = @(
        "-swp-phase-5-best-in-slot-gear-burning-crusade"
        "-sunwell-plateau-phase-5-best-in-slot-gear-burning-crusade"
    )
}

# Phase → short source label written into data files (fallback when per-item lookup fails)
$PHASE_SRC = @{
    0 = "Pre-Raid"   # Phase 0: Pre-raid best-in-slot
    1 = "Kara/T4"    # Phase 1: Karazhan, Gruul's Lair, Magtheridon
    2 = "SSC/TK"     # Phase 2: Serpentshrine Cavern, The Eye
    3 = "BT/Hyjal"   # Phase 3: Black Temple, Mount Hyjal
    4 = "ZA"         # Phase 4: Zul'Aman
    5 = "SWP"        # Phase 5: Sunwell Plateau
}

# Boss / mob name (lowercase substring) → short source name
# Used with the fast XML endpoint that returns sourcemore.n = boss/mob name
$BOSS_SRC = [ordered]@{
    # ── Karazhan ──────────────────────────────────────────────────────────────
    "attumen"                = "Kara"
    "moroes"                 = "Kara"
    "maiden of virtue"       = "Kara"
    "the curator"            = "Kara"
    "shade of aran"          = "Kara"
    "terestian illhoof"      = "Kara"
    "netherspite"            = "Kara"
    "nightbane"              = "Kara"
    "prince malchezaar"      = "Kara"
    "the big bad wolf"       = "Kara"
    "romulo"                 = "Kara"
    "julianne"               = "Kara"
    "the crone"              = "Kara"
    "dorothee"               = "Kara"
    "opera"                  = "Kara"
    "chess"                  = "Kara"
    # ── Gruul's Lair ──────────────────────────────────────────────────────────
    "gruul the dragonkiller" = "Gruul"
    "gruul"                  = "Gruul"
    "high king maulgar"      = "Gruul"
    "maulgar"                = "Gruul"
    # ── Magtheridon's Lair ────────────────────────────────────────────────────
    "magtheridon"            = "Mag"
    # ── Serpentshrine Cavern (SSC) ────────────────────────────────────────────
    "hydross the unstable"   = "SSC"
    "hydross"                = "SSC"
    "the lurker below"       = "SSC"
    "lurker"                 = "SSC"
    "leotheras the blind"    = "SSC"
    "leotheras"              = "SSC"
    "fathom-lord karathress" = "SSC"
    "karathress"             = "SSC"
    "morogrim tidewalker"    = "SSC"
    "morogrim"               = "SSC"
    "lady vashj"             = "SSC"
    "vashj"                  = "SSC"
    # ── The Eye / Tempest Keep (TK) ───────────────────────────────────────────
    "al'ar"                  = "TK"
    "void reaver"            = "TK"
    "high astromancer solarian" = "TK"
    "solarian"               = "TK"
    "kael'thas sunstrider"   = "TK"
    "kael'thas"              = "TK"
    "kaelthas"               = "TK"
    # ── Mount Hyjal ───────────────────────────────────────────────────────────
    "rage winterchill"       = "Hyjal"
    "winterchill"            = "Hyjal"
    "anetheron"              = "Hyjal"
    "kaz'rogal"              = "Hyjal"
    "azgalor"                = "Hyjal"
    "archimonde"             = "Hyjal"
    # ── Black Temple (BT) ─────────────────────────────────────────────────────
    "high warlord naj'entus" = "BT"
    "naj'entus"              = "BT"
    "supremus"               = "BT"
    "shade of akama"         = "BT"
    "teron gorefiend"        = "BT"
    "gorefiend"              = "BT"
    "gurtogg bloodboil"      = "BT"
    "bloodboil"              = "BT"
    "reliquary of souls"     = "BT"
    "reliquary"              = "BT"
    "mother shahraz"         = "BT"
    "shahraz"                = "BT"
    "illidari council"       = "BT"
    "illidan stormrage"      = "BT"
    "illidan"                = "BT"
    # ── Zul'Aman (ZA) ─────────────────────────────────────────────────────────
    "nalorakk"               = "ZA"
    "akil'zon"               = "ZA"
    "jan'alai"               = "ZA"
    "halazzi"                = "ZA"
    "hex lord malacrass"     = "ZA"
    "malacrass"              = "ZA"
    "zul'jin"                = "ZA"
    # ── Sunwell Plateau (SWP) ─────────────────────────────────────────────────
    "kalecgos"               = "SWP"
    "sathrovarr the corruptor" = "SWP"
    "brutallus"              = "SWP"
    "felmyst"                = "SWP"
    "eredar twins"           = "SWP"
    "grand warlock alythess" = "SWP"
    "lady sacrolash"         = "SWP"
    "m'uru"                  = "SWP"
    "entropius"              = "SWP"
    "kil'jaeden"             = "SWP"
    # ── Outland Heroic/Normal Dungeons ────────────────────────────────────────
    # The Botanica
    "laj"                    = "Botanica"
    "thorngrin the tender"   = "Botanica"
    "high botanist freywinn" = "Botanica"
    "warp splinter"          = "Botanica"
    # The Mechanar
    "capacitus"              = "Mechanar"
    "nethermancer sepethrea" = "Mechanar"
    "pathaleon the calculator" = "Mechanar"
    # The Arcatraz
    "zereketh the unbound"   = "Arcatraz"
    "dalliah the doomsayer"  = "Arcatraz"
    "wrath-scryer soccothrates" = "Arcatraz"
    "harbinger skyriss"      = "Arcatraz"
    "millhouse manastorm"    = "Arcatraz"
    # Shadow Labyrinth
    "ambassador hellmaw"     = "Shadow Lab"
    "blackheart the inciter" = "Shadow Lab"
    "grandmaster vorpil"     = "Shadow Lab"
    "murmur"                 = "Shadow Lab"
    # Shattered Halls
    "blood guard porung"     = "Sh. Halls"
    "grand warlock nethekurse" = "Sh. Halls"
    "shattered hand executioner" = "Sh. Halls"
    "warchief kargath bladefist" = "Sh. Halls"
    "kargath bladefist"      = "Sh. Halls"
    # The Steam Vaults
    "hydromancer thespia"    = "Steam Vault"
    "mekgineer steamrigger"  = "Steam Vault"
    "warlord kalithresh"     = "Steam Vault"
    # The Slave Pens
    "mennu the betrayer"     = "Slave Pens"
    "rokmar the crackler"    = "Slave Pens"
    "quagmirran"             = "Slave Pens"
    # The Underbog
    "hungarfen"              = "Underbog"
    "ghaz'an"                = "Underbog"
    "swamplord musel'ek"     = "Underbog"
    "the black stalker"      = "Underbog"
    # Sethekk Halls
    "darkweaver syth"        = "Sethekk"
    "anzu"                   = "Sethekk"
    "talon king ikiss"       = "Sethekk"
    # Mana-Tombs
    "pandemonius"            = "Mana-Tombs"
    "tavarok"                = "Mana-Tombs"
    "nexus-prince shaffar"   = "Mana-Tombs"
    # Auchenai Crypts
    "shirrak the dead watcher" = "Auchenai"
    "exarch maladaar"        = "Auchenai"
    # Old Hillsbrad / Black Morass (Caverns of Time)
    "lieutenant drake"       = "Old Hill."
    "captain skarloc"        = "Old Hill."
    "epoch hunter"           = "Black Morass"
    "chrono lord deja"       = "Black Morass"
    "temporus"               = "Black Morass"
    # Hellfire Citadel (Ramparts / Blood Furnace / Shattered Halls)
    "watchkeeper gargolmar"  = "Ramparts"
    "omor the unscarred"     = "Ramparts"
    "vazruden"               = "Ramparts"
    "nazan"                  = "Ramparts"
    "the maker"              = "Blood Furnace"
    "broggok"                = "Blood Furnace"
    "keli'dan the breaker"   = "Blood Furnace"
    # Coilfang: Slave Pens / Underbog already covered above
    # Auchindoun: already covered above
}

# XML sourcemore "z" field → short instance name
# (These zone IDs come from empirical testing of the Wowhead item XML endpoint)
$XML_ZONE_SRC = @{
    # ── TBC Raids ─────────────────────────────────────────────────────────────
    3457 = "Kara"       # Karazhan - upper (Prince Malchezaar area)
    3959 = "BT"         # Black Temple (Illidan, Mother Shahraz, etc.)
    3606 = "Hyjal"      # Mount Hyjal (Archimonde, Anetheron, etc.) — NOT Kara!
    3607 = "SSC"        # Serpentshrine Cavern
    3845 = "TK"         # The Eye / Tempest Keep (Void Reaver, Kael'thas)
    3923 = "Gruul"      # Gruul's Lair
    3836 = "Mag"        # Magtheridon's Lair
    3805 = "ZA"         # Zul'Aman
    4075 = "SWP"        # Sunwell Plateau
    4080 = "SWP"        # Sunwell area (Isle of Quel'Danas outdoor/sub-zone)
    # ── Outland Heroic/Normal Dungeons ────────────────────────────────────────
    3847 = "Botanica"
    3849 = "Mechanar"
    3848 = "Arcatraz"
    3710 = "Shadow Lab"
    3713 = "Sh. Halls"
    3715 = "Steam Vault"
    3716 = "Underbog"
    3717 = "Slave Pens" # Quagmirran zone ID in XML
    3714 = "Slave Pens" # alternate ID
    3711 = "Sethekk"
    3712 = "Mana-Tombs"
    3739 = "Auchenai"
    3524 = "Ramparts"
    3523 = "Ramparts"   # alternate
    3529 = "Blood Furnace"
    3844 = "Old Hill."  # Caverns of Time: Old Hillsbrad
    3525 = "Black Morass"
}

# Cache: itemId -> source string
$ItemSourceCache = @{}

# Fetch per-item source from Wowhead item XML endpoint (fast, ~5-15KB per item).
# XML sourcemore format inside <json><![CDATA[...]]></json>:
#   "sourcemore":[{"bd":N,"dd":N,"n":"BossOrContainerName","t":N,"ti":N,"z":ZONE_ID}]
# Type values (t): 1=creature drop  2=contained-in  3=crafted  4=quest
#                  6=vendor  8=pvp  9=badge of justice
# Zone field (z): Wowhead internal zone ID — mapped via $XML_ZONE_SRC
function Get-ItemSource($itemId, $phaseFallback) {
    if ($ItemSourceCache.ContainsKey($itemId)) { return $ItemSourceCache[$itemId] }

    $url = "$BASE_URL/tbc/item=$($itemId)&xml"
    try {
        $xml = (Invoke-WebRequest -Uri $url -UserAgent $UA -TimeoutSec 10 -UseBasicParsing -MaximumRedirection 3).Content
    } catch {
        $ItemSourceCache[$itemId] = $phaseFallback
        return $phaseFallback
    }

    $src = ""

    # Extract the first sourcemore object from the JSON blob in the XML
    $smBlock = [regex]::Match($xml, '"sourcemore":\[(\{[^\]]+\})\]')
    if ($smBlock.Success) {
        $raw   = $smBlock.Groups[1].Value
        $zM    = [regex]::Match($raw, '"z":(\d+)')
        $nM    = [regex]::Match($raw, '"n":"([^"]+)"')
        $tM    = [regex]::Match($raw, '"t":(\d+)')
        $zid   = if ($zM.Success) { [int]$zM.Groups[1].Value } else { -1 }
        $sname = if ($nM.Success) { $nM.Groups[1].Value } else { "" }
        $stype = if ($tM.Success) { [int]$tM.Groups[1].Value } else { -1 }

        # 1. Zone-ID lookup — most reliable, works for both drops and "contained in"
        if ($zid -ge 0 -and $XML_ZONE_SRC.ContainsKey($zid)) {
            $src = $XML_ZONE_SRC[$zid]
        }

        # 2. If zone unknown but it's a direct creature drop (t=1), try boss name
        if ($src -eq "" -and $stype -eq 1 -and $sname -ne "") {
            $lower = $sname.ToLower()
            foreach ($entry in $BOSS_SRC.GetEnumerator()) {
                if ($lower -eq $entry.Key -or $lower.Contains($entry.Key)) {
                    $src = $entry.Value; break
                }
            }
        }

        # 3. Non-location source types (override zone lookup only when zone is empty)
        if ($src -eq "") {
            switch ($stype) {
                3 { $src = "Craft" }
                4 { $src = "Quest" }
                6 { $src = "Vendor" }
                8 { $src = "PvP" }
                9 { $src = "Badge" }
            }
        }
    }

    # 4. Keyword scan of XML <json> block for badge / pvp / craft if still unknown
    if ($src -eq "") {
        if     ($xml -match '"class":4,"subclass":2') { $src = "Craft" }  # weapon: bow/gun craft
        if     ($xml -match 'arenapointsreq|honorpointsreq') { $src = "PvP" }
        elseif ($xml -match '"nbadges":')              { $src = "Badge" }
    }

    # Only cache definitive (non-fallback) results — avoids poisoning later
    # phase lookups when phase 0 (pre-raid) is processed first and an item's
    # XML lookup temporarily fails.
    if ($src -ne "") {
        $ItemSourceCache[$itemId] = $src
        return $src
    }
    # No definitive source found — return phase fallback but do NOT cache it,
    # so the next phase can try again and may find the correct source.
    return $phaseFallback
}

# -- Stat weights per role (for upgrade scoring) -------------------------------
$STAT_WEIGHTS = @{
    melee_dps  = @{str=2.2; agi=1.5; mleatkpwr=1.0; mlecritstrkrtng=1.4; mlehitrtng=2.0; exprtng=2.0; hastertng=1.7; armorpenrtng=1.6; sta=0.1}
    ranged_dps = @{agi=2.0; rgdatkpwr=1.0; rgdcritstrkrtng=1.4; rgdhitrtng=2.0; sta=0.1; int=0.3}
    caster_dps = @{int=0.8; spldmg=1.0; spl=1.0; splhitrtng=1.2; splcritstrkrtng=0.9; hastertng=0.8; sta=0.1}
    healer     = @{int=0.7; spi=0.5; splheal=0.9; splcritstrkrtng=0.5; mp5=1.0; sta=0.1}
    tank       = @{sta=2.0; defrtng=3.0; dodgertng=2.5; parrrtng=2.5; blkrtng=1.0; str=0.5; armor=0.01}
}

# -- HTTP helpers --------------------------------------------------------------
function Get-Page($url) {
    try {
        $r = Invoke-WebRequest -Uri $url -UserAgent $UA -TimeoutSec 25 -UseBasicParsing -MaximumRedirection 3
        if ($r.StatusCode -eq 200) { return $r.Content }
    } catch {}
    return $null
}

# -- Extract item data from WH.Gatherer.addData(3, 5, {...}) ------------------
function Get-ItemMeta($html) {
    $meta = @{}
    $m = [regex]::Match($html, 'WH\.Gatherer\.addData\(3,\s*5,\s*(\{.*?\})\s*\);',
        [System.Text.RegularExpressions.RegexOptions]::Singleline)
    if (-not $m.Success) { return $meta }
    $json = $m.Groups[1].Value
    $itemMatches = [regex]::Matches($json, '"(\d+)":\{([^{}]+(?:\{[^{}]*\}[^{}]*)*)\}')
    foreach ($im in $itemMatches) {
        $id   = $im.Groups[1].Value
        $body = $im.Groups[2].Value
        $name = ""
        $nm   = [regex]::Match($body, '"name_enus":"([^"]+)"')
        if ($nm.Success) { $name = $nm.Groups[1].Value }
        # Extract jsonequip block
        $stats = @{}
        $je = [regex]::Match($body, '"jsonequip":\{([^{}]+)\}')
        if ($je.Success) {
            $pairs = [regex]::Matches($je.Groups[1].Value, '"([^"]+)":([\d.]+)')
            foreach ($p in $pairs) {
                $stats[$p.Groups[1].Value] = [double]$p.Groups[2].Value
            }
        }
        $meta[$id] = @{name=$name; stats=$stats}
    }
    return $meta
}

# -- Extract BBCode guide body from script -------------------------------------
function Get-GuideBBCode($html) {
    # Get all script blocks
    $scripts = [regex]::Matches($html, '<script[^>]*>(.*?)</script>',
        [System.Text.RegularExpressions.RegexOptions]::Singleline)

    $best = ""
    foreach ($s in $scripts) {
        $content = $s.Groups[1].Value
        # Look for the script that has [item= BBCode (the guide content)
        if ($content -match '\[item=' -and $content.Length -gt $best.Length) {
            $best = $content
        }
    }
    if ($best -eq "") { return "" }

    # Pattern 0: WH.markup.printHtml("...") -- main guide body injection (TBC Wowhead format)
    $m0 = [regex]::Match($best, 'WH\.markup\.printHtml\(\s*"((?:[^"\\]|\\.)*)"',
        [System.Text.RegularExpressions.RegexOptions]::Singleline)
    if ($m0.Success) {
        $body = Unescape-JsonString $m0.Groups[1].Value
        if ($body -match '\[item=') { return $body }
    }

    # Try to find the actual BBCode body string — try several extraction patterns
    # Pattern 1: "body":"..." (JSON escaped string that starts with \r\n[ or [h)
    $ms = [regex]::Matches($best, '"body":"((?:[^"\\]|\\.)*)"\s*[,}]',
        [System.Text.RegularExpressions.RegexOptions]::Singleline)
    foreach ($m in $ms) {
        $raw = $m.Groups[1].Value
        # Unescape JSON
        $body = Unescape-JsonString $raw
        if ($body -match '\[table' -and $body -match '\[item=') {
            return $body
        }
    }

    # Pattern 2: direct BBCode in a string literal after "content":
    $m2 = [regex]::Match($best, '"(?:content|sections?|body|guide_body)":\s*"((?:[^"\\]|\\.){200,})"',
        [System.Text.RegularExpressions.RegexOptions]::Singleline)
    if ($m2.Success) {
        $body = Unescape-JsonString $m2.Groups[1].Value
        if ($body -match '\[table') { return $body }
    }

    # Pattern 3: raw BBCode substring in script (not encoded as JSON string)
    $idx = $best.IndexOf('[h2]')
    if ($idx -lt 0) { $idx = $best.IndexOf('[h3') }
    if ($idx -ge 0) {
        # Grab a large block from the first heading to the end of guide content
        $chunk = $best.Substring($idx, [Math]::Min($best.Length - $idx, 40000))
        if ($chunk -match '\[item=') { return $chunk }
    }

    return ""
}

function Unescape-JsonString($s) {
    return $s `
        -replace '\\r\\n', "`n" `
        -replace '\\n', "`n" `
        -replace '\\t', "`t" `
        -replace '\\"', '"' `
        -replace '\\/', '/' `
        -replace '\\\\', '\'
}

# -- Parse BBCode for slot/item mapping ----------------------------------------
function Parse-BISSlotsFromBBCode($bbcode) {
    $results = @{}  # slotId -> list of {itemId, rank}

    # Normalise: lowercase headings for matching
    $lines = $bbcode -replace '\r\n', "`n" -replace '\r', "`n"

    # Strategy: split on h2/h3 headings, each section = one gear slot
    $sections = [regex]::Split($lines, '\[h[23][^\]]*\]')
    if ($sections.Count -lt 2) {
        # Try splitting on h2 text content
        $sections = [regex]::Split($lines, '\[h2[^\]]*\]')
    }

    $currentSlotId = 0
    $rank = 1

    foreach ($section in $sections) {
        # The heading text is at the start of each section
        $headingMatch = [regex]::Match($section, '^([^\[\r\n]{2,50})')
        if ($headingMatch.Success) {
            $headingText = $headingMatch.Groups[1].Value.Trim().ToLower()
            # Extract slot name from "Best in Slot {slot} {rest}" pattern
            $bsMatch = [regex]::Match($headingText, 'best\s+in\s+slot\s+(\w+(?:\s+hand)?)')
            if ($bsMatch.Success) {
                $headingText = $bsMatch.Groups[1].Value.Trim()
            } else {
                # Fall back: strip trailing qualifier words
                $headingText = $headingText -replace '\s+(armor|jewelry|weapons?|gear|for|phase|bis|p\d).*$', ''
                $headingText = $headingText.Trim()
            }
            $slotId = Resolve-SlotName $headingText
            if ($slotId -gt 0) {
                $currentSlotId = $slotId
                $rank = 1
            } else {
                $currentSlotId = 0  # unknown section, skip
            }
        }

        if ($currentSlotId -le 0) { continue }

        # Within this section, find table rows: [td]Best[/td] [td][item=ID][/td]
        # Rows may span multiple lines, e.g. [tr][td]Best[/td]\n[td][item=ID][/td]
        $rowMatches = [regex]::Matches($section,
            '\[tr\]\[td\][^\[]*\[/td\]\s*\r?\n?\s*\[td\]\[item=(\d+)\]',
            ([System.Text.RegularExpressions.RegexOptions]::IgnoreCase -bor [System.Text.RegularExpressions.RegexOptions]::Singleline))

        if ($rowMatches.Count -eq 0) {
            # Try simpler: just find [item=ID] in this section as the BIS
            $simpleItems = [regex]::Matches($section, '\[item=(\d+)\]')
            $found = @()
            foreach ($si in $simpleItems) {
                $id = [int]$si.Groups[1].Value
                if ($id -gt 10000 -and $found -notcontains $id) { $found += $id }
            }
            if ($found.Count -gt 0) {
                if (-not $results.ContainsKey($currentSlotId)) { $results[$currentSlotId] = @() }
                $r = 1
                foreach ($id in $found | Select-Object -First 3) {
                    $results[$currentSlotId] += @{itemId=$id; rank=$r}
                    $r++
                }
            }
            continue
        }

        foreach ($row in $rowMatches) {
            $itemId = [int]$row.Groups[1].Value
            if ($itemId -gt 10000) {
                if (-not $results.ContainsKey($currentSlotId)) { $results[$currentSlotId] = @() }
                # Avoid duplicates
                $exists = $results[$currentSlotId] | Where-Object { $_.itemId -eq $itemId }
                if (-not $exists) {
                    $results[$currentSlotId] += @{itemId=$itemId; rank=$rank}
                    $rank++
                }
            }
        }

        # Each section resets rank when we move to next slot heading
    }

    return $results
}

function Resolve-SlotName($text) {
    # Direct lookup
    if ($SLOT_ID.ContainsKey($text)) { return $SLOT_ID[$text] }
    # Partial match
    foreach ($k in $SLOT_ID.Keys) {
        if ($text -match "\b$([regex]::Escape($k))\b") { return $SLOT_ID[$k] }
    }
    return 0
}

# -- Score an item given role stat weights -------------------------------------
function Compute-Score($stats, $role) {
    $weights = $STAT_WEIGHTS[$role]
    if (-not $weights) { return 0 }
    $score = 0.0
    foreach ($k in $weights.Keys) {
        if ($stats.ContainsKey($k)) {
            $score += $stats[$k] * $weights[$k]
        }
    }
    return [Math]::Round($score, 1)
}

# -- Fetch and parse a single guide page ---------------------------------------
function Scrape-Guide($url, $role) {
    Write-Host "  Fetching: $url" -ForegroundColor DarkGray
    $html = Get-Page "$BASE_URL$url"
    if (-not $html) { Write-Host "  FAILED (404 or network)" -ForegroundColor DarkRed; return $null }

    $itemMeta  = Get-ItemMeta $html
    $bbcode    = Get-GuideBBCode $html
    if ($bbcode -eq "") {
        Write-Host "  No BBCode found" -ForegroundColor DarkYellow
        return $null
    }

    $slotItems = Parse-BISSlotsFromBBCode $bbcode
    if ($slotItems.Count -eq 0) {
        Write-Host "  No slots parsed from BBCode" -ForegroundColor DarkYellow
    } else {
        Write-Host "  Parsed $($slotItems.Count) slots, $($itemMeta.Count) items cached" -ForegroundColor DarkGreen
    }

    # Build result: for each slot, return BIS item info
    $result = @{}
    foreach ($slotId in $slotItems.Keys) {
        $entries = $slotItems[$slotId] | Sort-Object { $_.rank }
        $slotResult = @()
        foreach ($entry in $entries) {
            $id   = $entry.itemId
            $meta = if ($itemMeta.ContainsKey("$id")) { $itemMeta["$id"] } else { @{name="Unknown Item $id"; stats=@{}} }
            $score = Compute-Score $meta.stats $role
            $slotResult += @{
                itemId = $id
                name   = $meta.name
                score  = $score
                rank   = $entry.rank
            }
        }
        $result[$slotId] = $slotResult
    }

    return $result
}

# -- Try phase-specific URL variants ------------------------------------------
function Get-PhaseData($specDef, $phase, $role) {
    # Phase 0 (pre-raid) uses /classes/{class}/{role}-bis-gear-pve-pre-raid
    if ($phase -eq 0) {
        $p0 = $specDef.preRaidPath
        if (-not $p0 -or $p0 -eq "") {
            Write-Host "  Pre-Raid: no guide available for this spec" -ForegroundColor DarkGray
            return $null
        }
        $url = "/tbc/guide/$p0"
        return Scrape-Guide $url $role
    }
    # Phase 2 uses a completely different URL structure on Wowhead: /classes/{class}/{spec}/{role}-bis-gear-pve-phase-2
    if ($phase -eq 2) {
        $p2 = $specDef.p2Path
        if (-not $p2 -or $p2 -eq "") {
            Write-Host "  Phase 2: no guide available for this spec" -ForegroundColor DarkGray
            return $null
        }
        $url = "/tbc/guide/$p2"
        $data = Scrape-Guide $url $role
        return $data
    }
    $suffixes = $PHASE_SUFFIXES[$phase]
    foreach ($suffix in $suffixes) {
        $url  = "/tbc/guide/$($specDef.slug)$suffix"
        $data = Scrape-Guide $url $role
        if ($data) { return $data }
    }
    return $null
}

# -- Lua escaping --------------------------------------------------------------
function Lua-Str($s) {
    if (-not $s) { return '""' }
    $escaped = $s -replace '\\', '\\\\' -replace '"', '\\"'
    return "`"$escaped`""
}

# -- Main ---------------------------------------------------------------------
Write-Host "=== TBC BIS Scraper ===" -ForegroundColor Cyan
Write-Host "Output: $OUT_FILE"
Write-Host ""

# Filter specs + phases if requested
$targetSpecs  = if ($Spec)  { $SPECS | Where-Object { $_.key -like "*$Spec*" -or $_.slug -like "*$Spec*" } } else { $SPECS }
$targetPhases = if ($Phase) { @($Phase) } else { @(0) + @(1..5) }

# Master data: [specKey][phase][slotId] = @{itemId; name; score; rank}
$masterData = @{}

foreach ($specDef in $targetSpecs) {
    Write-Host "[$($specDef.label)]" -ForegroundColor Yellow
    $masterData[$specDef.key] = @{}

    foreach ($ph in $targetPhases) {
        Write-Host "  Phase $ph" -ForegroundColor Cyan
        $phData = Get-PhaseData $specDef $ph $specDef.role
        if ($phData) {
            $masterData[$specDef.key][$ph] = $phData
        } else {
            $masterData[$specDef.key][$ph] = @{}
        }
    }
    Write-Host ""
}

# -- Generate Lua -------------------------------------------------------------
if ($Dry) { Write-Host "Dry run — skipping file write."; exit }

$sb = [System.Text.StringBuilder]::new()
$null = $sb.AppendLine("-- BIS_Data.lua  (Auto-generated by scripts/update-bis.ps1)")
$null = $sb.AppendLine("-- Source: Wowhead TBC Classic BIS guides")
$null = $sb.AppendLine("-- Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm')")
$null = $sb.AppendLine("-- DO NOT EDIT MANUALLY -- re-run update-bis.ps1 to refresh")
$null = $sb.AppendLine("")
$null = $sb.AppendLine("-- Slot IDs (WoW inventory slot IDs):")
$null = $sb.AppendLine("--   1=Head 2=Neck 3=Shoulder 5=Chest 6=Waist 7=Legs 8=Feet")
$null = $sb.AppendLine("--   9=Wrist 10=Hands 11=Ring1 12=Ring2 13=Trinket1 14=Trinket2")
$null = $sb.AppendLine("--   15=Back 16=MainHand 17=OffHand 18=Ranged")
$null = $sb.AppendLine("")

# -- Static enchant/gem recommendations per role (hardcoded, well-known for TBC)
$null = $sb.AppendLine("-- Recommended enchants per role per slot. Enchant IDs from Wowhead.")
$null = $sb.AppendLine("IRR_BIS_ENCHANTS = {")
$null = $sb.AppendLine("    melee_dps = {")
$null = $sb.AppendLine("        [1]  = 29192,  -- Head: Glyph of Ferocity (Cenarion Expedition)")
$null = $sb.AppendLine("        [3]  = 24421,  -- Shoulder: Greater Inscription of Vengeance (Aldor)")
$null = $sb.AppendLine("        [15] = 25082,  -- Back: Enchant Cloak - Greater Agility")
$null = $sb.AppendLine("        [5]  = 27960,  -- Chest: Enchant Chest - Exceptional Stats")
$null = $sb.AppendLine("        [9]  = 27899,  -- Wrist: Enchant Bracer - Assault (+24 AP)")
$null = $sb.AppendLine("        [10] = 25080,  -- Hands: Enchant Gloves - Superior Agility")
$null = $sb.AppendLine("        [7]  = 35297,  -- Legs: Nethercobra Leg Armor (physical)")
$null = $sb.AppendLine("        [8]  = 27954,  -- Feet: Enchant Boots - Surefooted")
$null = $sb.AppendLine("        [16] = 27984,  -- Main-hand: Enchant Weapon - Mongoose")
$null = $sb.AppendLine("        [17] = 27984,  -- Off-hand: Enchant Weapon - Mongoose")
$null = $sb.AppendLine("    },")
$null = $sb.AppendLine("    ranged_dps = {")
$null = $sb.AppendLine("        [1]  = 29192,  -- Head: Glyph of Ferocity")
$null = $sb.AppendLine("        [3]  = 24421,  -- Shoulder: Greater Inscription of Vengeance")
$null = $sb.AppendLine("        [15] = 25082,  -- Back: Greater Agility")
$null = $sb.AppendLine("        [5]  = 27960,  -- Chest: Exceptional Stats")
$null = $sb.AppendLine("        [9]  = 27899,  -- Wrist: Assault")
$null = $sb.AppendLine("        [10] = 33153,  -- Hands: Enchant Gloves - Ranged Specialization")
$null = $sb.AppendLine("        [7]  = 35279,  -- Legs: Cobrahide Leg Armor")
$null = $sb.AppendLine("        [8]  = 27954,  -- Feet: Surefooted")
$null = $sb.AppendLine("        [16] = 23765,  -- Weapon: Adamantite Scope")
$null = $sb.AppendLine("    },")
$null = $sb.AppendLine("    caster_dps = {")
$null = $sb.AppendLine("        [1]  = 22535,  -- Head: Glyph of Power (Violet Eye/Kirin Tor)")
$null = $sb.AppendLine("        [3]  = 24425,  -- Shoulder: Greater Inscription of the Orb (Scryers)")
$null = $sb.AppendLine("        [15] = 25084,  -- Back: Enchant Cloak - Subtlety")
$null = $sb.AppendLine("        [5]  = 27960,  -- Chest: Exceptional Stats")
$null = $sb.AppendLine("        [9]  = 27917,  -- Wrist: Enchant Bracer - Spellpower")
$null = $sb.AppendLine("        [10] = 33997,  -- Hands: Enchant Gloves - Spell Strike")
$null = $sb.AppendLine("        [7]  = 24272,  -- Legs: Runic Spellthread")
$null = $sb.AppendLine("        [8]  = 34007,  -- Feet: Enchant Boots - Boar's Speed")
$null = $sb.AppendLine("        [16] = 28004,  -- Weapon: Enchant Weapon - Sunfire")
$null = $sb.AppendLine("    },")
$null = $sb.AppendLine("    healer = {")
$null = $sb.AppendLine("        [1]  = 22534,  -- Head: Glyph of Renewal (Keepers of Time)")
$null = $sb.AppendLine("        [3]  = 24428,  -- Shoulder: Greater Inscription of Faith (Aldor)")
$null = $sb.AppendLine("        [15] = 25084,  -- Back: Subtlety")
$null = $sb.AppendLine("        [5]  = 27960,  -- Chest: Exceptional Stats")
$null = $sb.AppendLine("        [9]  = 27917,  -- Wrist: Spellpower")
$null = $sb.AppendLine("        [10] = 33994,  -- Hands: Enchant Gloves - Major Healing")
$null = $sb.AppendLine("        [7]  = 24274,  -- Legs: Mystic Spellthread")
$null = $sb.AppendLine("        [8]  = 27948,  -- Feet: Enchant Boots - Vitality")
$null = $sb.AppendLine("        [16] = 22750,  -- Weapon: Enchant Weapon - Healing Power")
$null = $sb.AppendLine("    },")
$null = $sb.AppendLine("    tank = {")
$null = $sb.AppendLine("        [1]  = 29192,  -- Head: Glyph of Ferocity")
$null = $sb.AppendLine("        [3]  = 29483,  -- Shoulder: Greater Inscription of the Knight (Honor Hold)")
$null = $sb.AppendLine("        [15] = 25086,  -- Back: Enchant Cloak - Dodge")
$null = $sb.AppendLine("        [5]  = 24003,  -- Chest: Enchant Chest - Major Resilience (or 27960)")
$null = $sb.AppendLine("        [9]  = 27906,  -- Wrist: Enchant Bracer - Major Defense")
$null = $sb.AppendLine("        [10] = 25078,  -- Hands: Enchant Gloves - Major Agility")
$null = $sb.AppendLine("        [7]  = 35490,  -- Legs: Cobrahide Leg Armor or Clefthide")
$null = $sb.AppendLine("        [8]  = 34009,  -- Feet: Enchant Boots - Cat's Swiftness (or Stamina)")
$null = $sb.AppendLine("        [16] = 27975,  -- Weapon: Enchant Weapon - Major Defense")
$null = $sb.AppendLine("    },")
$null = $sb.AppendLine("}")
$null = $sb.AppendLine("")

# -- Static gem recommendations per role --------------------------------------
$null = $sb.AppendLine("-- Recommended gems per role (socket colour -> gemId)")
$null = $sb.AppendLine("IRR_BIS_GEMS = {")
$null = $sb.AppendLine("    melee_dps = {")
$null = $sb.AppendLine("        meta   = 32409,  -- Relentless Earthstorm Diamond")
$null = $sb.AppendLine("        red    = 32193,  -- Bright Living Ruby (+12 AP)")
$null = $sb.AppendLine("        yellow = 28507,  -- Inscribed Noble Topaz (+4 crit/+4 str)")
$null = $sb.AppendLine("        blue   = 28483,  -- Rigid Dawnstone (+8 hit) or Royal Nightseye")
$null = $sb.AppendLine("    },")
$null = $sb.AppendLine("    ranged_dps = {")
$null = $sb.AppendLine("        meta   = 32409,  -- Relentless Earthstorm Diamond")
$null = $sb.AppendLine("        red    = 28367,  -- Delicate Living Ruby (+8 agi)")
$null = $sb.AppendLine("        yellow = 28507,  -- Inscribed Noble Topaz")
$null = $sb.AppendLine("        blue   = 28483,  -- Rigid Dawnstone (+8 hit)")
$null = $sb.AppendLine("    },")
$null = $sb.AppendLine("    caster_dps = {")
$null = $sb.AppendLine("        meta   = 34220,  -- Chaotic Skyfire Diamond (+12 crit dmg)")
$null = $sb.AppendLine("        red    = 28458,  -- Runed Living Ruby (+9 spell dmg)")
$null = $sb.AppendLine("        yellow = 28349,  -- Smooth Dawnstone (+9 crit rtng)")
$null = $sb.AppendLine("        blue   = 28462,  -- Veiled Noble Topaz (+5 hit/+5 AP) or Royal Nightseye")
$null = $sb.AppendLine("    },")
$null = $sb.AppendLine("    healer = {")
$null = $sb.AppendLine("        meta   = 25896,  -- Bracing Earthstorm Diamond")
$null = $sb.AppendLine("        red    = 28460,  -- Brilliant Dawnstone (+9 int) or Luminous Noble Topaz")
$null = $sb.AppendLine("        yellow = 28460,  -- Brilliant Dawnstone (+9 int)")
$null = $sb.AppendLine("        blue   = 28462,  -- Royal Nightseye (+4 heal/+2 mana5)")
$null = $sb.AppendLine("    },")
$null = $sb.AppendLine("    tank = {")
$null = $sb.AppendLine("        meta   = 32936,  -- Austere Earthstorm Diamond (armor)")
$null = $sb.AppendLine("        red    = 28455,  -- Bold Living Ruby (+8 str)")
$null = $sb.AppendLine("        yellow = 28347,  -- Thick Dawnstone (+8 sta)")
$null = $sb.AppendLine("        blue   = 28464,  -- Solid Star of Elune (+12 sta)")
$null = $sb.AppendLine("    },")
$null = $sb.AppendLine("}")
$null = $sb.AppendLine("")

# -- Spec metadata -------------------------------------------------------------
$null = $sb.AppendLine("-- Spec metadata (class, spec key, talent tab, role)")
$null = $sb.AppendLine("IRR_BIS_SPECS = {")
foreach ($specDef in $SPECS) {
    $null = $sb.AppendLine("    [$(Lua-Str $specDef.key)] = {")
    $null = $sb.AppendLine("        class   = $(Lua-Str $specDef.class),")
    $null = $sb.AppendLine("        spec    = $(Lua-Str $specDef.spec),")
    $null = $sb.AppendLine("        specTab = $($specDef.specTab),")
    $null = $sb.AppendLine("        role    = $(Lua-Str $specDef.role),")
    $null = $sb.AppendLine("        label   = $(Lua-Str $specDef.label),")
    $null = $sb.AppendLine("    },")
}
$null = $sb.AppendLine("}")
$null = $sb.AppendLine("")

# -- BIS item data: write per-class split files --------------------------------
$ADDON_DIR = Join-Path $PSScriptRoot "..\addons\ItemRackRevived"

# Group specs by class
$classByKey = @{}
foreach ($specDef in $SPECS) {
    if (-not $classByKey.ContainsKey($specDef.class)) { $classByKey[$specDef.class] = @() }
    $classByKey[$specDef.class] += $specDef
}

foreach ($class in ($classByKey.Keys | Sort-Object)) {
    $classSpecs = $classByKey[$class]
    $csb = [System.Text.StringBuilder]::new()
    $null = $csb.AppendLine("-- BIS_Data_$class.lua  (Auto-generated by scripts/update-bis.ps1)")
    $null = $csb.AppendLine("-- Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm')  -- DO NOT EDIT MANUALLY")
    $null = $csb.AppendLine("IRR_BIS_DATA = IRR_BIS_DATA or {}")
    $null = $csb.AppendLine("do local _d = {")

    foreach ($specDef in $classSpecs) {
        $key      = $specDef.key
        $specData = $masterData[$key]
        if (-not $specData) { continue }

        $null = $csb.AppendLine("    [$(Lua-Str $key)] = {")
        foreach ($ph in @(0) + @(1..5)) {
            $phData  = if ($specData.ContainsKey($ph)) { $specData[$ph] } else { @{} }
            $phSrc   = if ($PHASE_SRC.ContainsKey($ph)) { $PHASE_SRC[$ph] } else { "P$ph" }
            $null = $csb.AppendLine("        [$ph] = {")
            foreach ($slotId in ($phData.Keys | Sort-Object)) {
                $entries = $phData[$slotId] | Sort-Object { $_.rank }
                $valid   = @($entries | Where-Object { $_.itemId -and [int]$_.itemId -gt 0 })
                if ($valid.Count -eq 0) { continue }
                $null = $csb.AppendLine("            [$slotId] = {")
                foreach ($entry in ($valid | Select-Object -First 3)) {
                    $score   = if ($entry.score) { $entry.score } else { 0 }
                    $itemSrc = Get-ItemSource $entry.itemId $phSrc
                    $null = $csb.AppendLine("                {id=$($entry.itemId), name=$(Lua-Str $entry.name), score=$score, rank=$($entry.rank), src=$(Lua-Str $itemSrc)},")
                }
                $null = $csb.AppendLine("            },")
            }
            $null = $csb.AppendLine("        },")
        }
        $null = $csb.AppendLine("    },")
    }

    $null = $csb.AppendLine("}")
    $null = $csb.AppendLine("for k,v in pairs(_d) do IRR_BIS_DATA[k] = v end")
    $null = $csb.AppendLine("end")

    if (-not $Dry) {
        $classFile = Join-Path $ADDON_DIR "BIS_Data_$class.lua"
        [System.IO.File]::WriteAllText($classFile, $csb.ToString(), [System.Text.UTF8Encoding]::new($false))
        Write-Host "Written: BIS_Data_$class.lua ($([Math]::Round((Get-Item $classFile).Length/1024,1)) KB)" -ForegroundColor Green
    } else {
        Write-Host "[Dry] Would write BIS_Data_$class.lua" -ForegroundColor DarkGray
    }
}
