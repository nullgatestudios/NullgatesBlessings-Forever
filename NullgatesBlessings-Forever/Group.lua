-- Nullgate's Blessings: the group, the blessings on each member and who cast them, and the hidden
-- addon messages paladins running the addon share (their blessings, leanings, tank marks and locks).
local _, ns = ...

local Group = {}
ns.Group = Group

Group.PREFIX = "NGBless"
local peers = {}        -- [name] = hello info from other paladins running the addon
local leaderLocks = {}  -- [paladin][player] = key, from the group leader or an assistant
local specs = {}        -- [name] = { tree, at }: talent trees learned by inspecting, yours or shared
local peerLists = {}    -- [name] = edited blessing lists from a paladin or leader running the addon
Group.peers, Group.specs, Group.peerLists = peers, specs, peerLists

local K = NullgateBuffKit
Group.SpellName, Group.IsKnown, Group.IsSecret, Group.BareName = K.SpellName, K.IsKnown, K.IsSecret, K.BareName

function Group.Me()
    return UnitName("player")
end

-- The talent tree with the most points (1, 2 or 3; for a paladin 1 Holy, 2 Protection, 3
-- Retribution), or nil: yours, or the inspected player's when `inspect` is true.
function Group.Tree(inspect)
    if not GetTalentTabInfo then return nil end
    local best, bestPoints = nil, 0
    for tab = 1, 3 do
        -- Classic returns (name, icon, pointsSpent, ...); newer clients return pointsSpent fifth.
        local _, _, third, _, fifth = GetTalentTabInfo(tab, inspect)
        local points = (type(third) == "number" and not Group.IsSecret(third) and third)
            or (type(fifth) == "number" and not Group.IsSecret(fifth) and fifth) or 0
        if points > bestPoints then best, bestPoints = tab, points end
    end
    return best
end

function Group.MyTree() return Group.Tree(false) end

-- A player's talent tree, or nil when it isn't known.
function Group.Spec(name)
    if name == Group.Me() then return Group.MyTree() end
    return specs[name] and specs[name].tree
end

-- Records a learned tree; returns true when it's new or changed.
function Group.SetSpec(name, tree, now)
    if not (name and tree) then return false end
    local old = specs[name]
    specs[name] = { tree = tree, at = now or 0 }
    return not old or old.tree ~= tree
end

-- --- Members -------------------------------------------------------------------------

function Group.Members()
    return K.Members(function(m) m.spec = Group.Spec(m.name) end)
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

-- Hand marks win; then the group role, the raid's Main Tank, and a Protection warrior or paladin
-- (from their talents).
function Group.IsTank(member, tanks, notTanks)
    if notTanks[member.name] then return false end
    if tanks[member.name] then return true end
    if member.role == "TANK" or member.mainTank == true then return true end
    return (member.class == "WARRIOR" and member.spec == 3) or (member.class == "PALADIN" and member.spec == 2) or false
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

local IsSecret = K.IsSecret
local ReadAura = K.ReadAura
Group.ReadAura = ReadAura

-- The last full read of each unit, used while the game hides its auras.
local lastRead = {} -- [unit] = { name, at, taken, mine, current }

local function LastRead(unit, now)
    local last, name = lastRead[unit], UnitName(unit)
    local taken, mine, current = {}, {}, {}
    if last and not IsSecret(name) and last.name == name then
        for key in pairs(last.taken) do taken[key] = true end
        for key, left in pairs(last.mine) do
            left = left - (now - last.at)
            if left > 0 then mine[key] = left end
        end
        for pal, key in pairs(last.current) do current[pal] = key end
    end
    return taken, mine, current
end

-- The blessings on a unit: taken = set of keys cast by paladins not in `addonNames`; mine =
-- [key] = seconds left on blessings you cast; current = [paladin] = key for you and the paladins in
-- `addonNames`. While the game hides the unit's auras, the last full read is used.
function Group.Blessings(unit, addonNames, now)
    local taken, mine, current, map, me = {}, {}, {}, NameToKey(), Group.Me()
    for i = 1, 40 do
        local a = ReadAura(unit, i)
        if a == nil then break end
        if a == false then return LastRead(unit, now) end
        local name, expires, caster = a.name, a.expirationTime, a.sourceUnit
        local key = name and map[name]
        if key then
            local casterName = caster and UnitName(caster)
            if IsSecret(casterName) then casterName = nil end
            if casterName == me then
                mine[key] = (expires and expires > 0) and (expires - now) or math.huge
                current[me] = key
            elseif casterName and addonNames[casterName] then
                current[casterName] = key
            else
                taken[key] = true
            end
        end
    end
    local name = UnitName(unit)
    lastRead[unit] = { name = not IsSecret(name) and name or nil, at = now, taken = taken, mine = mine, current = current }
    return taken, mine, current
end

-- Seconds left on your own aura `spellID` on a unit (math.huge when it doesn't run out), 0 when it
-- isn't there, or nil while the game hides the unit's auras.
function Group.MyAuraLeft(unit, spellID, now)
    local name, me = Group.SpellName(spellID), Group.Me()
    for i = 1, 40 do
        local a = ReadAura(unit, i)
        if a == nil then return 0 end
        if a == false then return nil end
        if a.spellId == spellID or (name and a.name == name) then
            local caster = a.sourceUnit and UnitName(a.sourceUnit)
            if not IsSecret(caster) and caster == me then
                return (a.expirationTime and a.expirationTime > 0) and (a.expirationTime - now) or math.huge
            end
        end
    end
    return 0
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

-- The group leader's name, or nil.
local function Leader(members)
    for _, m in ipairs(members) do
        if m.unit and UnitIsGroupLeader and UnitIsGroupLeader(m.unit) then return m.name end
    end
end

-- Whose edited blessing lists the group uses: the leader's when they run the addon, else the first
-- paladin running it (by name). Returns their name and lists (nil for the recommended ones).
function Group.ListSource(members)
    local me = Group.Me()
    local leader = Leader(members)
    local source
    if leader and (leader == me or peerLists[leader]) then
        source = leader
    else
        for _, p in ipairs(Group.Paladins(members)) do
            if not source or p.name < source then source = p.name end
        end
    end
    if not source then return nil, nil end
    local lists = source == me and ns.db.lists or peerLists[source]
    return source, (lists and next(lists)) and lists or nil
end

-- --- Messages ----------------------------------------------------------------------------

function Group.Send(message)
    K.Send(Group.PREFIX, message)
end

-- Specs to share: yours and every one learned in the group.
function Group.KnownSpecs()
    local list = {}
    for name, info in pairs(specs) do list[name] = info.tree end
    local mine = Group.MyTree()
    if mine then list[Group.Me()] = mine end
    return list
end

local helloQueued = false
function Group.Hello()
    if helloQueued then return end
    helloQueued = true
    C_Timer.After(2, function()
        helloQueued = false
        local _, class = UnitClass("player")
        local leading = UnitIsGroupLeader and UnitIsGroupLeader("player")
        if class == "PALADIN" or next(ns.db.tanks) then Group.Send(ns.Engine.EncodeHello(Group.MyInfo())) end
        if class == "PALADIN" or leading then
            for _, m in ipairs(ns.Engine.EncodeLists(ns.db.lists)) do Group.Send(m) end
        end
        for _, m in ipairs(ns.Engine.EncodeSpecs(Group.KnownSpecs())) do Group.Send(m) end
    end)
end

-- Shares one spec just learned.
function Group.SendSpec(name, tree)
    for _, m in ipairs(ns.Engine.EncodeSpecs({ [name] = tree })) do Group.Send(m) end
end

function Group.CanLead(name)
    if not name then return false end
    return (UnitIsGroupLeader and UnitIsGroupLeader(name)) or (UnitIsGroupAssistant and UnitIsGroupAssistant(name)) or false
end

function Group.SendLeaderLocks(locks)
    leaderLocks = locks
    Group.Send(ns.Engine.EncodeLeaderLocks(locks))
end

local BareName = K.BareName

-- Returns true when the message changed anything.
function Group.OnMessage(prefix, message, _, sender)
    if prefix ~= Group.PREFIX or not sender then return false end
    local name = BareName(sender)
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
    local learned = ns.Engine.DecodeSpecs(message)
    if learned then
        local changed = false
        local now = GetTime and GetTime() or 0
        for player, tree in pairs(learned) do
            if player ~= Group.Me() and Group.SetSpec(player, tree, now) then changed = true end
        end
        return changed
    end
    local lists = ns.Engine.DecodeLists(message)
    if lists == "reset" then
        peerLists[name] = {}
        return true
    elseif lists then
        peerLists[name] = peerLists[name] or {}
        for id, list in pairs(lists) do peerLists[name][id] = list end
        return true
    end
    return false
end

-- Forget paladins who left the group.
function Group.Prune(members)
    local present = {}
    for _, m in ipairs(members) do present[m.name] = true end
    for name in pairs(peers) do if not present[name] then peers[name] = nil end end
    for name in pairs(peerLists) do if not present[name] then peerLists[name] = nil end end
    for name in pairs(specs) do if not present[name] then specs[name] = nil end end
end
