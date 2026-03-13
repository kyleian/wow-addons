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
