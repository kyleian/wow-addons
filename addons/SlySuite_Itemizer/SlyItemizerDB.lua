-- SlyItemizerDB.lua
-- Stat weight presets, enchant recommendations, gem recommendations.
-- All data is TBC Anniversary (Patch 2.4.3) specific.

local SI = SlyItemizer

-- ─────────────────────────────────────────────────────────────────────────────
-- STAT WEIGHT PRESETS
-- Weights are relative — higher = more valuable per point.
-- Based on widely-used TBC theorycrafting (Wowpedia, SimulationCraft, TBC MaxDPS).
-- hit/expertise weights reflect value BEFORE their respective caps:
--   hit cap: 142 (raid boss for most specs)
--   spell hit cap: 202 (raid boss, 16% vs bosses + 1% racial)
--   expertise cap: 26 (dodge-cap)
-- ─────────────────────────────────────────────────────────────────────────────
SI.PRESETS = {

    WARRIOR = {
        dps = {  -- Fury / Arms
            str=2.4, agi=0.6, sta=0.2, ap=1.0,
            crit=1.5, hit=2.2, haste=0.8, expertise=1.8, arp=1.2,
            weapon_dps=6.0,
        },
        tank = {  -- Protection
            sta=3.0, str=0.5, agi=1.0,
            defense=2.0, dodge=1.5, parry=1.3, block=0.8, blockval=0.9,
            hit=1.0, expertise=1.2, armor=0.015,
        },
    },

    ROGUE = {
        dps = {  -- Combat / Assassination / Sub
            agi=2.2, str=0.9, ap=1.0,
            crit=1.4, hit=2.2, haste=1.0, expertise=1.8, arp=0.8,
            weapon_dps=7.0,
        },
    },

    HUNTER = {
        dps = {  -- BM / MM / SV
            agi=1.6, ap=1.0, rap=1.0, str=0.2,
            crit=1.4, hit=2.0, haste=0.9, int=0.25,
            weapon_dps=2.0,
        },
    },

    PALADIN = {
        dps = {  -- Retribution
            str=2.0, agi=0.6, ap=1.0,
            crit=1.5, hit=2.2, haste=0.7, expertise=1.5,
            weapon_dps=5.0,
        },
        heal = {  -- Holy
            sp=1.0, hp=0.9, int=0.7, spi=0.5, mp5=2.0, crit=0.9, sta=0.1,
        },
        tank = {  -- Protection
            sta=2.8, str=0.6, agi=0.8,
            defense=2.2, dodge=1.4, parry=1.4, block=0.8, blockval=1.0,
            hit=1.0, expertise=1.2, armor=0.015,
        },
    },

    DRUID = {
        dps = {  -- Feral Cat
            agi=2.0, str=0.9, ap=1.0, feral_ap=1.0,
            crit=1.5, hit=2.2, haste=0.7, expertise=1.0,
        },
        tank = {  -- Feral Bear
            sta=2.8, agi=2.0, str=0.5, feral_ap=0.5,
            defense=1.5, dodge=1.5, armor=0.020, resilience=1.0,
        },
        heal = {  -- Resto
            sp=0.5, hp=1.0, int=0.7, spi=1.0, mp5=2.2, crit=0.8,
        },
        balance = {  -- Moonkin
            sp=1.0, int=0.4, crit=1.2, hit=2.0, haste=1.0, spi=0.2,
        },
    },

    MAGE = {
        dps = {  -- Fire / Frost / Arcane
            sp=1.0, int=0.3,
            crit=1.2, hit=2.0, haste=1.0,
            fire_sp=0.2, frost_sp=0.2, arcane_sp=0.2,
        },
    },

    WARLOCK = {
        dps = {  -- Destruction / Affliction / Demonology
            sp=1.0, int=0.25, sta=0.15,
            crit=1.0, hit=2.0, haste=0.9,
            shadow_sp=0.3, fire_sp=0.2,
        },
    },

    PRIEST = {
        dps = {  -- Shadow
            sp=1.0, int=0.25, spi=0.4,
            crit=1.0, hit=2.0, haste=0.9,
            shadow_sp=0.3,
        },
        heal = {  -- Holy / Disc
            hp=1.0, sp=0.6, int=0.7, spi=0.9, mp5=2.2, crit=0.9,
        },
    },

    SHAMAN = {
        dps = {  -- Enhancement
            str=1.2, agi=1.4, ap=1.0,
            crit=1.3, hit=2.0, haste=1.0, expertise=1.0,
            weapon_dps=5.0,
        },
        balance = {  -- Elemental
            sp=1.0, int=0.3,
            crit=1.3, hit=2.0, haste=1.0,
            nature_sp=0.2,
        },
        heal = {  -- Resto
            hp=1.0, sp=0.5, int=0.6, spi=0.4, mp5=2.5, crit=0.6,
        },
    },
}

-- Alias: balance spec maps to "dps" slot in UI, real key differs per class
-- DRUID / SHAMAN expose a "balance" key; fallback for other classes is dps.
function SI:GetPreset(cls, spec)
    cls  = cls  or (SlyItemizerDB and SlyItemizerDB.class) or "WARRIOR"
    spec = spec or (SlyItemizerDB and SlyItemizerDB.spec)  or "dps"
    local cp = SI.PRESETS[cls]
    if not cp then return SI.PRESETS["WARRIOR"]["dps"] end
    return cp[spec] or cp["dps"] or cp[next(cp)]
end

-- ─────────────────────────────────────────────────────────────────────────────
-- ENCHANT RECOMMENDATIONS  (TBC 2.4.3)
-- Format: { slot=slotId, name, effect, role }
-- role: "dps" | "tank" | "heal" | "all"
-- Multiple entries per slot — best-first within each role.
-- ─────────────────────────────────────────────────────────────────────────────
SI.ENCHANT_DB = {
    -- HEAD (1) — rep enchants from Aldor/Scryer/Cenarion/etc.
    { slot=1, name="Glyph of Ferocity",           effect="+34 AP, +16 Hit",              role="dps"  },
    { slot=1, name="Glyph of Power",              effect="+22 SP, +14 Hit",              role="heal" },
    { slot=1, name="Glyph of the Gladiator",      effect="+18 Sta, +20 Resilience",      role="tank" },
    { slot=1, name="Arcanum of the Stalwart Protector", effect="+10 Defense, +15 Block", role="tank" },
    { slot=1, name="Arcanum of Blissful Mending",  effect="+35 Heal Power, +7 MP5",      role="heal" },
    { slot=1, name="Arcanum of Burning Mysteries", effect="+18 SP, +20 Crit",            role="dps"  },

    -- SHOULDERS (3)
    { slot=3, name="Greater Inscription of Vengeance",  effect="+30 AP, +10 Crit",       role="dps"  },
    { slot=3, name="Greater Inscription of the Orb",    effect="+12 SP, +15 Crit",       role="heal" },
    { slot=3, name="Greater Inscription of Warding",    effect="+15 Dodge, +10 Defense", role="tank" },
    { slot=3, name="Greater Inscription of Discipline", effect="+18 Heal Power, +4 MP5", role="heal" },
    { slot=3, name="Greater Inscription of the Blade",  effect="+26 AP, +14 Crit",       role="dps"  },
    { slot=3, name="Master's Inscription of Vengeance", effect="+46 AP, +15 Crit (Inscr.)", role="dps" },
    { slot=3, name="Master's Inscription of the Crag",  effect="+18 SP, +20 Crit (Inscr.)", role="heal" },

    -- BACK / CLOAK (15)
    { slot=15, name="Enchant Cloak - Greater Agility",  effect="+12 Agility",            role="dps"  },
    { slot=15, name="Enchant Cloak - Subtlety",         effect="-2% Threat",             role="dps"  },
    { slot=15, name="Enchant Cloak - Greater Arcane Resistance", effect="+15 Arcane Res", role="all" },
    { slot=15, name="Enchant Cloak - Dodge",            effect="+12 Dodge",              role="tank" },
    { slot=15, name="Enchant Cloak - Spell Penetration",effect="+20 Spell Pen",          role="dps"  },

    -- CHEST (5)
    { slot=5, name="Enchant Chest - Exceptional Stats", effect="+6 All Stats",           role="all"  },
    { slot=5, name="Enchant Chest - Major Resilience",  effect="+15 Resilience",         role="tank" },
    { slot=5, name="Enchant Chest - Exceptional Health",effect="+150 Health",            role="tank" },
    { slot=5, name="Enchant Chest - Major Spirit",      effect="+15 Spirit",             role="heal" },

    -- WRISTS (9)
    { slot=9, name="Enchant Bracer - Assault",          effect="+24 AP",                 role="dps"  },
    { slot=9, name="Enchant Bracer - Spellpower",       effect="+15 SP",                 role="heal" },
    { slot=9, name="Enchant Bracer - Greater Strength", effect="+12 Strength",           role="dps"  },
    { slot=9, name="Enchant Bracer - Stats",            effect="+4 All Stats",           role="all"  },
    { slot=9, name="Enchant Bracer - Major Defense",    effect="+12 Defense",            role="tank" },

    -- HANDS (10)
    { slot=10, name="Enchant Gloves - Superior Agility", effect="+15 Agility",           role="dps"  },
    { slot=10, name="Enchant Gloves - Major Strength",   effect="+15 Strength",          role="dps"  },
    { slot=10, name="Enchant Gloves - Spell Strike",     effect="+15 Spell Hit",         role="dps"  },
    { slot=10, name="Enchant Gloves - Blasting",         effect="+15 Spell Crit",        role="dps"  },
    { slot=10, name="Enchant Gloves - Major Healing",    effect="+35 Healing Power",     role="heal" },
    { slot=10, name="Enchant Gloves - Threat",           effect="+2% Threat",            role="tank" },
    { slot=10, name="Enchant Gloves - Precise Strikes",  effect="+10 Expertise",         role="dps"  },

    -- LEGS (7)
    { slot=7, name="Nethercobra Leg Armor",   effect="+50 AP, +12 Crit",                 role="dps"  },
    { slot=7, name="Mystic Spellthread",      effect="+50 Heal Power, +20 Stamina",      role="heal" },
    { slot=7, name="Golden Spellthread",      effect="+35 Heal Power, +12 Stamina",      role="heal" },
    { slot=7, name="Nethercleft Leg Armor",   effect="+40 Stamina, +12 Agility",         role="tank" },
    { slot=7, name="Cobrahide Leg Armor",     effect="+40 AP, +10 Crit",                 role="dps"  },
    { slot=7, name="Runic Spellthread",       effect="+35 Spell Damage, +20 Stamina",    role="dps"  },

    -- FEET (8)
    { slot=8, name="Enchant Boots - Cat's Swiftness",   effect="+6 Agi, minor run speed", role="dps" },
    { slot=8, name="Enchant Boots - Boar's Speed",      effect="+9 Sta, minor run speed", role="tank"},
    { slot=8, name="Enchant Boots - Dexterity",         effect="+12 Agility",            role="dps"  },
    { slot=8, name="Enchant Boots - Fortitude",         effect="+12 Stamina",            role="tank" },
    { slot=8, name="Enchant Boots - Surefooted",        effect="+10 Hit, minor run speed",role="dps" },

    -- MAIN HAND (16)
    { slot=16, name="Enchant Weapon - Mongoose",        effect="+120 Agi proc, +2% Haste proc", role="dps" },
    { slot=16, name="Enchant Weapon - Executioner",     effect="+840 ArP proc",          role="dps"  },
    { slot=16, name="Enchant Weapon - Savagery",        effect="+70 AP",                 role="dps"  },
    { slot=16, name="Enchant Weapon - Soulfrost",       effect="+54 Frost/Shadow Damage",role="dps"  },
    { slot=16, name="Enchant Weapon - Sunfire",         effect="+50 Fire/Arcane Damage", role="dps"  },
    { slot=16, name="Enchant Weapon - Greater Spell Power", effect="+30 Spell Power",    role="heal" },
    { slot=16, name="Enchant Weapon - Spellsurge",      effect="Mana restore proc on cast",role="heal"},
    { slot=16, name="Enchant Weapon - Healing Power",   effect="+29 Healing Power",      role="heal" },

    -- OFF HAND (17)
    { slot=17, name="Enchant Weapon - Major Agility",   effect="+35 Agility",            role="dps"  },
    { slot=17, name="Enchant Weapon - Mongoose",        effect="+120 Agi proc",          role="dps"  },
    { slot=17, name="Enchant Shield - Major Stamina",   effect="+18 Stamina",            role="tank" },
    { slot=17, name="Enchant Shield - Resilience",      effect="+12 Resilience",         role="tank" },
    { slot=17, name="Enchant Shield - Intellect",       effect="+12 Intellect",          role="heal" },

    -- RANGED (18)
    { slot=18, name="Stabilized Eternium Scope",        effect="+28 Ranged Crit",        role="dps"  },
    { slot=18, name="Khorium Scope",                    effect="+12 Ranged Crit",        role="dps"  },
}

-- ─────────────────────────────────────────────────────────────────────────────
-- GEM RECOMMENDATIONS  (TBC 2.4.3 — Sunwell gems = Crimsonspinel tier)
-- Format: { color, name, effect, role }
-- color: "red" | "yellow" | "blue" | "meta" | "prismatic"
-- ─────────────────────────────────────────────────────────────────────────────
SI.GEM_DB = {
    -- META
    { color="meta", name="Relentless Earthstorm Diamond",   effect="+12 Agi, 3% Increased Critical Damage", role="dps"  },
    { color="meta", name="Chaotic Skyfire Diamond",         effect="+12 Crit, 3% Increased Critical Damage",role="dps"  },
    { color="meta", name="Swift Skyfire Diamond",           effect="+24 AP, Minor Run Speed",               role="dps"  },
    { color="meta", name="Mystical Skyfire Diamond",        effect="Haste Rating proc on spell cast",       role="dps"  },
    { color="meta", name="Bracing Earthstorm Diamond",      effect="-2% Threat, 1% Reduced Physical Dmg",   role="tank" },
    { color="meta", name="Eternal Earthstorm Diamond",      effect="+12 Defense, +5% Shield Block Value",   role="tank" },
    { color="meta", name="Insightful Earthstorm Diamond",   effect="Mana Restore proc, +12 Intellect",      role="heal" },
    { color="meta", name="Bracing Earthstorm Diamond",      effect="-2% Threat, 1% Reduced Physical Dmg",   role="heal" },

    -- RED (pure offense)
    { color="red", name="Bold Crimsonspinel",           effect="+10 Strength",      role="dps"  },
    { color="red", name="Runed Crimsonspinel",          effect="+12 Spell Power",   role="dps"  },
    { color="red", name="Bright Crimsonspinel",         effect="+20 Attack Power",  role="dps"  },
    { color="red", name="Delicate Crimsonspinel",       effect="+10 Agility",       role="dps"  },
    { color="red", name="Teardrop Crimsonspinel",       effect="+22 Healing Power", role="heal" },
    { color="red", name="Bold Living Ruby",             effect="+8 Strength",       role="dps"  },
    { color="red", name="Runed Living Ruby",            effect="+9 Spell Damage",   role="dps"  },

    -- YELLOW (utility/hybrid)
    { color="yellow", name="Smooth Crimsonspinel",      effect="+10 Crit Rating",   role="dps"  },
    { color="yellow", name="Thick Crimsonspinel",       effect="+15 Stamina",       role="tank" },
    { color="yellow", name="Rigid Crimsonspinel",       effect="+10 Hit Rating",    role="dps"  },
    { color="yellow", name="Inscribed Crimsonspinel",   effect="+6 Crit, +6 Str",   role="dps"  },
    { color="yellow", name="Reckless Pyrestone",        effect="+9 SP, +5 Haste",   role="dps"  },
    { color="yellow", name="Quick Dawnstone",           effect="+8 Haste",          role="dps"  },
    { color="yellow", name="Brilliant Dawnstone",       effect="+8 Intellect",      role="heal" },

    -- BLUE (stamina / healing / mana)
    { color="blue", name="Solid Crimsonspinel",         effect="+15 Stamina",       role="tank" },
    { color="blue", name="Lustrous Pyrestone",          effect="+6 MP5",            role="heal" },
    { color="blue", name="Sparkling Crimsonspinel",     effect="+10 Spirit",        role="heal" },
    { color="blue", name="Royal Nightseye",             effect="+9 Heal Power, +2 MP5", role="heal" },
    { color="blue", name="Enduring Talasite",           effect="+6 Def Rtg, +6 Sta",role="tank" },
    { color="blue", name="Timeless Chrysoprase",        effect="+6 All Stats",      role="all"  },

    -- ORANGE (hybrid red+yellow)
    { color="orange", name="Deadly Pyrestone",          effect="+6 Crit, +6 AP",    role="dps"  },
    { color="orange", name="Glinting Noble Topaz",      effect="+6 Hit, +4 Agi",    role="dps"  },
    { color="orange", name="Potent Noble Topaz",        effect="+9 SP, +5 Crit",    role="dps"  },
    { color="orange", name="Luminous Noble Topaz",      effect="+9 Heal Power, +5 MP5", role="heal" },

    -- GREEN (hybrid blue+yellow)
    { color="green", name="Jagged Talasite",            effect="+10 Crit, +6 Sta",  role="dps"  },
    { color="green", name="Durable Talasite",           effect="+6 Def Rtg, +9 Sta",role="tank" },
}

-- ── Helpers for UI to query ───────────────────────────────────────────────────
function SI:GetEnchantSuggestions(slotId, role)
    local out = {}
    for _, e in ipairs(SI.ENCHANT_DB) do
        if e.slot == slotId and (e.role == role or e.role == "all") then
            out[#out+1] = e
        end
    end
    return out
end

function SI:GetGemSuggestions(color, role)
    color = color or "red"
    role  = role  or "dps"
    local out = {}
    for _, g in ipairs(SI.GEM_DB) do
        if g.color == color and (g.role == role or g.role == "all") then
            out[#out+1] = g
        end
    end
    return out
end

-- Check current enchant on a slot (reads tooltip text for "Enchanted:" line)
function SI:GetEquippedEnchantName(slotId)
    local link = GetInventoryItemLink("player", slotId)
    if not link then return nil end
    scanTip:ClearLines()
    pcall(function() scanTip:SetInventoryItem("player", slotId) end)
    for i = 1, scanTip:NumLines() do
        local fs = _G["SlyItemizerScanTipTextLeft"..i]
        if fs and fs:GetText() then
            local txt = fs:GetText()
            local enchant = txt:match("^Enchanted: (.+)") or txt:match("^(Enchant.+)$")
            if enchant then return enchant end
        end
    end
    return nil
end
