-- ============================================================
-- SlyError.lua  —  SlySuite shared error capture + storage
-- Wraps addon code in xpcall, stores errors to SavedVariables
-- so they persist across sessions and can be reviewed via:
--   /slyerror           — show recent errors in chat
--   /slyerror clear     — wipe stored errors
--   /slyerror dump N    — print last N errors (default 10)
--
-- API for other SlySuite addons:
--   SlyError.guard(fn, label)         → wrapped fn, auto-logs errors
--   SlyError.pcall(label, fn, ...)    → protected call, returns ok, result
--   SlyError.Log(label, msg, stack)   → manual log entry
-- ============================================================

SlyError      = SlyError or {}
SlyError._db  = nil       -- set on ADDON_LOADED
SlyError._queue = nil     -- pre-DB buffer

local ADDON_NAME     = "SlySuite_Error"
local MAX_ERRORS     = 100   -- rolling window on disk
local MAX_SHOW       = 15    -- default shown by /slyerror

-- ============================================================
-- DB init
-- ============================================================
local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("ADDON_LOADED")
initFrame:SetScript("OnEvent", function(self, event, addon)
    if addon ~= ADDON_NAME then return end
    SlyErrorDB         = SlyErrorDB or {}
    SlyErrorDB.errors  = SlyErrorDB.errors or {}
    SlyErrorDB.version = 1
    SlyError._db = SlyErrorDB

    -- Flush any errors that were caught before DB was ready
    if SlyError._queue then
        for _, e in ipairs(SlyError._queue) do
            tinsert(SlyError._db.errors, e)
        end
        SlyError._queue = nil
    end
    self:UnregisterEvent("ADDON_LOADED")
end)

-- ============================================================
-- Internal storage
-- ============================================================
local function _Trim(s, n)
    s = tostring(s or "")
    return #s > n and s:sub(1, n) .. "…" or s
end

local function _Store(label, msg, stack)
    local entry = {
        label = _Trim(label or "unknown", 64),
        msg   = _Trim(msg              , 400),
        stack = _Trim(stack or ""      , 600),
        t     = time(),
        dt    = date("%m-%d %H:%M:%S"),
    }

    local db = SlyError._db
    if not db then
        SlyError._queue = SlyError._queue or {}
        tinsert(SlyError._queue, entry)
        return
    end

    tinsert(db.errors, entry)
    -- Rolling window — drop oldest
    while #db.errors > MAX_ERRORS do
        tremove(db.errors, 1)
    end
end

-- ============================================================
-- Public API
-- ============================================================

--- Log an error entry without halting execution.
function SlyError.Log(label, msg, stack)
    _Store(label, msg, stack or debugstack(2, 10, 5))
end

--- Protected call — logs any error and returns ok, result.
--- Usage: local ok, val = SlyError.pcall("MyAddon:fn", fn, arg1, arg2)
function SlyError.pcall(label, fn, ...)
    local ok, result = xpcall(fn, function(err)
        _Store(label, err, debugstack(2, 10, 5))
        return err
    end, ...)
    return ok, result
end

--- Wrap fn so every call is protected and errors are logged + shown once.
--- Usage: myFn = SlyError.guard(myFn, "MyAddon:myFn")
function SlyError.guard(fn, label)
    local reported = false
    return function(...)
        local ok, result = xpcall(fn, function(err)
            _Store(label, err, debugstack(2, 10, 5))
            return err
        end, ...)
        if not ok then
            -- Show in chat on first occurrence per session so debugging is immediate
            if not reported then
                reported = true
                local short = _Trim(tostring(result), 120)
                DEFAULT_CHAT_FRAME:AddMessage(
                    "|cffff4444[SlyError]|r " .. (label or "?") .. ": " .. short)
            end
        end
        return result
    end
end

-- ============================================================
-- Global WoW error handler hook
-- Any unprotected Lua error in any addon reaches here.
-- ============================================================
do
    local _prev = geterrorhandler()
    seterrorhandler(function(msg)
        -- Attribute a source label from the error string when possible
        local src = "GLOBAL"
        if type(msg) == "string" then
            local file = msg:match("Interface[/\\]AddOns[/\\]([^/\\]+)[/\\]")
            if file then src = file end
        end
        _Store(src, msg, debugstack(2, 10, 5))
        if _prev then _prev(msg) end
    end)
end

-- ============================================================
-- /slyerror slash command
-- ============================================================
local function Cmd(args)
    args = (args or ""):match("^%s*(.-)%s*$")  -- trim

    local db = SlyError._db
    if not db then
        DEFAULT_CHAT_FRAME:AddMessage("|cffff9900[SlyError]|r DB not loaded yet.")
        return
    end

    local errs = db.errors
    local total = #errs

    -- clear
    if args == "clear" then
        db.errors = {}
        DEFAULT_CHAT_FRAME:AddMessage(
            "|cff88ff88[SlyError]|r Cleared " .. total .. " stored error(s).")
        return
    end

    -- dump N
    local n = tonumber(args) or MAX_SHOW
    if total == 0 then
        DEFAULT_CHAT_FRAME:AddMessage("|cff88ff88[SlyError]|r No errors logged. \\o/")
        return
    end

    local show = math.min(total, n)
    DEFAULT_CHAT_FRAME:AddMessage(string.format(
        "|cffff9900[SlyError]|r %d error(s) on disk — last %d:", total, show))

    for i = total - show + 1, total do
        local e = errs[i]
        DEFAULT_CHAT_FRAME:AddMessage(string.format(
            " |cff888888[%s]|r |cffff7070%s|r  %s",
            e.dt or "?", e.label or "?",
            (e.msg or ""):gsub("\n", " ")))
        if e.stack and e.stack ~= "" then
            DEFAULT_CHAT_FRAME:AddMessage("  |cff444444" ..
                e.stack:gsub("\n", "\n  ") .. "|r")
        end
    end
end

SLASH_SLYERROR1 = "/slyerror"
SlashCmdList["SLYERROR"] = Cmd
