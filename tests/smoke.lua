-- Nullgate's Blessings: smoke test of the whole addon with stand-in game API.
-- Logs in as a Protection paladin tank in a dungeon party with a rogue, a mage, a hunter and a Holy
-- paladin, receives the Holy paladin's hello over addon messages, and checks the buttons follow the
-- shared plan; then blessings from a paladin without the addon, combat, locks (own and leader), Top Up,
-- the announcement, tank marks, a raid (Greater Blessings by class), settings and /nbless check.
-- Run from the repository root:  lua tests/smoke.lua

local source = debug.getinfo(1, "S").source or ""
local script = source:match("^@(.*)$") or "tests/smoke.lua"
local scriptDir = script:match("^(.*)[/\\][^/\\]*$") or "."
local repo = scriptDir:match("^(.*)[/\\][^/\\]*$") or "."
local folder = "NullgatesBlessings-Forever"
local root = repo .. "/" .. folder .. "/"

local checks, failures = 0, 0
local function OK(cond, name)
    checks = checks + 1
    if not cond then failures = failures + 1; io.write("FAIL " .. name .. "\n") end
end

-- --- Stand-in game API ----------------------------------------------------------
local frames, printed, said, sent = {}, {}, {}, {}
local function NewFrame(kind, name, _, template)
    local f = { kind = kind, name = name, template = template, scripts = {}, attributes = {}, events = {}, shown = false }
    setmetatable(f, { __index = function(_, key) if type(key) == "string" and key:match("^%u") then return function() return nil end end end })
    function f:SetScript(k, fn) self.scripts[k] = fn end
    function f:GetScript(k) return self.scripts[k] end
    function f:RegisterEvent(e) self.events[e] = true end
    function f:SetAttribute(k, v) self.attributes[k] = v end
    function f:GetAttribute(k) return self.attributes[k] end
    function f:Show() self.shown = true end
    function f:Hide() self.shown = false end
    function f:SetShown(v) self.shown = v and true or false end
    function f:IsShown() return self.shown end
    function f:SetText(t) self.text = t end
    function f:GetText() return self.text end
    function f:SetChecked(v) self.checked = v end
    function f:GetChecked() return self.checked end
    function f:CreateFontString() return NewFrame("FontString") end
    function f:CreateTexture() return NewFrame("Texture") end
    frames[#frames + 1] = f
    if name then _G[name] = f end
    return f
end
CreateFrame = NewFrame
SlashCmdList = {}
UIParent = NewFrame("Frame", "UIParent")
GameTooltip = NewFrame("GameTooltip", "GameTooltip")
UISpecialFrames = {}
RAID_CLASS_COLORS = {}
print = function(text) printed[#printed + 1] = tostring(text) end
function SendChatMessage(text, channel) said[#said + 1] = channel .. ": " .. text end
local function Printed(fragment)
    for _, line in ipairs(printed) do if line:find(fragment, 1, true) then return true end end
    return false
end

local inCombat, raid, now = false, false, 1000
local units = {
    player = { name = "Ironwall", class = "PALADIN", level = 60, role = "TANK" },
    party1 = { name = "Brightmend", class = "PALADIN", level = 60, role = "HEALER" },
    party2 = { name = "Shiv", class = "ROGUE", level = 60, role = "DAMAGER" },
    party3 = { name = "Frosty", class = "MAGE", level = 60, role = "DAMAGER" },
    party4 = { name = "Arrow", class = "HUNTER", level = 60, role = "DAMAGER" },
}
local byName = {}
for unit, u in pairs(units) do byName[u.name] = unit end
local function U(unit) return units[unit] or units[byName[unit] or ""] end
function UnitExists(u) return U(u) ~= nil end
function UnitClass(u) return U(u).class, U(u).class end
function UnitName(u) return U(u) and U(u).name end
function UnitLevel(u) return U(u).level end
function UnitIsUnit(a, b) return U(a) == U(b) end
function UnitIsConnected() return true end
function UnitIsDeadOrGhost() return false end
function UnitInRange() return true, true end
function UnitGroupRolesAssigned(u) return U(u).role end
function GetPartyAssignment() return false end
local leader = "Ironwall"
function UnitIsGroupLeader(u) return UnitName(u) == leader or u == leader end
function UnitIsGroupAssistant() return false end
function Ambiguate(name) return (name:gsub("%-.*$", "")) end
function IsInRaid() return raid end
function GetNumSubgroupMembers() return 4 end
function GetNumGroupMembers() return raid and 5 or 5 end
local raidUnits = { "player", "party1", "party2", "party3", "party4" }
function GetRaidRosterInfo(i) return nil, nil, 1 end
function InCombatLockdown() return inCombat end
function GetTime() return now end
function GetBuildInfo() return "1.60.1", "70532", "Nov 2026", 16001 end
function GetTalentTabInfo(tab) return "Tab", "icon", tab == 2 and 31 or 5, "file" end
local timers = {}
C_Timer = { After = function(_, fn) timers[#timers + 1] = fn end, NewTicker = function() end }
local function Flush() for _ = 1, 3 do local t = timers; timers = {}; for _, fn in ipairs(t) do fn() end end end
C_ChatInfo = { RegisterAddonMessagePrefix = function() return true end,
               SendAddonMessage = function(prefix, msg, channel) sent[#sent + 1] = { prefix = prefix, msg = msg, channel = channel } end }

local data = {}
assert(loadfile(root .. "Data/Blessings.lua"))(folder, data)
local names, known = {}, {}
local NAMES = { might = "Blessing of Might", wisdom = "Blessing of Wisdom", kings = "Blessing of Kings", light = "Blessing of Light", salvation = "Salvation" }
local GREATER = { might = "Greater Blessing of Might", wisdom = "Greater Blessing of Wisdom", kings = "Greater Blessing of Kings", light = "Greater Blessing of Light", salvation = "Mass Salvation" }
for _, b in ipairs(data.BLESSINGS) do
    for _, r in ipairs(b.single) do names[r[1]] = NAMES[b.key]; known[r[1]] = true end
    for _, r in ipairs(b.greater) do names[r[1]] = GREATER[b.key]; known[r[1]] = true end
end
for _, a in ipairs(data.AURAS) do for _, r in ipairs(a.ranks) do names[r[1]] = a.key .. " aura"; known[r[1]] = true end end
C_Spell = { GetSpellName = function(id) return names[id] end, GetSpellTexture = function(id) return "tex" .. tostring(id) end }
C_SpellBook = { IsSpellKnown = function(id) return known[id] == true end }
local symbols = 50
C_Item = { GetItemCount = function(id) return id == 21177 and symbols or 0 end }
local auras = {} -- [unit] = { { name, expires, sourceUnit } }
C_UnitAuras = { GetAuraDataByIndex = function(u, i)
    local a = auras[u] and auras[u][i]
    return a and { name = a[1], expirationTime = a[2], sourceUnit = a[3] } or nil
end }

-- --- Load the files in .toc order -----------------------------------------------
local ns = {}
local toc = assert(io.open(root .. folder .. ".toc", "r")):read("*a")
for line in toc:gmatch("[^\r\n]+") do
    if not line:match("^##") and line:match("%.lua$") then
        assert(loadfile(root .. line:gsub("\\", "/")))(folder, ns)
    end
end
local core
for _, f in ipairs(frames) do if f.events.CHAT_MSG_ADDON then core = f end end
local function Fire(event, ...) core.scripts.OnEvent(core, event, ...) end
Fire("ADDON_LOADED", folder)
local db = NullgatesBlessingsDB
OK(db.warnMinutes == 5 and db.topUpMinutes == 10 and #db.auraLean == 3, "saved data gets its defaults")
OK(SLASH_NULLGATESBLESSINGS1 == "/nbless" and SLASH_NULLGATESBLESSINGS2 == "/blessings", "slash commands /nbless and /blessings")

-- --- Login, alone in the plan --------------------------------------------------------------
Fire("PLAYER_LOGIN")
Flush()
OK(sent[1] and sent[1].prefix == "NGBless" and sent[1].channel == "PARTY" and sent[1].msg:find("^H;"), "a hello goes out to the party")
local hello = ns.Engine.DecodeHello(sent[1].msg)
OK(hello.known.kings and hello.lean[1] == "might", "it carries our blessings and Protection leanings")
OK(next(hello.tanks) == nil, "no tank mark needed: our role selection already says Tank")
units.player.role = "NONE"
OK(ns.Group.MyInfo().tanks.Ironwall, "with no role, the Protection talent guess marks us as a tank")
units.player.role = "TANK"

-- --- The Holy paladin's hello arrives ------------------------------------------------------
local holyHello = ns.Engine.EncodeHello({ known = { might = true, wisdom = true, kings = true, light = true, salvation = true },
    lean = { "wisdom", "kings", "light" }, knownAuras = { concentration = true }, auraLean = { "concentration" }, tanks = {}, locks = {} })
sent = {}
Fire("CHAT_MSG_ADDON", "NGBless", holyHello, "PARTY", "Brightmend-Realm")
Flush()
OK(#sent == 1, "a newcomer gets our hello back")
local state = ns.Buttons.State()
local function Mine(name) return state.plan.Ironwall[name] end
local function Theirs(name) return state.plan.Brightmend[name] end
OK(Mine("Shiv") == "might" and Theirs("Shiv") == "kings", "rogue: Might from us, Kings from the Holy paladin")
OK(Mine("Frosty") == "kings" and Theirs("Frosty") == "wisdom", "mage: Kings from us, Wisdom from them")
OK(Mine("Ironwall") == "kings" and Theirs("Ironwall") == "wisdom", "us (the tank): Kings and Wisdom")

local slot = {}
for _, b in ipairs(ns.Buttons.slots) do if b.target then slot[b.target.label] = b end end
local mightTop = data.BLESSINGS[1].single[#data.BLESSINGS[1].single][1]
OK(slot.Shiv and slot.Shiv.template == "SecureActionButtonTemplate", "a secure button for each party member")
OK(slot.Shiv.attributes.type == "spell" and slot.Shiv.attributes.spell == mightTop and slot.Shiv.attributes.unit == "party2",
    "the rogue's button casts our top Blessing of Might on the rogue")
OK(slot.Shiv.glow.shown, "missing: the button is red")
OK(NullgatesBlessingsBar.shown, "something's missing: the bar shows")

-- --- Blessings land; one from a paladin without the addon -------------------------------------
auras.party2 = { { "Blessing of Might", now + 3600, "player" } }
auras.party3 = { { "Blessing of Kings", now + 3600, "raid9" } } -- someone not running the addon
Fire("UNIT_AURA", "party2")
Flush()
state = ns.Buttons.State()
OK(not slot.Shiv.glow.shown and slot.Shiv.timer.text == "60m", "our Might on the rogue: 60 minutes, not red")
OK(state.plan.Ironwall.Frosty ~= "kings" and state.plan.Brightmend.Frosty ~= "kings", "Kings already on the mage from someone else: nobody plans it")

-- --- Top Up ------------------------------------------------------------------------------------
local topUp = ns.Buttons.topUp
OK(topUp.attributes.unit and topUp.attributes.unit ~= "party2", "Top Up skips the rogue (plenty of time) for someone missing")
auras = {}
for unit in pairs(units) do
    local name = units[unit].name
    local key = ns.Buttons.State().plan.Ironwall[name]
    if key then auras[unit] = { { NAMES[key], now + 3000, "player" } } end
end
auras.party4 = { { NAMES[ns.Buttons.State().plan.Ironwall.Arrow], now + 300, "player" } }
table.insert(auras.party3, { "Blessing of Kings", now + 3600, "raid9" }) -- still there from the other paladin
Fire("UNIT_AURA", "party4")
Flush()
OK(topUp.attributes.unit == "party4", "Top Up picks the one with 5 minutes left")
db.locked = true
auras.party4[1][2] = now + 3000
local onAura = ns.Plan.Aura(ns.Buttons.State().auras.Ironwall) -- your aura is on too
function GetNumShapeshiftForms() return 1 end
function GetShapeshiftFormInfo() return "tex", true, true, onAura.ranks[#onAura.ranks][1] end
Fire("UNIT_AURA", "party4")
Flush()
OK(not NullgatesBlessingsBar.shown, "locked and every blessing fresh: the bar hides")
db.hideWhenFresh = false
ns.Buttons.UpdateTimers()
OK(NullgatesBlessingsBar.shown, "unless hiding is turned off")
db.hideWhenFresh, db.locked = true, false
GetNumShapeshiftForms, GetShapeshiftFormInfo = nil, nil
auras.party4[1][2] = now + 300

-- --- Combat ------------------------------------------------------------------------------------
inCombat = true
local before = slot.Shiv.attributes.spell
db.locks.Shiv = "salvation"
Fire("UNIT_AURA", "party2")
Flush()
OK(slot.Shiv.attributes.spell == before and slot.Shiv.stale, "in combat the buttons don't change and are marked")
inCombat = false
Fire("PLAYER_REGEN_ENABLED")
Flush()
OK(ns.Buttons.State().plan.Ironwall.Shiv == "salvation", "after combat our lock on the rogue applies")
OK(ns.Buttons.State().plan.Brightmend.Shiv == "might", "and the Holy paladin plans around it (Might)")
db.locks.Shiv = nil

-- --- Leader locks -------------------------------------------------------------------------------
local ls = ns.Engine.EncodeLeaderLocks({ Brightmend = { Shiv = "light" } })
Fire("CHAT_MSG_ADDON", "NGBless", ls, "PARTY", "Brightmend")
Flush()
OK(ns.Buttons.State().plan.Brightmend.Shiv ~= "light", "leader locks from someone who isn't leader are ignored")
leader = "Brightmend"
Fire("CHAT_MSG_ADDON", "NGBless", ls, "PARTY", "Brightmend")
Flush()
OK(ns.Buttons.State().plan.Brightmend.Shiv == "light", "from the leader they apply")
leader = "Ironwall"

-- --- Plan window and announce -------------------------------------------------------------------
SlashCmdList.NULLGATESBLESSINGS("")
OK(NullgatesBlessingsPlan and NullgatesBlessingsPlan.shown, "/nbless shows the plan")
SlashCmdList.NULLGATESBLESSINGS("announce")
OK(said[1] and said[1]:find("^PARTY: Brightmend: ") and said[2] and said[2]:find("^PARTY: Ironwall: "), "the plan is announced to party chat, one line per paladin")

-- --- Tank marks ----------------------------------------------------------------------------------
SlashCmdList.NULLGATESBLESSINGS("tank Shiv")
Flush()
OK(db.tanks.Shiv == true and Printed("Shiv is marked as a tank."), "/nbless tank marks a tank")
local given = { ns.Buttons.State().plan.Ironwall.Shiv, ns.Buttons.State().plan.Brightmend.Shiv }
OK(given[1] ~= "salvation" and given[2] ~= "salvation", "a marked tank gets no Salvation")
SlashCmdList.NULLGATESBLESSINGS("tank Shiv")
SlashCmdList.NULLGATESBLESSINGS("tank Shiv")
OK(db.tanks.Shiv == nil, "marking cycles back to automatic")

-- --- A raid: Greater Blessings by class -------------------------------------------------------------
raid = true
for i, unit in ipairs(raidUnits) do units["raid" .. i] = units[unit] end
Fire("GROUP_ROSTER_UPDATE")
Flush()
state = ns.Buttons.State()
OK(state.mode == "raid", "in a raid the plan is by class")
local classes = {}
for _, col in ipairs(state.columns) do classes[#classes + 1] = col.name end
OK(table.concat(classes, ",") == "HUNTER,MAGE,PALADIN,ROGUE", "one column per class")
local greaterMight = data.BLESSINGS[1].greater[#data.BLESSINGS[1].greater][1]
local rogueSlot
for _, b in ipairs(ns.Buttons.slots) do if b.target and b.target.label == "ROGUE" then rogueSlot = b end end
OK(rogueSlot and (rogueSlot.attributes.spell == greaterMight or names[rogueSlot.attributes.spell]:find("^Greater")),
    "the rogue class button casts a Greater Blessing")
symbols = 3
Fire("UNIT_AURA", "player")
Flush()
OK(Printed("Low on Symbol of Kings: 3 left."), "low on Symbol of Kings in a raid: a warning")

-- --- The aura button only while your aura is off ------------------------------------------------------
local myAura = ns.Plan.Aura(ns.Buttons.State().auras.Ironwall)
local formOn = false
function GetNumShapeshiftForms() return 1 end
function GetShapeshiftFormInfo() return "tex", formOn, true, myAura.ranks[#myAura.ranks][1] end
ns.Buttons.Update()
OK(ns.Buttons.aura.shown, "aura off: the aura button shows")
formOn = true
Fire("UPDATE_SHAPESHIFT_FORM")
Flush()
OK(not ns.Buttons.aura.shown, "aura on: no aura button")
formOn = false

-- --- Auras the game hides from addons (secret values, usually in combat) ------------------------------
auras.raid1 = { { "Blessing of Kings", 4000, "player" }, { "Blessing of Wisdom", 0, "raid9" } }
local firstRead = { ns.Group.Blessings("raid1", {}, 1000) }
local hidden = false
local realRead = C_UnitAuras.GetAuraDataByIndex
C_UnitAuras.GetAuraDataByIndex = function(u, i)
    if hidden then error("GetAuraDataByIndex(): Auras cannot be accessed when secret") end
    return realRead(u, i)
end
C_Secrets = { ShouldUnitAuraIndexBeSecret = function() return hidden end }
hidden = true
local ok, taken, mine = pcall(ns.Group.Blessings, "raid1", {}, 1600)
OK(ok, "hidden auras don't cause an error")
OK(ok and taken.wisdom and mine.kings == firstRead[2].kings - 600, "hidden auras: the last full read is used, timers counted down")
C_Secrets = nil
ok, taken, mine = pcall(ns.Group.Blessings, "raid1", {}, 1600)
OK(ok and taken.wisdom, "the refused read is caught even without the game's secret check")
hidden = false
C_UnitAuras.GetAuraDataByIndex = realRead

-- --- Settings and /nbless check ---------------------------------------------------------------------
SlashCmdList.NULLGATESBLESSINGS("config")
OK(NullgatesBlessingsOptions and NullgatesBlessingsOptions.shown, "/nbless config opens the settings")
SlashCmdList.NULLGATESBLESSINGS("check")
local log = table.concat(db.check or {}, "\n")
OK(log:find("C_ChatInfo.SendAddonMessage=yes", 1, true), "check reports which calls exist")
OK(log:find("paladins heard from: Brightmend", 1, true), "check lists the paladins heard from")

io.write(string.format("smoke: %d checks, %d failure(s)\n", checks, failures))
if failures > 0 then os.exit(1) end
