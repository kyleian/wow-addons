-- ================================================================
-- SlyAuctionItems.lua  —  Curated trade-goods item list
-- These are the key TBC consumables and materials worth tracking.
--
-- Item IDs are hints for bag-counting and are auto-corrected on the
-- first AH scan (the scan uses name queries; discovered IDs overwrite
-- these defaults via SlyAuctionDB.priceHistory[name].id).
-- ================================================================

-- category values used for grouping / filtering in the UI
-- PRIMAL, MOTE, ORE, BAR, ENCHANTING, CLOTH, OIL

SLYAUCTION_ITEMS = {
    -- ── Primals ──────────────────────────────────────────────
    { name="Primal Fire",    id=21884, cat="PRIMAL",     stackHint=1  },
    { name="Primal Water",   id=21885, cat="PRIMAL",     stackHint=1  },
    { name="Primal Air",     id=21876, cat="PRIMAL",     stackHint=1  },
    { name="Primal Earth",   id=22452, cat="PRIMAL",     stackHint=1  },
    { name="Primal Mana",    id=22457, cat="PRIMAL",     stackHint=1  },
    { name="Primal Life",    id=21886, cat="PRIMAL",     stackHint=1  },
    { name="Primal Shadow",  id=22456, cat="PRIMAL",     stackHint=1  },

    -- ── Motes ────────────────────────────────────────────────
    { name="Mote of Fire",   id=22572, cat="MOTE",       stackHint=10 },
    { name="Mote of Water",  id=22573, cat="MOTE",       stackHint=10 },
    { name="Mote of Air",    id=22574, cat="MOTE",       stackHint=10 },
    { name="Mote of Earth",  id=22575, cat="MOTE",       stackHint=10 },
    { name="Mote of Mana",   id=22576, cat="MOTE",       stackHint=10 },
    { name="Mote of Life",   id=22577, cat="MOTE",       stackHint=10 },
    { name="Mote of Shadow", id=22578, cat="MOTE",       stackHint=10 },

    -- ── Ore ──────────────────────────────────────────────────
    { name="Fel Iron Ore",       id=23424, cat="ORE",    stackHint=20 },
    { name="Adamantite Ore",     id=23425, cat="ORE",    stackHint=20 },
    { name="Eternium Ore",       id=23426, cat="ORE",    stackHint=20 },

    -- ── Bars ─────────────────────────────────────────────────
    { name="Fel Iron Bar",       id=23427, cat="BAR",    stackHint=20 },
    { name="Adamantite Bar",     id=23117, cat="BAR",    stackHint=20 },
    { name="Eternium Bar",       id=23445, cat="BAR",    stackHint=20 },

    -- ── Enchanting mats ──────────────────────────────────────
    { name="Arcane Dust",             id=22445, cat="ENCHANTING", stackHint=20 },
    { name="Greater Planar Essence",  id=22447, cat="ENCHANTING", stackHint=5  },
    { name="Large Prismatic Shard",   id=22449, cat="ENCHANTING", stackHint=3  },
    { name="Void Crystal",            id=22450, cat="ENCHANTING", stackHint=1  },

    -- ── Cloth ────────────────────────────────────────────────
    { name="Netherweave Cloth",  id=21840, cat="CLOTH",  stackHint=20 },

    -- ── Weapon / armour oils & stones ────────────────────────
    { name="Brilliant Mana Oil",   id=22748, cat="OIL",  stackHint=1  },
    { name="Brilliant Wizard Oil", id=22749, cat="OIL",  stackHint=1  },
    { name="Superior Mana Oil",    id=22747, cat="OIL",  stackHint=1  },
    { name="Superior Wizard Oil",  id=22750, cat="OIL",  stackHint=1  },
}

-- Quick lookup table — built once at load, used throughout
SLYAUCTION_ITEM_BY_NAME = {}
for _, item in ipairs(SLYAUCTION_ITEMS) do
    SLYAUCTION_ITEM_BY_NAME[item.name] = item
end
