-- Nullgate's Blessings: the plan window. Paladins are rows, players (party) or classes (raid) are
-- columns; each cell is the blessing that paladin gives. Click a cell in your own row to lock it
-- (cycling through the blessings, then back to smart); the leader or an assistant can lock any cell.
local _, ns = ...

local L = ns.L
local PlanWindow = {}
ns.PlanWindow = PlanWindow

local CELL_W, ROW_H, NAME_W, TOP = 62, 20, 96, 52
local frame
local cells, rowLabels, colLabels = {}, {}, {}
local CYCLE = { "might", "wisdom", "kings", "light", "salvation" }

local SHORT
local function Short(key)
    SHORT = SHORT or { might = L["Might"], wisdom = L["Wisdom"], kings = L["Kings"], light = L["Light"], salvation = L["Salvation"] }
    return key and SHORT[key] or ""
end
PlanWindow.Short = Short

local function NextKey(key)
    local cycle = { false }
    for _, k in ipairs(ns.Plan.Available(CYCLE)) do cycle[#cycle + 1] = k end
    for i, k in ipairs(cycle) do
        if k == (key or false) then return cycle[i % #cycle + 1] or nil end
    end
    return cycle[2]
end
PlanWindow.NextKey = NextKey

-- Locks a cell: your own row in your settings (shared in your hello), others as leader locks.
function PlanWindow.CycleLock(paladin, column)
    local me = ns.Group.Me()
    if paladin == me then
        ns.db.locks[column] = NextKey(ns.db.locks[column])
        ns.Group.Hello()
    elseif ns.Group.CanLead(me) then
        local locks = ns.Group.LeaderLocks()
        locks[paladin] = locks[paladin] or {}
        locks[paladin][column] = NextKey(locks[paladin][column])
        ns.Group.SendLeaderLocks(locks)
    else
        ns.Print(L["Only the group leader or an assistant can lock another paladin's blessings."])
        return
    end
    ns.Buttons.Update()
    PlanWindow.Draw()
end

local function IsLocked(paladin, column)
    if paladin == ns.Group.Me() then return ns.db.locks[column] ~= nil end
    local l = ns.Group.LeaderLocks()[paladin]
    if l and l[column] then return true end
    local peer = ns.Group.peers[paladin]
    return peer and peer.locks and peer.locks[column] ~= nil
end

local function Build()
    frame = CreateFrame("Frame", "NullgatesBlessingsPlan", UIParent, "BasicFrameTemplateWithInset")
    frame:SetFrameStrata("DIALOG") -- above unit frames, nameplates and bags
    frame:SetToplevel(true)
    frame:SetPoint("CENTER")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:SetClampedToScreen(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    if type(frame.SetTitle) == "function" then frame:SetTitle(L["Blessing plan"])
    elseif type(frame.TitleText) == "table" then frame.TitleText:SetText(L["Blessing plan"]) end
    if UISpecialFrames then table.insert(UISpecialFrames, "NullgatesBlessingsPlan") end
    frame.hint = frame:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    frame.hint:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 12, 10)
    frame.hint:SetText(L["Click a cell in your row to lock it. Locked cells are marked *."])
    local announce = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    announce:SetSize(90, 20)
    announce:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -8, 6)
    announce:SetText(L["Announce"])
    announce:SetScript("OnClick", function() ns.Announce() end)
    frame.empty = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    frame.empty:SetPoint("TOP", frame, "TOP", 0, -TOP)
end

local function Label(list, i, template)
    local l = list[i]
    if not l then
        l = frame:CreateFontString(nil, "ARTWORK", template)
        list[i] = l
    end
    return l
end

local function Cell(r, c)
    cells[r] = cells[r] or {}
    local cell = cells[r][c]
    if not cell then
        cell = CreateFrame("Button", nil, frame)
        cell:SetSize(CELL_W - 2, ROW_H - 2)
        cell.bg = cell:CreateTexture(nil, "BACKGROUND")
        cell.bg:SetAllPoints(cell)
        cell.text = cell:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        cell.text:SetAllPoints(cell)
        local hl = cell:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints(cell)
        hl:SetColorTexture(1, 1, 1, 0.15)
        cell:SetScript("OnClick", function(self) PlanWindow.CycleLock(self.paladin, self.column) end)
        cells[r][c] = cell
    end
    return cell
end

function PlanWindow.Draw()
    if not (frame and frame:IsShown()) then return end
    local state = ns.Buttons.State() or ns.Plan.Build()
    local paladins = {}
    for _, p in ipairs(state.paladins) do paladins[#paladins + 1] = p.name end
    table.sort(paladins)
    for c, col in ipairs(state.columns) do
        local l = Label(colLabels, c, "GameFontNormalSmall")
        l:ClearAllPoints()
        l:SetPoint("TOPLEFT", frame, "TOPLEFT", 12 + NAME_W + (c - 1) * CELL_W, -30)
        l:SetWidth(CELL_W - 2)
        local color = RAID_CLASS_COLORS and RAID_CLASS_COLORS[col.class]
        l:SetText(col.name:sub(1, 8))
        if color then l:SetTextColor(color.r, color.g, color.b) end
        l:Show()
    end
    for c = #state.columns + 1, #colLabels do colLabels[c]:Hide() end
    for r, name in ipairs(paladins) do
        local l = Label(rowLabels, r, "GameFontHighlightSmall")
        l:ClearAllPoints()
        l:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -TOP - (r - 1) * ROW_H - 3)
        local aura = state.auras[name]
        l:SetText(name .. (aura and (" |cff9d9d9d(" .. aura .. ")|r") or ""))
        l:Show()
        for c, col in ipairs(state.columns) do
            local cell = Cell(r, c)
            cell:ClearAllPoints()
            cell:SetPoint("TOPLEFT", frame, "TOPLEFT", 12 + NAME_W + (c - 1) * CELL_W, -TOP - (r - 1) * ROW_H)
            local key = state.plan[name] and state.plan[name][col.name]
            cell.paladin, cell.column = name, col.name
            cell.text:SetText(Short(key) .. (IsLocked(name, col.name) and "*" or ""))
            cell.bg:SetColorTexture(name == ns.Group.Me() and 0.15 or 0.08, 0.12, 0.18, 0.9)
            cell:Show()
        end
        for c = #state.columns + 1, #(cells[r] or {}) do cells[r][c]:Hide() end
    end
    for r = #paladins + 1, #rowLabels do
        rowLabels[r]:Hide()
        for _, cell in ipairs(cells[r] or {}) do cell:Hide() end
    end
    frame.empty:SetText(#paladins == 0 and L["No paladins running the addon in your group."] or "")
    frame:SetSize(math.max(300, 24 + NAME_W + #state.columns * CELL_W), TOP + math.max(1, #paladins) * ROW_H + 40)
end

function PlanWindow.Toggle()
    if not frame then Build() end
    if frame:IsShown() then frame:Hide() else frame:Show(); PlanWindow.Draw() end
end

function PlanWindow.Show()
    if not frame then Build() end
    frame:Show()
    PlanWindow.Draw()
end
