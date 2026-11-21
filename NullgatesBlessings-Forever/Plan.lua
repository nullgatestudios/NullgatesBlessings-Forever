-- Nullgate's Blessings: turns the group into the engine's inputs and the engine's plan into your
-- targets. In a party every member is planned for (normal blessings); in a raid every class is
-- (Greater Blessings).
local _, ns = ...

local Plan = {}
ns.Plan = Plan

-- { mode, plan, paladins, targets, columns, auras }
--   columns: the players (party) or classes (raid) in order, for the plan window
--   targets: what you cast: { label, key, units = { unit, ... }, level, remaining, greater }
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
        local taken, mine = ns.Group.Blessings(m.unit, addonNames, now)
        info[m.name] = { member = m, taken = taken, mine = mine, tank = ns.Group.IsTank(m, tanks, notTanks) }
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
            players[#players + 1] = { name = class, class = class, role = "NONE", taken = taken }
            columns[#columns + 1] = { name = class, class = class, members = byClass[class] }
        end
    else
        for _, m in ipairs(members) do
            players[#players + 1] = { name = m.name, class = m.class, role = m.role, tank = info[m.name].tank, taken = info[m.name].taken }
            columns[#columns + 1] = { name = m.name, class = m.class, members = { m } }
        end
    end

    local plan = ns.Engine.Assign(paladins, players, ns.Group.Locks())
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
             auras = auras, info = info }
end

function Plan.Blessing(key)
    for _, b in ipairs(ns.BLESSINGS) do if b.key == key then return b end end
end

function Plan.Aura(key)
    for _, a in ipairs(ns.AURAS) do if a.key == key then return a end end
end

-- The spell to cast for a target: the highest rank of the (Greater) blessing the target can receive.
function Plan.Spell(target)
    local b = Plan.Blessing(target.key)
    if not b then return nil end
    local ranks = target.greater and b.greater or b.single
    local rank = ns.Engine.Rank(ranks, target.level, ns.Group.IsKnown)
    return rank and rank[1]
end

-- The target to top up next: missing first, then the least time left under the top-up limit.
function Plan.TopUp(targets, limit)
    local best
    for _, t in ipairs(targets) do
        if #t.units > 0 and t.remaining < limit and (not best or t.remaining < best.remaining) then best = t end
    end
    return best
end
