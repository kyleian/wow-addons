-- SlyMetrics.lua  (TBC Anniversary / Interface 20505)
-- Full Details-equivalent combat engine.
-- Tracks: damage done, healing done (effective), overhealing, damage taken,
--         deaths, interrupts, dispels, casts, pet attribution.

local ADDON_NAME    = "SlySuite_Metrics"
local ADDON_VERSION = "1.2.0"

SM = {}
SM.panel    = "dps"   -- "dps" | "hps"
SM.inCombat = false
SM.db       = {}

-- WoW API locals
local band              = bit.band
local CombatLogGetCurrentEventInfo = CombatLogGetCurrentEventInfo
local GetTime           = GetTime
local UnitExists        = UnitExists
local UnitGUID          = UnitGUID
local UnitName          = UnitName
local UnitClass         = UnitClass
local UnitDetailedThreatSituation = UnitDetailedThreatSituation

-- constants
local MELEE_SPELL_ID = 0
local MELEE_SPELL_NM = "Melee"
local FRIENDLY_FLAG  = 0x10   -- COMBATLOG_OBJECT_REACTION_FRIENDLY

-- state
local actors    = {}
local petOwners = {}
local totals    = {}
local elapsed   = 0
local startT    = 0

local function ResetTotals()
    totals = { dmg=0, heal=0, overheal=0, taken=0,
               interrupts=0, dispels=0, deaths=0, casts=0 }
end

local function Reset()
    actors    = {}
    petOwners = {}
    elapsed   = 0
    startT    = 0
    ResetTotals()
end
SM.Reset = Reset
ResetTotals()

-- actor management
local function Actor(guid, name)
    if not guid or guid == "" then return nil end
    if not actors[guid] then
        actors[guid] = {
            guid=guid, name=name or "?", cls=nil,
            dmg=0, dmgSpells={},
            heal=0, overheal=0, healSpells={},
            taken=0, takenSpells={},
            interrupts=0, dispels=0, deaths=0, casts=0,
        }
    end
    local a = actors[guid]
    if name and name ~= "" then a.name = name end
    return a
end

local function OwnerGUID(guid)
    return petOwners[guid] or guid
end

local function ActorOwned(guid, name)
    local og = OwnerGUID(guid)
    if og ~= guid then
        local oa = actors[og]
        if oa then return oa end
        return Actor(og, name and (name.." [owner]") or "?")
    end
    return Actor(guid, name)
end

local function SpellEntry(tbl, spellId, spellName)
    local id = spellId or 0
    if not tbl[id] then
        tbl[id] = { name=spellName or tostring(id), hits=0, crits=0,
                    dmg=0, abs=0, miss=0, heal=0, overheal=0 }
    end
    return tbl[id]
end

-- data accessors
local function ElapsedNow()
    if SM.inCombat then
        return startT > 0 and (GetTime() - startT) or 0
    end
    return elapsed
end

local function GetRows(key)
    local rows = {}
    for _, a in pairs(actors) do
        if (a[key] or 0) > 0 then rows[#rows+1] = a end
    end
    table.sort(rows, function(a, b) return (a[key] or 0) > (b[key] or 0) end)
    return rows, totals[key] or 0, ElapsedNow()
end

SM.GetDMGRows   = function() return GetRows("dmg")   end
SM.GetHEALRows  = function() return GetRows("heal")  end
SM.GetTAKENRows = function() return GetRows("taken") end

SM.GetMISCRows = function()
    local rows = {}
    for _, a in pairs(actors) do
        if a.interrupts > 0 or a.dispels > 0 or a.deaths > 0 or a.casts > 0 then
            rows[#rows+1] = a
        end
    end
    table.sort(rows, function(a, b)
        local sa = a.interrupts*100 + a.dispels*50 + a.deaths*20 + a.casts
        local sb = b.interrupts*100 + b.dispels*50 + b.deaths*20 + b.casts
        return sa > sb
    end)
    return rows, 0, ElapsedNow()
end

-- backwards compat
SM.GetDPSRows = SM.GetDMGRows
SM.GetHPSRows = SM.GetHEALRows

function SM.Fmt(n)
    n = tonumber(n) or 0
    if n >= 1e6 then return string.format("%.1fM", n/1e6) end
    if n >= 1e3 then return string.format("%.1fk", n/1e3) end
    return tostring(math.floor(n))
end

-- damage handler (shared by all damage subevents)
local function HandleDamage(srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags,
                            spellId, spellName, amount, absorbed, critical)
    -- skip enemy sources
    if not srcFlags or band(srcFlags, FRIENDLY_FLAG) == 0 then return end
    local amt = tonumber(amount)   or 0
    local abs = tonumber(absorbed) or 0
    local eff = amt + abs
    if eff <= 0 then return end

    if srcGUID and srcGUID ~= "" and srcName and srcName ~= "" then
        local act = ActorOwned(srcGUID, srcName)
        if act then
            act.dmg    = act.dmg    + eff
            totals.dmg = totals.dmg + eff
            local sp   = SpellEntry(act.dmgSpells, spellId, spellName)
            sp.dmg     = sp.dmg  + eff
            sp.abs     = sp.abs  + abs
            sp.hits    = sp.hits + 1
            if critical then sp.crits = sp.crits + 1 end
        end
    end

    if dstGUID and dstGUID ~= "" and dstName and dstName ~= "" then
        -- only track damage-taken for friendly targets
        if dstFlags and band(dstFlags, FRIENDLY_FLAG) > 0 then
            local tgt = Actor(dstGUID, dstName)
            if tgt then
                tgt.taken     = tgt.taken     + eff
                totals.taken  = totals.taken  + eff
                local sp      = SpellEntry(tgt.takenSpells, spellId, spellName)
                sp.dmg        = sp.dmg  + eff
                sp.hits       = sp.hits + 1
            end
        end
    end
end

-- combat log
-- TBC Anniversary: COMBAT_LOG_EVENT_UNFILTERED fires with NO varargs.
-- Layout from CombatLogGetCurrentEventInfo():
--   ts, subev, hideCaster,
--   srcGUID, srcName, srcFlags, srcRaidFlags,
--   dstGUID, dstName, dstFlags, dstRaidFlags,
--   A1..A12
--
-- SWING_DAMAGE:       A1=amount A2=overkill A3=school A4=resisted A5=blocked A6=absorbed A7=critical
-- SPELL_DAMAGE etc.:  A1=spellId A2=spellName A3=school A4=amount A5=overkill A6=school A7=resisted A8=blocked A9=absorbed A10=critical
-- SPELL_HEAL etc.:    A1=spellId A2=spellName A3=school A4=amount A5=overhealing A6=absorbed A7=critical A8=bIsShield
-- SWING_MISSED:       A1=missType A2=isOffHand A3=amountMissed
-- SPELL_MISSED etc.:  A1=spellId A2=spellName A3=school A4=missType A5=isOffHand A6=amountMissed
-- SPELL_SUMMON:       src=owner dst=pet
-- SPELL_INTERRUPT:    A1=spellId A2=spellName A3=school A4=intSpellId A5=intSpellName A6=intSchool
-- SPELL_DISPEL/STOLEN: A1=spellId A2=spellName A3=school A4=exId A5=exName A6=exSchool A7=auraType

local clFrame = CreateFrame("Frame")
clFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
clFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
clFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
clFrame:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_REGEN_DISABLED" then
        SM.inCombat = true
        Reset()
        startT = GetTime()
        return
    elseif event == "PLAYER_REGEN_ENABLED" then
        SM.inCombat = false
        elapsed = startT > 0 and (GetTime() - startT) or 0
        if SM_Refresh then SM_Refresh() end
        return
    end

    local ts, subev, _,
          srcGUID, srcName, srcFlags, _,
          dstGUID, dstName, dstFlags, _,
          A1, A2, A3, A4, A5, A6, A7, A8, A9, A10 = CombatLogGetCurrentEventInfo()

    -- DAMAGE
    if subev == "SWING_DAMAGE" then
        HandleDamage(srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags,
                     MELEE_SPELL_ID, MELEE_SPELL_NM,
                     A1, A6, A7 == true or A7 == 1)

    elseif subev == "SPELL_DAMAGE"
        or subev == "SPELL_PERIODIC_DAMAGE"
        or subev == "RANGE_DAMAGE"
        or subev == "DAMAGE_SHIELD"
        or subev == "DAMAGE_SPLIT"
        or subev == "SPELL_BUILDING_DAMAGE" then
        HandleDamage(srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags,
                     tonumber(A1), A2,
                     A4, A9, A10 == true or A10 == 1)

    elseif subev == "ENVIRONMENTAL_DAMAGE" then
        -- A1=envType A2=amount A3=overkill A4=school A5=resisted A6=blocked A7=absorbed
        if dstGUID and dstGUID ~= "" and dstName and dstName ~= "" then
            local eff = (tonumber(A2) or 0) + (tonumber(A7) or 0)
            if eff > 0 then
                local tgt = Actor(dstGUID, dstName)
                if tgt then
                    tgt.taken    = tgt.taken    + eff
                    totals.taken = totals.taken + eff
                    local sp     = SpellEntry(tgt.takenSpells, A1 or 0, A1 or "Environmental")
                    sp.dmg = sp.dmg + eff ; sp.hits = sp.hits + 1
                end
            end
        end

    -- ABSORB MISSES count toward attacker's effective damage
    elseif subev == "SWING_MISSED" then
        if A1 == "ABSORB" then
            local amt = tonumber(A3) or 0
            if amt > 0 and srcGUID and srcGUID ~= "" and srcFlags and band(srcFlags, FRIENDLY_FLAG) > 0 then
                local act = ActorOwned(srcGUID, srcName)
                if act then
                    act.dmg = act.dmg + amt ; totals.dmg = totals.dmg + amt
                    local sp = SpellEntry(act.dmgSpells, MELEE_SPELL_ID, MELEE_SPELL_NM)
                    sp.dmg = sp.dmg + amt ; sp.abs = sp.abs + amt ; sp.hits = sp.hits + 1
                end
            end
        end

    elseif subev == "SPELL_MISSED"
        or subev == "SPELL_PERIODIC_MISSED"
        or subev == "RANGE_MISSED"
        or subev == "DAMAGE_SHIELD_MISSED" then
        if A4 == "ABSORB" then
            local amt = tonumber(A6) or 0
            if amt > 0 and srcGUID and srcGUID ~= "" and srcFlags and band(srcFlags, FRIENDLY_FLAG) > 0 then
                local act = ActorOwned(srcGUID, srcName)
                if act then
                    act.dmg = act.dmg + amt ; totals.dmg = totals.dmg + amt
                    local sp = SpellEntry(act.dmgSpells, tonumber(A1), A2)
                    sp.dmg = sp.dmg + amt ; sp.abs = sp.abs + amt ; sp.hits = sp.hits + 1
                end
            end
        end

    -- HEALING
    elseif subev == "SPELL_HEAL" or subev == "SPELL_PERIODIC_HEAL" then
        local amt  = tonumber(A4) or 0
        local over = tonumber(A5) or 0
        local abs  = tonumber(A6) or 0
        local bIsShield = (A8 == true or A8 == 1)
        local eff
        if bIsShield then
            eff = amt
        else
            eff = amt - over + abs
            if eff < 0 then eff = 0 end
        end
        if srcGUID and srcGUID ~= "" and srcName and srcName ~= "" then
            local act = ActorOwned(srcGUID, srcName)
            if act then
                act.heal        = act.heal     + eff
                act.overheal    = act.overheal + over
                totals.heal     = totals.heal     + eff
                totals.overheal = totals.overheal + over
                local sp        = SpellEntry(act.healSpells, tonumber(A1), A2)
                sp.heal         = (sp.heal or 0)     + eff
                sp.overheal     = (sp.overheal or 0) + over
                sp.abs          = sp.abs  + abs
                sp.hits         = sp.hits + 1
                if A7 == true or A7 == 1 then sp.crits = sp.crits + 1 end
            end
        end

    -- PET SUMMON -> map petGUID to ownerGUID
    elseif subev == "SPELL_SUMMON" then
        if srcGUID and srcGUID ~= "" and dstGUID and dstGUID ~= "" then
            petOwners[dstGUID] = srcGUID
            Actor(srcGUID, srcName)
        end

    -- DEATHS
    elseif subev == "UNIT_DIED" or subev == "UNIT_DESTROYED" then
        if dstGUID and dstGUID ~= "" and dstName and dstName ~= "" then
            local act = Actor(dstGUID, dstName)
            if act then act.deaths = act.deaths + 1 ; totals.deaths = totals.deaths + 1 end
            petOwners[dstGUID] = nil
        end

    -- INTERRUPTS
    elseif subev == "SPELL_INTERRUPT" then
        if srcGUID and srcGUID ~= "" and srcName and srcName ~= "" then
            local act = Actor(srcGUID, srcName)
            if act then act.interrupts = act.interrupts + 1 ; totals.interrupts = totals.interrupts + 1 end
        end

    -- DISPELS
    elseif subev == "SPELL_DISPEL" or subev == "SPELL_STOLEN" then
        if srcGUID and srcGUID ~= "" and srcName and srcName ~= "" then
            local act = Actor(srcGUID, srcName)
            if act then act.dispels = act.dispels + 1 ; totals.dispels = totals.dispels + 1 end
        end

    -- CAST COUNT
    elseif subev == "SPELL_CAST_SUCCESS" then
        if srcGUID and srcGUID ~= "" and srcName and srcName ~= "" then
            local act = Actor(srcGUID, srcName)
            if act then act.casts = act.casts + 1 end
        end
    end
end)

-- class poller (resolves cls from unit frames every 5s)
local classFrame = CreateFrame("Frame")
classFrame:SetScript("OnUpdate", (function()
    local clock = 0
    return function(_, dt)
        clock = clock + dt
        if clock < 5 then return end
        clock = 0
        local function tryUnit(u)
            if not UnitExists(u) then return end
            local guid = UnitGUID(u)
            if guid and actors[guid] and not actors[guid].cls then
                local _, cls = UnitClass(u)
                actors[guid].cls = cls
            end
        end
        tryUnit("player")
        for i = 1, 4  do tryUnit("party"..i) end
        for i = 1, 40 do tryUnit("raid"..i)  end
    end
end)())

-- threat ticker
SM.threat = {}
local thrClock = 0
local thrFrame = CreateFrame("Frame")
thrFrame:SetScript("OnUpdate", function(_, dt)
    thrClock = thrClock + dt
    if thrClock < 0.5 then return end
    thrClock = 0
    local rows = {}
    local function tryUnit(u)
        if not UnitExists(u) then return end
        local isTanking, _, threatPct, _, threatVal =
            UnitDetailedThreatSituation(u, "target")
        if threatVal and threatVal > 0 then
            local _, cls = UnitClass(u)
            rows[#rows+1] = {
                name=UnitName(u) or u, cls=cls,
                val=threatVal, pct=threatPct or 0,
                isTank=isTanking and true or false,
            }
        end
    end
    tryUnit("player")
    for i = 1, 4  do tryUnit("party"..i) end
    for i = 1, 40 do tryUnit("raid"..i)  end
    table.sort(rows, function(a, b) return a.val > b.val end)
    SM.threat = rows
    if SM_RefreshThreat then SM_RefreshThreat() end
end)

-- refresh ticker (0.5s in combat + 3s linger after)
local dClock  = 0
local dLinger = 0
local dFrame  = CreateFrame("Frame")
dFrame:SetScript("OnUpdate", function(_, dt)
    if SM.inCombat then
        dLinger = 3
    elseif dLinger > 0 then
        dLinger = dLinger - dt
    else
        return
    end
    dClock = dClock + dt
    if dClock < 0.5 then return end
    dClock = 0
    if SM_Refresh then SM_Refresh() end
end)

-- Init
local function Init()
    SlyMetricsDB = SlyMetricsDB or {}
    SM.db        = SlyMetricsDB
    if SM_BuildUI then SM_BuildUI() end
end

-- Boot
local bootFrame = CreateFrame("Frame")
bootFrame:RegisterEvent("ADDON_LOADED")
bootFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
bootFrame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 ~= ADDON_NAME then return end
        self:UnregisterEvent("ADDON_LOADED")
        if SlySuiteDataFrame and SlySuiteDataFrame.Register then
            SlySuiteDataFrame.Register(ADDON_NAME, ADDON_VERSION, Init, {
                description = "Damage, healing and threat meter.",
                slash       = "/slymetrics",
                icon        = "Interface\\Icons\\Ability_Warrior_Charge",
            })
        else
            Init()
        end
    elseif event == "PLAYER_ENTERING_WORLD" then
        self:UnregisterEvent("PLAYER_ENTERING_WORLD")
        if not SlyMetricsFrame then Init() end
    end
end)

-- Slash
SLASH_SLYMETRICS1 = "/slymetrics"
SlashCmdList["SLYMETRICS"] = function(msg)
    msg = string.lower(string.gsub(msg or "", "^%s*(.-)%s*$", "%1"))
    if not SlyMetricsFrame then
        if SM_BuildUI then SM_BuildUI()
        else print("|cffff4444[SlyMetrics]|r Not ready yet.") ; return end
    end
    if     msg == "reset" then Reset() ; if SM_Refresh then SM_Refresh() end
    elseif msg == "dmg"   or msg == "dps"  then SM.panel = "dps"  ; if SM_Refresh then SM_Refresh() end
    elseif msg == "heal"  or msg == "hps"  then SM.panel = "hps"  ; if SM_Refresh then SM_Refresh() end
    elseif msg == "taken"                  then SM.panel = "taken" ; if SM_Refresh then SM_Refresh() end
    elseif msg == "misc"                   then SM.panel = "misc"  ; if SM_Refresh then SM_Refresh() end
    elseif msg == "pos" then
        if SM.db then SM.db.mx = nil ; SM.db.my = nil end
        SlyMetricsFrame:ClearAllPoints()
        SlyMetricsFrame:SetPoint("RIGHT", UIParent, "RIGHT", -60, 100)
        SlyMetricsFrame:Show()
        print("|cff00ccff[SlyMetrics]|r Window repositioned.")
    else
        if SlyMetricsFrame:IsShown() then SlyMetricsFrame:Hide()
        else SlyMetricsFrame:Show() end
    end
end