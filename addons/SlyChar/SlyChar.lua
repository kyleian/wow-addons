-- ============================================================
-- SlyChar.lua  (full rewrite — movable character sheet)
-- • Intercepts C key: hides CharacterFrame, shows our panel
-- • SC_BuildMain() builds a full equipped-gear + model panel
-- • Stats tab (base stats + ECS extended) + Sets tab (IRR)
-- ============================================================

SC  = SC  or {}
SC.version = "1.0.0"

-- --------------------------------------------------------
-- SavedVariables defaults
-- --------------------------------------------------------
local DB_DEFAULTS = {
    position = nil,     -- {point, x, y} for SlyCharMainFrame
    lastTab  = "stats",
    theme    = "shadow",
}

SC.db = {}

-- --------------------------------------------------------
-- Helpers
-- --------------------------------------------------------
local function ApplyDefaults(dest, src)
    for k, v in pairs(src) do
        if dest[k] == nil then
            dest[k] = type(v) == "table" and {} or v
        end
        if type(v) == "table" and type(dest[k]) == "table" then
            ApplyDefaults(dest[k], v)
        end
    end
end

-- --------------------------------------------------------
-- Show / Toggle our main panel
-- --------------------------------------------------------
function SC_ShowMain()
    if not SlyCharMainFrame then
        SC_BuildMain()
    end
    local pos = SC.db.position
    if pos and pos.point then
        SlyCharMainFrame:ClearAllPoints()
        SlyCharMainFrame:SetPoint(pos.point, UIParent, pos.point, pos.x or 0, pos.y or 0)
    end
    SlyCharMainFrame:Show()
    SC_RefreshAll()
end

function SC_ToggleMain()
    if SlyCharMainFrame and SlyCharMainFrame:IsShown() then
        SlyCharMainFrame:Hide()
    else
        SC_ShowMain()
    end
end

-- --------------------------------------------------------
-- Hook CharacterFrame: C key → suppress default, use ours
-- The C keybinding fires ShowUIPanel(CharacterFrame).
-- HookScript on OnShow immediately hides it and toggles ours.
-- Since CharacterFrame is always instantly hidden,
-- ToggleCharacter() always thinks it's closed and calls Show —
-- so we toggle based on our own panel state.
-- --------------------------------------------------------
local function HookCharacterFrame()
    if not CharacterFrame then return end
    CharacterFrame:HookScript("OnShow", function(self)
        self:Hide()                 -- suppress the default frame
        SC_ToggleMain()             -- toggle our panel
    end)
end

-- --------------------------------------------------------
-- Slash commands
-- --------------------------------------------------------
local function SC_Slash(msg)
    msg = (msg or ""):lower():trim()
    if msg == "reset" then
        SC.db.position = nil
        if SlyCharMainFrame then
            SlyCharMainFrame:ClearAllPoints()
            SlyCharMainFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        end
        DEFAULT_CHAT_FRAME:AddMessage("|cff88bbff[SlyChar]|r Position reset.")
    elseif msg == "stats" then
        SC_ShowMain()
        SC_SwitchTab("stats")
    elseif msg == "sets" then
        SC_ShowMain()
        if SC_SetSetsSubTab then SC_SetSetsSubTab("gear") end
        SC_SwitchTab("sets")
        if SC_RefreshSetsSub then SC_RefreshSetsSub() end
    elseif msg == "bars" then
        SC_ShowMain()
        if SC_SetSetsSubTab then SC_SetSetsSubTab("bars") end
        SC_SwitchTab("sets")
        if SC_RefreshSetsSub then SC_RefreshSetsSub() end
    elseif msg == "rep" then
        SC_ShowMain()
        if SC_SetMiscSubTab then SC_SetMiscSubTab("rep") end
        SC_SwitchTab("misc")
        if SC_RefreshMisc then SC_RefreshMisc() end
    elseif msg == "skills" then
        SC_ShowMain()
        if SC_SetMiscSubTab then SC_SetMiscSubTab("skills") end
        SC_SwitchTab("misc")
        if SC_RefreshMisc then SC_RefreshMisc() end
    elseif msg == "debug" then
        -- Print raw talent API data + which frame exists.
        local numTabs = GetNumTalentTabs and GetNumTalentTabs() or 0
        print("|cff88bbff[SlyChar Debug]|r numTabs=" .. numTabs ..
              "  PlayerTalentFrame=" .. tostring(PlayerTalentFrame ~= nil) ..
              "  TalentFrame=" .. tostring(TalentFrame ~= nil))
        for tab = 1, numTabs do
            local tname, _, spent = GetTalentTabInfo(tab)
            local n = GetNumTalents and GetNumTalents(tab) or 0
            print("|cff88bbff Tab"..tab.."|r " .. (tname or "?") ..
                  " spent="..tostring(spent) .. " numTalents="..n)
            for i = 1, math.min(n, 3) do
                local tn, _, tier, col, cr, mr = GetTalentInfo(tab, i)
                print("  ["..i.."] "..tostring(tn)..
                      " tier="..tostring(tier)..
                      " col="..tostring(col)..
                      " rank="..tostring(cr).."/"..tostring(mr))
            end
        end
    else
        SC_ToggleMain()
    end
end

-- --------------------------------------------------------
-- Event frame
-- --------------------------------------------------------
local evFrame = CreateFrame("Frame", "SlyCharEventFrame", UIParent)
evFrame:RegisterEvent("ADDON_LOADED")
evFrame:RegisterEvent("PLAYER_LOGOUT")
evFrame:RegisterEvent("UNIT_INVENTORY_CHANGED")
evFrame:RegisterEvent("PLAYER_TALENT_UPDATE")
evFrame:RegisterEvent("CHARACTER_POINTS_CHANGED")
evFrame:RegisterEvent("UPDATE_FACTION")
evFrame:RegisterEvent("SKILL_LINES_CHANGED")
evFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
evFrame:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
evFrame:RegisterEvent("GUILD_ROSTER_UPDATE")

evFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local name = ...
        if name == "SlyChar" then
            SlyCharDB = SlyCharDB or {}
            ApplyDefaults(SlyCharDB, DB_DEFAULTS)
            SC.db = SlyCharDB

            HookCharacterFrame()

            SLASH_SLYCHAR1 = "/slychar"
            SlashCmdList["SLYCHAR"] = SC_Slash

            if SlySuite_Register then
                SlySuite_Register("SlyChar", SC.version, function() end, {
                    description = "Movable character sheet: gear, model, stats, sets, reputation, skills. Press C.",
                    slash       = "/slychar",
                    icon        = "Interface\\Icons\\INV_Misc_PocketWatch_01",
                })
            end
        end

    elseif event == "PLAYER_LOGOUT" then
        if SlyCharMainFrame then
            local pt, _, _, x, y = SlyCharMainFrame:GetPoint()
            SC.db.position = { point = pt or "CENTER", x = x or 0, y = y or 0 }
        end

    elseif event == "UNIT_INVENTORY_CHANGED" then
        if SlyCharMainFrame and SlyCharMainFrame:IsShown() then
            SC_RefreshAll()
        end

    elseif event == "PLAYER_TALENT_UPDATE"
        or event == "CHARACTER_POINTS_CHANGED" then
        if SlyCharMainFrame and SlyCharMainFrame:IsShown() then
            SC_RefreshAll()
        end

    elseif event == "UPDATE_FACTION" then
        if SlyCharMainFrame and SlyCharMainFrame:IsShown()
            and SC.db.lastTab == "rep" then
            SC_RefreshReputation()
        end

    elseif event == "SKILL_LINES_CHANGED" then
        if SlyCharMainFrame and SlyCharMainFrame:IsShown()
            and SC.db.lastTab == "skills" then
            SC_RefreshSkills()
        end

    elseif event == "PLAYER_TARGET_CHANGED" then
        if SlyCharMainFrame and SlyCharMainFrame:IsShown()
            and SC.db.lastTab == "nit" then
            if SC_UpdateNITLayer then SC_UpdateNITLayer("target") end
        end

    elseif event == "UPDATE_MOUSEOVER_UNIT" then
        -- Only bother with mouseover if NWB hasn't already set a layer value
        if SlyCharMainFrame and SlyCharMainFrame:IsShown()
            and SC.db.lastTab == "nit"
            and (not NWB_CurrentLayer or NWB_CurrentLayer == 0) then
            if SC_UpdateNITLayer then SC_UpdateNITLayer("mouseover") end
        end

    elseif event == "GUILD_ROSTER_UPDATE" then
        if SlyCharMainFrame and SlyCharMainFrame:IsShown()
            and SC.db.lastTab == "nit" then
            if SC_RefreshNITGuild then SC_RefreshNITGuild() end
        end
    end
end)
