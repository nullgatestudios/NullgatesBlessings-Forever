-- Nullgate's Blessings: the smart macro. One character macro ("NGBless") that casts the right
-- blessing on your friendly target (your Oath of Light first on the tank, when it's running out), or tops up whoever in your plan needs it next when you have no
-- friendly target. The game doesn't let secure code see who your target is in combat, so the macro is
-- rewritten out of combat whenever your target, their blessings or the plan change; in combat it
-- keeps what it had.
local _, ns = ...

local L = ns.L
local Macro = {}
ns.Macro = Macro

Macro.NAME = "NGBless"
local ICON = "INV_Misc_QuestionMark" -- with #showtooltip the macro shows the blessing's own icon

local K = NullgateBuffKit
Macro.CastName = K.CastName

-- The blessing spell to cast on a unit: your planned one when they're in the plan (the Greater
-- Blessing for their class in a raid), else the best one from their class list that they don't
-- already have from someone else and that you know.
function Macro.SpellFor(unit, state)
    if not (UnitExists(unit) and UnitIsPlayer(unit) and UnitCanAssist("player", unit)) then return nil end
    local name, level = UnitName(unit), UnitLevel(unit) or 1
    if ns.Group.IsSecret(name) then return nil end
    local oath = state and state.oath
    if oath and oath.label == name and oath.remaining < ns.Plan.OATH_REFRESH then return ns.Plan.Spell(oath) end
    for _, col in ipairs(state and state.columns or {}) do
        for _, member in ipairs(col.members) do
            if member.name == name then
                for _, t in ipairs(state.targets) do
                    if t.label == col.name then return ns.Plan.Spell({ key = t.key, level = t.level, greater = t.greater }) end
                end
                return nil -- in the plan, but nothing from you
            end
        end
    end
    local _, class = UnitClass(unit)
    local now = GetTime()
    local taken, mine = ns.Group.Blessings(unit, {}, now)
    local _, lists = ns.Group.ListSource(ns.Group.Members())
    local tank = UnitGroupRolesAssigned and UnitGroupRolesAssigned(unit) == "TANK"
    local known = ns.Group.MyInfo().known
    for _, key in ipairs(ns.Engine.Wishes(class, "NONE", tank, ns.Group.Spec(name), lists)) do
        if known[key] and (mine[key] or not taken[key]) and ns.Engine.CanReceive(key, level) then
            return ns.Plan.Spell({ key = key, level = level })
        end
    end
end

-- The macro text for the current target and plan.
function Macro.Body(state)
    local lines = { "#showtooltip" }
    local clauses = {}
    local forTarget = Macro.CastName(Macro.SpellFor("target", state))
    if forTarget then clauses[#clauses + 1] = "[@target,help,nodead] " .. forTarget end
    local next = state and ns.Plan.TopUp(state.targets, (ns.db.topUpMinutes or 10) * 60, state.oath)
    local topUp = next and next.units[1] and Macro.CastName(ns.Plan.Spell(next))
    if topUp then clauses[#clauses + 1] = "[@" .. next.units[1] .. "] " .. topUp end
    if #clauses == 0 then
        -- Nothing to cast: keep the button showing your first leaning.
        local lean = ns.Group.MyInfo().lean or {}
        local b = lean[1] and ns.Plan.Blessing(lean[1])
        local rank = b and ns.Engine.Rank(b.single, 99, ns.Group.IsKnown)
        local fallback = rank and Macro.CastName(rank[1])
        if fallback then clauses[1] = "[@target,help,nodead][@player] " .. fallback end
    end
    if #clauses > 0 then lines[2] = "/cast " .. table.concat(clauses, "; ") end
    return table.concat(lines, "\n")
end

local smart -- made on first use, once the language is known
local function Smart()
    smart = smart or K.NewMacro({ name = Macro.NAME, icon = ICON, body = function() return Macro.Body(ns.Buttons.State()) end,
        run = ns.WhenSafe, print = ns.Print, texts = { combat = L["You can't make macros during combat."],
        full = L["Your character macros are full. Delete one and try again."],
        done = L["The smart blessing macro is on your cursor: put it on an action bar."] } })
    return smart
end

-- Rewrites the macro if it exists and its text changed (out of combat only).
function Macro.Update() Smart().Update() end

-- /nbless macro and the settings button: makes the macro if needed and puts it on your cursor.
function Macro.Make() Smart().Make() end
