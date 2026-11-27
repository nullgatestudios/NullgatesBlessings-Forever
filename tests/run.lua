-- Nullgate's Blessings: tests for the blessing data and the assignment engine, including the case it
-- was designed for (a Protection and a Holy paladin in a dungeon).
-- Run from the repository root:  lua tests/run.lua   (Lua 5.1 or newer)

local source = debug.getinfo(1, "S").source or ""
local script = source:match("^@(.*)$") or "tests/run.lua"
local scriptDir = script:match("^(.*)[/\\][^/\\]*$") or "."
local root = (scriptDir:match("^(.*)[/\\][^/\\]*$") or ".") .. "/NullgatesBlessings-Forever/"

local ns = {}
local function Load(file) assert(loadfile(root .. file), "cannot load " .. file)("NullgatesBlessings-Forever", ns) end
Load("Data/Blessings.lua")
Load("Engine.lua")
local E = ns.Engine

local checks, failures = 0, 0
local function EQ(got, want, name)
    checks = checks + 1
    if got ~= want then
        failures = failures + 1
        print(string.format("FAIL %s: expected %s, got %s", name, tostring(want), tostring(got)))
    end
end

local function Set(...) local s = {}; for _, v in ipairs({ ... }) do s[v] = true end; return s end
local ALL = Set("might", "wisdom", "kings", "light", "salvation")
local NO_KINGS = Set("might", "wisdom", "light", "salvation")

-- --- The data: Forever ---------------------------------------------------------------
EQ(type(ns.BLESSING_DATA_BUILD), "string", "the data names its client build")
for _, b in ipairs(ns.BLESSINGS) do
    EQ(b.single[1][3], 3600, b.key .. ": one hour in Forever")
    EQ(#b.greater > 0 and b.greater[1][3] == 3600, true, b.key .. ": Greater also one hour")
    EQ(b.reagent, 21177, b.key .. ": Greater uses Symbol of Kings")
end
EQ(#ns.BLESSINGS, 3, "three blessings (Forever 1.60.1.71037 removed Light and Salvation; no Sanctuary)")
EQ(ns.OATH_OF_LIGHT and ns.OATH_OF_LIGHT[1] == 1328548 and ns.OATH_OF_LIGHT[2] == 300, true, "Oath of Light: spell 1328548, 5 minutes")
EQ(#ns.AURAS >= 3, true, "auras")

-- --- The dungeon example ----------------------------------------------------------------
local prot = { name = "Ironwall", known = ALL, lean = E.DefaultLean(2) }
local holy = { name = "Brightmend", known = ALL, lean = E.DefaultLean(1) }
local players = {
    { name = "Shiv", class = "ROGUE", role = "DAMAGER" },
    { name = "Frosty", class = "MAGE", role = "DAMAGER" },
    { name = "Arrow", class = "HUNTER", role = "DAMAGER" },
    { name = "Ironwall", class = "PALADIN", role = "TANK", tank = true },
    { name = "Brightmend", class = "PALADIN", role = "HEALER" },
}
local plan = E.Assign({ prot, holy }, players, {})
local function Pair(p) return plan.Ironwall[p] .. "/" .. plan.Brightmend[p] end
EQ(Pair("Shiv"), "might/kings", "rogue: Might from Protection, Kings from Holy")
EQ(Pair("Frosty"), "kings/wisdom", "mage: Kings from Protection, Wisdom from Holy")
EQ(Pair("Arrow"), "kings/wisdom", "hunter: Kings from Protection, Wisdom from Holy")
EQ(Pair("Ironwall"), "kings/wisdom", "the Protection tank: Kings and Wisdom")
EQ(Pair("Brightmend"), "kings/wisdom", "the Holy paladin: Kings and Wisdom")

-- The same plan whatever order the paladins are given in (every copy agrees).
local again = E.Assign({ holy, prot }, players, {})
for _, p in ipairs(players) do
    EQ(again.Ironwall[p.name] .. "/" .. again.Brightmend[p.name], Pair(p.name), "same plan in any order: " .. p.name)
end

-- --- Lists by class and spec -----------------------------------------------------------------------
local function W(...) return table.concat(E.Wishes(...), ",") end
EQ(W("ROGUE", "DAMAGER", false), "might,kings,salvation,light", "rogue: Might, Kings, Salvation, Light")
EQ(W("PRIEST", "HEALER", false), "wisdom,kings,salvation,light", "priest: Wisdom first")
EQ(W("DRUID", "NONE", false, 1), "wisdom,kings,salvation,light", "Balance druid (from talents)")
EQ(W("DRUID", "NONE", false, 2), "kings,might,salvation,light", "Feral druid in cat form")
EQ(W("DRUID", "TANK", true, 2), "kings,might,light", "Feral druid tanking: bear list")
EQ(W("SHAMAN", "NONE", false, 2), "might,kings,wisdom,salvation", "Enhancement shaman")
EQ(W("SHAMAN", "HEALER", false), "wisdom,kings,salvation,light", "spec not known, healer role: Restoration")
EQ(W("PALADIN", "NONE", false), "kings,wisdom,might,salvation,light", "spec not known, no role: the hybrid list")
EQ(W("WARRIOR", "DAMAGER", true), "kings,might,light", "a warrior tank")
local edited = { rogue = { "kings", false, "might", "kings" } }
EQ(W("ROGUE", "DAMAGER", false, nil, edited), "kings,might", "an edited list: gaps and repeats dropped")
EQ(W("ROGUE", "DAMAGER", true, nil, { rogue = { "salvation", "kings" } }), "kings", "tanks never get Salvation, even from an edited list")
-- Top choice already given by someone else: the next one.
plan = E.Assign({ prot }, { { name = "Shiv", class = "ROGUE", taken = Set("might") } }, {}, edited)
EQ(plan.Ironwall.Shiv, "kings", "edited rogue list, Kings first")
plan = E.Assign({ prot }, { { name = "Shiv", class = "ROGUE", taken = Set("kings") } }, {}, edited)
EQ(plan.Ironwall.Shiv, "might", "Kings already there: the rogue's next choice, Might")

-- --- Blessings already given are kept ------------------------------------------------------------
-- A tester's case: Herald put Might on themself and a friend gave them Wisdom; it asked for Kings.
local herald = { name = "Herald", known = ALL, lean = E.DefaultLean(3) }
local friend = { name = "Abandon", known = ALL, lean = E.DefaultLean(1) }
local me = { { name = "Herald", class = "PALADIN", role = "NONE", current = { Herald = "might", Abandon = "wisdom" } } }
plan = E.Assign({ herald, friend }, me, {})
EQ(plan.Herald.Herald .. "/" .. plan.Abandon.Herald, "might/wisdom", "both paladins running the addon: what's on stays")
me = { { name = "Herald", class = "PALADIN", role = "NONE", taken = Set("wisdom"), current = { Herald = "might" } } }
EQ(E.Assign({ herald }, me, {}).Herald.Herald, "might", "the friend without the addon: your Might stays, no switch to Kings")
plan = E.Assign({ prot }, { { name = "Shiv", class = "ROGUE", current = { Ironwall = "kings" }, taken = Set("kings") } }, {})
EQ(plan.Ironwall.Shiv, "might", "a kept blessing that someone else already gives is replaced")
plan = E.Assign({ prot }, { { name = "Shiv", class = "ROGUE", current = { Ironwall = "wisdom" } } }, {})
EQ(plan.Ironwall.Shiv, "might", "one that isn't on the player's wish list is replaced")
plan = E.Assign({ prot }, { { name = "Shiv", class = "ROGUE", current = { Ironwall = "kings" } } }, { Ironwall = { Shiv = "salvation" } })
EQ(plan.Ironwall.Shiv, "salvation", "a lock beats what's on")

-- --- The other paladin doesn't run the addon ---------------------------------------------
plan = E.Assign({ prot }, { { name = "Shiv", class = "ROGUE", taken = Set("kings") } }, {})
EQ(plan.Ironwall.Shiv, "might", "Kings already on the rogue from someone else: Might")
plan = E.Assign({ prot }, { { name = "Shiv", class = "ROGUE", taken = Set("might") } }, {})
EQ(plan.Ironwall.Shiv, "kings", "Might already there: the next wish, Kings")
plan = E.Assign({ prot }, { { name = "Frosty", class = "MAGE", taken = Set("wisdom", "kings") } }, {})
EQ(plan.Ironwall.Frosty, "salvation", "Wisdom and Kings taken on a mage: Salvation")

-- --- Only one paladin knows Kings ------------------------------------------------------------
local holyNoKings = { name = "Brightmend", known = NO_KINGS, lean = E.DefaultLean(1) }
plan = E.Assign({ prot, holyNoKings }, { { name = "Shiv", class = "ROGUE" }, { name = "Frosty", class = "MAGE" } }, {})
EQ(plan.Ironwall.Shiv .. "/" .. plan.Brightmend.Shiv, "kings/might", "rogue: Kings must come from Protection, so Holy gives Might")
EQ(plan.Ironwall.Frosty .. "/" .. plan.Brightmend.Frosty, "kings/wisdom", "mage: Kings from Protection, Wisdom from Holy")

-- --- Tanks never get Salvation --------------------------------------------------------------
local three = { prot, holy, { name = "Zeal", known = ALL, lean = E.DefaultLean(3) } }
plan = E.Assign(three, { { name = "Tanky", class = "WARRIOR", tank = true } }, {})
local given = {}
for _, p in ipairs(three) do if plan[p.name].Tanky then given[plan[p.name].Tanky] = true end end
EQ(given.salvation, nil, "a tank never gets Salvation")
EQ(given.kings and given.might and given.light, true, "a warrior tank gets Kings, Might and Light")
plan = E.Assign(three, { { name = "Dps", class = "WARRIOR" } }, {})
given = {}
for _, p in ipairs(three) do if plan[p.name].Dps then given[plan[p.name].Dps] = true end end
EQ(given.salvation, true, "a non-tank warrior does get Salvation from the third paladin")

-- --- No duplicates, never an unknown blessing ---------------------------------------------------
local four = { prot, holy, { name = "Zeal", known = ALL, lean = E.DefaultLean(3) }, { name = "Aaron", known = Set("might"), lean = { "might" } } }
plan = E.Assign(four, { { name = "Shiv", class = "ROGUE" } }, {})
local seen, dup = {}, false
for _, p in ipairs(four) do
    local key = plan[p.name].Shiv
    if key then
        if seen[key] then dup = true end
        seen[key] = true
        EQ(p.known[key], true, p.name .. " only gives blessings they know")
    end
end
EQ(dup, false, "no two paladins give the same blessing to one player")

-- --- Locks --------------------------------------------------------------------------------------
plan = E.Assign({ prot, holy }, { { name = "Shiv", class = "ROGUE" } }, { Brightmend = { Shiv = "salvation" } })
EQ(plan.Brightmend.Shiv, "salvation", "a lock wins")
EQ(plan.Ironwall.Shiv, "might", "and the other paladin plans around it")
plan = E.Assign({ prot, holyNoKings }, { { name = "Shiv", class = "ROGUE" } }, { Brightmend = { Shiv = "kings" } })
EQ(plan.Brightmend.Shiv ~= "kings", true, "a lock on a blessing that paladin doesn't know is ignored")

-- --- Auras --------------------------------------------------------------------------------------
local auras = E.AssignAuras({
    { name = "Ironwall", knownAuras = Set("devotion", "retribution"), auraLean = { "devotion", "retribution" } },
    { name = "Brightmend", knownAuras = Set("devotion", "concentration"), auraLean = { "devotion", "concentration" } },
})
EQ(auras.Brightmend, "devotion", "auras: first by name gets their first choice")
EQ(auras.Ironwall, "retribution", "the next takes their next choice")

-- --- Ranks ---------------------------------------------------------------------------------------
local might = ns.BLESSINGS[1]
local known = {}
for _, r in ipairs(might.single) do known[r[1]] = true end
local function IsKnown(id) return known[id] == true end
EQ(E.Rank(might.single, 60, IsKnown)[2], 60, "a level 60 gets the top rank")
EQ(E.Rank(might.single, 25, IsKnown)[2], 32, "a level 25 gets the rank learned at 32 (up to 10 above)")

-- --- Sync messages -------------------------------------------------------------------------------
local msg = E.EncodeHello({ known = Set("might", "kings"), lean = { "might", "kings" }, knownAuras = Set("devotion"),
    auraLean = { "devotion" }, tanks = Set("Ironwall"), locks = { Shiv = "kings" } })
EQ(msg, "H;k=kings,might;l=might,kings;ka=devotion;al=devotion;tm=Ironwall;nt=;lk=Shiv:kings", "the hello message")
local info = E.DecodeHello(msg)
EQ(info.known.kings and info.known.might and info.lean[1] == "might" and info.tanks.Ironwall and info.locks.Shiv == "kings", true,
    "decodes back")
EQ(E.DecodeHello("garbage"), nil, "anything else is ignored")
EQ(next(E.DecodeHello("H;k=;l=;ka=;al=;tm=;nt=;lk=").known), nil, "an empty hello decodes to empty sets")
local ls = E.EncodeLeaderLocks({ Ironwall = { Shiv = "kings" }, Brightmend = { Frosty = "light" } })
EQ(ls, "LS;Brightmend:Frosty:light,Ironwall:Shiv:kings", "the leader lock message")
local back = E.DecodeLeaderLocks(ls)
EQ(back.Ironwall.Shiv == "kings" and back.Brightmend.Frosty == "light", true, "decodes back")
EQ(E.DecodeLeaderLocks("H;k="), nil, "a hello isn't a leader lock message")

-- --- Target level: a rank reaches players up to 10 levels below where it's learned -------
EQ(E.MinLevel("might"), 1, "Might reaches any level")
EQ(E.MinLevel("wisdom"), 4, "Wisdom (learned at 14) needs level 4")
EQ(E.MinLevel("kings"), 10, "Kings (learned at 20) needs level 10")
EQ(E.MinLevel("kings", true), 50, "Greater Kings (learned at 60) needs level 50")
EQ(E.MinLevel("might", true), 42, "Greater Might (learned at 52) needs level 42")
EQ(E.CanReceive("kings", 9), false, "a level 9 player can't get Kings")
EQ(E.CanReceive("kings", 10), true, "a level 10 player can")
EQ(E.CanReceive("kings", nil), true, "an unknown level isn't held back")
EQ(E.CanReceive("light", 1), true, "a blessing this client doesn't have isn't held back by level")

local function Got(planned, pal, player) return planned[pal] and planned[pal][player] end
plan = E.Assign({ prot }, { { name = "Lowbie", class = "WARRIOR", level = 9 } }, {})
EQ(Got(plan, "Ironwall", "Lowbie"), "might", "level 9 warrior: Might instead of Kings")
plan = E.Assign({ holy }, { { name = "Tinymage", class = "MAGE", level = 9 } }, {})
EQ(Got(plan, "Brightmend", "Tinymage"), "wisdom", "level 9 mage: Wisdom instead of Kings")
plan = E.Assign({ { name = "Brightmend", known = Set("might", "wisdom", "kings"), lean = E.DefaultLean(1) } }, { { name = "Baby", class = "MAGE", level = 3 } }, {})
EQ(Got(plan, "Brightmend", "Baby"), nil, "level 3 mage (Forever blessings): nothing yet, the mage list has no Might")
plan = E.Assign({ prot }, { { name = "Baby", class = "ROGUE", level = 3 } }, {})
EQ(Got(plan, "Ironwall", "Baby"), "might", "level 3 rogue: Might still works")
plan = E.Assign({ prot }, { { name = "Tenner", class = "WARRIOR", level = 10, tank = true } }, {})
EQ(Got(plan, "Ironwall", "Tenner"), "kings", "level 10 tank: Kings again")
plan = E.Assign({ prot }, { { name = "Lowbie", class = "WARRIOR", level = 9 } }, { Ironwall = { Lowbie = "kings" } })
EQ(Got(plan, "Ironwall", "Lowbie"), "might", "a lock on Kings for a level 9 player is set aside")
plan = E.Assign({ prot }, { { name = "Lowbie", class = "WARRIOR", level = 9, current = { Ironwall = "kings" } } }, {})
EQ(Got(plan, "Ironwall", "Lowbie"), "might", "a Kings already on a player too low for it isn't kept in the plan")
plan = E.Assign({ prot }, { { name = "WARRIOR", class = "WARRIOR", level = 45, greater = true } }, {})
EQ(Got(plan, "Ironwall", "WARRIOR"), "might", "raid: a class with a level 45 member gets Greater Might, not Greater Kings")
plan = E.Assign({ prot }, { { name = "WARLOCK", class = "WARLOCK", level = 49, greater = true } }, {})
EQ(Got(plan, "Ironwall", "WARLOCK"), "wisdom", "raid: warlocks with a level 49 member get Greater Wisdom (44+), not Greater Kings (50+)")

print(string.format("%d checks, %d failure(s)", checks, failures))
if failures > 0 then os.exit(1) end
