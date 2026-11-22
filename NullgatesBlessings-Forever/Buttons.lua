-- Nullgate's Blessings: your bar. A list with Top Up (your Oath of Light when it's running out, else
-- whoever's blessing from you is missing or lowest) and your aura on top, your Oath of Light on the
-- tank (with the talent), then one secure row per target in your plan (each party member in a
-- party, each class in a raid) with the time left on yours. Targets and spells can only change out
-- of combat; the bar hides while every blessing is fresh.
local _, ns = ...

local L = ns.L
local Buttons = {}
ns.Buttons = Buttons

local WIDTH, ROW, ICON_SIZE, GAP, SLOTS = 180, 22, 18, 3, 10
local ICON = "Interface\\Icons\\Spell_Holy_FistOfJustice"
local bar
local slots, topUp, aura, oath = {}, nil, nil, nil
Buttons.slots = slots
local state -- the last plan

local function SpellIcon(spellID)
    if not spellID then return nil end
    if C_Spell and C_Spell.GetSpellTexture then return C_Spell.GetSpellTexture(spellID) end
    return GetSpellTexture and GetSpellTexture(spellID) or nil
end

local function Short(seconds)
    if seconds == math.huge then return "" end
    if seconds >= 60 then return math.floor(seconds / 60) .. "m" end
    return math.floor(seconds) .. "s"
end

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

local function Dragging(button)
    button:RegisterForDrag("LeftButton")
    button:SetScript("OnDragStart", function() bar:GetScript("OnDragStart")(bar) end)
    button:SetScript("OnDragStop", function() bar:GetScript("OnDragStop")(bar) end)
end

-- A row: icon, name, a bar for the time left and the timer. Top Up uses the same row in gold.
local function NewRow(name, gold)
    local row = CreateFrame("Button", name, bar, "SecureActionButtonTemplate")
    row:SetSize(WIDTH - 2 * GAP, ROW)
    row:RegisterForClicks("AnyUp", "AnyDown")
    row.back = row:CreateTexture(nil, "BACKGROUND")
    row.back:SetAllPoints(row)
    if gold then row.back:SetColorTexture(0.32, 0.24, 0.04, 0.9) else row.back:SetColorTexture(0, 0, 0, 0.45) end
    row.fill = row:CreateTexture(nil, "BORDER")
    row.fill:SetPoint("TOPLEFT", row, "TOPLEFT", ROW, 0)
    row.fill:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", ROW, 0)
    row.fill:SetColorTexture(0.25, 0.55, 0.3, 0.55)
    row.fill:Hide()
    row.glow = row:CreateTexture(nil, "BORDER")
    row.glow:SetAllPoints(row)
    row.glow:SetColorTexture(0.8, 0.1, 0.1, 0.4)
    row.glow:Hide()
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(ICON_SIZE, ICON_SIZE)
    row.icon:SetPoint("LEFT", row, "LEFT", 2, 0)
    row.icon:SetTexture(ICON)
    row.label = row:CreateFontString(nil, "OVERLAY", gold and "GameFontNormal" or "GameFontHighlightSmall")
    row.label:SetPoint("LEFT", row.icon, "RIGHT", 5, 0)
    row.label:SetJustifyH("LEFT")
    row.timer = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.timer:SetPoint("RIGHT", row, "RIGHT", -5, 0)
    row.timer:SetJustifyH("RIGHT")
    row.label:SetPoint("RIGHT", row.timer, "LEFT", -4, 0)
    local highlight = row:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints(row)
    highlight:SetColorTexture(1, 1, 1, 0.12)
    row:SetScript("OnEnter", ShowTooltip)
    row:SetScript("OnLeave", function() GameTooltip:Hide() end)
    Dragging(row)
    return row
end

local function NewAuraButton()
    local button = CreateFrame("Button", "NullgatesBlessingsAura", bar, "SecureActionButtonTemplate")
    button:SetSize(ROW, ROW)
    button:RegisterForClicks("AnyUp", "AnyDown")
    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetAllPoints(button)
    button.icon:SetTexture(ICON)
    local highlight = button:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints(button)
    highlight:SetColorTexture(1, 1, 1, 0.15)
    button:SetScript("OnEnter", ShowTooltip)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)
    Dragging(button)
    return button
end

local function SavePosition()
    local point, _, relativePoint, x, y = bar:GetPoint()
    ns.db.point = { point = point, relativePoint = relativePoint, x = x, y = y }
end

local function RestorePosition()
    bar:ClearAllPoints()
    local p = ns.db.point
    if p and p.point then bar:SetPoint(p.point, UIParent, p.relativePoint or p.point, p.x or 0, p.y or 0)
    else bar:SetPoint("CENTER", UIParent, "CENTER", 0, -220) end
end

function Buttons.Create()
    if bar then return end
    bar = CreateFrame("Frame", "NullgatesBlessingsBar", UIParent)
    bar:SetMovable(true)
    bar:SetClampedToScreen(true)
    bar:EnableMouse(true)
    bar:RegisterForDrag("LeftButton")
    bar:SetScript("OnDragStart", function(self) if not ns.db.locked and not InCombatLockdown() then self:StartMoving() end end)
    bar:SetScript("OnDragStop", function(self) self:StopMovingOrSizing(); SavePosition() end)
    bar.background = bar:CreateTexture(nil, "BACKGROUND")
    bar.background:SetAllPoints(bar)
    bar.background:SetColorTexture(0.08, 0.1, 0.13, 0.75)
    topUp = NewRow("NullgatesBlessingsTopUp", true)
    aura = NewAuraButton()
    oath = NewRow("NullgatesBlessingsOath")
    for i = 1, SLOTS do slots[i] = NewRow("NullgatesBlessingsSlot" .. i) end
    Buttons.topUp, Buttons.aura, Buttons.oath = topUp, aura, oath
    RestorePosition()
    Buttons.Update()
end

local function SetTarget(row, target, spell, duration)
    row.target, row.spell, row.duration = target, spell, duration
    local unit = target and target.units[1]
    row:SetAttribute("type", (spell and unit) and "spell" or nil)
    row:SetAttribute("spell", (spell and unit) and spell or nil)
    row:SetAttribute("unit", (spell and unit) and unit or nil)
    row.icon:SetTexture(SpellIcon(spell) or ICON)
    row.icon:SetDesaturated(not (spell and unit))
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
        aura.icon:SetTexture(SpellIcon(aura.spell) or ICON)

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
    local function Timer(row, rowWarn)
        local t = row.target
        if t then
            local left = t.remaining
            row.timer:SetText(left > 0 and Short(left) or L["Missing."])
            row.glow:SetShown(left < rowWarn)
            local fraction = (left == math.huge and 1) or (row.duration and row.duration > 0 and math.min(1, left / row.duration)) or 0
            row.fill:SetWidth(math.max(1, fillWidth * fraction))
            row.fill:SetShown(fraction > 0)
        else
            row.timer:SetText("")
            row.glow:Hide()
            row.fill:Hide()
        end
    end
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
    ns.WhenSafe("position", RestorePosition)
end
