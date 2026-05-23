$dir = "d:\code\wow-addons\addons\SlyRotate"

function Fix-Module {
    param([string]$file, $iconMap)
    $content = [System.IO.File]::ReadAllText($file, [System.Text.Encoding]::UTF8)
    # Remove: Icons comment line
    $content = [Regex]::Replace($content, '(?m)^--[^\r\n]*Icons[^\r\n]*\r?\n', '')
    # Remove: SI() function + ICO = {...} block (including trailing blank line)
    $content = [Regex]::Replace($content, '(?s)local function SI\(n\)[^\r\n]*\r?\nlocal ICO = \{.*?\}\r?\n\r?\n', '')
    # Apply icon -> spell replacements
    foreach ($key in $iconMap.Keys) {
        $old = "icon=ICO.$key"
        $new = "spell=`"$($iconMap[$key])`""
        $content = $content.Replace($old, $new)
    }
    [System.IO.File]::WriteAllText($file, $content, [System.Text.Encoding]::UTF8)
    Write-Host "Fixed: $(Split-Path $file -Leaf)"
}

# Mage
Fix-Module "$dir\SlyRotate_Mage.lua" ([ordered]@{
    'FrostfireBolt'  = 'Frostbolt'
    'ArcanePower'    = 'Arcane Power'
    'PresenceOfMind' = 'Presence of Mind'
    'ArcaneBlast'    = 'Arcane Blast'
    'ArcaneMissile'  = 'Arcane Missiles'
    'Evocation'      = 'Evocation'
    'Combustion'     = 'Combustion'
    'Scorch'         = 'Scorch'
    'Fireball'       = 'Fireball'
    'FireBlast'      = 'Fire Blast'
    'IcyVeins'       = 'Icy Veins'
    'WaterElem'      = 'Summon Water Elemental'
    'ColdSnap'       = 'Cold Snap'
    'Frostbolt'      = 'Frostbolt'
})

# Hunter
Fix-Module "$dir\SlyRotate_Hunter.lua" ([ordered]@{
    'BestialWrath'   = 'Bestial Wrath'
    'RapidFire'      = 'Rapid Fire'
    'KillCommand'    = 'Kill Command'
    'ArcaneShot'     = 'Arcane Shot'
    'SteadyShot'     = 'Steady Shot'
    'ViperAspect'    = 'Aspect of the Viper'
    'AimedShot'      = 'Aimed Shot'
    'MultiShot'      = 'Multi-Shot'
    'TrueshotAura'   = 'Trueshot Aura'
    'ExposeWeakness' = 'Expose Weakness'
    'ExplosiveTrap'  = 'Explosive Trap'
    'WyvernSting'    = 'Wyvern Sting'
    'PetAttack'      = 'Kill Command'
    'HawkAspect'     = 'Aspect of the Hawk'
})

# Rogue
Fix-Module "$dir\SlyRotate_Rogue.lua" ([ordered]@{
    'AdrenalineRush' = 'Adrenaline Rush'
    'BladeFlurry'    = 'Blade Flurry'
    'SliceAndDice'   = 'Slice and Dice'
    'Rupture'        = 'Rupture'
    'Eviscerate'     = 'Eviscerate'
    'SinisterStrike' = 'Sinister Strike'
    'ColdBlood'      = 'Cold Blood'
    'Mutilate'       = 'Mutilate'
    'Hemorrhage'     = 'Hemorrhage'
    'Ambush'         = 'Ambush'
    'Expose'         = 'Expose Armor'
    'KidneyShot'     = 'Kidney Shot'
    'Energy'         = 'Sinister Strike'
})

# Paladin
Fix-Module "$dir\SlyRotate_Paladin.lua" ([ordered]@{
    'SealCommand'       = 'Seal of Command'
    'SealBlood'         = 'Seal of Blood'
    'SealRighteousness' = 'Seal of Righteousness'
    'Judgement'         = 'Judgement'
    'CrusaderStrike'    = 'Crusader Strike'
    'Consecration'      = 'Consecration'
    'Exorcism'          = 'Exorcism'
    'HolyShield'        = 'Holy Shield'
    'AvengersShield'    = "Avenger's Shield"
    'HammerOfWrath'     = 'Hammer of Wrath'
    'DivineFavor'       = 'Divine Favor'
    'HolyShock'         = 'Holy Shock'
    'FlashOfLight'      = 'Flash of Light'
    'HolyLight'         = 'Holy Light'
    'LayOnHands'        = 'Lay on Hands'
})

# Priest
Fix-Module "$dir\SlyRotate_Priest.lua" ([ordered]@{
    'VampiricTouch'  = 'Vampiric Touch'
    'SWPain'         = 'Shadow Word: Pain'
    'SWDeath'        = 'Shadow Word: Death'
    'MindBlast'      = 'Mind Blast'
    'MindFlay'       = 'Mind Flay'
    'Shadowfiend'    = 'Shadowfiend'
    'InnerFocus'     = 'Inner Focus'
    'DispersionIcon' = 'Dispersion'
    'GuardianSpirit' = 'Prayer of Healing'
    'CircleOfHeal'   = 'Circle of Healing'
    'PoH'            = 'Prayer of Healing'
    'FlashHeal'      = 'Flash Heal'
    'GreaterHeal'    = 'Greater Heal'
    'PowerInfusion'  = 'Power Infusion'
    'PWShield'       = 'Power Word: Shield'
    'PainSuppression'= 'Pain Suppression'
})

# Warlock
Fix-Module "$dir\SlyRotate_Warlock.lua" ([ordered]@{
    'CurseAgony'      = 'Curse of Agony'
    'CurseElements'   = 'Curse of the Elements'
    'UnstableAfflict' = 'Unstable Affliction'
    'Corruption'      = 'Corruption'
    'Immolate'        = 'Immolate'
    'SiphonLife'      = 'Siphon Life'
    'ShadowBolt'      = 'Shadow Bolt'
    'Conflagrate'     = 'Conflagrate'
    'Incinerate'      = 'Incinerate'
    'LifeTap'         = 'Life Tap'
    'SoulFire'        = 'Soul Fire'
    'Drain'           = 'Drain Soul'
    'DemonicSacrifice'= 'Demonic Sacrifice'
})

Write-Host "All modules fixed."
