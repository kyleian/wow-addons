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
    @{key="fury_warrior";        class="WARRIOR"; spec="fury";          specTab=2; role="melee_dps";  label="Fury Warrior";         slug="fury-warrior-dps"}
    @{key="arms_warrior";        class="WARRIOR"; spec="arms";          specTab=1; role="melee_dps";  label="Arms Warrior";          slug="arms-warrior-dps"}
    @{key="prot_warrior";        class="WARRIOR"; spec="protection";    specTab=3; role="tank";       label="Prot Warrior";          slug="protection-warrior-tank"}
    @{key="holy_paladin";        class="PALADIN"; spec="holy";          specTab=1; role="healer";     label="Holy Paladin";          slug="holy-paladin-healer"}
    @{key="prot_paladin";        class="PALADIN"; spec="protection";    specTab=2; role="tank";       label="Prot Paladin";          slug="paladin-tank"}
    @{key="ret_paladin";         class="PALADIN"; spec="retribution";   specTab=3; role="melee_dps";  label="Ret Paladin";           slug="retribution-paladin-dps"}
    @{key="bm_hunter";           class="HUNTER";  spec="beast_mastery"; specTab=1; role="ranged_dps"; label="BM Hunter";             slug="beast-mastery-hunter-dps"}
    @{key="mm_hunter";           class="HUNTER";  spec="marksmanship";  specTab=2; role="ranged_dps"; label="MM Hunter";             slug="marksmanship-hunter-dps"}
    @{key="surv_hunter";         class="HUNTER";  spec="survival";      specTab=3; role="ranged_dps"; label="Survival Hunter";       slug="survival-hunter-dps"}
    @{key="combat_rogue";        class="ROGUE";   spec="combat";        specTab=2; role="melee_dps";  label="Combat Rogue";          slug="rogue-dps"}
    @{key="shadow_priest";       class="PRIEST";  spec="shadow";        specTab=3; role="caster_dps"; label="Shadow Priest";         slug="shadow-priest-dps"}
    @{key="holy_priest";         class="PRIEST";  spec="holy";          specTab=2; role="healer";     label="Holy Priest";           slug="priest-healer"}
    @{key="elemental_shaman";    class="SHAMAN";  spec="elemental";     specTab=1; role="caster_dps"; label="Elemental Shaman";      slug="elemental-shaman-dps"}
    @{key="enhance_shaman";      class="SHAMAN";  spec="enhancement";   specTab=2; role="melee_dps";  label="Enhance Shaman";        slug="enhancement-shaman-dps"}
    @{key="resto_shaman";        class="SHAMAN";  spec="restoration";   specTab=3; role="healer";     label="Resto Shaman";          slug="shaman-healer"}
    @{key="arcane_mage";         class="MAGE";    spec="arcane";        specTab=1; role="caster_dps"; label="Arcane Mage";           slug="arcane-mage-dps"}
    @{key="fire_mage";           class="MAGE";    spec="fire";          specTab=2; role="caster_dps"; label="Fire Mage";             slug="fire-mage-dps"}
    @{key="frost_mage";          class="MAGE";    spec="frost";         specTab=3; role="caster_dps"; label="Frost Mage";            slug="frost-mage-dps"}
    @{key="affliction_warlock";  class="WARLOCK"; spec="affliction";    specTab=1; role="caster_dps"; label="Affliction Warlock";    slug="affliction-warlock-dps"}
    @{key="destro_warlock";      class="WARLOCK"; spec="destruction";   specTab=3; role="caster_dps"; label="Destro Warlock";        slug="destruction-warlock-dps"}
    @{key="demo_warlock";        class="WARLOCK"; spec="demonology";    specTab=2; role="caster_dps"; label="Demo Warlock";          slug="demonology-warlock-dps"}
    @{key="balance_druid";       class="DRUID";   spec="balance";       specTab=1; role="caster_dps"; label="Balance Druid";         slug="balance-druid-dps"}
    @{key="feral_dps_druid";     class="DRUID";   spec="feral";         specTab=2; role="melee_dps";  label="Feral DPS Druid";       slug="feral-druid-dps"}
    @{key="feral_tank_druid";    class="DRUID";   spec="feral_tank";    specTab=2; role="tank";       label="Feral Tank Druid";      slug="feral-druid-tank"}
    @{key="resto_druid";         class="DRUID";   spec="restoration";   specTab=3; role="healer";     label="Resto Druid";           slug="druid-healer"}
)

# Phase URL suffixes to try (in order)
$PHASE_SUFFIXES = @{
    1 = @(
        "-karazhan-best-in-slot-gear-burning-crusade-classic-wow"
        "-karazhan-best-in-slot-gear-burning-crusade"
    )
    2 = @(
        "-ssc-tk-phase-2-best-in-slot-gear-burning-crusade"
        "-serpentshrine-cavern-the-eye-phase-2-best-in-slot-gear-burning-crusade"
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
function Get-PhaseData($specSlug, $phase, $role) {
    $suffixes = $PHASE_SUFFIXES[$phase]
    foreach ($suffix in $suffixes) {
        $url  = "/tbc/guide/$specSlug$suffix"
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
$targetPhases = if ($Phase) { @($Phase) } else { 1..5 }

# Master data: [specKey][phase][slotId] = @{itemId; name; score; rank}
$masterData = @{}

foreach ($specDef in $targetSpecs) {
    Write-Host "[$($specDef.label)]" -ForegroundColor Yellow
    $masterData[$specDef.key] = @{}

    foreach ($ph in $targetPhases) {
        Write-Host "  Phase $ph" -ForegroundColor Cyan
        $phData = Get-PhaseData $specDef.slug $ph $specDef.role
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

# -- BIS item data -------------------------------------------------------------
$null = $sb.AppendLine("-- BIS item data per spec per phase per slot")
$null = $sb.AppendLine("-- Each entry: {id=itemId, name='...', score=weightedScore, rank=N}")
$null = $sb.AppendLine("IRR_BIS_DATA = {")

foreach ($specDef in $SPECS) {
    $key     = $specDef.key
    $specData = $masterData[$key]
    if (-not $specData) { continue }

    $null = $sb.AppendLine("    -- $($specDef.label)")
    $null = $sb.AppendLine("    [$(Lua-Str $key)] = {")

    foreach ($ph in 1..5) {
        $phData = if ($specData.ContainsKey($ph)) { $specData[$ph] } else { @{} }
        $null = $sb.AppendLine("        [$ph] = {")

        foreach ($slotId in $phData.Keys | Sort-Object) {
            $entries = $phData[$slotId] | Sort-Object { $_.rank }
            if ($entries.Count -eq 0) { continue }
            $best = $entries[0]
            # Skip entries with no valid item ID
            if (-not $best.itemId -or [int]$best.itemId -le 0) { continue }
            $score = if ($best.score) { $best.score } else { 0 }
            $null = $sb.AppendLine("            [$slotId] = {id=$($best.itemId), name=$(Lua-Str $best.name), score=$score, rank=1},")
        }

        $null = $sb.AppendLine("        },")
    }

    $null = $sb.AppendLine("    },")
}

$null = $sb.AppendLine("}")

[System.IO.File]::WriteAllText($OUT_FILE, $sb.ToString(), [System.Text.UTF8Encoding]::new($false))
Write-Host "Written: $OUT_FILE ($([Math]::Round((Get-Item $OUT_FILE).Length/1024, 1)) KB)" -ForegroundColor Green
