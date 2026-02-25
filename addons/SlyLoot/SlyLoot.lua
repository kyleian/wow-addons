-- SlyLoot.lua
-- Master looter assistant: announces quality drops, tracks /roll results.
-- /slyloot  -> toggle panel

local ADDON_NAME    = "SlyLoot"
local ADDON_VERSION = "1.0.0"

SlyLoot = {}  -- public namespace
local SL = SlyLoot

SL.activeItem  = nil    -- { link, name, icon } - item currently being rolled
SL.rolls       = {}     -- { [playerName] = rollValue } for current session
SL.history     = {}     -- list of completed sessions { item, winner, rolls }
SL.uiRefresh   = nil    -- set by UI file
SL.srRefresh   = nil    -- set by UI file (switches to SR tab and refreshes)
SL.sr          = {}     -- fast lookup: { [itemId]=players[], [itemNameLower]=players[] }
SL.srItems     = {}     -- sorted display list: { {id, name, players[]}, ... }

-- ── Defaults ─────────────────────────────────────────────────────────────────
local DB_DEFAULTS = {
    enabled        = true,
    announceChannel = "raid",   -- raid | party | say
    minQuality     = 3,         -- 0=gray 1=white 2=green 3=blue 4=epic 5=leg
    position       = { point = "CENTER", x = 200, y = 0 },
    srRaw          = "",        -- last raw soft-reserve import text
}

SL.QUALITY_COLORS = {
    [0] = "|cff9d9d9d", -- gray
    [1] = "|cffffffff", -- white
    [2] = "|cff1eff00", -- green
    [3] = "|cff0070dd", -- blue
    [4] = "|cffa335ee", -- purple
    [5] = "|cffff8000", -- orange
}

SL.QUALITY_NAMES = { [0]="Gray",[1]="White",[2]="Green",[3]="Blue",[4]="Epic",[5]="Legendary" }

local function ApplyDefaults(saved, defaults)
    for k, v in pairs(defaults) do
        if saved[k] == nil then
            if type(v) == "table" then saved[k] = {}; ApplyDefaults(saved[k], v)
            else saved[k] = v end
        end
    end
end

-- ── Chat helpers ──────────────────────────────────────────────────────────────
function SL:Send(msg)
    local ch = (SlyLootDB.announceChannel or "raid"):upper()
    if ch == "RAID" and GetNumRaidMembers() == 0 then ch = "PARTY" end
    if ch == "PARTY" and GetNumPartyMembers() == 0 then ch = "SAY" end
    SendChatMessage(msg, ch)
end

function SL:Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ccff[SlyLoot]|r " .. msg)
end

-- ── Soft Reserve ─────────────────────────────────────────────────────────────
function SL:GetSRForLink(itemLink)
    if not itemLink then return {} end
    local players, seen = {}, {}
    local idStr = itemLink:match("item:(%d+)")
    if idStr then
        for _, p in ipairs(SL.sr[tonumber(idStr)] or {}) do
            if not seen[p] then seen[p]=true; players[#players+1]=p end
        end
    end
    local itemName = GetItemInfo(itemLink)
    if itemName then
        for _, p in ipairs(SL.sr[itemName:lower()] or {}) do
            if not seen[p] then seen[p]=true; players[#players+1]=p end
        end
    end
    return players
end

local function ParseSRText(text)
    local itemMap = {}
    local skipNames = { name=true, character=true, charname=true }
    local classWords = { warrior=true,paladin=true,hunter=true,rogue=true,priest=true,
        shaman=true,mage=true,warlock=true,druid=true,dps=true,tank=true,healer=true,
        male=true,female=true }
    for line in (text or ""):gmatch("[^\r\n]+") do
        line = line:gsub('"',''):match("^%s*(.-)%s*$")
        if line ~= "" then
            local parts = {}
            for p in line:gmatch("[^,]+") do parts[#parts+1]=p:match("^%s*(.-)%s*$") end
            if #parts >= 2 then
                local charName = parts[1]
                if not skipNames[charName:lower()] then
                    for i = 2, #parts do
                        local p = parts[i]
                        if p ~= "" and not classWords[p:lower()] then
                            local numId = tonumber(p)
                            local key = numId or p:lower()
                            if not itemMap[key] then
                                itemMap[key] = { id=numId, name=(numId and tostring(numId) or p), players={} }
                            end
                            local already = false
                            for _, e in ipairs(itemMap[key].players) do
                                if e == charName then already=true; break end
                            end
                            if not already then
                                itemMap[key].players[#itemMap[key].players+1] = charName
                            end
                        end
                    end
                end
            end
        end
    end
    return itemMap
end

function SL:ImportSR(text)
    SL.sr = {}; SL.srItems = {}
    local itemMap = ParseSRText(text)
    local count = 0
    for k, entry in pairs(itemMap) do
        SL.sr[k] = entry.players
        local n = GetItemInfo(entry.id or "")
        if n then entry.name = n end
        SL.srItems[#SL.srItems+1] = entry
        count = count + 1
    end
    table.sort(SL.srItems, function(a,b) return (a.name or ""):lower() < (b.name or ""):lower() end)
    SlyLootDB.srRaw = text
    SL:Print("Imported " .. count .. " SR item(s).")
    if SL.srRefresh then SL.srRefresh() end
end

function SL:ClearSR()
    SL.sr = {}; SL.srItems = {}
    SlyLootDB.srRaw = ""
    SL:Print("Soft reserves cleared.")
    if SL.srRefresh then SL.srRefresh() end
end

function SL:LoadSR()
    local text = SlyLootDB and SlyLootDB.srRaw or ""
    if text == "" then return end
    SL.sr = {}; SL.srItems = {}
    local itemMap = ParseSRText(text)
    for k, entry in pairs(itemMap) do
        SL.sr[k] = entry.players
        SL.srItems[#SL.srItems+1] = entry
    end
    table.sort(SL.srItems, function(a,b) return (a.name or ""):lower() < (b.name or ""):lower() end)
end

-- ── Loot handling ─────────────────────────────────────────────────────────────
function SL:ScanLoot()
    if not SlyLootDB.enabled then return end
    local count = GetNumLootItems()
    if count == 0 then return end

    local reported = {}
    for i = 1, count do
        local icon, name, qty, quality, locked = GetLootSlotInfo(i)
        if name and quality and quality >= SlyLootDB.minQuality then
            local link = GetLootSlotLink(i) or name
            local col  = SL.QUALITY_COLORS[quality] or ""
            local qstr = SL.QUALITY_NAMES[quality] or "?"
            local qtyStr = qty and qty > 1 and " x" .. qty or ""
            reported[#reported+1] = col .. "[" .. name .. qtyStr .. "]|r"            -- Announce soft-reserve holders for this item
            local srPlayers = SL:GetSRForLink(link)
            if #srPlayers > 0 then
                SL:Send("[SR] " .. (link or name) .. " -> " .. table.concat(srPlayers, ", "))
            end        end
    end

    if #reported > 0 then
        SL:Send("[Loot] " .. table.concat(reported, "  "))
    end
end

-- ── Roll session ──────────────────────────────────────────────────────────────
function SL:StartRoll(itemLink, label)
    SL.activeItem = { link = itemLink or label, name = label or itemLink }
    SL.rolls      = {}
    SL:Send("Roll for " .. (itemLink or label) .. " — type /roll 100 now!")
    SL:Print("Roll session started for " .. (label or itemLink) .. ". Tracking rolls...")
    if SL.uiRefresh then SL.uiRefresh() end
end

function SL:EndRoll()
    if not SL.activeItem then SL:Print("No active roll session."); return end

    local winner, winRoll = nil, -1
    for player, roll in pairs(SL.rolls) do
        if roll > winRoll then winner = player; winRoll = roll end
    end

    local itemName = SL.activeItem.name or SL.activeItem.link or "item"
    if winner then
        SL:Send("[Roll Result] " .. itemName .. " → " .. winner .. " (" .. winRoll .. ")")
        SL:Print("Winner: " .. winner .. " with roll " .. winRoll)
    else
        SL:Print("No rolls recorded.")
    end

    -- Save to history (keep last 20)
    table.insert(SL.history, 1, {
        item   = itemName,
        winner = winner or "none",
        roll   = winRoll,
        rolls  = SL.rolls,
        time   = time(),
    })
    if #SL.history > 20 then SL.history[21] = nil end

    SL.activeItem = nil
    SL.rolls      = {}
    if SL.uiRefresh then SL.uiRefresh() end
end

function SL:ClearRoll()
    SL.activeItem = nil
    SL.rolls      = {}
    SL:Print("Roll session cleared.")
    if SL.uiRefresh then SL.uiRefresh() end
end

-- ── Roll parsing (CHAT_MSG_SYSTEM) ────────────────────────────────────────────
-- TBC roll message: "Playername rolls 87 (1-100)."
local ROLL_PATTERN = "^(.+) rolls (%d+) %((%d+)-(%d+)%)"

function SL:ParseRoll(msg)
    if not SL.activeItem then return end
    local player, roll, low, high = msg:match(ROLL_PATTERN)
    if player and roll then
        roll = tonumber(roll)
        -- Only track if it's a /roll 100 (1-100)
        if tonumber(low) == 1 and tonumber(high) == 100 then
            -- Overwrite only if higher (prevent re-rolls gaming)
            if not SL.rolls[player] or roll > SL.rolls[player] then
                SL.rolls[player] = roll
                SL:Print(player .. " rolls " .. roll)
                if SL.uiRefresh then SL.uiRefresh() end
            end
        end
    end
end

-- ── Events ────────────────────────────────────────────────────────────────────
local eventFrame = CreateFrame("Frame")

function SL:Init()
    SlyLootDB = SlyLootDB or {}
    ApplyDefaults(SlyLootDB, DB_DEFAULTS)
    SL:LoadSR()  -- rebuild SR lookup from saved raw text

    eventFrame:RegisterEvent("LOOT_OPENED")
    eventFrame:RegisterEvent("CHAT_MSG_SYSTEM")
    eventFrame:SetScript("OnEvent", function(self, event, msg)
        if event == "LOOT_OPENED" then
            SL:ScanLoot()
        elseif event == "CHAT_MSG_SYSTEM" then
            SL:ParseRoll(msg)
        end
    end)

    SLASH_SLYLOOT1 = "/slyloot"
    SlashCmdList["SLYLOOT"] = function(raw)
        local cmd, rest = (raw or ""):match("^%s*(%S*)%s*(.*)")
        cmd = (cmd or ""):lower()
        if cmd == "" then
            if SlyLootPanel and SlyLootPanel:IsShown() then SlyLootPanel:Hide()
            else if SL_BuildUI then SL_BuildUI() end end
        elseif cmd == "start" or cmd == "roll" then
            SL:StartRoll(nil, rest ~= "" and rest or "item")
        elseif cmd == "end" or cmd == "winner" then
            SL:EndRoll()
        elseif cmd == "clear" then
            SL:ClearRoll()
        elseif cmd == "channel" and rest ~= "" then
            SlyLootDB.announceChannel = rest:lower()
            SL:Print("Announce channel: " .. SlyLootDB.announceChannel)
        elseif cmd == "quality" and tonumber(rest) then
            SlyLootDB.minQuality = tonumber(rest)
            SL:Print("Min quality set to " .. SL.QUALITY_NAMES[SlyLootDB.minQuality])
        elseif cmd == "enable" then
            SlyLootDB.enabled = true; SL:Print("Enabled.")
        elseif cmd == "disable" then
            SlyLootDB.enabled = false; SL:Print("Disabled.")
        elseif cmd == "sr" then
            if SL_OpenSRTab then SL_OpenSRTab() else SL_BuildUI() end
        elseif cmd == "clsr" then
            SL:ClearSR()
        else
            SL:Print("Commands: /slyloot | start <item> | end | clear | sr | clsr | channel <raid|party|say> | quality <0-5> | enable | disable")
        end
    end
end

-- ── Boot ─────────────────────────────────────────────────────────────────────
local boot = CreateFrame("Frame")
boot:RegisterEvent("ADDON_LOADED")
boot:SetScript("OnEvent", function(self, event, name)
    if name ~= ADDON_NAME then return end
    self:UnregisterEvent("ADDON_LOADED")
    if SlySuite_Register then
        SlySuite_Register(ADDON_NAME, ADDON_VERSION, function() SL:Init() end, {
            description = "Loot announcer + /roll tracker. Announces quality drops, picks winners.",
            slash       = "/slyloot",
            icon        = "Interface\\Icons\\INV_Misc_Bag_10",
        })
    else
        SL:Init()
    end
end)
