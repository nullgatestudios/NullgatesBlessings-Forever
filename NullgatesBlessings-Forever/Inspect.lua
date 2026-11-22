-- Nullgate's Blessings: learns group members' specs by inspecting their talents, one at a time, out
-- of combat and only when they're close enough. Only classes whose blessing list depends on spec are
-- inspected (warriors, druids, shamans and paladins). What's learned is shared with the other
-- paladins running the addon, so every copy plans with the same specs.
local _, ns = ...

local Inspect = {}
ns.Inspect = Inspect

local MAX_AGE, TIMEOUT = 900, 5   -- re-inspect after 15 minutes; give up on an answer after 5 seconds
local BY_SPEC = { WARRIOR = true, DRUID = true, SHAMAN = true, PALADIN = true }
local pending -- { unit, name, guid, at }

local function Yes(value) -- a plain true (secret values count as no)
    return value and not ns.Group.IsSecret(value) and true or false
end

local function Wanted(m, now)
    if not BY_SPEC[m.class] or not m.reachable or m.name == ns.Group.Me() then return false end
    if ns.Group.peers[m.name] then return false end -- paladins running the addon share their own
    local known = ns.Group.specs[m.name]
    return not known or now - known.at > MAX_AGE
end

-- Starts the next inspection, if one is needed and allowed. Called every few seconds.
function Inspect.Tick()
    if not (NotifyInspect and CanInspect and GetTalentTabInfo) then return end
    local now = GetTime()
    if pending then
        if now - pending.at < TIMEOUT then return end
        pending = nil
    end
    if InCombatLockdown() or (InspectFrame and InspectFrame:IsShown()) then return end
    if not (IsInGroup and IsInGroup()) then return end
    for _, m in ipairs(ns.Group.Members()) do
        if Wanted(m, now) and Yes(CanInspect(m.unit)) and (not CheckInteractDistance or Yes(CheckInteractDistance(m.unit, 1))) then
            pending = { unit = m.unit, name = m.name, guid = UnitGUID and UnitGUID(m.unit), at = now }
            NotifyInspect(m.unit)
            return
        end
    end
end

-- INSPECT_READY: read the talents of the player we asked about.
function Inspect.OnReady(guid)
    if not pending then return end
    if guid and pending.guid and not ns.Group.IsSecret(guid) and guid ~= pending.guid then return end -- someone else's inspect
    local name = pending.name
    pending = nil
    local tree = ns.Group.Tree(true)
    if ClearInspectPlayer and not (InspectFrame and InspectFrame:IsShown()) then ClearInspectPlayer() end
    if tree and ns.Group.SetSpec(name, tree, GetTime()) then
        ns.Group.SendSpec(name, tree)
        ns.Refresh()
    elseif tree then
        ns.Group.specs[name].at = GetTime()
    end
end
