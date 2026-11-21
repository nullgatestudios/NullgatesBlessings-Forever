-- Nullgate's Blessings: the group, the blessings on each member and who cast them, and the hidden
-- addon messages paladins running the addon share (their blessings, leanings, tank marks and locks).
local _, ns = ...

local Group = {}
ns.Group = Group

Group.PREFIX = "NGBless"
local peers = {}        -- [name] = hello info from other paladins running the addon
local leaderLocks = {}  -- [paladin][player] = key, from the group leader or an assistant
Group.peers = peers

function Group.SpellName(spellID)
    if not spellID then return nil end
    if C_Spell and C_Spell.GetSpellName then return C_Spell.GetSpellName(spellID) end
    return GetSpellInfo and (GetSpellInfo(spellID)) or nil
end

function Group.IsKnown(spellID)
    local known = (C_SpellBook and C_SpellBook.IsSpellKnown) or IsSpellKnown or IsPlayerSpell
    return known ~= nil and known(spellID) == true
end

function Group.Me()
    return UnitName("player")
end

-- The talent tree with the most points (1 Holy, 2 Protection, 3 Retribution), or nil.
function Group.MyTree()
    if not GetTalentTabInfo then return nil end
    local best, bestPoints = nil, 0
    for tab = 1, 3 do
        -- Classic returns (name, icon, pointsSpent, ...); newer clients return pointsSpent fifth.
        local _, _, third, _, fifth = GetTalentTabInfo(tab)
        local points = (type(third) == "number" and third) or (type(fifth) == "number" and fifth) or 0
        if points > bestPoints then best, bestPoints = tab, points end
    end
    return best
end

-- --- Members -------------------------------------------------------------------------

function Group.Members()
    local list = {}
    local function Add(unit, group)
        if not UnitExists(unit) then return end
        local _, class = UnitClass(unit)
        local reachable = UnitIsConnected(unit) and not UnitIsDeadOrGhost(unit)
        if reachable and not UnitIsUnit(unit, "player") then
            local inRange, checked = UnitInRange(unit)
            if checked and not inRange then reachable = false end
        end
        local role = UnitGroupRolesAssigned and UnitGroupRolesAssigned(unit) or "NONE"
        list[#list + 1] = { unit = unit, name = UnitName(unit), class = class, level = UnitLevel(unit), group = group,
                            role = role, reachable = reachable,
                            mainTank = GetPartyAssignment and GetPartyAssignment("MAINTANK", unit) or false }
    end
    if IsInRaid() then
        for i = 1, GetNumGroupMembers() do
            local _, _, group = GetRaidRosterInfo(i)
            Add("raid" .. i, group or 1)
        end
    else
        Add("player", 1)
        for i = 1, GetNumSubgroupMembers() do Add("party" .. i, 1) end
    end
    table.sort(list, function(a, b)
        if a.group ~= b.group then return a.group < b.group end
        return (a.name or "") < (b.name or "")
    end)
    return list
end

-- Tank marks from every paladin running the addon (and you): marked tanks and marked not-tanks.
function Group.TankMarks()
    local tanks, notTanks = {}, {}
    local function Merge(info)
        for name in pairs(info.tanks or {}) do tanks[name] = true end
        for name in pairs(info.notTanks or {}) do notTanks[name] = true end
    end
    Merge(Group.MyInfo())
    for _, info in pairs(peers) do Merge(info) end
    return tanks, notTanks
end

-- Hand marks win; then the group role, the raid's Main Tank, and (for you) a Protection talent guess.
function Group.IsTank(member, tanks, notTanks)
    if notTanks[member.name] then return false end
    if tanks[member.name] then return true end
    return member.role == "TANK" or member.mainTank == true
end

-- --- Blessings on a unit ------------------------------------------------------------------
local nameToKey
local function NameToKey()
    if not nameToKey then
        nameToKey = {}
        for _, b in ipairs(ns.BLESSINGS) do
            local single, greater = Group.SpellName(b.single[1][1]), Group.SpellName(b.greater[1] and b.greater[1][1])
            if single then nameToKey[single] = b.key end
            if greater then nameToKey[greater] = b.key end
        end
    end
    return nameToKey
end

-- The blessings on a unit: taken = set of keys cast by paladins not in `addonNames`; mine =
-- [key] = seconds left on blessings you cast.
function Group.Blessings(unit, addonNames, now)
    local taken, mine, map, me = {}, {}, NameToKey(), Group.Me()
    for i = 1, 40 do
        local name, expires, caster
        if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
            local a = C_UnitAuras.GetAuraDataByIndex(unit, i, "HELPFUL")
            if not a then break end
            name, expires, caster = a.name, a.expirationTime, a.sourceUnit
        else
            local n, _, _, _, _, e, c = UnitBuff(unit, i)
            if not n then break end
            name, expires, caster = n, e, c
        end
        local key = name and map[name]
        if key then
            local casterName = caster and UnitName(caster)
            if casterName == me then
                mine[key] = (expires and expires > 0) and (expires - now) or math.huge
            elseif not (casterName and addonNames[casterName]) then
                taken[key] = true
            end
        end
    end
    return taken, mine
end

-- --- Your own info and the paladins ------------------------------------------------------

function Group.MyInfo()
    local db = ns.db
    local known, knownAuras = {}, {}
    for _, b in ipairs(ns.BLESSINGS) do
        for _, r in ipairs(b.single) do if Group.IsKnown(r[1]) then known[b.key] = true end end
    end
    for _, a in ipairs(ns.AURAS) do
        for _, r in ipairs(a.ranks) do if Group.IsKnown(r[1]) then knownAuras[a.key] = true end end
    end
    local tanks, notTanks = {}, {}
    for name, mark in pairs(db.tanks) do
        if mark then tanks[name] = true else notTanks[name] = true end
    end
    local me = Group.Me()
    local myRole = UnitGroupRolesAssigned and UnitGroupRolesAssigned("player") or "NONE"
    if db.tanks[me] == nil and myRole == "NONE" and Group.MyTree() == 2 then tanks[me] = true end
    return { known = known, lean = db.lean or ns.Engine.DefaultLean(Group.MyTree()), knownAuras = knownAuras,
             auraLean = db.auraLean, tanks = tanks, notTanks = notTanks, locks = db.locks }
end

-- The paladins in the group running the addon (you included), for the engine.
function Group.Paladins(members)
    local list, inGroup = {}, {}
    for _, m in ipairs(members) do inGroup[m.name] = m.class end
    local me = Group.Me()
    local _, myClass = UnitClass("player")
    if myClass == "PALADIN" then
        local info = Group.MyInfo()
        list[#list + 1] = { name = me, known = info.known, lean = info.lean, knownAuras = info.knownAuras, auraLean = info.auraLean }
    end
    for name, info in pairs(peers) do
        if inGroup[name] == "PALADIN" and name ~= me then
            list[#list + 1] = { name = name, known = info.known, lean = info.lean, knownAuras = info.knownAuras, auraLean = info.auraLean }
        end
    end
    return list
end

-- Locks for the engine: each paladin's own locks, with the leader's on top.
function Group.Locks()
    local locks = { [Group.Me()] = {} }
    for player, key in pairs(ns.db.locks) do locks[Group.Me()][player] = key end
    for name, info in pairs(peers) do
        locks[name] = locks[name] or {}
        for player, key in pairs(info.locks or {}) do locks[name][player] = key end
    end
    for pal, players in pairs(leaderLocks) do
        locks[pal] = locks[pal] or {}
        for player, key in pairs(players) do locks[pal][player] = key end
    end
    return locks
end

function Group.LeaderLocks()
    return leaderLocks
end

-- --- Messages ----------------------------------------------------------------------------

local function Channel()
    if IsInRaid() then return "RAID" end
    if GetNumSubgroupMembers() > 0 then return "PARTY" end
end

function Group.Send(message)
    local channel = Channel()
    if channel and C_ChatInfo and C_ChatInfo.SendAddonMessage then
        C_ChatInfo.SendAddonMessage(Group.PREFIX, message, channel)
    end
end

local helloQueued = false
function Group.Hello()
    if helloQueued then return end
    helloQueued = true
    C_Timer.After(2, function()
        helloQueued = false
        local _, class = UnitClass("player")
        if class == "PALADIN" or next(ns.db.tanks) then Group.Send(ns.Engine.EncodeHello(Group.MyInfo())) end
    end)
end

function Group.CanLead(name)
    if not name then return false end
    return (UnitIsGroupLeader and UnitIsGroupLeader(name)) or (UnitIsGroupAssistant and UnitIsGroupAssistant(name)) or false
end

function Group.SendLeaderLocks(locks)
    leaderLocks = locks
    Group.Send(ns.Engine.EncodeLeaderLocks(locks))
end

-- Returns true when the message changed anything.
function Group.OnMessage(prefix, message, _, sender)
    if prefix ~= Group.PREFIX or not sender then return false end
    local name = Ambiguate and Ambiguate(sender, "none") or sender
    if name == Group.Me() then return false end
    local hello = ns.Engine.DecodeHello(message)
    if hello then
        local first = peers[name] == nil
        peers[name] = hello
        if first then Group.Hello() end -- answer a newcomer so they know about us
        return true
    end
    local locks = ns.Engine.DecodeLeaderLocks(message)
    if locks and Group.CanLead(name) then
        leaderLocks = locks
        return true
    end
    return false
end

-- Forget paladins who left the group.
function Group.Prune(members)
    local present = {}
    for _, m in ipairs(members) do present[m.name] = true end
    for name in pairs(peers) do if not present[name] then peers[name] = nil end end
end
