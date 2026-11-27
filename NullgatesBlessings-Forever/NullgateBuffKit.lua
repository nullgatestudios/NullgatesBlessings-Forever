-- NullgateBuffKit: the parts every Nullgate buff addon shares (Blessings, Fortitude, Armors...):
-- reading spells and auras safely in Forever, the group roster and addon messages, the out-of-combat
-- queue, the bar with its secure rows and timers, the smart macro, and the settings widgets.
--
-- Every addon ships an identical copy of this file (the master is Shared/NullgateBuffKit.lua in the suite
-- folder). Like NullgateReport.lua, the newest REVISION loaded wins, so raise it whenever the file
-- changes and copy it into every addon. Everything here is general: rules, data and texts stay in each
-- addon and are passed in.
local REVISION = 1
local lib = _G.NullgateBuffKit
if lib and (lib.revision or 0) >= REVISION then return end
lib = lib or {}
lib.revision = REVISION
_G.NullgateBuffKit = lib

-- --- Spells and auras --------------------------------------------------------------------

function lib.SpellName(spellID)
    if not spellID then return nil end
    if C_Spell and C_Spell.GetSpellName then return C_Spell.GetSpellName(spellID) end
    return GetSpellInfo and (GetSpellInfo(spellID)) or nil
end

function lib.SpellIcon(spellID)
    if not spellID then return nil end
    if C_Spell and C_Spell.GetSpellTexture then return C_Spell.GetSpellTexture(spellID) end
    return GetSpellTexture and GetSpellTexture(spellID) or nil
end

function lib.IsKnown(spellID)
    local known = (C_SpellBook and C_SpellBook.IsSpellKnown) or IsSpellKnown or IsPlayerSpell
    return known ~= nil and known(spellID) == true
end

-- Forever hides some values from addons (secret values, usually in combat): they can't be compared.
function lib.IsSecret(v) return issecretvalue ~= nil and issecretvalue(v) == true end
local IsSecret = lib.IsSecret

-- A unit's helpful aura i: the aura, nil past the last one, or false when the game is hiding it
-- (asking for a hidden aura is an error, and hidden fields can't be compared).
function lib.ReadAura(unit, i)
    if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
        local S = C_Secrets
        if S and S.ShouldUnitAuraIndexBeSecret and S.ShouldUnitAuraIndexBeSecret(unit, i, "HELPFUL") then return false end
        local ok, a = pcall(C_UnitAuras.GetAuraDataByIndex, unit, i, "HELPFUL")
        if not ok then return false end
        if a and (IsSecret(a.name) or IsSecret(a.expirationTime) or IsSecret(a.duration) or IsSecret(a.sourceUnit)
            or IsSecret(a.spellId)) then return false end
        return a
    end
    local name, _, _, _, duration, expires, caster, _, _, spellId = UnitBuff(unit, i)
    if not name then return nil end
    return { name = name, duration = duration, expirationTime = expires, sourceUnit = caster, spellId = spellId }
end

-- "Power Word: Fortitude(Rank 6)" for /cast, or just the name when the client has no rank text.
function lib.CastName(spellID)
    local name = spellID and lib.SpellName(spellID)
    if not name then return nil end
    local sub = C_Spell and C_Spell.GetSpellSubtext and C_Spell.GetSpellSubtext(spellID)
        or (GetSpellSubtext and GetSpellSubtext(spellID))
    if type(sub) == "string" and sub ~= "" and not IsSecret(sub) then return name .. "(" .. sub .. ")" end
    return name
end

-- "12m", "40s", or "" for something that doesn't run out.
function lib.ShortTime(seconds)
    if seconds == math.huge then return "" end
    if seconds >= 60 then return math.floor(seconds / 60) .. "m" end
    return math.floor(seconds) .. "s"
end

-- --- The group --------------------------------------------------------------------------

-- A player's name without any "-Realm" part. Ambiguate does most of it; the rest guards against a
-- blanked realm ("Name-"), since character names can't contain a hyphen.
function lib.BareName(name)
    local n = Ambiguate and Ambiguate(name, "none") or name
    if type(n) ~= "string" or IsSecret(n) then return n end
    return n:match("^[^-]+") or n
end

-- Every group member (you alone when not grouped), sorted by raid group then name:
-- { unit, name, class, level, group, role, reachable, mainTank }. extra(member), when given, adds fields.
function lib.Members(extra)
    local list = {}
    local function Add(unit, group)
        if not UnitExists(unit) then return end
        local _, class = UnitClass(unit)
        local reachable = UnitIsConnected(unit) and not UnitIsDeadOrGhost(unit)
        if reachable and not UnitIsUnit(unit, "player") then
            -- Forever can return the range as secret values, which can't be tested: then it's unknown.
            local inRange, checked = UnitInRange(unit)
            if not (IsSecret(inRange) or IsSecret(checked)) and checked and not inRange then reachable = false end
        end
        local role = UnitGroupRolesAssigned and UnitGroupRolesAssigned(unit) or "NONE"
        if IsSecret(role) then role = "NONE" end
        local member = { unit = unit, name = UnitName(unit), class = class, level = UnitLevel(unit), group = group,
                         role = role, reachable = reachable,
                         mainTank = GetPartyAssignment and GetPartyAssignment("MAINTANK", unit) or false }
        if extra then extra(member) end
        list[#list + 1] = member
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

function lib.Channel()
    if IsInRaid() then return "RAID" end
    if GetNumSubgroupMembers() > 0 then return "PARTY" end
end

-- Sends a hidden addon message to the group (nothing when you're not in one).
function lib.Send(prefix, message)
    local channel = lib.Channel()
    if channel and C_ChatInfo and C_ChatInfo.SendAddonMessage then
        C_ChatInfo.SendAddonMessage(prefix, message, channel)
    end
end

-- --- Out of combat ------------------------------------------------------------------------

-- Secure buttons and macros can only change out of combat. queue.Run(key, fn) runs fn now, or once
-- combat ends (the latest fn per key wins) and returns whether it ran now; call queue.Flush() on
-- PLAYER_REGEN_ENABLED.
function lib.NewSafeQueue()
    local pending = {}
    local queue = {}
    function queue.Run(key, fn)
        if InCombatLockdown() then
            pending[key] = fn
            return false
        end
        pending[key] = nil
        fn()
        return true
    end
    function queue.Flush()
        for key, fn in pairs(pending) do
            pending[key] = nil
            fn()
        end
    end
    return queue
end

-- --- The bar ------------------------------------------------------------------------------

-- A movable bar of secure rows. opts: name, db (keeps point and locked), width, row, icon (default
-- texture), fill ({ r, g, b, a } of the time bar), point ({ x, y } from the centre by default), tooltip
-- (function(button) shown on mouse-over). Returns the bar object.
function lib.NewBar(opts)
    local bar = { width = opts.width or 180, row = opts.row or 22, gap = 3, icon = opts.icon }
    local frame = CreateFrame("Frame", opts.name, UIParent)
    bar.frame = frame
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(self) if not opts.db.locked and not InCombatLockdown() then self:StartMoving() end end)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, relativePoint, x, y = self:GetPoint()
        opts.db.point = { point = point, relativePoint = relativePoint, x = x, y = y }
    end)
    frame.background = frame:CreateTexture(nil, "BACKGROUND")
    frame.background:SetAllPoints(frame)
    frame.background:SetColorTexture(0.08, 0.1, 0.13, 0.75)

    local function Dragging(button)
        button:RegisterForDrag("LeftButton")
        button:SetScript("OnDragStart", function() frame:GetScript("OnDragStart")(frame) end)
        button:SetScript("OnDragStop", function() frame:GetScript("OnDragStop")(frame) end)
    end
    local function Hover(button)
        local highlight = button:CreateTexture(nil, "HIGHLIGHT")
        highlight:SetAllPoints(button)
        highlight:SetColorTexture(1, 1, 1, 0.12)
        if opts.tooltip then button:SetScript("OnEnter", opts.tooltip) end
        button:SetScript("OnLeave", function() GameTooltip:Hide() end)
        Dragging(button)
    end

    -- A secure row: icon, label, a bar for the time left and the timer. gold = the Top Up style.
    function bar.NewRow(name, gold)
        local size = bar.row
        local row = CreateFrame("Button", name, frame, "SecureActionButtonTemplate")
        row:SetSize(bar.width - 2 * bar.gap, size)
        row:RegisterForClicks("AnyUp", "AnyDown")
        row.back = row:CreateTexture(nil, "BACKGROUND")
        row.back:SetAllPoints(row)
        if gold then row.back:SetColorTexture(0.32, 0.24, 0.04, 0.9) else row.back:SetColorTexture(0, 0, 0, 0.45) end
        row.fill = row:CreateTexture(nil, "BORDER")
        row.fill:SetPoint("TOPLEFT", row, "TOPLEFT", size, 0)
        row.fill:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", size, 0)
        local f = opts.fill or { 0.25, 0.55, 0.3, 0.55 }
        row.fill:SetColorTexture(f[1], f[2], f[3], f[4])
        row.fill:Hide()
        row.glow = row:CreateTexture(nil, "BORDER")
        row.glow:SetAllPoints(row)
        row.glow:SetColorTexture(0.8, 0.1, 0.1, 0.4)
        row.glow:Hide()
        row.icon = row:CreateTexture(nil, "ARTWORK")
        row.icon:SetSize(size - 4, size - 4)
        row.icon:SetPoint("LEFT", row, "LEFT", 2, 0)
        row.icon:SetTexture(bar.icon)
        row.label = row:CreateFontString(nil, "OVERLAY", gold and "GameFontNormal" or "GameFontHighlightSmall")
        row.label:SetPoint("LEFT", row.icon, "RIGHT", 5, 0)
        row.label:SetJustifyH("LEFT")
        row.timer = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        row.timer:SetPoint("RIGHT", row, "RIGHT", -5, 0)
        row.timer:SetJustifyH("RIGHT")
        row.label:SetPoint("RIGHT", row.timer, "LEFT", -4, 0)
        Hover(row)
        return row
    end

    -- A square secure button with just an icon (an aura, Inner Fire, an armor).
    function bar.NewSquare(name)
        local button = CreateFrame("Button", name, frame, "SecureActionButtonTemplate")
        button:SetSize(bar.row, bar.row)
        button:RegisterForClicks("AnyUp", "AnyDown")
        button.icon = button:CreateTexture(nil, "ARTWORK")
        button.icon:SetAllPoints(button)
        button.icon:SetTexture(bar.icon)
        Hover(button)
        return button
    end

    function bar.Restore()
        frame:ClearAllPoints()
        local p = opts.db.point
        local d = opts.point or { 0, -220 }
        if p and p.point then frame:SetPoint(p.point, UIParent, p.relativePoint or p.point, p.x or 0, p.y or 0)
        else frame:SetPoint("CENTER", UIParent, "CENTER", d[1], d[2]) end
    end

    bar.Restore()
    return bar
end

-- Points a secure row at a target: casts spell on target.units[1] (nothing when either is missing).
function lib.SetTarget(row, target, spell, duration, icon)
    row.target, row.spell, row.duration = target, spell, duration
    local unit = target and target.units[1]
    row:SetAttribute("type", (spell and unit) and "spell" or nil)
    row:SetAttribute("spell", (spell and unit) and spell or nil)
    row:SetAttribute("unit", (spell and unit) and unit or nil)
    row.icon:SetTexture(lib.SpellIcon(spell) or icon)
    row.icon:SetDesaturated(not (spell and unit))
end

-- Shows a row's time left (target.remaining), its fill and the red tint under `warn` seconds.
function lib.ShowTimer(row, warn, fillWidth, missingText)
    local t = row.target
    if t then
        local left = t.remaining
        row.timer:SetText(left > 0 and lib.ShortTime(left) or missingText)
        row.glow:SetShown(left < warn)
        local fraction = (left == math.huge and 1) or (row.duration and row.duration > 0 and math.min(1, left / row.duration)) or 0
        row.fill:SetWidth(math.max(1, fillWidth * fraction))
        row.fill:SetShown(fraction > 0)
    else
        row.timer:SetText("")
        row.glow:Hide()
        row.fill:Hide()
    end
end

-- --- The smart macro ------------------------------------------------------------------------

-- A character macro the addon keeps rewritten. opts: name, icon, body (function returning the macro
-- text), run (the addon's safe-queue Run), print, and texts { combat, full, done }.
function lib.NewMacro(opts)
    local macro, lastBody = {}, nil
    local function Index()
        local index = GetMacroIndexByName and GetMacroIndexByName(opts.name)
        return (index and index > 0) and index or nil
    end
    -- Rewrites the macro if it exists and its text changed (out of combat only).
    function macro.Update()
        if not Index() then return end
        opts.run("macro", function()
            local index = Index()
            if not index then return end
            local body = opts.body()
            if body ~= lastBody then
                EditMacro(index, opts.name, opts.icon, body)
                lastBody = body
            end
        end)
    end
    -- Makes the macro if needed and puts it on your cursor.
    function macro.Make()
        if InCombatLockdown() then
            opts.print(opts.texts.combat)
            return
        end
        local index = Index()
        if not index then
            local ok, made = pcall(CreateMacro, opts.name, opts.icon, opts.body(), true)
            if not ok or not made or made == 0 then
                opts.print(opts.texts.full)
                return
            end
            index = made
        end
        lastBody = nil
        macro.Update()
        if PickupMacro then PickupMacro(index) end
        opts.print(opts.texts.done)
    end
    return macro
end

-- --- Settings widgets ---------------------------------------------------------------------------

-- The settings widgets, each calling apply() after a change. Every one takes the y it starts at and
-- returns the y below it.
function lib.Widgets(apply)
    local W = {}
    function W.Header(parent, text, y)
        local label = parent:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
        label:SetPoint("TOPLEFT", parent, "TOPLEFT", 16, y)
        label:SetText(text)
        return y - 28
    end
    function W.Check(parent, text, get, set, y)
        local box = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
        box:SetSize(24, 24)
        box:SetPoint("TOPLEFT", parent, "TOPLEFT", 16, y)
        box:SetChecked(get())
        box:SetScript("OnClick", function(self) set(self:GetChecked() and true or false); apply() end)
        local label = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        label:SetPoint("LEFT", box, "RIGHT", 4, 0)
        label:SetText(text)
        return y - 28
    end
    -- A number with - and + buttons (works on every client, unlike slider templates). zeroText is
    -- shown for 0 (for example "off").
    function W.Stepper(parent, text, get, set, min, max, step, format, y, zeroText)
        local label = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        label:SetPoint("TOPLEFT", parent, "TOPLEFT", 20, y - 4)
        label:SetText(text)
        local value = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        value:SetPoint("TOPLEFT", parent, "TOPLEFT", 252, y - 4)
        value:SetWidth(46)
        local function Show()
            local v = get()
            value:SetText((v == 0 and zeroText) or string.format(format, v))
        end
        local function Change(delta)
            local new = math.floor((get() + delta) / step + 0.5) * step
            set(math.max(min, math.min(max, new)))
            Show()
            apply()
        end
        local minus = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
        minus:SetSize(24, 20)
        minus:SetPoint("TOPLEFT", parent, "TOPLEFT", 224, y)
        minus:SetText("-")
        minus:SetScript("OnClick", function() Change(-step) end)
        local plus = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
        plus:SetSize(24, 20)
        plus:SetPoint("TOPLEFT", parent, "TOPLEFT", 300, y)
        plus:SetText("+")
        plus:SetScript("OnClick", function() Change(step) end)
        Show()
        return y - 28
    end
    function W.Button(parent, text, x, y, width, onClick)
        local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
        button:SetSize(width or 150, 22)
        button:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
        button:SetText(text)
        button:SetScript("OnClick", onClick)
        return button
    end
    -- Small grey text under a section. Returns the y below `height`.
    function W.Note(parent, text, y, height, template)
        local note = parent:CreateFontString(nil, "ARTWORK", template or "GameFontDisableSmall")
        note:SetPoint("TOPLEFT", parent, "TOPLEFT", 16, y)
        note:SetWidth(330)
        note:SetJustifyH("LEFT")
        note:SetText(text)
        return y - (height or 20)
    end
    -- A dropdown (the game's own; a button that cycles through the options on clients without one).
    -- items() returns { { value =, text = } }; get() returns the selected value; set(value) changes it.
    -- Returns an object with :Refresh() for when the value changes elsewhere.
    function W.Dropdown(parent, x, y, width, items, get, set)
        local ok, dropdown = pcall(CreateFrame, "DropdownButton", nil, parent, "WowStyle1DropdownTemplate")
        if ok and dropdown and type(dropdown.SetupMenu) == "function" then
            dropdown:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
            dropdown:SetWidth(width)
            dropdown:SetupMenu(function(_, root)
                for _, item in ipairs(items()) do
                    root:CreateRadio(item.text, function() return get() == item.value end, function() set(item.value) end)
                end
            end)
            return { frame = dropdown, Refresh = function() if dropdown.GenerateMenu then dropdown:GenerateMenu() end end }
        end
        local button = W.Button(parent, "", x, y, width, nil)
        local function Text()
            for _, item in ipairs(items()) do if item.value == get() then button:SetText(item.text) return end end
            button:SetText("")
        end
        button:SetScript("OnClick", function()
            local list, at = items(), 0
            for i, item in ipairs(list) do if item.value == get() then at = i end end
            if #list > 0 then set(list[at % #list + 1].value) end
            Text()
        end)
        Text()
        return { frame = button, Refresh = Text }
    end
    return W
end

-- Nullgate's Addon Config gives each addon a fixed-height page, so the settings go in a scroll frame
-- there (the hub hides the scroll bar when everything fits). build(child) returns the height used.
function lib.BuildScrolling(container, build)
    local scroll = CreateFrame("ScrollFrame", nil, container, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", container, "TOPLEFT", 0, 0)
    scroll:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", -24, 0)
    local child = CreateFrame("Frame", nil, scroll)
    child:SetSize(math.max(300, (container:GetWidth() or 0) - 24), 600)
    scroll:SetScrollChild(child)
    child:SetHeight(build(child))
    local hub = NullgatesAddonConfigForever
    local ui = hub and hub.UI
    if ui and ui.SetupAutoScroll then ui:SetupAutoScroll(scroll, child) end
end

-- The addon's own settings window (made once). build(content) returns the height used.
function lib.ShowWindow(name, title, width, build, existing)
    local window = existing
    if not window then
        window = CreateFrame("Frame", name, UIParent, "BasicFrameTemplateWithInset")
        window:SetSize(width, 640)
        window:SetPoint("CENTER")
        window:SetFrameStrata("DIALOG") -- above unit frames, nameplates and bags
        window:SetToplevel(true)
        window:SetMovable(true)
        window:EnableMouse(true)
        window:SetClampedToScreen(true)
        window:RegisterForDrag("LeftButton")
        window:SetScript("OnDragStart", window.StartMoving)
        window:SetScript("OnDragStop", window.StopMovingOrSizing)
        if type(window.SetTitle) == "function" then window:SetTitle(title)
        elseif type(window.TitleText) == "table" then window.TitleText:SetText(title) end
        local content = CreateFrame("Frame", nil, window)
        content:SetPoint("TOPLEFT", window, "TOPLEFT", 4, -26)
        content:SetPoint("BOTTOMRIGHT", window, "BOTTOMRIGHT", -4, 4)
        window:SetHeight(build(content) + 30)
        if UISpecialFrames then table.insert(UISpecialFrames, name) end
    end
    window:Show()
    return window
end
