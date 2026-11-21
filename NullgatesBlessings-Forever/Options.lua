-- Nullgate's Blessings: settings. Options.Build(container) lays out every setting and is used
-- both by the addon's own window and by Nullgate's Addon Config when installed.
local addonName, ns = ...

local L = ns.L
local Options = {}
ns.Options = Options

local FULL_TITLE = "Nullgate's Blessings - Forever"
local window

local function Apply()
    if ns.Refresh then ns.Refresh() end
end

local function Header(parent, text, y)
    local label = parent:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    label:SetPoint("TOPLEFT", parent, "TOPLEFT", 16, y)
    label:SetText(text)
    return y - 28
end

local function Check(parent, text, get, set, y)
    local box = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    box:SetSize(24, 24)
    box:SetPoint("TOPLEFT", parent, "TOPLEFT", 16, y)
    box:SetChecked(get())
    box:SetScript("OnClick", function(self) set(self:GetChecked() and true or false); Apply() end)
    local label = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    label:SetPoint("LEFT", box, "RIGHT", 4, 0)
    label:SetText(text)
    return y - 28
end

-- A number with - and + buttons. zeroText is shown for 0 (for example "off").
local function Stepper(parent, text, get, set, min, max, step, format, y, zeroText)
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
        Apply()
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

local function Button(parent, text, x, y, width, onClick)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(width or 150, 22)
    button:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    button:SetText(text)
    button:SetScript("OnClick", onClick)
    return button
end

-- Lays out every setting inside container; returns the height used.
function Options.Build(container)
    local db = ns.db
    local y = -12
    y = Header(container, L["Bar"], y)
    y = Check(container, L["Lock the bar (unlock to drag it)"], function() return db.locked end, function(v) db.locked = v end, y)
    y = Check(container, L["Stack the buttons vertically"], function() return db.vertical end, function(v) db.vertical = v end, y)
    y = Stepper(container, L["Bar scale"], function() return db.scale end, function(v) db.scale = v end, 0.5, 2, 0.1, "%.1f", y)
    y = Check(container, L["Show the Top Up button"], function() return db.showTopUp end, function(v) db.showTopUp = v end, y)
    y = Check(container, L["Show the aura button"], function() return db.showAura end, function(v) db.showAura = v end, y)
    Button(container, L["Reset bar position"], 16, y, 150, function() ns.Buttons.ResetPosition() end)
    Button(container, L["Show the plan"], 176, y, 150, function() ns.PlanWindow.Show() end)
    y = y - 34

    y = Header(container, L["Your leanings"], y)
    local KEYS = ns.Engine.KEYS
    local function LeanList() return db.lean or ns.Engine.DefaultLean(ns.Group.MyTree()) end
    for slot = 1, 3 do
        local picker = Button(container, "", 16, y, 230, nil)
        local function Text() picker:SetText(string.format(L["Choice %d: %s"], slot, ns.PlanWindow.Short(LeanList()[slot]) ~= ""
            and ns.PlanWindow.Short(LeanList()[slot]) or L["none"])) end
        picker:SetScript("OnClick", function()
            local list = {}
            for i, k in ipairs(LeanList()) do list[i] = k end
            local current, nextKey = list[slot], nil
            for i, k in ipairs(KEYS) do if k == current then nextKey = KEYS[i % #KEYS + 1] end end
            list[slot] = nextKey or KEYS[1]
            db.lean = list
            Text()
            ns.Group.Hello()
            Apply()
        end)
        Text()
        y = y - 26
    end
    y = y - 6

    y = Header(container, L["Warnings"], y)
    y = Stepper(container, L["Red when under (minutes)"], function() return db.warnMinutes end, function(v) db.warnMinutes = v end, 1, 30, 1, "%d", y)
    y = Stepper(container, L["Top Up refreshes under (minutes)"], function() return db.topUpMinutes end, function(v) db.topUpMinutes = v end, 1, 59, 1, "%d", y)
    y = Stepper(container, L["Warn below this many Symbol of Kings"], function() return db.symbolWarning end,
        function(v) db.symbolWarning = v end, 0, 100, 5, "%d", y, L["off"])
    y = y - 4

    y = Header(container, L["Language"], y)
    local function LanguageName()
        if db.language == "auto" then return L["Automatic (game language)"] end
        for _, entry in ipairs(ns.LANGUAGES) do
            if entry.code == db.language then return entry.name end
        end
        return db.language
    end
    local picker = Button(container, LanguageName(), 16, y, 230, nil)
    picker:SetScript("OnClick", function(self)
        local nextCode = ns.LANGUAGES[1].code
        if db.language ~= "auto" then
            nextCode = "auto"
            for i, entry in ipairs(ns.LANGUAGES) do
                if entry.code == db.language and ns.LANGUAGES[i + 1] then nextCode = ns.LANGUAGES[i + 1].code end
            end
        end
        db.language = nextCode
        self:SetText(LanguageName())
        ns.Print(L["The language changes after you type /reload."])
    end)
    y = y - 32

    local note = container:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    note:SetPoint("TOPLEFT", container, "TOPLEFT", 16, y - 8)
    note:SetWidth(330)
    note:SetJustifyH("LEFT")
    note:SetText(L["Commands: /nbless (plan), /nbless tank <name>, /nbless announce, /nbless check. Key bindings are under Key Bindings > AddOns."])
    return -y + 40
end

local function OwnWindow()
    if not window then
        window = CreateFrame("Frame", "NullgatesBlessingsOptions", UIParent, "BasicFrameTemplateWithInset")
        window:SetSize(380, 640)
        window:SetPoint("CENTER")
        window:SetFrameStrata("DIALOG") -- above unit frames, nameplates and bags
        window:SetToplevel(true)
        window:SetMovable(true)
        window:EnableMouse(true)
        window:SetClampedToScreen(true)
        window:RegisterForDrag("LeftButton")
        window:SetScript("OnDragStart", window.StartMoving)
        window:SetScript("OnDragStop", window.StopMovingOrSizing)
        if type(window.SetTitle) == "function" then window:SetTitle(FULL_TITLE)
        elseif type(window.TitleText) == "table" then window.TitleText:SetText(FULL_TITLE) end
        local content = CreateFrame("Frame", nil, window)
        content:SetPoint("TOPLEFT", window, "TOPLEFT", 4, -26)
        content:SetPoint("BOTTOMRIGHT", window, "BOTTOMRIGHT", -4, 4)
        window:SetHeight(Options.Build(content) + 30)
        if UISpecialFrames then table.insert(UISpecialFrames, "NullgatesBlessingsOptions") end
    end
    window:Show()
end

function Options.Open(standalone)
    local hub = NullgatesAddonConfigForever
    if not standalone and hub and hub.ShowUI and hub.SelectModule and Options.registered then
        hub:ShowUI()
        hub:SelectModule(addonName)
    else
        OwnWindow()
    end
end

function Options.RegisterHub()
    local hub = NullgatesAddonConfigForever
    if Options.registered or not (hub and hub.RegisterModule and ns.db) then return end
    hub:RegisterModule(addonName, {
        name = FULL_TITLE,
        sidebarName = "Blessings",
        author = "Nullgate Studios",
        isNullgate = true,
        description = L["Smart blessing assignments that check what every player already has and coordinate paladins."],
        db = ns.db,
        buildUI = function(container) Options.Build(container) end,
        toggleMovers = function(state) ns.db.locked = not state; ns.Buttons.Update() end,
        resetMovers = function() ns.Buttons.ResetPosition() end,
        isMoversUnlocked = function() return not ns.db.locked end,
    })
    Options.registered = true
end
