-- Omen Deaths: the new window (0.9.8), the game's own window and side tabs with the graves inside.
-- The default since 0.9.8; /omen newui switches to the old window (UI.lua) and back.
-- A new feature = one entry in NewUI.TABS plus a case in NewUI.Page.
local _, ns = ...
local NewUI = {}
ns.NewUI = NewUI

-- The height of the old window, which is known to fit: a design of 780 would not fit a UI of 768 high.
NewUI.W, NewUI.H = 560, 620
NewUI.ROWS, NewUI.ROW_H = 8, 34
NewUI.GRASS_H = 20
NewUI.TAB_SIZE, NewUI.TAB_GAP, NewUI.TAB_ICON = 40, 3, 50 -- as the game's side tab: 50 = the icon fills it
-- 0.9.11: the tabs ran past the bottom of the window (user, 25-11-2026). The whole tab, art and
-- icon, is scaled; 0.8 keeps 10 tabs in the window with room to spare.
NewUI.TAB_SCALE = 0.8
-- the challenge button in a Duels row (0.9.12): 22 = the height of the game's small buttons on this
-- window (Btn 22), at 395 as in the preview the user approved; the note gets 150 there instead of 196
NewUI.CHALLENGE, NewUI.CHALLENGE_X, NewUI.NOTE_SHORT = 22, 395, 150

local WHITE = "Interface\\Buttons\\WHITE8X8"
local LOGO = "Interface\\AddOns\\OmenDeaths\\OmenLogo"
local GRAVE = "Interface\\AddOns\\OmenDeaths\\Gravestone"
local GRASS = "Interface\\AddOns\\OmenDeaths\\GraveGrass"
local QUESTION = "Interface\\Icons\\INV_Misc_QuestionMark"

local function C(hex)
    return { tonumber(hex:sub(1, 2), 16) / 255, tonumber(hex:sub(3, 4), 16) / 255, tonumber(hex:sub(5, 6), 16) / 255 }
end
local COL = {
    window = C("0f1513"), panel = C("141b18"), ground = C("121916"), field = C("1b2320"), frame = C("7b857f"),
    line = C("5a4a32"), soft = C("2c2822"), bone = C("f2f2f2"), bright = C("ffd200"), muted = C("b8b8b8"),
    dark = C("101512"), crimson = C("c41e3a"), stone = C("8a6a3a"), orange = C("ff9900"),
}

-- the cross before a fallen name in the Hall of Fame (0.9.12): the dagger sign of the game's own font
NewUI.CROSS = "|cfff2f2f2\226\128\160|r"
-- online / offline in the Duels list (0.9.12): the game's own status dots of the Friends list
NewUI.ONLINE = "|TInterface\\FriendsFrame\\StatusIcon-Online:12|t Online"
NewUI.OFFLINE = "|TInterface\\FriendsFrame\\StatusIcon-Offline:12|t Offline"

NewUI.TABS = {
    { id = "board", label = "Leaderboard", icon = "Interface\\Icons\\INV_Misc_Bone_HumanSkull_01", periods = true, scope = true },
    { id = "killers", label = "Killers", icon = "Interface\\Icons\\Spell_Shadow_DeathCoil", periods = true, scope = true },
    -- beta = only with /omen beta (25-11-2026, the user's choice: not finished yet)
    -- Duels out of beta with the ranking (0.9.12, the user, 26-11-2026)
    { id = "duels", label = "Duels", icon = "Interface\\Icons\\Ability_DualWield" },
    { id = "repairs", label = "Repairs", icon = "Interface\\Icons\\Trade_BlackSmithing", periods = true },
    { id = "awards", label = "Awards", icon = "Interface\\Icons\\INV_Crown_01" },
    -- Hall of Fame (0.9.11, wish of the user): everyone who never died, highest level on top
    { id = "deathless", label = "Hall of Fame", icon = "Interface\\Icons\\Spell_Holy_Resurrection" },
    { id = "raids", label = "Raids", icon = "Interface\\Icons\\INV_Misc_Map_01", beta = true },
    { id = "raidadmin", label = "Raid Admin", icon = "Interface\\Icons\\INV_Misc_Key_03", owner = true, beta = true },
    { id = "health", label = "Health", icon = QUESTION, hidden = true },
    { id = "custom", label = "Custom Messages", icon = "Interface\\Icons\\INV_Letter_15", beta = true },
    { id = "settings", label = "Settings", icon = "Interface\\Icons\\INV_Misc_Gear_01" },
}

NewUI.SETTINGS = {
    { key = "guildChat", label = "Guild chat", help = "Post a funny line when you die (never from battlegrounds)" },
    { key = "toast", label = "Popup", help = "Show the banner when a guildie dies" },
    { key = "chat", label = "My chat", help = "Show deaths in your own chat window" },
    { key = "sound", label = "Sound", help = "The death scream when a guildie dies. Only you hear it" },
    { key = "autoRepair", label = "Auto repair", help = "Repair your gear when you open a merchant" },
    { key = "guildRepair", label = "Guild repairs", help = "Auto repair pays from the guild bank when it lets you. Off: you pay" },
}

local QUIPS = {
    "Here lie the finest of the guild. Repeatedly.",
    "Death is temporary. Shame is forever.",
    "Proudly sponsored by the Spirit Healer.",
    "Every wipe tells a story.",
    "Repair bills are a lifestyle.",
    "Stand in the fire, climb the board.",
    "Keep calm and release spirit.",
}
local MARKS = { "R.I.P. I", "R.I.P. II", "R.I.P. III" }
-- Slot from the left: #2, #1, #3. Height, number size and stone colour per rank.
local TOMB = {
    { x = 200, h = 190, font = "GameFontNormalHuge", medal = { 1, 0.82, 0 }, icon = 44 },
    { x = 38, h = 170, font = "GameFontNormalLarge", medal = { 0.78, 0.8, 0.88 }, icon = 38 },
    { x = 362, h = 156, font = "GameFontNormalLarge", medal = { 0.82, 0.5, 0.25 }, icon = 34 },
}
local TOMB_W = 150

local frame, state

-- The only one who sees Raid Admin and later chooses the raid admins (24-11-2026, the user's choice).
NewUI.OWNER = "Kwatta Koning"
function NewUI.Visible(def)
    if def.id == "health" then return ns.db.settings.showHealth == true end
    if def.beta and ns.db.settings.beta ~= true then return false end
    if def.owner then return ns.MyName() == NewUI.OWNER end
    return true
end

---------------------------------------------------------------------------
-- Small parts
---------------------------------------------------------------------------
local function Paint(fs, c) fs:SetTextColor(c[1], c[2], c[3]) end

local function Label(parent, fontObject, c)
    local fs = parent:CreateFontString(nil, "OVERLAY", fontObject)
    if c then Paint(fs, c) end
    return fs
end

local function Rect(parent, layer, c)
    local t = parent:CreateTexture(nil, layer or "BACKGROUND")
    t:SetTexture(WHITE)
    t:SetVertexColor(c[1], c[2], c[3])
    return t
end

-- The game's own red button; the chosen one stays lit, with gold text.
local function Btn(parent, w, h, text)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(w, h)
    b:SetText(text or "")
    local fs = b:GetFontString()
    if fs then
        fs:SetWidth(w - 14)
        fs:SetWordWrap(false)
    end
    return b
end

local function Select(b, on)
    if on then b:LockHighlight() else b:UnlockHighlight() end
    local fs = b:GetFontString()
    if fs then Paint(fs, on and COL.bright or COL.bone) end
end

-- An icon the client does not have shows as a green square: then the question mark.
function NewUI.Icon(path)
    if type(GetFileIDFromPath) == "function" and ns.Call(GetFileIDFromPath, path) == nil then return QUESTION end
    return path
end

local function Tip(self)
    if self.data and self.kind then ns.UI.Tooltip(self) end
end
local function NoTip() GameTooltip:Hide() end

---------------------------------------------------------------------------
-- Building
---------------------------------------------------------------------------
-- The game's own side tab (the Professions window): its frame, grid and bevelled corners.
local function BuildTab(def)
    local b = CreateFrame("Frame", nil, frame, "LargeSideTabButtonTemplate")
    b:SetScale(NewUI.TAB_SCALE)
    b.def = def
    b:EnableMouse(true)
    b.Icon:SetTexture(NewUI.Icon(def.icon))
    if b.SetFillToInterior then
        b:SetFillToInterior(true, NewUI.TAB_ICON)
    else
        b.Icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    end
    b.tooltipText = def.label
    b:SetCustomOnMouseUpHandler(function(_, button, upInside)
        if button == "LeftButton" and upInside ~= false then NewUI.Select(def.id) end
    end)
    return b
end

-- A real gravestone (drawn for this addon, 256x512): weathered stone, a carved line, cracks and moss.
-- A shorter grave shows the same stone with its foot in the ground, so the round top never stretches.
local function NewGrave(parent, w, h)
    local t = CreateFrame("Frame", nil, parent)
    t:SetSize(w, h)
    t.art = t:CreateTexture(nil, "BACKGROUND")
    t.art:SetAllPoints(t)
    t.art:SetTexture(GRAVE)
    t.art:SetTexCoord(0, 1, 0, h / (2 * w))
    return t
end

-- Grass in front of the foot of the stones: on its own layer above them, it takes no clicks.
local function Grass(parent, level, w)
    local g = CreateFrame("Frame", nil, parent)
    g:SetSize(w, NewUI.GRASS_H)
    g:SetFrameLevel(level + 6)
    local tex = g:CreateTexture(nil, "ARTWORK")
    tex:SetAllPoints(g)
    tex:SetTexture(GRASS)
    g.tex = tex
    return g
end

local function BuildTomb(parent, i)
    local spec = TOMB[i]
    local t = NewGrave(parent, TOMB_W, spec.h)
    t:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", spec.x, 3)
    t:EnableMouse(true)

    t.note = Label(t, "GameFontHighlightSmall", COL.muted)
    t.note:SetPoint("BOTTOM", t, "BOTTOM", 0, NewUI.GRASS_H)
    t.note:SetWidth(TOMB_W - 34)
    t.note:SetJustifyH("CENTER")
    t.note:SetMaxLines(2) -- the rest of the stone is stacked on this line
    t.note:SetMaxLines(2) -- the rest of the stone is stacked on this line
    t.value = Label(t, spec.font, COL.bright)
    t.value:SetPoint("BOTTOM", t.note, "TOP", 0, 3)
    t.name = Label(t, "GameFontHighlight")
    t.name:SetPoint("BOTTOM", t.value, "TOP", 0, 2)
    t.name:SetWidth(TOMB_W - 30)
    t.name:SetWordWrap(false)
    t.name:SetJustifyH("CENTER")
    t.icon = t:CreateTexture(nil, "ARTWORK")
    t.icon:SetSize(spec.icon, spec.icon)
    t.icon:SetPoint("BOTTOM", t.name, "TOP", 0, 4)
    t.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    t.mark = Label(t, "GameFontNormalSmall", spec.medal)
    t.mark:SetPoint("BOTTOM", t.icon, "TOP", 0, 3)
    -- the Omen belt beside the champion's icon (Duels, 0.9.12)
    t.belt = t:CreateTexture(nil, "ARTWORK")
    t.belt:SetSize(20, 20)
    t.belt:SetPoint("BOTTOMLEFT", t.icon, "BOTTOMRIGHT", 4, 0)
    t.belt:SetTexture(NewUI.Icon("Interface\\Icons\\INV_Belt_13"))
    t.belt:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    t.belt:Hide()
    t:SetScript("OnEnter", Tip)
    t:SetScript("OnLeave", NoTip)
    return t
end

local function BuildRow(parent, i)
    local r = CreateFrame("Frame", nil, parent)
    r:SetSize(516, NewUI.ROW_H)
    r:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -(i - 1) * NewUI.ROW_H)
    r:EnableMouse(true)
    local rule = Rect(r, "BORDER", COL.soft)
    rule:SetPoint("BOTTOMLEFT", r, "BOTTOMLEFT", 0, 0)
    rule:SetPoint("BOTTOMRIGHT", r, "BOTTOMRIGHT", 0, 0)
    rule:SetHeight(1)
    r.rank = Label(r, "GameFontNormal")
    r.rank:SetPoint("LEFT", r, "LEFT", 0, 0)
    r.rank:SetWidth(38)
    r.rank:SetJustifyH("LEFT")
    r.name = Label(r, "GameFontHighlight")
    r.name:SetPoint("LEFT", r, "LEFT", 38, 0)
    r.name:SetWidth(186)
    r.name:SetWordWrap(false)
    r.name:SetJustifyH("LEFT")
    r.note = Label(r, "GameFontHighlightSmall", COL.muted)
    r.note:SetPoint("LEFT", r, "LEFT", 230, 0)
    r.note:SetWidth(196)
    r.note:SetWordWrap(false)
    r.note:SetJustifyH("LEFT")
    r.value = Label(r, "GameFontHighlight")
    r.value:SetPoint("RIGHT", r, "RIGHT", 0, 0)
    r.value:SetJustifyH("RIGHT")
    -- Duels (0.9.12): whisper a challenge; between the note and the score, the note made shorter
    local b = CreateFrame("Button", nil, r)
    b:SetSize(NewUI.CHALLENGE, NewUI.CHALLENGE)
    b:SetPoint("LEFT", r, "LEFT", NewUI.CHALLENGE_X, 0)
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetAllPoints(b)
    b.icon:SetTexture(NewUI.Icon("Interface\\Icons\\Ability_DualWield"))
    b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    b:SetScript("OnClick", function(self)
        if self.target and self.online then ns.Duels.Challenge(self.target, self.rank, self.mine) end
    end)
    b:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(self.online and ("Challenge " .. self.target) or (self.target .. " is offline"))
        if self.online then GameTooltip:AddLine("Opens a whisper. Press Enter to send it.", 1, 1, 1) end
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", NoTip)
    b:Hide()
    r.challenge = b
    r:SetScript("OnEnter", Tip)
    r:SetScript("OnLeave", NoTip)
    return r
end

local function BuildSettings()
    local page = CreateFrame("Frame", nil, frame.content)
    page:SetPoint("TOPLEFT", frame, "TOPLEFT", 22, -98)
    page:SetSize(NewUI.W - 44, 480)
    frame.settingRows = {}
    for i, s in ipairs(NewUI.SETTINGS) do
        local y = -(i - 1) * 74
        local b = CreateFrame("CheckButton", nil, page, "UICheckButtonTemplate")
        b:SetSize(28, 28)
        b:SetPoint("TOPLEFT", page, "TOPLEFT", 0, y - 16)
        b.key = s.key
        b:SetScript("OnClick", function()
            state[s.key] = not state[s.key]
            -- a sample, in my own gender
            if s.key == "sound" and state.sound and ns.Toast then
                ns.Toast.Sound(ns.Call(UnitSex, "player") == 3 and "f" or "m")
            end
            NewUI.Refresh()
        end)
        local label = Label(page, "GameFontNormal")
        label:SetPoint("TOPLEFT", page, "TOPLEFT", 38, y - 14)
        label:SetText(s.label)
        local help = Label(page, "GameFontHighlightSmall", COL.muted)
        help:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -5)
        help:SetWidth(460)
        help:SetJustifyH("LEFT")
        help:SetText(s.help)
        local rule = Rect(page, "BORDER", COL.soft)
        rule:SetPoint("TOPLEFT", page, "TOPLEFT", 0, y - 73)
        rule:SetPoint("TOPRIGHT", page, "TOPRIGHT", 0, y - 73)
        rule:SetHeight(1)
        frame.settingRows[i] = b
    end
    local back = Label(page, "GameFontDisableSmall")
    back:SetPoint("BOTTOMLEFT", page, "BOTTOMLEFT", 0, 8)
    back:SetText("Back to the old window: /omen newui")
    return page
end

-- Awards (0.9.8, redesign: the user could not tell what the tab meant). Three different prizes on
-- stones of one height, so it does not read as a top 3; the prize is the headline, the score has
-- its unit and one line says what it is for. Below it: who is on course this week.
NewUI.AWARDS = {
    { who = "top", n = "topN", title = "Death of the Week", unit = "death", help = "Died the most" },
    { who = "faller", n = "fallN", title = "Floor Inspector", unit = "fall", help = "Fell the most" },
    { who = "foe", n = "foeN", title = "Deadliest Foe", unit = "kill", help = "Killed the most of us", foe = true },
}
local AWARD_W, AWARD_H, AWARD_GAP = 164, 256, 12 -- three across the 516 of the list: (516 - 2 x 12) / 3

local function BuildAwards()
    local page = CreateFrame("Frame", nil, frame.content)
    page:SetPoint("TOPLEFT", frame, "TOPLEFT", 17, -70)
    page:SetSize(516, 510)
    local a = { stones = {}, rows = {} }
    a.lastHead = Label(page, "GameFontNormalLarge")
    a.lastHead:SetPoint("TOPLEFT", page, "TOPLEFT", 0, 0)
    a.lastHead:SetText("Last Week's Winners")
    a.range = Label(page, "GameFontHighlightSmall", COL.muted)
    a.range:SetPoint("TOPRIGHT", page, "TOPRIGHT", 0, -2)
    for i, def in ipairs(NewUI.AWARDS) do
        local t = NewGrave(page, AWARD_W, AWARD_H)
        t:SetPoint("TOPLEFT", page, "TOPLEFT", (i - 1) * (AWARD_W + AWARD_GAP), -26)
        t.title = Label(t, "GameFontNormalLarge")
        t.title:SetPoint("TOP", t, "TOP", 0, -48)
        t.title:SetWidth(AWARD_W - 50)
        t.title:SetJustifyH("CENTER")
        t.title:SetText(def.title)
        t.name = Label(t, "GameFontHighlight")
        t.name:SetPoint("TOP", t, "TOP", 0, -122)
        t.name:SetWidth(AWARD_W - 34)
        t.name:SetWordWrap(false)
        t.name:SetJustifyH("CENTER")
        t.score = Label(t, "GameFontNormalLarge", COL.bone)
        t.score:SetPoint("TOP", t.name, "BOTTOM", 0, -8)
        t.help = Label(t, "GameFontHighlightSmall", COL.muted)
        t.help:SetPoint("BOTTOM", t, "BOTTOM", 0, NewUI.GRASS_H + 8)
        t.help:SetWidth(AWARD_W - 40)
        t.help:SetJustifyH("CENTER")
        t.help:SetText(def.help)
        a.stones[i] = t
    end
    a.grass = Grass(page, page:GetFrameLevel() + 1, 516)
    a.grass:SetPoint("TOPLEFT", page, "TOPLEFT", 0, -26 - AWARD_H + NewUI.GRASS_H - 3)
    a.empty = Label(page, "GameFontNormalLarge", COL.muted)
    a.empty:SetPoint("TOP", page, "TOP", 0, -110)
    a.empty:SetWidth(440)
    a.empty:SetJustifyH("CENTER")
    a.nowHead = Label(page, "GameFontNormalLarge")
    a.nowHead:SetPoint("TOPLEFT", page, "TOPLEFT", 0, -298)
    a.nowHead:SetText("This Week So Far")
    a.left = Label(page, "GameFontHighlightSmall", COL.muted)
    a.left:SetPoint("TOPRIGHT", page, "TOPRIGHT", 0, -300)
    local rule = Rect(page, "BORDER", COL.line)
    rule:SetPoint("TOPLEFT", page, "TOPLEFT", 0, -320)
    rule:SetPoint("TOPRIGHT", page, "TOPRIGHT", 0, -320)
    rule:SetHeight(1)
    for i, def in ipairs(NewUI.AWARDS) do
        local r = CreateFrame("Frame", nil, page)
        r:SetSize(516, 40)
        r:SetPoint("TOPLEFT", page, "TOPLEFT", 0, -322 - (i - 1) * 40)
        local line = Rect(r, "BORDER", COL.soft)
        line:SetPoint("BOTTOMLEFT", r, "BOTTOMLEFT", 0, 0)
        line:SetPoint("BOTTOMRIGHT", r, "BOTTOMRIGHT", 0, 0)
        line:SetHeight(1)
        r.title = Label(r, "GameFontNormal")
        r.title:SetPoint("LEFT", r, "LEFT", 0, 0)
        r.title:SetWidth(180)
        r.title:SetJustifyH("LEFT")
        r.title:SetText(def.title)
        r.name = Label(r, "GameFontHighlight")
        r.name:SetPoint("LEFT", r, "LEFT", 186, 0)
        r.name:SetWidth(210)
        r.name:SetWordWrap(false)
        r.name:SetJustifyH("LEFT")
        r.score = Label(r, "GameFontHighlight")
        r.score:SetPoint("RIGHT", r, "RIGHT", 0, 0)
        r.score:SetJustifyH("RIGHT")
        a.rows[i] = r
    end
    frame.awards = a
    return page
end

local function Build()
    state = ns.db.settings
    state.period = state.period or "week"
    state.newTab = state.newTab or "board"

    -- The game's own window (as the Friends window): frame art, title bar, close button, portrait.
    frame = CreateFrame("Frame", "OmenDeathsNewFrame", UIParent, "ButtonFrameTemplate")
    frame:SetSize(NewUI.W, NewUI.H)
    if state.newPoint then
        frame:SetPoint(state.newPoint[1], UIParent, state.newPoint[2], state.newPoint[3], state.newPoint[4])
    else
        frame:SetPoint("CENTER", UIParent, "CENTER", -NewUI.TAB_SIZE / 2, 0)
    end
    frame:SetFrameStrata("DIALOG")
    frame:SetToplevel(true)
    frame:SetTitle("Omen Deaths")
    if frame.TitleContainer then
        frame.TitleContainer:ClearAllPoints()
        frame.TitleContainer:SetPoint("TOPLEFT", frame, "TOPLEFT", 24, -1)
        frame.TitleContainer:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -24, -1)
    end
    frame:SetPortraitToAsset(LOGO)
    -- the template's default spot is not centred in Forever's copper ring
    if frame.SetPortraitTextureSizeAndOffset then frame:SetPortraitTextureSizeAndOffset(62, -6, 9) end
    -- the dark inner panel; the strip below it holds the footer
    if frame.Inset then
        frame.Inset:ClearAllPoints()
        frame.Inset:SetPoint("TOPLEFT", frame, "TOPLEFT", 4, -60)
        frame.Inset:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -6, 26)
    end
    -- a plain Hide: the template's way goes through the panel manager, which left this kind of
    -- window open on Forever (08-11-2026) and may not run in combat
    frame.onCloseCallback = function() frame:Hide() return false end
    if frame.CloseButton then frame.CloseButton:SetScript("OnClick", function() frame:Hide() end) end
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    -- the tabs stand outside the frame: they stay on screen too
    frame:SetClampRectInsets(0, NewUI.TAB_SIZE, 0, 0)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local p, _, rp, x, y = self:GetPoint()
        state.newPoint = { p, rp, x, y }
    end)
    frame:HookScript("OnShow", function(self)
        self:Raise()
        NewUI.Refresh()
    end)
    if UISpecialFrames then table.insert(UISpecialFrames, "OmenDeathsNewFrame") end

    -- everything inside the dark panel lives on a layer above it: the panel is a child frame of the
    -- window and would cover text and buttons placed on the window itself
    local content = CreateFrame("Frame", nil, frame)
    content:SetAllPoints(frame)
    content:SetFrameLevel((frame.Inset and frame.Inset:GetFrameLevel() or frame:GetFrameLevel()) + 1)
    frame.content = content

    frame.quip = Label(frame, "GameFontHighlightSmall", COL.muted)
    frame.quip:SetPoint("TOPLEFT", frame, "TOPLEFT", 70, -38)
    frame.quip:SetPoint("RIGHT", frame, "RIGHT", -16, 0)
    frame.quip:SetJustifyH("LEFT")
    frame.quip:SetWordWrap(false)

    -- filters
    frame.periodButtons = {}
    for i, period in ipairs(ns.Data.PERIODS) do
        local b = Btn(content, 84, 22, ns.Data.PERIOD_LABEL[period])
        b:SetPoint("TOPLEFT", frame, "TOPLEFT", 14 + (i - 1) * 87, -68)
        b.period = period
        b:SetScript("OnClick", function()
            state.period = period
            NewUI.offset = 0
            NewUI.Refresh()
        end)
        frame.periodButtons[i] = b
    end
    local scope = Btn(content, 150, 22, "")
    scope:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -16, -68)
    scope:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    scope:SetScript("OnClick", function(_, button) NewUI.StepScope(button == "RightButton" and -1 or 1) end)
    scope:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Place")
        GameTooltip:AddLine("Click: next. Right-click: previous.", 1, 1, 1)
        GameTooltip:Show()
    end)
    scope:HookScript("OnLeave", NoTip)
    frame.scopeButton = scope
    frame.filterNote = Label(content, "GameFontNormal")
    frame.filterNote:SetPoint("TOPLEFT", frame, "TOPLEFT", 18, -73)

    -- the board: the top 3 cards, then the list
    local board = CreateFrame("Frame", nil, content)
    board:SetPoint("TOPLEFT", frame, "TOPLEFT", 4, -94)
    board:SetSize(NewUI.W - 10, 490)
    board:EnableMouseWheel(true)
    board:SetScript("OnMouseWheel", function(_, delta)
        NewUI.offset = math.max(0, (NewUI.offset or 0) - delta)
        NewUI.Refresh()
    end)
    frame.board = board
    local podium = CreateFrame("Frame", nil, board)
    podium:SetPoint("TOPLEFT", board, "TOPLEFT", 0, 0)
    podium:SetSize(NewUI.W - 10, 196)
    frame.tombs = {}
    for i = 1, 3 do frame.tombs[i] = BuildTomb(podium, i) end
    frame.grass = Grass(podium, podium:GetFrameLevel() + 1, NewUI.W - 10)
    frame.grass:SetPoint("BOTTOMLEFT", podium, "BOTTOMLEFT", 0, 0)
    local list = CreateFrame("Frame", nil, board)
    list:SetPoint("TOPLEFT", podium, "BOTTOMLEFT", 17, -4)
    list:SetSize(516, NewUI.ROWS * NewUI.ROW_H)
    frame.rows = {}
    for i = 1, NewUI.ROWS do frame.rows[i] = BuildRow(list, i) end
    frame.podium = podium

    frame.message = Label(content, "GameFontNormalLarge", COL.muted)
    frame.message:SetPoint("CENTER", frame, "CENTER", 0, 20)
    frame.message:SetWidth(NewUI.W - 80)
    frame.message:SetJustifyH("CENTER")

    -- a tab that is still being built
    local building = CreateFrame("Frame", nil, content)
    building:SetSize(440, 230)
    building:SetPoint("CENTER", frame, "CENTER", 0, 20)
    building.icon = building:CreateTexture(nil, "ARTWORK")
    building.icon:SetSize(64, 64)
    building.icon:SetPoint("TOP", building, "TOP", 0, 0)
    building.icon:SetTexture(NewUI.Icon("Interface\\Icons\\Trade_Engineering"))
    building.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    building.title = Label(building, "GameFontNormalHuge")
    building.title:SetPoint("TOP", building.icon, "BOTTOM", 0, -16)
    building.title:SetText("Under Construction")
    building.text = Label(building, "GameFontHighlight", COL.muted)
    building.text:SetPoint("TOP", building.title, "BOTTOM", 0, -14)
    building.text:SetWidth(420)
    building.text:SetJustifyH("CENTER")
    frame.building = building

    frame.settingsPage = BuildSettings()
    frame.awardsPage = BuildAwards()

    -- footer, in the strip of the game's window
    frame.footLeft = Label(frame, "GameFontHighlightSmall", COL.muted)
    frame.footLeft:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 14, 9)
    frame.footLeft:SetWidth(300)
    frame.footLeft:SetWordWrap(false)
    frame.footLeft:SetJustifyH("LEFT")
    frame.footRight = Label(frame, "GameFontHighlightSmall", COL.muted)
    frame.footRight:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -14, 9)
    frame.footRight:SetJustifyH("RIGHT")

    -- tabs, outside the right edge
    frame.tabButtons = {}
    for i, def in ipairs(NewUI.TABS) do frame.tabButtons[i] = BuildTab(def) end
    frame:Hide()
end

---------------------------------------------------------------------------
-- What a tab shows
---------------------------------------------------------------------------
function NewUI.Scopes()
    local scopes = ns.Data.Scopes(ns.Book())
    local index = 1
    for i, s in ipairs(scopes) do
        if s.label == state.scope then index = i end
    end
    return scopes, index
end

function NewUI.StepScope(dir)
    local scopes, index = NewUI.Scopes()
    index = (index - 1 + dir) % #scopes + 1
    state.scope = scopes[index].label
    NewUI.offset = 0
    NewUI.Refresh()
end

local function ClassItem(d, value, note, kind, n)
    local r, g, b = ns.ClassColor(d.class)
    return { name = d.name, color = { r, g, b }, value = value, note = note, data = d, kind = kind, rank = n,
        icon = ns.ClassIcon(d.class) }
end

local function Mine(list, me)
    for _, d in ipairs(list) do
        if d.name == me then return d.count end
    end
    return 0
end

local function Online()
    local n = ns.Comm.OnlinePeers()
    return n .. (n == 1 and " guildie" or " guildies") .. " online"
end

-- The three prizes of one week: { name, color, score ("14 deaths") }; name nil when nobody won it.
local function AwardList(book, a)
    local out = {}
    for i, def in ipairs(NewUI.AWARDS) do
        local who, n = a[def.who], a[def.n]
        if who then
            local p = not def.foe and book.players[who]
            local r, g, b = ns.ClassColor(p and p.class)
            out[i] = { name = who, color = def.foe and COL.bone or { r, g, b },
                score = n .. " " .. def.unit .. (n == 1 and "" or "s") }
        else
            out[i] = {}
        end
    end
    return out
end

-- "3d 4h", "4h 12m", "12m": how long until the next reset.
function NewUI.Left(seconds)
    local s = math.max(0, math.floor(seconds))
    local d, h, m = math.floor(s / 86400), math.floor(s % 86400 / 3600), math.floor(s % 3600 / 60)
    if d > 0 then return d .. "d " .. h .. "h" end
    if h > 0 then return h .. "h " .. m .. "m" end
    return math.max(1, m) .. "m"
end

local function Day(t) return tonumber(date("%d", t)) .. " " .. date("%b", t) end

-- Killers that are no NPC, each with a fitting icon: a feather for the fall, the grinning lava spawn,
-- bubbles for drowning, tired eyes for fatigue.
NewUI.CAUSE_ICONS = {
    Falling = "Interface\\Icons\\Spell_Magic_FeatherFall",
    Lava = "Interface\\Icons\\Spell_Fire_LavaSpawn",
    Fire = "Interface\\Icons\\Spell_Fire_Fire",
    Drowning = "Interface\\Icons\\Spell_Shadow_DemonBreath",
    Fatigue = "Interface\\Icons\\Spell_Nature_Sleep",
    Slime = "Interface\\Icons\\INV_Misc_Slime_01",
}

-- The icon of a killer; an NPC with a known number gets its portrait over this (SetIcon).
function NewUI.KillerIcon(d)
    if d.name == ns.Data.UNKNOWN then return QUESTION end
    if d.name == ns.Data.BEFORE then return "Interface\\Icons\\INV_Misc_Bone_HumanSkull_01" end
    if NewUI.CAUSE_ICONS[d.name] then return NewUI.CAUSE_ICONS[d.name] end
    if d.kc == "PLAYER" then return "Interface\\Icons\\Ability_DualWield" end
    if d.kc then return ns.ClassIcon(d.kc) end
    return "Interface\\Icons\\Spell_Shadow_DeathCoil"
end

-- One page: { items (ranked, 1 to 3 go on the graves), message, left, right }.
function NewUI.Page(id, book, now)
    local period = ns.Data.PERIOD_LABEL[state.period]
    local me = ns.MyName()
    local page = { items = {}, right = Online() }
    if id == "board" or id == "killers" then
        local scopes, index = NewUI.Scopes()
        local scope = scopes[index]
        local board = ns.Data.Leaderboard(book, state.period, scope, now)
        local killers = ns.Data.Killers(book, state.period, scope, now)
        local total = ns.Data.Total(book, state.period, scope, now)
        local list = id == "board" and board or killers
        ns.UI.list = list
        for n, d in ipairs(list) do
            if id == "board" then
                page.items[n] = ClassItem(d, d.count, ns.UI.Title(n, #list), "players", n)
            else
                -- R.I.P. only fits the fallen (user, 22-11-2026)
                page.items[n] = { name = d.name, color = COL.bone, value = d.count, note = "Victims: " .. ns.UI.TopVictims(d.victims),
                    data = d, kind = "killers", rank = n, mark = "Most Wanted #" .. n,
                    icon = NewUI.KillerIcon(d), npc = d.ni }
            end
        end
        page.message = #list == 0 and (id == "board" and "Nobody died here. Suspicious." or "Nothing has killed us here. Yet.") or nil
        local top = killers[1] and killers[1].name ~= ns.Data.UNKNOWN and killers[1]
        page.left = ("%s: %d %s%s"):format(period, total, total == 1 and "death" or "deaths",
            top and ("  ·  Deadliest foe: " .. top.name .. " (" .. top.count .. ")") or "")
        page.right = "You: " .. Mine(board, me) .. "  ·  " .. page.right
    elseif id == "repairs" then
        local list = ns.Repair.Board(book, state.period, now)
        ns.UI.list = list
        local sum = 0
        for n, d in ipairs(list) do
            sum = sum + d.count
            page.items[n] = ClassItem(d, ns.Repair.Coins(d.count),
                ("%d %s · %s"):format(d.n, d.n == 1 and "repair" or "repairs", ns.Repair.Money(d.count)), "repairs", n)
            page.items[n].mark = "Best Customer #" .. n
        end
        page.message = #list == 0 and "No repair bills yet. Everyone's gear is shiny." or nil
        page.left = ("%s: %s on repairs"):format(period, ns.Repair.Money(sum))
        page.right = "You: " .. ns.Repair.Money(Mine(list, me)) .. "  ·  " .. page.right
    elseif id == "health" then
        local list = ns.Health.List(book)
        ns.UI.list = list
        local bad = 0
        for n, d in ipairs(list) do
            if d.count > 0 then bad = bad + 1 end
            page.items[n] = ClassItem(d, d.count, ns.Health.Line(d.h) .. " · " .. ns.UI.Ago(d.h.at, now), "health", n)
            page.items[n].mark = "#" .. n
        end
        page.message = #list == 0 and "No reports yet. Guildies need Omen Deaths 0.8.0 or newer." or nil
        page.left = ("Health: %d %s reported, %d with problems"):format(#list, #list == 1 and "player" or "players", bad)
    elseif id == "deathless" then
        local list = ns.Stats.Ladder(book)
        ns.UI.list = list
        -- 0.9.12: one ranking, the fallen keep their place with a cross and a grey name
        local mine, alive = nil, 0
        for n, d in ipairs(list) do
            local note
            if d.dead then
                note = "Died at lvl " .. d.lv .. (d.k and (" to " .. d.k) or "")
            else
                alive = alive + 1
                note = d.lv >= ns.Stats.DEATHLESS_TOP and "Deathless 60 · never died" or "Alive · still climbing"
            end
            local item = ClassItem(d, "Lvl " .. d.lv, note, nil, n)
            if d.dead then
                item.name = NewUI.CROSS .. " " .. d.name
                item.color = { COL.muted[1], COL.muted[2], COL.muted[3] }
            end
            item.mark = (d.dead and "Fallen #" or "Alive #") .. n
            page.items[n] = item
            if d.name == me then mine = d end
        end
        page.message = #list == 0 and "Nobody here yet. Everyone has died at least once. Typical." or nil
        -- the rule on the free line above the board (this tab has no period buttons); the footer is
        -- short: its left part is 300 wide and does not wrap
        page.note = "Alive: climbs with each level  ·  " .. NewUI.CROSS .. " Fallen: stays where they died"
        page.left = ("%d alive  ·  %d fallen"):format(alive, #list - alive)
        local you
        if mine then
            you = "#" .. (function() for n, d in ipairs(list) do if d == mine then return n end end end)()
                .. (mine.dead and (", fell at lvl " .. mine.lv) or ", alive")
        elseif me and ns.Stats.HasDied(book, me) then
            you = "not on it (died earlier)"
        else
            you = "not on it yet"
        end
        page.right = "You: " .. you .. "  ·  " .. page.right
    elseif id == "awards" then
        local week = ns.Awards.WeekStart()
        local lastWeek = ns.Awards.Compute(book, week - ns.Awards.WEEK, week)
        page.noBoard = true
        page.awards = {
            last = AwardList(book, lastWeek),
            hasWinners = lastWeek.top ~= nil,
            now = AwardList(book, ns.Awards.Compute(book, week, now + 1)),
            range = Day(week - ns.Awards.WEEK) .. " - " .. Day(week),
            left = NewUI.Left(week + ns.Awards.WEEK - now),
        }
        page.left = "Winners are posted in guild chat after each weekly reset"
    elseif id == "duels" then
        -- the duel ranking (0.9.12, the preview the user approved, layout A)
        local r = ns.Duels.Ranking(book, now)
        local roster = ns.Duels.Roster()
        local mine = me and ns.Duels.Place(r, me)
        local online = 0
        ns.UI.list = {}
        for n, name in ipairs(r.order) do
            local i, ro = r.info[name], roster[name] or {}
            local p = book.players[name]
            local class = ro.class or (p and p.class)
            local lv = ro.level or i.lv
            if ro.online then online = online + 1 end
            local d = { name = name, class = class, W = i.W, L = i.L, lv = lv, online = ro.online, rank = n,
                h2h = me and name ~= me and r.h2h[name < me and (name .. "|" .. me) or (me .. "|" .. name)] or nil }
            ns.UI.list[n] = d
            local item = ClassItem(d, i.W .. "W " .. i.L .. "L",
                (ro.online and NewUI.ONLINE or NewUI.OFFLINE) .. (lv and (" · lvl " .. lv) or ""), "duel", n)
            if n == 1 then
                local def = r.champion.defenses
                item.mark = "CHAMPION · " .. def .. (def == 1 and " defense" or " defenses")
                item.belt = true
                -- the defense deadline (0.9.13): in days, the last day in hours
                local left = (r.champion.active or now) + ns.Duels.DEFEND - now
                local when = left >= 86400 and (math.floor(left / 86400) .. "d") or (math.max(1, math.ceil(left / 3600)) .. "h")
                item.note = item.note .. " · defend in " .. when
            else
                item.mark = "Contender #" .. n
            end
            if name ~= me then item.challenge, item.online, item.mine = name, ro.online, mine end
            page.items[n] = item
        end
        page.allRows = true
        page.note = "Beat someone above you to take their place  ·  1 duel per pair per day counts"
        page.message = #r.order == 0 and "No ranked duels yet.\n\nDuel a guildie to start the Omen ranking." or nil
        page.left = ("%d ranked  ·  %d online"):format(#r.order, online)
        local you = mine and ("#" .. mine .. " · " .. r.info[me].W .. "W " .. r.info[me].L .. "L") or "not ranked yet"
        page.right = "You: " .. you .. "  ·  " .. page.right
    elseif id == "raids" then
        -- Raids gets its own title (24-11-2026, wish of the user); other tabs keep "Under Construction"
        page.note = "Raid plans from your raid leader"
        page.buildingTitle = "Coming soon..."
        page.building = "...so you stop dying.\n\nYour raid leader puts the tactics and your own task for every boss here. You only have to read it."
        page.noBoard = true
    elseif id == "raidadmin" then
        page.note = "Only you can see this tab"
        page.building = "Soon you can choose here who may import the sign-ups and write raid plans."
        page.noBoard = true
    elseif id == "custom" then
        page.note = "Your own death lines"
        page.building = "Soon you can write your own funny death lines for your guildies."
        page.noBoard = true
    elseif id == "settings" then
        page.note = "Saved for this account"
        page.noBoard, page.settings = true, true
        page.left = "Omen Deaths " .. ns.VERSION
    end
    return page
end

---------------------------------------------------------------------------
-- Filling
---------------------------------------------------------------------------
-- NPC portraits (0.9.8). The game draws one from a display number; a hidden model tells which
-- display an NPC number has. One look-up at a time, only for the top 3 on screen, kept in
-- OmenDeathsDB.displayIDs. No answer in time: the icon stays until the next session.
NewUI.PORTRAIT_WAIT = 2 -- seconds; not measured, a late answer only means the icon stays
local portraitQueue, portraitQueued, portraitFailed, portraitBusy, portraitModel = {}, {}, {}, nil, nil

local function NextPortrait()
    if portraitBusy then return end
    local npc = table.remove(portraitQueue, 1)
    if not npc then return end
    portraitQueued[npc] = nil
    if not portraitModel then
        portraitModel = CreateFrame("PlayerModel", nil, UIParent)
        portraitModel:SetSize(1, 1)
        portraitModel:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        portraitModel:SetAlpha(0)
    end
    local model, request = portraitModel, { npc = npc }
    portraitBusy = request
    local function finish(display)
        if portraitBusy ~= request then return end
        portraitBusy = nil
        model:SetScript("OnModelLoaded", nil)
        model:Hide()
        if type(display) == "number" and display > 0 then
            ns.db.displayIDs = ns.db.displayIDs or {}
            ns.db.displayIDs[npc] = display
            NewUI.Refresh()
        else
            portraitFailed[npc] = true
        end
        NextPortrait()
    end
    model:Show()
    -- first: clearing can count as "loaded", with no display yet
    pcall(model.ClearModel, model)
    model:SetScript("OnModelLoaded", function()
        local ok, display = pcall(model.GetDisplayInfo, model)
        finish(ok and ns.Safe(display) or nil)
    end)
    if C_Timer and C_Timer.After then C_Timer.After(NewUI.PORTRAIT_WAIT, function() finish(nil) end) end
    if not pcall(model.SetCreature, model, npc) then finish(nil) end
end

function NewUI.QueuePortrait(npc)
    if portraitFailed[npc] or portraitQueued[npc] or (portraitBusy and portraitBusy.npc == npc) then return end
    if ns.db.displayIDs and ns.db.displayIDs[npc] then return end
    portraitQueued[npc] = true
    portraitQueue[#portraitQueue + 1] = npc
    NextPortrait()
end

local function SetIcon(tex, item)
    local display = item.npc and ns.db.displayIDs and ns.db.displayIDs[item.npc]
    if display and type(SetPortraitTextureFromCreatureDisplayID) == "function"
        and pcall(SetPortraitTextureFromCreatureDisplayID, tex, display) then
        tex:SetTexCoord(0, 1, 0, 1)
        return
    end
    tex:SetTexture(NewUI.Icon(item.icon or QUESTION))
    tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    -- last: the answer can come at once and then draws the portrait over this
    if item.npc and not display then NewUI.QueuePortrait(item.npc) end
end

local function FillTomb(t, item, i)
    if not item then
        t.data, t.kind = nil, nil
        t:Hide()
        return
    end
    t:Show()
    t.data, t.kind, t.rankNumber = item.data, item.kind, item.rank
    t.mark:SetText(item.mark or MARKS[i])
    SetIcon(t.icon, item)
    t.name:SetText(item.name)
    Paint(t.name, item.color)
    t.value:SetText(item.value)
    t.note:SetText(item.note)
    if item.belt then t.belt:Show() else t.belt:Hide() end
end

local function FillRow(r, item)
    if not item then
        r.data, r.kind = nil, nil
        r:Hide()
        return
    end
    r:Show()
    r.data, r.kind, r.rankNumber = item.data, item.kind, item.rank
    r.rank:SetText("#" .. tostring(item.rank))
    r.name:SetText(item.name)
    Paint(r.name, item.color)
    r.note:SetText(item.note)
    r.value:SetText(item.value)
    local c = r.challenge
    if item.challenge then
        r.note:SetWidth(NewUI.NOTE_SHORT)
        c.target, c.online, c.rank, c.mine = item.challenge, item.online, item.rank, item.mine
        c.icon:SetDesaturated(not item.online)
        c.icon:SetAlpha(item.online and 1 or 0.45)
        c:Show()
    else
        r.note:SetWidth(196)
        c:Hide()
    end
end

local function Show(w, on)
    if on then w:Show() else w:Hide() end
end

local function FillAwards(data)
    local a = frame.awards
    a.range:SetText(data.range)
    a.left:SetText("New winners in " .. data.left)
    Show(a.empty, not data.hasWinners)
    Show(a.grass, data.hasWinners)
    a.empty:SetText("No winners yet.\n\nThe first prizes go out at the next weekly reset, in " .. data.left .. ".")
    for i, t in ipairs(a.stones) do
        Show(t, data.hasWinners)
        local w = data.last[i]
        t.name:SetText(w.name or "Nobody")
        Paint(t.name, w.color or COL.muted)
        t.score:SetText(w.score or "-")
    end
    for i, r in ipairs(a.rows) do
        local w = data.now[i]
        r.name:SetText(w.name or "Nobody yet")
        Paint(r.name, w.color or COL.muted)
        r.score:SetText(w.score or "-")
    end
end

local function CurrentTab()
    for _, def in ipairs(NewUI.TABS) do
        if def.id == state.newTab then
            if NewUI.Visible(def) then return def end
        end
    end
    state.newTab = "board"
    return NewUI.TABS[1]
end

local function LayoutTabs(current)
    local previous
    for _, b in ipairs(frame.tabButtons) do
        local shown = NewUI.Visible(b.def)
        Show(b, shown)
        if shown then
            b:ClearAllPoints()
            if previous then
                b:SetPoint("TOP", previous, "BOTTOM", 0, -NewUI.TAB_GAP)
            else
                -- offsets count in the tab's own scale: divided, so the first tab keeps its place
                b:SetPoint("TOPLEFT", frame, "TOPRIGHT", -2 / NewUI.TAB_SCALE, -48 / NewUI.TAB_SCALE)
            end
            previous = b
            b.active = b.def.id == current.id
            Show(b.SelectedTexture, b.active)
        end
    end
end

function NewUI.Refresh()
    if not frame or not frame:IsShown() then return end
    local def = CurrentTab()
    LayoutTabs(def)
    frame:SetTitle("Omen Deaths  ·  " .. def.label)

    for _, b in ipairs(frame.periodButtons) do
        Show(b, def.periods)
        Select(b, b.period == state.period)
    end
    Show(frame.scopeButton, def.scope)
    if def.scope then
        local scopes, index = NewUI.Scopes()
        frame.scopeButton:SetText(scopes[index].short or scopes[index].label)
    end

    local page = NewUI.Page(def.id, ns.Book(), ns.Now())
    frame.page = page
    Show(frame.filterNote, page.note ~= nil)
    frame.filterNote:SetText(page.note or "")
    -- a message stands where the graves would be: the board (a child frame) would cover it
    Show(frame.board, not page.noBoard and page.message == nil)
    Show(frame.settingsPage, page.settings == true)
    Show(frame.awardsPage, page.awards ~= nil)
    if page.awards then FillAwards(page.awards) end
    Show(frame.building, page.building ~= nil)
    frame.building.title:SetText(page.buildingTitle or "Under Construction")
    frame.building.text:SetText(page.building or "")
    Show(frame.message, page.message ~= nil)
    frame.message:SetText(page.message or "")

    if not page.noBoard then
        for i, t in ipairs(frame.tombs) do FillTomb(t, page.items[i] or nil, i) end
        -- Duels (0.9.12, the user's choice): the list starts at #1, the top 3 stand on the stones too
        local skip = page.allRows and 0 or 3
        local maxOffset = math.max(0, #page.items - skip - NewUI.ROWS)
        NewUI.offset = math.min(NewUI.offset or 0, maxOffset)
        for i, r in ipairs(frame.rows) do FillRow(r, page.items[skip + i + NewUI.offset]) end
    end
    if page.settings then
        for _, b in ipairs(frame.settingRows) do
            b:SetChecked(state[b.key] and true or false)
        end
    end
    frame.footLeft:SetText(page.left or "")
    frame.footRight:SetText(page.right or "")

    local update = ns.Comm.newest and ("Update to " .. ns.Comm.newest .. " (you have " .. ns.VERSION .. "): CurseForge app or GitHub")
    if update then
        frame.quip:SetText(update)
        Paint(frame.quip, COL.orange)
    elseif frame.quipUpdate then
        frame.quip:SetText(QUIPS[math.random(#QUIPS)])
        Paint(frame.quip, COL.muted)
    end
    frame.quipUpdate = update
end

function NewUI.Select(id)
    state.newTab = id
    NewUI.offset = 0
    NewUI.Refresh()
end

function NewUI.Show()
    if not ns.db then return end
    if not frame then Build() end
    frame.quip:SetText(QUIPS[math.random(#QUIPS)])
    frame:Show()
    NewUI.Refresh()
end

function NewUI.Hide()
    if frame then frame:Hide() end
end

function NewUI.Toggle()
    if frame and frame:IsShown() then frame:Hide() else NewUI.Show() end
end

function NewUI.Frame() return frame end
