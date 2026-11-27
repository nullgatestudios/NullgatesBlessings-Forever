-- Nullgate's Blessings: saved data, events, sync, the announcement, the Symbol of Kings warning and
-- slash commands.
local addonName, ns = ...

local L = ns.L

ns.DEFAULTS = {
    locked = false,
    hideWhenFresh = true,               -- hide the bar until a blessing is under the warning time
    scale = 1,
    lean = nil,                         -- your blessing leanings (nil = from your talents)
    auraLean = { "devotion", "retribution", "concentration" },
    locks = {},                         -- [player or class] = key: your own locks
    lists = {},                         -- [listId] = list: your edits to the recommended blessing lists
    tanks = {},                         -- [name] = true (tank) or false (not a tank): your hand marks
    warnMinutes = 5,                    -- red when your blessing is missing or under this
    topUpMinutes = 10,                  -- Top Up refreshes blessings under this
    showTopUp = true,
    showAura = true,
    symbolWarning = 10,                 -- warn below this many Symbol of Kings in a raid (0 = off)
    language = "auto",
}

-- Fills in missing settings; a missing table setting gets a copy of its default.
local function Merge(target, defaults)
    for key, value in pairs(defaults) do
        if target[key] == nil or (type(value) == "table" and type(target[key]) ~= "table") then
            if type(value) == "table" then
                local copy = {}
                for k, v in pairs(value) do copy[k] = v end
                target[key] = copy
            else
                target[key] = value
            end
        end
    end
end

function ns.Print(text)
    print("|cff00c0ffBlessings:|r " .. tostring(text))
end

-- Secure rows and the macro only change out of combat (the kit's queue).
local safe = NullgateBuffKit.NewSafeQueue()
ns.WhenSafe = safe.Run

-- --- Announce -----------------------------------------------------------------------------

-- One line per paladin: "Ironwall: Shiv Might, Frosty Kings".
function ns.AnnounceLines(state)
    local lines, names = {}, {}
    for name in pairs(state.plan) do names[#names + 1] = name end
    table.sort(names)
    for _, name in ipairs(names) do
        local parts = {}
        for _, col in ipairs(state.columns) do
            local key = state.plan[name][col.name]
            if key then parts[#parts + 1] = col.name .. " " .. ns.PlanWindow.Short(key) end
        end
        if #parts > 0 then lines[#lines + 1] = name .. ": " .. table.concat(parts, ", ") end
    end
    return lines
end

function ns.Announce()
    local channel = IsInRaid() and "RAID" or (GetNumSubgroupMembers() > 0 and "PARTY") or nil
    local lines = ns.AnnounceLines(ns.Plan.Build())
    if #lines == 0 then
        ns.Print(L["Nothing to announce yet."])
        return
    end
    for _, line in ipairs(lines) do
        if channel then SendChatMessage(line, channel) else ns.Print(line) end
    end
end

-- --- Symbol of Kings ---------------------------------------------------------------------------
local symbolWarned = false
local function CheckSymbols()
    local state = ns.Buttons.State()
    if not state or state.mode ~= "raid" or #state.targets == 0 or (ns.db.symbolWarning or 0) <= 0 then
        symbolWarned = false
        return
    end
    local count = (C_Item and C_Item.GetItemCount or GetItemCount)(ns.BLESSINGS[1].reagent) or 0
    local low = count < ns.db.symbolWarning
    if low and not symbolWarned then ns.Print(string.format(L["Low on Symbol of Kings: %d left."], count)) end
    symbolWarned = low
end

-- --- Events (refresh at most every half second) --------------------------------------------
local queued, active = false, false
function ns.Refresh()
    if queued then return end
    queued = true
    C_Timer.After(0.5, function()
        queued = false
        ns.Buttons.Update()
        ns.Macro.Update()
        ns.PlanWindow.Draw()
        CheckSymbols()
    end)
end

BINDING_HEADER_NULLGATESBLESSINGS = "Nullgate's Blessings"

local events = CreateFrame("Frame")
events:SetScript("OnEvent", function(_, event, ...)
    local arg1 = ...
    if event == "ADDON_LOADED" then
        if arg1 == addonName then
            if type(NullgatesBlessingsDB) ~= "table" then NullgatesBlessingsDB = {} end
            Merge(NullgatesBlessingsDB, ns.DEFAULTS)
            ns.db = NullgatesBlessingsDB
            ns.SetLanguage(ns.db.language)
            if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then C_ChatInfo.RegisterAddonMessagePrefix(ns.Group.PREFIX) end
            _G["BINDING_NAME_CLICK NullgatesBlessingsTopUp:LeftButton"] = L["Top Up your blessings"]
            _G["BINDING_NAME_CLICK NullgatesBlessingsAura:LeftButton"] = L["Turn on your aura"]
        end
        if arg1 == addonName or arg1 == "NullgatesAddonConfig-Forever" then ns.Options.RegisterHub() end
    elseif event == "PLAYER_LOGIN" then
        local _, class = UnitClass("player")
        active = class == "PALADIN"
        if active then
            ns.Buttons.Create()
            C_Timer.NewTicker(5, ns.Buttons.UpdateTimers)
            C_Timer.NewTicker(3, ns.Inspect.Tick)
        end
        ns.Group.Hello()
    elseif event == "PLAYER_LOGOUT" then
        -- When the settings were last saved: Nullgate's Buffs keeps whichever copy is newer.
        if ns.db then ns.db.savedAt = time() end
    elseif event == "PLAYER_REGEN_ENABLED" then
        safe.Flush()
        if active then ns.Refresh() end
    elseif event == "CHAT_MSG_ADDON" then
        if ns.Group.OnMessage(...) and active then ns.Refresh() end
    elseif event == "GROUP_ROSTER_UPDATE" then
        ns.Group.Hello()
        if active then ns.Refresh() end
    elseif not active then
        return
    elseif event == "UNIT_AURA" then
        if arg1 == "player" or arg1 == "target" or (arg1 and (arg1:match("^party%d") or arg1:match("^raid%d"))) then ns.Refresh() end
    elseif event == "PLAYER_FOCUS_CHANGED" then
        ns.Refresh() -- your focus gets your Oath of Light
    elseif event == "PLAYER_TARGET_CHANGED" then
        ns.Macro.Update()
    elseif event == "UNIT_LEVEL" then
        -- a level-up can make a better blessing reachable (Kings from level 10)
        if arg1 == "target" then ns.Macro.Update() end
        if arg1 == "player" or (arg1 and (arg1:match("^party%d") or arg1:match("^raid%d"))) then ns.Refresh() end
    elseif event == "INSPECT_READY" then
        ns.Inspect.OnReady(arg1)
    elseif event == "UPDATE_SHAPESHIFT_FORM" or event == "UPDATE_SHAPESHIFT_FORMS" then
        ns.Refresh() -- an aura turned on or off
    else -- spells or talents changed
        ns.Group.Hello()
        ns.Refresh()
    end
end)
for _, event in ipairs({ "ADDON_LOADED", "PLAYER_LOGIN", "PLAYER_LOGOUT", "PLAYER_REGEN_ENABLED", "CHAT_MSG_ADDON", "GROUP_ROSTER_UPDATE",
    "UNIT_AURA", "SPELLS_CHANGED", "CHARACTER_POINTS_CHANGED", "UPDATE_SHAPESHIFT_FORM", "UPDATE_SHAPESHIFT_FORMS", "INSPECT_READY", "PLAYER_TARGET_CHANGED", "PLAYER_FOCUS_CHANGED", "UNIT_LEVEL" }) do
    events:RegisterEvent(event)
end

local function Help()
    ns.Print(L["commands:"])
    print("  /nbless - " .. L["show or hide the blessing plan"])
    print("  /nbless tank <" .. L["name"] .. "> - " .. L["mark a player as a tank, not a tank, or automatic"])
    print("  /nbless announce - " .. L["post the plan to group chat"])
    print("  /nbless config - " .. L["open the settings"])
    print("  /nbless lock | unlock - " .. L["lock or unlock the bar"])
    print("  /nbless reset - " .. L["reset the bar's position"])
    print("  /nbless macro - " .. L["make the smart blessing macro and put it on your cursor"])
    print("  /nbless check - " .. L["test what the addon needs in this client (results are saved)"])
end

SLASH_NULLGATESBLESSINGS1 = "/nbless"
SLASH_NULLGATESBLESSINGS2 = "/blessings"
SlashCmdList["NULLGATESBLESSINGS"] = function(msg)
    msg = msg or ""
    local command, rest = msg:match("^%s*(%S*)%s*(.-)%s*$")
    command = string.lower(command or "")
    if command == "" or command == "plan" then
        ns.PlanWindow.Toggle()
    elseif command == "check" then
        ns.Check.Run()
    elseif command == "announce" then
        ns.Announce()
    elseif command == "config" or command == "options" then
        ns.Options.Open()
    elseif command == "tank" then
        local name = rest ~= "" and rest or UnitName("target")
        if not name then
            ns.Print(L["Target a player or type their name after /nbless tank."])
            return
        end
        -- automatic -> tank -> not a tank -> automatic
        local mark = ns.db.tanks[name]
        if mark == nil then ns.db.tanks[name] = true elseif mark then ns.db.tanks[name] = false else ns.db.tanks[name] = nil end
        local now = ns.db.tanks[name]
        ns.Print(string.format(now == nil and L["%s: tank detection is automatic."] or (now and L["%s is marked as a tank."]
            or L["%s is marked as not a tank."]), name))
        ns.Group.Hello()
        ns.Refresh()
    elseif not active then
        ns.Print(L["Only paladins have a blessing bar; /nbless tank and the plan work for everyone."])
    elseif command == "lock" or command == "unlock" then
        ns.db.locked = command == "lock"
        ns.Buttons.Update()
    elseif command == "reset" then
        ns.Buttons.ResetPosition()
    elseif command == "macro" then
        ns.Macro.Make()
    else
        Help()
    end
end
