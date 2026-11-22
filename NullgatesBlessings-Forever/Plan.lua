-- Nullgate's Blessings: turns the group into the engine's inputs and the engine's plan into your
-- targets. In a party every member is planned for (normal blessings); in a raid every class is
-- (Greater Blessings).
local _, ns = ...

local Plan = {}
ns.Plan = Plan

-- Oath of Light is refreshed when it has less than this left (it lasts 5 minutes).
Plan.OATH_REFRESH = 60

-- Your Oath of Light target, when you have the talent: your focus when it's someone in your group,
-- else the marked tank who has your Oath (only one at a time), else the first tank in range, else the
-- first tank. Not you. (Focus only steers the Oath: blessings follow the plan every paladin shares.)
local function OathTarget(members, info, now)
    local oath = ns.OATH_OF_LIGHT
    if not (oath and ns.Group.IsKnown(oath[1])) then return nil end
    local me, pick, pickLeft = ns.Group.Me(), nil, 0
    local focus
    if UnitExists("focus") then
        for _, m in ipairs(members) do
            if m.name ~= me and UnitIsUnit(m.unit, "focus") then focus = m end
        end
    end
    for _, m in ipairs(members) do
        if (focus and m == focus) or (not focus and info[m.name].tank and m.name ~= me) then
            local left = ns.Group.MyAuraLeft(m.unit, oath[1], now)
            if left == nil then left = math.huge end -- hidden from addons: assume it's fine until it can be read
            if left > 0 then pick, pickLeft = m, left; break end
            if not pick or (m.reachable and not pick.reachable) then pick, pickLeft = m, left end
        end
    end
    if not pick then return nil end
    return { label = pick.name, class = pick.class, key = "oath", oath = true, units = pick.reachable and { pick.unit } or {},
             level = pick.level or 1, remaining = pickLeft }
end

-- { mode, plan, paladins, targets, columns, auras, oath }
--   columns: the players (party) or classes (raid) in order, for the plan window
--   targets: what you cast: { label, key, units = { unit, ... }, level, remaining, greater }
--   oath: your Oath of Light target (same shape, key "oath"), or nil
function Plan.Build()
    local now = GetTime()
    local members = ns.Group.Members()
    ns.Group.Prune(members)
    local paladins = ns.Group.Paladins(members)
    local addonNames = {}
    for _, p in ipairs(paladins) do addonNames[p.name] = true end
    local tanks, notTanks = ns.Group.TankMarks()
    local raid = IsInRaid()

    local info = {}
    for _, m in ipairs(members) do
        local taken, mine, current = ns.Group.Blessings(m.unit, addonNames, now)
        info[m.name] = { member = m, taken = taken, mine = mine, current = current, tank = ns.Group.IsTank(m, tanks, notTanks) }
    end

    local players, columns = {}, {}
    if raid then
        local byClass, order = {}, {}
        for _, m in ipairs(members) do
            if m.class then
                if not byClass[m.class] then byClass[m.class] = {}; order[#order + 1] = m.class end
                table.insert(byClass[m.class], m)
            end
        end
        table.sort(order)
        for _, class in ipairs(order) do
            -- A blessing counts as taken for a class when at least half of it has it from someone else.
            local counts, n = {}, #byClass[class]
            for _, m in ipairs(byClass[class]) do
                for key in pairs(info[m.name].taken) do counts[key] = (counts[key] or 0) + 1 end
            end
            local taken = {}
            for key, c in pairs(counts) do if c * 2 >= n then taken[key] = true end end
            -- A paladin's blessing is kept for a class when at least half of it has it from them.
            local given = {}
            for _, m in ipairs(byClass[class]) do
                for pal, key in pairs(info[m.name].current) do
                    local id = pal .. ":" .. key
                    given[id] = (given[id] or 0) + 1
                end
            end
            local current, ids = {}, {}
            for id in pairs(given) do ids[#ids + 1] = id end
            table.sort(ids)
            for _, id in ipairs(ids) do
                local pal, key = id:match("^(.*):(%a+)$")
                if given[id] * 2 >= n and (not current[pal] or given[id] > given[pal .. ":" .. current[pal]]) then current[pal] = key end
            end
            players[#players + 1] = { name = class, class = class, role = "NONE", taken = taken, current = current }
            columns[#columns + 1] = { name = class, class = class, members = byClass[class] }
        end
    else
        for _, m in ipairs(members) do
            players[#players + 1] = { name = m.name, class = m.class, role = m.role, spec = m.spec, tank = info[m.name].tank, taken = info[m.name].taken,
                                      current = info[m.name].current }
            columns[#columns + 1] = { name = m.name, class = m.class, members = { m } }
        end
    end

    local listSource, lists = ns.Group.ListSource(members)
    local plan = ns.Engine.Assign(paladins, players, ns.Group.Locks(), lists)
    local auras = ns.Engine.AssignAuras(paladins)
    local mine = plan[ns.Group.Me()] or {}
    local targets = {}
    for _, col in ipairs(columns) do
        local key = mine[col.name]
        if key then
            local units, level, remaining = {}, 99, math.huge
            for _, m in ipairs(col.members) do
                if m.reachable then units[#units + 1] = m.unit end
                level = math.min(level, m.level or 1)
                remaining = math.min(remaining, info[m.name].mine[key] or 0)
            end
            targets[#targets + 1] = { label = col.name, class = col.class, key = key, units = units, level = level,
                                      remaining = remaining, greater = raid }
        end
    end
    return { mode = raid and "raid" or "party", plan = plan, paladins = paladins, columns = columns, targets = targets,
             auras = auras, info = info, listSource = listSource, oath = OathTarget(members, info, now) }
end

function Plan.Blessing(key)
    for _, b in ipairs(ns.BLESSINGS) do if b.key == key then return b end end
end

-- The keys of `list` (default: every blessing) that this client has. Forever 1.60.1.71037 removed
-- Blessing of Light and Salvation.
function Plan.Available(list)
    local out = {}
    for _, key in ipairs(list or ns.Engine.KEYS) do
        if key and Plan.Blessing(key) then out[#out + 1] = key end
    end
    return out
end

function Plan.Aura(key)
    for _, a in ipairs(ns.AURAS) do if a.key == key then return a end end
end

-- The spell to cast for a target: the highest rank of the (Greater) blessing the target can receive,
-- and how long it lasts.
function Plan.Spell(target)
    if target.key == "oath" then
        local oath = ns.OATH_OF_LIGHT
        if oath then return oath[1], oath[2] end
        return nil
    end
    local b = Plan.Blessing(target.key)
    if not b then return nil end
    local ranks = target.greater and b.greater or b.single
    local rank = ns.Engine.Rank(ranks, target.level, ns.Group.IsKnown)
    if rank then return rank[1], rank[3] end
end

-- The target to top up next: your Oath of Light when it's missing or running out, then blessings:
-- missing first, then the least time left under the top-up limit.
function Plan.TopUp(targets, limit, oath)
    if oath and #oath.units > 0 and oath.remaining < Plan.OATH_REFRESH then return oath end
    local best
    for _, t in ipairs(targets) do
        if #t.units > 0 and t.remaining < limit and (not best or t.remaining < best.remaining) then best = t end
    end
    return best
end
