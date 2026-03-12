-- ============================================================
-- SlyCharMacros.lua
-- Curated TBC Warrior macro library for the SlyChar Macros wing.
-- Each entry: spec, name, icon (texture short-name), body, tip.
-- ============================================================

SLYCHAR_WARRIOR_MACROS = {

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
