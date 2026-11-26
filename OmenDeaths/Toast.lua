-- Omen Deaths: the little banner (and chat line) when a guildie dies.
local _, ns = ...
local Toast = {}
ns.Toast = Toast

-- How long the banner stays, then fades (a feel choice, not measured).
local SHOW, FADE = 6, 1

local SELF = {
    "You died. Again.",
    "You died. The Spirit Healer waves hello.",
    "You died. Your repair bill sends its regards.",
    "You died. Omen will remember this.",
    "You died. Walk it off, ghost.",
}

local frame

---------------------------------------------------------------------------
-- Guild chat: the one who died posts one funny line, so guildies without the addon see it too.
-- Only your own death, only when "Guild chat" is on. While the game holds chat back
-- (C_ChatInfo.InChatMessagingLockdown, e.g. in a boss fight) the line waits, as PPForever does.
---------------------------------------------------------------------------
Toast.CHAT_MAX = 255 -- the game's limit for a chat line
local outbox = {}
local poster = CreateFrame("Frame")
poster:Hide()

local function Locked()
    local api = C_ChatInfo
    return api and ns.Call(api.InChatMessagingLockdown) == true
end

-- How the guild chat line of my latest death went, for the Health report (08-11-2026: a guildie's
-- death got no line and nothing showed why). One word: off, bg (battleground: never posted), boss (counted as a boss
-- fight), wait (the game holds chat back), queued, click (waits for my next click), err (the game
-- refused it), noguild, sent (not seen back yet), arrived (seen back in guild chat), lost (not back
-- by the time I was alive again: next lines go at a click). Up to 0.8.6 also retried (a second try;
-- gone since 0.8.7) and lost meant "also not after the second try". echo = seconds until seen back.
function Toast.Note(result, err, echo)
    if not ns.db then return end
    ns.db.lastPost = { r = result, at = ns.Now(), echo = echo }
    if err then ns.NoteError(err, "guild chat") end
end

local function Report()
    if ns.Comm and ns.Comm.SendHealth then ns.Comm.SendHealth() end
end

local function Send(msg)
    local send = C_ChatInfo and C_ChatInfo.SendChatMessage or SendChatMessage
    if not send then return false, "no way to send chat" end
    return pcall(send, msg, "GUILD")
end

-- My own line (09-11-2026): at once, or at my first click after the death on a client that needs it.
-- - Chrysi's lines sent by the addon got lost without an error, while a typed line arrived; a line
--   sent from a click arrived for him (Health "retried/1.21", 08-11-2026). For Kwatta, Benny and
--   Booty the line sent at once arrived ("arrived/0.55").
-- - The second try of 0.8.5 (once more if the echo was not back within 1 s) gave a double line:
--   Kwatta's echo came back about 5 s late (death at :53.5, second try at :58.8, then an echo
--   0.23 s later, faster than any fresh echo measured: 0.50-0.55 s). A late echo cannot be told
--   apart from a lost line, so there is never a second try.
-- So the client learns: a line sent at once that has not come back by the time I am alive again
-- (or by my next line) puts this client on clicks (OmenDeathsDB.clickMode); if its echo still
-- comes later, clicks go off again. The user chose this over "always at a click" (09-11-2026).
-- Clicks: Release Spirit, accepting a res, any click in the world (turning the camera too).
local waiting -- my line: { msg, at = GetTime() when sent (nil: waits for a click), auto = sent at once, missed }

-- The shortest echo measured of a fresh line (0.50, 0.53, 0.55 s; 08-11-2026). A "retried" from
-- 0.8.5/0.8.6 with a shorter echo was the late first line, not a lost one (Kwatta's 0.23).
Toast.FRESH_ECHO = 0.50

-- Upgrading from 0.8.5/0.8.6: a client that lost a line then starts on clicks, so it does not lose one again.
function Toast.SeedClickMode()
    local db = ns.db
    if not db or db.clickMode ~= nil then return end
    local lp = db.lastPost
    db.clickMode = (lp and (lp.r == "lost" or (lp.r == "retried" and type(lp.echo) == "number"
        and lp.echo >= Toast.FRESH_ECHO))) and true or false
end
ns.On("PLAYER_LOGIN", function() Toast.SeedClickMode() end)

-- My line sent at once did not come back in time: from now on at a click.
local function Missed()
    if not waiting or not waiting.auto or waiting.missed then return end
    waiting.missed = true
    if ns.db then ns.db.clickMode = true end
    Toast.Note("lost")
    Report()
end

-- Post log (0.9.5): every line this addon put in guild chat, newest last, in OmenDeathsDB.postLog.
-- 13-11-2026 a guildie sent several lines at once and nothing showed what they were.
-- Per line: t = server time, k = kind (d death, b boss summary, a awards, u new version, r rank, s Spirit Healer),
-- w = whole seconds it waited before going out (chat held back, or waiting for a click),
-- c = sent at a click, x = the game refused it.
-- KEEP 12: the most deaths of one guildie in one evening (Chrysi 13-11-2026, 12 in battlegrounds).
Toast.POST_LOG_KEEP = 12
function Toast.LogPost(kind, queued, ok, click)
    local db = ns.db
    if not db then return end
    local log = type(db.postLog) == "table" and db.postLog or {}
    db.postLog = log
    log[#log + 1] = { t = ns.Now(), k = kind or "?", w = queued and math.floor(GetTime() - queued) or 0,
        c = click or nil, x = not ok or nil }
    while #log > Toast.POST_LOG_KEEP do table.remove(log, 1) end
end

-- The log for the Health report: "d35w12c,d35" = newest first, kind + seconds before `now`
-- (+ w seconds waited, c at a click, x refused), as many as fit in maxLen bytes.
function Toast.PostLogText(now, maxLen)
    local log = ns.db and ns.db.postLog or {}
    local parts, len = {}, 0
    for i = #log, 1, -1 do
        local e = log[i]
        local s = tostring(e.k) .. math.max(0, now - (e.t or now))
            .. ((e.w or 0) > 0 and ("w" .. e.w) or "") .. (e.c and "c" or "") .. (e.x and "x" or "")
        local add = #s + (#parts > 0 and 1 or 0)
        if len + add > maxLen then break end
        parts[#parts + 1], len = s, len + add
    end
    if #parts > 0 then return table.concat(parts, ",") end
end

-- The second line that belongs to my death line (top 3 of All Time): right behind it.
local function SendFollow(msg, queued, click)
    local ok = Send(msg)
    Toast.LogPost("r", queued, ok, click)
end

poster:SetScript("OnUpdate", function(self)
    if Locked() then return end
    while outbox[1] do
        local item = table.remove(outbox, 1)
        if not ns.GuildName() then
            if item.mine then Toast.Note("noguild") end
        elseif item.mine then
            -- the line before has not come back yet: it counts as lost
            Missed()
            if ns.db and ns.db.clickMode then
                waiting = { msg = item.msg, queued = item.queued, follow = item.follow }
                Toast.Note("click")
            else
                local ok, err = Send(item.msg)
                Toast.LogPost(item.kind, item.queued, ok)
                if ok and item.follow then SendFollow(item.follow, item.queued) end
                waiting = ok and { msg = item.msg, at = GetTime(), auto = true } or nil
                Toast.Note(ok and "sent" or "err", not ok and err or nil)
                Report()
            end
        else
            local ok = Send(item.msg)
            Toast.LogPost(item.kind, item.queued, ok)
            -- Deathless 60 (0.9.11): its second line right behind it
            if ok and item.follow then SendFollow(item.follow, item.queued) end
            -- boss summary, awards, new version: rare (a few per session), so the guild sees the log at once
            Report()
        end
    end
    self:Hide()
end)

ns.On("PLAYER_ALIVE", function() Missed() end)
ns.On("PLAYER_UNGHOST", function() Missed() end)

local function Trim(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end

-- A line in guild chat: is it mine coming back?
function Toast.Heard(text, sender)
    if not waiting or not waiting.at then return end
    local fromMe = ns.IsSecret(sender) or ns.SameChar(sender, ns.MyName())
    if not fromMe then return end
    if not ns.IsSecret(text) and (type(text) ~= "string" or Trim(text) ~= Trim(waiting.msg)) then return end
    local echo = math.floor((GetTime() - waiting.at) * 100 + 0.5) / 100
    -- only late, not lost: sending at once works on this client after all
    if waiting.missed and ns.db then ns.db.clickMode = false end
    Toast.Note("arrived", nil, echo)
    waiting = nil
    Report()
end
ns.On("CHAT_MSG_GUILD", function(text, sender) Toast.Heard(text, sender) end)

-- The player clicked: my line that waits for a click goes out now, once.
function Toast.Click()
    if not waiting or waiting.at or Locked() then return end
    if not ns.GuildName() then
        waiting = nil
        Toast.Note("noguild")
        return
    end
    local ok, err = Send(waiting.msg)
    Toast.LogPost("d", waiting.queued, ok, true)
    if ok then
        if waiting.follow then
            SendFollow(waiting.follow, waiting.queued, true)
            waiting.follow = nil
        end
        waiting.at = GetTime()
        Toast.Note("sent")
    else
        waiting = nil
        Toast.Note("err", err)
    end
    -- the guild sees at once how it went
    Report()
end

-- Clicks to listen to: the buttons of the game's popups (StaticPopup1-4, under several names as
-- client versions differ) and clicks in the world. Only those that exist; hooked once each.
local hooked = {}
local function Hook(frame, script)
    if type(frame) ~= "table" or hooked[frame] or not frame.HookScript then return end
    hooked[frame] = true
    pcall(frame.HookScript, frame, script, function() Toast.Click() end)
end
function Toast.HookClicks()
    Hook(WorldFrame, "OnMouseDown")
    for i = 1, Toast.POPUPS do
        local p = _G["StaticPopup" .. i]
        if type(p) == "table" then
            -- rawget: a frame's child keys are plain fields; a missing one is simply nil
            local box = rawget(p, "ButtonContainer")
            for j = 1, 4 do
                Hook(rawget(p, "button" .. j), "OnClick")
                Hook(_G["StaticPopup" .. i .. "Button" .. j], "OnClick")
                if type(box) == "table" then Hook(rawget(box, "Button" .. j), "OnClick") end
            end
        end
    end
end
ns.On("PLAYER_LOGIN", function() Toast.HookClicks() end)

-- "[Omen Deaths] Hogger says hi to Benny - by Rend in Elwynn Forest. Deaths this week: 3"
-- rank (0.9.6): moved up All Time. Outside the top 3 a short note at the end, always kept whole.
function Toast.GuildLine(owner, rec, rank)
    local text, named = ns.Lines.For(rec, owner)
    local line = "[Omen Deaths] " .. text
    local detail = ns.Lines.Detail(rec, named)
    if detail ~= "" then line = line .. " - " .. detail end
    local n = ns.Data.CountFor(ns.Book(), owner, "week")
    if n > 0 then line = line .. ". Deaths this week: " .. n end
    if rank and rank.to > 3 then
        local note = " [Rank " .. rank.from .. " > " .. rank.to .. "]"
        return Toast.Fit(line, Toast.CHAT_MAX - #note) .. note, text, named, n
    end
    return Toast.Fit(line), text, named, n
end

-- The second line when I pass someone in the All Time top 3.
function Toast.RankLine(owner, rank)
    local sets = ns.Lines.SETS.rank
    local list = sets[rank.to] or sets.top3
    return "[Omen Deaths] " .. ns.Lines.Render(list[math.random(#list)], owner, nil,
        { n = rank.n, other = rank.other, leader = rank.leader })
end

-- Came back at the Spirit Healer: one line in guild chat (not from a battleground).
function Toast.SpiritPost(entry)
    if not ns.db or not ns.db.settings.guildChat or not ns.GuildName() then return end
    if entry and (entry.it == "pvp" or entry.it == "arena") then return end
    local list = ns.Lines.SETS.spirit.plain
    Toast.Post("[Omen Deaths] " .. ns.Lines.Render(list[math.random(#list)], ns.MyName()), false, "s")
end

-- No "|" (chat escape codes) and at most CHAT_MAX bytes, not cutting a character in half.
function Toast.Fit(line, max)
    max = max or Toast.CHAT_MAX
    line = line:gsub("|", "")
    if #line > max then
        line = line:sub(1, max):gsub("[\192-\255][\128-\191]*$", "")
    end
    return line
end

-- Posts a line in guild chat as soon as chat is allowed. mine = the line of my own death.
-- kind for the post log: "d" death (default for mine), "b" boss summary, "a" awards, "u" new version.
function Toast.Post(line, mine, kind, follow)
    outbox[#outbox + 1] = { msg = Toast.Fit(line), mine = mine, kind = kind or (mine and "d") or "?", queued = GetTime(),
        follow = follow and Toast.Fit(follow) or nil }
    if mine then Toast.Note(Locked() and "wait" or "queued") end
    poster:Show()
end

function Toast.IsBG(rec) return rec.it == "pvp" or rec.it == "arena" end

function Toast.GuildPost(owner, t)
    if not ns.db or owner ~= ns.MyName() then return end
    if not ns.db.settings.guildChat then return Toast.Note("off") end
    if not ns.GuildName() then return Toast.Note("noguild") end
    local p = ns.Book().players[owner]
    local rec = p and p.deaths[t]
    if not rec then return end
    -- battlegrounds and arenas: never (0.9.4). Up to 0.9.3 a button step "On" posted them, and the
    -- step after "Off" was "On": a guildie flooded guild chat from a battleground (13-11-2026).
    if Toast.IsBG(rec) then return Toast.Note("bg") end
    local rank = ns.Lines.RankUp(rec, owner, ns.Book())
    local top3 = rank and rank.to <= 3 and Toast.RankLine(owner, rank) or nil
    -- died in a boss fight: the summary after the fight covers it (Wipe.lua); a top 3 line follows it
    -- the very first death always gets its own line (0.9.11), also in a boss fight
    if ns.Wipe and ns.Wipe.Covers(rec) and not rec.fd then
        if top3 then ns.Wipe.HoldRank(rec, top3) end
        return Toast.Note("boss")
    end
    local line, text, named, week = Toast.GuildLine(owner, rec, rank)
    Toast.Post(line, true, nil, top3)
    return text, named, week
end

-- The game's own popups (StaticPopup1-4, "Release Spirit" among them) stand at the top of the
-- screen in a higher layer and covered the toast (08-11-2026). The toast goes under the lowest one
-- that is open, else at its own place.
Toast.TOP_Y = -140      -- own place when no popup is open (as before)
Toast.POPUP_GAP = 4     -- between the game's popup and the toast
Toast.POPUPS = 4        -- the game has StaticPopup1 to StaticPopup4
Toast.CENTER_Y = 120 -- the big popup: a little above the middle, clear of the character
function Toast.Anchor()
    if frame.center then return end
    local below
    for i = 1, Toast.POPUPS do
        local p = _G["StaticPopup" .. i]
        if p and p.IsShown and p:IsShown() then below = p end
    end
    if below == frame.below then return end
    frame.below = below
    frame:ClearAllPoints()
    if below then
        frame:SetPoint("TOP", below, "BOTTOM", 0, -Toast.POPUP_GAP)
    else
        frame:SetPoint("TOP", UIParent, "TOP", 0, Toast.TOP_Y)
    end
end

-- The popup's height: 64 as always, more when a long line wraps. Padding = (64 - skull 40) / 2.
Toast.MIN_HEIGHT, Toast.PADDING = 64, 12
Toast.TEXT_X = 62 -- skull at 12 + its width 40 + gap 10
local function Build()
    frame = CreateFrame("Frame", "OmenDeathsToast", UIParent, "BackdropTemplate")
    frame:SetSize(360, Toast.MIN_HEIGHT)
    frame:SetPoint("TOP", UIParent, "TOP", 0, Toast.TOP_Y)
    frame:SetFrameStrata("HIGH")
    frame:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    frame:SetBackdropColor(0.08, 0.02, 0.02, 0.92)
    frame:SetBackdropBorderColor(0.77, 0.12, 0.23)

    local skull = frame:CreateTexture(nil, "ARTWORK")
    skull:SetSize(40, 40)
    skull:SetPoint("LEFT", frame, "LEFT", 12, 0)
    skull:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcon_8")
    frame.skull = skull

    local title = frame:CreateFontString(nil, "OVERLAY")
    title:SetFont("Fonts\\MORPHEUS.TTF", 16, "OUTLINE")
    -- at the frame's top, the same spot as the skull's top at the normal height: the frame can grow
    title:SetPoint("TOPLEFT", frame, "TOPLEFT", Toast.TEXT_X, -Toast.PADDING)
    title:SetPoint("RIGHT", frame, "RIGHT", -10, 0)
    title:SetJustifyH("LEFT")
    title:SetTextColor(1, 0.82, 0)
    frame.title = title

    local line = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    line:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
    line:SetPoint("RIGHT", frame, "RIGHT", -10, 0)
    line:SetJustifyH("LEFT")
    line:SetTextColor(0.85, 0.85, 0.85)
    frame.line = line

    frame:EnableMouse(true)
    frame:SetScript("OnMouseUp", function()
        frame:Hide()
        if ns.UI then ns.UI.Show() end
    end)
    frame:SetScript("OnUpdate", function(self)
        -- the game's popup can open (or close) just after the toast
        Toast.Anchor()
        local age = GetTime() - (self.started or 0)
        local show = self.showFor or SHOW
        if age >= show + FADE then
            self:Hide()
        elseif age > show then
            self:SetAlpha(1 - (age - show) / FADE)
        end
    end)
    frame:Hide()
end

local function Pick(list) return list[math.random(#list)] end

-- "to Hogger (Rend) in The Deadmines · #3 this week"
function Toast.Detail(owner, rec, named, week)
    local parts = {}
    local d = ns.Lines.Detail(rec, named)
    if d ~= "" then parts[#parts + 1] = d end
    local n = week or ns.Data.CountFor(ns.Book(), owner, "week")
    if n > 0 then parts[#parts + 1] = "#" .. n .. " this week" end
    return table.concat(parts, " · ")
end

-- A guildie died (0.9.0, off unless switched on): the game's own player death scream, by the gender
-- of who died (chosen by the user by ear, 10-11-2026). IDs: Wowhead Classic HumanMalePlayerDeath 2944,
-- HumanFemalePlayerDeath 2940; 2944 also used by the Forever addon PetHealthWatch-Forever.
-- Unknown gender (older versions do not send it): male, the user's pick.
Toast.SOUND_MALE, Toast.SOUND_FEMALE = 2944, 2940
Toast.SOUND_FALLBACK = 847 -- SOUNDKIT.IG_QUEST_FAILED, if the client cannot play the scream
-- On the Master channel (0.9.3): on Effects it was too soft to notice while playing (user, 11-11-2026).
-- An addon cannot play one sound louder than its channel; Master is usually the loudest one.
Toast.CHANNEL = "Master"
-- 3 times at once (0.9.3): no volume per sound in the API, copies add up. Picked by ear out of 1-3,
-- "no echo" (user, 12-11-2026).
Toast.TIMES = 3
function Toast.Sound(gender)
    if not PlaySound then return end
    local id = gender == "f" and Toast.SOUND_FEMALE or Toast.SOUND_MALE
    local ok, willPlay = pcall(PlaySound, id, Toast.CHANNEL)
    if not ok or willPlay == false then id = SOUNDKIT and SOUNDKIT.IG_QUEST_FAILED or Toast.SOUND_FALLBACK
        pcall(PlaySound, id, Toast.CHANNEL) end
    for _ = 2, Toast.TIMES do pcall(PlaySound, id, Toast.CHANNEL) end
end

-- style (0.9.11, deathless and first deaths): scale = bigger popup, gold = gold border and a crown,
-- center = in the middle of the screen, show = seconds on screen. Sizes by feel, as the popup itself.
local function Show(title, line, style)
    if not frame then Build() end
    style = style or {}
    frame.title:SetText(title)
    frame.line:SetText(line)
    -- a streak stands out in orange (colour by feel, as the rest of the popup)
    if title:find("^%[%d+x STREAK") then frame.title:SetTextColor(1, 0.45, 0)
    else frame.title:SetTextColor(1, 0.82, 0) end
    frame:SetScale(style.scale or 1)
    if style.gold then
        frame:SetBackdropBorderColor(1, 0.82, 0)
        frame.skull:SetTexture("Interface\\Icons\\INV_Crown_01")
    else
        frame:SetBackdropBorderColor(0.77, 0.12, 0.23)
        frame.skull:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcon_8")
    end
    frame.showFor = style.show or SHOW
    frame.center = style.center
    frame.below = "again" -- anchor afresh: the last popup may have stood elsewhere
    if style.center then
        frame:ClearAllPoints()
        frame:SetPoint("CENTER", UIParent, "CENTER", 0, Toast.CENTER_Y / (style.scale or 1))
    end
    frame.started = GetTime()
    frame:SetAlpha(1)
    Toast.Anchor()
    frame:Show()
    -- after Show: the text is laid out at the frame's width, so a wrapped line counts
    local needed = frame.title:GetStringHeight() + 4 + frame.line:GetStringHeight() + 2 * Toast.PADDING
    frame:SetHeight(math.max(Toast.MIN_HEIGHT, needed))
end

-- A guildie runs a newer version (0.9.3): the same popup as a death, once per newer version heard.
-- The chat line alone was easy to miss: 10 of 13 guildies on an older version (Health, 11-11-2026).
function Toast.Update(version)
    if not ns.db or not ns.db.settings.toast then return end
    Show("Update available: Omen Deaths " .. version,
        "You have " .. ns.VERSION .. " · Update via CurseForge, then restart")
end

-- The popup of a guildie shows the line that went to guild chat (0.9.6). It comes in a T message:
-- before the L when the killer was known at once, after it (L carries "w") when it was not.
local heldDeaths, earlyLines = {}, {}
-- A held popup that never gets its line (message lost, or the player logged out) shows with an own line
-- after the longest time measured between a death and coming back: 268 s (20 deaths, 22-11-2026).
-- The line normally comes sooner: the killer was known at once in 19 of those 20.
Toast.LINE_WAIT = 268

function Toast.Incoming(owner, rec, wait)
    local key = owner .. "/" .. rec.t
    local line = earlyLines[key]
    earlyLines[key] = nil
    if line then
        Toast.Death(owner, rec, line)
    elseif wait then
        heldDeaths[key] = true
        if C_Timer and C_Timer.After then
            C_Timer.After(Toast.LINE_WAIT, function()
                if not heldDeaths[key] then return end
                heldDeaths[key] = nil
                local p = ns.Book().players[owner]
                Toast.Death(owner, p and p.deaths[rec.t] or rec)
            end)
        end
    else
        Toast.Death(owner, rec)
    end
end

function Toast.HeardLine(owner, t, line)
    local key = owner .. "/" .. t
    local p = ns.Book().players[owner]
    local rec = p and p.deaths[t]
    if heldDeaths[key] then
        heldDeaths[key] = nil
        -- from the book: it has the killer that arrived after the first message
        if rec then Toast.Death(owner, rec, line) end
    elseif not rec then
        earlyLines[key] = line
    end
end

-- The name in class colour inside a line that came ready-made.
local function ColorName(text, owner, colored)
    local a, b = text:find(owner, 1, true)
    if not a then return text end
    return text:sub(1, a - 1) .. colored .. text:sub(b + 1)
end

function Toast.Death(owner, rec, shared)
    if not ns.db or not rec then return end
    local mine = owner == ns.MyName()
    -- a guildie's death in a battleground or arena: no popup, sound or chat line (0.9.4, user's
    -- choice: a battleground gives many deaths). Still counted, under Battlegrounds.
    if not mine and Toast.IsBG(rec) then return end
    if not mine and ns.db.settings.sound then Toast.Sound(rec.g) end
    local headline, named, template, n
    local sharedText = not mine and shared and shared.text
    if mine and rec.fd then
        headline, named = "Your very first death. The deathless run is over.", false
    elseif mine then
        headline, named = Pick(SELF), false
    elseif sharedText then
        headline, named = sharedText, shared.named
    else
        headline, named, template, n = ns.Lines.For(rec, owner)
    end
    local detail = Toast.Detail(owner, rec, named, sharedText and shared.week or nil)
    Toast.last = { headline = headline, detail = detail }
    if ns.db.settings.chat then
        -- the popup's line, with the name in class colour
        local colored = not mine and ns.Colored(owner, ns.ClassColor(rec.c))
        local text = mine and headline or (sharedText and ColorName(sharedText, owner, colored))
            or ns.Lines.Render(ns.Lines.WithLevel(template, rec), colored, rec.k, n)
        ns.Print(text .. (detail ~= "" and (" — " .. detail) or ""))
    end
    if ns.db.settings.toast then Show(headline, detail, rec.fd and Toast.FirstStyle(rec.l) or nil) end
end

-- Deathless (0.9.11): the popup grows with the step. 10 and 20 only go to guild chat (the user's plan);
-- from 30 a popup, from 40 with the game's level-up sound, 60 the biggest, in the middle of the screen.
Toast.DEATHLESS = {
    [30] = { scale = 1, gold = true },
    [40] = { scale = 1.15, gold = true, sound = 1 },
    [50] = { scale = 1.3, gold = true, sound = 1, show = 8 },
    [60] = { scale = 1.6, gold = true, sound = 2, center = true, show = 12 },
}
-- SOUNDKIT.LEVELUPSOUND = 888 in the game's own list; not heard in Forever yet
Toast.SOUND_CHEER = 888
function Toast.Deathless(owner, lv)
    if not ns.db or not ns.db.settings.toast then return end
    local style = Toast.DEATHLESS[lv]
    if not style then return end
    local mine = owner == ns.MyName()
    local who = mine and "You" or owner
    local title = lv >= 60 and ("DEATHLESS 60: " .. owner) or ("Deathless " .. lv .. ": " .. owner)
    local line = lv >= 60 and (who .. " reached level 60 without dying once · Hall of Fame")
        or (who .. " reached level " .. lv .. " without a single death")
    Show(title, line, style)
    if style.sound and PlaySound then
        local id = SOUNDKIT and SOUNDKIT.LEVELUPSOUND or Toast.SOUND_CHEER
        for _ = 1, style.sound do pcall(PlaySound, id, Toast.CHANNEL) end
    end
end

-- A new Omen champion (0.9.12, duel ranking): gold, as big as the Deathless 50 popup.
function Toast.Champion(winner, old, undefended)
    if not ns.db or not ns.db.settings.toast then return end
    local line = undefended and (old .. " did not defend it: the belt goes to " .. winner)
        or old and (winner .. " took the belt from " .. old) or (winner .. " is the first to hold the belt")
    Show("NEW OMEN CHAMPION", line, Toast.DEATHLESS[50])
end

-- The very first death: bigger after a longer run, in the same steps as the levels (30, 59).
function Toast.FirstStyle(level)
    level = type(level) == "number" and level or 1
    if level >= ns.Lines.FIRST_TOP then return { scale = 1.6, center = true, show = 12 } end
    if level >= ns.Lines.FIRST_CLOSE then return { scale = 1.3, show = 8 } end
    if level >= ns.Lines.FIRST_HIGH then return { scale = 1.15 } end
end