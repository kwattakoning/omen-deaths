-- Omen Deaths: the leaderboard window.
local _, ns = ...
local UI = {}
ns.UI = UI

local ROWS, ROW_H = 12, 30
local GOLD = { 1, 0.82, 0 }
local MEDALS = { { 1, 0.82, 0 }, { 0.78, 0.8, 0.88 }, { 0.82, 0.5, 0.25 } }
local CRIMSON = { 0.77, 0.12, 0.23 }
local SKULL = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_8"
local BONE = "Interface\\Icons\\INV_Misc_Bone_HumanSkull_01"
local QUESTION = "Interface\\Icons\\INV_Misc_QuestionMark"
local WHITE = "Interface\\Buttons\\WHITE8X8"
local MORPHEUS = "Fonts\\MORPHEUS.TTF"

local QUIPS = {
    "Here lie the brave. Mostly the clumsy.",
    "Death is temporary. Shame is forever.",
    "Proudly sponsored by the Spirit Healer.",
    "Every wipe tells a story.",
    "Repair bills are a lifestyle.",
    "Stand in the fire, climb the board.",
    "Keep calm and release spirit.",
}
local TOP_TITLES = { "Spirit Healer's Favourite", "Professional Corpse Runner", "Repair Bill Champion" }
local TITLES = {
    "Floor Inspector", "Gravity Tester", "Pull Enthusiast", "Lava Swimmer", "Aggro Magnet",
    "Ankh Collector", "Durability Destroyer", "Fall Damage Researcher", "Brave (Briefly)",
    "Leeroy's Apprentice", "Graveyard Regular", "Part-time Ghost",
}

-- Same name, same title: a title should not jump around between refreshes.
function UI.Title(name, rank)
    if TOP_TITLES[rank] then return TOP_TITLES[rank] end
    local h = 0
    for i = 1, #name do h = (h * 31 + name:byte(i)) % 1000003 end
    return TITLES[h % #TITLES + 1]
end

function UI.Ago(t, now)
    local s = math.max(0, (now or ns.Now()) - t)
    if s < 60 then return "just now" end
    if s < 3600 then return math.floor(s / 60) .. "m ago" end
    if s < 86400 then return math.floor(s / 3600) .. "h ago" end
    return math.floor(s / 86400) .. "d ago"
end

local Colored = ns.Colored

local frame, rows, tabs, viewButtons
local state -- settings table: period, view, scope (label of the chosen place)

---------------------------------------------------------------------------
-- Building
---------------------------------------------------------------------------
local function Font(parent, size, layer)
    local fs = parent:CreateFontString(nil, layer or "OVERLAY")
    fs:SetFont(MORPHEUS, size, "OUTLINE")
    return fs
end

local function Button(parent, text, width)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(width, 22)
    b:SetText(text)
    return b
end

local function Select(button, on)
    if on then button:LockHighlight() else button:UnlockHighlight() end
    local fs = button:GetFontString()
    if fs then
        if on then fs:SetTextColor(GOLD[1], GOLD[2], GOLD[3]) else fs:SetTextColor(0.8, 0.8, 0.8) end
    end
end

local function BuildRow(parent, i)
    local row = CreateFrame("Frame", nil, parent)
    row:SetSize(412, ROW_H - 2)
    row:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -(i - 1) * ROW_H)
    row:EnableMouse(true)

    local stripe = row:CreateTexture(nil, "BACKGROUND")
    stripe:SetAllPoints(row)
    stripe:SetTexture(WHITE)
    stripe:SetVertexColor(1, 1, 1)
    stripe:SetAlpha(i % 2 == 0 and 0.05 or 0.02)

    local bar = row:CreateTexture(nil, "BORDER")
    bar:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
    bar:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 0, 0)
    bar:SetTexture(WHITE)
    bar:SetVertexColor(CRIMSON[1], CRIMSON[2], CRIMSON[3])
    bar:SetAlpha(0.35)
    row.bar = bar

    local rank = Font(row, 18)
    rank:SetPoint("LEFT", row, "LEFT", 4, 0)
    rank:SetWidth(30)
    rank:SetJustifyH("CENTER")
    row.rank = rank

    local icon = row:CreateTexture(nil, "ARTWORK")
    icon:SetSize(24, 24)
    icon:SetPoint("LEFT", row, "LEFT", 38, 0)
    row.icon = icon

    local name = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    name:SetPoint("TOPLEFT", icon, "TOPRIGHT", 8, 1)
    name:SetPoint("RIGHT", row, "RIGHT", -80, 0)
    name:SetJustifyH("LEFT")
    row.name = name

    local sub = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    sub:SetPoint("BOTTOMLEFT", icon, "BOTTOMRIGHT", 8, -1)
    sub:SetPoint("RIGHT", row, "RIGHT", -80, 0)
    sub:SetJustifyH("LEFT")
    row.sub = sub

    local skull = row:CreateTexture(nil, "ARTWORK")
    skull:SetSize(16, 16)
    skull:SetPoint("RIGHT", row, "RIGHT", -6, 0)
    skull:SetTexture(SKULL)
    row.skull = skull

    local count = Font(row, 18)
    count:SetPoint("RIGHT", skull, "LEFT", -6, 0)
    count:SetJustifyH("RIGHT")
    count:SetTextColor(1, 1, 1)
    row.count = count

    row:SetScript("OnEnter", function(self) UI.Tooltip(self) end)
    row:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return row
end

local function Build()
    state = ns.db.settings
    state.period = state.period or "week"
    state.view = state.view or "players"

    frame = CreateFrame("Frame", "OmenDeathsFrame", UIParent, "BackdropTemplate")
    frame:SetSize(460, 620)
    if state.point then
        frame:SetPoint(state.point[1], UIParent, state.point[2], state.point[3], state.point[4])
    else
        frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end
    frame:SetFrameStrata("DIALOG")
    frame:SetBackdrop({
        bgFile = "Interface\\FrameGeneral\\UI-Background-Rock",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 256, edgeSize = 32,
        insets = { left = 11, right = 11, top = 11, bottom = 11 },
    })
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local p, _, rp, x, y = self:GetPoint()
        state.point = { p, rp, x, y }
    end)
    frame:SetScript("OnShow", function() UI.Refresh() end)
    if UISpecialFrames then table.insert(UISpecialFrames, "OmenDeathsFrame") end

    -- darker inside so the text reads well on the rock
    local shade = frame:CreateTexture(nil, "BACKGROUND", nil, 1)
    shade:SetPoint("TOPLEFT", frame, "TOPLEFT", 11, -11)
    shade:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -11, 11)
    shade:SetTexture(WHITE)
    shade:SetVertexColor(0, 0, 0)
    shade:SetAlpha(0.45)

    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -6, -6)
    -- own click: the template's default close goes through Blizzard's panel manager,
    -- which on WoW Forever left this window open (only Escape worked, 08-11-2026)
    close:SetScript("OnClick", function() frame:Hide() end)
    frame.closeButton = close

    -- header
    local crest = frame:CreateTexture(nil, "ARTWORK")
    crest:SetSize(48, 48)
    crest:SetPoint("TOPLEFT", frame, "TOPLEFT", 22, -20)
    crest:SetTexture(BONE)

    local title = Font(frame, 30)
    title:SetPoint("TOPLEFT", crest, "TOPRIGHT", 12, 2)
    title:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
    title:SetText("Omen Deaths")

    local subtitle = Font(frame, 14)
    subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 2, -2)
    subtitle:SetTextColor(CRIMSON[1] + 0.15, CRIMSON[2] + 0.1, CRIMSON[3] + 0.1)
    subtitle:SetText("<Omen> Hall of the Fallen")

    local quip = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    quip:SetPoint("TOP", frame, "TOP", 0, -78)
    frame.quip = quip

    local rule = frame:CreateTexture(nil, "ARTWORK")
    rule:SetPoint("TOPLEFT", frame, "TOPLEFT", 22, -94)
    rule:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -22, -94)
    rule:SetHeight(1)
    rule:SetTexture(WHITE)
    rule:SetVertexColor(0.8, 0.62, 0.2)
    rule:SetAlpha(0.7)

    -- period tabs
    tabs = {}
    for i, period in ipairs(ns.Data.PERIODS) do
        local b = Button(frame, ns.Data.PERIOD_LABEL[period], 100)
        b:SetPoint("TOPLEFT", frame, "TOPLEFT", 22 + (i - 1) * 104, -104)
        b:SetScript("OnClick", function()
            state.period = period
            UI.offset = 0
            UI.Refresh()
        end)
        b.period = period
        tabs[i] = b
    end

    -- view and place
    viewButtons = {}
    -- 0.9.0: four views; 66 wide, 68 apart (Health only shows for whoever switched it on)
    for i, v in ipairs({ { "players", "The Fallen" }, { "killers", "Killers" }, { "repairs", "Repairs" }, { "health", "Health" } }) do
        local b = Button(frame, v[2], 66)
        b:SetPoint("TOPLEFT", frame, "TOPLEFT", 22 + (i - 1) * 68, -132)
        b:SetScript("OnClick", function()
            state.view = v[1]
            UI.offset = 0
            UI.Refresh()
        end)
        b.view = v[1]
        viewButtons[i] = b
    end
    local prev = Button(frame, "<", 24)
    prev:SetPoint("TOPLEFT", frame, "TOPLEFT", 252, -132)
    frame.prev = prev
    local nextB = Button(frame, ">", 24)
    nextB:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -22, -132)
    frame.nextB = nextB
    -- in the Repairs view the place means nothing: the auto repair switch stands there
    local repairB = Button(frame, "", 150)
    repairB:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -22, -132)
    repairB:SetScript("OnClick", function()
        state.autoRepair = not state.autoRepair
        UI.Refresh()
    end)
    repairB:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Auto repair")
        GameTooltip:AddLine("Repairs all your gear when you open a merchant who can repair.", 1, 1, 1)
        GameTooltip:AddLine("The guild pays when it lets you, else you do.", 0.8, 0.8, 0.8)
        GameTooltip:Show()
    end)
    repairB:SetScript("OnLeave", function() GameTooltip:Hide() end)
    repairB:Hide()
    frame.repairButton = repairB
    local place = Font(frame, 15)
    place:SetPoint("LEFT", prev, "RIGHT", 4, 0)
    place:SetPoint("RIGHT", nextB, "LEFT", -4, 0)
    place:SetJustifyH("CENTER")
    place:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
    frame.place = place
    prev:SetScript("OnClick", function() UI.StepScope(-1) end)
    nextB:SetScript("OnClick", function() UI.StepScope(1) end)

    -- list
    local list = CreateFrame("Frame", nil, frame)
    list:SetSize(412, ROWS * ROW_H)
    list:SetPoint("TOPLEFT", frame, "TOPLEFT", 24, -164)
    list:EnableMouseWheel(true)
    list:SetScript("OnMouseWheel", function(_, delta)
        UI.offset = math.max(0, (UI.offset or 0) - delta)
        UI.Refresh()
    end)
    rows = {}
    for i = 1, ROWS do rows[i] = BuildRow(list, i) end
    local empty = Font(list, 16)
    empty:SetPoint("CENTER", list, "CENTER", 0, 20)
    empty:SetTextColor(0.7, 0.7, 0.7)
    frame.empty = empty

    -- footer
    local rule2 = frame:CreateTexture(nil, "ARTWORK")
    rule2:SetPoint("TOPLEFT", list, "BOTTOMLEFT", -2, -6)
    rule2:SetPoint("TOPRIGHT", list, "BOTTOMRIGHT", 2, -6)
    rule2:SetHeight(1)
    rule2:SetTexture(WHITE)
    rule2:SetVertexColor(0.8, 0.62, 0.2)
    rule2:SetAlpha(0.7)

    local foot1 = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    foot1:SetPoint("TOPLEFT", rule2, "BOTTOMLEFT", 2, -8)
    foot1:SetPoint("RIGHT", frame, "RIGHT", -24, 0)
    foot1:SetJustifyH("LEFT")
    frame.foot1 = foot1
    local foot2 = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    foot2:SetPoint("TOPLEFT", foot1, "BOTTOMLEFT", 0, -6)
    foot2:SetJustifyH("LEFT")
    frame.foot2 = foot2

    -- three steps: On -> No BG -> Off -> On
    local guild = Button(frame, "", 128)
    guild:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -22, 18)
    guild:SetScript("OnClick", function()
        if not state.guildChat then
            state.guildChat, state.guildChatBG = true, true
        elseif state.guildChatBG then
            state.guildChatBG = false
        else
            state.guildChat = false
        end
        UI.Refresh()
    end)
    guild:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Guild chat")
        GameTooltip:AddLine("When you die, post a funny line in guild chat.", 1, 1, 1)
        GameTooltip:AddLine("Everyone in the guild sees it, also without the addon.", 0.8, 0.8, 0.8)
        GameTooltip:AddLine("No BG: not for deaths in battlegrounds and arenas.", 0.8, 0.8, 0.8)
        GameTooltip:Show()
    end)
    guild:SetScript("OnLeave", function() GameTooltip:Hide() end)
    frame.guildButton = guild
    local chat = Button(frame, "", 100)
    chat:SetPoint("RIGHT", guild, "LEFT", -4, 0)
    chat:SetScript("OnClick", function()
        state.chat = not state.chat
        UI.Refresh()
    end)
    frame.chatButton = chat
    local banner = Button(frame, "", 90)
    banner:SetPoint("RIGHT", chat, "LEFT", -4, 0)
    banner:SetScript("OnClick", function()
        state.toast = not state.toast
        UI.Refresh()
    end)
    frame.bannerButton = banner
    local sound = Button(frame, "", 80)
    sound:SetPoint("RIGHT", banner, "LEFT", -4, 0)
    sound:SetScript("OnClick", function()
        state.sound = not state.sound
        -- a sample, in my own gender
        if state.sound and ns.Toast then ns.Toast.Sound(ns.Call(UnitSex, "player") == 3 and "f" or "m") end
        UI.Refresh()
    end)
    sound:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Sound")
        GameTooltip:AddLine("The human death scream when a guildie dies. Only you hear it.", 1, 1, 1)
        GameTooltip:Show()
    end)
    sound:SetScript("OnLeave", function() GameTooltip:Hide() end)
    frame.soundButton = sound

    frame:Hide()
end

---------------------------------------------------------------------------
-- Filling
---------------------------------------------------------------------------
function UI.Scopes()
    local scopes = ns.Data.Scopes(ns.Book())
    local index = 1
    for i, s in ipairs(scopes) do
        if s.label == state.scope then index = i end
    end
    return scopes, index
end

function UI.StepScope(dir)
    local scopes, index = UI.Scopes()
    index = (index - 1 + dir) % #scopes + 1
    state.scope = scopes[index].label
    UI.offset = 0
    UI.Refresh()
end

local function PlayerTooltip(row)
    local d, now = row.data, ns.Now()
    GameTooltip:SetText(Colored(d.name, ns.ClassColor(d.class)))
    GameTooltip:AddLine(UI.Title(d.name, row.rankNumber), GOLD[1], GOLD[2], GOLD[3])
    GameTooltip:AddLine(" ")
    GameTooltip:AddDoubleLine("Deaths", d.count, 0.8, 0.8, 0.8, 1, 1, 1)
    if d.fromStats then
        GameTooltip:AddDoubleLine("  seen by Omen Deaths", d.tracked, 0.6, 0.6, 0.6, 0.8, 0.8, 0.8)
        GameTooltip:AddLine("  (All Time uses the game's own statistic, from day one)", 0.5, 0.5, 0.5)
    end
    if d.nemesis then
        GameTooltip:AddDoubleLine("Nemesis", d.nemesis .. " (" .. d.nemesisCount .. ")", 0.8, 0.8, 0.8, 1, 0.5, 0.5)
    end
    local last = d.last
    if last then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Last death, " .. UI.Ago(last.t, now), 0.8, 0.8, 0.8)
        local cause = ns.Data.Cause(last)
        if cause then GameTooltip:AddLine("  to " .. cause .. (last.k and last.s and (" (" .. last.s .. ")") or ""), 1, 1, 1) end
        if last.z then GameTooltip:AddLine("  in " .. last.z, 1, 1, 1) end
        if last.l then GameTooltip:AddLine("  at level " .. last.l, 1, 1, 1) end
    end
end

local function KillerTooltip(row)
    local d = row.data
    GameTooltip:SetText(d.name, CRIMSON[1] + 0.2, CRIMSON[2] + 0.2, CRIMSON[3] + 0.2)
    GameTooltip:AddDoubleLine("Kills", d.count, 0.8, 0.8, 0.8, 1, 1, 1)
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("Victims", GOLD[1], GOLD[2], GOLD[3])
    local victims = {}
    for name, n in pairs(d.victims) do victims[#victims + 1] = { name = name, n = n } end
    table.sort(victims, function(a, b)
        if a.n ~= b.n then return a.n > b.n end
        return a.name < b.name
    end)
    local book = ns.Book()
    for _, v in ipairs(victims) do
        local p = book.players[v.name]
        GameTooltip:AddDoubleLine(Colored(v.name, ns.ClassColor(p and p.class)), v.n, 1, 1, 1, 1, 1, 1)
    end
end

local function HealthTooltip(row)
    local d, h = row.data, row.data.h
    GameTooltip:AddLine(d.name, ns.ClassColor(d.class))
    GameTooltip:AddLine("Omen Deaths " .. tostring(h.v or "?") .. ", reported " .. UI.Ago(h.at, ns.Now()), 1, 1, 1)
    GameTooltip:AddLine("Deaths in the log: " .. (h.n or 0) .. ", without a cause: " .. (h.miss or 0), 0.85, 0.85, 0.85)
    if h.step then GameTooltip:AddLine("Latest one without a cause stopped at: " .. h.step, 0.85, 0.85, 0.85) end
    GameTooltip:AddLine("Errors in the addon: " .. (h.err or 0), 0.85, 0.85, 0.85)
    if h.text then GameTooltip:AddLine("Latest error: " .. h.text, 1, 0.5, 0.5, true) end
    if h.post then
        local text, bad = ns.Health.PostText(h.post)
        GameTooltip:AddLine("Guild chat, latest death: " .. text,
            bad and 1 or 0.85, bad and 0.6 or 0.85, bad and 0.2 or 0.85, true)
    end
end

function UI.Tooltip(row)
    if not row.data then return end
    GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
    if row.kind == "repairs" then
        local d = row.data
        GameTooltip:SetText(d.name, ns.ClassColor(d.class))
        GameTooltip:AddLine(("%s on %d %s"):format(ns.Repair.Money(d.count), d.n, d.n == 1 and "repair" or "repairs"), 1, 1, 1)
    elseif row.kind == "players" then
        PlayerTooltip(row)
    elseif row.kind == "health" then
        HealthTooltip(row)
    else
        KillerTooltip(row)
    end
    GameTooltip:Show()
end

local function TopVictims(victims)
    local list = {}
    for name, n in pairs(victims) do list[#list + 1] = { name = name, n = n } end
    table.sort(list, function(a, b)
        if a.n ~= b.n then return a.n > b.n end
        return a.name < b.name
    end)
    local names = {}
    for i = 1, math.min(3, #list) do names[i] = list[i].name end
    return table.concat(names, ", ") .. (#list > 3 and ", ..." or "")
end

function UI.Refresh()
    if not frame or not frame:IsShown() then return end
    local book, now = ns.Book(), ns.Now()
    local scopes, index = UI.Scopes()
    local scope = scopes[index]
    frame.place:SetText(scope.short or scope.label)
    for _, b in ipairs(tabs) do Select(b, b.period == state.period) end
    -- Health only for whoever switched it on (/omen health, saved for the whole account; 09-11-2026,
    -- wish of the user: "alleen voor mij"). The reports still arrive for everyone.
    local health = ns.db.settings.showHealth == true
    if state.view == "health" and not health then state.view = "players" end
    for _, b in ipairs(viewButtons) do
        if b.view == "health" then
            if health then b:Show() else b:Hide() end
        end
        Select(b, b.view == state.view)
    end
    local repairs = state.view == "repairs"
    frame.prev:ClearAllPoints()
    frame.prev:SetPoint("TOPLEFT", frame, "TOPLEFT", health and 298 or 252, -132)
    for _, w in ipairs({ frame.prev, frame.nextB, frame.place }) do
        if repairs then w:Hide() else w:Show() end
    end
    if repairs then frame.repairButton:Show() else frame.repairButton:Hide() end
    frame.repairButton:SetText("Auto repair: " .. (state.autoRepair and "On" or "Off"))

    local list
    if state.view == "health" then
        list = ns.Health.List(book)
    elseif state.view == "killers" then
        list = ns.Data.Killers(book, state.period, scope, now)
    elseif repairs then
        list = ns.Repair.Board(book, state.period, now)
    else
        list = ns.Data.Leaderboard(book, state.period, scope, now)
    end
    UI.list = list
    local maxOffset = math.max(0, #list - ROWS)
    UI.offset = math.min(UI.offset or 0, maxOffset)
    local top = list[1] and list[1].count or 1

    for i, row in ipairs(rows) do
        local n = i + UI.offset
        local d = list[n]
        row.data, row.kind, row.rankNumber = d, state.view, n
        if not d then
            row:Hide()
        else
            row:Show()
            local medal = MEDALS[n]
            row.rank:SetText(n)
            if medal then
                row.rank:SetTextColor(medal[1], medal[2], medal[3])
            else
                row.rank:SetTextColor(0.6, 0.6, 0.6)
            end
            row.count:SetText(repairs and ns.Repair.Coins(d.count) or d.count)
            -- the coins are in the number itself: no skull next to it
            if repairs then row.skull:Hide() else row.skull:Show() end
            row.bar:SetWidth(math.max(1, 412 * d.count / top))
            if repairs then
                row.icon:SetTexture(ns.ClassIcon(d.class))
                row.name:SetText(d.name)
                row.name:SetTextColor(ns.ClassColor(d.class))
                row.sub:SetText(("%d %s · %s"):format(d.n, d.n == 1 and "repair" or "repairs", ns.Repair.Money(d.count)))
            elseif state.view == "health" then
                row.icon:SetTexture(ns.ClassIcon(d.class))
                row.name:SetText(d.name)
                row.name:SetTextColor(ns.ClassColor(d.class))
                row.sub:SetText(ns.Health.Line(d.h) .. " · " .. UI.Ago(d.h.at, now))
            elseif state.view == "killers" then
                row.icon:SetTexture(d.name == ns.Data.UNKNOWN and QUESTION or d.name == ns.Data.BEFORE and BONE or SKULL)
                row.name:SetText(d.name)
                row.name:SetTextColor(1, 0.55, 0.55)
                row.sub:SetText("Victims: " .. TopVictims(d.victims))
            else
                row.icon:SetTexture(ns.ClassIcon(d.class))
                row.name:SetText(d.name)
                row.name:SetTextColor(ns.ClassColor(d.class))
                row.sub:SetText(UI.Title(d.name, n))
            end
        end
    end

    if #list == 0 then
        frame.empty:SetText(repairs and "No repair bills yet. Everyone's gear is shiny."
            or state.view == "health" and "No reports yet. Guildies need Omen Deaths 0.8.0 or newer."
            or state.view == "killers" and "Nothing has killed us here. Yet." or "Nobody died here. Suspicious.")
        frame.empty:Show()
    else
        frame.empty:Hide()
    end

    local total = ns.Data.Total(book, state.period, scope, now)
    local killers = ns.Data.Killers(book, state.period, scope, now)
    local deadliest = killers[1] and killers[1].name ~= ns.Data.UNKNOWN and killers[1]
    if repairs then
        local sum = 0
        for _, d in ipairs(list) do sum = sum + d.count end
        frame.foot1:SetText(("%s: %s on repairs"):format(ns.Data.PERIOD_LABEL[state.period], ns.Repair.Money(sum)))
    elseif state.view == "health" then
        local bad = 0
        for _, d in ipairs(list) do if d.count > 0 then bad = bad + 1 end end
        frame.foot1:SetText(("Health: %d %s reported, %d with problems"):format(#list, #list == 1 and "player" or "players", bad))
    else
        frame.foot1:SetText(("%s: %d %s%s"):format(ns.Data.PERIOD_LABEL[state.period], total, total == 1 and "death" or "deaths",
            deadliest and ("  ·  Deadliest foe: " .. deadliest.name .. " (" .. deadliest.count .. ")") or ""))
    end
    local me = ns.MyName()
    local mine = 0
    for _, d in ipairs(ns.Data.Leaderboard(book, state.period, scope, now)) do
        if d.name == me then mine = d.count end
    end
    local online = ns.Comm.OnlinePeers()
    if repairs then
        mine = 0
        for _, d in ipairs(list) do if d.name == me then mine = d.count end end
        mine = ns.Repair.Money(mine)
    end
    frame.foot2:SetText(("You: %s  ·  %d %s online with Omen Deaths"):format(mine, online, online == 1 and "guildie" or "guildies"))

    frame.guildButton:SetText("Guild chat: " .. (not state.guildChat and "Off" or state.guildChatBG and "On" or "No BG"))
    frame.chatButton:SetText("My chat: " .. (state.chat and "On" or "Off"))
    frame.bannerButton:SetText("Popup: " .. (state.toast and "On" or "Off"))
    frame.soundButton:SetText("Sound: " .. (state.sound and "On" or "Off"))
    -- an old version: the line under the title says so, in orange, until the addon is updated
    -- short, to fit the one line under the title
    local update = ns.Comm.newest and ("Update to " .. ns.Comm.newest .. " (you have " .. ns.VERSION .. "): CurseForge app or GitHub")
    if update then
        frame.quip:SetText(update)
        frame.quip:SetTextColor(1, 0.6, 0)
    elseif frame.quip.update then
        frame.quip:SetText(QUIPS[math.random(#QUIPS)])
        frame.quip:SetTextColor(0.5, 0.5, 0.5)
    end
    frame.quip.update = update
end

function UI.Show()
    if not ns.db then return end
    if not frame then Build() end
    frame.quip:SetText(QUIPS[math.random(#QUIPS)])
    frame:Show()
    UI.Refresh()
end

function UI.Toggle()
    if frame and frame:IsShown() then frame:Hide() else UI.Show() end
end

function UI.Frame() return frame end

-- /omen opens the window as well (the minimap button is the main way in).
SLASH_OMENDEATHS1 = "/omen"
SLASH_OMENDEATHS2 = "/omendeaths"
-- /omen health shows or hides the Health tab (for this whole account).
function UI.Slash(msg)
    msg = type(msg) == "string" and msg:lower():match("^%s*(.-)%s*$") or ""
    if msg == "repair" then
        if not ns.db then return end
        ns.db.settings.autoRepair = not ns.db.settings.autoRepair
        ns.Print("Auto repair " .. (ns.db.settings.autoRepair and "on" or "off") .. ".")
        UI.Refresh()
        return
    end
    if msg == "health" then
        if not ns.db then return end
        ns.db.settings.showHealth = not ns.db.settings.showHealth
        ns.Print("Health tab " .. (ns.db.settings.showHealth and "on" or "off") .. ".")
        UI.Refresh()
        return
    end
    UI.Toggle()
end
SlashCmdList.OMENDEATHS = function(msg) UI.Slash(msg) end
