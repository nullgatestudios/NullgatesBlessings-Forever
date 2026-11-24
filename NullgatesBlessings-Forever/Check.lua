-- Nullgate's Blessings: /nbless check, the in-game self test (phase 0 of PLAN.md).
-- Every result goes to chat and to NullgatesBlessingsDB.check, so the log can be copied from
-- WTF\Account\<account>\<realm>\<character>\SavedVariables\NullgatesBlessings-Forever.lua.
--
--   1. Which calls exist; your known blessings, auras, talent tree and leanings; each member's role,
--      Main Tank flag, tank decision, and the blessings on them with who cast each (to confirm that
--      blessing auras report their caster); the paladins heard from over addon messages.
--   2. Whether Salvation shares the blessing slot: with Salvation and another blessing of yours on
--      the same player, both show (separate) or only the last one cast (shared).
local _, ns = ...

local Check = {}
ns.Check = Check

local LOG_LIMIT = 400
local L = ns.L


local function Log(text)
    local db = ns.db
    if db then
        db.check = db.check or {}
        if #db.check >= LOG_LIMIT then table.remove(db.check, 1) end
        db.check[#db.check + 1] = text
    end
    print("|cff00c0ffNullgate's Blessings check:|r " .. text)
    if NullgateReport then NullgateReport.Update("blessings") end
end
Check.Log = Log

-- Opens the report window every Nullgate addon shares (NullgateReport.lua) with this check's log,
-- ready to copy and paste into the report form on our website.
function Check.ShowReport()
    local L = ns.L
    return NullgateReport.Show({
        slug = "blessings", name = "Nullgate's Blessings", addon = "NullgatesBlessings-Forever", command = "/nbless check",
        lines = function() return ns.db and ns.db.check end,
        title = L["Bug report"], selectAll = L["Select all"], selectLink = L["Select link"],
        help = L["Press Ctrl+C to copy this report, then paste it into a new report at the link below, with a few words on what happened."],
    })
end

local function Exists(path)
    local value = _G
    for part in path:gmatch("[^.]+") do
        if type(value) ~= "table" then return false end
        value = value[part]
    end
    return type(value) == "function"
end

local function Keys(set)
    local list = {}
    for k in pairs(set or {}) do list[#list + 1] = k end
    table.sort(list)
    return table.concat(list, ",")
end

function Check.Run()
    if ns.db then ns.db.check = {} end
    local _, class = UnitClass("player")
    Log(string.format("client %s, build %s, interface %s; class %s, level %s; data build %s",
        tostring(GetBuildInfo and select(1, GetBuildInfo())), tostring(GetBuildInfo and select(2, GetBuildInfo())),
        tostring(GetBuildInfo and select(4, GetBuildInfo())), tostring(class), tostring(UnitLevel("player")),
        tostring(ns.BLESSING_DATA_BUILD)))
    local calls = {}
    for _, name in ipairs({ "C_UnitAuras.GetAuraDataByIndex", "UnitBuff", "UnitGroupRolesAssigned", "GetPartyAssignment",
        "C_ChatInfo.SendAddonMessage", "C_ChatInfo.RegisterAddonMessagePrefix", "GetTalentTabInfo", "UnitIsGroupAssistant",
        "NotifyInspect", "CanInspect", "CheckInteractDistance", "ClearInspectPlayer" }) do
        calls[#calls + 1] = name .. "=" .. (Exists(name) and "yes" or "no")
    end
    Log("calls: " .. table.concat(calls, " "))
    local info = ns.Group.MyInfo()
    Log(string.format("you: blessings %s, auras %s, talent tree %s, leanings %s, tank marks %s / not %s", Keys(info.known),
        Keys(info.knownAuras), tostring(ns.Group.MyTree()), table.concat(info.lean or {}, ","), Keys(info.tanks), Keys(info.notTanks)))
    if GetTalentTabInfo then
        for tab = 1, 3 do
            local r = { GetTalentTabInfo(tab) }
            local parts = {}
            for i = 1, 6 do parts[i] = tostring(r[i]) end
            Log("talent tab " .. tab .. ": " .. table.concat(parts, ", "))
        end
    end
    local tanks, notTanks = ns.Group.TankMarks()
    local now = GetTime()
    for _, m in ipairs(ns.Group.Members()) do
        local auras = {}
        for i = 1, 40 do
            local a = ns.Group.ReadAura(m.unit, i)
            if a == nil then break end
            if a == false then auras[#auras + 1] = "hidden by the game"; break end
            local name, caster = a.name, a.sourceUnit
            if name and (name:find("Bless", 1, true) or name:find("Salvation", 1, true)) then
                auras[#auras + 1] = name .. " from " .. tostring(caster and UnitName(caster))
            end
        end
        local taken, mine = ns.Group.Blessings(m.unit, {}, now)
        local tank = ns.Group.IsTank(m, tanks, notTanks)
        Log(string.format("%s (%s %s): role %s, spec %s, main tank %s, tank %s, list %s | %s | taken %s, yours %s", tostring(m.name),
            tostring(m.class), tostring(m.unit), tostring(m.role), tostring(m.spec), tostring(m.mainTank), tostring(tank),
            ns.Engine.ListFor(m.class, m.spec, m.role, tank), #auras > 0 and table.concat(auras, "; ") or "no blessings", Keys(taken), Keys(mine)))
    end
    local peers = {}
    for name, p in pairs(ns.Group.peers) do peers[#peers + 1] = name .. " (" .. Keys(p.known) .. ")" end
    Log("paladins heard from: " .. (#peers > 0 and table.concat(peers, ", ") or "none"))
    local source, lists = ns.Group.ListSource(ns.Group.Members())
    local edited = {}
    for id in pairs(lists or {}) do edited[#edited + 1] = id end
    table.sort(edited)
    Log(string.format("blessing lists from %s; edited: %s", tostring(source or "nobody (recommended)"), #edited > 0 and table.concat(edited, ",") or "none"))
    local oath = ns.OATH_OF_LIGHT
    local o = ns.Buttons.State() and ns.Buttons.State().oath
    Log(string.format("Oath of Light: talent %s, target %s", tostring(oath and ns.Group.IsKnown(oath[1])), tostring(o and o.label or "none")))
    if ns.Plan.Blessing("salvation") then
        Log("Salvation test: put Salvation and another blessing of yours on one player, then run /nbless check again; if both show above, Salvation is separate from the blessing slot")
    end
    Check.ShowReport()
end
