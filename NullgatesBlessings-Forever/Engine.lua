-- Nullgate's Blessings: the assignment engine. Every paladin running the addon calls Engine.Assign
-- with the same inputs and gets the same plan, so no negotiation is needed. Pure: no game calls.
--
-- For each player, the paladins (sorted by name) are given distinct blessings from the player's wish
-- list, skipping blessings already on the player from a paladin without the addon. Every combination
-- is tried; the best gives each player their highest-wished blessings, then follows each paladin's
-- leanings. Locks are applied first, then blessings paladins already have on the player are kept,
-- and everyone else plans around them.
local _, ns = ...

local Engine = {}
ns.Engine = Engine

Engine.KEYS = { "might", "wisdom", "kings", "light", "salvation" }

-- Recommended wish lists, best first, by class and spec. A group can use the leader's edited lists
-- instead (see Engine.Wishes); every copy of the addon then uses the same ones.
local DEFAULT_LISTS = {
    warriorDps   = { "might", "kings", "salvation", "light" },
    warriorTank  = { "kings", "might", "light" },
    rogue        = { "might", "kings", "salvation", "light" },
    hunter       = { "kings", "wisdom", "salvation", "light" },
    mage         = { "wisdom", "kings", "salvation", "light" },
    warlock      = { "kings", "wisdom", "salvation", "light" },
    priest       = { "wisdom", "kings", "salvation", "light" },
    druidBalance = { "wisdom", "kings", "salvation", "light" },
    druidCat     = { "kings", "might", "salvation", "light" },
    druidBear    = { "kings", "might", "light" },
    druidResto   = { "wisdom", "kings", "salvation", "light" },
    shamanEle    = { "wisdom", "kings", "salvation", "light" },
    shamanEnh    = { "might", "kings", "wisdom", "salvation" },
    shamanResto  = { "wisdom", "kings", "salvation", "light" },
    paladinHoly  = { "wisdom", "kings", "salvation", "light" },
    paladinProt  = { "kings", "wisdom", "light" },
    paladinRet   = { "might", "kings", "wisdom", "salvation" },
    hybrid       = { "kings", "wisdom", "might", "salvation", "light" }, -- a druid, shaman or paladin whose spec isn't known yet
}
Engine.DEFAULT_LISTS = DEFAULT_LISTS
-- In the order the settings show them.
Engine.LIST_IDS = { "warriorDps", "warriorTank", "rogue", "hunter", "mage", "warlock", "priest", "druidBalance", "druidCat",
    "druidBear", "druidResto", "shamanEle", "shamanEnh", "shamanResto", "paladinHoly", "paladinProt", "paladinRet", "hybrid" }

local SPEC_LISTS = { -- talent tree (1, 2, 3) -> list
    DRUID = { "druidBalance", "druidCat", "druidResto" },
    SHAMAN = { "shamanEle", "shamanEnh", "shamanResto" },
    PALADIN = { "paladinHoly", "paladinProt", "paladinRet" },
}
local HEALER_LISTS = { DRUID = "druidResto", SHAMAN = "shamanResto", PALADIN = "paladinHoly" }
local SINGLE = { ROGUE = "rogue", HUNTER = "hunter", MAGE = "mage", WARLOCK = "warlock", PRIEST = "priest" }

-- Which list a player uses: class, talent tree (nil when not known), group role ("TANK", "HEALER",
-- "DAMAGER" or "NONE") and whether they're treated as a tank.
function Engine.ListFor(class, spec, role, tank)
    if class == "WARRIOR" then return tank and "warriorTank" or "warriorDps" end
    if SINGLE[class] then return SINGLE[class] end
    if tank then
        if class == "DRUID" then return "druidBear" end
        if class == "PALADIN" then return "paladinProt" end
    end
    local bySpec = SPEC_LISTS[class]
    if bySpec and spec and bySpec[spec] then return bySpec[spec] end
    if role == "HEALER" and HEALER_LISTS[class] then return HEALER_LISTS[class] end
    return "hybrid"
end

-- A list without gaps or repeats (edited lists may have "none" slots, stored as false).
function Engine.CleanList(list)
    local out, seen = {}, {}
    for i = 1, #Engine.KEYS do
        local key = list and list[i]
        if key and not seen[key] then out[#out + 1] = key; seen[key] = true end
    end
    return out
end

-- A player's wish list: the group's edited list for their spec if there is one, else the
-- recommended one. Tanks never get Salvation.
function Engine.Wishes(class, role, tank, spec, lists)
    local id = Engine.ListFor(class, spec, role, tank)
    local list = (lists and lists[id] and Engine.CleanList(lists[id])) or DEFAULT_LISTS[id]
    if not tank then return list end
    local out = {}
    for _, key in ipairs(list) do if key ~= "salvation" then out[#out + 1] = key end end
    return out
end

-- Default leanings by talent tree (1 Holy, 2 Protection, 3 Retribution).
local LEAN = {
    [1] = { "wisdom", "kings", "light" },
    [2] = { "might", "kings" },
    [3] = { "might", "kings", "wisdom" },
}
function Engine.DefaultLean(tree)
    return LEAN[tree] or LEAN[3]
end

local function IndexOf(list, value)
    for i, v in ipairs(list or {}) do if v == value then return i end end
end

-- Picks blessings for one player. paladins: sorted { name, known = set, lean = list }; wish: list;
-- taken: set of keys already on the player from paladins without the addon; locked: [name] = key;
-- current: [name] = key already on the player from that paladin, kept when it's on the wish list and
-- doesn't clash. Returns [paladinName] = key.
function Engine.AssignPlayer(paladins, wish, taken, locked, current)
    local result, used = {}, {}
    for k in pairs(taken or {}) do used[k] = true end
    local free = {}
    for _, p in ipairs(paladins) do
        local key = locked and locked[p.name]
        if key and p.known[key] and not used[key] then
            result[p.name] = key
            used[key] = true
        elseif not key then
            free[#free + 1] = p
        end
    end
    local unkept = {}
    for _, p in ipairs(free) do
        local key = current and current[p.name]
        if key and p.known[key] and not used[key] and IndexOf(wish, key) then
            result[p.name] = key
            used[key] = true
        else
            unkept[#unkept + 1] = p
        end
    end
    free = unkept
    local candidates = {}
    for _, key in ipairs(wish) do if not used[key] then candidates[#candidates + 1] = key end end

    local best, bestScore, current = nil, -1, {}
    local W = #wish
    local function Search(i, score)
        if i > #free then
            if score > bestScore then
                bestScore = score
                best = {}
                for name, key in pairs(current) do best[name] = key end
            end
            return
        end
        local p = free[i]
        for _, key in ipairs(candidates) do
            if not used[key] and p.known[key] then
                used[key] = true
                current[p.name] = key
                local lean = IndexOf(p.lean, key)
                Search(i + 1, score + (W - IndexOf(wish, key) + 1) * 1000 + (lean and (10 - lean) or 0))
                current[p.name] = nil
                used[key] = nil
            end
        end
        Search(i + 1, score) -- this paladin gives nothing to this player
    end
    Search(1, 0)
    for name, key in pairs(best or {}) do result[name] = key end
    return result
end

-- The whole plan. paladins: as above (any order); players: { name, class, role, tank, spec, taken = set,
-- current = [paladin] = key }; locks: [paladinName][playerName] = key; lists: the group's edited
-- lists ([listId] = list), or nil. Returns plan[paladinName][playerName] = key.
function Engine.Assign(paladins, players, locks, lists)
    local sorted = {}
    for _, p in ipairs(paladins) do sorted[#sorted + 1] = p end
    table.sort(sorted, function(a, b) return a.name < b.name end)
    local plan = {}
    for _, p in ipairs(sorted) do plan[p.name] = {} end
    for _, player in ipairs(players) do
        local locked = {}
        for _, p in ipairs(sorted) do
            local key = locks and locks[p.name] and locks[p.name][player.name]
            if key then locked[p.name] = key end
        end
        local wish = Engine.Wishes(player.class, player.role, player.tank, player.spec, lists)
        for name, key in pairs(Engine.AssignPlayer(sorted, wish, player.taken, locked, player.current)) do plan[name][player.name] = key end
    end
    return plan
end

-- Auras: each paladin gets a distinct aura, following their own aura leanings in name order.
-- paladins: { name, knownAuras = set, auraLean = list }. Returns [name] = auraKey.
function Engine.AssignAuras(paladins)
    local sorted = {}
    for _, p in ipairs(paladins) do sorted[#sorted + 1] = p end
    table.sort(sorted, function(a, b) return a.name < b.name end)
    local result, used = {}, {}
    for _, p in ipairs(sorted) do
        for _, key in ipairs(p.auraLean or {}) do
            if p.knownAuras[key] and not used[key] then
                result[p.name], used[key] = key, true
                break
            end
        end
    end
    return result
end

-- The highest rank of a blessing you know that a target of `level` can receive (up to 10 levels
-- above theirs). ranks: { { spell, level, duration } }.
function Engine.Rank(ranks, level, isKnown)
    local best
    for _, rank in ipairs(ranks or {}) do
        if isKnown(rank[1]) and rank[2] <= level + 10 then best = rank end
    end
    return best
end

-- --- Sync messages -------------------------------------------------------------------
-- Hello (each paladin's own state): "H;k=might,wisdom;l=might,kings;ka=devotion;al=devotion;tm=Bob;nt=Ann;lk=Bob:kings"
--   k known blessings, l leanings, ka known auras, al aura leanings, tm marked tanks, nt marked
--   not-tanks, lk this paladin's own locks (player:blessing).
-- Leader locks (leader or assistant only): "LS;Pal:Player:kings,Pal2:Player2:might"

local function Join(list) return table.concat(list or {}, ",") end
local function SetToList(set)
    local list = {}
    for k in pairs(set or {}) do list[#list + 1] = k end
    table.sort(list)
    return list
end

function Engine.EncodeHello(info)
    local locks = {}
    for player, key in pairs(info.locks or {}) do locks[#locks + 1] = player .. ":" .. key end
    table.sort(locks)
    return "H;k=" .. Join(SetToList(info.known)) .. ";l=" .. Join(info.lean) .. ";ka=" .. Join(SetToList(info.knownAuras))
        .. ";al=" .. Join(info.auraLean) .. ";tm=" .. Join(SetToList(info.tanks)) .. ";nt=" .. Join(SetToList(info.notTanks))
        .. ";lk=" .. table.concat(locks, ",")
end

local function Split(text)
    local list = {}
    for item in (text or ""):gmatch("[^,]+") do list[#list + 1] = item end
    return list
end

local function ToSet(list)
    local set = {}
    for _, v in ipairs(list) do set[v] = true end
    return set
end

-- Returns the info table, or nil for anything that isn't a hello message.
function Engine.DecodeHello(message)
    if type(message) ~= "string" or message:sub(1, 2) ~= "H;" then return nil end
    local fields = {}
    for key, value in message:sub(3):gmatch("(%w+)=([^;]*)") do fields[key] = value end
    local locks = {}
    for _, pair in ipairs(Split(fields.lk)) do
        local player, key = pair:match("^(.-):(%a+)$")
        if player then locks[player] = key end
    end
    return { known = ToSet(Split(fields.k)), lean = Split(fields.l), knownAuras = ToSet(Split(fields.ka)),
             auraLean = Split(fields.al), tanks = ToSet(Split(fields.tm)), notTanks = ToSet(Split(fields.nt)), locks = locks }
end

-- locks: [paladin][player] = key.
function Engine.EncodeLeaderLocks(locks)
    local list = {}
    for pal, players in pairs(locks or {}) do
        for player, key in pairs(players) do list[#list + 1] = pal .. ":" .. player .. ":" .. key end
    end
    table.sort(list)
    return "LS;" .. table.concat(list, ",")
end

function Engine.DecodeLeaderLocks(message)
    if type(message) ~= "string" or message:sub(1, 3) ~= "LS;" then return nil end
    local locks = {}
    for _, item in ipairs(Split(message:sub(4))) do
        local pal, player, key = item:match("^(.-):(.-):(%a+)$")
        if pal then
            locks[pal] = locks[pal] or {}
            locks[pal][player] = key
        end
    end
    return locks
end

-- Specs learned by inspecting (or your own): "S;Bob:2,Ann:3", split to fit the 255-byte message limit.
-- specs: [name] = tree. Returns a list of messages.
local LIMIT = 240
local function Pack(prefix, items)
    local messages, current = {}, prefix
    for _, item in ipairs(items) do
        if #current > #prefix and #current + 1 + #item > LIMIT then
            messages[#messages + 1] = current
            current = prefix
        end
        current = current .. (#current > #prefix and "," or "") .. item
    end
    if #current > #prefix then messages[#messages + 1] = current end
    return messages
end

function Engine.EncodeSpecs(specs)
    local items = {}
    for name, tree in pairs(specs or {}) do items[#items + 1] = name .. ":" .. tree end
    table.sort(items)
    return Pack("S;", items)
end

-- Returns [name] = tree, or nil for anything that isn't a spec message.
function Engine.DecodeSpecs(message)
    if type(message) ~= "string" or message:sub(1, 2) ~= "S;" then return nil end
    local specs = {}
    for _, item in ipairs(Split(message:sub(3))) do
        local name, tree = item:match("^(.-):([123])$")
        if name and name ~= "" then specs[name] = tonumber(tree) end
    end
    return specs
end

-- A paladin's edited lists: "W0;" (back to the recommended lists) followed by
-- "W;rogue=might.kings,priest=wisdom.kings" with the edited ones. lists: [listId] = list.
function Engine.EncodeLists(lists)
    local items = {}
    for _, id in ipairs(Engine.LIST_IDS) do
        local list = lists and lists[id] and Engine.CleanList(lists[id])
        if list then items[#items + 1] = id .. "=" .. table.concat(list, ".") end
    end
    local messages = { "W0;" }
    for _, m in ipairs(Pack("W;", items)) do messages[#messages + 1] = m end
    return messages
end

-- Returns "reset", or [listId] = list, or nil for anything else.
function Engine.DecodeLists(message)
    if message == "W0;" then return "reset" end
    if type(message) ~= "string" or message:sub(1, 2) ~= "W;" then return nil end
    local valid = {}
    for _, k in ipairs(Engine.KEYS) do valid[k] = true end
    local lists = {}
    for _, item in ipairs(Split(message:sub(3))) do
        local id, keys = item:match("^(%a+)=([%a.]*)$")
        if id and DEFAULT_LISTS[id] then
            local list = {}
            for key in keys:gmatch("[^.]+") do if valid[key] then list[#list + 1] = key end end
            lists[id] = list
        end
    end
    return lists
end
