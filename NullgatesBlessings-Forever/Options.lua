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

-- A dropdown (the game's own; a button that cycles through the options on clients without one).
-- items() returns { { value =, text = } }; get() returns the selected value; set(value) changes it.
-- Returns an object with :Refresh() for when the value changes elsewhere.
local function Dropdown(parent, x, y, width, items, get, set)
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
    local button = Button(parent, "", x, y, width, nil)
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

-- "Choice 1:" (the "Choice %d: %s" text without a value).
local function ChoiceLabel(parent, slot, y)
    local label = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    label:SetPoint("TOPLEFT", parent, "TOPLEFT", 20, y - 5)
    label:SetText((string.format(L["Choice %d: %s"], slot, ""):gsub("%s+$", "")))
end

-- Blessings for a choice dropdown: every blessing, and "none".
local function BlessingItems()
    local items = {}
    for _, key in ipairs(ns.Plan.Available()) do items[#items + 1] = { value = key, text = ns.PlanWindow.Short(key) } end
    items[#items + 1] = { value = false, text = L["none"] }
    return items
end

-- Puts key in slot; if it's already in another slot, the two swap.
local function Place(list, slot, key, size)
    local old = list[slot]
    for i = 1, size do if i ~= slot and key and list[i] == key then list[i] = old or false end end
    list[slot] = key
end

-- The settings name of each blessing list (looked up when shown, so the chosen language applies).
local function ListName(id)
    local names = {
        warriorDps = L["Warrior: Arms and Fury"], warriorTank = L["Warrior: Protection"], rogue = L["Rogue"],
        hunter = L["Hunter"], mage = L["Mage"], warlock = L["Warlock"], priest = L["Priest"],
        druidBalance = L["Druid: Balance"], druidCat = L["Druid: Feral (cat)"], druidBear = L["Druid: Feral (bear)"],
        druidResto = L["Druid: Restoration"], shamanEle = L["Shaman: Elemental"], shamanEnh = L["Shaman: Enhancement"],
        shamanResto = L["Shaman: Restoration"], paladinHoly = L["Paladin: Holy"], paladinProt = L["Paladin: Protection"],
        paladinRet = L["Paladin: Retribution"], hybrid = L["Druid, shaman or paladin, spec not known yet"],
    }
    return names[id] or id
end

-- Blessing lists: pick a list, then a dropdown for each choice. Picking a blessing that's already in
-- the list swaps the two. Edits are shared with the group; the leader's lists win.
local function ListEditor(container, y)
    local db, KEYS, IDS = ns.db, ns.Plan.Available(), ns.Engine.LIST_IDS
    local selected = IDS[1]
    local choices = {}
    local status = container:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    local function Current()
        local src, list = ns.Plan.Available(db.lists[selected] or ns.Engine.DEFAULT_LISTS[selected]), {}
        for i = 1, #KEYS do list[i] = src[i] or false end
        return list
    end
    local function Draw()
        for _, choice in ipairs(choices) do choice.Refresh() end
        local state = ns.Buttons.State()
        local source = state and state.listSource
        status:SetText(source and source ~= ns.Group.Me() and string.format(L["The group is using %s's lists."], source) or "")
    end
    local listLabel = container:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    listLabel:SetPoint("TOPLEFT", container, "TOPLEFT", 20, y - 5)
    listLabel:SetText((string.format(L["List: %s"], ""):gsub("%s+$", "")))
    local picker = Dropdown(container, 110, y, 236, function()
        local items = {}
        for _, id in ipairs(IDS) do items[#items + 1] = { value = id, text = ListName(id) } end
        return items
    end, function() return selected end, function(id) selected = id; Draw() end)
    y = y - 30
    for slot = 1, #KEYS do
        ChoiceLabel(container, slot, y)
        choices[slot] = Dropdown(container, 110, y, 150, BlessingItems, function() return Current()[slot] end, function(key)
            local list = Current()
            Place(list, slot, key, #KEYS)
            if table.concat(ns.Engine.CleanList(list), ",") == table.concat(ns.Plan.Available(ns.Engine.DEFAULT_LISTS[selected]), ",") then
                db.lists[selected] = nil
            else
                db.lists[selected] = list
            end
            ns.Group.Hello()
            Apply()
            Draw()
        end)
        y = y - 28
    end
    Button(container, L["Reset to recommended"], 16, y - 2, 180, function()
        for id in pairs(db.lists) do db.lists[id] = nil end
        ns.Group.Hello()
        Apply()
        Draw()
    end)
    y = y - 30
    status:SetPoint("TOPLEFT", container, "TOPLEFT", 16, y)
    status:SetWidth(330)
    status:SetJustifyH("LEFT")
    y = y - 14
    local note = container:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    note:SetPoint("TOPLEFT", container, "TOPLEFT", 16, y)
    note:SetWidth(330)
    note:SetJustifyH("LEFT")
    note:SetText(L["Best first. In a group, the leader's lists are used, or the first paladin's by name. Tanks never get Salvation."])
    Draw()
    picker.Refresh()
    return y - 36
end

-- Lays out every setting inside container; returns the height used.
function Options.Build(container)
    local db = ns.db
    local y = -12
    y = Header(container, L["Bar"], y)
    y = Check(container, L["Lock the bar (unlock to drag it)"], function() return db.locked end, function(v) db.locked = v end, y)
    y = Check(container, L["Hide the bar while every blessing is fresh"], function() return db.hideWhenFresh end, function(v) db.hideWhenFresh = v end, y)
    y = Stepper(container, L["Bar scale"], function() return db.scale end, function(v) db.scale = v end, 0.5, 2, 0.1, "%.1f", y)
    y = Check(container, L["Show the Top Up button"], function() return db.showTopUp end, function(v) db.showTopUp = v end, y)
    y = Check(container, L["Show the aura button"], function() return db.showAura end, function(v) db.showAura = v end, y)
    Button(container, L["Reset bar position"], 16, y, 150, function() ns.Buttons.ResetPosition() end)
    Button(container, L["Show the plan"], 176, y, 150, function() ns.PlanWindow.Show() end)
    y = y - 34

    y = Header(container, L["Smart macro"], y)
    local macroNote = container:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    macroNote:SetPoint("TOPLEFT", container, "TOPLEFT", 16, y)
    macroNote:SetWidth(330)
    macroNote:SetJustifyH("LEFT")
    macroNote:SetText(L["One action-bar button: it casts the right blessing on your friendly target, or tops up your group when you have no friendly target. It updates out of combat."])
    y = y - 44
    Button(container, L["Make the smart macro"], 16, y, 200, function() ns.Macro.Make() end)
    y = y - 34

    y = Header(container, L["Your leanings"], y)
    local function LeanList()
        local src, list = db.lean or ns.Engine.DefaultLean(ns.Group.MyTree()), {}
        for i = 1, 3 do list[i] = src[i] or false end
        return list
    end
    local leanings = {}
    for slot = 1, 3 do
        ChoiceLabel(container, slot, y)
        leanings[slot] = Dropdown(container, 110, y, 150, BlessingItems, function() return LeanList()[slot] end, function(key)
            local list = LeanList()
            Place(list, slot, key, 3)
            db.lean = ns.Engine.CleanList(list)
            for _, d in ipairs(leanings) do d.Refresh() end
            ns.Group.Hello()
            Apply()
        end)
        y = y - 28
    end
    y = y - 6

    y = Header(container, L["Blessing lists"], y)
    y = ListEditor(container, y)

    y = Header(container, L["Warnings"], y)
    y = Stepper(container, L["Red when under (minutes)"], function() return db.warnMinutes end, function(v) db.warnMinutes = v end, 1, 30, 1, "%d", y)
    y = Stepper(container, L["Top Up refreshes under (minutes)"], function() return db.topUpMinutes end, function(v) db.topUpMinutes = v end, 1, 59, 1, "%d", y)
    y = Stepper(container, L["Warn below this many Symbol of Kings"], function() return db.symbolWarning end,
        function(v) db.symbolWarning = v end, 0, 100, 5, "%d", y, L["off"])
    y = y - 4

    y = Header(container, L["Language"], y)
    Dropdown(container, 16, y, 230, function()
        local items = { { value = "auto", text = L["Automatic (game language)"] } }
        for _, entry in ipairs(ns.LANGUAGES) do items[#items + 1] = { value = entry.code, text = entry.name } end
        return items
    end, function() return db.language end, function(code)
        db.language = code
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

-- Nullgate's Addon Config gives each addon a fixed-height page, so the settings go in a scroll frame
-- there (the hub hides the scroll bar when everything fits).
local function BuildScrolling(container)
    local scroll = CreateFrame("ScrollFrame", nil, container, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", container, "TOPLEFT", 0, 0)
    scroll:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", -24, 0)
    local child = CreateFrame("Frame", nil, scroll)
    child:SetSize(math.max(300, (container:GetWidth() or 0) - 24), 600)
    scroll:SetScrollChild(child)
    child:SetHeight(Options.Build(child))
    local hub = NullgatesAddonConfigForever
    local ui = hub and hub.UI
    if ui and ui.SetupAutoScroll then ui:SetupAutoScroll(scroll, child) end
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
        buildUI = function(container) BuildScrolling(container) end,
        toggleMovers = function(state) ns.db.locked = not state; ns.Buttons.Update() end,
        resetMovers = function() ns.Buttons.ResetPosition() end,
        isMoversUnlocked = function() return not ns.db.locked end,
    })
    Options.registered = true
end
