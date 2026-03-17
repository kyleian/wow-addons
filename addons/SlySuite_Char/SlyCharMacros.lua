-- ============================================================
-- SlyCharMacros.lua
-- Curated TBC class macro library for the SlyChar Macros wing.
-- Keyed by UnitClassBase token: SLYCHAR_CLASS_MACROS["WARRIOR"], etc.
-- Each entry: spec, name, icon (texture short-name), body, tip.
-- Add a new class block below to support additional classes.
-- ============================================================

SLYCHAR_CLASS_MACROS = SLYCHAR_CLASS_MACROS or {}
SLYCHAR_CLASS_MACROS["WARRIOR"] = {

    -- ── Arms ─────────────────────────────────────────────────────────────────
    {
        spec="Arms", name="Charge",
        icon="ability_warrior_charge",
        body="#showtooltip Charge\n/cast [nostance:1] Battle Stance\n/cast Charge",
        tip="Stance-swap to Battle Stance then charge the target from range.",
    },
    {
        spec="Arms", name="Intercept",
        icon="ability_gouge",
        body="#showtooltip Intercept\n/cast [nostance:3] Berserker Stance\n/cast Intercept",
        tip="Stance-swap to Berserker Stance then Intercept (10–25 yd closer).",
    },
    {
        spec="Arms", name="Mortal Strike",
        icon="ability_warrior_saver",
        body="#showtooltip Mortal Strike\n/cast Mortal Strike",
        tip="Core Arms nuke. Applies the 50% healing debuff.",
    },
    {
        spec="Arms", name="Whirlwind",
        icon="ability_whirlwind",
        body="#showtooltip Whirlwind\n/cast Whirlwind",
        tip="AoE melee + single-target filler when MS is on cooldown.",
    },
    {
        spec="Arms", name="Overpower",
        icon="ability_meleeDamage",
        body="#showtooltip Overpower\n/cast [nostance:1] Battle Stance\n/cast Overpower",
        tip="Proc-reaction to target dodge. Must be in Battle Stance.",
    },
    {
        spec="Arms", name="Execute",
        icon="ability_warrior_decimate",
        body="#showtooltip Execute\n/cast Execute",
        tip="Sub-20% execute finisher. Converts excess rage to damage.",
    },
    {
        spec="Arms", name="Sweeping Strikes Cleave",
        icon="ability_rogue_sliceDice",
        body="#showtooltip Sweeping Strikes\n/cast Sweeping Strikes\n/cast Whirlwind",
        tip="Activate Sweeping Strikes then immediately Whirlwind for double 2-target hit.",
    },
    {
        spec="Arms", name="Heroic Strike",
        icon="ability_racial_bloodrage",
        body="#showtooltip Heroic Strike\n/cast Heroic Strike",
        tip="Queues Heroic Strike on your next swing. Use when rage is above 60.",
    },
    {
        spec="Arms", name="Sunder Armor",
        icon="ability_warrior_sunderArmor",
        body="#showtooltip Sunder Armor\n/cast Sunder Armor",
        tip="Apply or refresh Sunder Armor (-520 armor per stack, 5 stacks max).",
    },
    {
        spec="Arms", name="Rend",
        icon="ability_gouge",
        body="#showtooltip Rend\n/cast [nostance:1] Battle Stance\n/cast Rend",
        tip="Apply Rend bleed DoT. Requires Battle Stance.",
    },
    {
        spec="Arms", name="Pummel",
        icon="ability_warrior_pummelRank1",
        body="#showtooltip Pummel\n/cast [nostance:3] Berserker Stance\n/cast Pummel",
        tip="Stance-swap to Berserker Stance then interrupt the target's cast.",
    },
    {
        spec="Arms", name="Battle Shout",
        icon="ability_warrior_battleshout",
        body="#showtooltip Battle Shout\n/cast [nostance:1] Battle Stance\n/cast Battle Shout",
        tip="Refresh Battle Shout (+AP buff). Swaps to Battle Stance first.",
    },
    {
        spec="Arms", name="Hamstring",
        icon="ability_shockwave",
        body="#showtooltip Hamstring\n/cast Hamstring",
        tip="Reduce target movement speed by 50% for 15s.",
    },

    -- ── Fury ─────────────────────────────────────────────────────────────────
    {
        spec="Fury", name="Bloodthirst",
        icon="ability_gutRip",
        body="#showtooltip Bloodthirst\n/cast Bloodthirst",
        tip="Core Fury nuke. Use on every cooldown — highest priority.",
    },
    {
        spec="Fury", name="Whirlwind",
        icon="ability_whirlwind",
        body="#showtooltip Whirlwind\n/cast Whirlwind",
        tip="Second-highest Fury GCD. Use when not held for BT.",
    },
    {
        spec="Fury", name="Heroic Strike",
        icon="ability_racial_bloodrage",
        body="#showtooltip Heroic Strike\n/cast Heroic Strike",
        tip="Off-GCD rage dump. Queue when above ~50–60 rage.",
    },
    {
        spec="Fury", name="Cleave (AoE)",
        icon="ability_warrior_cleave",
        body="#showtooltip Cleave\n/cast Cleave",
        tip="Replace Heroic Strike with Cleave on 2+ target pulls.",
    },
    {
        spec="Fury", name="Death Wish",
        icon="spell_shadow_deathscream",
        body="#showtooltip Death Wish\n/cast Death Wish",
        tip="30% damage bonus for 30s. Pain amplification — activate on pull.",
    },
    {
        spec="Fury", name="Recklessness",
        icon="ability_warrior_challange",
        body="#showtooltip Recklessness\n/cast [nostance:3] Berserker Stance\n/cast Recklessness",
        tip="Stance-swap to Berserker then 100% crit chance for 15s (3 charges). Big CD.",
    },
    {
        spec="Fury", name="CD Stack",
        icon="spell_shadow_deathscream",
        body="#showtooltip Death Wish\n/use 13\n/use 14\n/cast Death Wish\n/cast [nostance:3] Berserker Stance\n/cast Recklessness",
        tip="Fire both on-use trinkets + Death Wish + Recklessness in one button.",
    },
    {
        spec="Fury", name="Berserker Rage",
        icon="spell_nature_ancestralguardian",
        body="#showtooltip Berserker Rage\n/cast Berserker Rage",
        tip="Immune to Fear/Sap/Incapacitate for 10s. Generates extra rage from damage.",
    },
    {
        spec="Fury", name="Pummel",
        icon="ability_warrior_pummelRank1",
        body="#showtooltip Pummel\n/cast [nostance:3] Berserker Stance\n/cast Pummel",
        tip="Stance-swap to Berserker Stance then interrupt target cast.",
    },
    {
        spec="Fury", name="Battle Shout",
        icon="ability_warrior_battleshout",
        body="#showtooltip Battle Shout\n/cast [nostance:1] Battle Stance\n/cast Battle Shout",
        tip="Swap to Battle Stance and refresh Battle Shout buff for the group.",
    },

    -- ── Tank ─────────────────────────────────────────────────────────────────
    {
        spec="Tank", name="Shield Slam",
        icon="ability_warrior_shieldbash",
        body="#showtooltip Shield Slam\n/cast Shield Slam",
        tip="Highest single-hit threat generator. Use on cooldown every pull.",
    },
    {
        spec="Tank", name="Devastate",
        icon="ability_warrior_senzionslam",
        body="#showtooltip Devastate\n/cast Devastate",
        tip="Core tank spam. Applies Sunder Armor stacks + good threat per hit.",
    },
    {
        spec="Tank", name="Revenge",
        icon="ability_warrior_revenge",
        body="#showtooltip Revenge\n/cast Revenge",
        tip="Proc-based — activates after you dodge/parry/block. High TPS when it fires.",
    },
    {
        spec="Tank", name="Heroic Strike",
        icon="ability_racial_bloodrage",
        body="#showtooltip Heroic Strike\n/cast Heroic Strike",
        tip="Rage dump for extra threat. Queue when rage is above 50 and won't cap.",
    },
    {
        spec="Tank", name="Shield Block",
        icon="ability_warrior_shieldblock",
        body="#showtooltip Shield Block\n/cast Shield Block",
        tip="Guarantees block on next 2 attacks for 5s. Use to proc Revenge.",
    },
    {
        spec="Tank", name="Taunt",
        icon="spell_nature_reincarnation",
        body="#showtooltip Taunt\n/cast Taunt",
        tip="Force target to attack you for 3s and set your threat equal to theirs.",
    },
    {
        spec="Tank", name="Mocking Blow",
        icon="ability_warrior_mockingblow",
        body="#showtooltip Mocking Blow\n/cast Mocking Blow",
        tip="Backup taunt if Taunt is on cooldown. 6s, same threat mechanics.",
    },
    {
        spec="Tank", name="Challenging Shout",
        icon="ability_warrior_intensifyrage",
        body="#showtooltip Challenging Shout\n/cast Challenging Shout",
        tip="AoE taunt — forces all nearby enemies to attack you for 6s. 10 min CD.",
    },
    {
        spec="Tank", name="Shield Bash",
        icon="ability_warrior_shieldbash",
        body="#showtooltip Shield Bash\n/cast Shield Bash",
        tip="Interrupt + silences the spellschool for 3s. Main interrupt in Defensive Stance.",
    },
    {
        spec="Tank", name="Spell Reflect",
        icon="ability_warrior_spellreflection",
        body="#showtooltip Spell Reflection\n/cast [nostance:2] Defensive Stance\n/cast Spell Reflection",
        tip="Swap to Defensive Stance and reflect the next spell back at the caster.",
    },
    {
        spec="Tank", name="Last Stand",
        icon="ability_warrior_recklessness",
        body="#showtooltip Last Stand\n/cast Last Stand",
        tip="Increases max HP by 30% for 20s. Use when dropping below ~25% HP.",
    },
    {
        spec="Tank", name="Shield Wall",
        icon="ability_warrior_shieldblock",
        body="#showtooltip Shield Wall\n/cast Shield Wall",
        tip="60% damage reduction for 10s. Major survivability cooldown. 30 min CD.",
    },
    {
        spec="Tank", name="Emergency CDs",
        icon="ability_warrior_revenge",
        body="#showtooltip Last Stand\n/cast Last Stand\n/cast Shield Wall",
        tip="Pop both Last Stand and Shield Wall together in a crisis.",
    },
    {
        spec="Tank", name="Thunder Clap",
        icon="spell_nature_thunderclap",
        body="#showtooltip Thunder Clap\n/cast [nostance:2] Defensive Stance\n/cast Thunder Clap",
        tip="AoE: slows attack speed of all nearby mobs. Keep on cooldown on pulls.",
    },
    {
        spec="Tank", name="Demoralizing Shout",
        icon="ability_warrior_battleshout",
        body="#showtooltip Demoralizing Shout\n/cast Demoralizing Shout",
        tip="Reduce nearby enemies' attack damage. Keep refreshed on raid bosses.",
    },
    {
        spec="Tank", name="Disarm",
        icon="ability_warrior_disarm",
        body="#showtooltip Disarm\n/cast [nostance:2] Defensive Stance\n/cast Disarm",
        tip="Disarm target for 10s. Requires Defensive Stance. Use on physical mobs.",
    },
    {
        spec="Tank", name="Sunder Armor",
        icon="ability_warrior_sunderArmor",
        body="#showtooltip Sunder Armor\n/cast Sunder Armor",
        tip="Pre-Devastate armor debuff. Keep 5 stacks on bosses for the raid.",
    },

    -- ── PvP ──────────────────────────────────────────────────────────────────
    {
        spec="PvP", name="Charge",
        icon="ability_warrior_charge",
        body="#showtooltip Charge\n/cast [nostance:1] Battle Stance\n/cast Charge",
        tip="Swap to Battle Stance and Charge the target to start a fight.",
    },
    {
        spec="PvP", name="Intercept",
        icon="ability_gouge",
        body="#showtooltip Intercept\n/cast [nostance:3] Berserker Stance\n/cast Intercept",
        tip="Berserker Stance gap-closer. Stuns for 3s. Use to chase or re-engage.",
    },
    {
        spec="PvP", name="Hamstring",
        icon="ability_shockwave",
        body="#showtooltip Hamstring\n/cast Hamstring",
        tip="50% movement slow. Keep applying — most important PvP button.",
    },
    {
        spec="PvP", name="Piercing Howl",
        icon="spell_nature_earthquake",
        body="#showtooltip Piercing Howl\n/cast Piercing Howl",
        tip="(Fury talent) AoE Hamstring — slows all nearby enemies. No cooldown.",
    },
    {
        spec="PvP", name="Mortal Strike",
        icon="ability_warrior_saver",
        body="#showtooltip Mortal Strike\n/cast Mortal Strike",
        tip="50% healing debuff. Critical vs. healer-supported targets.",
    },
    {
        spec="PvP", name="Intimidating Shout",
        icon="ability_bullrush",
        body="#showtooltip Intimidating Shout\n/cast Intimidating Shout",
        tip="Fear nearby enemies for 8s. Use to peel, create distance, or peel adds.",
    },
    {
        spec="PvP", name="Fear + Hamstring",
        icon="ability_bullrush",
        body="/cast Intimidating Shout\n/cast Hamstring",
        tip="Fear the pack then immediately Hamstring your priority target.",
    },
    {
        spec="PvP", name="Berserker Rage (Break Fear)",
        icon="spell_nature_ancestralguardian",
        body="#showtooltip Berserker Rage\n/cast Berserker Rage",
        tip="Break out of Fear/Sap/Incapacitate and become immune for 10s.",
    },
    {
        spec="PvP", name="Pummel Interrupt",
        icon="ability_warrior_pummelRank1",
        body="#showtooltip Pummel\n/cast [nostance:3] Berserker Stance\n/cast Pummel",
        tip="Stance-swap to Berserker and interrupt. Silences that spell school for 4s.",
    },
    {
        spec="PvP", name="Shield Bash Interrupt",
        icon="ability_warrior_shieldbash",
        body="#showtooltip Shield Bash\n/cast [nostance:2] Defensive Stance\n/cast Shield Bash",
        tip="Swap to Defensive and interrupt. 3s silence. Use when off Pummel CD.",
    },
    {
        spec="PvP", name="Overpower (counter dodge)",
        icon="ability_meleeDamage",
        body="#showtooltip Overpower\n/cast [nostance:1] Battle Stance\n/cast Overpower",
        tip="Swap to Battle Stance and Overpower on the target's dodge proc.",
    },
    {
        spec="PvP", name="Disarm",
        icon="ability_warrior_disarm",
        body="#showtooltip Disarm\n/cast [nostance:2] Defensive Stance\n/cast Disarm",
        tip="Swap to Defensive Stance and disarm target's weapon for 10s.",
    },
    {
        spec="PvP", name="Retaliation",
        icon="ability_warrior_challange",
        body="#showtooltip Retaliation\n/cast [nostance:1] Battle Stance\n/cast Retaliation",
        tip="Battle Stance: auto-attacks any attacker for 12s. Great burst defense.",
    },
    {
        spec="PvP", name="Execute",
        icon="ability_warrior_decimate",
        body="#showtooltip Execute\n/cast Execute",
        tip="Sub-20% finisher. Rage is converted to massive damage.",
    },
}

-- ============================================================
-- Mage
-- ============================================================
SLYCHAR_CLASS_MACROS["MAGE"] = {

    -- ── Arcane ───────────────────────────────────────────────────────────────
    {
        spec="Arcane", name="Arcane Blast",
        icon="spell_arcane_arcane03",
        body="#showtooltip Arcane Blast\n/cast Arcane Blast",
        tip="Core Arcane nuke. Stacks up to 4 times increasing damage and mana cost.",
    },
    {
        spec="Arcane", name="Arcane Missiles",
        icon="spell_nature_starfall",
        body="#showtooltip Arcane Missiles\n/cast Arcane Missiles",
        tip="Channeled follow-up to high Arcane Blast stacks to dump mana efficiently.",
    },
    {
        spec="Arcane", name="Arcane Power",
        icon="spell_nature_lightning",
        body="#showtooltip Arcane Power\n/cast Arcane Power",
        tip="+30% spell damage and cost for 15s. Activate at max Arcane Blast stacks.",
    },
    {
        spec="Arcane", name="Presence of Mind + AB",
        icon="spell_nature_enchantarmor",
        body="#showtooltip Arcane Blast\n/cast Presence of Mind\n/cast Arcane Blast",
        tip="Instantly cast one Arcane Blast. Pair with Arcane Power for a spike.",
    },
    {
        spec="Arcane", name="Icy Veins",
        icon="spell_frost_coldhearted",
        body="#showtooltip Icy Veins\n/cast Icy Veins",
        tip="20% cast speed increase for 20s. Synergises with any spec on demand.",
    },
    {
        spec="Arcane", name="CD Stack",
        icon="spell_nature_lightning",
        body="#showtooltip Arcane Power\n/use 13\n/use 14\n/cast Arcane Power\n/cast Icy Veins",
        tip="Pop both trinkets + Arcane Power + Icy Veins in one button.",
    },
    {
        spec="Arcane", name="Counterspell",
        icon="spell_frost_iceshock",
        body="#showtooltip Counterspell\n/cast Counterspell",
        tip="Interrupt target's cast and lock that school for 8s.",
    },
    {
        spec="Arcane", name="Spellsteal",
        icon="spell_arcane_arcane01",
        body="#showtooltip Spellsteal\n/cast Spellsteal",
        tip="Steal one beneficial buff from the target. Invaluable in TBC raids and PvP.",
    },
    {
        spec="Arcane", name="Evocation",
        icon="spell_nature_purge",
        body="#showtooltip Evocation\n/cast Evocation",
        tip="Regen 15% mana/sec for 8s. Use when oom — cancel early if interrupted.",
    },

    -- ── Fire ─────────────────────────────────────────────────────────────────
    {
        spec="Fire", name="Fireball",
        icon="spell_fire_fireball02",
        body="#showtooltip Fireball\n/cast Fireball",
        tip="Core Fire nuke. High crit chance procs Ignite for strong DoT.",
    },
    {
        spec="Fire", name="Scorch",
        icon="spell_fire_soulburn",
        body="#showtooltip Scorch\n/cast Scorch",
        tip="Fast cast filler. Imp. Scorch applies a 15% Fire vulnerability stack (5 max).",
    },
    {
        spec="Fire", name="Fire Blast",
        icon="spell_fire_fireball",
        body="#showtooltip Fire Blast\n/cast Fire Blast",
        tip="Instant off-GCD — use to fish for Hot Streak procs alongside Fireball/Scorch.",
    },
    {
        spec="Fire", name="Pyroblast",
        icon="spell_fire_fireball",
        body="#showtooltip Pyroblast\n/cast Pyroblast",
        tip="Opener or Hot Streak instant proc. Highest base damage Fire spell.",
    },
    {
        spec="Fire", name="Combustion",
        icon="spell_fire_sealoffire",
        body="#showtooltip Combustion\n/cast Combustion",
        tip="Next 3 Fire crits guaranteed. Use when about to Fireball spam for burst.",
    },
    {
        spec="Fire", name="CD Stack",
        icon="spell_fire_sealoffire",
        body="#showtooltip Combustion\n/use 13\n/use 14\n/cast Combustion\n/cast Icy Veins",
        tip="Pop both trinkets + Combustion + Icy Veins together on pull.",
    },
    {
        spec="Fire", name="Dragon's Breath",
        icon="inv_misc_head_dragon_01",
        body="#showtooltip Dragon's Breath\n/cast Dragon's Breath",
        tip="AoE cone disorient for 3s. Strong on-demand interrupt/peel in Fire builds.",
    },
    {
        spec="Fire", name="Blast Wave",
        icon="spell_holy_excorcism_02",
        body="#showtooltip Blast Wave\n/cast Blast Wave",
        tip="AoE knockback + slows. Use for AoE pulls or emergencies.",
    },
    {
        spec="Fire", name="Counterspell",
        icon="spell_frost_iceshock",
        body="#showtooltip Counterspell\n/cast Counterspell",
        tip="Interrupt target's cast and lock that school for 8s.",
    },

    -- ── Frost ─────────────────────────────────────────────────────────────────
    {
        spec="Frost", name="Frostbolt",
        icon="spell_frost_frostbolt02",
        body="#showtooltip Frostbolt\n/cast Frostbolt",
        tip="Core Frost nuke. Applies chill/slow. Procs Shatter on Frozen targets.",
    },
    {
        spec="Frost", name="Ice Lance",
        icon="spell_frost_frostblast",
        body="#showtooltip Ice Lance\n/cast Ice Lance",
        tip="Instant, cheap, triple damage vs. Frozen. Follow up after Frost Nova/FoF.",
    },
    {
        spec="Frost", name="Shatter Combo",
        icon="spell_frost_frostbolt02",
        body="#showtooltip Frostbolt\n/cast Frost Nova\n/cast Ice Lance",
        tip="Root with Frost Nova then instantly Ice Lance for guaranteed Shatter crit.",
    },
    {
        spec="Frost", name="Fingers of Frost Ice Lance",
        icon="spell_frost_frostblast",
        body="#showtooltip Ice Lance\n/cast Ice Lance",
        tip="Use on Fingers of Frost proc — counts as frozen target, full Shatter bonus.",
    },
    {
        spec="Frost", name="Deep Freeze",
        icon="spell_frost_stun",
        body="#showtooltip Deep Freeze\n/cast Deep Freeze",
        tip="Hard stun on Frozen/chilled target for 5s. Highest Frost spike setup.",
    },
    {
        spec="Frost", name="Icy Veins",
        icon="spell_frost_coldhearted",
        body="#showtooltip Icy Veins\n/cast Icy Veins",
        tip="20% haste for 20s. Activate on cooldown — core DPS cooldown for Frost.",
    },
    {
        spec="Frost", name="CD Stack",
        icon="spell_frost_coldhearted",
        body="#showtooltip Icy Veins\n/use 13\n/use 14\n/cast Icy Veins\n/cast Cold Snap",
        tip="Pop both trinkets + Icy Veins + Cold Snap together on pull.",
    },
    {
        spec="Frost", name="Frost Nova",
        icon="spell_frost_frostnova",
        body="#showtooltip Frost Nova\n/cast Frost Nova",
        tip="Instantly freezes all nearby enemies. Enables guaranteed Shatter crits.",
    },
    {
        spec="Frost", name="Cone of Cold",
        icon="spell_frost_glacier",
        body="#showtooltip Cone of Cold\n/cast Cone of Cold",
        tip="AoE frontal chill + damage. Use for AoE pulls or Shatter AoE with Nova.",
    },
    {
        spec="Frost", name="Cold Snap",
        icon="spell_frost_wizardmark",
        body="#showtooltip Cold Snap\n/cast Cold Snap",
        tip="Instantly resets all Frost spell cooldowns including Frost Nova and Ice Block.",
    },
    {
        spec="Frost", name="Counterspell",
        icon="spell_frost_iceshock",
        body="#showtooltip Counterspell\n/cast Counterspell",
        tip="Interrupt target's cast and lock that school for 8s.",
    },

    -- ── PvP ───────────────────────────────────────────────────────────────────
    {
        spec="PvP", name="Blink",
        icon="spell_arcane_blink",
        body="#showtooltip Blink\n/cast Blink",
        tip="Teleport 20 yards forward and clear snares/roots. Highest priority escape.",
    },
    {
        spec="PvP", name="Ice Block",
        icon="spell_frost_frost",
        body="#showtooltip Ice Block\n/cast Ice Block",
        tip="Full immunity for 10s. Use to survive burst, reset CDs, or wait for help.",
    },
    {
        spec="PvP", name="Blink Break + Escape",
        icon="spell_arcane_blink",
        body="/cast Blink\n/cancelaura Ice Block",
        tip="Blink out of root/slow then cancel Ice Block if active to resume casting.",
    },
    {
        spec="PvP", name="Frost Nova + Blink",
        icon="spell_frost_frostnova",
        body="#showtooltip Frost Nova\n/cast Frost Nova\n/cast Blink",
        tip="Root melee then instantly Blink to max range.",
    },
    {
        spec="PvP", name="Counterspell",
        icon="spell_frost_iceshock",
        body="#showtooltip Counterspell\n/cast Counterspell",
        tip="Interrupt and school-lock for 8s. Most important PvP button.",
    },
    {
        spec="PvP", name="Polymorph",
        icon="spell_magic_polymorphchicken",
        body="#showtooltip Polymorph\n/cast Polymorph",
        tip="Sheep target for 10s (soft CC). Breaks on damage — don't dot first.",
    },
    {
        spec="PvP", name="Spellsteal",
        icon="spell_arcane_arcane01",
        body="#showtooltip Spellsteal\n/cast Spellsteal",
        tip="Steal a beneficial buff. Mandatory vs. Paladin bubbles, Druid HoTs, etc.",
    },
    {
        spec="PvP", name="Slow",
        icon="spell_arcane_slow",
        body="#showtooltip Slow\n/cast Slow",
        tip="(Arcane) Reduce movement/attack/cast speed by 60%. No cooldown.",
    },
    {
        spec="PvP", name="Dragon's Breath",
        icon="inv_misc_head_dragon_01",
        body="#showtooltip Dragon's Breath\n/cast Dragon's Breath",
        tip="(Fire) AoE cone disorient 3s. Use to interrupt a healer or peel melee.",
    },
    {
        spec="PvP", name="Deep Freeze",
        icon="spell_frost_stun",
        body="#showtooltip Deep Freeze\n/cast Deep Freeze",
        tip="(Frost) Stun a Frozen target for 5s. Follow with Shatter burst.",
    },
    {
        spec="PvP", name="Mana Shield",
        icon="spell_shadow_detectlesserinvisibility",
        body="#showtooltip Mana Shield\n/cast Mana Shield",
        tip="Absorb damage from mana instead of HP. Useful against burst when low HP.",
    },
    {
        spec="PvP", name="Remove Curse",
        icon="spell_nature_removecurse",
        body="#showtooltip Remove Curse\n/cast [@player] Remove Curse",
        tip="Remove a curse from yourself. Cast on focus: replace @player with @focus.",
    },
}

-- ============================================================
-- PALADIN
-- ============================================================
SLYCHAR_CLASS_MACROS["PALADIN"] = {

    -- ── Holy ─────────────────────────────────────────────────────────────────
    {
        spec="Holy", name="Holy Light",
        icon="spell_holy_holybolt",
        body="#showtooltip Holy Light\n/cast Holy Light",
        tip="Primary big heal. Use [target=mouseover] for mouseover healing.",
    },
    {
        spec="Holy", name="Flash of Light",
        icon="spell_holy_flashheal",
        body="#showtooltip Flash of Light\n/cast Flash of Light",
        tip="Fast cheap heal. Spam this in fights requiring reactive healing.",
    },
    {
        spec="Holy", name="Mouseover Holy Light",
        icon="spell_holy_holybolt",
        body="#showtooltip Holy Light\n/cast [@mouseover,help,nodead][@target] Holy Light",
        tip="Heals mouseover target if friendly; falls back to current target.",
    },
    {
        spec="Holy", name="Cleanse",
        icon="spell_holy_purify",
        body="#showtooltip Cleanse\n/cast [@mouseover,help,nodead][@target] Cleanse",
        tip="Removes disease, magic, and poison from mouseover or target.",
    },
    {
        spec="Holy", name="Divine Favor Flash",
        icon="spell_holy_heal",
        body="#showtooltip Flash of Light\n/cast Divine Favor\n/cast Flash of Light",
        tip="Pop Divine Favor for a guaranteed crit Flash of Light.",
    },
    {
        spec="Holy", name="Lay on Hands",
        icon="spell_holy_layonhands",
        body="#showtooltip Lay on Hands\n/cast [@target,help,nodead][@player] Lay on Hands",
        tip="Full HP emergency heal on friendly target or self.",
    },
    {
        spec="Holy", name="Beacon of Light",
        icon="ability_paladin_beaconoflight",
        body="#showtooltip Beacon of Light\n/cast [@focus] Beacon of Light",
        tip="Place Beacon on focus (usually tank) — all your heals copy there.",
    },
    {
        spec="Holy", name="Sacred Shield",
        icon="ability_paladin_sacredshield",
        body="#showtooltip Sacred Shield\n/cast [@focus] Sacred Shield",
        tip="Apply Sacred Shield to focus target for absorption on each hit.",
    },
    {
        spec="Holy", name="Judgement of Wisdom",
        icon="spell_holy_righteousfury",
        body="#showtooltip Judgement of Wisdom\n/cast Judgement of Wisdom",
        tip="Judge for mana return on every melee hit. Keep this up during fights.",
    },

    -- ── Prot ─────────────────────────────────────────────────────────────────
    {
        spec="Prot", name="Consecration",
        icon="spell_holy_consecration",
        body="#showtooltip Consecration\n/cast Consecration",
        tip="AoE holy damage under your feet. Core prot threat tool.",
    },
    {
        spec="Prot", name="Holy Shield",
        icon="ability_paladin_holyshield",
        body="#showtooltip Holy Shield\n/cast Holy Shield",
        tip="Increases block chance and deals holy damage on block. Keep active.",
    },
    {
        spec="Prot", name="Shield of Righteousness",
        icon="ability_paladin_shieldoftherighteousness",
        body="#showtooltip Shield of Righteousness\n/cast Shield of Righteousness",
        tip="Shield-slam style burst. Scales with block value.",
    },
    {
        spec="Prot", name="Avenger's Shield",
        icon="spell_holy_avengersshield",
        body="#showtooltip Avenger's Shield\n/cast Avenger's Shield",
        tip="Pulls casters; interrupts. Bounces between 3 targets.",
    },
    {
        spec="Prot", name="Hammer of the Righteous",
        icon="ability_paladin_hammeroftherigheousnew",
        body="#showtooltip Hammer of the Righteous\n/cast Hammer of the Righteous",
        tip="AoE physical hits 3 nearby targets. Great for multi-mob packs.",
    },
    {
        spec="Prot", name="Righteous Defense",
        icon="spell_holy_righteousdefense",
        body="#showtooltip Righteous Defense\n/cast [@target] Righteous Defense",
        tip="Taunt 3 mobs attacking the target. Prot's AoE taunt.",
    },
    {
        spec="Prot", name="Hand of Reckoning",
        icon="spell_holy_unyieldingfaith",
        body="#showtooltip Hand of Reckoning\n/cast Hand of Reckoning",
        tip="Single-target taunt. Deals holy damage if target is not targeting you.",
    },
    {
        spec="Prot", name="Hammer of Wrath",
        icon="spell_holy_sealofmight",
        body="#showtooltip Hammer of Wrath\n/cast Hammer of Wrath",
        tip="Ranged finisher usable sub-20%. Good for executing fleeing mobs.",
    },
    {
        spec="Prot", name="Turn Evil",
        icon="spell_holy_turnundead",
        body="#showtooltip Turn Evil\n/cast Turn Evil",
        tip="Fear undead or demons. Useful in Naxx/Sunwell trash.",
    },

    -- ── Ret ──────────────────────────────────────────────────────────────────
    {
        spec="Ret", name="Crusader Strike",
        icon="ability_paladin_crusaderstrike",
        body="#showtooltip Crusader Strike\n/cast Crusader Strike",
        tip="Core Ret filler on a 6-sec CD. Refreshes all Judgements.",
    },
    {
        spec="Ret", name="Divine Storm",
        icon="ability_paladin_divinestorm",
        body="#showtooltip Divine Storm\n/cast Divine Storm",
        tip="Instant AoE melee swing hitting 4 targets. Heals on proc.",
    },
    {
        spec="Ret", name="Judgement of Command",
        icon="spell_holy_righteousfury",
        body="#showtooltip Judgement of Command\n/cast Judgement of Command",
        tip="Deal holy damage on judge; bonus on stunned targets. Core damage.",
    },
    {
        spec="Ret", name="Seal of Command",
        icon="ability_warrior_innerrage",
        body="#showtooltip Seal of Command\n/cast Seal of Command",
        tip="Apply Seal of Command — procs extra holy damage on melee swings.",
    },
    {
        spec="Ret", name="Avenging Wrath",
        icon="spell_holy_avenginewrath",
        body="#showtooltip Avenging Wrath\n/cast Avenging Wrath",
        tip="Wings — +20% damage and healing for 20 sec. Pop on cooldown.",
    },
    {
        spec="Ret", name="Divine Plea",
        icon="ability_paladin_divineplea",
        body="#showtooltip Divine Plea\n/cast Divine Plea",
        tip="Restore 25% mana over 15 sec. Use when below 50% mana.",
    },
    {
        spec="Ret", name="Repentance",
        icon="spell_holy_prayerofhealing02",
        body="#showtooltip Repentance\n/cast [@mouseover,harm,nodead][@target] Repentance",
        tip="Single-target CC on humanoids. Drops on damage.",
    },
    {
        spec="Ret", name="Hammer of Wrath",
        icon="spell_holy_sealofmight",
        body="#showtooltip Hammer of Wrath\n/cast Hammer of Wrath",
        tip="Sub-20% execute ranged shot. Big chunk of a boss kill.",
    },

    -- ── PvP ──────────────────────────────────────────────────────────────────
    {
        spec="PvP", name="Divine Shield",
        icon="spell_holy_divineshield",
        body="#showtooltip Divine Shield\n/cast Divine Shield",
        tip="Full immunity 8 sec. Bubble to survive burst or trinket.",
    },
    {
        spec="PvP", name="Bubble Trinket",
        icon="spell_holy_divineshield",
        body="/use 13\n/cast Divine Shield",
        tip="Use PvP trinket to break CC then immediately bubble.",
    },
    {
        spec="PvP", name="Hammer of Justice",
        icon="spell_holy_sealofmight",
        body="#showtooltip Hammer of Justice\n/cast Hammer of Justice",
        tip="6-sec stun on 40 yd range. Core CC in every PvP situation.",
    },
    {
        spec="PvP", name="Hand of Freedom",
        icon="spell_holy_sealofvalor",
        body="#showtooltip Hand of Freedom\n/cast [@mouseover,help,nodead][@player] Hand of Freedom",
        tip="Immune to movement impairing effects on self or friendly.",
    },
    {
        spec="PvP", name="Hand of Protection",
        icon="spell_holy_sealofprotection",
        body="#showtooltip Hand of Protection\n/cast [@mouseover,help,nodead][@player] Hand of Protection",
        tip="Physical immunity 10 sec on self or friendly. Hands-of macro.",
    },
    {
        spec="PvP", name="Repentance Focus",
        icon="spell_holy_prayerofhealing02",
        body="#showtooltip Repentance\n/cast [@focus] Repentance",
        tip="CC your focus target. Great for locking down healers in arena.",
    },
    {
        spec="PvP", name="Cleanse Self",
        icon="spell_holy_purify",
        body="#showtooltip Cleanse\n/cast [@player] Cleanse",
        tip="Dispel disease/magic/poison from yourself.",
    },
    {
        spec="PvP", name="Judgement of Justice",
        icon="ability_paladin_judgementofthepure",
        body="#showtooltip Judgement of Justice\n/cast Judgement of Justice",
        tip="Prevents target from fleeing and limits their movement speed. Great in BGs.",
    },
}

-- ============================================================
-- HUNTER
-- ============================================================
SLYCHAR_CLASS_MACROS["HUNTER"] = {

    -- ── BM ───────────────────────────────────────────────────────────────────
    {
        spec="BM", name="Kill Command",
        icon="ability_hunter_killcommand",
        body="#showtooltip Kill Command\n/cast Kill Command",
        tip="Command pet to deal 127% normal damage on its next attack.",
    },
    {
        spec="BM", name="Bestial Wrath",
        icon="ability_druid_ferociousbite",
        body="#showtooltip Bestial Wrath\n/cast Bestial Wrath",
        tip="Pet immune to CC and +50% damage for 18 sec. Use on cooldown as BM.",
    },
    {
        spec="BM", name="The Beast Within",
        icon="ability_hunter_beastwithintwo",
        body="#showtooltip Bestial Wrath\n/cast Bestial Wrath",
        tip="Talent procs The Beast Within alongside Bestial Wrath — same button.",
    },
    {
        spec="BM", name="Feed Pet",
        icon="ability_hunter_beastcall",
        body="#showtooltip Feed Pet\n/cast Feed Pet\n/use [pet] Clefthoof Ribs",
        tip="Feed your pet to restore happiness. Adjust food item as needed.",
    },
    {
        spec="BM", name="Mend Pet",
        icon="ability_hunter_mendpet",
        body="#showtooltip Mend Pet\n/cast Mend Pet",
        tip="Periodic heal on pet over 10 sec. Use to keep pet alive in raids.",
    },
    {
        spec="BM", name="Intimidation",
        icon="ability_hunter_intimidation",
        body="#showtooltip Intimidation\n/cast Intimidation",
        tip="Pet stuns target for 3 sec. Requires BM talent.",
    },
    {
        spec="BM", name="Steady Shot",
        icon="ability_hunter_steadyshot",
        body="#showtooltip Steady Shot\n/cast Steady Shot",
        tip="Filler shot between auto-shots. Core of the 1:1 shot rotation.",
    },
    {
        spec="BM", name="Multi-Shot",
        icon="ability_upgrademoonglaive",
        body="#showtooltip Multi-Shot\n/cast Multi-Shot",
        tip="AoE shot hitting up to 3 targets in a cone.",
    },

    -- ── MM ───────────────────────────────────────────────────────────────────
    {
        spec="MM", name="Aimed Shot",
        icon="ability_hunter_aimedshot",
        body="#showtooltip Aimed Shot\n/cast Aimed Shot",
        tip="High-damage cast-time shot. Reduces healing on target.",
    },
    {
        spec="MM", name="Arcane Shot",
        icon="ability_impalingbolt",
        body="#showtooltip Arcane Shot\n/cast Arcane Shot",
        tip="Instant magic damage shot. Good mana efficiency in MM.",
    },
    {
        spec="MM", name="Chimera Shot",
        icon="ability_hunter_chimerashot2",
        body="#showtooltip Chimera Shot\n/cast Chimera Shot",
        tip="Refreshes sting and deals bonus damage based on sting type.",
    },
    {
        spec="MM", name="Serpent Sting",
        icon="ability_hunter_quickshot",
        body="#showtooltip Serpent Sting\n/cast Serpent Sting",
        tip="Apply Serpent Sting for sustained poison DoT damage.",
    },
    {
        spec="MM", name="Trueshot Aura",
        icon="ability_trueshot",
        body="#showtooltip Trueshot Aura\n/cast Trueshot Aura",
        tip="Buff granting +125 AP to party. Keep active at all times as MM.",
    },
    {
        spec="MM", name="Readiness",
        icon="ability_hunter_readiness",
        body="#showtooltip Readiness\n/cast Readiness",
        tip="Reset all cooldowns. Use after Bestial Wrath or Rapid Fire for double use.",
    },
    {
        spec="MM", name="Rapid Fire",
        icon="ability_hunter_runningshotmulti",
        body="#showtooltip Rapid Fire\n/cast Rapid Fire",
        tip="+40% attack speed for 15 sec. Use on pull or burn phases.",
    },
    {
        spec="MM", name="Scatter Shot",
        icon="ability_hunter_scattershot",
        body="#showtooltip Scatter Shot\n/cast Scatter Shot",
        tip="Disorients target 4 sec. Resets if target takes damage.",
    },

    -- ── Survival ─────────────────────────────────────────────────────────────
    {
        spec="Survival", name="Explosive Shot",
        icon="ability_hunter_explosiveshot",
        body="#showtooltip Explosive Shot\n/cast Explosive Shot",
        tip="Core SV shot. Deals fire damage over 3 ticks.",
    },
    {
        spec="Survival", name="Black Arrow",
        icon="ability_hunter_focusedaim",
        body="#showtooltip Black Arrow\n/cast Black Arrow",
        tip="Shadow DoT that feeds Lock and Load procs.",
    },
    {
        spec="Survival", name="Immolation Trap",
        icon="spell_fire_selfdestruct",
        body="#showtooltip Immolation Trap\n/cast Immolation Trap",
        tip="Fire trap that ticks on the first enemy to trigger it.",
    },
    {
        spec="Survival", name="Explosive Trap",
        icon="spell_fire_flameshock",
        body="#showtooltip Explosive Trap\n/cast Explosive Trap",
        tip="AoE fire damage burst trap. Great for adds and BG choke points.",
    },
    {
        spec="Survival", name="Wyvern Sting",
        icon="ability_hunter_wyvernsting",
        body="#showtooltip Wyvern Sting\n/cast Wyvern Sting",
        tip="Sleep then DoT. CC a secondary target for 12 sec.",
    },
    {
        spec="Survival", name="Wing Clip",
        icon="ability_rogue_trip",
        body="#showtooltip Wing Clip\n/cast Wing Clip",
        tip="Movement snare in melee. Use to kite or escape.",
    },
    {
        spec="Survival", name="Counterattack",
        icon="ability_hunter_counterattack",
        body="#showtooltip Counterattack\n/cast Counterattack",
        tip="Immobilize melee attacker for 5 sec after parrying.",
    },
    {
        spec="Survival", name="Deterrence",
        icon="ability_hunter_displacement",
        body="#showtooltip Deterrence\n/cast Deterrence",
        tip="+25% dodge and parry for 10 sec when in melee range.",
    },

    -- ── PvP ──────────────────────────────────────────────────────────────────
    {
        spec="PvP", name="Feign Death",
        icon="ability_rogue_feigndeath",
        body="#showtooltip Feign Death\n/cast Feign Death",
        tip="Drop threat and appear dead. Also clears some debuffs.",
    },
    {
        spec="PvP", name="Freeze Trap",
        icon="spell_frost_chainsofice",
        body="#showtooltip Freezing Trap\n/cast Feign Death\n/cast Freezing Trap",
        tip="Feign Death to drop target, then lay Freezing Trap for incoming enemy.",
    },
    {
        spec="PvP", name="Scatter Trap",
        icon="ability_hunter_scattershot",
        body="#showtooltip Scatter Shot\n/cast Scatter Shot\n/cast Freezing Trap",
        tip="Scatter then immediately lay Freezing Trap for extended CC.",
    },
    {
        spec="PvP", name="Disengage",
        icon="ability_rogue_sprint",
        body="#showtooltip Disengage\n/cast Disengage",
        tip="Break from melee and gain speed boost. Essential PvP escape.",
    },
    {
        spec="PvP", name="Tranquilizing Shot",
        icon="ability_hunter_tranquilizingshot",
        body="#showtooltip Tranquilizing Shot\n/cast Tranquilizing Shot",
        tip="Dispel enrage and magic buffs from enemy. Great vs Warriors.",
    },
    {
        spec="PvP", name="Silencing Shot",
        icon="ability_theblackarrow",
        body="#showtooltip Silencing Shot\n/cast Silencing Shot",
        tip="3-sec silence on enemies casting spells. Requires MM talent.",
    },
    {
        spec="PvP", name="Concussive Shot",
        icon="ability_hunter_disconc",
        body="#showtooltip Concussive Shot\n/cast Concussive Shot",
        tip="Snare target 4 sec. Maintain range in PvP at all times.",
    },
    {
        spec="PvP", name="Aspect of Cheetah",
        icon="ability_mount_jungletiger",
        body="#showtooltip Aspect of the Cheetah\n/cast Aspect of the Cheetah",
        tip="Sprint out of combat. Dazed on hit — combine with kite spacing.",
    },
}

-- ============================================================
-- ROGUE
-- ============================================================
SLYCHAR_CLASS_MACROS["ROGUE"] = {

    -- ── Assassination ─────────────────────────────────────────────────────────
    {
        spec="Assassination", name="Mutilate",
        icon="ability_rogue_eviscerate",
        body="#showtooltip Mutilate\n/cast Mutilate",
        tip="Core Assassination combo-builder. Uses two daggers for 2 CPs.",
    },
    {
        spec="Assassination", name="Envenom",
        icon="ability_rogue_envenom",
        body="#showtooltip Envenom\n/cast Envenom",
        tip="Finisher that consumes Deadly Poison stacks for massive damage.",
    },
    {
        spec="Assassination", name="Rupture",
        icon="ability_rogue_rupture",
        body="#showtooltip Rupture\n/cast Rupture",
        tip="Bleed finisher providing sustained DPS. Keep rolling in single-target.",
    },
    {
        spec="Assassination", name="Garrote",
        icon="ability_rogue_garrote",
        body="#showtooltip Garrote\n/cast [stealth] Garrote",
        tip="Stealth opener. Silences casters and applies heavy bleed.",
    },
    {
        spec="Assassination", name="Cold Blood Envenom",
        icon="ability_rogue_coldblood",
        body="#showtooltip Envenom\n/cast Cold Blood\n/cast Envenom",
        tip="Pop Cold Blood for a guaranteed crit Envenom.",
    },
    {
        spec="Assassination", name="Deadly Throw",
        icon="ability_rogue_deadlybrewbio",
        body="#showtooltip Deadly Throw\n/cast Deadly Throw",
        tip="Ranged finisher. At 5 CP interrupts and slows target.",
    },
    {
        spec="Assassination", name="Fan of Knives",
        icon="ability_rogue_fanofknives",
        body="#showtooltip Fan of Knives\n/cast Fan of Knives",
        tip="AoE attack hitting all nearby enemies. Great for packs.",
    },
    {
        spec="Assassination", name="Slice and Dice",
        icon="ability_rogue_slicedice",
        body="#showtooltip Slice and Dice\n/cast Slice and Dice",
        tip="Attack speed buff. Keep this up for sustained DPS on long fights.",
    },

    -- ── Combat ───────────────────────────────────────────────────────────────
    {
        spec="Combat", name="Sinister Strike",
        icon="ability_rogue_sinisterstrike",
        body="#showtooltip Sinister Strike\n/cast Sinister Strike",
        tip="Core Combat combo-builder. Works with any weapon type.",
    },
    {
        spec="Combat", name="Eviscerate",
        icon="ability_rogue_eviscerate",
        body="#showtooltip Eviscerate\n/cast Eviscerate",
        tip="Core damage finisher. Scales with AP — use at 4-5 CPs.",
    },
    {
        spec="Combat", name="Blade Flurry",
        icon="ability_warrior_punishingblow",
        body="#showtooltip Blade Flurry\n/cast Blade Flurry",
        tip="Mirror your attacks to a second target. Core Combat cooldown.",
    },
    {
        spec="Combat", name="Adrenaline Rush",
        icon="spell_shadow_shadowworddominate",
        body="#showtooltip Adrenaline Rush\n/cast Adrenaline Rush",
        tip="Double energy regen for 15 sec. Sync with Blade Flurry for burst.",
    },
    {
        spec="Combat", name="Killing Spree",
        icon="ability_rogue_murderspree",
        body="#showtooltip Killing Spree\n/cast Killing Spree",
        tip="Teleports between nearby enemies dealing rapid strikes.",
    },
    {
        spec="Combat", name="Riposte",
        icon="ability_warrior_challange",
        body="#showtooltip Riposte\n/cast Riposte",
        tip="Disarms and deals damage after a parry. Keep on bar for reactive use.",
    },
    {
        spec="Combat", name="Expose Armor",
        icon="ability_warrior_riposte",
        body="#showtooltip Expose Armor\n/cast Expose Armor",
        tip="Reduce target armor by up to 20% (stacks to 5). Use if no Sunder.",
    },
    {
        spec="Combat", name="Kick",
        icon="ability_kick",
        body="#showtooltip Kick\n/cast Kick",
        tip="5-sec interrupt. Locks out school if cast in progress.",
    },

    -- ── Subtlety ─────────────────────────────────────────────────────────────
    {
        spec="Subtlety", name="Ambush",
        icon="ability_rogue_ambush",
        body="#showtooltip Ambush\n/cast [stealth] Ambush",
        tip="Stealth opener. Massive burst from behind — requires dagger.",
    },
    {
        spec="Subtlety", name="Hemorrhage",
        icon="ability_rogue_hemorrhage",
        body="#showtooltip Hemorrhage\n/cast Hemorrhage",
        tip="Combo builder that stacks Hemorrhage debuff increasing bleed damage.",
    },
    {
        spec="Subtlety", name="Premeditation",
        icon="ability_rogue_premeditation",
        body="#showtooltip Premeditation\n/cast Premeditation",
        tip="Add 2 CP without breaking stealth. Use before openers.",
    },
    {
        spec="Subtlety", name="Preparation",
        icon="ability_rogue_preparation",
        body="#showtooltip Preparation\n/cast Preparation",
        tip="Reset all cooldowns. Enables double-vanish in PvP.",
    },
    {
        spec="Subtlety", name="Shadowstep",
        icon="ability_rogue_shadowstep",
        body="#showtooltip Shadowstep\n/cast Shadowstep",
        tip="Teleport behind target; next ability costs 20% less energy.",
    },
    {
        spec="Subtlety", name="Shadow Dance",
        icon="ability_rogue_shadowdance",
        body="#showtooltip Shadow Dance\n/cast Shadow Dance",
        tip="Briefly enter pseudo-stealth, enabling stealth-only abilities.",
    },
    {
        spec="Subtlety", name="Ghostly Strike",
        icon="ability_rogue_ghostlystrike",
        body="#showtooltip Ghostly Strike\n/cast Ghostly Strike",
        tip="Combo builder that raises your dodge 15% for 7 sec.",
    },
    {
        spec="Subtlety", name="Vanish",
        icon="ability_vanish",
        body="#showtooltip Vanish\n/cast Vanish",
        tip="Instantly enter stealth mid-combat. Use as escape or reset.",
    },

    -- ── PvP ──────────────────────────────────────────────────────────────────
    {
        spec="PvP", name="Cheap Shot",
        icon="ability_rogue_ambush",
        body="#showtooltip Cheap Shot\n/cast [stealth] Cheap Shot",
        tip="4-sec stun from stealth. Use to open for full burst rotation.",
    },
    {
        spec="PvP", name="Gouge",
        icon="ability_gouge",
        body="#showtooltip Gouge\n/cast Gouge",
        tip="Incapacitate 4 sec. Drop target, restealth, reopen.",
    },
    {
        spec="PvP", name="Blind",
        icon="spell_shadow_mindsteal",
        body="#showtooltip Blind\n/cast [@mouseover,harm,nodead][@target] Blind",
        tip="CC target 10 sec. Breaks on damage — use to peel or CC healer.",
    },
    {
        spec="PvP", name="Kidney Shot",
        icon="ability_rogue_kidneyshot",
        body="#showtooltip Kidney Shot\n/cast Kidney Shot",
        tip="Stun finisher scaling with CPs. Core PvP CC.",
    },
    {
        spec="PvP", name="Smoke Bomb",
        icon="ability_rogue_smokebomb",
        body="#showtooltip Smoke Bomb\n/cast Smoke Bomb",
        tip="AoE zone blocking LOS for spells. Protects allies in arena.",
    },
    {
        spec="PvP", name="Dismantle",
        icon="ability_rogue_dismantle",
        body="#showtooltip Dismantle\n/cast Dismantle",
        tip="Disarm enemy 8 sec. Shuts down melee and Hunters.",
    },
    {
        spec="PvP", name="Evasion",
        icon="spell_shadow_shadowward",
        body="#showtooltip Evasion\n/cast Evasion",
        tip="+50% dodge for 10 sec. Pop during melee burst to survive.",
    },
    {
        spec="PvP", name="Cloak of Shadows",
        icon="spell_shadow_nethercloak",
        body="#showtooltip Cloak of Shadows\n/cast Cloak of Shadows",
        tip="Remove all magical debuffs and immune to magic 5 sec.",
    },
}

-- ============================================================
-- PRIEST
-- ============================================================
SLYCHAR_CLASS_MACROS["PRIEST"] = {

    -- ── Discipline ────────────────────────────────────────────────────────────
    {
        spec="Discipline", name="Power Word: Shield",
        icon="spell_holy_powerwordshield",
        body="#showtooltip Power Word: Shield\n/cast [@mouseover,help,nodead][@target] Power Word: Shield",
        tip="Absorb damage on mouseover or target. Keep on tank between pulls.",
    },
    {
        spec="Discipline", name="Penance",
        icon="spell_holy_penance",
        body="#showtooltip Penance\n/cast [@mouseover,help,nodead][@target] Penance",
        tip="Channeled heal burst or direct damage. Core Disc spell.",
    },
    {
        spec="Discipline", name="Pain Suppression",
        icon="spell_holy_painsupression",
        body="#showtooltip Pain Suppression\n/cast [@mouseover,help,nodead][@player] Pain Suppression",
        tip="-40% damage taken on friendly for 8 sec. Emergency CD.",
    },
    {
        spec="Discipline", name="Power Infusion",
        icon="spell_holy_powerinfusion",
        body="#showtooltip Power Infusion\n/cast [@focus] Power Infusion",
        tip="Give caster focus +20% cast speed and -20% mana cost for 15 sec.",
    },
    {
        spec="Discipline", name="Flash Heal",
        icon="spell_holy_flashheal",
        body="#showtooltip Flash Heal\n/cast [@mouseover,help,nodead][@target] Flash Heal",
        tip="Fast small heal. Spammable reactive healing on mouseover.",
    },
    {
        spec="Discipline", name="Inner Focus Flash",
        icon="spell_frost_windwalkon",
        body="#showtooltip Flash Heal\n/cast Inner Focus\n/cast Flash Heal",
        tip="Free guaranteed-crit Flash Heal via Inner Focus.",
    },
    {
        spec="Discipline", name="Dispel Magic",
        icon="spell_holy_dispelmagic",
        body="#showtooltip Dispel Magic\n/cast [@mouseover,help,nodead][@target] Dispel Magic",
        tip="Dispel 2 magic effects from a friendly on mouseover or target.",
    },
    {
        spec="Discipline", name="Mass Dispel",
        icon="spell_arcane_massdispel",
        body="#showtooltip Mass Dispel\n/cast Mass Dispel",
        tip="AoE dispel — dispels magic including Paladin Divine Shield.",
    },

    -- ── Holy ─────────────────────────────────────────────────────────────────
    {
        spec="Holy", name="Heal",
        icon="spell_holy_heal",
        body="#showtooltip Heal\n/cast [@mouseover,help,nodead][@target] Heal",
        tip="Efficient medium heal. Core of Holy throughput.",
    },
    {
        spec="Holy", name="Greater Heal",
        icon="spell_holy_greaterheal",
        body="#showtooltip Greater Heal\n/cast [@mouseover,help,nodead][@target] Greater Heal",
        tip="Large slow heal for tanking targets taking heavy damage.",
    },
    {
        spec="Holy", name="Circle of Healing",
        icon="spell_holy_circleofrenewal",
        body="#showtooltip Circle of Healing\n/cast [@mouseover] Circle of Healing",
        tip="Instant AoE heal hitting 5 players near mouseover target.",
    },
    {
        spec="Holy", name="Prayer of Healing",
        icon="spell_holy_prayerofhealing",
        body="#showtooltip Prayer of Healing\n/cast Prayer of Healing",
        tip="AoE group heal. Use on your own party group.",
    },
    {
        spec="Holy", name="Guardian Spirit",
        icon="spell_holy_guardianspirit",
        body="#showtooltip Guardian Spirit\n/cast [@mouseover,help,nodead][@player] Guardian Spirit",
        tip="Prevents one lethal hit and boosts healing on target for 10 sec.",
    },
    {
        spec="Holy", name="Lightwell",
        icon="spell_holy_summonlightwell",
        body="#showtooltip Lightwell\n/cast Lightwell",
        tip="Place a Lightwell for raid members to click for free heals.",
    },
    {
        spec="Holy", name="Renew",
        icon="spell_holy_renew",
        body="#showtooltip Renew\n/cast [@mouseover,help,nodead][@target] Renew",
        tip="HoT heal on target. Efficient healing on moderately damaged targets.",
    },
    {
        spec="Holy", name="Prayer of Mending",
        icon="spell_holy_restoration",
        body="#showtooltip Prayer of Mending\n/cast [@mouseover,help,nodead][@target] Prayer of Mending",
        tip="Bouncing heal — heals when target takes damage, then jumps.",
    },

    -- ── Shadow ────────────────────────────────────────────────────────────────
    {
        spec="Shadow", name="Vampiric Touch",
        icon="spell_holy_stoicism",
        body="#showtooltip Vampiric Touch\n/cast Vampiric Touch",
        tip="Core Shadow DoT. Replenishes mana to party on each tick.",
    },
    {
        spec="Shadow", name="Shadow Word: Pain",
        icon="spell_shadow_shadowwordpain",
        body="#showtooltip Shadow Word: Pain\n/cast Shadow Word: Pain",
        tip="Instant DoT. Apply at pull and refresh before falling off.",
    },
    {
        spec="Shadow", name="Devouring Plague",
        icon="spell_shadow_devouringplague",
        body="#showtooltip Devouring Plague\n/cast Devouring Plague",
        tip="DoT that heals you per tick. Core Undead racial and Shadow spell.",
    },
    {
        spec="Shadow", name="Mind Blast",
        icon="spell_shadow_unholyfrenzy",
        body="#showtooltip Mind Blast\n/cast Mind Blast",
        tip="Highest single-hit shadow damage. Procs Misery stacks.",
    },
    {
        spec="Shadow", name="Mind Flay",
        icon="spell_shadow_siphonmana",
        body="#showtooltip Mind Flay\n/cast Mind Flay",
        tip="Channeled damage + snare. Primary filler between casts.",
    },
    {
        spec="Shadow", name="Shadowform",
        icon="spell_shadow_shadowform",
        body="#showtooltip Shadowform\n/cast Shadowform",
        tip="Toggle: +15% shadow damage, reduced physical damage taken.",
    },
    {
        spec="Shadow", name="Dispersion",
        icon="spell_shadow_dispersion",
        body="#showtooltip Dispersion\n/cast Dispersion",
        tip="90% damage reduction, regen mana 36%. Emergency survival CD.",
    },
    {
        spec="Shadow", name="Fade",
        icon="spell_magic_lesserinvisibilty",
        body="#showtooltip Fade\n/cast Fade",
        tip="Drop threat for 10 sec. Use when aggro spiked.",
    },

    -- ── PvP ──────────────────────────────────────────────────────────────────
    {
        spec="PvP", name="Psychic Scream",
        icon="spell_shadow_psychicscream",
        body="#showtooltip Psychic Scream\n/cast Psychic Scream",
        tip="AoE fear 8 sec. Core PvP escape vs melee.",
    },
    {
        spec="PvP", name="Silence",
        icon="spell_shadow_impphaseshift",
        body="#showtooltip Silence\n/cast Silence",
        tip="5-sec silence on target. Requires Shadow spec talent.",
    },
    {
        spec="PvP", name="Mind Control",
        icon="spell_shadow_shadowworddominate",
        body="#showtooltip Mind Control\n/cast [@mouseover,harm,nodead][@target] Mind Control",
        tip="30-sec channel controlling enemy humanoid. Use on edge of cliff.",
    },
    {
        spec="PvP", name="Shackle Undead",
        icon="spell_holy_excorcism",
        body="#showtooltip Shackle Undead\n/cast [@mouseover,harm,nodead][@target] Shackle Undead",
        tip="Incapacitate undead 50 sec. Essential in Naxx PvP.",
    },
    {
        spec="PvP", name="Dispel Enemy",
        icon="spell_holy_dispelmagic",
        body="#showtooltip Dispel Magic\n/cast [@mouseover,harm,nodead][@target] Dispel Magic",
        tip="Remove 1 magic buff from enemy target.",
    },
    {
        spec="PvP", name="Vampiric Embrace",
        icon="spell_shadow_unsummonbuilding",
        body="#showtooltip Vampiric Embrace\n/cast Vampiric Embrace",
        tip="Passive lifedrain on shadow damage — passive healing for party.",
    },
    {
        spec="PvP", name="Shadow Word: Death",
        icon="spell_shadow_demonicfortitude",
        body="#showtooltip Shadow Word: Death\n/cast Shadow Word: Death",
        tip="High damage below 25% — damages you if target doesn't die.",
    },
    {
        spec="PvP", name="Desperate Prayer",
        icon="spell_holy_holysmite",
        body="#showtooltip Desperate Prayer\n/cast Desperate Prayer",
        tip="Free instant self-heal. Use when low HP mid-burst.",
    },
}

-- ============================================================
-- SHAMAN
-- ============================================================
SLYCHAR_CLASS_MACROS["SHAMAN"] = {

    -- ── Elemental ─────────────────────────────────────────────────────────────
    {
        spec="Elemental", name="Lightning Bolt",
        icon="spell_nature_lightning",
        body="#showtooltip Lightning Bolt\n/cast Lightning Bolt",
        tip="Core Elemental filler. Refreshes with Maelstrom Weapon procs.",
    },
    {
        spec="Elemental", name="Chain Lightning",
        icon="spell_nature_chainlightning",
        body="#showtooltip Chain Lightning\n/cast Chain Lightning",
        tip="Bounces to 2 additional targets. Great for AoE packs.",
    },
    {
        spec="Elemental", name="Lava Burst",
        icon="spell_shaman_lavaburst",
        body="#showtooltip Lava Burst\n/cast Lava Burst",
        tip="Always crits with Flame Shock up. Core damage cooldown.",
    },
    {
        spec="Elemental", name="Flame Shock",
        icon="spell_fire_flameshock",
        body="#showtooltip Flame Shock\n/cast Flame Shock",
        tip="Apply Flame Shock for DoT and to guarantee Lava Burst crit.",
    },
    {
        spec="Elemental", name="Thunderstorm",
        icon="spell_shaman_thunderstorm",
        body="#showtooltip Thunderstorm\n/cast Thunderstorm",
        tip="AoE knockback + mana return. Use to pushback melee in PvP.",
    },
    {
        spec="Elemental", name="Earth Shock",
        icon="spell_nature_earthshock",
        body="#showtooltip Earth Shock\n/cast Earth Shock",
        tip="Interrupt + nature damage. Use to interrupt casters.",
    },
    {
        spec="Elemental", name="Fire Nova",
        icon="spell_fire_sealoffire",
        body="#showtooltip Fire Nova\n/cast Fire Nova",
        tip="AoE fire damage burst from Fire Elemental Totem.",
    },
    {
        spec="Elemental", name="Elemental Mastery",
        icon="spell_nature_wispheal",
        body="#showtooltip Elemental Mastery\n/cast Elemental Mastery",
        tip="Next spell is instant and free. Pop before Lava Burst.",
    },

    -- ── Enhance ──────────────────────────────────────────────────────────────
    {
        spec="Enhance", name="Stormstrike",
        icon="ability_shaman_stormstrike",
        body="#showtooltip Stormstrike\n/cast Stormstrike",
        tip="Core Enhancement attack. Increases nature spell damage taken by target.",
    },
    {
        spec="Enhance", name="Lava Lash",
        icon="ability_shaman_lavalash",
        body="#showtooltip Lava Lash\n/cast Lava Lash",
        tip="OH attack. Enhanced by Flametongue weapon enchant.",
    },
    {
        spec="Enhance", name="Maelstrom Weapon",
        icon="spell_nature_lightningshield",
        body="#showtooltip Lightning Bolt\n/cast Lightning Bolt",
        tip="Use instant Lightning Bolt after 5x Maelstrom Weapon procs.",
    },
    {
        spec="Enhance", name="Shamanistic Rage",
        icon="spell_nature_shamanrage",
        body="#showtooltip Shamanistic Rage\n/cast Shamanistic Rage",
        tip="-30% damage taken + mana regeneration for 15 sec.",
    },
    {
        spec="Enhance", name="Feral Spirit",
        icon="spell_shaman_feralspirit",
        body="#showtooltip Feral Spirit\n/cast Feral Spirit",
        tip="Summon 2 spirit wolves for 45 sec. Major DPS + self-healing cooldown.",
    },
    {
        spec="Enhance", name="Windfury Weapon",
        icon="spell_nature_cyclone",
        body="#showtooltip Windfury Weapon\n/cast Windfury Weapon",
        tip="Imbue MH with Windfury — extra auto attacks proc burst.",
    },
    {
        spec="Enhance", name="Flametongue Weapon",
        icon="spell_fire_flametounge",
        body="#showtooltip Flametongue Weapon\n/cast Flametongue Weapon",
        tip="Imbue weapon with fire damage — use on OH for Lava Lash boost.",
    },
    {
        spec="Enhance", name="Earth Shock",
        icon="spell_nature_earthshock",
        body="#showtooltip Earth Shock\n/cast Earth Shock",
        tip="Interrupt + nature damage. Priority when target is casting.",
    },

    -- ── Resto ─────────────────────────────────────────────────────────────────
    {
        spec="Resto", name="Chain Heal",
        icon="spell_nature_healingwavegreater",
        body="#showtooltip Chain Heal\n/cast [@mouseover,help,nodead][@target] Chain Heal",
        tip="Heals target and jumps to 2 injured allies nearby.",
    },
    {
        spec="Resto", name="Healing Wave",
        icon="spell_nature_magicimmunity",
        body="#showtooltip Healing Wave\n/cast [@mouseover,help,nodead][@target] Healing Wave",
        tip="Big efficient heal. Primary single-target heal for tank healing.",
    },
    {
        spec="Resto", name="Lesser Healing Wave",
        icon="spell_nature_healingwavelesser",
        body="#showtooltip Lesser Healing Wave\n/cast [@mouseover,help,nodead][@target] Lesser Healing Wave",
        tip="Fast heal. Use for reactive healing or free Tidal Wave stacks.",
    },
    {
        spec="Resto", name="Riptide",
        icon="spell_nature_riptide",
        body="#showtooltip Riptide\n/cast [@mouseover,help,nodead][@target] Riptide",
        tip="Instant HoT that also boosts next Chain Heal bounce.",
    },
    {
        spec="Resto", name="Earth Shield",
        icon="spell_nature_earthshield",
        body="#showtooltip Earth Shield\n/cast [@focus] Earth Shield",
        tip="9-charge shield on focus (tank) — heals on damage, boosts your heals.",
    },
    {
        spec="Resto", name="Nature's Swiftness Heal",
        icon="spell_nature_ravenform",
        body="#showtooltip Healing Wave\n/cast Nature's Swiftness\n/cast Healing Wave",
        tip="Instant maximum-rank Healing Wave emergency heal.",
    },
    {
        spec="Resto", name="Mana Tide Totem",
        icon="spell_frost_summonwaterelemental",
        body="#showtooltip Mana Tide Totem\n/cast Mana Tide Totem",
        tip="Restore 24% mana to nearby party over 12 sec. Use when low.",
    },
    {
        spec="Resto", name="Tremor Totem",
        icon="spell_nature_tremortotem",
        body="#showtooltip Tremor Totem\n/cast Tremor Totem",
        tip="Remove fear/charm/sleep on nearby allies every 3 sec.",
    },

    -- ── PvP ──────────────────────────────────────────────────────────────────
    {
        spec="PvP", name="Frost Shock",
        icon="spell_frost_frostshock",
        body="#showtooltip Frost Shock\n/cast Frost Shock",
        tip="Instant snare + nature damage. Core kite tool in PvP.",
    },
    {
        spec="PvP", name="Hex",
        icon="spell_shaman_hex",
        body="#showtooltip Hex\n/cast [@mouseover,harm,nodead][@target] Hex",
        tip="Polymorph-style CC on humanoids and beasts for 1 min.",
    },
    {
        spec="PvP", name="Grounding Totem",
        icon="spell_nature_groundingtotem",
        body="#showtooltip Grounding Totem\n/cast Grounding Totem",
        tip="Absorbs next targeted spell cast at a party member.",
    },
    {
        spec="PvP", name="Earthbind Totem",
        icon="spell_nature_earthbindtotem",
        body="#showtooltip Earthbind Totem\n/cast Earthbind Totem",
        tip="AoE 50% movement snare around the totem. Drop under melee.",
    },
    {
        spec="PvP", name="Purge",
        icon="spell_nature_purge",
        body="#showtooltip Purge\n/cast [@mouseover,harm,nodead][@target] Purge",
        tip="Dispel 2 magic buffs from enemy. High value vs Paladins and Hunters.",
    },
    {
        spec="PvP", name="Wind Shear",
        icon="ability_shaman_windshear",
        body="#showtooltip Wind Shear\n/cast Wind Shear",
        tip="Instant ranged interrupt. Locks spell school 2 sec.",
    },
    {
        spec="PvP", name="Ghost Wolf",
        icon="spell_nature_spiritwolf",
        body="#showtooltip Ghost Wolf\n/cast Ghost Wolf",
        tip="Move at 40% increased speed. Use to escape melee pressure.",
    },
    {
        spec="PvP", name="Nature's Guardian",
        icon="ability_hunter_aspectofthemonkey",
        body="#showtooltip Healing Wave\n/cast Nature's Swiftness\n/cast Healing Wave",
        tip="Nature's Swiftness → instant max Healing Wave when low HP.",
    },
}

-- ============================================================
-- WARLOCK
-- ============================================================
SLYCHAR_CLASS_MACROS["WARLOCK"] = {

    -- ── Affliction ────────────────────────────────────────────────────────────
    {
        spec="Affliction", name="Corruption",
        icon="spell_shadow_abominationexplosion",
        body="#showtooltip Corruption\n/cast Corruption",
        tip="Instant DoT. Keep rolling at all times — very mana efficient.",
    },
    {
        spec="Affliction", name="Unstable Affliction",
        icon="spell_shadow_unstableaffliction_3",
        body="#showtooltip Unstable Affliction\n/cast Unstable Affliction",
        tip="DoT that silences + damages dispeller. Always keep up.",
    },
    {
        spec="Affliction", name="Haunt",
        icon="ability_warlock_haunt",
        body="#showtooltip Haunt\n/cast Haunt",
        tip="High damage + buff boosting all DoT damage. Refreshes UA.",
    },
    {
        spec="Affliction", name="Curse of Agony",
        icon="spell_shadow_curseofsatanis",
        body="#showtooltip Curse of Agony\n/cast Curse of Agony",
        tip="Ramping damage curse. Core DoT — replaces CoE on non-CoE situations.",
    },
    {
        spec="Affliction", name="Drain Soul",
        icon="spell_shadow_haunting",
        body="#showtooltip Drain Soul\n/cast Drain Soul",
        tip="Channel below 25% to drain soul shards and deal bonus damage.",
    },
    {
        spec="Affliction", name="Drain Life",
        icon="spell_shadow_lifedrain02",
        body="#showtooltip Drain Life\n/cast Drain Life",
        tip="Sustain heal and damage. Use to recover HP in open world.",
    },
    {
        spec="Affliction", name="Siphon Life",
        icon="spell_shadow_requiem",
        body="#showtooltip Siphon Life\n/cast Siphon Life",
        tip="DoT that heals you for the damage dealt.",
    },
    {
        spec="Affliction", name="Pandemic",
        icon="spell_shadow_shadowbolt",
        body="#showtooltip Haunt\n/cast Haunt\n/cast Corruption\n/cast Unstable Affliction",
        tip="Apply core Affliction dots in sequence.",
    },

    -- ── Demo ─────────────────────────────────────────────────────────────────
    {
        spec="Demo", name="Metamorphosis",
        icon="ability_warlock_metamorphosis",
        body="#showtooltip Metamorphosis\n/cast Metamorphosis",
        tip="Transform into demon form for 30 sec. Massive DPS cooldown.",
    },
    {
        spec="Demo", name="Immolation Aura",
        icon="spell_shadow_shadowpact",
        body="#showtooltip Immolation Aura\n/cast Immolation Aura",
        tip="AoE fire damage aura in Metamorphosis — use on packs.",
    },
    {
        spec="Demo", name="Shadow Bolt",
        icon="spell_shadow_shadowbolt",
        body="#showtooltip Shadow Bolt\n/cast Shadow Bolt",
        tip="Core filler with Shadow and Flame talent boosting next cast.",
    },
    {
        spec="Demo", name="Soul Fire",
        icon="spell_fire_incinerate",
        body="#showtooltip Soul Fire\n/cast [nochanneling] Soul Fire",
        tip="High damage nuke. Use when Decimation procs below 35%.",
    },
    {
        spec="Demo", name="Curse of Doom",
        icon="spell_shadow_auraofdarkness",
        body="#showtooltip Curse of Doom\n/cast Curse of Doom",
        tip="Huge delayed shadow damage after 60 sec. Use on bosses.",
    },
    {
        spec="Demo", name="Demonic Empowerment",
        icon="ability_warlock_demonicpower",
        body="#showtooltip Demonic Empowerment\n/cast Demonic Empowerment",
        tip="Buff your active demon. Felguard gains extra damage and speed.",
    },
    {
        spec="Demo", name="Summon Felguard",
        icon="ability_warrior_warcry",
        body="#showtooltip Summon Felguard\n/cast Summon Felguard",
        tip="Summon core Demo pet. Use Felguard for max DPS.",
    },
    {
        spec="Demo", name="Life Tap",
        icon="spell_shadow_burningspirit",
        body="#showtooltip Life Tap\n/cast Life Tap",
        tip="Convert HP to mana. Use with Spirit Tap or bandage after.",
    },

    -- ── Destruction ───────────────────────────────────────────────────────────
    {
        spec="Destruction", name="Incinerate",
        icon="spell_fire_incinerate",
        body="#showtooltip Incinerate\n/cast Incinerate",
        tip="Core Destro filler. Faster cast than Shadow Bolt, feeds Backdraft.",
    },
    {
        spec="Destruction", name="Chaos Bolt",
        icon="ability_warlock_chaosbolt",
        body="#showtooltip Chaos Bolt\n/cast Chaos Bolt",
        tip="Cannot be resisted or absorbed. Major nuke on long cooldown.",
    },
    {
        spec="Destruction", name="Conflagrate",
        icon="spell_fire_fireball",
        body="#showtooltip Conflagrate\n/cast Conflagrate",
        tip="Instant Immolate explosion — use while Backdraft is active.",
    },
    {
        spec="Destruction", name="Immolate",
        icon="spell_fire_immolation",
        body="#showtooltip Immolate\n/cast Immolate",
        tip="Fire DoT that lets you use Conflagrate. Keep active.",
    },
    {
        spec="Destruction", name="Backdraft",
        icon="ability_warlock_backdraft",
        body="#showtooltip Conflagrate\n/cast Conflagrate",
        tip="Conflagrate procs Backdraft — next 3 Incinerates cast 30% faster.",
    },
    {
        spec="Destruction", name="Rain of Fire",
        icon="spell_shadow_rainoffire",
        body="#showtooltip Rain of Fire\n/cast Rain of Fire",
        tip="AoE fire damage channel. Use on tightly packed packs.",
    },
    {
        spec="Destruction", name="Shadowfury",
        icon="ability_warlock_shadowfurytga",
        body="#showtooltip Shadowfury\n/cast Shadowfury",
        tip="AoE stun 3 sec. Great interrupt vs caster packs.",
    },
    {
        spec="Destruction", name="Shadowburn",
        icon="spell_shadow_scourgebuild",
        body="#showtooltip Shadowburn\n/cast Shadowburn",
        tip="Sub-20% execute. Grants a soul shard on kill.",
    },

    -- ── PvP ──────────────────────────────────────────────────────────────────
    {
        spec="PvP", name="Fear",
        icon="spell_shadow_possession",
        body="#showtooltip Fear\n/cast [@mouseover,harm,nodead][@target] Fear",
        tip="Single-target fear 10 sec. Core CC for all PvP.",
    },
    {
        spec="PvP", name="Howl of Terror",
        icon="spell_shadow_deathscream",
        body="#showtooltip Howl of Terror\n/cast Howl of Terror",
        tip="AoE fear 6 sec for all melee in range. Escape vs melee train.",
    },
    {
        spec="PvP", name="Seduction Pet",
        icon="spell_shadow_mindtwisting",
        body="/petautocastoff Firebolt\n/petautocastoff Lash of Pain\n/cast [pet:Succubus] Seduction",
        tip="Turn off Succubus auto attacks then Seduce the target.",
    },
    {
        spec="PvP", name="Curse of Exhaustion",
        icon="spell_shadow_grimward",
        body="#showtooltip Curse of Exhaustion\n/cast Curse of Exhaustion",
        tip="-30% movement speed. Slow kite target in open-world PvP.",
    },
    {
        spec="PvP", name="Unstable Affliction PvP",
        icon="spell_shadow_unstableaffliction_3",
        body="#showtooltip Unstable Affliction\n/cast Unstable Affliction",
        tip="Silences dispeller for 3 sec — punishes any healer attempting to dispel.",
    },
    {
        spec="PvP", name="Death Coil",
        icon="spell_shadow_deathcoil",
        body="#showtooltip Death Coil\n/cast Death Coil",
        tip="Horror 3 sec + heal yourself. Range escape or stall ability.",
    },
    {
        spec="PvP", name="Spell Lock",
        icon="ability_warlock_spelllock",
        body="/cast [pet:Felhunter] Spell Lock",
        tip="Felhunter interrupt + 5-sec school lockout. Best PvP pet.",
    },
    {
        spec="PvP", name="Devour Magic",
        icon="spell_shadow_antishadow",
        body="/cast [pet:Felhunter] Devour Magic",
        tip="Felhunter dispels one magic effect from target.",
    },
}

-- ============================================================
-- DRUID
-- ============================================================
SLYCHAR_CLASS_MACROS["DRUID"] = {

    -- ── Balance ───────────────────────────────────────────────────────────────
    {
        spec="Balance", name="Starsurge",
        icon="ability_druid_starsurge",
        body="#showtooltip Starsurge\n/cast Starsurge",
        tip="Highest damage Moonkin nuke. Use on proc or cooldown.",
    },
    {
        spec="Balance", name="Starfire",
        icon="spell_arcane_starfire",
        body="#showtooltip Starfire\n/cast Starfire",
        tip="Primary caster filler. High damage + Nature's Grace proc.",
    },
    {
        spec="Balance", name="Wrath",
        icon="spell_nature_abolishmagic",
        body="#showtooltip Wrath\n/cast Wrath",
        tip="Faster nature nuke. Use in Solar Eclipse or for movement.",
    },
    {
        spec="Balance", name="Moonfire",
        icon="spell_nature_starfall",
        body="#showtooltip Moonfire\n/cast Moonfire",
        tip="Instant DoT. Apply at pull and refresh for Moonkin DPS rotation.",
    },
    {
        spec="Balance", name="Insect Swarm",
        icon="spell_nature_insectswarm",
        body="#showtooltip Insect Swarm\n/cast Insect Swarm",
        tip="DoT + -20% chance to hit debuff on target. Keep active.",
    },
    {
        spec="Balance", name="Starfall",
        icon="ability_druid_starfall",
        body="#showtooltip Starfall\n/cast Starfall",
        tip="Massive AoE damage rain. Use on cooldown for Pull/AoE phases.",
    },
    {
        spec="Balance", name="Force of Nature",
        icon="ability_druid_forceofnature",
        body="#showtooltip Force of Nature\n/cast Force of Nature",
        tip="Summon 3 treants for 30 sec. Large burst cooldown.",
    },
    {
        spec="Balance", name="Typhoon",
        icon="ability_druid_typhoon",
        body="#showtooltip Typhoon\n/cast Typhoon",
        tip="AoE knockback + daze. Use to interrupt and peel melee.",
    },

    -- ── Feral ─────────────────────────────────────────────────────────────────
    {
        spec="Feral", name="Mangle (Cat)",
        icon="ability_druid_mangle2",
        body="#showtooltip Mangle (Cat)\n/cast [stance:3] Mangle (Cat)",
        tip="Core Cat combo builder. Applies Mangle bleed debuff +30% bleed damage.",
    },
    {
        spec="Feral", name="Rip",
        icon="ability_ghoulfrenzy",
        body="#showtooltip Rip\n/cast [stance:3] Rip",
        tip="Bleed finisher. Primary sustained DPS finisher — use at 5 CPs.",
    },
    {
        spec="Feral", name="Ferocious Bite",
        icon="ability_druid_ferociousbite",
        body="#showtooltip Ferocious Bite\n/cast [stance:3] Ferocious Bite",
        tip="Heavy hitting finisher. Use when Rip is already up.",
    },
    {
        spec="Feral", name="Rake",
        icon="ability_druid_disembowel",
        body="#showtooltip Rake\n/cast [stance:3] Rake",
        tip="Bleed on opener. Keep Rake ticking for sustained DPS.",
    },
    {
        spec="Feral", name="Savage Roar",
        icon="ability_druid_skinteeth",
        body="#showtooltip Savage Roar\n/cast [stance:3] Savage Roar",
        tip="+30% physical damage buff. Keep this active above all else.",
    },
    {
        spec="Feral", name="Berserk",
        icon="ability_druid_berserk",
        body="#showtooltip Berserk\n/cast Berserk",
        tip="Triple Mangle for 15 sec + removes Daze. Major burst cooldown.",
    },
    {
        spec="Feral", name="Tiger's Fury",
        icon="ability_druid_tigersfury",
        body="#showtooltip Tiger's Fury\n/cast Tiger's Fury",
        tip="+40 energy + damage for 6 sec. Use to restart engine after energy dump.",
    },
    {
        spec="Feral", name="Feral Charge (Cat)",
        icon="ability_hunter_pet_bear",
        body="#showtooltip Feral Charge (Cat)\n/cast [stance:3] Feral Charge (Cat)",
        tip="Jump to target in Cat form. Usable at range.",
    },
    {
        spec="Feral", name="Lacerate",
        icon="ability_druid_lacerate",
        body="#showtooltip Lacerate\n/cast [stance:5] Lacerate",
        tip="Bear form bleed stack (up to 5). Core tanking threat filler.",
    },
    {
        spec="Feral", name="Mangle (Bear)",
        icon="ability_druid_mangle2",
        body="#showtooltip Mangle (Bear)\n/cast [stance:5] Mangle (Bear)",
        tip="Bear form high-damage single-target hit. Top threat ability.",
    },

    -- ── Resto ─────────────────────────────────────────────────────────────────
    {
        spec="Resto", name="Rejuvenation",
        icon="spell_nature_rejuvenation",
        body="#showtooltip Rejuvenation\n/cast [@mouseover,help,nodead][@target] Rejuvenation",
        tip="Core Resto HoT. Roll on all raid members taking damage.",
    },
    {
        spec="Resto", name="Lifebloom",
        icon="inv_misc_herb_felblossom",
        body="#showtooltip Lifebloom\n/cast [@mouseover,help,nodead][@target] Lifebloom",
        tip="3-stack rolling HoT. Stack to 3 on tank and let bloom heal.",
    },
    {
        spec="Resto", name="Regrowth",
        icon="spell_nature_resistnature",
        body="#showtooltip Regrowth\n/cast [@mouseover,help,nodead][@target] Regrowth",
        tip="HoT + direct heal. Use for burst reactive healing.",
    },
    {
        spec="Resto", name="Nourish",
        icon="ability_druid_nourish",
        body="#showtooltip Nourish\n/cast [@mouseover,help,nodead][@target] Nourish",
        tip="Efficient direct heal boosted by active HoTs on target.",
    },
    {
        spec="Resto", name="Wild Growth",
        icon="ability_druid_wildgrowth",
        body="#showtooltip Wild Growth\n/cast [@mouseover] Wild Growth",
        tip="AoE HoT on 5 injured targets near mouseover. Core raid healing.",
    },
    {
        spec="Resto", name="Tranquility",
        icon="spell_nature_tranquility",
        body="#showtooltip Tranquility\n/cast Tranquility",
        tip="Emergency 8-sec group heal channeled AoE. Use in wipe scenarios.",
    },
    {
        spec="Resto", name="Swiftmend",
        icon="inv_relics_idolofrejuvenation",
        body="#showtooltip Swiftmend\n/cast [@mouseover,help,nodead][@target] Swiftmend",
        tip="Instant burst heal consuming a Rejuv or Regrowth HoT.",
    },
    {
        spec="Resto", name="Nature's Swiftness Heal",
        icon="spell_nature_ravenform",
        body="#showtooltip Healing Touch\n/cast Nature's Swiftness\n/cast Healing Touch",
        tip="Instant maximum Healing Touch emergency heal.",
    },

    -- ── PvP ──────────────────────────────────────────────────────────────────
    {
        spec="PvP", name="Cyclone",
        icon="spell_nature_earthbind",
        body="#showtooltip Cyclone\n/cast [@mouseover,harm,nodead][@target] Cyclone",
        tip="6-sec CC immune to all effects. Core druid PvP CC.",
    },
    {
        spec="PvP", name="Bash",
        icon="ability_druid_bash",
        body="#showtooltip Bash\n/cast [stance:5] Bash",
        tip="Bear form 4-sec stun. Interrupt casters or stun for peeling.",
    },
    {
        spec="PvP", name="Skull Bash",
        icon="ability_druid_skullbash",
        body="#showtooltip Skull Bash\n/cast [stance:3,5] Skull Bash",
        tip="Cat/Bear instant interrupt. Pushback + school lockout.",
    },
    {
        spec="PvP", name="Entangling Roots",
        icon="spell_nature_stranglevines",
        body="#showtooltip Entangling Roots\n/cast [@mouseover,harm,nodead][@target] Entangling Roots",
        tip="Root target 27 sec. Use to peel melee off healer.",
    },
    {
        spec="PvP", name="Faerie Fire",
        icon="spell_nature_faeriefire",
        body="#showtooltip Faerie Fire\n/cast Faerie Fire",
        tip="Prevent stealth re-entry. Track Rogues and prevent vanish.",
    },
    {
        spec="PvP", name="Travel Form",
        icon="ability_druid_travelform",
        body="#showtooltip Travel Form\n/cast Travel Form",
        tip="Instant 40% movement speed. Fastest escape in open world PvP.",
    },
    {
        spec="PvP", name="Abolish Poison",
        icon="spell_nature_nullifypoison_b",
        body="#showtooltip Abolish Poison\n/cast [@player] Abolish Poison",
        tip="Remove and prevent poison on yourself — counters Rogues.",
    },
    {
        spec="PvP", name="Barkskin",
        icon="spell_nature_stoneclawtotem",
        body="#showtooltip Barkskin\n/cast Barkskin",
        tip="-20% damage, castable in all forms, usable while stunned.",
    },
}
