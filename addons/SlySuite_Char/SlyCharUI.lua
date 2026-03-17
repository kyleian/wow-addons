-- ============================================================
-- SlyCharUI.lua
-- Movable character sheet: gear slots, player model,
-- Stats tab (base + ECS), Gear Sets tab (IRR)
-- Left-click slot -> ItemRack-style gear picker popup
-- ============================================================

-- TBC Anniversary: C_Container is present on the anniv client;
-- remap bag APIs exactly like the real ItemRack addon does.
local _PickupContainerItem
local _GetContainerNumSlots
local _GetContainerItemID
local _GetItemLink
if C_Container then
    _PickupContainerItem  = C_Container.PickupContainerItem
    _GetContainerNumSlots = C_Container.GetContainerNumSlots
    _GetContainerItemID   = function(bag, slot)
        local info = C_Container.GetContainerItemInfo(bag, slot)
        return info and info.itemID or nil
    end
    _GetItemLink          = C_Container.GetContainerItemLink or GetContainerItemLink
else
    _PickupContainerItem  = PickupContainerItem
    _GetContainerNumSlots = GetContainerNumSlots
    _GetContainerItemID   = GetContainerItemID
    _GetItemLink          = GetContainerItemLink
end

SlyCharMainFrame = nil   -- global ref, set at end of SC_BuildMain

-- ---- Layout ----
local FRAME_W      = 732
local FRAME_H      = 404
local HDR_H        = 30
local FOOT_H       = 20
local CHAR_W       = 370
local BTN_STRIP_W  = 32
local SIDE_W       = FRAME_W - CHAR_W - BTN_STRIP_W  -- 330
local WING_W       = 360  -- expandable right-side wing panel
local PAD      = 8
local SLOT_S   = 38
local SLOT_GAP = 5
local SLOT_TOP = -8

local COL_L    = PAD
local COL_R    = CHAR_W - PAD - SLOT_S
local MODEL_X  = COL_L + SLOT_S + PAD
local MODEL_W  = COL_R - PAD - MODEL_X
local MODEL_H  = 280

local COL_H     = 8 * SLOT_S + 7 * SLOT_GAP
local WPN_Y     = SLOT_TOP - 7 * (SLOT_S + SLOT_GAP)   -- aligns with col row 8
local WPN_GAP   = 10
local WPN_TOTAL = 4 * SLOT_S + 3 * WPN_GAP
local WPN_START = math.floor((CHAR_W - WPN_TOTAL) / 2)

-- ---- Slot lists ----
local LEFT_SLOTS = {
    {id=1,  label="Head"},    {id=2,  label="Neck"},
    {id=3,  label="Shoulder"},{id=15, label="Back"},
    {id=5,  label="Chest"},   {id=4,  label="Shirt"},
    {id=19, label="Tabard"},  {id=9,  label="Wrist"},
}
local RIGHT_SLOTS = {
    {id=10, label="Hands"},    {id=6,  label="Waist"},
    {id=7,  label="Legs"},     {id=8,  label="Feet"},
    {id=11, label="Ring 1"},   {id=12, label="Ring 2"},
    {id=13, label="Trinket 1"},{id=14, label="Trinket 2"},
}
local WEAPON_SLOTS = {
    {id=16, label="Main Hand"},
    {id=17, label="Off Hand"},
    {id=18, label="Ranged"},
    {id=0,  label="Ammo"},
}

local QUALITY_COLORS = {
    [0]={0.62,0.62,0.62}, [1]={1,1,1},
    [2]={0.12,1,0},       [3]={0,0.44,0.87},
    [4]={0.64,0.21,0.93}, [5]={1,0.5,0},
    [6]={0.9,0.8,0.5},
}
local CLASS_COLORS = {
    WARRIOR={0.78,0.61,0.43}, PALADIN={0.96,0.55,0.73},
    HUNTER ={0.67,0.83,0.45}, ROGUE  ={1,0.96,0.41},
    PRIEST ={1,1,1},          SHAMAN ={0,0.44,0.87},
    MAGE   ={0.41,0.8,0.94},  WARLOCK={0.58,0.51,0.79},
    DRUID  ={1,0.49,0.04},
}

-- invtype strings that fit each slot id
local SLOT_INVTYPES = {
    [1] ={INVTYPE_HEAD=true},
    [2] ={INVTYPE_NECK=true},
    [3] ={INVTYPE_SHOULDER=true},
    [4] ={INVTYPE_BODY=true},
    [5] ={INVTYPE_CHEST=true, INVTYPE_ROBE=true},
    [6] ={INVTYPE_WAIST=true},
    [7] ={INVTYPE_LEGS=true},
    [8] ={INVTYPE_FEET=true},
    [9] ={INVTYPE_WRIST=true},
    [10]={INVTYPE_HAND=true},
    [11]={INVTYPE_FINGER=true},
    [12]={INVTYPE_FINGER=true},
    [13]={INVTYPE_TRINKET=true},
    [14]={INVTYPE_TRINKET=true},
    [15]={INVTYPE_CLOAK=true},
    [16]={INVTYPE_WEAPON=true, INVTYPE_2HWEAPON=true, INVTYPE_WEAPONMAINHAND=true},
    [17]={INVTYPE_WEAPONOFFHAND=true, INVTYPE_SHIELD=true, INVTYPE_HOLDABLE=true, INVTYPE_WEAPON=true},
    [18]={INVTYPE_RANGED=true, INVTYPE_RANGEDRIGHT=true, INVTYPE_THROWN=true, INVTYPE_RELIC=true},
    [19]={INVTYPE_TABARD=true},
    [0] ={INVTYPE_AMMO=true},
}

-- Blizzard inventory slot IDs for equipment slots (used by secure overlay macro).
-- /use <slotId> resolves spell targeting, cursor-item equip, and enchant application
-- onto the item in that equipment slot -- no CharacterFrame needed.
local EQUIP_SLOT_IDS = {
    [1]=true,  [2]=true,  [3]=true,  [4]=true,  [5]=true,
    [6]=true,  [7]=true,  [8]=true,  [9]=true,  [10]=true,
    [11]=true, [12]=true, [13]=true, [14]=true, [15]=true,
    [16]=true, [17]=true, [18]=true, [19]=true,
}
-- SpellIsTargetingUnit was added after TBC; guard against it not existing.
local _hasSpellIsTargetingUnit = type(SpellIsTargetingUnit) == "function"
-- Only Hunters use the ammo slot; hide it for all other classes.
local _classUsesAmmo = (select(2, UnitClass("player"))) == "HUNTER"

-- ---- Widget refs (module-level) ----
local slotWidgets   = {}
local tabFrames     = {}
local tabBtnWidgets = {}
local statRows      = {}
local setRowWidgets = {}
local repRows       = {}
local skillRows     = {}
-- Secure overlay buttons (per slot) that handle SpellIsTargeting() application.
local _secureSlots  = {}
-- One shared OnUpdate monitor that enables/disables the overlays.
local _targetMonitor = CreateFrame("Frame")
do
    local _wasTargeting   = false
    local _autoShownSlyChar = false   -- true when we auto-opened the frame for targeting
    _targetMonitor:SetScript("OnUpdate", function()
        -- Activate secure overlays whenever a spell is targeting (armor kit,
        -- oil, stone, poison, enchant) OR any cursor type is set (item drag).
        -- PickupInventoryItem is permanently restricted in TBC Anniversary; the
        -- only valid path is SecureActionButtonTemplate firing "/use N", which
        -- resolves SpellIsTargeting AND cursor-item equips onto gear slots.
        local t = SpellIsTargeting() or (GetCursorInfo() ~= nil)
        if t == _wasTargeting then return end
        -- EnableMouse is NOT combat-restricted (only SetAttribute is).
        _wasTargeting = t
        for sid, sBtn in pairs(_secureSlots) do
            sBtn:EnableMouse(t)
            -- Un-register / re-register LeftButton drag on the parent slot button.
            -- Without this, RegisterForDrag("LeftButton") on the parent claims
            -- the LeftButton-down event and the secure child never sees LeftButtonUp.
            local w = slotWidgets[sid]
            if w and w.frame then
                if t then
                    w.frame:RegisterForDrag()           -- release while targeting
                else
                    w.frame:RegisterForDrag("LeftButton") -- restore
                end
            end
        end

        -- Auto-open SlyChar when there's an item on cursor (bag drag, enchant
        -- scroll, etc.) OR when SpellIsTargeting for an item-use effect (weapon
        -- stone, oil, armor kit, poison).  SpellIsTargetingUnit() is true for
        -- targeted SPELL abilities (Polymorph, Sap, Trap) which should NOT open
        -- SlyChar.  Guard: SpellIsTargetingUnit may not exist in TBC Anniversary;
        -- in that case we cannot distinguish safely so we skip the spell-targeting
        -- auto-open entirely (cursor-drag auto-open still works).
        local cursorActive  = (GetCursorInfo() ~= nil)
        local itemTargeting = _hasSpellIsTargetingUnit and
            SpellIsTargeting() and not SpellIsTargetingUnit()
        if t then
            if cursorActive or itemTargeting then
                if not (SlyCharMainFrame and SlyCharMainFrame:IsShown()) then
                    if SC_ShowMain and not InCombatLockdown() then
                        SC_ShowMain()
                        _autoShownSlyChar = true
                    end
                else
                    _autoShownSlyChar = false  -- was already open; don't auto-close it
                end
            end
        else
            -- Targeting ended (item applied or right-click cancelled).
            -- Only auto-close if we were the ones who opened it.
            if _autoShownSlyChar then
                _autoShownSlyChar = false
                -- Small delay so the player sees the result update on the slot.
                C_Timer.After(1.5, function()
                    if SlyCharMainFrame and SlyCharMainFrame:IsShown()
                        and not (GetCursorInfo() ~= nil)
                        and not SpellIsTargeting() then
                        SlyCharMainFrame:Hide()
                    end
                end)
            end
        end
    end)
end
local nitLockRows   = {}
local nitRunRows    = {}
local nitRunHeader  = nil
local headerName    = nil
local headerInfo    = nil
local headerGS      = nil

local MAX_STAT_ROWS  = 60
local MAX_SET_ROWS        = 14   -- visible rows that fit the panel
local setsScrollOffset    = 0    -- first visible set index (0-based)
local setsScrollInfoLabel = nil  -- FontString updated by SC_RefreshSets
local setsUI = { subTab="gear", gearContent=nil, barsContent=nil, bisContent=nil, subGearBtn=nil, subBarsBtn=nil, subBisBtn=nil }
local MAX_REP_ROWS        = 80
local MAX_SKILL_ROWS      = 60
local miscUI = { honorContent=nil }  -- rep/skills/honor live in wing panes now
local MAX_BAR_ROWS        = 14   -- visible action bar profile rows
local barRowWidgets       = {}
local barsScrollOffset    = 0
local barsScrollInfoLabel = nil
local MAX_NIT_LOCK_ROWS   = 15   -- reduced by 2 to make room for layer display
local MAX_NIT_RUN_ROWS    = 0   -- section removed; space used for per-alt view
local nitLockScrollOffset = 0
local nitScrollInfoLabel  = nil
local suiteRowWidgets  = {}    -- [name]={row,dot,nameTx,statusTx,toggleBtn}
local suiteErrLabel    = nil   -- FontString: "N errors on disk"
local suiteCont        = nil   -- scroll child for sub-mod rows
local nitLayerLabel       = nil  -- FontString showing current layer
local nitSubTab           = "locks"  -- "locks" | "guild" | "friends" | "layer"
local nitLockContent      = nil  -- Frame containing lockout header+rows
local nitLayerContent     = nil  -- Frame containing layer number display
local nitLayerSrcLabel    = nil  -- FontString for source info in layer tab
local nitSubLayerBtn      = nil
local nitSubLockBtn       = nil  -- sub-tab button widgets
local nitSubGuildBtn      = nil
local nitGuildContent     = nil
local nitGuildHeaderFs    = nil
local nitGuildRows        = {}
local nitSubFriendsBtn    = nil
local nitFriendsContent   = nil
local nitFriendsHeaderFs  = nil
local nitFriendsRows      = {}
local socialUI = {               -- Friends / Guild social tab
    subTab          = "friends", -- "friends" | "guild"
    guildRows       = {},
    friendsRows     = {},
    guildContent    = nil,
    guildHeaderFs   = nil,
    subGuildBtn     = nil,
    friendsContent  = nil,
    friendsHeaderFs = nil,
    subFriendsBtn   = nil,
    scrollOffset    = 0,
}

-- Macro wing state
local macroRows       = {}
local macroScrollOff  = 0
local macroSpecFilter = "All"
local MAX_MACRO_ROWS  = 17
local macroSpecBtns   = {}
local macroScrollLabel = nil

-- Spec filter tabs per class (keyed by UnitClassBase token)
local CLASS_SPECS = {
    WARRIOR     = { "All", "Arms",        "Fury",   "Tank",         "PvP" },
    PALADIN     = { "All", "Holy",        "Prot",   "Ret",          "PvP" },
    HUNTER      = { "All", "BM",          "MM",     "Survival",     "PvP" },
    ROGUE       = { "All", "Assassination","Combat", "Subtlety",    "PvP" },
    PRIEST      = { "All", "Discipline",  "Holy",   "Shadow",       "PvP" },
    SHAMAN      = { "All", "Elemental",   "Enhance","Resto",        "PvP" },
    MAGE        = { "All", "Arcane",      "Fire",   "Frost",        "PvP" },
    WARLOCK     = { "All", "Affliction",  "Demo",   "Destruction",  "PvP" },
    DRUID       = { "All", "Balance",     "Feral",  "Resto",        "PvP" },
    DEATHKNIGHT = { "All", "Blood",       "Frost",  "Unholy",       "PvP" },
}

-- ============================================================
-- Themes
-- ============================================================
local SC_THEMES = {
    shadow = {
        name="Shadow",
        frameBg  = {0.05, 0.05, 0.07, 0.97},
        border   = {0.28, 0.28, 0.35, 1},
        headerBg = {0.09, 0.09, 0.14, 1},
        sep      = {0.25, 0.25, 0.32, 1},
        div      = {0.20, 0.20, 0.27, 1},
        sideBg   = {0.05, 0.05, 0.08, 1},
        tabBarBg = {0.07, 0.07, 0.11, 1},
        footBg   = {0.07, 0.07, 0.10, 1},
        modelBg  = {0.03, 0.03, 0.04, 1},
        tabActiveBg   = {0.11, 0.16, 0.26},
        tabInactiveBg = {0.06, 0.06, 0.09},
        tabActiveTxt  = {1.00, 1.00, 1.00},
        tabInactiveTxt= {0.55, 0.55, 0.60},
    },
    midnight = {
        name="Midnight",
        frameBg  = {0.04, 0.06, 0.14, 0.97},
        border   = {0.30, 0.42, 0.72, 1},
        headerBg = {0.06, 0.09, 0.22, 1},
        sep      = {0.20, 0.30, 0.55, 1},
        div      = {0.15, 0.22, 0.44, 1},
        sideBg   = {0.04, 0.06, 0.16, 1},
        tabBarBg = {0.06, 0.09, 0.20, 1},
        footBg   = {0.05, 0.08, 0.18, 1},
        modelBg  = {0.02, 0.03, 0.08, 1},
        tabActiveBg   = {0.15, 0.24, 0.52},
        tabInactiveBg = {0.05, 0.07, 0.17},
        tabActiveTxt  = {0.75, 0.90, 1.00},
        tabInactiveTxt= {0.42, 0.52, 0.70},
    },
    crimson = {
        name="Crimson",
        frameBg  = {0.10, 0.04, 0.04, 0.97},
        border   = {0.55, 0.18, 0.18, 1},
        headerBg = {0.16, 0.06, 0.06, 1},
        sep      = {0.38, 0.10, 0.10, 1},
        div      = {0.28, 0.08, 0.08, 1},
        sideBg   = {0.11, 0.04, 0.04, 1},
        tabBarBg = {0.15, 0.05, 0.05, 1},
        footBg   = {0.13, 0.05, 0.05, 1},
        modelBg  = {0.05, 0.02, 0.02, 1},
        tabActiveBg   = {0.42, 0.10, 0.10},
        tabInactiveBg = {0.12, 0.04, 0.04},
        tabActiveTxt  = {1.00, 0.72, 0.72},
        tabInactiveTxt= {0.62, 0.38, 0.38},
    },
    emerald = {
        name="Emerald",
        frameBg  = {0.04, 0.09, 0.05, 0.97},
        border   = {0.20, 0.52, 0.24, 1},
        headerBg = {0.05, 0.13, 0.07, 1},
        sep      = {0.12, 0.34, 0.14, 1},
        div      = {0.08, 0.24, 0.10, 1},
        sideBg   = {0.03, 0.10, 0.05, 1},
        tabBarBg = {0.05, 0.13, 0.07, 1},
        footBg   = {0.04, 0.11, 0.06, 1},
        modelBg  = {0.02, 0.05, 0.03, 1},
        tabActiveBg   = {0.10, 0.38, 0.14},
        tabInactiveBg = {0.04, 0.10, 0.05},
        tabActiveTxt  = {0.68, 1.00, 0.70},
        tabInactiveTxt= {0.38, 0.62, 0.40},
    },
    gold = {
        name="Gold",
        frameBg  = {0.12, 0.10, 0.04, 0.97},
        border   = {0.68, 0.52, 0.14, 1},
        headerBg = {0.18, 0.15, 0.06, 1},
        sep      = {0.46, 0.36, 0.10, 1},
        div      = {0.32, 0.24, 0.07, 1},
        sideBg   = {0.13, 0.10, 0.04, 1},
        tabBarBg = {0.18, 0.14, 0.05, 1},
        footBg   = {0.16, 0.13, 0.05, 1},
        modelBg  = {0.06, 0.05, 0.02, 1},
        tabActiveBg   = {0.44, 0.32, 0.08},
        tabInactiveBg = {0.14, 0.11, 0.04},
        tabActiveTxt  = {1.00, 0.92, 0.50},
        tabInactiveTxt= {0.68, 0.58, 0.28},
    },
    storm = {
        name="Storm",
        frameBg  = {0.08, 0.09, 0.13, 0.97},
        border   = {0.46, 0.50, 0.64, 1},
        headerBg = {0.11, 0.12, 0.18, 1},
        sep      = {0.30, 0.34, 0.46, 1},
        div      = {0.22, 0.25, 0.34, 1},
        sideBg   = {0.08, 0.09, 0.14, 1},
        tabBarBg = {0.11, 0.12, 0.18, 1},
        footBg   = {0.10, 0.11, 0.16, 1},
        modelBg  = {0.04, 0.04, 0.07, 1},
        tabActiveBg   = {0.24, 0.28, 0.46},
        tabInactiveBg = {0.09, 0.10, 0.15},
        tabActiveTxt  = {0.82, 0.90, 1.00},
        tabInactiveTxt= {0.48, 0.54, 0.68},
    },
    void = {
        name="Void",
        frameBg  = {0.06, 0.03, 0.12, 0.97},
        border   = {0.50, 0.22, 0.70, 1},
        headerBg = {0.10, 0.05, 0.18, 1},
        sep      = {0.34, 0.14, 0.50, 1},
        div      = {0.24, 0.10, 0.36, 1},
        sideBg   = {0.07, 0.04, 0.14, 1},
        tabBarBg = {0.10, 0.05, 0.18, 1},
        footBg   = {0.08, 0.04, 0.16, 1},
        modelBg  = {0.03, 0.01, 0.07, 1},
        tabActiveBg   = {0.36, 0.12, 0.52},
        tabInactiveBg = {0.08, 0.04, 0.14},
        tabActiveTxt  = {0.90, 0.68, 1.00},
        tabInactiveTxt= {0.52, 0.36, 0.66},
    },
    frost = {
        name="Frost",
        frameBg  = {0.05, 0.09, 0.14, 0.97},
        border   = {0.55, 0.72, 0.88, 1},
        headerBg = {0.08, 0.14, 0.22, 1},
        sep      = {0.36, 0.52, 0.68, 1},
        div      = {0.22, 0.38, 0.52, 1},
        sideBg   = {0.06, 0.10, 0.16, 1},
        tabBarBg = {0.08, 0.14, 0.22, 1},
        footBg   = {0.07, 0.12, 0.20, 1},
        modelBg  = {0.03, 0.05, 0.09, 1},
        tabActiveBg   = {0.22, 0.44, 0.62},
        tabInactiveBg = {0.06, 0.11, 0.18},
        tabActiveTxt  = {0.82, 0.96, 1.00},
        tabInactiveTxt= {0.44, 0.60, 0.74},
    },
    obsidian = {
        name="Obsidian",
        frameBg  = {0.03, 0.03, 0.04, 0.98},
        border   = {0.22, 0.22, 0.28, 1},
        headerBg = {0.05, 0.05, 0.07, 1},
        sep      = {0.16, 0.16, 0.20, 1},
        div      = {0.12, 0.12, 0.16, 1},
        sideBg   = {0.03, 0.03, 0.05, 1},
        tabBarBg = {0.05, 0.05, 0.07, 1},
        footBg   = {0.04, 0.04, 0.06, 1},
        modelBg  = {0.01, 0.01, 0.02, 1},
        tabActiveBg   = {0.18, 0.18, 0.26},
        tabInactiveBg = {0.04, 0.04, 0.07},
        tabActiveTxt  = {0.90, 0.90, 0.96},
        tabInactiveTxt= {0.40, 0.40, 0.46},
    },
    copper = {
        name="Copper",
        frameBg  = {0.11, 0.07, 0.03, 0.97},
        border   = {0.72, 0.44, 0.18, 1},
        headerBg = {0.17, 0.11, 0.04, 1},
        sep      = {0.48, 0.28, 0.10, 1},
        div      = {0.34, 0.20, 0.06, 1},
        sideBg   = {0.12, 0.07, 0.03, 1},
        tabBarBg = {0.16, 0.10, 0.04, 1},
        footBg   = {0.14, 0.09, 0.04, 1},
        modelBg  = {0.05, 0.03, 0.01, 1},
        tabActiveBg   = {0.46, 0.26, 0.06},
        tabInactiveBg = {0.13, 0.08, 0.03},
        tabActiveTxt  = {1.00, 0.82, 0.48},
        tabInactiveTxt= {0.62, 0.48, 0.28},
    },
    rose = {
        name="Rose",
        frameBg  = {0.12, 0.04, 0.07, 0.97},
        border   = {0.70, 0.28, 0.46, 1},
        headerBg = {0.18, 0.06, 0.10, 1},
        sep      = {0.46, 0.16, 0.28, 1},
        div      = {0.32, 0.10, 0.20, 1},
        sideBg   = {0.13, 0.04, 0.08, 1},
        tabBarBg = {0.18, 0.06, 0.10, 1},
        footBg   = {0.16, 0.05, 0.09, 1},
        modelBg  = {0.06, 0.02, 0.04, 1},
        tabActiveBg   = {0.48, 0.14, 0.26},
        tabInactiveBg = {0.14, 0.04, 0.08},
        tabActiveTxt  = {1.00, 0.70, 0.82},
        tabInactiveTxt= {0.64, 0.38, 0.48},
    },
    venom = {
        name="Venom",
        frameBg  = {0.07, 0.10, 0.03, 0.97},
        border   = {0.48, 0.68, 0.12, 1},
        headerBg = {0.10, 0.16, 0.04, 1},
        sep      = {0.30, 0.46, 0.08, 1},
        div      = {0.20, 0.32, 0.05, 1},
        sideBg   = {0.08, 0.11, 0.03, 1},
        tabBarBg = {0.10, 0.16, 0.04, 1},
        footBg   = {0.09, 0.14, 0.04, 1},
        modelBg  = {0.03, 0.05, 0.01, 1},
        tabActiveBg   = {0.28, 0.46, 0.06},
        tabInactiveBg = {0.08, 0.12, 0.03},
        tabActiveTxt  = {0.80, 1.00, 0.30},
        tabInactiveTxt= {0.48, 0.62, 0.26},
    },
}
local SC_THEME_ORDER = {"shadow","midnight","crimson","emerald","gold","storm","void","frost","obsidian","copper","rose","venom"}
local themeRefs = {}   -- texture handles populated in SC_BuildMain

-- If SlyStyle (SlySuite_Style addon) is loaded, use its shared theme table so
-- all addons (SlyBag, SlyRepair, Whelp) see the same palettes and receive
-- theme-change callbacks when the user cycles via the theme button.
if SlyStyle then
    SC_THEMES     = SlyStyle.themes
    SC_THEME_ORDER = SlyStyle.themeOrder
end

function SC_ApplyTheme(name)
    local th = SC_THEMES[name]
    if not th then name = "shadow" ; th = SC_THEMES.shadow end
    if SC.db then SC.db.theme = name end
    -- Notify SlyStyle and all registered theme-change listeners across the suite
    -- (SlyBag, SlyRepair, Whelp, etc. all repaint via OnThemeChange callbacks).
    if SlyStyle then SlyStyle._fire(name) end
    local r = themeRefs
    local function sc(t, c) if t then t:SetColorTexture(c[1],c[2],c[3],c[4] or 1) end end
    sc(r.frameBg,    th.frameBg)
    sc(r.frameBord,  th.border)
    sc(r.frameInner, th.frameBg)
    sc(r.hdrBg,      th.headerBg)
    sc(r.hdrSep,     th.sep)
    sc(r.charDiv,    th.div)
    sc(r.sideBg,     th.sideBg)
    sc(r.tabBarBg,   th.tabBarBg)
    sc(r.tabSep,     th.div)
    sc(r.modelBg,    th.modelBg)
    sc(r.footBg,     th.footBg)
    if r.themeBtn then
        r.themeBtn:SetText("|cffbbbbff"..th.name.."|r")
    end
    SC_SwitchTab(SC.db and SC.db.lastTab or "stats")
end

function SC_CycleTheme()
    local cur = (SC.db and SC.db.theme) or "shadow"
    local idx = 1
    for i, k in ipairs(SC_THEME_ORDER) do
        if k == cur then idx = i ; break end
    end
    idx = (idx % #SC_THEME_ORDER) + 1
    SC_ApplyTheme(SC_THEME_ORDER[idx])
end

-- Wing panel state (spellbook wing still built; side-panel tracker handles the rest)
local wingFrame       = nil
local wingPanes       = {}
local activeWingKey   = nil
local wingTitleTx     = nil
local currentSidePanel      = nil   -- currently open native side panel
local hookedPanels          = {}    -- frames we've already HookScript'd
local talentFrameHooked     = false -- kept for compat
local spellRows       = {}
local MAX_SPELL_ROWS  = 120
local TAL_SZ          = 32
local TAL_PAD         = 8
local TAL_STEP        = TAL_SZ + TAL_PAD
local TAL_ROWS        = 7
local TAL_COLS        = 4

-- ============================================================
-- Gear Picker (TOOLTIP strata, OnUpdate-based hide timer)
-- ============================================================
local picker              = nil
local pickerRows          = {}
local PICKER_W            = 248
local PICKER_ROW_H        = 26
local PICKER_MAX          = 18
local pickerHideCountdown = 0
local pickerTimerFrame    = nil

local function CancelPickerHide()
    pickerHideCountdown = 0
end

local function SchedulePickerHide()
    pickerHideCountdown = 0.3
end

function SC_HidePicker()
    CancelPickerHide()
    if picker then
        picker._slotId = nil
        picker:Hide()
    end
end

local function SC_BuildPicker()
    local f = CreateFrame("Frame", "SlyCharGearPicker", UIParent)
    f:SetWidth(PICKER_W)
    f:SetHeight(100)
    f:SetFrameStrata("TOOLTIP")
    f:EnableMouse(false)
    f:HookScript("OnShow", function(self) self:EnableMouse(true) end)
    f:HookScript("OnHide", function(self) self:EnableMouse(false) end)
    f:Hide()

    local bord = f:CreateTexture(nil, "OVERLAY")
    bord:SetAllPoints(f)
    bord:SetColorTexture(0.30, 0.30, 0.45, 1)

    local bg = f:CreateTexture(nil, "BACKGROUND")
    bg:SetPoint("TOPLEFT",     f, "TOPLEFT",      1, -1)
    bg:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -1,  1)
    bg:SetColorTexture(0.06, 0.06, 0.10, 0.97)

    local hdrBg = f:CreateTexture(nil, "BORDER")
    hdrBg:SetPoint("TOPLEFT",  f, "TOPLEFT",  1, -1)
    hdrBg:SetPoint("TOPRIGHT", f, "TOPRIGHT", -1, -1)
    hdrBg:SetHeight(20)
    hdrBg:SetColorTexture(0.10, 0.10, 0.18, 1)

    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    title:SetFont(title:GetFont(), 10, "")
    title:SetPoint("TOPLEFT", f, "TOPLEFT", 6, -5)
    title:SetTextColor(0.60, 0.82, 1.00)
    f.title = title

    local sep = f:CreateTexture(nil, "ARTWORK")
    sep:SetHeight(1)
    sep:SetPoint("TOPLEFT",  f, "TOPLEFT",  1, -21)
    sep:SetPoint("TOPRIGHT", f, "TOPRIGHT", -1, -21)
    sep:SetColorTexture(0.20, 0.20, 0.35, 1)

    local content = CreateFrame("Frame", nil, f)
    content:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -22)
    content:SetWidth(PICKER_W - 2)
    f.content = content

    for i = 1, PICKER_MAX do
        local row = CreateFrame("Button", nil, content)
        row:SetSize(PICKER_W - 4, PICKER_ROW_H)
        row:SetPoint("TOPLEFT", content, "TOPLEFT", 2, -((i-1)*PICKER_ROW_H))

        local hl = row:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints(row)
        hl:SetColorTexture(1, 1, 1, 0.10)

        local eqGlow = row:CreateTexture(nil, "BACKGROUND")
        eqGlow:SetAllPoints(row)
        eqGlow:SetColorTexture(0.80, 0.65, 0, 0.14)
        eqGlow:Hide()
        row.eqGlow = eqGlow

        local rowSep = row:CreateTexture(nil, "ARTWORK")
        rowSep:SetHeight(1)
        rowSep:SetPoint("BOTTOMLEFT",  row, "BOTTOMLEFT",  0, 0)
        rowSep:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, 0)
        rowSep:SetColorTexture(0.14, 0.14, 0.20, 1)

        local icn = row:CreateTexture(nil, "ARTWORK")
        icn:SetSize(22, 22)
        icn:SetPoint("LEFT", row, "LEFT", 4, 0)
        icn:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        row.icn = icn

        local nm = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        nm:SetFont(nm:GetFont(), 10, "")
        nm:SetPoint("TOPLEFT", icn, "TOPRIGHT", 4, -1)
        nm:SetWidth(PICKER_W - 80)
        nm:SetJustifyH("LEFT")
        row.nm = nm

        local sub = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        sub:SetFont(sub:GetFont(), 8, "")
        sub:SetPoint("BOTTOMLEFT", icn, "BOTTOMRIGHT", 4, 2)
        sub:SetTextColor(0.50, 0.50, 0.55)
        row.sub = sub

        local ilvl = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        ilvl:SetFont(ilvl:GetFont(), 9, "")
        ilvl:SetPoint("RIGHT", row, "RIGHT", -4, 0)
        ilvl:SetJustifyH("RIGHT")
        ilvl:SetTextColor(0.50, 0.50, 0.55)
        row.ilvl = ilvl

        row:SetScript("OnEnter", function(self)
            if self._itemLink or self._itemId then
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                -- Use the full hyperlink (includes enchant/gem data) when available
                GameTooltip:SetHyperlink(self._itemLink or ("item:" .. self._itemId))
                GameTooltip:Show()
            end
        end)
        row:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)

        row:Hide()
        pickerRows[i] = row
    end

    f:SetScript("OnEnter", function() end)
    f:SetScript("OnLeave", function() end)
    f:SetScript("OnHide",  function(self) self._slotId = nil end)

    -- OnUpdate-based countdown timer (no C_Timer needed)
    pickerTimerFrame = CreateFrame("Frame", nil, UIParent)
    pickerTimerFrame:SetScript("OnUpdate", function(self, elapsed)
        if pickerHideCountdown > 0 then
            pickerHideCountdown = pickerHideCountdown - elapsed
            if pickerHideCountdown <= 0 then
                SC_HidePicker()
            end
        end
    end)

    picker = f
end

-- Parse enchant presence + gem count from a full item hyperlink.
-- Returns: enchanted (bool), gemCount (int)
-- NOTE: GetSpellInfo(enchantId) often returns crafting-recipe names in TBC Classic
-- (spell IDs collide), so we only report whether an enchant is present, not its name.
local function ParseEnchantGems(link)
    if not link then return false, 0 end
    local itemStr = link:match("|Hitem:([^|]+)|h")
    if not itemStr then return false, 0 end
    local parts = { strsplit(":", itemStr) }
    -- parts[1]=itemId  parts[2]=enchantId  parts[3..6]=gem slots
    local enchId   = tonumber(parts[2]) or 0
    local gemCount = 0
    for i = 3, 6 do
        if tonumber(parts[i] or "0") and tonumber(parts[i] or "0") > 0 then
            gemCount = gemCount + 1
        end
    end
    return enchId > 0, gemCount
end

function SC_ShowGearPicker(slotId)
    if not picker then SC_BuildPicker() end
    CancelPickerHide()
    picker._slotId = slotId

    local validTypes = SLOT_INVTYPES[slotId]
    if not validTypes then return end
    local currentId  = GetInventoryItemID("player", slotId)

    local items = {}
    -- Track IDs already shown as "Equipped" so we don't also list them in bags/swap.
    -- We do NOT dedup within bags — duplicate items in bags must all appear.
    local shownAsEquipped = {}

    -- Currently equipped
    if currentId then
        local link = GetInventoryItemLink("player", slotId)
        local n,_,q,ilvl,_,_,_,_,_,tex = GetItemInfo(currentId)
        if n then
            shownAsEquipped[currentId] = true
            items[#items+1] = {
                itemId=currentId, name=n, qual=q or 1,
                ilvl=ilvl or 0, tex=tex, equipped=true,
                src="Equipped", bag=-1, bslot=-1,
                link=link,
            }
        end
    end

    -- Bags 0-4: show ALL matching stacks including duplicates.
    -- Only skip the exact item currently equipped in this slot.
    for bag = 0, 4 do
        for bs = 1, _GetContainerNumSlots(bag) do
            local id = _GetContainerItemID(bag, bs)
            if id and not shownAsEquipped[id] then
                local bagLink = _GetItemLink(bag, bs)
                local n,_,q,ilvl,_,_,_,_,eqLoc,tex = GetItemInfo(id)
                if n and validTypes[eqLoc] then
                    items[#items+1] = {
                        itemId=id, name=n, qual=q or 1,
                        ilvl=ilvl or 0, tex=tex, equipped=false,
                        src="Bag", bag=bag, bslot=bs,
                        link=bagLink,
                    }
                end
            end
        end
    end

    -- Other equipped slots (swap candidates) — dedup by id only
    local seenSwap = {}
    for sid = 1, 19 do
        if sid ~= slotId then
            local id = GetInventoryItemID("player", sid)
            if id and not shownAsEquipped[id] and not seenSwap[id] then
                local swapLink = GetInventoryItemLink("player", sid)
                local n,_,q,ilvl,_,_,_,_,eqLoc,tex = GetItemInfo(id)
                if n and validTypes[eqLoc] then
                    seenSwap[id] = true
                    items[#items+1] = {
                        itemId=id, name=n, qual=q or 1,
                        ilvl=ilvl or 0, tex=tex, equipped=false,
                        src="Swap", bag=-1, bslot=-1, fromSlot=sid,
                        link=swapLink,
                    }
                end
            end
        end
    end

    -- Sort: equipped first, then ilvl descending
    table.sort(items, function(a, b)
        if a.equipped ~= b.equipped then return a.equipped end
        return (a.ilvl or 0) > (b.ilvl or 0)
    end)

    -- Slot name for title bar
    local slabel = "Slot " .. slotId
    for _,s in ipairs(LEFT_SLOTS)   do if s.id==slotId then slabel=s.label end end
    for _,s in ipairs(RIGHT_SLOTS)  do if s.id==slotId then slabel=s.label end end
    for _,s in ipairs(WEAPON_SLOTS) do if s.id==slotId then slabel=s.label end end
    picker.title:SetText(slabel)

    for i = 1, PICKER_MAX do pickerRows[i]:Hide() end

    local rowCount = 0
    if #items == 0 then
        local row = pickerRows[1]
        row._itemId   = nil
        row._itemLink = nil
        row.nm:SetText("|cff555555No matching items|r")
        row.sub:SetText("") ; row.ilvl:SetText("")
        row.icn:SetTexture("Interface\\PaperDoll\\UI-Backpack-EmptySlot")
        row.icn:SetTexCoord(0, 1, 0, 1)
        row.eqGlow:Hide()
        row:SetScript("OnClick", SC_HidePicker)
        row:Show() ; rowCount = 1
    else
        for i, item in ipairs(items) do
            if i > PICKER_MAX then break end
            local row = pickerRows[i]
            row._itemId   = item.itemId
            row._itemLink = item.link
            row._slotId   = slotId

            local qc = QUALITY_COLORS[item.qual] or QUALITY_COLORS[1]
            row.nm:SetText(string.format("|cff%02x%02x%02x%s|r",
                qc[1]*255, qc[2]*255, qc[3]*255, item.name))
            row.ilvl:SetText(item.ilvl > 0 and ("i"..item.ilvl) or "")

            -- Sub-line: source + enchant indicator + gem count
            local enchanted, gemCount = ParseEnchantGems(item.link)
            local subParts = {}
            if item.equipped then
                subParts[#subParts+1] = "|cffddbb22Equipped|r"
            elseif item.src == "Swap" then
                subParts[#subParts+1] = "|cff998866Swap|r"
            else
                subParts[#subParts+1] = "|cff555566Bag|r"
            end
            if enchanted then
                subParts[#subParts+1] = "|cff55aaffEnc|r"
            end
            if gemCount > 0 then
                subParts[#subParts+1] = string.format("|cff88dd88+%d gem%s|r",
                    gemCount, gemCount > 1 and "s" or "")
            end
            row.sub:SetText(table.concat(subParts, " "))

            if item.tex then
                row.icn:SetTexture(item.tex)
                row.icn:SetTexCoord(0.07, 0.93, 0.07, 0.93)
            else
                row.icn:SetTexture("Interface\\PaperDoll\\UI-Backpack-EmptySlot")
                row.icn:SetTexCoord(0, 1, 0, 1)
            end

            if item.equipped then
                row.eqGlow:Show()
            else
                row.eqGlow:Hide()
            end
            row.sub:SetTextColor(1, 1, 1)  -- allow inline color codes to show through

            local ci = item
            local cs = slotId
            row:SetScript("OnClick", function()
                GameTooltip:Hide()
                -- Guard: never equip if cursor is occupied or a spell is targeting
                if not ci.equipped and not GetCursorInfo() and not SpellIsTargeting() then
                    if cs == 0 then
                        -- Ammo slot: PickupInventoryItem(0) is not valid in TBC Anniversary.
                        -- Equip ammo by right-clicking the stack in the bag.
                        if ci.bag >= 0 then
                            local uc = C_Container and C_Container.UseContainerItem or UseContainerItem
                            uc(ci.bag, ci.bslot)
                        end
                    elseif ci.bag >= 0 then
                        -- Item in a bag: pick it up then swap into equip slot
                        _PickupContainerItem(ci.bag, ci.bslot)
                        PickupInventoryItem(cs)
                    elseif ci.fromSlot then
                        -- Item already in an equip slot: swap the two slots
                        PickupInventoryItem(ci.fromSlot)
                        PickupInventoryItem(cs)
                    end
                end
                SC_HidePicker()
            end)

            row:Show()
            rowCount = rowCount + 1
        end
    end

    local ch = rowCount * PICKER_ROW_H
    picker.content:SetHeight(ch)
    picker:SetHeight(22 + ch)

    -- Position at cursor (UIParent coords only -- safe across all strata)
    picker:ClearAllPoints()
    local cx, cy = GetCursorPosition()
    local sc     = UIParent:GetEffectiveScale()
    local ux     = cx / sc
    local uy     = cy / sc
    local sw     = GetScreenWidth()
    if ux + PICKER_W + 20 < sw then
        picker:SetPoint("TOPLEFT",  UIParent, "BOTTOMLEFT", ux + 16, uy + 10)
    else
        picker:SetPoint("TOPRIGHT", UIParent, "BOTTOMLEFT", ux - 16, uy + 10)
    end

    picker:Show()
    picker:Raise()
end

-- ============================================================
-- Slot button helpers
-- ============================================================
local function FillBg(f, r, g, b, a)
    local t = f:CreateTexture(nil, "BACKGROUND")
    t:SetAllPoints(f) ; t:SetColorTexture(r, g, b, a or 1)
    return t
end

-- ThemeFill: like FillBg but reads from the active SlyStyle theme palette and
-- registers an OnThemeChange listener so the texture repaints automatically.
-- Falls back to raw r,g,b,a values when SlyStyle is not installed.
local function ThemeFill(f, key, r, g, b, a)
    local t = f:CreateTexture(nil, "BACKGROUND")
    t:SetAllPoints(f)
    if SlyStyle then
        SlyStyle.Paint(t, key)
        SlyStyle.OnThemeChange(function() SlyStyle.Paint(t, key) end)
    else
        t:SetColorTexture(r, g, b, a or 1)
    end
    return t
end

-- ThemeTex: like ThemeFill but the caller sets point anchors manually.
local function ThemeTex(parent, key, layer, r, g, b, a)
    local t = parent:CreateTexture(nil, layer or "ARTWORK")
    if SlyStyle then
        SlyStyle.Paint(t, key)
        SlyStyle.OnThemeChange(function() SlyStyle.Paint(t, key) end)
    else
        t:SetColorTexture(r, g, b, a or 1)
    end
    return t
end

local function UpdateSlot(w, slotId)
    local tex = GetInventoryItemTexture("player", slotId)
    if tex then
        w.icon:SetTexture(tex)
        w.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        w.icon:SetVertexColor(1, 1, 1, 1)
        local qual = GetInventoryItemQuality("player", slotId)
        local qc   = QUALITY_COLORS[qual or 1] or QUALITY_COLORS[1]
        w.border:SetColorTexture(qc[1], qc[2], qc[3], 1)
    else
        w.icon:SetTexture("Interface\\PaperDoll\\UI-Backpack-EmptySlot")
        w.icon:SetTexCoord(0, 1, 0, 1)
        w.icon:SetVertexColor(0.28, 0.28, 0.28, 0.7)
        w.border:SetColorTexture(0.18, 0.18, 0.22, 0.9)
    end
end

local function BuildSlot(parent, slotId, label, x, y)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetSize(SLOT_S, SLOT_S)
    btn:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)

    local border = btn:CreateTexture(nil, "BACKGROUND")
    border:SetAllPoints(btn)
    border:SetColorTexture(0.18, 0.18, 0.22, 0.9)

    local slotBg = btn:CreateTexture(nil, "BORDER")
    slotBg:SetPoint("TOPLEFT",     btn, "TOPLEFT",      1, -1)
    slotBg:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -1,  1)
    slotBg:SetColorTexture(0.04, 0.04, 0.05, 1)

    local icon = btn:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("TOPLEFT",     btn, "TOPLEFT",      2, -2)
    icon:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -2,  2)
    icon:SetTexture("Interface\\PaperDoll\\UI-Backpack-EmptySlot")
    icon:SetTexCoord(0, 1, 0, 1)
    icon:SetVertexColor(0.28, 0.28, 0.28, 0.7)

    btn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        if GetInventoryItemTexture("player", slotId) then
            GameTooltip:SetInventoryItem("player", slotId)
            GameTooltip:AddLine("Left-click: swap gear", 0.5, 0.5, 0.5)
            GameTooltip:AddLine("Shift+click: socket gems", 0.5, 0.5, 0.5)
            GameTooltip:AddLine("Drag: move to trade/bank", 0.5, 0.5, 0.5)
        else
            GameTooltip:SetText(label, 0.65, 0.65, 0.65)
            GameTooltip:AddLine("Empty slot", 0.4, 0.4, 0.4)
        end
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    -- Drag OUT: lets the player drag equipped items to trade/bank/bags
    btn:RegisterForDrag("LeftButton")
    btn:SetScript("OnDragStart", function(self)
        -- Ammo slot (0): can't be dragged via PickupInventoryItem(0) in TBC Anniversary
        if slotId == 0 then return end
        -- Don't pick up while a weapon stone / spell is waiting for a target
        if SpellIsTargeting() or GetCursorInfo() then return end
        if IsInventoryItemLocked(slotId) then return end
        GameTooltip:Hide()
        SC_HidePicker()
        local ok = pcall(PickupInventoryItem, slotId)
        if ok then UpdateSlot(slotWidgets[slotId], slotId) end
    end)

    -- Drop ON: equip or apply whatever is on the cursor (dragged from bags/bank).
    -- Ammo slot (0): PickupInventoryItem(0) is invalid; ammo is equipped via the picker.
    btn:SetScript("OnReceiveDrag", function(self)
        if slotId == 0 then return end
        local ctype = GetCursorInfo()
        if not ctype then return end
        -- Only block a spell cursor if the slot is empty — you can't apply an
        -- enhancement to nothing, and an empty-slot click was likely accidental.
        -- Occupied slots allow any cursor type (kits / oils / stones / poisons).
        if ctype == "spell" and not GetInventoryItemTexture("player", slotId) then return end
        GameTooltip:Hide()
        local ok = pcall(PickupInventoryItem, slotId)
        if ok then UpdateSlot(slotWidgets[slotId], slotId) end
    end)

    btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    btn:SetScript("OnClick", function(self, mb)
        if mb == "LeftButton" then
            GameTooltip:Hide()
            -- Shift+click: open gem socketing UI if the slot has an item
            if IsShiftKeyDown() then
                if GetInventoryItemTexture("player", slotId) then
                    SC_HidePicker()
                    SocketInventoryItem(slotId)
                end
                return
            end
            -- If targeting/cursor is active and this slot has a secure overlay,
            -- sBtn already handled the click via the "/use N" secure macro.
            -- Bail here so we don't attempt the restricted PickupInventoryItem path.
            if slotId ~= 0 and _secureSlots[slotId] and
               (SpellIsTargeting() or GetCursorInfo()) then return end

            -- Fallback for slots without a secure overlay (ammo slot 0, or any
            -- future slot not in EQUIP_SLOT_IDS).  Outside combat lockdown this
            -- is sometimes callable via OnReceiveDrag hardware path, but for
            -- safety we only attempt it for truly unsecured slots.
            local ctype = GetCursorInfo()
            if ctype and slotId == 0 then
                -- Ammo slot: no sBtn, try direct path
                local ok = pcall(PickupInventoryItem, slotId)
                if ok then UpdateSlot(slotWidgets[slotId], slotId) end
                return
            end
            -- Toggle picker
            if picker and picker:IsShown() and picker._slotId == slotId then
                SC_HidePicker()
            else
                SC_ShowGearPicker(slotId)
            end
        elseif mb == "RightButton" then
            local link = GetInventoryItemLink("player", slotId)
            if link and ChatFrame1EditBox then
                ChatFrame1EditBox:Show()
                ChatFrame1EditBox:SetText(link)
                ChatFrame1EditBox:SetFocus()
            end
        end
    end)

    -- Secure overlay for enchant/cursor/SpellIsTargeting application.
    -- "/use N" via SecureActionButtonTemplate is the ONLY valid way to call
    -- UseInventoryItem from addon code in TBC Anniversary (PickupInventoryItem
    -- is permanently restricted to Blizzard-signed UI).  "/use N" resolves:
    --   SpellIsTargeting() = true  → applies pending spell onto item in slot N
    --   GetCursorInfo() = "item"   → equips cursor item to slot N (swap)
    --   GetCursorInfo() = "enchant"→ applies cursor enchant to item in slot N
    -- Enabled only while targeting/cursor is active (_targetMonitor above).
    if EQUIP_SLOT_IDS[slotId] then
        local sBtn = CreateFrame("Button", nil, btn, "SecureActionButtonTemplate")
        sBtn:SetAllPoints(btn)
        sBtn:SetAttribute("type", "macro")
        sBtn:SetAttribute("macrotext", "/use " .. slotId)
        sBtn:RegisterForClicks("LeftButtonUp")
        -- Explicitly raise frame level so sBtn sits above btn and wins the
        -- mouse-hit test when both are enabled at the same screen position.
        sBtn:SetFrameLevel(btn:GetFrameLevel() + 20)
        sBtn:EnableMouse(false)
        _secureSlots[slotId] = sBtn
    end

    local w = {frame=btn, icon=icon, border=border}
    slotWidgets[slotId] = w
    return w
end

function SC_RefreshSlots()
    for sid, w in pairs(slotWidgets) do
        UpdateSlot(w, sid)
    end
end

-- ============================================================
-- Header
-- ============================================================
local function RefreshHeader()
    if not headerName then return end
    local name   = UnitName("player") or "Unknown"
    local level  = UnitLevel("player") or 0
    local race   = UnitRace("player") or ""
    local _, cls = UnitClass("player")
    local cc     = (cls and CLASS_COLORS[cls]) or {1,1,1}
    headerName:SetFormattedText("|cff%02x%02x%02x%s|r",
        cc[1]*255, cc[2]*255, cc[3]*255, name)
    headerInfo:SetFormattedText("Level %d  %s  %s",
        level, race, cls and (cls:sub(1,1)..cls:sub(2):lower()) or "")
    if headerGS then
        local gs = GS_GetTotalScore and GS_GetTotalScore() or 0
        if gs > 0 then
            headerGS:SetFormattedText("GS: %d", gs)
        else
            headerGS:SetText("|cff666666GS: --  |r")
        end
    end
end

-- ============================================================
-- Stats tab
-- ============================================================
local function BuildStatRows(parent)
    for i = 1, MAX_STAT_ROWS do
        local row = CreateFrame("Button", nil, parent)
        row:SetSize(SIDE_W - PAD*2 - 16, 24)
        row:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -((i-1)*24))

        local lbl = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        lbl:SetFont(lbl:GetFont(), 12, "")
        lbl:SetPoint("LEFT", row, "LEFT", 0, 0)
        lbl:SetJustifyH("LEFT")
        lbl:SetWidth((SIDE_W - PAD*2 - 16) * 0.60)

        local val = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        val:SetFont(val:GetFont(), 12, "")
        val:SetPoint("RIGHT", row, "RIGHT", 0, 0)
        val:SetJustifyH("RIGHT")

        row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        row:Hide()
        statRows[i] = {row=row, lbl=lbl, val=val}
    end
end

function SC_RefreshStats()
    for _, w in ipairs(statRows) do
        w.row:Hide()
        w.lbl:SetText("")
        w.val:SetText("")
        w.row:SetScript("OnClick", nil)
        w.row:SetScript("OnEnter", nil)
        w.row:SetScript("OnLeave", nil)
        w.row:EnableMouse(false)
    end
    local ri = 0
    local currentSection = nil
    local collapsed = SC.db and SC.db.collapsed or {}
    local hidden    = SC.db and SC.db.hidden    or {}
    local hiddenCount = 0

    local function addSection(secKey)
        currentSection = secKey
        if hidden[secKey] then
            hiddenCount = hiddenCount + 1
            return
        end
        ri = ri + 1
        local w = statRows[ri]
        if not w then return end
        local arrow = collapsed[secKey] and "[+] " or "[-] "
        w.lbl:SetText("|cffaaaaaa" .. arrow .. "|r|cff66d4ff" .. secKey .. "|r")
        w.val:SetText("")
        w.row:EnableMouse(true)
        w.row:SetScript("OnClick", function(self, btn)
            if btn == "RightButton" then
                hidden[secKey] = true
                SC_RefreshStats()
            else
                if collapsed[secKey] then
                    collapsed[secKey] = nil
                else
                    collapsed[secKey] = true
                end
                SC_RefreshStats()
            end
        end)
        w.row:SetScript("OnEnter", function()
            local arr = collapsed[secKey] and "[+] " or "[-] "
            w.lbl:SetText("|cffaaaaaa" .. arr .. "|r|cffffffff" .. secKey .. "|r")
            w.val:SetText("|cff666666right-click: hide|r")
        end)
        w.row:SetScript("OnLeave", function()
            local arr = collapsed[secKey] and "[+] " or "[-] "
            w.lbl:SetText("|cffaaaaaa" .. arr .. "|r|cff66d4ff" .. secKey .. "|r")
            w.val:SetText("")
        end)
        w.row:Show()
    end

    local function addRow(lbl, val)
        if currentSection and (collapsed[currentSection] or hidden[currentSection]) then return end
        ri = ri + 1
        local w = statRows[ri]
        if not w then return end
        w.lbl:SetText("|cffbbbbbb" .. lbl .. "|r")
        w.val:SetText("|cffffd700" .. (val or "n/a") .. "|r")
        w.row:Show()
    end

    addSection("BASE STATS")
    local NAMES = {"Strength","Agility","Stamina","Intellect","Spirit"}
    for i = 1, 5 do
        local base, pos, neg = UnitStat("player", i)
        addRow(NAMES[i], tostring((base or 0)+(pos or 0)-(neg or 0)))
    end
    addRow("Armor", tostring(UnitArmor("player") or 0))

    if ECS_GetStats then
        local ok, stats = pcall(ECS_GetStats)
        if ok and stats then
            local lastSec = nil
            for _, s in ipairs(stats) do
                if s.section and s.section ~= lastSec then
                    addSection(s.section)
                    lastSec = s.section
                end
                if s.label then addRow(s.label, s.value) end
            end
        end
    end

    -- Footer: show hidden count + click to restore all
    if hiddenCount > 0 then
        ri = ri + 1
        local w = statRows[ri]
        if w then
            local txt = "|cffff9900" .. hiddenCount .. " section(s) hidden  [click to show all]|r"
            w.lbl:SetText(txt)
            w.val:SetText("")
            w.row:EnableMouse(true)
            w.row:SetScript("OnClick", function()
                SC.db.hidden = {}
                SC_RefreshStats()
            end)
            w.row:SetScript("OnEnter", function()
                w.lbl:SetText("|cffffffff" .. hiddenCount .. " section(s) hidden  [click to show all]|r")
            end)
            w.row:SetScript("OnLeave", function()
                w.lbl:SetText(txt)
            end)
            w.row:Show()
        end
    end
end

-- ============================================================
-- Set Icon Picker
-- ============================================================
local IPICK_COLS  = 5
local IPICK_ROWS  = 5
local IPICK_PAGE  = IPICK_COLS * IPICK_ROWS   -- 25 icons per page
local IPICK_ICO_S = 30
local IPICK_GAP   = 2
local IPICK_PAD   = 6
local IPICK_HDR_H = 26
local IPICK_FOT_H = 26
local IPICK_W     = IPICK_COLS*(IPICK_ICO_S+IPICK_GAP) - IPICK_GAP + IPICK_PAD*2

local iconPickerFrame  = nil
local iconPickerTarget = nil
local iconBtnPool      = {}
local iconList         = {}
local iconCurrentPage  = 1

local STATIC_SET_ICONS = {
    -- ── Warrior ──────────────────────────────────────────────────────────────
    "Interface\\Icons\\Ability_Warrior_BattleShout",
    "Interface\\Icons\\Ability_Warrior_BerserkerRage",
    "Interface\\Icons\\Ability_Warrior_BerserkerStance",
    "Interface\\Icons\\Ability_Warrior_Charge",
    "Interface\\Icons\\Ability_Warrior_Cleave",
    "Interface\\Icons\\Ability_Warrior_DefensiveStance",
    "Interface\\Icons\\Ability_Warrior_DemoralizingShout",
    "Interface\\Icons\\Ability_Warrior_Disarm",
    "Interface\\Icons\\Ability_Warrior_Execute",
    "Interface\\Icons\\Ability_Warrior_Hamstring",
    "Interface\\Icons\\Ability_Warrior_InnerRage",
    "Interface\\Icons\\Ability_Warrior_Intimidatingshout",
    "Interface\\Icons\\Ability_Warrior_MortalStrike",
    "Interface\\Icons\\Ability_Warrior_OffensiveStance",
    "Interface\\Icons\\Ability_Warrior_Overpower",
    "Interface\\Icons\\Ability_Warrior_PiercingHowl",
    "Interface\\Icons\\Ability_Warrior_Rend",
    "Interface\\Icons\\Ability_Warrior_Revenge",
    "Interface\\Icons\\Ability_Warrior_Riposte",
    "Interface\\Icons\\Ability_Warrior_ShieldBash",
    "Interface\\Icons\\Ability_Warrior_ShieldBlock",
    "Interface\\Icons\\Ability_Warrior_ShieldWall",
    "Interface\\Icons\\Ability_Warrior_SpellReflection",
    "Interface\\Icons\\Ability_Warrior_Sunder",
    "Interface\\Icons\\Ability_Warrior_Sunderarmor",
    "Interface\\Icons\\Ability_Warrior_Trauma",
    "Interface\\Icons\\Ability_Warrior_Whirlwind",
    "Interface\\Icons\\Ability_Warrior_StrategicCharge",
    "Interface\\Icons\\Ability_Warrior_PunishingBlow",
    "Interface\\Icons\\Ability_DualWield",
    -- ── Paladin ──────────────────────────────────────────────────────────────
    "Interface\\Icons\\Ability_Paladin_HolyBolt",
    "Interface\\Icons\\Ability_Paladin_HolyShock",
    "Interface\\Icons\\Ability_Paladin_DivineSacrifice",
    "Interface\\Icons\\Ability_Paladin_DivineLight",
    "Interface\\Icons\\Ability_Paladin_JudgementofCommand",
    "Interface\\Icons\\Ability_Paladin_JudgementofLight",
    "Interface\\Icons\\Ability_Paladin_JudgementofWisdom",
    "Interface\\Icons\\Ability_Paladin_LayOnHands",
    "Interface\\Icons\\Ability_Paladin_SealOfCommand",
    "Interface\\Icons\\Ability_Paladin_SealOfWisdom",
    "Interface\\Icons\\Ability_Paladin_ShieldOfLight",
    -- ── Hunter ───────────────────────────────────────────────────────────────
    "Interface\\Icons\\Ability_Hunter_AimedShot",
    "Interface\\Icons\\Ability_Hunter_BeastCall",
    "Interface\\Icons\\Ability_Hunter_BeastTraining",
    "Interface\\Icons\\Ability_Hunter_ChimeraShot",
    "Interface\\Icons\\Ability_Hunter_CompanionshipTalent",
    "Interface\\Icons\\Ability_Hunter_CriticalShot",
    "Interface\\Icons\\Ability_Hunter_DistractingShot",
    "Interface\\Icons\\Ability_Hunter_ElementalArrow",
    "Interface\\Icons\\Ability_Hunter_ExplosiveTrap",
    "Interface\\Icons\\Ability_Hunter_FreezingTrap",
    "Interface\\Icons\\Ability_Hunter_ImmolationTrap",
    "Interface\\Icons\\Ability_Hunter_Mastermarksman",
    "Interface\\Icons\\Ability_Hunter_MultiShot",
    "Interface\\Icons\\Ability_Hunter_PetBash",
    "Interface\\Icons\\Ability_Hunter_RapidKilling",
    "Interface\\Icons\\Ability_Hunter_ScatterShot",
    "Interface\\Icons\\Ability_Hunter_SniperShot",
    "Interface\\Icons\\Ability_Hunter_SteadyShot",
    "Interface\\Icons\\Ability_Hunter_TrueshotAura",
    "Interface\\Icons\\Ability_Hunter_Wyvern",
    -- ── Rogue ────────────────────────────────────────────────────────────────
    "Interface\\Icons\\Ability_Rogue_Ambush",
    "Interface\\Icons\\Ability_Rogue_Backstab",
    "Interface\\Icons\\Ability_Rogue_BladeFlurry",
    "Interface\\Icons\\Ability_Rogue_CheapShot",
    "Interface\\Icons\\Ability_Rogue_Deadliness",
    "Interface\\Icons\\Ability_Rogue_Evasion",
    "Interface\\Icons\\Ability_Rogue_Eviscerate",
    "Interface\\Icons\\Ability_Rogue_GaugePoison",
    "Interface\\Icons\\Ability_Rogue_HemorragingStrike",
    "Interface\\Icons\\Ability_Rogue_KidneyShot",
    "Interface\\Icons\\Ability_Rogue_MasterOfSubtlety",
    "Interface\\Icons\\Ability_Rogue_Mutilate",
    "Interface\\Icons\\Ability_Rogue_NervesOfSteel",
    "Interface\\Icons\\Ability_Rogue_Preparation",
    "Interface\\Icons\\Ability_Rogue_RuptureCripple",
    "Interface\\Icons\\Ability_Rogue_Shadowstrikes",
    "Interface\\Icons\\Ability_Rogue_Sliceanddice",
    "Interface\\Icons\\Ability_Rogue_Sprint",
    "Interface\\Icons\\Ability_Rogue_SuicidalInstincts",
    "Interface\\Icons\\Ability_Rogue_Vanish",
    -- ── Priest ───────────────────────────────────────────────────────────────
    "Interface\\Icons\\Spell_Holy_Dispel",
    "Interface\\Icons\\Spell_Holy_Exorcism",
    "Interface\\Icons\\Spell_Holy_Exorcism_02",
    "Interface\\Icons\\Spell_Holy_FistOfJustice",
    "Interface\\Icons\\Spell_Holy_FlashHeal",
    "Interface\\Icons\\Spell_Holy_Forgiveness",
    "Interface\\Icons\\Spell_Holy_GreaterHeal",
    "Interface\\Icons\\Spell_Holy_GuardianSpirit",
    "Interface\\Icons\\Spell_Holy_Heal02",
    "Interface\\Icons\\Spell_Holy_HolySmite",
    "Interface\\Icons\\Spell_Holy_InnerFire",
    "Interface\\Icons\\Spell_Holy_LayOnHands",
    "Interface\\Icons\\Spell_Holy_MindSooth",
    "Interface\\Icons\\Spell_Holy_NovaBurst",
    "Interface\\Icons\\Spell_Holy_Penance",
    "Interface\\Icons\\Spell_Holy_PowerWordFortitude",
    "Interface\\Icons\\Spell_Holy_PowerWordShield",
    "Interface\\Icons\\Spell_Holy_PrayerOfHealing02",
    "Interface\\Icons\\Spell_Holy_Renew",
    "Interface\\Icons\\Spell_Holy_ReviveChampion",
    "Interface\\Icons\\Spell_Holy_SealOfSacrifice",
    "Interface\\Icons\\Spell_Holy_SealOfValor",
    "Interface\\Icons\\Spell_Holy_SenseUndead",
    "Interface\\Icons\\Spell_Holy_TurnAlt",
    "Interface\\Icons\\Spell_Holy_TurnEvil",
    "Interface\\Icons\\Spell_Holy_UnyieldingFaith",
    "Interface\\Icons\\Spell_Holy_WordOfRecall",
    -- ── Shaman ───────────────────────────────────────────────────────────────
    "Interface\\Icons\\Ability_Shaman_AstralShift",
    "Interface\\Icons\\Ability_Shaman_ElementalMastery",
    "Interface\\Icons\\Ability_Shaman_FocusedStrikes",
    "Interface\\Icons\\Ability_Shaman_HeraldOfTheElements",
    "Interface\\Icons\\Ability_Shaman_Improvedghostolf",
    "Interface\\Icons\\Ability_Shaman_ManaSpring",
    "Interface\\Icons\\Ability_Shaman_MasteryOfElements",
    "Interface\\Icons\\Ability_Shaman_ThunderBolt",
    "Interface\\Icons\\Ability_Shaman_TotemDrop",
    "Interface\\Icons\\Ability_Shaman_WindfuryTotem",
    "Interface\\Icons\\Spell_Nature_ElementalShields",
    "Interface\\Icons\\Spell_Nature_EarthbindTotem",
    "Interface\\Icons\\Spell_Nature_FlameShield",
    "Interface\\Icons\\Spell_Nature_FreezingTrap",
    "Interface\\Icons\\Spell_Nature_GroundingTotem",
    "Interface\\Icons\\Spell_Nature_HealingTouch",
    "Interface\\Icons\\Spell_Nature_LightningShield",
    "Interface\\Icons\\Spell_Nature_LightningBolt",
    "Interface\\Icons\\Spell_Nature_MagicImmunity",
    "Interface\\Icons\\Spell_Nature_NatureGuardian",
    "Interface\\Icons\\Spell_Nature_Purge",
    "Interface\\Icons\\Spell_Nature_RemovePoison",
    "Interface\\Icons\\Spell_Nature_SkinofEarth",
    "Interface\\Icons\\Spell_Nature_SlowingTotem",
    "Interface\\Icons\\Spell_Nature_SpiritArmor",
    "Interface\\Icons\\Spell_Nature_StormReach",
    "Interface\\Icons\\Spell_Nature_Thunderclap",
    "Interface\\Icons\\Spell_Nature_TransformDenmother",
    "Interface\\Icons\\Spell_Nature_UndyingWill",
    "Interface\\Icons\\Spell_Nature_WispSplode",
    -- ── Mage ─────────────────────────────────────────────────────────────────
    "Interface\\Icons\\Ability_Mage_ArcaneMissiles",
    "Interface\\Icons\\Ability_Mage_ArcaneConcentration",
    "Interface\\Icons\\Ability_Mage_ArcanePotency",
    "Interface\\Icons\\Ability_Mage_Arcanesubtlety",
    "Interface\\Icons\\Ability_Mage_FocusMagic",
    "Interface\\Icons\\Ability_Mage_Frostjaw",
    "Interface\\Icons\\Ability_Mage_FrostWarding",
    "Interface\\Icons\\Ability_Mage_Torment",
    "Interface\\Icons\\Spell_Arcane_ArcanePower",
    "Interface\\Icons\\Spell_Arcane_Blink",
    "Interface\\Icons\\Spell_Arcane_ExplosiveBlast",
    "Interface\\Icons\\Spell_Arcane_InnerFire",
    "Interface\\Icons\\Spell_Arcane_MagicMappingTotem",
    "Interface\\Icons\\Spell_Arcane_MindMastery",
    "Interface\\Icons\\Spell_Arcane_Missiles",
    "Interface\\Icons\\Spell_Arcane_PortalDalaran",
    "Interface\\Icons\\Spell_Arcane_PortalIronforge",
    "Interface\\Icons\\Spell_Arcane_PortalOrgrimmar",
    "Interface\\Icons\\Spell_Arcane_PortalStormwind",
    "Interface\\Icons\\Spell_Arcane_PresenceOfMind",
    "Interface\\Icons\\Spell_Arcane_Prismaticcloak",
    "Interface\\Icons\\Spell_Arcane_RuneOfPower",
    "Interface\\Icons\\Spell_Arcane_Slow",
    "Interface\\Icons\\Spell_Arcane_StarFire",
    "Interface\\Icons\\Spell_Arcane_TimeWarp",
    "Interface\\Icons\\Spell_Fire_Fireball",
    "Interface\\Icons\\Spell_Fire_Fireball02",
    "Interface\\Icons\\Spell_Fire_FireBolt02",
    "Interface\\Icons\\Spell_Fire_BlazingFire",
    "Interface\\Icons\\Spell_Fire_Burnout",
    "Interface\\Icons\\Spell_Fire_CharmTotem",
    "Interface\\Icons\\Spell_Fire_DemonicPower",
    "Interface\\Icons\\Spell_Fire_FireArrow",
    "Interface\\Icons\\Spell_Fire_Flamebolt",
    "Interface\\Icons\\Spell_Fire_FlameBolt",
    "Interface\\Icons\\Spell_Fire_FlameTongueWeapon",
    "Interface\\Icons\\Spell_Fire_FireShield",
    "Interface\\Icons\\Spell_Fire_Flare",
    "Interface\\Icons\\Spell_Fire_Incinerate",
    "Interface\\Icons\\Spell_Fire_MoltenBlood",
    "Interface\\Icons\\Spell_Fire_MeteorStorm",
    "Interface\\Icons\\Spell_Fire_Scorch",
    "Interface\\Icons\\Spell_Fire_SoulFirePortal",
    "Interface\\Icons\\Spell_Frost_FrostNova",
    "Interface\\Icons\\Spell_Frost_FrostBolt02",
    "Interface\\Icons\\Spell_Frost_Freeze",
    "Interface\\Icons\\Spell_Frost_Glacial",
    "Interface\\Icons\\Spell_Frost_FrostShield",
    "Interface\\Icons\\Spell_Frost_IceFloes",
    "Interface\\Icons\\Spell_Frost_IceLance",
    "Interface\\Icons\\Spell_Frost_Iceblock",
    "Interface\\Icons\\Spell_Frost_SummonWaterElemental",
    "Interface\\Icons\\Spell_Frost_WaterJet",
    -- ── Warlock ──────────────────────────────────────────────────────────────
    "Interface\\Icons\\Ability_Warlock_ChaosBolt",
    "Interface\\Icons\\Ability_Warlock_CreateHealthstone_Minor",
    "Interface\\Icons\\Ability_Warlock_DemonicCircle_Summon",
    "Interface\\Icons\\Ability_Warlock_EradicateSouls",
    "Interface\\Icons\\Ability_Warlock_EyeOfKilrogg",
    "Interface\\Icons\\Ability_Warlock_FelArmor",
    "Interface\\Icons\\Ability_Warlock_Hellfire1",
    "Interface\\Icons\\Ability_Warlock_ImprovedShadowBolt",
    "Interface\\Icons\\Ability_Warlock_LifeTap",
    "Interface\\Icons\\Ability_Warlock_SoulLink",
    "Interface\\Icons\\Ability_Warlock_UnstableAffliction",
    "Interface\\Icons\\Spell_Shadow_Cripple",
    "Interface\\Icons\\Spell_Shadow_Curse",
    "Interface\\Icons\\Spell_Shadow_DemonForm",
    "Interface\\Icons\\Spell_Shadow_Doom",
    "Interface\\Icons\\Spell_Shadow_Drain",
    "Interface\\Icons\\Spell_Shadow_FocusShadow",
    "Interface\\Icons\\Spell_Shadow_MindBomb",
    "Interface\\Icons\\Spell_Shadow_MindFlay",
    "Interface\\Icons\\Spell_Shadow_Possession",
    "Interface\\Icons\\Spell_Shadow_PsychicScream",
    "Interface\\Icons\\Spell_Shadow_RainOfFire",
    "Interface\\Icons\\Spell_Shadow_SeedOfCorruption",
    "Interface\\Icons\\Spell_Shadow_ShadowBolt",
    "Interface\\Icons\\Spell_Shadow_ShadowShock",
    "Interface\\Icons\\Spell_Shadow_ShadowWordDominate",
    "Interface\\Icons\\Spell_Shadow_ShadowWordPain",
    "Interface\\Icons\\Spell_Shadow_Silence",
    "Interface\\Icons\\Spell_Shadow_SoulLeech_3",
    "Interface\\Icons\\Spell_Shadow_Unholyfrenzy",
    "Interface\\Icons\\Spell_Shadow_VampiricEmbrace",
    -- ── Druid ────────────────────────────────────────────────────────────────
    "Interface\\Icons\\Ability_Druid_Bash",
    "Interface\\Icons\\Ability_Druid_CatForm",
    "Interface\\Icons\\Ability_Druid_FaerieFire",
    "Interface\\Icons\\Ability_Druid_Flourish",
    "Interface\\Icons\\Ability_Druid_Growl",
    "Interface\\Icons\\Ability_Druid_HarmonicGrove",
    "Interface\\Icons\\Ability_Druid_Languish",
    "Interface\\Icons\\Ability_Druid_Lacerate",
    "Interface\\Icons\\Ability_Druid_Maul",
    "Interface\\Icons\\Ability_Druid_MoonfireSpam",
    "Interface\\Icons\\Ability_Druid_Moonfire",
    "Interface\\Icons\\Ability_Druid_NaturalFury",
    "Interface\\Icons\\Ability_Druid_NaturalReaction",
    "Interface\\Icons\\Ability_Druid_OwlkinFrenzy",
    "Interface\\Icons\\Ability_Druid_Primaltenacity",
    "Interface\\Icons\\Ability_Druid_PredatoryInstincts",
    "Interface\\Icons\\Ability_Druid_Prowl",
    "Interface\\Icons\\Ability_Druid_Rake",
    "Interface\\Icons\\Ability_Druid_Ravage",
    "Interface\\Icons\\Ability_Druid_Rip",
    "Interface\\Icons\\Ability_Druid_SkinBark",
    "Interface\\Icons\\Ability_Druid_Starfall",
    "Interface\\Icons\\Ability_Druid_StarlightWrath",
    "Interface\\Icons\\Ability_Druid_SummonBear",
    "Interface\\Icons\\Ability_Druid_Swipe",
    "Interface\\Icons\\Ability_Druid_ThrashBear",
    "Interface\\Icons\\Ability_Druid_TigersFury",
    "Interface\\Icons\\Ability_Druid_TreeofLife",
    "Interface\\Icons\\Ability_Druid_TravelForm",
    "Interface\\Icons\\Ability_Druid_WildGrowth",
    "Interface\\Icons\\Spell_Nature_HealingTouch",
    "Interface\\Icons\\Spell_Nature_HolyStrike",
    "Interface\\Icons\\Spell_Nature_Insect_Swarm",
    "Interface\\Icons\\Spell_Nature_LifeRegeneration",
    "Interface\\Icons\\Spell_Nature_MoonFire",
    "Interface\\Icons\\Spell_Nature_Rejuvenation",
    "Interface\\Icons\\Spell_Nature_Regrowth",
    "Interface\\Icons\\Spell_Nature_Starfall",
    "Interface\\Icons\\Spell_Nature_WispHeal",
    "Interface\\Icons\\Spell_Nature_Wraith",
    -- ── Death Knight (avail as icons even if class added later) ───────────────
    "Interface\\Icons\\Spell_Deathknight_ArmyOfTheDead",
    "Interface\\Icons\\Spell_Deathknight_BloodBoil",
    "Interface\\Icons\\Spell_Deathknight_BloodPresence",
    "Interface\\Icons\\Spell_Deathknight_BloodTap",
    "Interface\\Icons\\Spell_Deathknight_DeathCoil",
    "Interface\\Icons\\Spell_Deathknight_DeathGrip",
    "Interface\\Icons\\Spell_Deathknight_DeathStrike",
    "Interface\\Icons\\Spell_Deathknight_FrostPresence",
    "Interface\\Icons\\Spell_Deathknight_HowlingBlast",
    "Interface\\Icons\\Spell_Deathknight_IcyTouch",
    "Interface\\Icons\\Spell_Deathknight_PlagueStrike",
    "Interface\\Icons\\Spell_Deathknight_RuneTap",
    "Interface\\Icons\\Spell_Deathknight_ScourgeStrike",
    "Interface\\Icons\\Spell_Deathknight_UnholyPresence",
    -- ── Holy / Devotion ──────────────────────────────────────────────────────
    "Interface\\Icons\\Spell_Holy_Consecration",
    "Interface\\Icons\\Spell_Holy_CrusaderAura",
    "Interface\\Icons\\Spell_Holy_Devotion",
    "Interface\\Icons\\Spell_Holy_EqualPerfection",
    "Interface\\Icons\\Spell_Holy_HolyBolt",
    "Interface\\Icons\\Spell_Holy_ResurrectionAura",
    "Interface\\Icons\\Spell_Holy_RighteousFury",
    "Interface\\Icons\\Spell_Holy_Smite",
    -- ── Swords ───────────────────────────────────────────────────────────────
    "Interface\\Icons\\INV_Sword_01",
    "Interface\\Icons\\INV_Sword_02",
    "Interface\\Icons\\INV_Sword_04",
    "Interface\\Icons\\INV_Sword_05",
    "Interface\\Icons\\INV_Sword_06",
    "Interface\\Icons\\INV_Sword_09",
    "Interface\\Icons\\INV_Sword_12",
    "Interface\\Icons\\INV_Sword_16",
    "Interface\\Icons\\INV_Sword_17",
    "Interface\\Icons\\INV_Sword_20",
    "Interface\\Icons\\INV_Sword_23",
    "Interface\\Icons\\INV_Sword_27",
    "Interface\\Icons\\INV_Sword_29",
    "Interface\\Icons\\INV_Sword_36",
    "Interface\\Icons\\INV_Sword_39",
    "Interface\\Icons\\INV_Sword_40",
    "Interface\\Icons\\INV_Sword_49",
    "Interface\\Icons\\INV_Sword_63",
    -- ── Axes ─────────────────────────────────────────────────────────────────
    "Interface\\Icons\\INV_Axe_01",
    "Interface\\Icons\\INV_Axe_02",
    "Interface\\Icons\\INV_Axe_06",
    "Interface\\Icons\\INV_Axe_07",
    "Interface\\Icons\\INV_Axe_09",
    "Interface\\Icons\\INV_Axe_10",
    "Interface\\Icons\\INV_Axe_12",
    "Interface\\Icons\\INV_Axe_13",
    "Interface\\Icons\\INV_Axe_21",
    "Interface\\Icons\\INV_Axe_22",
    "Interface\\Icons\\INV_Axe_23",
    "Interface\\Icons\\INV_Axe_26",
    "Interface\\Icons\\INV_Axe_29",
    "Interface\\Icons\\INV_Axe_30",
    "Interface\\Icons\\INV_Axe_35",
    -- ── Maces ────────────────────────────────────────────────────────────────
    "Interface\\Icons\\INV_Mace_01",
    "Interface\\Icons\\INV_Mace_05",
    "Interface\\Icons\\INV_Mace_07",
    "Interface\\Icons\\INV_Mace_08",
    "Interface\\Icons\\INV_Mace_13",
    "Interface\\Icons\\INV_Mace_14",
    "Interface\\Icons\\INV_Mace_15",
    "Interface\\Icons\\INV_Mace_19",
    "Interface\\Icons\\INV_Mace_24",
    "Interface\\Icons\\INV_Mace_29",
    "Interface\\Icons\\INV_Mace_36",
    "Interface\\Icons\\INV_Mace_37",
    -- ── Staves ───────────────────────────────────────────────────────────────
    "Interface\\Icons\\INV_Staff_06",
    "Interface\\Icons\\INV_Staff_08",
    "Interface\\Icons\\INV_Staff_13",
    "Interface\\Icons\\INV_Staff_15",
    "Interface\\Icons\\INV_Staff_16",
    "Interface\\Icons\\INV_Staff_18",
    "Interface\\Icons\\INV_Staff_20",
    "Interface\\Icons\\INV_Staff_21",
    "Interface\\Icons\\INV_Staff_22",
    "Interface\\Icons\\INV_Staff_30",
    "Interface\\Icons\\INV_Staff_36",
    -- ── Daggers / Short Blades ───────────────────────────────────────────────
    "Interface\\Icons\\INV_Weapon_ShortBlade_01",
    "Interface\\Icons\\INV_Weapon_ShortBlade_02",
    "Interface\\Icons\\INV_Weapon_ShortBlade_04",
    "Interface\\Icons\\INV_Weapon_ShortBlade_05",
    "Interface\\Icons\\INV_Weapon_ShortBlade_07",
    "Interface\\Icons\\INV_Weapon_ShortBlade_10",
    "Interface\\Icons\\INV_Dagger_07",
    "Interface\\Icons\\INV_Dagger_09",
    "Interface\\Icons\\INV_Dagger_13",
    "Interface\\Icons\\INV_Dagger_14",
    "Interface\\Icons\\INV_Dagger_17",
    -- ── Ranged ───────────────────────────────────────────────────────────────
    "Interface\\Icons\\INV_Weapon_Bow_01",
    "Interface\\Icons\\INV_Weapon_Bow_02",
    "Interface\\Icons\\INV_Weapon_Bow_07",
    "Interface\\Icons\\INV_Weapon_Bow_11",
    "Interface\\Icons\\INV_Weapon_Bow_12",
    "Interface\\Icons\\INV_Weapon_Crossbow_01",
    "Interface\\Icons\\INV_Weapon_Crossbow_05",
    "Interface\\Icons\\INV_Weapon_Rifle_01",
    "Interface\\Icons\\INV_Weapon_Rifle_04",
    "Interface\\Icons\\INV_Weapon_Thrown_08",
    "Interface\\Icons\\INV_Spear_04",
    "Interface\\Icons\\INV_Spear_06",
    "Interface\\Icons\\INV_Spear_07",
    "Interface\\Icons\\INV_ThrowingKnife_02",
    "Interface\\Icons\\INV_ThrowingKnife_06",
    -- ── Polearms / Fist ──────────────────────────────────────────────────────
    "Interface\\Icons\\INV_Weapon_Glave_01",
    "Interface\\Icons\\INV_Weapon_Halberd_01",
    "Interface\\Icons\\INV_Weapon_HalberdPolearm_01",
    "Interface\\Icons\\INV_Gauntlets_4",
    "Interface\\Icons\\INV_Gauntlets_07",
    "Interface\\Icons\\INV_Gauntlets_08",
    -- ── Shields ──────────────────────────────────────────────────────────────
    "Interface\\Icons\\INV_Shield_01",
    "Interface\\Icons\\INV_Shield_04",
    "Interface\\Icons\\INV_Shield_06",
    "Interface\\Icons\\INV_Shield_07",
    "Interface\\Icons\\INV_Shield_09",
    "Interface\\Icons\\INV_Shield_12",
    "Interface\\Icons\\INV_Shield_16",
    "Interface\\Icons\\INV_Shield_17",
    "Interface\\Icons\\INV_Shield_25",
    "Interface\\Icons\\INV_Shield_30",
    -- ── Plate Armor ──────────────────────────────────────────────────────────
    "Interface\\Icons\\INV_Chest_Plate01",
    "Interface\\Icons\\INV_Chest_Plate02",
    "Interface\\Icons\\INV_Chest_Plate04",
    "Interface\\Icons\\INV_Chest_Plate05",
    "Interface\\Icons\\INV_Helm_Plate_AhnQirajBoss_D_01",
    "Interface\\Icons\\INV_Helmet_01",
    "Interface\\Icons\\INV_Helmet_02",
    "Interface\\Icons\\INV_Helmet_03",
    "Interface\\Icons\\INV_Helmet_04",
    "Interface\\Icons\\INV_Helmet_07",
    "Interface\\Icons\\INV_Helmet_08",
    "Interface\\Icons\\INV_Shoulder_01",
    "Interface\\Icons\\INV_Shoulder_02",
    "Interface\\Icons\\INV_Shoulder_22",
    "Interface\\Icons\\INV_Shoulder_23",
    "Interface\\Icons\\INV_Boots_01",
    "Interface\\Icons\\INV_Boots_05",
    "Interface\\Icons\\INV_Boots_06",
    "Interface\\Icons\\INV_Boots_Plate_02",
    "Interface\\Icons\\INV_Bracer_01",
    "Interface\\Icons\\INV_Bracer_02",
    "Interface\\Icons\\INV_Bracer_07",
    "Interface\\Icons\\INV_Bracer_14",
    "Interface\\Icons\\INV_Gauntlets_01",
    "Interface\\Icons\\INV_Belt_01",
    "Interface\\Icons\\INV_Belt_12",
    "Interface\\Icons\\INV_Belt_13",
    "Interface\\Icons\\INV_Belt_29",
    "Interface\\Icons\\INV_Pants_01",
    "Interface\\Icons\\INV_Pants_02",
    -- ── Mail / Leather / Cloth ───────────────────────────────────────────────
    "Interface\\Icons\\INV_Chest_Leather_01",
    "Interface\\Icons\\INV_Chest_Leather_04",
    "Interface\\Icons\\INV_Chest_Mail_01",
    "Interface\\Icons\\INV_Chest_Mail_04",
    "Interface\\Icons\\INV_Chest_Cloth_05",
    "Interface\\Icons\\INV_Chest_Cloth_13",
    "Interface\\Icons\\INV_Leather_01",
    "Interface\\Icons\\INV_Leather_25",
    "Interface\\Icons\\INV_Leather_Boot_02",
    -- ── Cloaks ───────────────────────────────────────────────────────────────
    "Interface\\Icons\\INV_Misc_Cape_05",
    "Interface\\Icons\\INV_Misc_Cape_07",
    "Interface\\Icons\\INV_Misc_Cape_12",
    "Interface\\Icons\\INV_Misc_Cape_14",
    "Interface\\Icons\\INV_Misc_Cape_15",
    "Interface\\Icons\\INV_Misc_Cape_16",
    "Interface\\Icons\\INV_Misc_Cape_17",
    "Interface\\Icons\\INV_Misc_Cape_19",
    -- ── Jewelry ──────────────────────────────────────────────────────────────
    "Interface\\Icons\\INV_Jewelry_Ring_01",
    "Interface\\Icons\\INV_Jewelry_Ring_02",
    "Interface\\Icons\\INV_Jewelry_Ring_06",
    "Interface\\Icons\\INV_Jewelry_Ring_10",
    "Interface\\Icons\\INV_Jewelry_Ring_13",
    "Interface\\Icons\\INV_Jewelry_Ring_14",
    "Interface\\Icons\\INV_Jewelry_Ring_15",
    "Interface\\Icons\\INV_Jewelry_Ring_24",
    "Interface\\Icons\\INV_Jewelry_Ring_25",
    "Interface\\Icons\\INV_Jewelry_Necklace_01",
    "Interface\\Icons\\INV_Jewelry_Necklace_02",
    "Interface\\Icons\\INV_Jewelry_Necklace_06",
    "Interface\\Icons\\INV_Jewelry_Necklace_10",
    "Interface\\Icons\\INV_Jewelry_Necklace_11",
    "Interface\\Icons\\INV_Jewelry_Necklace_12",
    "Interface\\Icons\\INV_Jewelry_Trinket_01",
    "Interface\\Icons\\INV_Jewelry_Trinket_02",
    "Interface\\Icons\\INV_Jewelry_AmuletExodar_01",
    "Interface\\Icons\\INV_Jewelry_Amulet_01",
    "Interface\\Icons\\INV_Jewelry_Amulet_06",
    "Interface\\Icons\\INV_Jewelry_Talisman_03",
    "Interface\\Icons\\INV_Jewelry_Talisman_07",
    "Interface\\Icons\\INV_Jewelry_Talisman_10",
    -- ── Profession / Trade ───────────────────────────────────────────────────
    "Interface\\Icons\\Trade_Alchemy",
    "Interface\\Icons\\Trade_ArmorSmithing",
    "Interface\\Icons\\Trade_BlackSmithing",
    "Interface\\Icons\\Trade_BrewPoison",
    "Interface\\Icons\\Trade_Cooking",
    "Interface\\Icons\\Trade_Engraving",
    "Interface\\Icons\\Trade_Engineering",
    "Interface\\Icons\\Trade_Fishing",
    "Interface\\Icons\\Trade_Herbalism",
    "Interface\\Icons\\Trade_Leatherworking",
    "Interface\\Icons\\Trade_Mining",
    "Interface\\Icons\\Trade_Skinning",
    "Interface\\Icons\\Trade_Tailoring",
    "Interface\\Icons\\Trade_WeaponSmithing",
    -- ── Misc / UI ────────────────────────────────────────────────────────────
    "Interface\\Icons\\INV_Misc_QuestionMark",
    "Interface\\Icons\\INV_Misc_Coin_01",
    "Interface\\Icons\\INV_Misc_Coin_02",
    "Interface\\Icons\\INV_Misc_Rune_01",
    "Interface\\Icons\\INV_Misc_Rune_04",
    "Interface\\Icons\\INV_Misc_Note_01",
    "Interface\\Icons\\INV_Misc_Bag_07",
    "Interface\\Icons\\INV_Misc_Bag_10",
    "Interface\\Icons\\INV_Misc_Key_01",
    "Interface\\Icons\\INV_Misc_Key_02",
    "Interface\\Icons\\INV_Misc_PocketWatch_01",
    "Interface\\Icons\\INV_Misc_Head_Dragon_01",
    "Interface\\Icons\\INV_Misc_Head_Dragon_Bronze",
    "Interface\\Icons\\INV_Misc_StarFall_01",
    "Interface\\Icons\\INV_Misc_Gem_01",
    "Interface\\Icons\\INV_Misc_Gem_02",
    "Interface\\Icons\\INV_Misc_Gem_Ruby_01",
    "Interface\\Icons\\INV_Misc_Gem_Sapphire_01",
    "Interface\\Icons\\INV_Misc_Gem_Emerald_02",
    "Interface\\Icons\\INV_Misc_Gem_Diamond_01",
    "Interface\\Icons\\INV_Misc_Gem_Bloodstone_01",
    "Interface\\Icons\\INV_Misc_Gem_Opal_02",
    "Interface\\Icons\\INV_Misc_Gem_VariousCuts",
    "Interface\\Icons\\INV_Misc_MonsterScales_06",
    "Interface\\Icons\\INV_Misc_MonsterTail_01",
    "Interface\\Icons\\INV_Misc_Orb_01",
    "Interface\\Icons\\INV_Misc_Orb_02",
    "Interface\\Icons\\INV_Misc_Orb_04",
    "Interface\\Icons\\INV_Misc_Orb_05",
    "Interface\\Icons\\INV_Wand_01",
    "Interface\\Icons\\INV_Wand_06",
    "Interface\\Icons\\INV_Wand_10",
    "Interface\\Icons\\INV_Wand_11",
    "Interface\\Icons\\INV_Stone_01",
    "Interface\\Icons\\INV_Stone_02",
    "Interface\\Icons\\INV_Scroll_01",
    "Interface\\Icons\\INV_Scroll_06",
    "Interface\\Icons\\INV_Potion_01",
    "Interface\\Icons\\INV_Potion_09",
    "Interface\\Icons\\INV_Potion_15",
    "Interface\\Icons\\INV_Potion_17",
    "Interface\\Icons\\INV_Potion_23",
    "Interface\\Icons\\INV_Potion_51",
    "Interface\\Icons\\INV_Potion_56",
    "Interface\\Icons\\INV_Potion_67",
    "Interface\\Icons\\INV_Potion_73",
    "Interface\\Icons\\INV_Potion_75",
    "Interface\\Icons\\INV_Potion_76",
    "Interface\\Icons\\INV_Potion_78",
    "Interface\\Icons\\INV_Potion_83",
    "Interface\\Icons\\INV_Potion_85",
    "Interface\\Icons\\INV_Potion_88",
    "Interface\\Icons\\INV_Potion_90",
    "Interface\\Icons\\INV_Potion_92",
    -- ── PvP / Faction ────────────────────────────────────────────────────────
    "Interface\\Icons\\PVPCurrency_Honor_Alliance",
    "Interface\\Icons\\PVPCurrency_Honor_Horde",
    "Interface\\Icons\\Achievement_Pvp_A_01",
    "Interface\\Icons\\Achievement_Pvp_H_01",
    -- ── Character Emblems ────────────────────────────────────────────────────
    "Interface\\Icons\\Achievement_Character_Warrior_Male",
    "Interface\\Icons\\Achievement_Character_Paladin_Male",
    "Interface\\Icons\\Achievement_Character_Hunter_Male",
    "Interface\\Icons\\Achievement_Character_Rogue_Male",
    "Interface\\Icons\\Achievement_Character_Priest_Male",
    "Interface\\Icons\\Achievement_Character_Shaman_Male",
    "Interface\\Icons\\Achievement_Character_Mage_Male",
    "Interface\\Icons\\Achievement_Character_Warlock_Male",
    "Interface\\Icons\\Achievement_Character_Druid_Male",
}

local function SC_HideIconPicker()
    if iconPickerFrame then iconPickerFrame:Hide() end
    iconPickerTarget = nil
end

local function SC_ShowPage(page) end  -- forward decl, defined after BuildIconPicker

local function BuildIconPicker()
    if iconPickerFrame then return end
    local gridH = IPICK_ROWS*(IPICK_ICO_S+IPICK_GAP) + IPICK_PAD*2
    local totalH = IPICK_HDR_H + gridH + IPICK_FOT_H
    local f = CreateFrame("Frame", "SlyCharIconPicker", UIParent)
    f:SetFrameStrata("FULLSCREEN_DIALOG")
    f:SetWidth(IPICK_W)
    f:SetHeight(totalH)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop",  f.StopMovingOrSizing)
    f:SetClampedToScreen(true)
    f:Hide()

    local bg = f:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints() ; bg:SetColorTexture(0.06, 0.06, 0.09, 0.97)
    local bord = f:CreateTexture(nil, "OVERLAY")
    bord:SetAllPoints() ; bord:SetColorTexture(0.28, 0.28, 0.40, 1)
    local inner = f:CreateTexture(nil, "BACKGROUND")
    inner:SetPoint("TOPLEFT",     f, "TOPLEFT",      1, -1)
    inner:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -1,  1)
    inner:SetColorTexture(0.07, 0.07, 0.10, 0.97)

    local hdr = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    hdr:SetFont(hdr:GetFont(), 10, "OUTLINE")
    hdr:SetPoint("TOPLEFT", f, "TOPLEFT", IPICK_PAD, -5)
    hdr:SetTextColor(0.70, 0.85, 1.00)
    hdr:SetText("Choose Icon")

    local xBtn = CreateFrame("Button", nil, f)
    xBtn:SetSize(16, 16) ; xBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -3, -3)
    xBtn:EnableMouse(true)
    xBtn:RegisterForClicks("LeftButtonUp")
    local xBg = xBtn:CreateTexture(nil, "BACKGROUND")
    xBg:SetAllPoints() ; xBg:SetColorTexture(0.40, 0.10, 0.10, 0.90)
    local xHl = xBtn:CreateTexture(nil, "HIGHLIGHT")
    xHl:SetAllPoints() ; xHl:SetColorTexture(0.70, 0.20, 0.20, 0.60)
    local xTx = xBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    xTx:SetAllPoints() ; xTx:SetJustifyH("CENTER") ; xTx:SetText("|cffff8888x|r")
    xBtn:SetScript("OnClick", function() SC_HideIconPicker() end)

    local sep = f:CreateTexture(nil, "ARTWORK")
    sep:SetPoint("TOPLEFT",  f, "TOPLEFT",  1, -IPICK_HDR_H)
    sep:SetPoint("TOPRIGHT", f, "TOPRIGHT", -1, -IPICK_HDR_H)
    sep:SetHeight(1) ; sep:SetColorTexture(0.25, 0.25, 0.38, 1)

    -- Icon buttons placed directly on frame (no scroll frame)
    for k = 1, IPICK_PAGE do
        local col = (k-1) % IPICK_COLS
        local row = math.floor((k-1) / IPICK_COLS)
        local btn = CreateFrame("Button", nil, f)
        btn:SetSize(IPICK_ICO_S, IPICK_ICO_S)
        btn:EnableMouse(true)
        btn:RegisterForClicks("LeftButtonUp")
        btn:SetPoint("TOPLEFT", f, "TOPLEFT",
            IPICK_PAD + col*(IPICK_ICO_S+IPICK_GAP),
            -(IPICK_HDR_H + IPICK_PAD + row*(IPICK_ICO_S+IPICK_GAP)))
        btn:Hide()
        local icTex = btn:CreateTexture(nil, "ARTWORK")
        icTex:SetAllPoints() ; icTex:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        btn._ic = icTex
        local hl = btn:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints() ; hl:SetColorTexture(1, 1, 1, 0.35)
        local selRing = btn:CreateTexture(nil, "OVERLAY")
        selRing:SetAllPoints() ; selRing:SetColorTexture(0, 0, 0, 0)
        btn._sel = selRing
        btn:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            local sn2 = (self._tex or ""):match("\\([^\\]+)$") or "?"
            GameTooltip:SetText(sn2, 1, 1, 1)
            GameTooltip:Show()
        end)
        btn:SetScript("OnLeave", function(self)
            self._sel:SetColorTexture(0, 0, 0, 0)
            GameTooltip:Hide()
        end)
        iconBtnPool[k] = btn
    end

    -- Footer: prev / page label / next
    local prevBtn = CreateFrame("Button", nil, f)
    prevBtn:SetSize(40, 20)
    prevBtn:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", IPICK_PAD, 4)
    prevBtn:EnableMouse(true)
    prevBtn:RegisterForClicks("LeftButtonUp")
    local prevBg = prevBtn:CreateTexture(nil, "BACKGROUND")
    prevBg:SetAllPoints() ; prevBg:SetColorTexture(0.18, 0.18, 0.28, 0.90)
    local prevHl = prevBtn:CreateTexture(nil, "HIGHLIGHT")
    prevHl:SetAllPoints() ; prevHl:SetColorTexture(1, 1, 1, 0.15)
    local prevTx = prevBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    prevTx:SetAllPoints() ; prevTx:SetJustifyH("CENTER") ; prevTx:SetText("< Prev")
    prevBtn:SetScript("OnClick", function()
        SC_ShowPage(iconCurrentPage - 1)
    end)

    local nextBtn = CreateFrame("Button", nil, f)
    nextBtn:SetSize(40, 20)
    nextBtn:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -IPICK_PAD, 4)
    nextBtn:EnableMouse(true)
    nextBtn:RegisterForClicks("LeftButtonUp")
    local nextBg = nextBtn:CreateTexture(nil, "BACKGROUND")
    nextBg:SetAllPoints() ; nextBg:SetColorTexture(0.18, 0.18, 0.28, 0.90)
    local nextHl = nextBtn:CreateTexture(nil, "HIGHLIGHT")
    nextHl:SetAllPoints() ; nextHl:SetColorTexture(1, 1, 1, 0.15)
    local nextTx = nextBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    nextTx:SetAllPoints() ; nextTx:SetJustifyH("CENTER") ; nextTx:SetText("Next >")
    nextBtn:SetScript("OnClick", function()
        SC_ShowPage(iconCurrentPage + 1)
    end)

    local pageLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    pageLabel:SetPoint("BOTTOM", f, "BOTTOM", 0, 8)
    pageLabel:SetTextColor(0.60, 0.60, 0.70)
    f._pageLabel = pageLabel
    f._prevBtn   = prevBtn
    f._nextBtn   = nextBtn
    iconPickerFrame = f
end

local function SC_PopulateIconPicker()
    local seen = {}
    iconList = {}
    local function addTex(tex)
        if not tex then return end
        tex = tostring(tex)
        if tex == "" or tex:find("^table:") then return end  -- skip invalid/table values
        if seen[tex] then return end
        seen[tex] = true ; iconList[#iconList+1] = tex
    end

    -- Static icons first so page 1 is always populated
    for _, tex in ipairs(STATIC_SET_ICONS) do addTex(tex) end

    -- Full spellbook scan (captures every spell icon the player has)
    if GetNumSpellTabs then
        local numTabs = GetNumSpellTabs()
        for tab = 1, numTabs do
            local _, _, offset, numSlots = GetSpellTabInfo(tab)
            for i = offset + 1, offset + numSlots do
                addTex(GetSpellBookItemTexture(i, "spell"))
            end
        end
    end

    -- Equipped item textures
    for slot = 1, 19 do addTex(GetInventoryItemTexture("player", slot)) end

    -- Bag item icons (C_Container-safe)
    local _GetNumSlots = C_Container and C_Container.GetContainerNumSlots or GetContainerNumSlots
    for bag = 0, 4 do
        local numSlots = _GetNumSlots and _GetNumSlots(bag) or 0
        for slot = 1, numSlots do
            local icon
            if C_Container and C_Container.GetContainerItemInfo then
                local info = C_Container.GetContainerItemInfo(bag, slot)
                icon = info and info.iconFileID
            else
                icon = (GetContainerItemInfo(bag, slot))
            end
            addTex(icon)
        end
    end
end

SC_ShowPage = function(page)
    local totalPages = math.max(1, math.ceil(#iconList / IPICK_PAGE))
    page = math.max(1, math.min(page, totalPages))
    iconCurrentPage = page

    local curIcon = iconPickerTarget and IRR_GetSetIcon and
        IRR_GetSetIcon(iconPickerTarget.name)

    for k = 1, IPICK_PAGE do
        local btn = iconBtnPool[k]
        local idx = (page-1)*IPICK_PAGE + k
        local tex = iconList[idx]
        if tex then
            btn._tex = tex
            btn._ic:SetTexture(tex)
            local isSelected = curIcon and curIcon == tex
            btn._sel:SetColorTexture(
                isSelected and 0.2 or 0,
                isSelected and 0.7 or 0,
                isSelected and 1.0 or 0,
                isSelected and 0.6 or 0)
            btn:SetScript("OnClick", function(self)
                if not iconPickerTarget then SC_HideIconPicker(); return end
                local sn = iconPickerTarget.name
                local ib = iconPickerTarget.btn
                if IRR_SetSetIcon then IRR_SetSetIcon(sn, self._tex) end
                if ib then
                    ib._icTex:SetTexture(self._tex)
                    ib._icTex:SetTexCoord(0.07, 0.93, 0.07, 0.93)
                end
                SC_HideIconPicker()
            end)
            btn:Show()
        else
            btn:Hide()
        end
    end

    iconPickerFrame._pageLabel:SetText(page .. " / " .. totalPages)
    iconPickerFrame._prevBtn:SetShown(page > 1)
    iconPickerFrame._nextBtn:SetShown(page < totalPages)
end

local function SC_ShowIconPicker(setName, anchorBtn)
    BuildIconPicker()
    iconPickerTarget = { name = setName, btn = anchorBtn }
    SC_PopulateIconPicker()
    iconCurrentPage = 1
    SC_ShowPage(1)
    iconPickerFrame:ClearAllPoints()
    iconPickerFrame:SetPoint("BOTTOMLEFT", anchorBtn, "TOPLEFT", 0, 4)
    iconPickerFrame:Show()
    iconPickerFrame:Raise()
end

-- ============================================================
-- Sets tab
-- ============================================================
local function BuildSetRows(parent)
    for i = 1, MAX_SET_ROWS do
        local row = CreateFrame("Frame", nil, parent)
        row:SetSize(SIDE_W - PAD*2 - 16, 22)
        row:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -((i-1)*22))

        local bg = row:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints(row)
        bg:SetColorTexture(0, 0, 0, i%2==0 and 0.12 or 0)

        -- Delete button (far right)
        local delBtn = CreateFrame("Button", nil, row)
        delBtn:SetSize(16, 16)
        delBtn:SetPoint("RIGHT", row, "RIGHT", -2, 0)
        delBtn:EnableMouse(false)
        delBtn:RegisterForClicks("LeftButtonUp")
        local delBg = delBtn:CreateTexture(nil, "BACKGROUND")
        delBg:SetAllPoints() ; delBg:SetColorTexture(0.45, 0.10, 0.10, 0.85)
        local delHl = delBtn:CreateTexture(nil, "HIGHLIGHT")
        delHl:SetAllPoints() ; delHl:SetColorTexture(0.70, 0.20, 0.20, 0.50)
        local delTx = delBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        delTx:SetFont(delTx:GetFont(), 9, "OUTLINE") ; delTx:SetAllPoints()
        delTx:SetJustifyH("CENTER") ; delTx:SetText("|cffff6666x|r")

        -- Save button
        local saveBtn = CreateFrame("Button", nil, row)
        saveBtn:SetSize(36, 16)
        saveBtn:SetPoint("RIGHT", delBtn, "LEFT", -2, 0)
        saveBtn:EnableMouse(false)
        saveBtn:RegisterForClicks("LeftButtonUp")
        local saveBg = saveBtn:CreateTexture(nil, "BACKGROUND")
        saveBg:SetAllPoints() ; saveBg:SetColorTexture(0.15, 0.38, 0.60, 0.85)
        local saveHl = saveBtn:CreateTexture(nil, "HIGHLIGHT")
        saveHl:SetAllPoints() ; saveHl:SetColorTexture(0.30, 0.55, 0.80, 0.50)
        local saveTx = saveBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        saveTx:SetFont(saveTx:GetFont(), 9, "OUTLINE") ; saveTx:SetAllPoints()
        saveTx:SetJustifyH("CENTER") ; saveTx:SetText("Save")

        -- Equip button
        local eqBtn = CreateFrame("Button", nil, row)
        eqBtn:SetSize(40, 16)
        eqBtn:SetPoint("RIGHT", saveBtn, "LEFT", -2, 0)
        eqBtn:EnableMouse(false)
        eqBtn:RegisterForClicks("LeftButtonUp")
        local eqBg = eqBtn:CreateTexture(nil, "BACKGROUND")
        eqBg:SetAllPoints() ; eqBg:SetColorTexture(0.15, 0.30, 0.15, 0.85)
        local eqHl = eqBtn:CreateTexture(nil, "HIGHLIGHT")
        eqHl:SetAllPoints() ; eqHl:SetColorTexture(0.25, 0.55, 0.25, 0.50)
        local eqTx = eqBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        eqTx:SetFont(eqTx:GetFont(), 9, "OUTLINE") ; eqTx:SetAllPoints()
        eqTx:SetJustifyH("CENTER") ; eqTx:SetText("Equip")

        -- Spec-link toggle button  (left of Equip)
        -- Clicking cycles: none → Spec 1 → Spec 2 → none
        local specBtn = CreateFrame("Button", nil, row)
        specBtn:SetSize(28, 16)
        specBtn:SetPoint("RIGHT", eqBtn, "LEFT", -2, 0)
        specBtn:EnableMouse(false)
        specBtn:RegisterForClicks("LeftButtonUp")
        local specBg = specBtn:CreateTexture(nil, "BACKGROUND")
        specBg:SetAllPoints() ; specBg:SetColorTexture(0.20, 0.20, 0.25, 0.85)
        specBtn.bg = specBg
        local specHl = specBtn:CreateTexture(nil, "HIGHLIGHT")
        specHl:SetAllPoints() ; specHl:SetColorTexture(1, 1, 1, 0.15)
        local specTx = specBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        specTx:SetFont(specTx:GetFont(), 8, "OUTLINE") ; specTx:SetAllPoints()
        specTx:SetJustifyH("CENTER") ; specTx:SetText("--")
        specBtn.tx = specTx

        -- Icon button (click opens icon picker)
        local iconBtn = CreateFrame("Button", nil, row)
        iconBtn:SetSize(20, 20)
        iconBtn:SetPoint("LEFT", row, "LEFT", 0, 0)
        iconBtn:EnableMouse(false)
        iconBtn:RegisterForClicks("LeftButtonUp")
        local iconBg2 = iconBtn:CreateTexture(nil, "BACKGROUND")
        iconBg2:SetAllPoints() ; iconBg2:SetColorTexture(0.12, 0.12, 0.16, 0.90)
        local iconTex = iconBtn:CreateTexture(nil, "ARTWORK")
        iconTex:SetAllPoints()
        iconTex:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
        iconTex:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        iconBtn._icTex = iconTex
        local iconHl = iconBtn:CreateTexture(nil, "HIGHLIGHT")
        iconHl:SetAllPoints() ; iconHl:SetColorTexture(1, 1, 1, 0.30)

        local nm = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        nm:SetFont(nm:GetFont(), 10, "")
        nm:SetPoint("LEFT", row, "LEFT", 24, 0)
        nm:SetJustifyH("LEFT")
        nm:SetWidth(138)

        local cnt = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        cnt:SetFont(cnt:GetFont(), 9, "")
        cnt:SetPoint("LEFT", nm, "RIGHT", 2, 0)
        cnt:SetJustifyH("LEFT")
        cnt:SetTextColor(0.4, 0.4, 0.4)

        row:Hide()
        setRowWidgets[i] = {row=row, nm=nm, cnt=cnt, iconBtn=iconBtn, specBtn=specBtn, eqBtn=eqBtn, saveBtn=saveBtn, delBtn=delBtn}
    end
end

local function BuildBarRows(parent)
    for i = 1, MAX_BAR_ROWS do
        local row = CreateFrame("Frame", nil, parent)
        row:SetSize(SIDE_W - PAD*2 - 16, 22)
        row:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -((i-1)*22))

        local bg = row:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints(row)
        bg:SetColorTexture(0, 0, 0, i%2==0 and 0.12 or 0)

        -- Delete button (far right)
        local delBtn = CreateFrame("Button", nil, row)
        delBtn:SetSize(16, 16) ; delBtn:SetPoint("RIGHT", row, "RIGHT", -2, 0)
        delBtn:EnableMouse(false) ; delBtn:RegisterForClicks("LeftButtonUp")
        local delBg = delBtn:CreateTexture(nil, "BACKGROUND")
        delBg:SetAllPoints() ; delBg:SetColorTexture(0.45, 0.10, 0.10, 0.85)
        local delHl = delBtn:CreateTexture(nil, "HIGHLIGHT")
        delHl:SetAllPoints() ; delHl:SetColorTexture(0.70, 0.20, 0.20, 0.50)
        local delTx = delBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        delTx:SetFont(delTx:GetFont(), 9, "OUTLINE") ; delTx:SetAllPoints()
        delTx:SetJustifyH("CENTER") ; delTx:SetText("|cffff6666x|r")

        -- Update (overwrite) button
        local updBtn = CreateFrame("Button", nil, row)
        updBtn:SetSize(36, 16) ; updBtn:SetPoint("RIGHT", delBtn, "LEFT", -2, 0)
        updBtn:EnableMouse(false) ; updBtn:RegisterForClicks("LeftButtonUp")
        local updBg = updBtn:CreateTexture(nil, "BACKGROUND")
        updBg:SetAllPoints() ; updBg:SetColorTexture(0.15, 0.38, 0.60, 0.85)
        local updHl = updBtn:CreateTexture(nil, "HIGHLIGHT")
        updHl:SetAllPoints() ; updHl:SetColorTexture(0.30, 0.55, 0.80, 0.50)
        local updTx = updBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        updTx:SetFont(updTx:GetFont(), 9, "OUTLINE") ; updTx:SetAllPoints()
        updTx:SetJustifyH("CENTER") ; updTx:SetText("Upd")

        -- Load button
        local loadBtn = CreateFrame("Button", nil, row)
        loadBtn:SetSize(36, 16) ; loadBtn:SetPoint("RIGHT", updBtn, "LEFT", -2, 0)
        loadBtn:EnableMouse(false) ; loadBtn:RegisterForClicks("LeftButtonUp")
        local loadBg = loadBtn:CreateTexture(nil, "BACKGROUND")
        loadBg:SetAllPoints() ; loadBg:SetColorTexture(0.15, 0.30, 0.15, 0.85)
        local loadHl = loadBtn:CreateTexture(nil, "HIGHLIGHT")
        loadHl:SetAllPoints() ; loadHl:SetColorTexture(0.25, 0.55, 0.25, 0.50)
        local loadTx = loadBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        loadTx:SetFont(loadTx:GetFont(), 9, "OUTLINE") ; loadTx:SetAllPoints()
        loadTx:SetJustifyH("CENTER") ; loadTx:SetText("Load")

        local nm = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        nm:SetFont(nm:GetFont(), 10, "")
        nm:SetPoint("LEFT", row, "LEFT", 4, 0)
        nm:SetJustifyH("LEFT") ; nm:SetWidth(170)

        row:Hide()
        barRowWidgets[i] = { row=row, nm=nm, loadBtn=loadBtn, updBtn=updBtn, delBtn=delBtn }
    end
end

function SC_RefreshBars()
    for _, w in ipairs(barRowWidgets) do w.row:Hide() end

    if not SlySlot or not SlySlot.db then
        local w = barRowWidgets[1]
        if w then
            w.nm:SetText("|cffff8800SlySlot not loaded|r")
            w.loadBtn:EnableMouse(false) ; w.updBtn:EnableMouse(false) ; w.delBtn:EnableMouse(false)
            w.row:Show()
        end
        return
    end

    local names = {}
    for n in pairs(SlySlot.db.profiles) do table.insert(names, n) end
    table.sort(names)

    if #names == 0 then
        local w = barRowWidgets[1]
        if w then
            w.nm:SetText("|cff666666No profiles saved|r")
            w.loadBtn:EnableMouse(false) ; w.updBtn:EnableMouse(false) ; w.delBtn:EnableMouse(false)
            w.row:Show()
        end
        return
    end

    local total = #names
    barsScrollOffset = math.max(0, math.min(barsScrollOffset, math.max(0, total - MAX_BAR_ROWS)))

    for i = 1, MAX_BAR_ROWS do
        local w    = barRowWidgets[i]
        if not w then break end
        local name = names[barsScrollOffset + i]
        if not name then break end

        w.nm:SetText("|cffdddddd" .. name .. "|r")

        w.loadBtn:EnableMouse(true)
        w.loadBtn:SetScript("OnClick", function()
            if SlySlot_LoadProfile then
                local ok, err = SlySlot_LoadProfile(name)
                if ok then
                    DEFAULT_CHAT_FRAME:AddMessage("|cff88bbff[SlyChar]|r Loaded bars: |cffffd700"..name.."|r")
                else
                    DEFAULT_CHAT_FRAME:AddMessage("|cffff4444[SlyChar]|r Load failed: "..tostring(err))
                end
            end
        end)
        w.loadBtn:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText("Load", 1, 1, 1)
            GameTooltip:AddLine("Restore action bars from \""..name.."\"", 0.8, 0.8, 0.8, true)
            GameTooltip:Show()
        end)
        w.loadBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

        w.updBtn:EnableMouse(true)
        w.updBtn:SetScript("OnClick", function()
            if SlySlot_SaveProfile then
                SlySlot_SaveProfile(name)
                DEFAULT_CHAT_FRAME:AddMessage("|cff88bbff[SlyChar]|r Updated bars: |cffffd700"..name.."|r")
                SC_RefreshBars()
            end
        end)
        w.updBtn:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText("Update", 1, 1, 1)
            GameTooltip:AddLine("Overwrite \""..name.."\" with current bars", 0.8, 0.8, 0.8, true)
            GameTooltip:Show()
        end)
        w.updBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

        w.delBtn:EnableMouse(true)
        w.delBtn:SetScript("OnClick", function()
            if SlySlot_DeleteProfile then
                SlySlot_DeleteProfile(name)
                SC_RefreshBars()
            end
        end)
        w.delBtn:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText("Delete", 1, 0.3, 0.3)
            GameTooltip:AddLine("Delete profile \""..name.."\"", 0.8, 0.8, 0.8, true)
            GameTooltip:Show()
        end)
        w.delBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

        w.row:Show()
    end

    if barsScrollInfoLabel then
        if total > MAX_BAR_ROWS then
            barsScrollInfoLabel:SetText(string.format("|cff444455%d-%d / %d  (scroll)|r",
                barsScrollOffset+1, math.min(barsScrollOffset+MAX_BAR_ROWS, total), total))
        else
            barsScrollInfoLabel:SetText("")
        end
    end
end

function SC_SetSetsSubTab(key)
    setsUI.subTab = key
end

function SC_RefreshSetsSub()
    local function StyleSetsSub(btn, active)
        if not btn then return end
        if active then
            btn.bg:SetColorTexture(0.12, 0.18, 0.32, 1)
            btn.tx:SetTextColor(0.75, 0.88, 1.00)
        else
            btn.bg:SetColorTexture(0.05, 0.05, 0.09, 1)
            btn.tx:SetTextColor(0.40, 0.40, 0.50)
        end
    end
    StyleSetsSub(setsUI.subGearBtn, setsUI.subTab == "gear")
    StyleSetsSub(setsUI.subBarsBtn, setsUI.subTab == "bars")
    StyleSetsSub(setsUI.subBisBtn,  setsUI.subTab == "bis")
    if setsUI.gearContent then setsUI.gearContent:SetShown(setsUI.subTab == "gear") end
    if setsUI.barsContent then setsUI.barsContent:SetShown(setsUI.subTab == "bars") end
    if setsUI.bisContent  then setsUI.bisContent:SetShown(setsUI.subTab == "bis")  end
    if setsUI.subTab == "gear" then
        SC_RefreshSets()
    elseif setsUI.subTab == "bars" then
        SC_RefreshBars()
    elseif setsUI.subTab == "bis" then
        if IRR_RefreshBISPanel then pcall(IRR_RefreshBISPanel) end
    end
end

function SC_RefreshSets()
    for _, w in ipairs(setRowWidgets) do w.row:Hide() end

    if not IRR_GetSetNames then
        local w = setRowWidgets[1]
        if w then
            w.nm:SetText("|cffff8800ItemRackRevived not loaded|r")
            w.cnt:SetText("") ; w.eqBtn:Hide() ; w.saveBtn:Hide() ; w.specBtn:Hide() ; w.delBtn:Hide()
            w.row:Show()
        end
        return
    end

    local names = IRR_GetSetNames()
    if not names or #names == 0 then
        local w = setRowWidgets[1]
        if w then
            w.nm:SetText("|cff666666No sets saved|r")
            w.cnt:SetText("") ; w.eqBtn:Hide() ; w.saveBtn:Hide() ; w.specBtn:Hide() ; w.delBtn:Hide()
            w.row:Show()
        end
        return
    end

    -- clamp offset
    local total = #names
    setsScrollOffset = math.max(0, math.min(setsScrollOffset, math.max(0, total - MAX_SET_ROWS)))

    for i = 1, MAX_SET_ROWS do
        local w = setRowWidgets[i]
        if not w then break end
        local name = names[setsScrollOffset + i]
        if not name then break end
        local setData = IRR and IRR.db and IRR.db.sets and IRR.db.sets[name]
        local n = 0
        if setData then for _ in pairs(setData) do n = n + 1 end end

        w.nm:SetText("|cffdddddd" .. name .. "|r")
        w.cnt:SetText(string.format("|cff555555(%d)|r", n))

        -- Icon button
        local ic = IRR_GetSetIcon and IRR_GetSetIcon(name)
        w.iconBtn._icTex:SetTexture(ic or "Interface\\Icons\\INV_Misc_QuestionMark")
        w.iconBtn._icTex:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        w.iconBtn:EnableMouse(true)
        w.iconBtn:SetScript("OnClick", function(self)
            SC_ShowIconPicker(name, self)
        end)
        w.iconBtn:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText("Set Icon", 1, 0.82, 0)
            GameTooltip:AddLine("Click to choose an icon for this set.", 0.8, 0.8, 0.8, true)
            GameTooltip:Show()
        end)
        w.iconBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
        w.iconBtn:Show()

        -- Spec-link toggle
        local function UpdateSpecBtn()
            local spec = IRR_GetSpecLink and IRR_GetSpecLink(name)
            local hasDualSpec = GetNumTalentGroups and GetNumTalentGroups() >= 2
            if not hasDualSpec then
                w.specBtn:Hide()
            else
                w.specBtn:EnableMouse(true)
                w.specBtn:Show()
                if spec == 1 then
                    w.specBtn.tx:SetText("|cffffd700S1|r")
                    w.specBtn.bg:SetColorTexture(0.40, 0.32, 0.05, 0.90)
                elseif spec == 2 then
                    w.specBtn.tx:SetText("|cff66ccffS2|r")
                    w.specBtn.bg:SetColorTexture(0.05, 0.25, 0.45, 0.90)
                else
                    w.specBtn.tx:SetText("|cff666666--|r")
                    w.specBtn.bg:SetColorTexture(0.20, 0.20, 0.25, 0.85)
                end
            end
        end
        UpdateSpecBtn()
        w.specBtn:SetScript("OnClick", function()
            if not IRR_SetSpecLink then return end
            local cur = IRR_GetSpecLink and IRR_GetSpecLink(name)
            local next = (cur == nil and 1) or (cur == 1 and 2) or nil
            IRR_SetSpecLink(name, next)
            UpdateSpecBtn()
        end)
        w.specBtn:SetScript("OnEnter", function(self)
            local spec = IRR_GetSpecLink and IRR_GetSpecLink(name)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText("Spec Link", 1, 0.82, 0)
            if spec then
                GameTooltip:AddLine("Equipping this set will switch to Spec " .. spec .. ".", 0.8, 0.8, 0.8, true)
            else
                GameTooltip:AddLine("Click to link a spec (1 or 2).\nWhen set is equipped, that spec activates.", 0.8, 0.8, 0.8, true)
            end
            GameTooltip:Show()
        end)
        w.specBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

        w.eqBtn:EnableMouse(true)
        w.eqBtn:SetScript("OnClick", function()
            if IRR_LoadSet then
                IRR_LoadSet(name)
                DEFAULT_CHAT_FRAME:AddMessage(
                    "|cff88bbff[SlyChar]|r Equipping: |cffffd700"..name.."|r")
            end
        end)

        w.saveBtn:EnableMouse(true)
        w.saveBtn:SetScript("OnClick", function()
            if IRR_SaveCurrentSet then
                IRR_SaveCurrentSet(name)
                SC_RefreshSets()
            end
        end)

        w.delBtn:EnableMouse(true)
        w.delBtn:SetScript("OnClick", function()
            if IRR_DeleteSet then IRR_DeleteSet(name) end
            SC_RefreshSets()
        end)

        w.row:SetScript("OnEnter", function()
            if not (IRR and IRR.db and IRR.db.sets and IRR.db.sets[name]) then return end
            GameTooltip:SetOwner(w.row, "ANCHOR_RIGHT")
            GameTooltip:SetText(name, 1, 0.84, 0)
            for _, itemId in pairs(IRR.db.sets[name]) do
                local n2 = GetItemInfo(itemId)
                if n2 then GameTooltip:AddLine(n2, 0.8, 0.8, 0.8) end
            end
            GameTooltip:Show()
        end)
        w.row:SetScript("OnLeave", function() GameTooltip:Hide() end)

        w.eqBtn:Show() ; w.saveBtn:Show() ; w.delBtn:Show()
        w.row:Show()
    end

    -- scroll indicator
    if setsScrollInfoLabel then
        local total2 = #names
        if total2 > MAX_SET_ROWS then
            local lo = setsScrollOffset + 1
            local hi = math.min(setsScrollOffset + MAX_SET_ROWS, total2)
            setsScrollInfoLabel:SetText(lo .. "-" .. hi .. " / " .. total2 .. "  ⇕ scroll")
        else
            setsScrollInfoLabel:SetText("")
        end
    end
end

-- ============================================================
-- Reputation tab
-- ============================================================
local STANDING_COLORS = {
    [1]={0.90,0.10,0.10}, [2]={0.90,0.35,0.00}, [3]={0.90,0.55,0.00},
    [4]={0.90,0.90,0.15}, [5]={0.30,0.90,0.30}, [6]={0.10,0.80,0.10},
    [7]={0.20,0.65,1.00}, [8]={1.00,0.85,0.25},
}
local STANDING_LABELS = {
    "Hated","Hostile","Unfriendly","Neutral",
    "Friendly","Honored","Revered","Exalted",
}

local function BuildRepRows(parent)
    local rowW = SIDE_W - PAD*2 - 16
    for i = 1, MAX_REP_ROWS do
        local row = CreateFrame("Frame", nil, parent)
        row:SetSize(rowW, 16)
        row:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -((i-1)*16))

        local bg = row:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints(row)
        bg:SetColorTexture(0, 0, 0, 0)
        row.bg = bg

        -- Col 1: faction name (~44% of row)
        local nm = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        nm:SetFont(nm:GetFont(), 9, "")
        nm:SetPoint("LEFT", row, "LEFT", 2, 2)
        nm:SetJustifyH("LEFT")
        nm:SetWidth(math.floor(rowW * 0.44))
        row.nm = nm

        -- Col 2: standing label (~22% of row)
        local st = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        st:SetFont(st:GetFont(), 9, "")
        st:SetPoint("LEFT", nm, "RIGHT", 4, 0)
        st:SetJustifyH("LEFT")
        st:SetWidth(math.floor(rowW * 0.22))
        row.st = st

        -- Col 3: numeric progress (right-aligned)
        local val = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        val:SetFont(val:GetFont(), 9, "")
        val:SetPoint("RIGHT", row, "RIGHT", -2, 2)
        val:SetJustifyH("RIGHT")
        val:SetTextColor(0.75, 0.75, 0.75)
        row.val = val

        -- thin progress bar at bottom of row
        local barBg = row:CreateTexture(nil, "ARTWORK")
        barBg:SetHeight(3)
        barBg:SetPoint("BOTTOMLEFT",  row, "BOTTOMLEFT",  2, 1)
        barBg:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -2, 1)
        barBg:SetColorTexture(0.12, 0.12, 0.15, 1)
        barBg:Hide()
        row.barBg = barBg

        local bar = row:CreateTexture(nil, "OVERLAY")
        bar:SetHeight(3)
        bar:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 2, 1)
        bar:SetWidth(1)
        bar:Hide()
        row.bar = bar

        row:Hide()
        repRows[i] = row
    end
end

function SC_RefreshReputation()
    for _, w in ipairs(repRows) do
        w:Hide() ; w.barBg:Hide() ; w.bar:Hide() ; w.val:SetText("") ; w.st:SetText("")
    end
    local ri  = 0
    local num = GetNumFactions and GetNumFactions() or 0
    local rowW = SIDE_W - PAD*2 - 20
    for i = 1, num do
        local name, _, standingId, barMin, barMax, barValue,
              _, _, isHeader, _, hasRep = GetFactionInfo(i)
        if name then
            ri = ri + 1
            local w = repRows[ri]
            if not w then break end
            w:Show()
            if isHeader then
                w.nm:SetText("|cff7799ff" .. name .. "|r")
                w.st:SetText("") ; w.val:SetText("")
                w.bg:SetColorTexture(0.09, 0.09, 0.16, 0.90)
                w.barBg:Hide() ; w.bar:Hide()
            else
                local sc2 = STANDING_COLORS[standingId] or {0.70,0.70,0.70}
                w.nm:SetText("|cffcccccc" .. name .. "|r")
                w.st:SetTextColor(sc2[1], sc2[2], sc2[3])
                w.st:SetText(STANDING_LABELS[standingId] or "?")
                w.bg:SetColorTexture(0, 0, 0, ri%2==0 and 0.12 or 0)
                if barMax and barMin and barMax > barMin then
                    local progress = barValue - barMin
                    local needed   = barMax - barMin
                    if standingId == 8 then  -- Exalted: no further progress
                        w.val:SetTextColor(sc2[1], sc2[2], sc2[3])
                        w.val:SetText("MAX")
                    else
                        w.val:SetTextColor(0.75, 0.75, 0.75)
                        w.val:SetText(string.format("%d / %d", progress, needed))
                    end
                    local pct = progress / needed
                    w.barBg:Show() ; w.bar:Show()
                    w.bar:SetWidth(math.max(1, pct * rowW))
                    w.bar:SetColorTexture(sc2[1]*0.65, sc2[2]*0.65, sc2[3]*0.65, 0.9)
                else
                    w.val:SetText("")
                    w.barBg:Hide() ; w.bar:Hide()
                end
            end
        end
    end
end

-- ============================================================
-- Skills tab
-- ============================================================
local function BuildSkillRows(parent)
    for i = 1, MAX_SKILL_ROWS do
        local row = CreateFrame("Frame", nil, parent)
        row:SetSize(SIDE_W - PAD*2 - 16, 14)
        row:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -((i-1)*14))

        local bg = row:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints(row)
        bg:SetColorTexture(0, 0, 0, 0)
        row.bg = bg

        local nm = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        nm:SetFont(nm:GetFont(), 9, "")
        nm:SetPoint("LEFT", row, "LEFT", 2, 0)
        nm:SetJustifyH("LEFT")
        nm:SetWidth((SIDE_W - PAD*2 - 16) * 0.68)
        row.nm = nm

        local rnk = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        rnk:SetFont(rnk:GetFont(), 9, "")
        rnk:SetPoint("RIGHT", row, "RIGHT", -2, 0)
        rnk:SetJustifyH("RIGHT")
        row.rnk = rnk

        row:Hide()
        skillRows[i] = row
    end
end

function SC_RefreshSkills()
    for _, w in ipairs(skillRows) do w:Hide() end
    local ri  = 0
    local num = GetNumSkillLines and GetNumSkillLines() or 0
    for i = 1, num do
        local skillName, isHeader, _, skillRank, numTempPoints,
              skillModifier, skillMaxRank = GetSkillLineInfo(i)
        if skillName then
            ri = ri + 1
            local w = skillRows[ri]
            if not w then break end
            w:Show()
            if isHeader then
                w.nm:SetText("|cff7799ff" .. skillName .. "|r")
                w.rnk:SetText("")
                w.bg:SetColorTexture(0.09, 0.09, 0.16, 0.90)
            else
                w.nm:SetText("|cffcccccc" .. skillName .. "|r")
                if skillMaxRank and skillMaxRank > 0 then
                    local eff = (skillRank or 0) + (numTempPoints or 0)
                        + (skillModifier or 0)
                    w.rnk:SetFormattedText(
                        "|cffc0c0c0%d|r/|cff666666%d|r", eff, skillMaxRank)
                else
                    w.rnk:SetText("|cff888888—|r")
                end
                w.bg:SetColorTexture(0, 0, 0, ri%2==0 and 0.10 or 0)
            end
        end
    end
end

function SC_RefreshHonor()
    if not miscUI.honorContent then return end
    if not miscUI.honorContent:IsShown() then return end
    local rows = miscUI._honorRows
    if not rows then return end

    -- Number formatter with thousands separators: 75000 → "75,000"
    local function commaNum(n)
        n = math.floor(n or 0)
        local s = tostring(n)
        local result, count = "", 0
        for i = #s, 1, -1 do
            if count > 0 and count % 3 == 0 then result = "," .. result end
            result = s:sub(i, i) .. result
            count  = count + 1
        end
        return result
    end

    local rank = 0
    if UnitPVPRank then rank = UnitPVPRank("player") or 0 end
    local rankName = "Unranked"
    if rank > 0 and GetPVPRankInfo then
        local rn = GetPVPRankInfo(rank)
        if rn then rankName = rn .. " (" .. rank .. ")" end
    end

    -- ── Honor currency (spendable amount) ────────────────────────────────────
    -- TBC Classic (including Anniversary) uses an index-based currency list:
    --   GetCurrencyListSize()  → total rows (headers + entries)
    --   GetCurrencyListInfo(i) → name, isHeader, isExpanded, _, _, qty, icon, maxQty
    --   ExpandCurrencyList(i, 1/0) → expand/collapse a header row
    local honorCurr, honorMax = 0, 75000
    local arenaPts = 0
    local function scanCurrencyList()
        if not GetCurrencyListSize then return end
        local size = GetCurrencyListSize()
        if (size or 0) == 0 then return end
        -- Expand every collapsed header so child entries become visible
        local toCollapse = {}
        for i = 1, size do
            local _, isHeader, isExpanded = GetCurrencyListInfo(i)
            if isHeader and not isExpanded then
                toCollapse[#toCollapse+1] = i
                ExpandCurrencyList(i, 1)
            end
        end
        size = GetCurrencyListSize()   -- re-query after expansion
        for i = 1, size do
            local name, isHeader, _, _, _, qty, _, maxQty = GetCurrencyListInfo(i)
            if not isHeader and name then
                local lname = name:lower()
                if lname:find("honor") then
                    honorCurr = math.floor(qty or 0)
                    honorMax  = (maxQty and maxQty > 0) and math.floor(maxQty) or 75000
                elseif lname:find("arena") then
                    arenaPts  = math.floor(qty or 0)
                end
            end
        end
        -- Re-collapse headers we opened
        for i = #toCollapse, 1, -1 do
            ExpandCurrencyList(toCollapse[i], 0)
        end
    end
    scanCurrencyList()
    -- WotLK+ fallbacks (nil on TBC Anniversary — kept for forward compat)
    if honorCurr == 0 and GetHonorCurrency then
        local c, m = GetHonorCurrency()
        honorCurr = math.floor(c or 0)
        honorMax  = (m and m > 0) and math.floor(m) or 75000
    end
    if arenaPts == 0 and GetArenaCurrency then
        arenaPts = math.floor(GetArenaCurrency() or 0)
    end

    -- ── HK / kill stats via GetHonorInfo() ───────────────────────────────────
    -- GetHonorInfo() -> todayHK, todayHonor, yHK, yHonor, lwHK, lwHonor,
    --                   twHK, twHonor, lifetimeHK, lifetimeHighestRank
    local twHK, yHK, lwHK, lfHK, lfDK = 0, 0, 0, 0, 0
    if GetHonorInfo then
        local _tdHK, _tdH, _yHK, _yH, _lwHK, _lwH, _twHK, _twH, _lfHK =
            GetHonorInfo()
        yHK  = math.floor(_yHK  or 0)
        lwHK = math.floor(_lwHK or 0)
        twHK = math.floor(_twHK or 0)
        lfHK = math.floor(_lfHK or 0)
        -- Use this-week honor as currency if C_CurrencyInfo gave us nothing
        if honorCurr == 0 and _twH and _twH > 0 then
            honorCurr = math.floor(_twH)
        end
    else
        -- Final per-stat fallbacks (WotLK+)
        if GetPVPThisWeekStats  then local a = GetPVPThisWeekStats()  ; twHK = math.floor(a or 0) end
        if GetPVPYesterdayStats then local a = GetPVPYesterdayStats() ; yHK  = math.floor(a or 0) end
        if GetPVPLastWeekStats  then local a = GetPVPLastWeekStats()  ; lwHK = math.floor(a or 0) end
        if GetPVPLifetimeStats  then
            local a, b = GetPVPLifetimeStats()
            lfHK = math.floor(a or 0) ; lfDK = math.floor(b or 0)
        end
    end
    if GetPVPLifetimeStats and lfHK == 0 then
        local a, b = GetPVPLifetimeStats()
        lfHK = math.floor(a or 0) ; lfDK = math.floor(b or 0)
    end

    local data = {
        { lbl="Rank",              val=rankName },
        { lbl="Honor",             val=commaNum(honorCurr).." / "..commaNum(honorMax) },
        { lbl="Arena Points",      val=commaNum(arenaPts) },
        { sep=true },
        { lbl="Yesterday HKs",     val=commaNum(yHK) },
        { lbl="This Week HKs",     val=commaNum(twHK) },
        { lbl="Last Week HKs",     val=commaNum(lwHK) },
        { sep=true },
        { lbl="Lifetime HKs",      val=commaNum(lfHK) },
        { lbl="Lifetime DKs",      val=commaNum(lfDK) },
    }

    for i = 1, #rows do
        local row = rows[i]
        local d   = data[i]
        if d then
            if d.sep then
                row.lbl:SetText("")
                row.val:SetText("")
                row.bg:SetColorTexture(0.12, 0.12, 0.20, 0.8)
                row:SetHeight(4)
            else
                row:SetHeight(14)
                row.lbl:SetText("|cff8899bb" .. d.lbl .. "|r")
                row.val:SetText("|cffdddddd" .. d.val .. "|r")
                row.bg:SetColorTexture(0, 0, 0, (i % 2 == 0) and 0.10 or 0)
            end
            row:Show()
        else
            row:Hide()
        end
    end
end

function SC_SetMiscSubTab(key) end  -- no-op; sub-tabs moved to wing flyout

function SC_RefreshMisc() end  -- Apps tab is static; no refresh needed

-- ============================================================
-- NIT (NovaInstanceTracker) tab  — per-alt lockout view
-- ============================================================
local function BuildNitRows(parent, width)
    local W = width or (SIDE_W - PAD*2)

    -- ── Sub-tab strip: Lockouts | Guild | Friends | Layer ────────────────────
    -- NIT pane has 2 sub-tabs: Lockouts | Layer
    local stHalf = math.floor(W / 2)

    local subBarBg = parent:CreateTexture(nil, "BACKGROUND")
    subBarBg:SetPoint("TOPLEFT",  parent, "TOPLEFT",  0, 0)
    subBarBg:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, 0)
    subBarBg:SetHeight(16)
    subBarBg:SetColorTexture(0.05, 0.05, 0.09, 1)

    local function MakeSubTab(label, xOff, key)
        local btn = CreateFrame("Button", nil, parent)
        btn:SetSize(stHalf, 16)
        btn:SetPoint("TOPLEFT", parent, "TOPLEFT", xOff, 0)
        local bg = btn:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints(btn) ; bg:SetColorTexture(0.06, 0.06, 0.10, 1)
        local tx = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        tx:SetFont(tx:GetFont(), 8, "OUTLINE")
        tx:SetAllPoints() ; tx:SetJustifyH("CENTER")
        tx:SetText(label) ; tx:SetTextColor(0.45, 0.45, 0.55)
        btn.bg = bg ; btn.tx = tx
        btn:SetScript("OnClick", function()
            nitSubTab = key
            SC_RefreshNIT()
        end)
        return btn
    end

    nitSubLockBtn  = MakeSubTab("Lockouts", 0,       "locks")
    nitSubLayerBtn = MakeSubTab("Layer",    stHalf,  "layer")

    -- thin separator below sub-tab strip
    local subSep = parent:CreateTexture(nil, "ARTWORK")
    subSep:SetPoint("TOPLEFT",  parent, "TOPLEFT",  0, -16)
    subSep:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, -16)
    subSep:SetHeight(1)
    subSep:SetColorTexture(0.18, 0.18, 0.26, 1)

    -- ── Lockout content (shown when nitSubTab == "locks") ────────────────────
    local lockContent = CreateFrame("Frame", nil, parent)
    lockContent:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -17)
    lockContent:SetSize(W, 18 + MAX_NIT_LOCK_ROWS * 18)
    nitLockContent = lockContent

    local lh = lockContent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    lh:SetFont(lh:GetFont(), 10, "OUTLINE")
    lh:SetPoint("TOPLEFT", lockContent, "TOPLEFT", 0, 0)
    lh:SetText("|cffffff99Alt Instance Lockouts|r")

    local si = lockContent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    si:SetFont(si:GetFont(), 8, "")
    si:SetPoint("TOPRIGHT", lockContent, "TOPRIGHT", 0, 0)
    si:SetJustifyH("RIGHT") ; si:SetTextColor(0.45, 0.45, 0.50)
    nitScrollInfoLabel = si

    -- Broadcast all alts' lockouts to party/raid/say
    local bcBtn = CreateFrame("Button", nil, lockContent)
    bcBtn:SetSize(70, 14)
    bcBtn:SetPoint("TOPRIGHT", lockContent, "TOPRIGHT", 0, -18)
    local bcBg = bcBtn:CreateTexture(nil, "BACKGROUND")
    bcBg:SetAllPoints() ; bcBg:SetColorTexture(0.08, 0.22, 0.38, 0.90)
    local bcHl = bcBtn:CreateTexture(nil, "HIGHLIGHT")
    bcHl:SetAllPoints() ; bcHl:SetColorTexture(0.20, 0.50, 0.80, 0.35)
    local bcTx = bcBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    bcTx:SetFont(bcTx:GetFont(), 8, "OUTLINE")
    bcTx:SetAllPoints() ; bcTx:SetJustifyH("CENTER")
    bcTx:SetText("|cff88ccff>> Broadcast|r")
    bcBtn:SetScript("OnClick", function() SC_BroadcastLockouts() end)
    bcBtn:SetScript("OnEnter", function()
        GameTooltip:SetOwner(bcBtn, "ANCHOR_LEFT")
        GameTooltip:SetText("Broadcast Lockouts", 1, 1, 1)
        GameTooltip:AddLine("Post all alts' lockouts to party, raid, or /say.", 0.7, 0.7, 0.7, true)
        GameTooltip:Show()
    end)
    bcBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    for i = 1, MAX_NIT_LOCK_ROWS do
        local yOff = -(18 + (i-1)*18)
        local row = CreateFrame("Frame", nil, lockContent)
        row:SetSize(W, 17)
        row:SetPoint("TOPLEFT", lockContent, "TOPLEFT", 0, yOff)

        local bg = row:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints(row) ; bg:SetColorTexture(0, 0, 0, 0)
        row.bg = bg

        local nm = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        nm:SetFont(nm:GetFont(), 9, "")
        nm:SetPoint("LEFT", row, "LEFT", 2, 0)
        nm:SetJustifyH("LEFT") ; nm:SetWidth(148)
        row.nm = nm

        local df = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        df:SetFont(df:GetFont(), 8, "")
        df:SetPoint("LEFT", row, "LEFT", 155, 0)
        df:SetJustifyH("LEFT") ; df:SetWidth(70)
        row.df = df

        local tm = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        tm:SetFont(tm:GetFont(), 8, "")
        tm:SetPoint("RIGHT", row, "RIGHT", -2, 0)
        tm:SetJustifyH("RIGHT")
        row.tm = tm

        row:Hide()
        nitLockRows[i] = row
    end

    -- ── Friends content (moved to BuildSocialRows — see below) ───────────────
    -- ── Friends Section placeholder: kept here for nitFriendsContent ref ─────
    -- (Guild and Friends UIs are built in BuildSocialRows, called in BuildWingFrame)

    -- ── Layer content (shown when nitSubTab == "layer") ──────────────────────
    local layerContent = CreateFrame("Frame", nil, parent)
    layerContent:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -17)
    layerContent:SetSize(W, 18 + MAX_NIT_LOCK_ROWS * 18)
    layerContent:Hide()
    nitLayerContent = layerContent

    local layerNumBig = layerContent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    layerNumBig:SetFont(layerNumBig:GetFont(), 48, "OUTLINE")
    layerNumBig:SetPoint("TOP", layerContent, "TOP", 0, -24)
    layerNumBig:SetText("|cff444466--|r")
    nitLayerLabel = layerNumBig

    local layerCaption = layerContent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    layerCaption:SetFont(layerCaption:GetFont(), 10, "OUTLINE")
    layerCaption:SetPoint("TOP", layerNumBig, "BOTTOM", 0, -4)
    layerCaption:SetText("|cff6688bbyour current layer|r")

    local layerSrcFs = layerContent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    layerSrcFs:SetFont(layerSrcFs:GetFont(), 8, "")
    layerSrcFs:SetPoint("TOP", layerCaption, "BOTTOM", 0, -6)
    layerSrcFs:SetTextColor(0.40, 0.40, 0.50)
    layerSrcFs:SetText("")
    nitLayerSrcLabel = layerSrcFs

    local layerHintFs = layerContent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    layerHintFs:SetFont(layerHintFs:GetFont(), 9, "")
    layerHintFs:SetPoint("TOP", layerSrcFs, "BOTTOM", 0, -20)
    layerHintFs:SetWidth(W - 16)
    layerHintFs:SetJustifyH("CENTER")
    layerHintFs:SetTextColor(0.28, 0.28, 0.36)
    layerHintFs:SetText("Target any NPC in a capital city\nto detect your layer")
end

-- ============================================================
-- BuildSocialRows: Friends & Guild pane (separate wing from NIT)
-- ============================================================
local function BuildSocialRows(parent, width)
    local W = width or (SIDE_W - PAD*2)
    local stHalf = math.floor(W / 2)

    local subBarBg = parent:CreateTexture(nil, "BACKGROUND")
    subBarBg:SetPoint("TOPLEFT",  parent, "TOPLEFT",  0, 0)
    subBarBg:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, 0)
    subBarBg:SetHeight(16) ; subBarBg:SetColorTexture(0.05, 0.05, 0.09, 1)

    local function MakeSocialTab(label, xOff, key)
        local btn = CreateFrame("Button", nil, parent)
        btn:SetSize(stHalf, 16)
        btn:SetPoint("TOPLEFT", parent, "TOPLEFT", xOff, 0)
        local bg = btn:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints(btn) ; bg:SetColorTexture(0.06, 0.06, 0.10, 1)
        local tx = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        tx:SetFont(tx:GetFont(), 8, "OUTLINE")
        tx:SetAllPoints() ; tx:SetJustifyH("CENTER")
        tx:SetText(label) ; tx:SetTextColor(0.45, 0.45, 0.55)
        btn.bg = bg ; btn.tx = tx
        btn:SetScript("OnClick", function()
            socialSubTab = key
            if key == "guild" then
                if C_GuildInfo then C_GuildInfo.GuildRoster()
                elseif GuildRoster then GuildRoster() end
            elseif key == "friends" then
                if C_FriendList and C_FriendList.ShowFriends then C_FriendList.ShowFriends()
                elseif ShowFriends then ShowFriends() end
            end
            SC_RefreshSocial()
        end)
        return btn
    end

    nitSubGuildBtn   = MakeSocialTab("Guild",   0,       "guild")
    nitSubFriendsBtn = MakeSocialTab("Friends", stHalf,  "friends")

    local subSep = parent:CreateTexture(nil, "ARTWORK")
    subSep:SetPoint("TOPLEFT",  parent, "TOPLEFT",  0, -16)
    subSep:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, -16)
    subSep:SetHeight(1) ; subSep:SetColorTexture(0.18, 0.18, 0.26, 1)

    -- ── Guild content ─────────────────────────────────────────────────────────
    local guildContent = CreateFrame("Frame", nil, parent)
    guildContent:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -17)
    guildContent:SetSize(W, 18 + MAX_NIT_LOCK_ROWS * 18)
    guildContent:Hide()
    nitGuildContent = guildContent

    local gh = guildContent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    gh:SetFont(gh:GetFont(), 10, "OUTLINE")
    gh:SetPoint("TOPLEFT", guildContent, "TOPLEFT", 0, 0)
    gh:SetText("|cffffff99Online Guildies|r")
    nitGuildHeaderFs = gh

    for i = 1, MAX_NIT_LOCK_ROWS do
        local yOff = -(18 + (i-1)*18)
        local row = CreateFrame("Button", nil, guildContent)
        row:SetSize(W, 17)
        row:SetPoint("TOPLEFT", guildContent, "TOPLEFT", 0, yOff)
        row:RegisterForClicks("LeftButtonUp")
        local bg = row:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints(row) ; bg:SetColorTexture(0.05, 0.05, 0.08, i % 2 == 0 and 0.45 or 0)
        row.bg = bg
        local hl = row:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints(row) ; hl:SetColorTexture(1, 1, 1, 0.07)
        local ly = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        ly:SetFont(ly:GetFont(), 9, "OUTLINE")
        ly:SetPoint("LEFT", row, "LEFT", 2, 0) ; ly:SetJustifyH("CENTER") ; ly:SetWidth(22)
        row.ly = ly
        local nm = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        nm:SetFont(nm:GetFont(), 9, "")
        nm:SetPoint("LEFT", row, "LEFT", 26, 0) ; nm:SetJustifyH("LEFT") ; nm:SetWidth(155)
        row.nm = nm
        local zn = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        zn:SetFont(zn:GetFont(), 8, "")
        zn:SetPoint("RIGHT", row, "RIGHT", -2, 0) ; zn:SetJustifyH("RIGHT") ; zn:SetWidth(W - 26 - 155 - 4)
        row.zn = zn
        row:SetScript("OnEnter", function(self)
            if self._name then
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT") ; GameTooltip:SetText(self._name, 1, 1, 1)
                GameTooltip:AddLine("Click to whisper", 0.5, 0.5, 0.5) ; GameTooltip:Show()
            end
        end)
        row:SetScript("OnLeave", function() GameTooltip:Hide() end)
        row:Hide() ; nitGuildRows[i] = row
    end

    -- ── Friends content ───────────────────────────────────────────────────────
    local friendsContent = CreateFrame("Frame", nil, parent)
    friendsContent:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -17)
    friendsContent:SetSize(W, 18 + MAX_NIT_LOCK_ROWS * 18)
    friendsContent:Hide()
    nitFriendsContent = friendsContent

    local fh = friendsContent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    fh:SetFont(fh:GetFont(), 10, "OUTLINE")
    fh:SetPoint("TOPLEFT", friendsContent, "TOPLEFT", 0, 0)
    fh:SetText("|cffffff99Friends|r") ; nitFriendsHeaderFs = fh

    local frRefreshBtn = CreateFrame("Button", nil, friendsContent)
    frRefreshBtn:SetSize(36, 14) ; frRefreshBtn:SetPoint("TOPRIGHT", friendsContent, "TOPRIGHT", 0, 0)
    local frRBg = frRefreshBtn:CreateTexture(nil, "BACKGROUND")
    frRBg:SetAllPoints() ; frRBg:SetColorTexture(0.10, 0.20, 0.35, 0.85)
    local frRHl = frRefreshBtn:CreateTexture(nil, "HIGHLIGHT")
    frRHl:SetAllPoints() ; frRHl:SetColorTexture(0.25, 0.50, 0.80, 0.40)
    local frRTx = frRefreshBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    frRTx:SetFont(frRTx:GetFont(), 8, "OUTLINE")
    frRTx:SetAllPoints() ; frRTx:SetJustifyH("CENTER") ; frRTx:SetText("|cffaaddffRefresh|r")
    frRefreshBtn:SetScript("OnClick", function()
        if C_FriendList and C_FriendList.ShowFriends then C_FriendList.ShowFriends()
        elseif ShowFriends then ShowFriends() end
        SC_RefreshNITFriends()
    end)

    for i = 1, MAX_NIT_LOCK_ROWS do
        local yOff = -(18 + (i-1)*18)
        local row = CreateFrame("Button", nil, friendsContent)
        row:SetSize(W, 17)
        row:SetPoint("TOPLEFT", friendsContent, "TOPLEFT", 0, yOff)
        row:RegisterForClicks("LeftButtonUp")
        local bg = row:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints(row) ; bg:SetColorTexture(0.05, 0.05, 0.08, i % 2 == 0 and 0.45 or 0)
        row.bg = bg
        local hl = row:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints(row) ; hl:SetColorTexture(1, 1, 1, 0.07)
        local dot = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        dot:SetFont(dot:GetFont(), 10, "OUTLINE")
        dot:SetPoint("LEFT", row, "LEFT", 2, 0) ; dot:SetWidth(10) ; dot:SetJustifyH("CENTER")
        row.dot = dot
        local nm = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        nm:SetFont(nm:GetFont(), 9, "")
        nm:SetPoint("LEFT", row, "LEFT", 14, 0) ; nm:SetJustifyH("LEFT") ; nm:SetWidth(130)
        row.nm = nm
        local lv = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        lv:SetFont(lv:GetFont(), 8, "")
        lv:SetPoint("LEFT", row, "LEFT", 146, 0) ; lv:SetJustifyH("LEFT") ; lv:SetWidth(28)
        row.lv = lv
        local ar = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        ar:SetFont(ar:GetFont(), 8, "")
        ar:SetPoint("RIGHT", row, "RIGHT", -2, 0) ; ar:SetJustifyH("RIGHT") ; ar:SetWidth(W - 14 - 130 - 28 - 6)
        row.ar = ar
        row:SetScript("OnEnter", function(self)
            if self._name then
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT") ; GameTooltip:SetText(self._name, 1, 1, 1)
                GameTooltip:AddLine("Click to whisper", 0.5, 0.5, 0.5) ; GameTooltip:Show()
            end
        end)
        row:SetScript("OnLeave", function() GameTooltip:Hide() end)
        row:Hide() ; nitFriendsRows[i] = row
    end
end

-- ============================================================
-- SC_BroadcastLockouts: send all alts' lockouts to chat
-- ============================================================
function SC_BroadcastLockouts()
    local now = time()
    local chars = {}  -- [{name, locks=[{name,diff,reset}]}]

    local hasNIT = NIT and NIT.db and NIT.db.global
    if hasNIT then
        local realm = GetRealmName and GetRealmName() or ""
        local myChars = NIT.db.global[realm] and NIT.db.global[realm].myChars
        if myChars then
            local me = UnitName("player") or ""
            local names = {}
            for cn in pairs(myChars) do names[#names+1] = cn end
            table.sort(names, function(a,b)
                if a == me then return true end
                if b == me then return false end
                return a < b
            end)
            for _, cn in ipairs(names) do
                local saved = myChars[cn] and myChars[cn].savedInstances
                if saved and next(saved) then
                    local locks = {}
                    for _, inst in pairs(saved) do locks[#locks+1] = inst end
                    table.sort(locks, function(a,b) return (a.resetTime or 0) < (b.resetTime or 0) end)
                    chars[#chars+1] = {name=cn, locks=locks}
                end
            end
        end
    end

    if #chars == 0 then
        local numSaved = GetNumSavedInstances and GetNumSavedInstances() or 0
        if numSaved > 0 then
            local me = UnitName("player") or "?"
            local locks = {}
            for i = 1, numSaved do
                local n, _, reset, _, _, _, _, _, _, diffName = GetSavedInstanceInfo(i)
                if n then locks[#locks+1] = {name=n, difficultyName=diffName, resetTime=reset} end
            end
            chars[#chars+1] = {name=me, locks=locks}
        end
    end

    if #chars == 0 then
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ccff[SlyChar]|r No lockouts to broadcast.")
        return
    end

    local channel = "SAY"
    if IsInRaid and IsInRaid() then channel = "RAID"
    elseif IsInGroup and IsInGroup() then channel = "PARTY" end

    local function FmtTime(secs)
        if secs <= 0 then return "exp" end
        local d = math.floor(secs / 86400)
        local h = math.floor((secs % 86400) / 3600)
        local m = math.floor((secs % 3600) / 60)
        if d > 0 then return d.."d"..h.."h" end
        if h > 0 then return h.."h"..m.."m" end
        return m.."m"
    end

    for _, e in ipairs(chars) do
        local parts = {}
        for _, inst in ipairs(e.locks) do
            local diff = inst.difficultyName or ""
            local tr   = FmtTime((inst.resetTime or 0) - now)
            parts[#parts+1] = inst.name .. (diff ~= "" and " ["..diff.."]" or "") .. " "..tr
        end
        local msg = "["..e.name.."] " .. table.concat(parts, " | ")
        if #msg > 250 then msg = msg:sub(1, 247) .. "..." end
        SendChatMessage(msg, channel)
    end
end

-- ============================================================
-- Macro wing — build and refresh
-- ============================================================
local function TryCreateMacro(m)
    local idx = GetMacroIndexByName(m.name)
    if idx and idx > 0 then
        EditMacro(idx, m.name, m.icon, m.body)
        print("|cff00ccff[SlyChar]|r Updated macro: |cffaadd88" .. m.name .. "|r")
    else
        local ok, err = pcall(CreateMacro, m.name, m.icon, m.body)
        if ok then
            print("|cff00ccff[SlyChar]|r Created macro: |cffaadd88" .. m.name .. "|r")
        else
            print("|cff00ccff[SlyChar]|r Macro slots full or error — |cffff8844" .. tostring(err) .. "|r")
        end
    end
end

local function BuildMacroWing(parent, W)
    local playerClass = select(2, UnitClass("player")) or "WARRIOR"
    local SPECS = CLASS_SPECS[playerClass] or { "All" }
    local tabW  = math.floor(W / #SPECS)

    -- Spec filter strip
    local specStrip = CreateFrame("Frame", nil, parent)
    specStrip:SetSize(W, 18)
    specStrip:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
    FillBg(specStrip, 0.05, 0.05, 0.09, 1)

    for i, spec in ipairs(SPECS) do
        local btn = CreateFrame("Button", nil, specStrip)
        btn:SetSize(tabW, 18)
        btn:SetPoint("TOPLEFT", specStrip, "TOPLEFT", (i-1)*tabW, 0)
        local bg = btn:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints(btn) ; bg:SetColorTexture(0.05, 0.05, 0.09, 1)
        btn.bg = bg
        local hl = btn:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints(btn) ; hl:SetColorTexture(1, 1, 1, 0.07)
        local tx = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        tx:SetFont(tx:GetFont(), 9, "OUTLINE") ; tx:SetAllPoints(btn)
        tx:SetJustifyH("CENTER") ; tx:SetText(spec) ; tx:SetTextColor(0.50, 0.50, 0.60)
        btn.tx = tx
        btn:SetScript("OnClick", function()
            macroSpecFilter = spec ; macroScrollOff = 0 ; SC_RefreshMacros()
        end)
        macroSpecBtns[spec] = btn
    end

    -- Macro rows
    local ROW_H     = 17
    local CREATE_W  = 46
    local rowsFrame = CreateFrame("Frame", nil, parent)
    rowsFrame:SetSize(W, MAX_MACRO_ROWS * (ROW_H + 1))
    rowsFrame:SetPoint("TOPLEFT", specStrip, "BOTTOMLEFT", 0, -2)

    for i = 1, MAX_MACRO_ROWS do
        local row = CreateFrame("Button", nil, rowsFrame)
        row:SetSize(W, ROW_H)
        row:SetPoint("TOPLEFT", rowsFrame, "TOPLEFT", 0, -(i-1)*(ROW_H+1))
        row:RegisterForClicks("LeftButtonUp")
        local bg = row:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints(row) ; bg:SetColorTexture(0, 0, 0, i%2==0 and 0.12 or 0)
        row.bg = bg
        local hl = row:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints(row) ; hl:SetColorTexture(1, 1, 1, 0.07)
        -- Spec badge
        local sp = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        sp:SetFont(sp:GetFont(), 7, "OUTLINE")
        sp:SetPoint("LEFT", row, "LEFT", 2, 0) ; sp:SetWidth(28) ; sp:SetJustifyH("LEFT")
        row.spec = sp
        -- Name
        local nm = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        nm:SetFont(nm:GetFont(), 9, "")
        nm:SetPoint("LEFT", row, "LEFT", 32, 0)
        nm:SetWidth(W - 32 - CREATE_W - 6) ; nm:SetJustifyH("LEFT")
        row.nm = nm
        -- Create button
        local cb = CreateFrame("Button", nil, row)
        cb:SetSize(CREATE_W, ROW_H - 2) ; cb:SetPoint("RIGHT", row, "RIGHT", -2, 0)
        cb:EnableMouse(true)
        local cbbg = cb:CreateTexture(nil, "BACKGROUND")
        cbbg:SetAllPoints(cb) ; cbbg:SetColorTexture(0.08, 0.22, 0.08, 0.90)
        local cbhl = cb:CreateTexture(nil, "HIGHLIGHT")
        cbhl:SetAllPoints(cb) ; cbhl:SetColorTexture(0.25, 0.60, 0.25, 0.40)
        local cbtx = cb:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        cbtx:SetFont(cbtx:GetFont(), 8, "OUTLINE") ; cbtx:SetAllPoints(cb)
        cbtx:SetJustifyH("CENTER") ; cbtx:SetText("|cff88ff88Create|r")
        row.createBtn = cb
        row:Hide()
        macroRows[i] = row
    end

    -- Scroll info
    local siTx = rowsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    siTx:SetFont(siTx:GetFont(), 8, "")
    siTx:SetPoint("TOPLEFT", rowsFrame, "BOTTOMLEFT", 0, -2)
    siTx:SetWidth(W) ; siTx:SetJustifyH("CENTER") ; siTx:SetTextColor(0.45, 0.45, 0.55)
    macroScrollLabel = siTx
end

function SC_RefreshMacros()
    local SPEC_COLORS = {
        Arms="|cffffaa44", Fury="|cffff6644", Tank="|cff4488ff", PvP="|cffdd44ff",
    }
    -- Style spec filter tabs
    for spec, btn in pairs(macroSpecBtns) do
        local active = (macroSpecFilter == spec)
        if active then
            btn.bg:SetColorTexture(0.12, 0.18, 0.32, 1) ; btn.tx:SetTextColor(0.75, 0.88, 1.00)
        else
            btn.bg:SetColorTexture(0.05, 0.05, 0.09, 1) ; btn.tx:SetTextColor(0.40, 0.40, 0.50)
        end
    end
    -- Filter macro list
    local playerClass = select(2, UnitClass("player")) or "WARRIOR"
    local macroList   = (SLYCHAR_CLASS_MACROS and SLYCHAR_CLASS_MACROS[playerClass]) or {}
    local filtered = {}
    for _, m in ipairs(macroList) do
        if macroSpecFilter == "All" or m.spec == macroSpecFilter then
            filtered[#filtered+1] = m
        end
    end
    local total = #filtered
    macroScrollOff = math.max(0, math.min(macroScrollOff, math.max(0, total - MAX_MACRO_ROWS)))
    -- Populate rows
    for i = 1, MAX_MACRO_ROWS do
        local row = macroRows[i]
        if not row then break end
        local m = filtered[macroScrollOff + i]
        if not m then row:Hide() else
            row:Show()
            local scol = SPEC_COLORS[m.spec] or "|cffaaaaaa"
            row.spec:SetText(scol .. m.spec:sub(1, 4) .. "|r")
            row.nm:SetText("|cffdddddd" .. m.name .. "|r")
            local macro = m
            row.createBtn:SetScript("OnClick", function() TryCreateMacro(macro) end)
            row:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(macro.name, 1, 0.85, 0.30)
                GameTooltip:AddLine(macro.tip, 0.80, 0.80, 0.80, true)
                GameTooltip:AddLine(" ", 1, 1, 1)
                for line in (macro.body or ""):gmatch("[^\n]+") do
                    GameTooltip:AddLine("  " .. line, 0.55, 0.90, 0.55)
                end
                GameTooltip:AddLine(" ", 1, 1, 1)
                GameTooltip:AddLine("|cff888888[Create] adds it to your macro book|r", 0.5, 0.5, 0.5)
                GameTooltip:Show()
            end)
            row:SetScript("OnLeave", function() GameTooltip:Hide() end)
            row.bg:SetColorTexture(0, 0, 0, i%2==0 and 0.12 or 0)
        end
    end
    if macroScrollLabel then
        if total > MAX_MACRO_ROWS then
            macroScrollLabel:SetText(string.format("%d\xe2\x80\x93%d / %d  \xe2\x87\x95",
                macroScrollOff+1, math.min(macroScrollOff+MAX_MACRO_ROWS, total), total))
        else
            macroScrollLabel:SetText(total .. " macros")
        end
    end
end

local function FormatNITTime(secs)
    if secs <= 0 then return "|cffff4444Expired|r" end
    local d = math.floor(secs / 86400)
    local h = math.floor((secs % 86400) / 3600)
    local m = math.floor((secs % 3600) / 60)
    if d > 0 then
        local col = d >= 2 and "55ff55" or "ffff55"
        return string.format("|cff%s%dd %dh|r", col, d, h)
    elseif h > 0 then
        local col = h >= 4 and "ffff55" or "ff8800"
        return string.format("|cff%s%dh %dm|r", col, h, m)
    else
        return string.format("|cffff4444%dm|r", m)
    end
end

-- ── Layer detection (mirrors NWB:setCurrentLayerText) ──────────────────────
function SC_UpdateNITLayer(unit)
    if not nitLayerLabel then return end

    -- Prefer NWB's already-computed value (most accurate).
    -- NWB sets the global NWB_CurrentLayer and NWB.currentLayer whenever
    -- you target or mouseover a creature; we just read it.
    local layerNum = (NWB_CurrentLayer and NWB_CurrentLayer > 0 and NWB_CurrentLayer)
                  or (NWB and NWB.currentLayer and NWB.currentLayer > 0 and NWB.currentLayer)
                  or (NWB and NWB.lastKnownLayer and NWB.lastKnownLayer > 0 and NWB.lastKnownLayer)

    -- Fallback: if NWB is loaded but hasn't set a value yet, parse the GUID
    -- ourselves using NWB's own layer dataset (same logic NWB:setCurrentLayerText uses).
    if not layerNum and unit and NWB and NWB.data and NWB.data.layers then
        local GUID = UnitGUID(unit)
        if GUID then
            local unitType, _, _, _, zoneID = strsplit("-", GUID)
            if unitType == "Creature" and zoneID then
                local zID = tonumber(zoneID)
                if zID then
                    local count = 0
                    -- NWB iterates with pairsByKeys (sorted); replicate that here
                    local sortedKeys = {}
                    for k in pairs(NWB.data.layers) do sortedKeys[#sortedKeys+1] = k end
                    table.sort(sortedKeys)
                    for _, k in ipairs(sortedKeys) do
                        count = count + 1
                        if k == zID then layerNum = count; break end
                    end
                end
            end
        end
    end

    if layerNum and layerNum > 0 then
        local src
        if NWB_CurrentLayer and NWB_CurrentLayer > 0 then
            src = "source: NWB (live)"
        elseif NWB and NWB.lastKnownLayer and NWB.lastKnownLayer > 0 then
            src = "source: NWB (last known)"
        else
            src = "source: GUID detection"
        end
        nitLayerLabel:SetText(string.format("|cff00ff00%d|r", layerNum))
        if nitLayerSrcLabel then nitLayerSrcLabel:SetText(src) end
    else
        nitLayerLabel:SetText("|cff444466--|r")
        if nitLayerSrcLabel then nitLayerSrcLabel:SetText("") end
    end
end

-- ── Friends refresh ────────────────────────────────────────────────────────
function SC_RefreshNITFriends()
    for _, r in ipairs(nitFriendsRows) do r:Hide() end
    if not nitFriendsContent or not nitFriendsContent:IsShown() then return end

    -- Do NOT call ShowFriends() here — it is async and triggers FRIENDLIST_UPDATE.
    -- It is called from the sub-tab click; we just read whatever is cached now.
    -- TBC Anniversary: C_FriendList.GetFriendInfoByIndex exists in some builds;
    -- C_FriendList.GetFriendInfo takes a NAME not an index so must not be used here.
    -- Fall back to the legacy global GetFriendInfo(index) which works in TBC 2.5.x.
    local total = (C_FriendList and C_FriendList.GetNumFriends and C_FriendList.GetNumFriends())
               or (GetNumFriends and GetNumFriends() or 0)
    local onlineCount = 0
    local shown = 0
    for i = 1, total do
        local name, level, area, connected
        if C_FriendList and C_FriendList.GetFriendInfoByIndex then
            local info = C_FriendList.GetFriendInfoByIndex(i)
            if info then
                name      = info.name
                level     = info.level
                area      = info.area
                connected = info.connected
            end
        elseif GetFriendInfo then
            local _class
            name, level, _class, area, connected = GetFriendInfo(i)
        end
        if connected then onlineCount = onlineCount + 1 end
        if name and shown < MAX_NIT_LOCK_ROWS then
            shown = shown + 1
            local row = nitFriendsRows[shown]
            row._name = name
            if connected then
                row.dot:SetText("|cff00ee44•|r")
                row.nm:SetText("|cffdddddd" .. name .. "|r")
            else
                row.dot:SetText("|cff444455•|r")
                row.nm:SetText("|cff666677" .. name .. "|r")
            end
            row.lv:SetText("|cff888888" .. (level or "?") .. "|r")
            row.ar:SetText("|cff555566" .. (area or "") .. "|r")
            row:SetScript("OnClick", function()
                if ChatFrame1EditBox then
                    ChatFrame1EditBox:Show()
                    ChatFrame1EditBox:SetText("/w " .. name .. " ")
                    ChatFrame1EditBox:SetCursorPosition(1000)
                    ChatFrame1EditBox:SetFocus()
                end
            end)
            row:Show()
        end
    end
    if nitFriendsHeaderFs then
        nitFriendsHeaderFs:SetText(string.format(
            "|cffffff99Friends|r |cff00ee44%d|r|cff888888/%d|r", onlineCount, total))
    end

end

-- ── Guild layer refresh ─────────────────────────────────────────────────────
function SC_RefreshNITGuild()
    for _, r in ipairs(nitGuildRows) do r:Hide() end
    if not nitGuildContent or not nitGuildContent:IsShown() then return end

    if not IsInGuild or not IsInGuild() then
        if nitGuildHeaderFs then nitGuildHeaderFs:SetText("|cff888888Not in a guild|r") end
        return
    end

    local realm = GetRealmName and GetRealmName() or ""

    -- Collect online guild members
    local numTotal = GetNumGuildMembers and GetNumGuildMembers() or 0
    local members = {}
    for i = 1, numTotal do
        local name, _, _, level, _, zone, _, _, isOnline, _, classFile = GetGuildRosterInfo(i)
        if isOnline and name then
            local charName = name:match("^([^%-]+)") or name
            -- Layer from NWB.hasL["CharName-Realm"] = "layerNum"
            local layerNum = nil
            if NWB and NWB.hasL then
                local v = NWB.hasL[charName .. "-" .. realm]
                if v then layerNum = tonumber(v) end
            end
            members[#members+1] = {
                name  = charName,
                class = (classFile or ""):upper(),
                zone  = zone or "",
                layer = layerNum,
            }
        end
    end

    -- Sort: known layers first (ascending), then alphabetical
    table.sort(members, function(a, b)
        local la, lb = a.layer or 999, b.layer or 999
        if la ~= lb then return la < lb end
        return a.name < b.name
    end)

    if nitGuildHeaderFs then
        nitGuildHeaderFs:SetText(string.format(
            "|cffffff99Online Guildies|r |cff888888(%d)|r", #members))
    end

    for i = 1, MAX_NIT_LOCK_ROWS do
        local row = nitGuildRows[i]
        local m   = members[i]
        if m then
            -- Layer cell
            if m.layer then
                row.ly:SetText(string.format("|cff00ee44%d|r", m.layer))
            else
                row.ly:SetText("|cff444455?|r")
            end
            -- Name with class color
            local cc = "aaaaaa"
            if RAID_CLASS_COLORS and RAID_CLASS_COLORS[m.class] then
                local c = RAID_CLASS_COLORS[m.class]
                cc = string.format("%02x%02x%02x",
                    math.floor((c.r or 0)*255),
                    math.floor((c.g or 0)*255),
                    math.floor((c.b or 0)*255))
            end
            row.nm:SetText(string.format("|cff%s%s|r", cc, m.name))
            -- Zone
            row.zn:SetText("|cff555566" .. m.zone .. "|r")
            -- Whisper on click
            row._name = m.name
            row:SetScript("OnClick", function()
                if ChatFrame1EditBox then
                    ChatFrame1EditBox:Show()
                    ChatFrame1EditBox:SetText("/w " .. m.name .. " ")
                    ChatFrame1EditBox:SetCursorPosition(1000)
                    ChatFrame1EditBox:SetFocus()
                end
            end)
            row:Show()
        else
            row._name = nil
            row:Hide()
        end
    end
end

function SC_RefreshNIT()
    -- Style sub-tab buttons to reflect active selection
    local function StyleSub(btn, active)
        if not btn then return end
        if active then
            btn.bg:SetColorTexture(0.12, 0.18, 0.32, 1)
            btn.tx:SetTextColor(0.75, 0.88, 1.00)
        else
            btn.bg:SetColorTexture(0.05, 0.05, 0.09, 1)
            btn.tx:SetTextColor(0.40, 0.40, 0.50)
        end
    end
    StyleSub(nitSubLockBtn,  nitSubTab == "locks")
    StyleSub(nitSubLayerBtn, nitSubTab == "layer")

    -- Show / hide content panels
    if nitLockContent  then nitLockContent:SetShown(nitSubTab == "locks") end
    if nitLayerContent then nitLayerContent:SetShown(nitSubTab == "layer") end

    if nitSubTab == "layer" then
        SC_UpdateNITLayer("target")
        return
    end

    -- ── Lockouts sub-tab ──────────────────────────────────────────────────────
    for _, w in ipairs(nitLockRows) do w:Hide() end
    if nitScrollInfoLabel then nitScrollInfoLabel:SetText("") end

    local now = time()
    local entries = {}  -- flat list: {type="char"|"lock", ...}

    -- Build entry list from NIT SavedVariables (all alts)
    local hasNIT = NIT and NIT.db and NIT.db.global
    if hasNIT then
        local realm = GetRealmName and GetRealmName() or ""
        local realmData = NIT.db.global[realm]
        local myChars  = realmData and realmData.myChars
        if myChars then
            local charNames = {}
            for cn in pairs(myChars) do charNames[#charNames+1] = cn end
            table.sort(charNames)
            local me = UnitName("player") or ""
            -- Sort: current char first, then alphabetical
            table.sort(charNames, function(a, b)
                if a == me then return true end
                if b == me then return false end
                return a < b
            end)
            for _, cn in ipairs(charNames) do
                local cData   = myChars[cn]
                local saved   = cData and cData.savedInstances
                if saved and next(saved) then
                    entries[#entries+1] = {type="char", name=cn, isMe=(cn==me)}
                    -- Collect + sort by reset time
                    local locks = {}
                    for _, inst in pairs(saved) do
                        locks[#locks+1] = inst
                    end
                    table.sort(locks, function(a,b)
                        return (a.resetTime or 0) < (b.resetTime or 0)
                    end)
                    for _, inst in ipairs(locks) do
                        entries[#entries+1] = {
                            type="lock",
                            name=inst.name,
                            diff=inst.difficultyName,
                            reset=inst.resetTime,
                            locked=inst.locked,
                        }
                    end
                end
            end
        end
    end

    -- Fallback: native API (current char only) when NIT not loaded
    if #entries == 0 then
        local numSaved = GetNumSavedInstances and GetNumSavedInstances() or 0
        if numSaved > 0 then
            local me = UnitName("player") or "?"
            entries[#entries+1] = {type="char", name=me, isMe=true}
            for i = 1, numSaved do
                local n, _, reset, _, locked, _, _, _, _, diffName = GetSavedInstanceInfo(i)
                if n then
                    entries[#entries+1] = {type="lock", name=n, diff=diffName, reset=reset, locked=locked}
                end
            end
        end
    end

    if #entries == 0 then
        local w = nitLockRows[1]
        if w then
            w:Show()
            w.nm:SetText("|cff666666No lockouts on any alt|r")
            w.df:SetText("") ; w.tm:SetText("")
            w.bg:SetColorTexture(0, 0, 0, 0)
        end
        return
    end

    local total = #entries
    nitLockScrollOffset = math.max(0, math.min(nitLockScrollOffset, math.max(0, total - MAX_NIT_LOCK_ROWS)))

    for i = 1, MAX_NIT_LOCK_ROWS do
        local w = nitLockRows[i]
        if not w then break end
        local e = entries[nitLockScrollOffset + i]
        if not e then break end
        w:Show()
        if e.type == "char" then
            local col = e.isMe and "d4a84f" or "8aaac8"
            w.nm:SetText(string.format("|cff%s%s|r", col, e.name))
            w.df:SetText("")
            w.tm:SetText("")
            w.bg:SetColorTexture(0.08, 0.09, 0.16, 0.80)
        else
            local n = e.name or "?"
            if #n > 22 then n = string.sub(n, 1, 20) .. ".." end
            local lcol = (e.locked == false) and "80ff80" or "ff8800"
            w.nm:SetText("|cff" .. lcol .. n .. "|r")
            w.df:SetText("|cff666666" .. (e.diff or "") .. "|r")
            w.tm:SetText(FormatNITTime((e.reset or 0) - now))
            w.bg:SetColorTexture(0, 0, 0, i%2==0 and 0.08 or 0)
        end
    end

    if nitScrollInfoLabel and total > MAX_NIT_LOCK_ROWS then
        nitScrollInfoLabel:SetText(string.format("%d-%d / %d  ⇕",
            nitLockScrollOffset+1,
            math.min(nitLockScrollOffset+MAX_NIT_LOCK_ROWS, total), total))
    end
end

-- ============================================================
-- Social wing refresh (Friends + Guild)
-- ============================================================
function SC_RefreshSocial()
    local function StyleSub(btn, active)
        if not btn then return end
        if active then
            btn.bg:SetColorTexture(0.12, 0.18, 0.32, 1)
            btn.tx:SetTextColor(0.75, 0.88, 1.00)
        else
            btn.bg:SetColorTexture(0.05, 0.05, 0.09, 1)
            btn.tx:SetTextColor(0.40, 0.40, 0.50)
        end
    end
    StyleSub(nitSubGuildBtn,   socialSubTab == "guild")
    StyleSub(nitSubFriendsBtn, socialSubTab == "friends")
    if nitGuildContent   then nitGuildContent:SetShown(socialSubTab == "guild")   end
    if nitFriendsContent then nitFriendsContent:SetShown(socialSubTab == "friends") end
    if socialSubTab == "guild"   then SC_RefreshNITGuild()   end
    if socialSubTab == "friends" then SC_RefreshNITFriends() end
end

-- ============================================================
-- Tab switching + master refresh
-- ============================================================
function SC_SwitchTab(name)
    -- remap removed top-level keys to their new parents
    if name == "bars" then name = "sets" end
    if name == "rep" or name == "skills" then name = "misc" end
    -- social/nit are wings, not tabs — open the wing panel and redirect
    if name == "nit" then
        SC_ToggleWing("nit")
        name = "stats"
    elseif name == "social" then
        SC_ToggleWing("social")
        name = "stats"
    end
    -- if still unknown, fall back to stats
    if not tabFrames[name] then name = "stats" end
    SC.db.lastTab = name
    for k, tf in pairs(tabFrames) do tf:SetShown(k == name) end
    local th = SC_THEMES[(SC.db and SC.db.theme) or "shadow"] or SC_THEMES.shadow
    for k, tb in pairs(tabBtnWidgets) do
        local a = (k == name)
        local bg = a and th.tabActiveBg   or th.tabInactiveBg
        local tx = a and th.tabActiveTxt  or th.tabInactiveTxt
        tb.bg:SetColorTexture(bg[1], bg[2], bg[3], 1)
        tb.txt:SetTextColor(tx[1], tx[2], tx[3])
        tb.txt:SetFont(tb.txt:GetFont(), a and 11 or 10, a and "OUTLINE" or "")
    end
end

function SC_RefreshSuite()
    if not suiteCont then return end
    local df = SlySuiteDataFrame
    if not df then return end
    local registry = df.registry
    local index    = df.index
    local STATUS   = df.STATUS
    if not registry or #registry == 0 then return end
    if not index or not STATUS then return end
    local ROW_H_S = 22
    local yOff    = 0
    for _, entry in ipairs(registry) do
        local name = entry.name
        local w    = suiteRowWidgets[name]
        if not w then
            local row = CreateFrame("Frame", nil, suiteCont)
            row:SetPoint("TOPLEFT",  suiteCont, "TOPLEFT",  0, 0)
            row:SetPoint("TOPRIGHT", suiteCont, "TOPRIGHT", 0, 0)
            row:SetHeight(ROW_H_S)
            local rbg = row:CreateTexture(nil, "BACKGROUND")
            rbg:SetAllPoints(row) ; rbg:SetColorTexture(0.06, 0.06, 0.10, 0.5)
            local dot = row:CreateTexture(nil, "ARTWORK")
            dot:SetSize(8, 8) ; dot:SetPoint("LEFT", row, "LEFT", 4, 0)
            dot:SetColorTexture(0.4, 0.4, 0.4, 1)
            local nameTx = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            nameTx:SetFont(nameTx:GetFont(), 10, "")
            nameTx:SetPoint("LEFT", dot, "RIGHT", 5, 0)
            nameTx:SetText(name) ; nameTx:SetTextColor(0.9, 0.9, 0.9)
            local statusTx = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            statusTx:SetFont(statusTx:GetFont(), 8, "")
            statusTx:SetPoint("RIGHT", row, "RIGHT", -48, 0)
            statusTx:SetTextColor(0.5, 0.5, 0.5)
            local toggleBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
            toggleBtn:SetSize(40, 16) ; toggleBtn:SetPoint("RIGHT", row, "RIGHT", -2, 0)
            local capName = name
            toggleBtn:SetScript("OnClick", function()
                local df2 = SlySuiteDataFrame
                if not df2 then return end
                local e2 = df2.index and df2.index[capName]
                if not e2 or not df2.STATUS then return end
                if e2.dbRecord.enabled and e2.status ~= df2.STATUS.DISABLED then
                    if df2.disableMod then df2.disableMod(capName) end
                else
                    if df2.enableMod  then df2.enableMod(capName)  end
                end
                SC_RefreshSuite()
            end)
            w = { row=row, dot=dot, nameTx=nameTx, statusTx=statusTx, toggleBtn=toggleBtn }
            suiteRowWidgets[name] = w
        end
        w.row:ClearAllPoints()
        w.row:SetPoint("TOPLEFT",  suiteCont, "TOPLEFT",  0, yOff)
        w.row:SetPoint("TOPRIGHT", suiteCont, "TOPRIGHT", 0, yOff)
        w.row:Show()
        yOff = yOff - ROW_H_S
        local e = index[name]
        if e then
            local s = e.status
            if     s == STATUS.OK       then w.dot:SetColorTexture(0.2, 0.9, 0.2, 1)
            elseif s == STATUS.ERROR    then w.dot:SetColorTexture(0.9, 0.2, 0.2, 1)
            elseif s == STATUS.DISABLED then w.dot:SetColorTexture(0.4, 0.4, 0.4, 1)
            else                             w.dot:SetColorTexture(1.0, 0.82, 0.0, 1)
            end
            local enabled = e.dbRecord.enabled and e.status ~= STATUS.DISABLED
            w.toggleBtn:SetText(enabled and "|cff44ff44ON|r" or "|cffaaaaaa OFF|r")
            w.statusTx:SetText(s or "?")
            w.nameTx:SetTextColor(
                s == STATUS.ERROR    and 1.0 or
                s == STATUS.DISABLED and 0.5 or 0.9,
                s == STATUS.ERROR    and 0.4 or
                s == STATUS.DISABLED and 0.5 or 0.9,
                s == STATUS.ERROR    and 0.4 or
                s == STATUS.DISABLED and 0.5 or 0.9)
        end
    end
    suiteCont:SetHeight(math.max(-yOff, 1))
    if suiteErrLabel then
        local df2 = SlySuiteDataFrame
        local n = (df2 and df2.db and df2.db.errorLog and #df2.db.errorLog) or 0
        suiteErrLabel:SetText(n .. " error" .. (n==1 and "" or "s") .. " on disk")
        suiteErrLabel:SetTextColor(n > 0 and 1.0 or 0.45, n > 0 and 0.5 or 0.45, n > 0 and 0.4 or 0.5)
    end
end

function SC_RefreshAll()
    RefreshHeader()
    SC_RefreshSlots()
    local tab = SC.db.lastTab or "stats"
    if     tab == "stats"  then SC_RefreshStats()
    elseif tab == "sets"   then SC_RefreshSetsSub()
    elseif tab == "misc"   then SC_RefreshMisc()
    elseif tab == "suite"  then SC_RefreshSuite()
    end
    -- Refresh whichever wing is currently open
    if wingFrame and wingFrame:IsShown() then
        if activeWingKey == "nit"    then SC_RefreshNIT()    end
        if activeWingKey == "social" then SC_RefreshSocial() end
        if activeWingKey == "macros" then SC_RefreshMacros() end
    end
end

function SC_RefreshWhelp()
    local panel = _G["SlyWhelpPanelFrame"]
    if not panel then return end
    local cont = panel._cont
    if not cont then return end

    for _, r in ipairs(panel._rows) do r:Hide() end
    if panel._statusMsg then panel._statusMsg:Hide() end

    local function showStatus(text)
        if panel._statusMsg then
            panel._statusMsg:SetText(text)
            panel._statusMsg:Show()
        end
        cont:SetHeight(20)
    end

    if not (Whelp and Whelp.VendorManager and Whelp.Database and Whelp.db) then
        showStatus("|cffff8844Whelp not loaded.|r")
        return
    end

    local vendors = Whelp.VendorManager:GetVendors({}, "rating") or {}
    if #vendors == 0 then
        showStatus("|cff888888No vendors yet. Click +Add.|r")
        return
    end

    local shown = math.min(#vendors, #panel._rows)
    for i = 1, shown do
        local vendor = vendors[i]
        local row    = panel._rows[i]
        row._nameFS:SetText("|cffffffff" .. (vendor.name or "Unknown") .. "|r")
        local avg    = vendor.averageRating or 0
        local filled = math.min(5, math.max(0, math.floor(avg + 0.5)))
        local stars  = string.rep("*", filled) .. string.rep("-", 5 - filled)
        row._ratingFS:SetText(string.format("|cffffd700%s|r |cff888888%.1f (%d)|r",
            stars, avg, vendor.reviewCount or 0))
        local vref = vendor
        row._viewBtn:SetScript("OnClick", function()
            if Whelp and Whelp.UI and Whelp.UI.MainFrame then
                local mf = Whelp.UI.MainFrame:Create()
                Whelp.UI.MainFrame:SelectTab("browse")
                mf:Show()
                -- navigate to detail if VendorDetail available
                if Whelp.UI.VendorDetail then
                    Whelp.UI.VendorDetail:Show(vref)
                end
            end
        end)
        row:Show()
    end
    cont:SetHeight(math.max(20, shown * 28))
end

-- ============================================================
-- Native side-panel helper
-- Each strip button calls SC_ToggleSidePanel(frame).
-- Frames are shown via ShowUIPanel (or :Show()), then repositioned
-- one frame later via C_Timer.After(0) after the panel manager settles.
-- SetUserPlaced(true) stops subsequent repositioning.
-- ============================================================
local function SC_AnchorRight(tf)
    pcall(function() tf:SetUserPlaced(true) end)
    if SlyCharMainFrame then
        tf:ClearAllPoints()
        tf:SetPoint("TOPLEFT", SlyCharMainFrame, "TOPRIGHT", 4, 0)
    end
end

local function SC_EnsureHooked(tf)
    if not tf or hookedPanels[tf] then return end
    hookedPanels[tf] = true
    tf:HookScript("OnHide", function()
        if currentSidePanel == tf then
            currentSidePanel = nil
            pcall(function() tf:SetUserPlaced(false) end)
        end
    end)
end

function SC_CloseSidePanel()
    if not currentSidePanel then return end
    local tf = currentSidePanel
    currentSidePanel = nil
    pcall(function() tf:SetUserPlaced(false) end)
    tf:Hide()
end

local function SC_ToggleSidePanel(tf)
    if not tf then return end
    SC_EnsureHooked(tf)
    if tf == currentSidePanel and tf:IsShown() then
        SC_CloseSidePanel() ; return
    end
    if currentSidePanel and currentSidePanel ~= tf then
        SC_CloseSidePanel()
    end
    currentSidePanel = tf
    -- Use :Show() directly — never ShowUIPanel — so WoW's panel manager
    -- never gets a chance to reposition the frame.
    -- SC_AnchorRight sets position synchronously after OnShow fires.
    tf:Show()
    SC_AnchorRight(tf)
end

local function SC_GetTalentFrame()
    if PlayerTalentFrame then return PlayerTalentFrame end
    if TalentFrame       then return TalentFrame       end
    if LoadAddOn         then LoadAddOn("Blizzard_TalentUI") end
    return PlayerTalentFrame or TalentFrame or nil
end

-- Resolve a UI panel frame, loading its LoD addon if needed.
-- If the frame still doesn't exist, call fallbackFn() instead.
local function SC_OpenPanel(addonName, frameGlobal, fallbackFn)
    if not _G[frameGlobal] and LoadAddOn then
        LoadAddOn(addonName)
    end
    local tf = _G[frameGlobal]
    if tf then
        SC_ToggleSidePanel(tf)
    elseif fallbackFn then
        fallbackFn()
    end
end

-- Wing Panel — slides out to the right of the main frame.
-- Keys: "social" (NIT), "spells", "talents"
-- ============================================================
function SC_ToggleWing(key)
    if not wingFrame then return end
    if activeWingKey == key and wingFrame:IsShown() then
        wingFrame:Hide() ; activeWingKey = nil ; return
    end
    activeWingKey = key
    for k, p in pairs(wingPanes) do
        if k == key then p:Show() else p:Hide() end
    end
    local macrosTitle = ((UnitClass and UnitClass("player")) or "Class") .. " Macros"
    local WING_TITLES = { social="Friends & Guild", nit="Lockouts & Layer", spells="Spellbook", talents="Talents", macros=macrosTitle, rep="Reputation", skills="Skills", honor="Honor" }
    if wingTitleTx then wingTitleTx:SetText(WING_TITLES[key] or key) end
    wingFrame:Show()
    if key == "spells"  then SC_RefreshSpells()      end
    if key == "social"  then SC_RefreshSocial()      end
    if key == "nit"     then SC_RefreshNIT()         end
    if key == "macros"  then SC_RefreshMacros()      end
    if key == "rep"     then SC_RefreshReputation()  end
    if key == "skills"  then SC_RefreshSkills()      end
    if key == "honor"   then SC_RefreshHonor()       end
end


function SC_RefreshSpells()
    for _, r in ipairs(spellRows) do r.frame:Hide() end
    local ri = 0
    local numTabs = GetNumSpellTabs and GetNumSpellTabs() or 0
    for tab = 1, numTabs do
        local tabName, _, offset, numSpells = GetSpellTabInfo(tab)
        ri = ri + 1 ; if ri > MAX_SPELL_ROWS then break end
        local rh = spellRows[ri]
        rh.frame:Show() ; rh.spellIdx = nil
        rh.lbl:SetText("|cff7799ff" .. (tabName or "?") .. "|r")
        rh.rank:SetText("")
        rh.frame:SetScript("OnEnter", nil) ; rh.frame:SetScript("OnLeave", nil)
        for s = offset + 1, offset + numSpells do
            local sName, sSubName = GetSpellBookItemName(s, BOOKTYPE_SPELL)
            local sType           = GetSpellBookItemInfo(s, BOOKTYPE_SPELL)
            if sName and sType ~= "FUTURESPELL" then
                ri = ri + 1 ; if ri > MAX_SPELL_ROWS then break end
                local rw = spellRows[ri]
                local spIdx = s
                rw.frame:Show() ; rw.spellIdx = spIdx
                rw.lbl:SetText("|cffdddddd" .. sName .. "|r")
                rw.rank:SetText(sSubName and ("|cff666666" .. sSubName .. "|r") or "")
                rw.frame:SetScript("OnEnter", function()
                    GameTooltip:SetOwner(rw.frame, "ANCHOR_LEFT")
                    GameTooltip:SetSpellBookItem(spIdx, BOOKTYPE_SPELL)
                    GameTooltip:Show()
                end)
                rw.frame:SetScript("OnLeave", function() GameTooltip:Hide() end)
            end
        end
    end
end

local function BuildWingFrame(mainFrame)
    if wingFrame then return end
    -- Parent to UIParent to avoid child-frame strata/clipping issues;
    -- reposition whenever the main frame shows or moves.
    local f = CreateFrame("Frame", "SlyCharWingFrame", UIParent)
    f:SetSize(WING_W, FRAME_H)
    f:SetPoint("TOPLEFT", mainFrame, "TOPRIGHT", 0, 0)
    f:SetFrameStrata("DIALOG")
    f:SetFrameLevel(mainFrame:GetFrameLevel())
    f:Hide()
    wingFrame = f
    ThemeFill(f, "sideBg", 0.04, 0.04, 0.07, 1)

    -- Left join border (uses theme border colour)
    local lbord = ThemeTex(f, "border", "ARTWORK", 0.25, 0.20, 0.38, 1)
    lbord:SetSize(2, FRAME_H)
    lbord:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)

    -- Header
    local hdr = CreateFrame("Frame", nil, f)
    hdr:SetSize(WING_W - 2, HDR_H)
    hdr:SetPoint("TOPLEFT", f, "TOPLEFT", 2, 0)
    ThemeFill(hdr, "headerBg", 0.07, 0.06, 0.12, 1)

    local htx = hdr:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    htx:SetFont(htx:GetFont(), 12, "OUTLINE")
    htx:SetPoint("LEFT", hdr, "LEFT", 10, 0)
    htx:SetTextColor(0.85, 0.70, 1.00)
    htx:SetText("Talents")
    wingTitleTx = htx

    local closeBtn = CreateFrame("Button", nil, hdr, "UIPanelCloseButton")
    closeBtn:SetSize(24, 24)
    closeBtn:SetPoint("RIGHT", hdr, "RIGHT", -4, 0)
    closeBtn:SetScript("OnClick", function()
        f:Hide() ; activeWingKey = nil
    end)

    local hdrSep = ThemeTex(f, "sep", "ARTWORK", 0.25, 0.20, 0.38, 1)
    hdrSep:SetSize(WING_W, 1)
    hdrSep:SetPoint("TOPLEFT", f, "TOPLEFT", 2, -HDR_H)

    -- ---- Talent Pane ----
    local talentPane = CreateFrame("Frame", nil, f)
    talentPane:SetPoint("TOPLEFT",     f, "TOPLEFT",     2, -(HDR_H + 1))
    talentPane:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, FOOT_H)
    ThemeFill(talentPane, "sideBg", 0.04, 0.04, 0.07, 1)
    wingPanes["talents"] = talentPane

    -- Talent pane is an empty backdrop; the native TalentFrame is reparented
    -- into it by SC_EmbedTalentFrame() each time the wing opens.

    -- ---- Spellbook Pane ----
    local spellPane = CreateFrame("Frame", nil, f)
    spellPane:SetPoint("TOPLEFT",     f, "TOPLEFT",     2, -(HDR_H + 1))
    spellPane:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, FOOT_H)
    spellPane:Hide()
    ThemeFill(spellPane, "sideBg", 0.04, 0.04, 0.07, 1)
    wingPanes["spells"] = spellPane

    local spellScroll = CreateFrame("ScrollFrame", nil, spellPane, "UIPanelScrollFrameTemplate")
    spellScroll:SetPoint("TOPLEFT",     spellPane, "TOPLEFT",     PAD, -4)
    spellScroll:SetPoint("BOTTOMRIGHT", spellPane, "BOTTOMRIGHT", -22,  4)
    local spellCont = CreateFrame("Frame", nil, spellScroll)
    spellCont:SetSize(WING_W - PAD*2 - 22, MAX_SPELL_ROWS * 16)
    spellScroll:SetScrollChild(spellCont)

    for i = 1, MAX_SPELL_ROWS do
        local row = CreateFrame("Frame", nil, spellCont)
        row:SetSize(WING_W - PAD*2 - 22, 16)
        row:SetPoint("TOPLEFT", spellCont, "TOPLEFT", 0, -(i-1)*16)
        row:EnableMouse(true) ; row:Hide()
        local rbg = row:CreateTexture(nil, "BACKGROUND")
        rbg:SetAllPoints(row)
        rbg:SetColorTexture(0, 0, 0, i%2==0 and 0.10 or 0)
        local lbl = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        lbl:SetFont(lbl:GetFont(), 9, "")
        lbl:SetPoint("LEFT", row, "LEFT", 4, 0)
        lbl:SetWidth((WING_W - PAD*2 - 22) * 0.70) ; lbl:SetJustifyH("LEFT")
        local rank = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        rank:SetFont(rank:GetFont(), 8, "")
        rank:SetPoint("RIGHT", row, "RIGHT", -2, 0) ; rank:SetJustifyH("RIGHT")
        spellRows[i] = {frame=row, lbl=lbl, rank=rank, spellIdx=nil}
    end

    -- ---- NIT Pane (Lockouts + Layer) ----
    local nitPane = CreateFrame("Frame", nil, f)
    nitPane:SetPoint("TOPLEFT",     f, "TOPLEFT",     2, -(HDR_H + 1))
    nitPane:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, FOOT_H)
    nitPane:Hide()
    ThemeFill(nitPane, "sideBg", 0.04, 0.04, 0.07, 1)
    wingPanes["nit"] = nitPane

    local nitCont = CreateFrame("Frame", nil, nitPane)
    nitCont:SetPoint("TOPLEFT", nitPane, "TOPLEFT", PAD, -4)
    nitCont:SetSize(WING_W - PAD*2, 17 + 18 + MAX_NIT_LOCK_ROWS * 18)
    BuildNitRows(nitCont, WING_W - PAD*2)

    nitPane:EnableMouseWheel(true)
    nitPane:SetScript("OnMouseWheel", function(self, delta)
        nitLockScrollOffset = math.max(0, nitLockScrollOffset - delta)
        SC_RefreshNIT()
    end)

    -- ---- Social Pane (Friends + Guild) ----
    local socialPane = CreateFrame("Frame", nil, f)
    socialPane:SetPoint("TOPLEFT",     f, "TOPLEFT",     2, -(HDR_H + 1))
    socialPane:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, FOOT_H)
    socialPane:Hide()
    ThemeFill(socialPane, "sideBg", 0.04, 0.04, 0.07, 1)
    wingPanes["social"] = socialPane

    local socialCont = CreateFrame("Frame", nil, socialPane)
    socialCont:SetPoint("TOPLEFT", socialPane, "TOPLEFT", PAD, -4)
    socialCont:SetSize(WING_W - PAD*2, 17 + 18 + MAX_NIT_LOCK_ROWS * 18)
    BuildSocialRows(socialCont, WING_W - PAD*2)

    -- ---- Macros Pane (Warrior macro library) ----
    local macroPaneF = CreateFrame("Frame", nil, f)
    macroPaneF:SetPoint("TOPLEFT",     f, "TOPLEFT",     2, -(HDR_H + 1))
    macroPaneF:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, FOOT_H)
    macroPaneF:Hide()
    ThemeFill(macroPaneF, "sideBg", 0.04, 0.04, 0.07, 1)
    wingPanes["macros"] = macroPaneF

    local macroCont = CreateFrame("Frame", nil, macroPaneF)
    macroCont:SetPoint("TOPLEFT", macroPaneF, "TOPLEFT", PAD, -4)
    macroCont:SetSize(WING_W - PAD*2, 18 + MAX_MACRO_ROWS * 18 + 14)
    BuildMacroWing(macroCont, WING_W - PAD*2)

    macroPaneF:EnableMouseWheel(true)
    macroPaneF:SetScript("OnMouseWheel", function(self, delta)
        macroScrollOff = math.max(0, macroScrollOff - delta)
        SC_RefreshMacros()
    end)

    -- ---- Rep Pane ----
    local repPane = CreateFrame("Frame", nil, f)
    repPane:SetPoint("TOPLEFT",     f, "TOPLEFT",     2, -(HDR_H + 1))
    repPane:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, FOOT_H)
    repPane:Hide()
    wingPanes["rep"] = repPane

    local repPaneScroll = CreateFrame("ScrollFrame", nil, repPane, "UIPanelScrollFrameTemplate")
    repPaneScroll:SetPoint("TOPLEFT",     repPane, "TOPLEFT",      PAD, -4)
    repPaneScroll:SetPoint("BOTTOMRIGHT", repPane, "BOTTOMRIGHT", -22,   4)
    local repPaneCont = CreateFrame("Frame", nil, repPaneScroll)
    repPaneCont:SetSize(WING_W - PAD*2 - 22, MAX_REP_ROWS * 16)
    repPaneScroll:SetScrollChild(repPaneCont)
    BuildRepRows(repPaneCont)
    repPane:EnableMouseWheel(true)
    repPane:SetScript("OnMouseWheel", function(self, delta)
        repPaneScroll:SetVerticalScroll(
            math.max(0, repPaneScroll:GetVerticalScroll() - delta * 20))
    end)

    -- ---- Skills Pane ----
    local skillPane = CreateFrame("Frame", nil, f)
    skillPane:SetPoint("TOPLEFT",     f, "TOPLEFT",     2, -(HDR_H + 1))
    skillPane:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, FOOT_H)
    skillPane:Hide()
    wingPanes["skills"] = skillPane

    local skillPaneScroll = CreateFrame("ScrollFrame", nil, skillPane, "UIPanelScrollFrameTemplate")
    skillPaneScroll:SetPoint("TOPLEFT",     skillPane, "TOPLEFT",      PAD, -4)
    skillPaneScroll:SetPoint("BOTTOMRIGHT", skillPane, "BOTTOMRIGHT", -22,   4)
    local skillPaneCont = CreateFrame("Frame", nil, skillPaneScroll)
    skillPaneCont:SetSize(WING_W - PAD*2 - 22, MAX_SKILL_ROWS * 14)
    skillPaneScroll:SetScrollChild(skillPaneCont)
    BuildSkillRows(skillPaneCont)
    skillPane:EnableMouseWheel(true)
    skillPane:SetScript("OnMouseWheel", function(self, delta)
        skillPaneScroll:SetVerticalScroll(
            math.max(0, skillPaneScroll:GetVerticalScroll() - delta * 16))
    end)

    -- ---- Honor Pane ----
    local honorPane = CreateFrame("Frame", nil, f)
    honorPane:SetPoint("TOPLEFT",     f, "TOPLEFT",     2, -(HDR_H + 1))
    honorPane:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, FOOT_H)
    honorPane:Hide()
    wingPanes["honor"] = honorPane
    miscUI.honorContent = honorPane   -- SC_RefreshHonor guards on IsShown()

    local honorPaneRows = {}
    for i = 1, 11 do
        local row = CreateFrame("Frame", nil, honorPane)
        row:SetPoint("TOPLEFT",  honorPane, "TOPLEFT",   PAD, -((i-1)*14 + 4))
        row:SetPoint("TOPRIGHT", honorPane, "TOPRIGHT", -PAD, -((i-1)*14 + 4))
        row:SetHeight(14) ; row:Hide()
        local rbg = row:CreateTexture(nil, "BACKGROUND")
        rbg:SetAllPoints() ; rbg:SetColorTexture(0, 0, 0, 0)
        row.bg = rbg
        local lbl = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        lbl:SetFont(lbl:GetFont(), 9, "")
        lbl:SetPoint("LEFT", row, "LEFT", 0, 0)
        lbl:SetWidth((WING_W - PAD*2) * 0.52) ; lbl:SetJustifyH("LEFT")
        row.lbl = lbl
        local val = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        val:SetFont(val:GetFont(), 9, "")
        val:SetPoint("RIGHT", row, "RIGHT", 0, 0)
        val:SetWidth((WING_W - PAD*2) * 0.46) ; val:SetJustifyH("RIGHT")
        row.val = val
        honorPaneRows[i] = row
    end
    miscUI._honorRows = honorPaneRows

    -- Wing footer stripe
    local wingFoot = CreateFrame("Frame", nil, f)
    wingFoot:SetSize(WING_W, FOOT_H)
    wingFoot:SetPoint("BOTTOM", f, "BOTTOM", 0, 0)
    ThemeFill(wingFoot, "footBg", 0.07, 0.07, 0.10, 1)
end

-- ============================================================
-- Build main frame (lazy, called once)
-- ============================================================
function SC_BuildMain()
    if SlyCharMainFrame then return end

    local f = CreateFrame("Frame", "SlyCharMainFrame", UIParent)
    f:SetSize(FRAME_W, FRAME_H)
    f:SetFrameStrata("DIALOG")
    f:SetFrameLevel(100)  -- pre-set above CharacterFrame; avoid level changes in combat
    f:SetMovable(true)
    f:EnableMouse(false)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local pt, _, _, x, y = self:GetPoint()
        SC.db.position = {point=pt or "CENTER", x=x or 0, y=y or 0}
    end)
    f:SetPoint("CENTER")
    f:Hide()

    themeRefs.frameBg   = FillBg(f, 0.05, 0.05, 0.07, 0.97)
    local bord = f:CreateTexture(nil, "OVERLAY")
    bord:SetAllPoints(f) ; bord:SetColorTexture(0.28, 0.28, 0.35, 1)
    themeRefs.frameBord  = bord
    local inner = f:CreateTexture(nil, "BACKGROUND")
    inner:SetPoint("TOPLEFT",     f, "TOPLEFT",      1, -1)
    inner:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -1,  1)
    inner:SetColorTexture(0.05, 0.05, 0.07, 0.97)
    themeRefs.frameInner = inner

    -- Header
    local hdr = CreateFrame("Frame", nil, f)
    hdr:SetSize(FRAME_W, HDR_H)
    hdr:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
    themeRefs.hdrBg = FillBg(hdr, 0.09, 0.09, 0.14, 1)

    headerName = hdr:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    headerName:SetFont(headerName:GetFont(), 13, "OUTLINE")
    headerName:SetPoint("LEFT", hdr, "LEFT", PAD, 0)
    headerName:SetText("...")

    headerInfo = hdr:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    headerInfo:SetFont(headerInfo:GetFont(), 10, "")
    headerInfo:SetPoint("CENTER", hdr, "CENTER", 0, 0)
    headerInfo:SetTextColor(0.65, 0.65, 0.65)

    -- Plain (non-secure) close button — works in combat, no UIPanelCloseButton template
    local closeBtn = CreateFrame("Button", nil, hdr)
    closeBtn:SetSize(24, 24)
    closeBtn:SetPoint("RIGHT", hdr, "RIGHT", -2, 0)
    closeBtn:EnableMouse(true)
    closeBtn:RegisterForClicks("LeftButtonUp")
    local closeBg = closeBtn:CreateTexture(nil, "BACKGROUND")
    closeBg:SetAllPoints() ; closeBg:SetColorTexture(0, 0, 0, 0)
    local closeHl = closeBtn:CreateTexture(nil, "HIGHLIGHT")
    closeHl:SetAllPoints() ; closeHl:SetColorTexture(0.9, 0.2, 0.2, 0.35)
    local closeTx = closeBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    closeTx:SetFont(closeTx:GetFont(), 16, "OUTLINE")
    closeTx:SetAllPoints() ; closeTx:SetJustifyH("CENTER") ; closeTx:SetJustifyV("MIDDLE")
    closeTx:SetText("\195\151")  -- UTF-8 × (U+00D7)
    closeTx:SetTextColor(0.80, 0.30, 0.30)
    closeBtn:SetScript("OnClick", function() f:Hide() end)
    closeBtn:SetScript("OnEnter", function() closeBg:SetColorTexture(0.7, 0.15, 0.15, 0.40) end)
    closeBtn:SetScript("OnLeave", function() closeBg:SetColorTexture(0, 0, 0, 0) end)

    local resetBtn = CreateFrame("Button", nil, hdr, "UIPanelButtonTemplate")
    resetBtn:SetSize(18, 18)
    resetBtn:SetPoint("RIGHT", closeBtn, "LEFT", -4, 0)
    resetBtn:SetText("o")
    resetBtn:SetScript("OnClick", function()
        SC.db.position = nil
        f:ClearAllPoints() ; f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end)
    resetBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:SetText("Reset position", 1,1,1) ; GameTooltip:Show()
    end)
    resetBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- Open native character screen button
    local chrBtn = CreateFrame("Button", nil, hdr)
    chrBtn:SetSize(32, 18)
    chrBtn:SetPoint("RIGHT", resetBtn, "LEFT", -4, 0)
    chrBtn:EnableMouse(true)
    chrBtn:RegisterForClicks("LeftButtonUp")
    local chrBtnBg = chrBtn:CreateTexture(nil, "BACKGROUND")
    chrBtnBg:SetAllPoints(chrBtn) ; chrBtnBg:SetColorTexture(0.08, 0.14, 0.08, 0.90)
    local chrBtnHl = chrBtn:CreateTexture(nil, "HIGHLIGHT")
    chrBtnHl:SetAllPoints(chrBtn) ; chrBtnHl:SetColorTexture(1, 1, 1, 0.12)
    local chrBtnTx = chrBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    chrBtnTx:SetFont(chrBtnTx:GetFont(), 9, "OUTLINE")
    chrBtnTx:SetAllPoints(chrBtn) ; chrBtnTx:SetJustifyH("CENTER")
    chrBtnTx:SetText("|cff88ff88Chr|r")
    chrBtn:SetScript("OnClick", function()
        -- Use _skipHook so the CharacterFrame OnShow interceptor ignores this click.
        SC._skipHook = true
        if CharacterFrame:IsShown() then
            CharacterFrame:Hide()
        else
            -- Show directly (not via ShowUIPanel/ToggleCharacter) to avoid the
            -- UISpecialFrames auto-hide that would close SlyChar.
            CharacterFrame:Show()
            -- Re-show SlyChar in case WoW triggered any hide side-effect.
            if SlyCharMainFrame and not SlyCharMainFrame:IsShown() then
                SlyCharMainFrame:Show()
            end
        end
        SC._skipHook = false
    end)
    chrBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:SetText("Toggle paper-doll frame", 1, 1, 1)
        GameTooltip:AddLine("Opens the default WoW character frame alongside SlyChar", 0.7, 0.7, 0.7)
        GameTooltip:AddLine("Required for enchant scroll targeting", 0.5, 0.5, 0.5)
        GameTooltip:Show()
    end)
    chrBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- Theme cycle button
    local themeBtn = CreateFrame("Button", nil, hdr)
    themeBtn:SetSize(56, 18)
    themeBtn:SetPoint("RIGHT", chrBtn, "LEFT", -4, 0)
    themeBtn:EnableMouse(true)
    themeBtn:RegisterForClicks("LeftButtonUp")
    local themeBtnBg = themeBtn:CreateTexture(nil, "BACKGROUND")
    themeBtnBg:SetAllPoints(themeBtn)
    themeBtnBg:SetColorTexture(0.12, 0.12, 0.20, 0.90)
    local themeBtnHl = themeBtn:CreateTexture(nil, "HIGHLIGHT")
    themeBtnHl:SetAllPoints(themeBtn)
    themeBtnHl:SetColorTexture(1, 1, 1, 0.12)
    local themeBtnTx = themeBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    themeBtnTx:SetFont(themeBtnTx:GetFont(), 9, "OUTLINE")
    themeBtnTx:SetAllPoints(themeBtn) ; themeBtnTx:SetJustifyH("CENTER")
    themeBtnTx:SetText("|cffbbbbffShadow|r")
    themeBtn:SetScript("OnClick", SC_CycleTheme)
    themeBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:SetText("Cycle theme", 1, 0.82, 0)
        for _, k in ipairs(SC_THEME_ORDER) do
            local isActive = (SC.db.theme == k)
            GameTooltip:AddLine((isActive and "|cffffd700> " or "  ") .. SC_THEMES[k].name .. (isActive and " (active)|r" or ""), 0.8, 0.8, 0.8)
        end
        GameTooltip:Show()
    end)
    themeBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    themeRefs.themeBtn = themeBtnTx

    -- Header drag: drag the empty chrome area to move the whole frame
    hdr:EnableMouse(true)
    hdr:RegisterForDrag("LeftButton")
    hdr:SetScript("OnDragStart", function() f:StartMoving() end)
    hdr:SetScript("OnDragStop", function()
        f:StopMovingOrSizing()
        local pt, _, _, x, y = f:GetPoint()
        SC.db.position = { point = pt or "CENTER", x = x or 0, y = y or 0 }
    end)

    local hdrSep = f:CreateTexture(nil, "ARTWORK")
    hdrSep:SetSize(FRAME_W, 1)
    hdrSep:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -HDR_H)
    hdrSep:SetColorTexture(0.25, 0.25, 0.32, 1)
    themeRefs.hdrSep = hdrSep

    -- Character body (gear + model)
    local charBody = CreateFrame("Frame", nil, f)
    charBody:SetSize(CHAR_W, FRAME_H - HDR_H - FOOT_H)
    charBody:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -HDR_H)

    local div = f:CreateTexture(nil, "ARTWORK")
    div:SetSize(1, FRAME_H - HDR_H - FOOT_H)
    div:SetPoint("TOPLEFT", f, "TOPLEFT", CHAR_W, -HDR_H)
    div:SetColorTexture(0.20, 0.20, 0.27, 1)
    themeRefs.charDiv = div

    -- GearScore label — top-centre of character pane, between gear columns
    headerGS = charBody:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    headerGS:SetFont(headerGS:GetFont(), 10, "OUTLINE")
    headerGS:SetPoint("TOP", charBody, "TOP", 0, -4)
    headerGS:SetTextColor(1.00, 0.80, 0.10)
    headerGS:SetText("")

    for i, s in ipairs(LEFT_SLOTS) do
        BuildSlot(charBody, s.id, s.label,
            COL_L, SLOT_TOP - (i-1)*(SLOT_S+SLOT_GAP))
    end
    for i, s in ipairs(RIGHT_SLOTS) do
        BuildSlot(charBody, s.id, s.label,
            COL_R, SLOT_TOP - (i-1)*(SLOT_S+SLOT_GAP))
    end
    for i, s in ipairs(WEAPON_SLOTS) do
        if s.id ~= 0 or _classUsesAmmo then
            BuildSlot(charBody, s.id, s.label,
                WPN_START + (i-1)*(SLOT_S+WPN_GAP), WPN_Y)
        end
    end

    -- Player model
    local modBg = charBody:CreateTexture(nil, "BACKGROUND")
    modBg:SetSize(MODEL_W, MODEL_H)
    modBg:SetPoint("TOPLEFT", charBody, "TOPLEFT", MODEL_X, SLOT_TOP - 12)
    modBg:SetColorTexture(0.03, 0.03, 0.04, 1)
    themeRefs.modelBg = modBg

    local model = CreateFrame("PlayerModel", "SlyCharModel", charBody)
    model:SetSize(MODEL_W, MODEL_H)
    model:SetPoint("TOPLEFT", charBody, "TOPLEFT", MODEL_X, SLOT_TOP - 12)
    model:SetUnit("player")
    model:EnableMouse(true)

    local rot, rotating, lastMX = 0, false, 0
    model:SetScript("OnMouseDown", function(self2, btn)
        if btn == "LeftButton" then
            rotating = true
            lastMX   = select(1, GetCursorPosition())
        end
    end)
    model:SetScript("OnMouseUp", function() rotating = false end)
    model:SetScript("OnUpdate", function(self2)
        if rotating then
            local cx2 = select(1, GetCursorPosition())
            rot    = rot - (cx2 - lastMX) * 0.01
            lastMX = cx2
            self2:SetRotation(rot)
        end
    end)

    -- Side panel
    local side = CreateFrame("Frame", nil, f)
    side:SetSize(SIDE_W, FRAME_H - HDR_H - FOOT_H)
    side:SetPoint("TOPLEFT", f, "TOPLEFT", CHAR_W + 1, -HDR_H)
    themeRefs.sideBg = FillBg(side, 0.05, 0.05, 0.08, 1)

    local tabBar = CreateFrame("Frame", nil, side)
    tabBar:SetSize(SIDE_W, 24)
    tabBar:SetPoint("TOPLEFT", side, "TOPLEFT", 0, 0)
    themeRefs.tabBarBg = FillBg(tabBar, 0.07, 0.07, 0.11, 1)

    local tabDefs = {
        {key="stats",  label="Stats"},
        {key="sets",   label="Sets"},
        {key="misc",   label="Apps"},
    }
    local tbW = math.floor(SIDE_W / #tabDefs)
    for i, td in ipairs(tabDefs) do
        local btn = CreateFrame("Button", nil, tabBar)
        btn:SetSize(tbW, 24)
        btn:SetPoint("TOPLEFT", tabBar, "TOPLEFT", (i-1)*tbW, 0)

        local tbg = btn:CreateTexture(nil, "BACKGROUND")
        tbg:SetAllPoints(btn) ; tbg:SetColorTexture(0.06,0.06,0.09,1)

        local ttx = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        ttx:SetFont(ttx:GetFont(), 10, "")
        ttx:SetPoint("CENTER", btn, "CENTER", 0, 0)
        ttx:SetText(td.label) ; ttx:SetTextColor(0.55, 0.55, 0.60)

        btn:SetScript("OnClick", function()
            SC_SwitchTab(td.key) ; SC_RefreshAll()
        end)
        tabBtnWidgets[td.key] = {btn=btn, bg=tbg, txt=ttx}
    end

    local tabSep = side:CreateTexture(nil, "ARTWORK")
    tabSep:SetSize(SIDE_W, 1)
    tabSep:SetPoint("TOPLEFT", side, "TOPLEFT", 0, -24)
    tabSep:SetColorTexture(0.20, 0.20, 0.27, 1)
    themeRefs.tabSep = tabSep

    local tcY = -25
    local tcH = FRAME_H - HDR_H - FOOT_H - 25

    local statsTab = CreateFrame("Frame", nil, side)
    statsTab:SetPoint("TOPLEFT",  side, "TOPLEFT",  0, tcY)
    statsTab:SetPoint("TOPRIGHT", side, "TOPRIGHT", 0, tcY)
    statsTab:SetHeight(tcH) ; statsTab:Hide()
    tabFrames["stats"] = statsTab

    local statsScroll = CreateFrame("ScrollFrame", nil, statsTab, "UIPanelScrollFrameTemplate")
    statsScroll:SetPoint("TOPLEFT",     statsTab, "TOPLEFT",      PAD,  -2)
    statsScroll:SetPoint("BOTTOMRIGHT", statsTab, "BOTTOMRIGHT", -22,    2)
    local statsCont = CreateFrame("Frame", nil, statsScroll)
    statsCont:SetSize(SIDE_W - PAD*2 - 22, MAX_STAT_ROWS * 24)
    statsScroll:SetScrollChild(statsCont)
    BuildStatRows(statsCont)

    local setsTab = CreateFrame("Frame", nil, side)
    setsTab:SetPoint("TOPLEFT",  side, "TOPLEFT",  0, tcY)
    setsTab:SetPoint("TOPRIGHT", side, "TOPRIGHT", 0, tcY)
    setsTab:SetHeight(tcH) ; setsTab:Hide()
    tabFrames["sets"] = setsTab

    -- Sub-tab strip: [Gear Sets][Bars][BIS]
    local sBW = math.floor(SIDE_W / 3)
    local function MakeSetsSubBtn(label, x)
        local btn = CreateFrame("Button", nil, setsTab)
        btn:SetSize(sBW, 16)
        btn:SetPoint("TOPLEFT", setsTab, "TOPLEFT", x, 0)
        local bbg = btn:CreateTexture(nil, "BACKGROUND")
        bbg:SetAllPoints() ; bbg:SetColorTexture(0.05, 0.05, 0.09, 1)
        btn.bg = bbg
        local btx = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        btx:SetFont(btx:GetFont(), 9, "") ; btx:SetAllPoints()
        btx:SetJustifyH("CENTER") ; btx:SetText(label)
        btx:SetTextColor(0.40, 0.40, 0.50)
        btn.tx = btx
        return btn
    end
    setsUI.subGearBtn = MakeSetsSubBtn("Gear Sets", 0)
    setsUI.subBarsBtn = MakeSetsSubBtn("Bars",      sBW)
    setsUI.subBisBtn  = MakeSetsSubBtn("BIS",       sBW * 2)

    local setSubSep = setsTab:CreateTexture(nil, "ARTWORK")
    setSubSep:SetSize(SIDE_W, 1)
    setSubSep:SetPoint("TOPLEFT", setsTab, "TOPLEFT", 0, -16)
    setSubSep:SetColorTexture(0.18, 0.18, 0.25, 1)

    -- ── Gear Sets content ─────────────────────────────────────────────────────
    local gearContent = CreateFrame("Frame", nil, setsTab)
    gearContent:SetPoint("TOPLEFT",  setsTab, "TOPLEFT",  0, -17)
    gearContent:SetPoint("TOPRIGHT", setsTab, "TOPRIGHT", 0, -17)
    gearContent:SetHeight(tcH - 17)
    setsUI.gearContent = gearContent

    local saveLbl = gearContent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    saveLbl:SetFont(saveLbl:GetFont(), 9, "")
    saveLbl:SetPoint("TOPLEFT", gearContent, "TOPLEFT", PAD, -3)
    saveLbl:SetTextColor(0.5, 0.5, 0.55) ; saveLbl:SetText("Save current as:")

    local saveInput = CreateFrame("EditBox", nil, gearContent, "InputBoxTemplate")
    saveInput:SetSize(SIDE_W - PAD*2 - 52, 17)
    saveInput:SetPoint("TOPLEFT", saveLbl, "BOTTOMLEFT", 0, -1)
    saveInput:SetAutoFocus(false) ; saveInput:SetFontObject("GameFontNormalSmall")
    saveInput:SetScript("OnEscapePressed", function(self2) self2:ClearFocus() end)

    local saveBtn = CreateFrame("Button", nil, gearContent, "UIPanelButtonTemplate")
    saveBtn:SetSize(46, 17) ; saveBtn:SetPoint("LEFT", saveInput, "RIGHT", 3, 0)
    saveBtn:SetText("Save")
    local function doSave()
        local sn = saveInput:GetText()
        if sn and sn:trim() ~= "" and IRR_SaveCurrentSet then
            IRR_SaveCurrentSet(sn:trim())
            saveInput:SetText("") ; saveInput:ClearFocus()
            SC_RefreshSets()
            DEFAULT_CHAT_FRAME:AddMessage(
                "|cff88bbff[SlyChar]|r Saved: |cffffd700"..sn:trim().."|r")
        end
    end
    saveBtn:SetScript("OnClick", doSave)
    saveInput:SetScript("OnEnterPressed", doSave)

    local setSep = gearContent:CreateTexture(nil, "ARTWORK")
    setSep:SetSize(SIDE_W - PAD*2, 1)
    setSep:SetPoint("TOPLEFT", saveInput, "BOTTOMLEFT", 0, -4)
    setSep:SetColorTexture(0.18, 0.18, 0.24, 1)

    local setsCont = CreateFrame("Frame", nil, gearContent)
    setsCont:SetPoint("TOPLEFT", gearContent, "TOPLEFT", PAD, -48)
    setsCont:SetSize(SIDE_W - PAD*2, MAX_SET_ROWS * 22)
    BuildSetRows(setsCont)

    local setsInfo = gearContent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    setsInfo:SetFont(setsInfo:GetFont(), 8, "")
    setsInfo:SetPoint("BOTTOMRIGHT", gearContent, "BOTTOMRIGHT", -4, 4)
    setsInfo:SetTextColor(0.40, 0.40, 0.50)
    setsScrollInfoLabel = setsInfo

    -- ── Bars content ──────────────────────────────────────────────────────────
    local barsContent = CreateFrame("Frame", nil, setsTab)
    barsContent:SetPoint("TOPLEFT",  setsTab, "TOPLEFT",  0, -17)
    barsContent:SetPoint("TOPRIGHT", setsTab, "TOPRIGHT", 0, -17)
    barsContent:SetHeight(tcH - 17)
    setsUI.barsContent = barsContent

    local barsLbl = barsContent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    barsLbl:SetFont(barsLbl:GetFont(), 9, "")
    barsLbl:SetPoint("TOPLEFT", barsContent, "TOPLEFT", PAD, -3)
    barsLbl:SetTextColor(0.5, 0.5, 0.55) ; barsLbl:SetText("Save current bars as:")

    local barsInput = CreateFrame("EditBox", nil, barsContent, "InputBoxTemplate")
    barsInput:SetSize(SIDE_W - PAD*2 - 52, 17)
    barsInput:SetPoint("TOPLEFT", barsLbl, "BOTTOMLEFT", 0, -1)
    barsInput:SetAutoFocus(false) ; barsInput:SetFontObject("GameFontNormalSmall")
    barsInput:SetScript("OnEscapePressed", function(self2) self2:ClearFocus() end)

    local barsSaveBtn = CreateFrame("Button", nil, barsContent, "UIPanelButtonTemplate")
    barsSaveBtn:SetSize(46, 17) ; barsSaveBtn:SetPoint("LEFT", barsInput, "RIGHT", 3, 0)
    barsSaveBtn:SetText("Save")
    local function doSaveBars()
        local sn = barsInput:GetText()
        if sn and sn:trim() ~= "" and SlySlot_SaveProfile then
            SlySlot_SaveProfile(sn:trim())
            barsInput:SetText("") ; barsInput:ClearFocus()
            SC_RefreshBars()
            DEFAULT_CHAT_FRAME:AddMessage(
                "|cff88bbff[SlyChar]|r Bars saved: |cffffd700"..sn:trim().."|r")
        end
    end
    barsSaveBtn:SetScript("OnClick", doSaveBars)
    barsInput:SetScript("OnEnterPressed", doSaveBars)

    local barsSep = barsContent:CreateTexture(nil, "ARTWORK")
    barsSep:SetSize(SIDE_W - PAD*2, 1)
    barsSep:SetPoint("TOPLEFT", barsInput, "BOTTOMLEFT", 0, -4)
    barsSep:SetColorTexture(0.18, 0.18, 0.24, 1)

    local barsCont = CreateFrame("Frame", nil, barsContent)
    barsCont:SetPoint("TOPLEFT", barsContent, "TOPLEFT", PAD, -48)
    barsCont:SetSize(SIDE_W - PAD*2, MAX_BAR_ROWS * 22)
    BuildBarRows(barsCont)

    local barsInfo = barsContent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    barsInfo:SetFont(barsInfo:GetFont(), 8, "")
    barsInfo:SetPoint("BOTTOMRIGHT", barsContent, "BOTTOMRIGHT", -4, 4)
    barsInfo:SetTextColor(0.40, 0.40, 0.50)
    barsScrollInfoLabel = barsInfo

    -- ── BIS content ─────────────────────────────────────────────────────────
    local bisContent = CreateFrame("Frame", nil, setsTab)
    bisContent:SetPoint("TOPLEFT",  setsTab, "TOPLEFT",  0, -17)
    bisContent:SetPoint("TOPRIGHT", setsTab, "TOPRIGHT", 0, -17)
    bisContent:SetHeight(tcH - 17)
    bisContent:Hide()
    setsUI.bisContent = bisContent

    -- Build lazily on first show so IRR is guaranteed loaded regardless of
    -- whether PLAYER_LOGIN already fired (e.g. after /reload).
    local bisBuilt = false
    bisContent:SetScript("OnShow", function()
        if bisBuilt then return end
        bisBuilt = true
        local _buildFn = IRR_BuildBISPanel or _G["IRR_BuildBISPanel"]
        if not _buildFn then
            local noLbl = bisContent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            noLbl:SetPoint("CENTER", bisContent, "CENTER", 0, 0)
            noLbl:SetTextColor(0.5, 0.5, 0.5)
            noLbl:SetText("ItemRackRevived not loaded")
            return
        end
        local ok, err = pcall(_buildFn, bisContent, tcH - 17, SIDE_W)
        if not ok then
            print("|cffff4444[SlyChar BIS]|r build error: " .. tostring(err))
            local errLbl = bisContent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            errLbl:SetPoint("CENTER", bisContent, "CENTER", 0, 0)
            errLbl:SetTextColor(1, 0.3, 0.3)
            errLbl:SetText("BIS error: " .. tostring(err))
        end
    end)

        -- Mouse-wheel dispatches to active sub-tab
    setsTab:EnableMouseWheel(true)
    setsTab:SetScript("OnMouseWheel", function(self, delta)
        if setsUI.subTab == "gear" then
            local names2 = IRR_GetSetNames and IRR_GetSetNames() or {}
            local maxOffset = math.max(0, #names2 - MAX_SET_ROWS)
            setsScrollOffset = math.max(0, math.min(setsScrollOffset - delta, maxOffset))
            SC_RefreshSets()
        elseif setsUI.subTab == "bars" then
            local names2 = {}
            if SlySlot and SlySlot.db then
                for n in pairs(SlySlot.db.profiles) do table.insert(names2, n) end
            end
            local maxOffset = math.max(0, #names2 - MAX_BAR_ROWS)
            barsScrollOffset = math.max(0, math.min(barsScrollOffset - delta, maxOffset))
            SC_RefreshBars()
        end
    end)

    setsUI.subGearBtn:SetScript("OnClick", function()
        setsUI.subTab = "gear" ; SC_RefreshSetsSub()
    end)
    setsUI.subBarsBtn:SetScript("OnClick", function()
        setsUI.subTab = "bars" ; SC_RefreshSetsSub()
    end)
    setsUI.subBisBtn:SetScript("OnClick", function()
        setsUI.subTab = "bis" ; SC_RefreshSetsSub()
    end)

    -- Apps tab — centralized launcher for all panels & wing flyouts
    local miscTab = CreateFrame("Frame", nil, side)
    miscTab:SetPoint("TOPLEFT",  side, "TOPLEFT",  0, tcY)
    miscTab:SetPoint("TOPRIGHT", side, "TOPRIGHT", 0, tcY)
    miscTab:SetHeight(tcH) ; miscTab:Hide()
    tabFrames["misc"] = miscTab

    -- Build the apps grid lazily on first show (ensures wingFrame exists)
    local appsBuilt = false
    miscTab:SetScript("OnShow", function()
        if appsBuilt then return end
        appsBuilt = true
        local APP_ITEMS = {
            { tip="Reputation",      desc="Factions & standing",             lbl="Rep", r=0.70, g=0.85, b=1.00,
              fn=function() SC_ToggleWing("rep")    end },
            { tip="Skills",          desc="Professions & secondary skills",  lbl="Sk",  r=0.65, g=1.00, b=0.65,
              fn=function() SC_ToggleWing("skills") end },
            { tip="Honor",           desc="PvP honor, HKs & arena points",  lbl="Hk",  r=1.00, g=0.45, b=0.45,
              fn=function() SC_ToggleWing("honor")  end },
            { tip="Talents",         desc="Talent tree",                     lbl="T",   r=0.75, g=0.50, b=1.00,
              fn=function() SC_ToggleSidePanel(SC_GetTalentFrame()) end },
            { tip="Spellbook",       desc="Spells & abilities",              lbl="Sp",  r=0.35, g=0.70, b=1.00,
              fn=function() SC_OpenPanel("Blizzard_SpellBookUI","SpellBookFrame",ToggleSpellBook) end },
            { tip="Quest Log",       desc="Active quests",                   lbl="Q",   r=1.00, g=0.78, b=0.15,
              fn=function() SC_OpenPanel("Blizzard_QuestLog","QuestLogFrame",ToggleQuestLog) end },
            { tip="World Map",       desc="World map & locations",           lbl="M",   r=0.25, g=0.85, b=0.30,
              fn=function() SC_OpenPanel("Blizzard_MapCanvas","WorldMapFrame",ToggleWorldMap) end },
            { tip="Bags",            desc="Bag window",                      lbl="B",   r=0.85, g=0.65, b=0.20,
              fn=function()
                  if SlyBagFrame then
                      if SlyBagFrame:IsShown() then SlyBagFrame:Hide()
                      else
                          if SlyBag_Refresh then SlyBag_Refresh() end
                          SlyBagFrame:ClearAllPoints()
                          SlyBagFrame:SetPoint("TOPLEFT", SlyCharMainFrame, "TOPRIGHT", 4, 0)
                          SlyBagFrame:Show()
                      end
                  end
              end },
            { tip="Loot SR",         desc="Soft Res & loot rolls",           lbl="SR",  r=0.20, g=0.90, b=0.50,
              fn=function()
                  if SlyLootPanel and SlyLootPanel:IsShown() then SlyLootPanel:Hide() ; return end
                  if SL_OpenSRTab then SL_OpenSRTab() elseif SL_BuildUI then SL_BuildUI() end
                  if SlyCharMainFrame and SlyLootPanel and SlyLootPanel:IsShown() then
                      SlyLootPanel:SetUserPlaced(true)
                      SlyLootPanel:ClearAllPoints()
                      SlyLootPanel:SetPoint("TOPLEFT", SlyCharMainFrame, "TOPRIGHT", 4, 0)
                  end
              end },
            { tip="Whelp",           desc="Vendor ratings & reviews",        lbl="Wh",  r=0.20, g=0.78, b=1.00,
              fn=function()
                  local wp = _G["SlyWhelpPanelFrame"]
                  if wp then if wp:IsShown() then wp:Hide() else wp:Show() end end
              end },
            { tip="Class Macros",    desc="Macro library for your class",    lbl="Mc",  r=0.95, g=0.70, b=0.20,
              fn=function() SC_ToggleWing("macros") end },
            { tip="Friends & Guild", desc="Online friends and guild members", lbl="Fr",  r=0.40, g=0.90, b=0.60,
              fn=function() SC_ToggleWing("social") end },
            { tip="Lockouts",        desc="Alt lockouts & layer detection",   lbl="NIT", r=0.30, g=0.80, b=1.00,
              fn=function() SC_ToggleWing("nit")    end },
        }
        -- 2-column grid: ceil(13/2)=7 rows × 44px = 322px + 4px top pad = 326px ≤ tcH(329)
        local ROW_H   = 44
        local COL_GAP = 4
        local appW    = SIDE_W - PAD * 2                          -- 314
        local colW    = math.floor((appW - COL_GAP) / 2)         -- 155
        for i, item in ipairs(APP_ITEMS) do
            local col    = (i - 1) % 2                           -- 0 = left, 1 = right
            local rowIdx = math.floor((i - 1) / 2)              -- 0-based row
            local xOff   = PAD + col * (colW + COL_GAP)
            local yOff   = -(rowIdx * (ROW_H + 2) + 4)

            local btn = CreateFrame("Button", nil, miscTab)
            btn:SetSize(colW, ROW_H)
            btn:SetPoint("TOPLEFT", miscTab, "TOPLEFT", xOff, yOff)
            btn:EnableMouse(true)

            local rbg = btn:CreateTexture(nil, "BACKGROUND")
            rbg:SetAllPoints(btn)
            rbg:SetColorTexture(item.r*0.07, item.g*0.07, item.b*0.07, 1)
            btn._rbg = rbg

            local accent = btn:CreateTexture(nil, "ARTWORK")
            accent:SetSize(3, ROW_H)
            accent:SetPoint("LEFT", btn, "LEFT", 0, 0)
            accent:SetColorTexture(item.r, item.g, item.b, 0.85)

            local titleLbl = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            titleLbl:SetFont(titleLbl:GetFont(), 10, "OUTLINE")
            titleLbl:SetPoint("TOPLEFT", btn, "TOPLEFT", 8, -6)
            titleLbl:SetWidth(colW - 10) ; titleLbl:SetJustifyH("LEFT")
            titleLbl:SetText(item.tip)
            titleLbl:SetTextColor(
                math.min(item.r * 0.80 + 0.20, 1),
                math.min(item.g * 0.80 + 0.20, 1),
                math.min(item.b * 0.80 + 0.20, 1))

            local descLbl = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            descLbl:SetFont(descLbl:GetFont(), 8, "")
            descLbl:SetPoint("BOTTOMLEFT", btn, "BOTTOMLEFT", 8, 5)
            descLbl:SetWidth(colW - 10) ; descLbl:SetJustifyH("LEFT")
            descLbl:SetText(item.desc)
            descLbl:SetTextColor(0.45, 0.45, 0.55)

            btn:SetScript("OnEnter", function()
                rbg:SetColorTexture(item.r*0.20, item.g*0.20, item.b*0.20, 1)
            end)
            btn:SetScript("OnLeave", function()
                rbg:SetColorTexture(item.r*0.07, item.g*0.07, item.b*0.07, 1)
            end)
            btn:SetScript("OnClick", function() item.fn() end)
        end
    end)

    -- NIT tab is now a wing flyout; no side-panel tab for social.

    -- Quick-launch button strip (right edge)
    local stripDiv = f:CreateTexture(nil, "ARTWORK")
    stripDiv:SetSize(1, FRAME_H - HDR_H - FOOT_H)
    stripDiv:SetPoint("TOPLEFT", f, "TOPLEFT", CHAR_W + 1 + SIDE_W, -HDR_H)
    stripDiv:SetColorTexture(0.20, 0.20, 0.27, 1)

    local btnStrip = CreateFrame("Frame", nil, f)
    btnStrip:SetSize(BTN_STRIP_W, FRAME_H - HDR_H - FOOT_H)
    btnStrip:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, -HDR_H)
    ThemeFill(btnStrip, "sideBg", 0.05, 0.04, 0.08, 1)

    local STRIP_BTNS = {
        { tip="Reputation",  desc="Factions & standing",           lbl="Rep", r=0.70, g=0.85, b=1.00,
          fn=function() SC_ToggleWing("rep")    end },
        { tip="Skills",      desc="Professions & secondary skills", lbl="Sk",  r=0.65, g=1.00, b=0.65,
          fn=function() SC_ToggleWing("skills") end },
        { tip="Honor",       desc="PvP honor, HKs & arena points", lbl="Hk",  r=1.00, g=0.45, b=0.45,
          fn=function() SC_ToggleWing("honor")  end },
        { tip="Talents",   desc="Open Talent frame",          lbl="T",   r=0.75, g=0.50, b=1.00,
          fn=function()
              SC_ToggleSidePanel(SC_GetTalentFrame())
          end },
        { tip="Spellbook", desc="Open Spellbook",             lbl="Sp",  r=0.35, g=0.70, b=1.00,
          fn=function()
              SC_OpenPanel("Blizzard_SpellBookUI", "SpellBookFrame", ToggleSpellBook)
          end },
        { tip="Quest Log", desc="Open Quest Log",             lbl="Q",   r=1.00, g=0.78, b=0.15,
          fn=function()
              SC_OpenPanel("Blizzard_QuestLog", "QuestLogFrame", ToggleQuestLog)
          end },
        { tip="World Map", desc="Open World Map",             lbl="M",   r=0.25, g=0.85, b=0.30,
          fn=function()
              SC_OpenPanel("Blizzard_MapCanvas", "WorldMapFrame", ToggleWorldMap)
          end },
        { tip="Bag",       desc="Open bag window",               lbl="B",   r=0.85, g=0.65, b=0.20,
          fn=function()
              if SlyBagFrame then
                  if SlyBagFrame:IsShown() then
                      SlyBagFrame:Hide()
                  else
                      if SlyBag_Refresh then SlyBag_Refresh() end
                      SlyBagFrame:ClearAllPoints()
                      SlyBagFrame:SetPoint("TOPLEFT", SlyCharMainFrame, "TOPRIGHT", 4, 0)
                      SlyBagFrame:Show()
                  end
              else
                  DEFAULT_CHAT_FRAME:AddMessage("|cff00ccff[SlyChar]|r SlyBag is not loaded — enable it in /sly")
              end
          end },
        { tip="SlyLoot SR",  desc="Soft Res & Loot rolls",  lbl="SR",  r=0.20, g=0.90, b=0.50,
          fn=function()
              if SlyLootPanel and SlyLootPanel:IsShown() then
                  SlyLootPanel:Hide() ; return
              end
              if SL_OpenSRTab then
                  SL_OpenSRTab()
              elseif SL_BuildUI then
                  SL_BuildUI()
              else
                  DEFAULT_CHAT_FRAME:AddMessage("|cff00ccff[SlyChar]|r SlyLoot is not loaded — enable it in /sly")
                  return
              end
              -- SL_BuildUI is synchronous; anchor immediately
              if SlyCharMainFrame and SlyLootPanel and SlyLootPanel:IsShown() then
                  SlyLootPanel:SetUserPlaced(true)
                  SlyLootPanel:ClearAllPoints()
                  SlyLootPanel:SetPoint("TOPLEFT", SlyCharMainFrame, "TOPRIGHT", 4, 0)
              end
          end },
        { tip="Whelp",      desc="Vendor ratings & reviews", lbl="Wh",  r=0.20, g=0.78, b=1.00,
          fn=function()
              local wp = _G["SlyWhelpPanelFrame"]
              if wp then
                  if wp:IsShown() then wp:Hide()
                  else wp:Show() end
              end
          end },
        { tip="Class Macros",   desc="Macro library for your class (by spec)",         lbl="Mc", r=0.95, g=0.70, b=0.20,
          fn=function()
              SC_ToggleWing("macros")
          end },
        { tip="Friends & Guild", desc="Online friends and guild members", lbl="Fr",  r=0.40, g=0.90, b=0.60,
          fn=function()
              SC_ToggleWing("social")
          end },
        { tip="Lockouts & Layer", desc="Alt instance lockouts, layer detection", lbl="NIT", r=0.30, g=0.80, b=1.00,
          fn=function()
              SC_ToggleWing("nit")
          end },
    }

    local bSz = BTN_STRIP_W - 6  -- 26px buttons with 3px margin each side

    -- ── Strip flyout menu ──────────────────────────────────────────────────────
    -- One >> button on the strip opens a popup menu; each row runs its action.
    local FLYOUT_W   = 152
    local FLYOUT_RH  = 24
    local FLYOUT_PAD = 4

    local flyoutMenu = CreateFrame("Frame", "SlyCharStripFlyout", UIParent)
    flyoutMenu:SetSize(FLYOUT_W, #STRIP_BTNS * FLYOUT_RH + FLYOUT_PAD * 2)
    flyoutMenu:SetFrameStrata("DIALOG")
    flyoutMenu:SetFrameLevel(f:GetFrameLevel() + 10)
    flyoutMenu:Hide()

    local fmBg = flyoutMenu:CreateTexture(nil, "BACKGROUND")
    fmBg:SetAllPoints() ; fmBg:SetColorTexture(0.04, 0.03, 0.08, 0.97)
    if flyoutMenu.SetBackdrop then
        flyoutMenu:SetBackdrop({
            bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile=true, tileSize=16, edgeSize=8,
            insets={left=2, right=2, top=2, bottom=2},
        })
        flyoutMenu:SetBackdropColor(0.04, 0.03, 0.08, 0.97)
        flyoutMenu:SetBackdropBorderColor(0.25, 0.20, 0.38, 1)
    end

    flyoutMenu:SetScript("OnShow", function()
        flyoutMenu:ClearAllPoints()
        flyoutMenu:SetPoint("TOPLEFT", f, "TOPRIGHT", 2, -HDR_H)
    end)

    tinsert(UISpecialFrames, "SlyCharStripFlyout")

    local stripFlyoutBtn  -- forward ref
    flyoutMenu:HookScript("OnHide", function()
        if stripFlyoutBtn and stripFlyoutBtn._lbl then
            stripFlyoutBtn._lbl:SetText(">>") end
    end)

    for i, bd in ipairs(STRIP_BTNS) do
        local row = CreateFrame("Button", nil, flyoutMenu)
        row:SetSize(FLYOUT_W - 4, FLYOUT_RH - 2)
        row:SetPoint("TOPLEFT", flyoutMenu, "TOPLEFT", 2,
                     -(FLYOUT_PAD + (i-1)*FLYOUT_RH))
        row:EnableMouse(true)

        local rowBg = row:CreateTexture(nil, "BACKGROUND")
        rowBg:SetAllPoints(row)
        rowBg:SetColorTexture(bd.r*0.08, bd.g*0.08, bd.b*0.08, 1)

        local accent = row:CreateTexture(nil, "ARTWORK")
        accent:SetSize(3, FLYOUT_RH - 2)
        accent:SetPoint("LEFT", row, "LEFT", 0, 0)
        accent:SetColorTexture(bd.r, bd.g, bd.b, 0.85)

        local rlbl = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        rlbl:SetFont(rlbl:GetFont(), 9, "OUTLINE")
        rlbl:SetPoint("LEFT", row, "LEFT", 8, 0)
        rlbl:SetText(bd.tip)
        rlbl:SetTextColor(
            math.min(bd.r * 0.80 + 0.20, 1),
            math.min(bd.g * 0.80 + 0.20, 1),
            math.min(bd.b * 0.80 + 0.20, 1))

        row:SetScript("OnEnter", function()
            rowBg:SetColorTexture(bd.r*0.25, bd.g*0.25, bd.b*0.25, 1)
            GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
            GameTooltip:SetText(bd.tip, 1, 1, 1)
            GameTooltip:AddLine(bd.desc, 0.7, 0.7, 0.7)
            GameTooltip:Show()
        end)
        row:SetScript("OnLeave", function()
            rowBg:SetColorTexture(bd.r*0.08, bd.g*0.08, bd.b*0.08, 1)
            GameTooltip:Hide()
        end)
        row:SetScript("OnClick", function()
            flyoutMenu:Hide()
            bd.fn()
        end)
    end

    -- >> toggle button
    stripFlyoutBtn = CreateFrame("Button", nil, btnStrip)
    stripFlyoutBtn:SetSize(bSz, bSz)
    stripFlyoutBtn:SetPoint("TOP", btnStrip, "TOP", 0, -25)
    stripFlyoutBtn:EnableMouse(true)

    local sfBord = stripFlyoutBtn:CreateTexture(nil, "BACKGROUND")
    sfBord:SetAllPoints(stripFlyoutBtn)
    sfBord:SetColorTexture(0.30*0.45, 0.25*0.45, 0.55*0.45, 0.7)

    local sfBg = stripFlyoutBtn:CreateTexture(nil, "ARTWORK")
    sfBg:SetPoint("TOPLEFT",     stripFlyoutBtn, "TOPLEFT",      1, -1)
    sfBg:SetPoint("BOTTOMRIGHT", stripFlyoutBtn, "BOTTOMRIGHT", -1,  1)
    sfBg:SetColorTexture(0.10, 0.08, 0.20, 1)

    local sfLbl = stripFlyoutBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    sfLbl:SetFont(sfLbl:GetFont(), 9, "OUTLINE")
    sfLbl:SetPoint("CENTER", stripFlyoutBtn, "CENTER", 0, 0)
    sfLbl:SetText(">>")
    sfLbl:SetTextColor(0.70, 0.65, 1.00)
    stripFlyoutBtn._lbl = sfLbl

    stripFlyoutBtn:SetScript("OnEnter", function()
        sfBg:SetColorTexture(0.22, 0.18, 0.38, 1)
        GameTooltip:SetOwner(stripFlyoutBtn, "ANCHOR_LEFT")
        GameTooltip:SetText("Quick Launch", 1, 1, 1)
        GameTooltip:AddLine("Open panel menu", 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end)
    stripFlyoutBtn:SetScript("OnLeave", function()
        sfBg:SetColorTexture(0.10, 0.08, 0.20, 1)
        GameTooltip:Hide()
    end)
    stripFlyoutBtn:SetScript("OnClick", function()
        if flyoutMenu:IsShown() then
            flyoutMenu:Hide() ; sfLbl:SetText(">>")
        else
            flyoutMenu:Show() ; sfLbl:SetText("<<")
        end
    end)

    -- ── Suite flyout panel (right-hand side panel outside the character sheet) ───
    do
        local SP_W = 230
        local SP_H = FRAME_H - HDR_H - FOOT_H   -- full content height
        local suitePanel = CreateFrame("Frame", "SlySuitePanelFrame", UIParent)
        suitePanel:SetSize(SP_W, SP_H)
        suitePanel:SetPoint("TOPLEFT", f, "TOPRIGHT", 4, -HDR_H)
        suitePanel:SetFrameStrata("DIALOG")
        suitePanel:Hide()

        local spBg = suitePanel:CreateTexture(nil, "BACKGROUND")
        spBg:SetAllPoints() ; spBg:SetColorTexture(0.04, 0.04, 0.08, 0.96)
        if suitePanel.SetBackdrop then
            suitePanel:SetBackdrop({
                bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background",
                edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                tile=true, tileSize=16, edgeSize=8,
                insets={left=2, right=2, top=2, bottom=2},
            })
            suitePanel:SetBackdropColor(0.04, 0.04, 0.08, 0.96)
            suitePanel:SetBackdropBorderColor(0.20, 0.20, 0.30, 1)
        end

        local spTitleBg = suitePanel:CreateTexture(nil, "ARTWORK")
        spTitleBg:SetPoint("TOPLEFT",  suitePanel, "TOPLEFT",  2, -2)
        spTitleBg:SetPoint("TOPRIGHT", suitePanel, "TOPRIGHT", -2, -2)
        spTitleBg:SetHeight(16)
        spTitleBg:SetColorTexture(0.08, 0.08, 0.14, 1)

        local spTitle = suitePanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        spTitle:SetFont(spTitle:GetFont(), 8, "OUTLINE")
        spTitle:SetPoint("TOPLEFT", suitePanel, "TOPLEFT", 6, -5)
        spTitle:SetText("|cff00ccffSlySuite|r Manager")

        -- footer with error label + View/Clear buttons
        local spFooter = CreateFrame("Frame", nil, suitePanel)
        spFooter:SetSize(SP_W, 24)
        spFooter:SetPoint("BOTTOMLEFT",  suitePanel, "BOTTOMLEFT",  0, 0)
        spFooter:SetPoint("BOTTOMRIGHT", suitePanel, "BOTTOMRIGHT", 0, 0)
        local spFBg = spFooter:CreateTexture(nil, "BACKGROUND")
        spFBg:SetAllPoints(spFooter) ; spFBg:SetColorTexture(0.05, 0.05, 0.09, 1)

        suiteErrLabel = spFooter:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        suiteErrLabel:SetFont(suiteErrLabel:GetFont(), 9, "")
        suiteErrLabel:SetPoint("LEFT", spFooter, "LEFT", 4, 0)
        suiteErrLabel:SetTextColor(0.45, 0.45, 0.5)
        suiteErrLabel:SetText("0 errors")

        local spViewBtn = CreateFrame("Button", nil, spFooter, "UIPanelButtonTemplate")
        spViewBtn:SetSize(38, 16) ; spViewBtn:SetText("View")
        spViewBtn:SetPoint("RIGHT", spFooter, "RIGHT", -44, 0)
        spViewBtn:SetScript("OnClick", function()
            if SlashCmdList["SLY"] then SlashCmdList["SLY"]("errors") end
        end)

        local spClearBtn = CreateFrame("Button", nil, spFooter, "UIPanelButtonTemplate")
        spClearBtn:SetSize(38, 16) ; spClearBtn:SetText("Clear")
        spClearBtn:SetPoint("RIGHT", spFooter, "RIGHT", -2, 0)
        spClearBtn:SetScript("OnClick", function()
            if SlashCmdList["SLY"] then SlashCmdList["SLY"]("clearerrors") end
            local df2 = SlySuiteDataFrame
            if df2 and df2.db then df2.db.errorLog = {} end
            SC_RefreshSuite()
        end)

        -- scroll area for module rows
        local spScroll = CreateFrame("ScrollFrame", nil, suitePanel, "UIPanelScrollFrameTemplate")
        spScroll:SetPoint("TOPLEFT",     suitePanel, "TOPLEFT",      0, -18)
        spScroll:SetPoint("BOTTOMRIGHT", suitePanel, "BOTTOMRIGHT", -18,  26)
        local spContent = CreateFrame("Frame", nil, spScroll)
        spContent:SetSize(SP_W - 18, 1)
        spScroll:SetScrollChild(spContent)
        suiteCont = spContent

        suitePanel:HookScript("OnShow", function() SC_RefreshSuite() end)
    end

    -- ── Whelp flyout panel (right-side) ────────────────────────────────────
    do
        local WP_W = 260
        local WP_H = FRAME_H - HDR_H - FOOT_H
        local wpanel = CreateFrame("Frame", "SlyWhelpPanelFrame", UIParent)
        wpanel:SetSize(WP_W, WP_H)
        wpanel:SetPoint("TOPLEFT", f, "TOPRIGHT", 4, -HDR_H)
        wpanel:SetFrameStrata("DIALOG")
        wpanel:SetMovable(true)
        wpanel:EnableMouse(true)
        wpanel:RegisterForDrag("LeftButton")
        wpanel:SetScript("OnDragStart", wpanel.StartMoving)
        wpanel:SetScript("OnDragStop",  wpanel.StopMovingOrSizing)
        wpanel:Hide()

        -- Background
        ThemeFill(wpanel, "frameBg", 0.04, 0.04, 0.08, 0.97)
        local wpBord = wpanel:CreateTexture(nil, "OVERLAY")
        wpBord:SetAllPoints(wpanel) ; wpBord:SetColorTexture(0.22, 0.18, 0.32, 1)
        local wpInner = wpanel:CreateTexture(nil, "BACKGROUND")
        wpInner:SetPoint("TOPLEFT",     wpanel, "TOPLEFT",      1, -1)
        wpInner:SetPoint("BOTTOMRIGHT", wpanel, "BOTTOMRIGHT", -1,  1)
        wpInner:SetColorTexture(0.04, 0.04, 0.08, 0.97)

        -- Header bar
        local wpHdr = CreateFrame("Frame", nil, wpanel)
        wpHdr:SetSize(WP_W, HDR_H)
        wpHdr:SetPoint("TOPLEFT", wpanel, "TOPLEFT", 0, 0)
        ThemeFill(wpHdr, "headerBg", 0.07, 0.06, 0.13, 1)

        local wpTitle = wpHdr:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        wpTitle:SetFont(wpTitle:GetFont(), 12, "OUTLINE")
        wpTitle:SetPoint("LEFT", wpHdr, "LEFT", PAD, 0)
        wpTitle:SetTextColor(0.40, 0.80, 1.00)
        wpTitle:SetText("Whelp  |cffaaaaaa Vendor Ratings|r")

        local wpClose = CreateFrame("Button", nil, wpHdr, "UIPanelCloseButton")
        wpClose:SetSize(22, 22)
        wpClose:SetPoint("RIGHT", wpHdr, "RIGHT", -2, 0)
        wpClose:SetScript("OnClick", function() wpanel:Hide() end)

        local wpAddBtn = CreateFrame("Button", nil, wpHdr, "UIPanelButtonTemplate")
        wpAddBtn:SetSize(50, 18)
        wpAddBtn:SetPoint("RIGHT", wpClose, "LEFT", -4, 0)
        wpAddBtn:SetText("+Add")
        wpAddBtn:SetScript("OnClick", function()
            if Whelp and Whelp.UI and Whelp.UI.MainFrame then
                local mf = Whelp.UI.MainFrame:Create()
                Whelp.UI.MainFrame:SelectTab("addvendor")
                mf:Show()
            else
                DEFAULT_CHAT_FRAME:AddMessage("|cff66d4ff[Whelp]|r Whelp is not loaded.")
            end
        end)

        -- Header separator
        local wpSep = wpanel:CreateTexture(nil, "ARTWORK")
        wpSep:SetSize(WP_W, 1)
        wpSep:SetPoint("TOPLEFT", wpanel, "TOPLEFT", 0, -HDR_H)
        wpSep:SetColorTexture(0.25, 0.20, 0.38, 1)

        -- Browse All button (footer)
        local wpBrowse = CreateFrame("Button", nil, wpanel, "UIPanelButtonTemplate")
        wpBrowse:SetSize(WP_W - 12, 18)
        wpBrowse:SetPoint("BOTTOMLEFT", wpanel, "BOTTOMLEFT", 6, 4)
        wpBrowse:SetText("Browse All in Whelp")
        wpBrowse:SetScript("OnClick", function()
            if Whelp and Whelp.UI and Whelp.UI.MainFrame then
                local mf = Whelp.UI.MainFrame:Create()
                mf:Show()
            end
        end)

        -- Footer separator
        local wpFSep = wpanel:CreateTexture(nil, "ARTWORK")
        wpFSep:SetSize(WP_W, 1)
        wpFSep:SetPoint("BOTTOMLEFT", wpanel, "BOTTOMLEFT", 0, 26)
        wpFSep:SetColorTexture(0.18, 0.14, 0.28, 1)

        -- Scroll area for vendor rows
        local wpScroll = CreateFrame("ScrollFrame", nil, wpanel, "UIPanelScrollFrameTemplate")
        wpScroll:SetPoint("TOPLEFT",     wpanel, "TOPLEFT",      6,   -(HDR_H + 2))
        wpScroll:SetPoint("BOTTOMRIGHT", wpanel, "BOTTOMRIGHT", -22,   28)
        local wpCont = CreateFrame("Frame", nil, wpScroll)
        wpCont:SetSize(WP_W - 8 - 22, 1)
        wpScroll:SetScrollChild(wpCont)

        -- Status FontString (empty / error states)
        local wpStatus = wpCont:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        wpStatus:SetPoint("TOPLEFT", wpCont, "TOPLEFT", 4, -6)
        wpStatus:SetWidth(WP_W - 8 - 22) ; wpStatus:SetJustifyH("LEFT")
        wpStatus:Hide()
        wpanel._statusMsg = wpStatus

        -- Pre-build 20 pooled vendor rows
        local WRW = WP_W - 8 - 22
        wpanel._cont = wpCont
        wpanel._rows = {}
        for i = 1, 20 do
            local row = CreateFrame("Frame", nil, wpCont)
            row:SetSize(WRW, 26)
            row:SetPoint("TOPLEFT", wpCont, "TOPLEFT", 0, -((i-1)*28) - 2)
            row:Hide()
            local rowParity = (i % 2 == 0)
            local rbg = row:CreateTexture(nil, "BACKGROUND")
            rbg:SetAllPoints()
            rbg:SetColorTexture(rowParity and 0.07 or 0.05,
                                rowParity and 0.06 or 0.04,
                                rowParity and 0.11 or 0.08, 0.9)
            local nameFS = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            nameFS:SetFont(nameFS:GetFont(), 10, "")
            nameFS:SetPoint("TOPLEFT", row, "TOPLEFT", 4, -3)
            nameFS:SetWidth(WRW - 50) ; nameFS:SetJustifyH("LEFT")
            local ratingFS = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            ratingFS:SetFont(ratingFS:GetFont(), 9, "")
            ratingFS:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 4, 3)
            local viewBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
            viewBtn:SetSize(38, 18)
            viewBtn:SetPoint("TOPRIGHT", row, "TOPRIGHT", -2, -4)
            viewBtn:SetText("View")
            row._nameFS   = nameFS
            row._ratingFS = ratingFS
            row._viewBtn  = viewBtn
            wpanel._rows[i] = row
        end

        wpanel:HookScript("OnShow", function() SC_RefreshWhelp() end)
    end

    -- Suite strip button (S) — toggles suite flyout above X button
    do
        local bS = CreateFrame("Button", nil, btnStrip)
        bS:SetSize(bSz, bSz)
        bS:SetPoint("BOTTOM", btnStrip, "BOTTOM", 0, 4 + bSz + 3)
        bS:EnableMouse(true)
        local bordS = bS:CreateTexture(nil, "BACKGROUND")
        bordS:SetAllPoints(bS)
        bordS:SetColorTexture(0.10, 0.35, 0.65, 0.7)
        local bbgS = bS:CreateTexture(nil, "ARTWORK")
        bbgS:SetPoint("TOPLEFT",     bS, "TOPLEFT",      1, -1)
        bbgS:SetPoint("BOTTOMRIGHT", bS, "BOTTOMRIGHT", -1,  1)
        bbgS:SetColorTexture(0.03, 0.10, 0.22, 1)
        local lblS = bS:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        lblS:SetFont(lblS:GetFont(), 8, "OUTLINE")
        lblS:SetPoint("CENTER", bS, "CENTER", 0, 0)
        lblS:SetText("S")
        lblS:SetTextColor(0.30, 0.70, 1.00)
        bS:SetScript("OnEnter", function()
            bbgS:SetColorTexture(0.08, 0.25, 0.50, 1)
            GameTooltip:SetOwner(bS, "ANCHOR_LEFT")
            GameTooltip:SetText("SlySuite", 1, 1, 1)
            GameTooltip:AddLine("Toggle suite manager panel", 0.7, 0.7, 0.7)
            GameTooltip:Show()
        end)
        bS:SetScript("OnLeave", function()
            bbgS:SetColorTexture(0.03, 0.10, 0.22, 1)
            GameTooltip:Hide()
        end)
        bS:SetScript("OnClick", function()
            local sp = _G["SlySuitePanelFrame"]
            if sp then
                if sp:IsShown() then sp:Hide() else sp:Show() end
            end
        end)
    end

    -- Close-side-panel button (×) at bottom of strip
    do
        local bX = CreateFrame("Button", nil, btnStrip)
        bX:SetSize(bSz, bSz)
        bX:SetPoint("BOTTOM", btnStrip, "BOTTOM", 0, 4)
        bX:EnableMouse(true)
        local bordX = bX:CreateTexture(nil, "BACKGROUND")
        bordX:SetAllPoints(bX)
        bordX:SetColorTexture(0.55, 0.12, 0.12, 0.7)
        local bbgX = bX:CreateTexture(nil, "ARTWORK")
        bbgX:SetPoint("TOPLEFT",     bX, "TOPLEFT",      1, -1)
        bbgX:SetPoint("BOTTOMRIGHT", bX, "BOTTOMRIGHT", -1,  1)
        bbgX:SetColorTexture(0.20, 0.04, 0.04, 1)
        local lblX = bX:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        lblX:SetFont(lblX:GetFont(), 11, "OUTLINE")
        lblX:SetPoint("CENTER", bX, "CENTER", 0, 0)
        lblX:SetText("×")
        lblX:SetTextColor(1, 0.35, 0.35)
        bX:SetScript("OnEnter", function()
            bbgX:SetColorTexture(0.40, 0.08, 0.08, 1)
            GameTooltip:SetOwner(bX, "ANCHOR_LEFT")
            GameTooltip:SetText("Close panel", 1, 1, 1)
            GameTooltip:AddLine("Dismiss current side panel", 0.7, 0.7, 0.7)
            GameTooltip:Show()
        end)
        bX:SetScript("OnLeave", function()
            bbgX:SetColorTexture(0.20, 0.04, 0.04, 1)
            GameTooltip:Hide()
        end)
        bX:SetScript("OnClick", SC_CloseSidePanel)
    end

    -- Footer
    local footer = CreateFrame("Frame", nil, f)
    footer:SetSize(FRAME_W, FOOT_H)
    footer:SetPoint("BOTTOM", f, "BOTTOM", 0, 0)
    themeRefs.footBg = FillBg(footer, 0.07, 0.07, 0.10, 1)

    local ftxt = footer:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    ftxt:SetFont(ftxt:GetFont(), 8, "")
    ftxt:SetPoint("LEFT", footer, "LEFT", PAD, 0)
    ftxt:SetTextColor(0.3, 0.3, 0.38)
    ftxt:SetText("C or /slychar  |  left-click = gear picker  |  shift+click = socket  |  right-click = link  |  >> = panel menu  |  x = close panel")

    f:HookScript("OnShow", function(self) self:EnableMouse(true) end)
    f:HookScript("OnHide", function(self)
        self:EnableMouse(false)
        SC_HidePicker()
        SC_CloseSidePanel()
        if wingFrame then wingFrame:Hide() ; activeWingKey = nil end
        local fm = _G["SlyCharStripFlyout"]
        if fm then fm:Hide() end
    end)

    BuildWingFrame(f)
    SlyCharMainFrame = f
    tinsert(UISpecialFrames, "SlyCharMainFrame")

    SC_ApplyTheme(SC.db.theme or "shadow")
end