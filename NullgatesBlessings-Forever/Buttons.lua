-- Nullgate's Blessings: your bar. A list with Top Up (your Oath of Light when it's running out, else
-- whoever's blessing from you is missing or lowest) and your aura on top, your Oath of Light on the
-- tank (with the talent), then one secure row per target in your plan (each party member in a
-- party, each class in a raid) with the time left on yours. Targets and spells can only change out
-- of combat; the bar hides while every blessing is fresh.
local _, ns = ...

local L = ns.L
local Buttons = {}
ns.Buttons = Buttons

local WIDTH, ROW, GAP, SLOTS = 180, 22, 3, 10
local ICON = "Interface\\Icons\\Spell_Holy_FistOfJustice"
local bar
local slots, topUp, aura, oath = {}, nil, nil, nil
Buttons.slots = slots
local state -- the last plan

local K = NullgateBuffKit
local Short = K.ShortTime

-- A party member's name, or a class's name in a raid.
local function Label(target)
    if target.class and target.label == target.class then
        return (LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[target.class]) or target.label
    end
    return target.label
end

local function ClassColor(class)
    local c = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
    if c then return c.r, c.g, c.b end
    return 1, 1, 1
end

local function ShowTooltip(button)
    GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
    local t = button.target
    if button == aura then
        GameTooltip:AddLine(L["Your aura"], 1, 0.82, 0)
        GameTooltip:AddLine(button.spell and (ns.Group.SpellName(button.spell) or "?") or L["No aura assigned."], 1, 1, 1)
    elseif t then
        local name = ns.Group.SpellName(button.spell) or t.key
        GameTooltip:AddLine((button == topUp and (L["Top Up"] .. ": ") or "") .. name, 1, 0.82, 0)
        GameTooltip:AddLine(string.format(L["For %s"], Label(t)), 1, 1, 1)
        if t.remaining == 0 then
            GameTooltip:AddLine(L["Missing."], 1, 0.3, 0.3)
        elseif t.remaining ~= math.huge then
            GameTooltip:AddLine(string.format(L["%s left on yours."], Short(t.remaining)), 0.8, 0.8, 0.8)
        end
        if #t.units == 0 then GameTooltip:AddLine(L["Out of range."], 1, 0.5, 0.3) end
    elseif button == topUp then
        GameTooltip:AddLine(L["Top Up"], 1, 0.82, 0)
        GameTooltip:AddLine(L["All your blessings have plenty of time left."], 0.4, 1, 0.4, true)
    end
    if button.stale then GameTooltip:AddLine(L["In combat: updates when combat ends."], 0.8, 0.8, 0.8, true) end
    GameTooltip:Show()
end

local barObject -- the kit bar: rows, squares and the saved position

function Buttons.Create()
    if bar then return end
    barObject = K.NewBar({ name = "NullgatesBlessingsBar", db = ns.db, width = WIDTH, row = ROW, icon = ICON,
                           point = { 0, -220 }, tooltip = ShowTooltip })
    bar = barObject.frame
    topUp = barObject.NewRow("NullgatesBlessingsTopUp", true)
    aura = barObject.NewSquare("NullgatesBlessingsAura")
    oath = barObject.NewRow("NullgatesBlessingsOath")
    for i = 1, SLOTS do slots[i] = barObject.NewRow("NullgatesBlessingsSlot" .. i) end
    Buttons.topUp, Buttons.aura, Buttons.oath = topUp, aura, oath
    Buttons.Update()
end

local function SetTarget(row, target, spell, duration)
    K.SetTarget(row, target, spell, duration, ICON)
end

-- Whether an aura of yours is on: from the stance bar (readable in combat), else your buffs.
local function AuraActive(a)
    if not a then return false end
    local ids = {}
    for _, r in ipairs(a.ranks) do ids[r[1]] = true end
    if GetNumShapeshiftForms and GetShapeshiftFormInfo then
        for i = 1, GetNumShapeshiftForms() or 0 do
            local _, active, _, spellID = GetShapeshiftFormInfo(i)
            if active and spellID and ids[spellID] then return true end
        end
    end
    local names = {}
    for id in pairs(ids) do
        local n = ns.Group.SpellName(id)
        if n then names[n] = true end
    end
    for i = 1, 40 do
        local buff = ns.Group.ReadAura("player", i)
        if not buff then return false end
        if names[buff.name] then return true end
    end
    return false
end

-- Your assigned aura, and whether it's already on.
local function MyAura()
    local key = state and state.auras[ns.Group.Me()]
    local a = key and ns.Plan.Aura(key)
    return a, AuraActive(a)
end

-- Whether any of your blessings is missing or under the warning time, your Oath of Light is running
-- out, or your aura is off.
local function Needed()
    if ns.db.showAura and aura.spell then
        local _, on = MyAura()
        if not on then return true end
    end
    if state and state.oath and state.oath.remaining < ns.Plan.OATH_REFRESH then return true end
    local warn = (ns.db.warnMinutes or 5) * 60
    for _, t in ipairs(state and state.targets or {}) do
        if t.remaining < warn then return true end
    end
    return false
end

local function UpdateVisibility()
    ns.WhenSafe("visibility", function()
        local hasTargets = state and (#state.targets > 0 or state.oath ~= nil)
        local show = not ns.db.locked or (hasTargets and (not ns.db.hideWhenFresh or Needed()))
        bar:SetShown(show and true or false)
    end)
end

-- Rebuilds the plan and sets every row, out of combat.
function Buttons.Update()
    if not bar then return end
    state = ns.Plan.Build()
    local applied = ns.WhenSafe("buttons", function()
        for i, row in ipairs(slots) do
            local t = state.targets[i]
            local spell, duration
            if t then spell, duration = ns.Plan.Spell(t) end
            SetTarget(row, t, spell, duration)
            row.label:SetText(t and Label(t) or "")
            row.label:SetTextColor(ClassColor(t and t.class))
        end
        local next = ns.Plan.TopUp(state.targets, (ns.db.topUpMinutes or 10) * 60, state.oath)
        SetTarget(topUp, next, next and ns.Plan.Spell(next))
        SetTarget(oath, state.oath, state.oath and ns.Plan.Spell(state.oath))
        oath.label:SetText(state.oath and state.oath.label or "")
        oath.label:SetTextColor(ClassColor(state.oath and state.oath.class))
        topUp.label:SetText(L["Top Up"])
        topUp.timer:SetText(next and Label(next) or "")
        local a, auraOn = MyAura()
        local rank = a and ns.Engine.Rank(a.ranks, 99, ns.Group.IsKnown)
        aura.spell = rank and rank[1]
        aura:SetAttribute("type", aura.spell and "spell" or nil)
        aura:SetAttribute("spell", aura.spell)
        aura.icon:SetTexture(K.SpellIcon(aura.spell) or ICON)

        -- Layout: Top Up and the aura on the first line (the aura only while it's off), then one row per target.
        local showTopUp, showAura = ns.db.showTopUp, ns.db.showAura and aura.spell ~= nil and not auraOn
        local y = -GAP
        topUp:SetShown(showTopUp)
        aura:SetShown(showAura)
        if showTopUp or showAura then
            if showAura then
                aura:ClearAllPoints()
                aura:SetPoint("TOPRIGHT", bar, "TOPRIGHT", -GAP, y)
            end
            if showTopUp then
                topUp:ClearAllPoints()
                topUp:SetPoint("TOPLEFT", bar, "TOPLEFT", GAP, y)
                topUp:SetWidth(WIDTH - 2 * GAP - (showAura and (ROW + GAP) or 0))
            end
            y = y - ROW - GAP
        end
        oath:SetShown(oath.target ~= nil)
        if oath.target then
            oath:ClearAllPoints()
            oath:SetPoint("TOPLEFT", bar, "TOPLEFT", GAP, y)
            y = y - ROW - GAP
        end
        for _, row in ipairs(slots) do
            if row.target then
                row:ClearAllPoints()
                row:SetPoint("TOPLEFT", bar, "TOPLEFT", GAP, y)
                row:Show()
                y = y - ROW - GAP
            else
                row:Hide()
            end
        end
        bar:SetSize(WIDTH, math.max(ROW + 2 * GAP, -y))
        bar:SetScale(ns.db.scale or 1)
        bar.background:SetShown(not ns.db.locked)
        for _, row in ipairs(slots) do row.stale = false end
        topUp.stale, oath.stale = false, false
    end)
    if not applied then
        for _, row in ipairs(slots) do row.stale = true end
        topUp.stale, oath.stale = true, true
    end
    Buttons.UpdateTimers()
end

-- Time left, the fill and the red tint (not protected), and hiding while everything is fresh.
function Buttons.UpdateTimers()
    if not bar or not state then return end
    local warn = (ns.db.warnMinutes or 5) * 60
    local fillWidth = WIDTH - 2 * GAP - ROW
    local function Timer(row, rowWarn) K.ShowTimer(row, rowWarn, fillWidth, L["Missing."]) end
    for _, row in ipairs(slots) do Timer(row, warn) end
    Timer(oath, ns.Plan.OATH_REFRESH)
    topUp.glow:SetShown(topUp.target ~= nil and topUp.target.remaining < (topUp.target.oath and ns.Plan.OATH_REFRESH or warn))
    local _, auraOn = MyAura()
    aura:SetAlpha(auraOn and 0.3 or 1) -- in combat the button can't hide; it fades once the aura is on
    UpdateVisibility()
end

function Buttons.State()
    return state
end

function Buttons.ResetPosition()
    if not bar then return end
    ns.db.point = nil
    ns.WhenSafe("position", barObject.Restore)
end
