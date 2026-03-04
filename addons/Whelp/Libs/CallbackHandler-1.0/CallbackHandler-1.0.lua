--[[ CallbackHandler-1.0
    CallbackHandler is a back-end utility library that makes it easy for a library
    to fire callbacks to client code.
]]

local MAJOR, MINOR = "CallbackHandler-1.0", 7
local CallbackHandler = LibStub:NewLibrary(MAJOR, MINOR)

if not CallbackHandler then return end

local meta = {__index = function(tbl, key) tbl[key] = {} return tbl[key] end}

local function Dispatch(handlers, ...)
    local index, method = next(handlers)
    if not method then return end
    repeat
        if type(method) == "function" then
            method(...)
        else
            local obj = method
            method = handlers[index]
            if obj and type(method) == "string" then
                obj[method](obj, ...)
            end
        end
        index, method = next(handlers, index)
    until not method
end

function CallbackHandler:New(target, RegisterName, UnregisterName, UnregisterAllName)
    RegisterName = RegisterName or "RegisterCallback"
    UnregisterName = UnregisterName or "UnregisterCallback"
    UnregisterAllName = UnregisterAllName or "UnregisterAllCallbacks"

    local events = setmetatable({}, meta)
    local registry = {recurse = 0}

    function registry:Fire(eventname, ...)
        if not events[eventname] or not next(events[eventname]) then return end
        local oldrecurse = registry.recurse
        registry.recurse = oldrecurse + 1

        Dispatch(events[eventname], eventname, ...)

        registry.recurse = oldrecurse

        if registry.insertQueue and oldrecurse == 0 then
            for event, callbacks in pairs(registry.insertQueue) do
                local t = events[event]
                for _, method in pairs(callbacks) do
                    t[#t + 1] = method
                end
            end
            registry.insertQueue = nil
        end
    end

    target[RegisterName] = function(self, eventname, method, ...)
        if type(eventname) ~= "string" then
            error("Usage: "..RegisterName.."(eventname, method[, arg]): 'eventname' - string expected.", 2)
        end

        method = method or eventname

        local first = not events[eventname][1]
        local t = events[eventname]

        if registry.recurse > 0 then
            registry.insertQueue = registry.insertQueue or setmetatable({}, meta)
            t = registry.insertQueue[eventname]
        end

        t[#t + 1] = method
        t[#t + 1] = self

        if first and type(self.OnUsed) == "function" then
            self:OnUsed(target, eventname)
        end
    end

    target[UnregisterName] = function(self, eventname)
        if not self or self == target then
            error("Usage: "..UnregisterName.."(eventname): 'self' - Loss of reference.", 2)
        end
        if type(eventname) ~= "string" then
            error("Usage: "..UnregisterName.."(eventname): 'eventname' - string expected.", 2)
        end
        local t = events[eventname]
        if t then
            for i = 1, #t, 2 do
                if t[i + 1] == self then
                    t[i], t[i + 1] = nil, nil
                end
            end
        end
        if type(self.OnUnused) == "function" then
            self:OnUnused(target, eventname)
        end
    end

    target[UnregisterAllName] = function(self)
        if self == target then
            error("Usage: "..UnregisterAllName.."(): 'self' - Loss of reference.", 2)
        end
        for eventname, handlers in pairs(events) do
            for i = 1, #handlers, 2 do
                if handlers[i + 1] == self then
                    handlers[i], handlers[i + 1] = nil, nil
                end
            end
        end
    end

    return registry
end
