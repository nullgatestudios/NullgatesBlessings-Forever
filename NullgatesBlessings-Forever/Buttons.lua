-- Nullgate's Blessings: your bar. One secure button per target in your plan (each party member in a
-- party, each class in a raid), Top Up (the target whose blessing from you is missing or lowest), and
-- your aura. Targets and spells can only change out of combat.
local _, ns = ...

local L = ns.L
local Buttons = {}
ns.Buttons = Buttons

local SIZE, GAP, SLOTS = 36, 4, 10
local ICON = "Interface\\Icons\\Spell_Holy_FistOfJustice"
local bar
local slots, topUp, aura = {}, nil, nil
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

local function ShowTooltip(button)
    GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
    local t = button.target
    if button == aura then
        GameTooltip:AddLine(L["Your aura"], 1, 0.82, 0)
        GameTooltip:AddLine(button.spell and (ns.Group.SpellName(button.spell) or "?") or L["No aura assigned."], 1, 1, 1)
    elseif t then
        local name = ns.Group.SpellName(button.spell) or t.key
        GameTooltip:AddLine((button == topUp and (L["Top Up"] .. ": ") or "") .. name, 1, 0.82, 0)
        GameTooltip:AddLine(string.format(L["For %s"], t.label), 1, 1, 1)
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
    if button.stale then GameTooltip:AddLine(L["In combat: updates when combat ends."], 1, 0.3, 0.3, true) end
    GameTooltip:Show()
end

local function NewButton(name)
    local button = CreateFrame("Button", name, bar, "SecureActionButtonTemplate")
    button:SetSize(SIZE, SIZE)
    button:RegisterForClicks("AnyUp", "AnyDown")
    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetAllPoints(button)
    button.icon:SetTexture(ICON)
    button.glow = button:CreateTexture(nil, "OVERLAY")
    button.glow:SetPoint("TOPLEFT", -3, 3)
    button.glow:SetPoint("BOTTOMRIGHT", 3, -3)
    button.glow:SetColorTexture(1, 0.2, 0.2, 0.35)
    button.glow:Hide()
    button.label = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    button.label:SetPoint("TOP", button, "BOTTOM", 0, -1)
    button.timer = button:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    button.timer:SetPoint("BOTTOMRIGHT", -2, 2)
    button.staleMark = button:CreateFontString(nil, "OVERLAY", "GameFontRedSmall")
    button.staleMark:SetPoint("TOPLEFT", 2, -2)
    button.staleMark:SetText("*")
    button.staleMark:Hide()
    local highlight = button:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints(button)
    highlight:SetColorTexture(1, 1, 1, 0.15)
    button:SetScript("OnEnter", ShowTooltip)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)
    button:RegisterForDrag("LeftButton")
    button:SetScript("OnDragStart", function() bar:GetScript("OnDragStart")(bar) end)
    button:SetScript("OnDragStop", function() bar:GetScript("OnDragStop")(bar) end)
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
    topUp = NewButton("NullgatesBlessingsTopUp")
    topUp.label:SetText(L["Top Up"])
    aura = NewButton("NullgatesBlessingsAura")
    for i = 1, SLOTS do slots[i] = NewButton("NullgatesBlessingsSlot" .. i) end
    Buttons.topUp, Buttons.aura = topUp, aura
    RestorePosition()
    Buttons.Update()
end

local function SetTarget(button, target, spell)
    button.target, button.spell = target, spell
    local unit = target and target.units[1]
    button:SetAttribute("type", (spell and unit) and "spell" or nil)
    button:SetAttribute("spell", (spell and unit) and spell or nil)
    button:SetAttribute("unit", (spell and unit) and unit or nil)
    button.icon:SetTexture(SpellIcon(spell) or ICON)
    button.icon:SetDesaturated(not (spell and unit))
end

-- Rebuilds the plan and sets every button, out of combat.
function Buttons.Update()
    if not bar then return end
    state = ns.Plan.Build()
    local applied = ns.WhenSafe("buttons", function()
        local shown = {}
        if ns.db.showTopUp then shown[#shown + 1] = topUp end
        for i, button in ipairs(slots) do
            local t = state.targets[i]
            SetTarget(button, t, t and ns.Plan.Spell(t))
            button.label:SetText(t and t.label:sub(1, 6) or "")
            if t then shown[#shown + 1] = button end
        end
        local next = ns.Plan.TopUp(state.targets, (ns.db.topUpMinutes or 10) * 60)
        SetTarget(topUp, next, next and ns.Plan.Spell(next))
        local auraKey = state.auras[ns.Group.Me()]
        local a = auraKey and ns.Plan.Aura(auraKey)
        local rank = a and ns.Engine.Rank(a.ranks, 99, ns.Group.IsKnown)
        aura.spell = rank and rank[1]
        aura:SetAttribute("type", aura.spell and "spell" or nil)
        aura:SetAttribute("spell", aura.spell)
        aura.icon:SetTexture(SpellIcon(aura.spell) or ICON)
        if ns.db.showAura and aura.spell then shown[#shown + 1] = aura end

        for _, b in ipairs(slots) do b:Hide() end
        topUp:Hide()
        aura:Hide()
        for i, button in ipairs(shown) do
            button:ClearAllPoints()
            local offset = GAP + (i - 1) * (SIZE + GAP)
            if ns.db.vertical then button:SetPoint("TOP", bar, "TOP", 0, -offset)
            else button:SetPoint("LEFT", bar, "LEFT", offset, 6) end
            button:Show()
        end
        local n = math.max(1, #shown)
        if ns.db.vertical then bar:SetSize(SIZE + 2 * GAP, GAP + n * (SIZE + GAP))
        else bar:SetSize(GAP + n * (SIZE + GAP), SIZE + 2 * GAP + 12) end
        bar:SetScale(ns.db.scale or 1)
        bar.background:SetShown(not ns.db.locked)
        bar:SetShown(#state.targets > 0 or not ns.db.locked)
        for _, b in ipairs(slots) do b.stale = false; b.staleMark:Hide() end
        topUp.stale = false
        topUp.staleMark:Hide()
    end)
    if not applied then
        for _, b in ipairs(slots) do b.stale = true; b.staleMark:Show() end
        topUp.stale = true
        topUp.staleMark:Show()
    end
    Buttons.UpdateTimers()
end

-- Time left and the red glow (not protected).
function Buttons.UpdateTimers()
    if not bar or not state then return end
    local warn = (ns.db.warnMinutes or 5) * 60
    for _, button in ipairs(slots) do
        local t = button.target
        if t then
            button.timer:SetText(t.remaining > 0 and Short(t.remaining) or "")
            button.glow:SetShown(t.remaining < warn)
        else
            button.timer:SetText("")
            button.glow:Hide()
        end
    end
    topUp.glow:SetShown(topUp.target ~= nil and topUp.target.remaining < warn)
end

function Buttons.State()
    return state
end

function Buttons.ResetPosition()
    if not bar then return end
    ns.db.point = nil
    ns.WhenSafe("position", RestorePosition)
end
