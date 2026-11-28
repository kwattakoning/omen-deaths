-- Omen Deaths: the duel ranking (0.9.12, the user's design, 26-11-2026). One ladder as in kickboxing:
-- #1 holds the Omen belt and only loses it by losing to a challenger. Beat someone above you and you
-- take their place (everyone between moves down one); beat someone below you and nothing changes, so
-- grinding weaker players gives nothing. A first duel puts you at the bottom. Fleeing is a loss.
-- Only the first duel of the same two players within Duels.DAY counts; later ones are friendly.
--
-- The ladder is not stored: it is played again from all kept duel reports (Data.DUEL_KEEP), oldest
-- first. A rule changed later (e.g. best of 3) then applies to the whole history.
local _, ns = ...
local Duels = {}
ns.Duels = Duels

-- 24 hours: the user's choice. Not measured (3 guild duels known); the reports are kept, so the
-- ranking can be played again with another rule once the data shows how often a pair duels again.
Duels.DAY = 86400
-- Both duelists report the same duel: same winner and loser, server time (GetServerTime). Herri vs
-- Brad (25-11-2026) were 0 s apart; 1 s allows for the two clients reading it on either side of a second.
Duels.SAME = 1
-- The champion has to play a counted duel within 7 days (the user, 26-11-2026: kickboxing, a champion
-- who will not fight loses the title). 7 = the week of the Awards; not measured.
Duels.DEFEND = 7 * 86400
-- Checked 15 s after login (duel answers of the login sync wait up to Comm.RELAY_JITTER = 3 s; the
-- rest is room for sending, not measured) and every hour: an hour late on a 7-day deadline is enough.
Duels.LOGIN_WAIT, Duels.CHECK = 15, 3600

local function Pair(a, b) return a < b and (a .. "|" .. b) or (b .. "|" .. a) end

-- One entry per duel (the two reports merged), oldest first.
function Duels.List(book)
    local out = {}
    for _, d in ipairs(ns.Data.DuelsAfter(book, -1)) do
        local dup = false
        for i = #out, 1, -1 do
            local o = out[i]
            if d.t - o.t > Duels.SAME then break end
            if ns.SameChar(o.w, d.w) and ns.SameChar(o.l, d.l) then dup = true break end
        end
        if not dup then out[#out + 1] = d end
    end
    return out
end

-- The ladder now: { order = { names, #1 first }, info = { [name] = { W, L, lv, t } },
-- champion = { name, defenses, since, active }, h2h = { [pair] = { [name] = wins } },
-- stripped = { { old, new, at } } (belts lost by not defending) }. `now` (default ns.Now()) is when
-- the defense deadline is checked last.
function Duels.Ranking(book, now)
    local order, info, last, h2h, stripped = {}, {}, {}, {}, {}
    local champ = { defenses = 0 }
    local function enter(name)
        if info[name] then return end
        info[name] = { W = 0, L = 0 }
        order[#order + 1] = name
    end
    local function place(name)
        for i, n in ipairs(order) do if n == name then return i end end
    end
    -- no counted duel within Duels.DEFEND: the champion drops one place, #2 takes the belt
    local function expire(t)
        while champ.name and #order >= 2 and t - champ.active > Duels.DEFEND do
            local at = champ.active + Duels.DEFEND
            order[1], order[2] = order[2], order[1]
            stripped[#stripped + 1] = { old = champ.name, new = order[1], at = at }
            champ = { name = order[1], defenses = 0, since = at, active = at }
        end
    end
    for _, d in ipairs(Duels.List(book or {})) do
        expire(d.t)
        local pair = Pair(d.w, d.l)
        if not last[pair] or d.t - last[pair] >= Duels.DAY then
            last[pair] = d.t
            enter(d.w)
            enter(d.l)
            local w, l = info[d.w], info[d.l]
            w.W, l.L = w.W + 1, l.L + 1
            w.lv, l.lv = d.wl or w.lv, d.ll or l.lv
            w.t, l.t = d.t, d.t
            h2h[pair] = h2h[pair] or {}
            h2h[pair][d.w] = (h2h[pair][d.w] or 0) + 1
            local iw, il = place(d.w), place(d.l)
            if il < iw then
                table.remove(order, iw)
                table.insert(order, il, d.w)
            elseif iw == 1 and champ.name == d.w then
                champ.defenses = champ.defenses + 1
                champ.active = d.t
            end
            if order[1] ~= champ.name then champ = { name = order[1], defenses = 0, since = d.t, active = d.t } end
        end
    end
    expire(now or ns.Now())
    return { order = order, info = info, champion = champ, h2h = h2h, stripped = stripped }
end

-- A belt lost by not defending, told once per client: a line in my own chat, a popup, and guild chat
-- from the new champion's own client. Checked at login and every Duels.CHECK seconds.
function Duels.Check()
    if not ns.db or not ns.GuildName() then return end
    local book = ns.Book()
    local now = ns.Now()
    local r = Duels.Ranking(book, now)
    local s = r.stripped[#r.stripped]
    if not s or s.at <= (book.duelStripSeen or 0) then return end
    book.duelStripSeen = s.at
    if now - s.at > Duels.DEFEND then return end -- old news (a first look at an old history)
    local text = s.old .. " did not defend the Omen belt for " .. math.floor(Duels.DEFEND / 86400) .. " days. " .. s.new .. " is the new Omen champion!"
    if ns.db.settings.chat then ns.Print(text) end
    if ns.Toast.Champion then ns.Toast.Champion(s.new, s.old, true) end
    Duels.PostTurn(s, text)
end

-- Guild chat once (0.9.14, the user: also when the new champion has no addon or is offline): the new
-- champion first, then every online addon user in the fixed order of the boss summary (Wipe.Turn,
-- Wipe.STEP). Whoever posts claims it (B|at); the claim is sent again to whoever logs in, as the
-- Awards claim, so a later login does not post it again. Guild chat off: no turn, the others post.
function Duels.PostTurn(s, text)
    local book = ns.Book()
    if (book.duelPosted or 0) >= s.at or not ns.db.settings.guildChat then return end
    local turn = ns.SameChar(s.new, ns.MyName()) and 0 or ((ns.Wipe and ns.Wipe.Turn() or 0) + 1)
    local function go()
        if not ns.db or not ns.GuildName() or (ns.Book().duelPosted or 0) >= s.at then return end
        ns.Book().duelPosted = s.at
        ns.Comm.SendRaw("B|" .. s.at)
        ns.Toast.Post("[Omen Deaths] " .. text, false, "c")
    end
    local wait = turn * (ns.Wipe and ns.Wipe.STEP or 1)
    if wait > 0 and C_Timer and C_Timer.After then C_Timer.After(wait, go) else go() end
end

function Duels.Claim()
    local at = ns.db and ns.GuildName() and ns.Book().duelPosted
    if at then return "B|" .. at end
end

function Duels.HeardClaim(at)
    local book = ns.Book()
    if not book.duelPosted or at > book.duelPosted then book.duelPosted = at end
end

local function Tick()
    pcall(Duels.Check)
    if C_Timer and C_Timer.After then C_Timer.After(Duels.CHECK, Tick) end
end
ns.On("PLAYER_LOGIN", function()
    if C_Timer and C_Timer.After then C_Timer.After(Duels.LOGIN_WAIT, Tick) end
end)
function Duels.Place(r, name)
    for i, n in ipairs(r.order) do if n == name then return i end end
end

-- Online and class from the guild roster: { [name] = { online, class, level } }.
function Duels.Roster()
    local out = {}
    local n = ns.Call(GetNumGuildMembers) or 0
    for i = 1, n do
        local name, _, _, level, _, _, _, _, online, _, class = ns.Call(GetGuildRosterInfo, i)
        name = ns.ShortName(name)
        if name then
            out[name] = { online = online and true or false, level = type(level) == "number" and level or nil,
                class = type(class) == "string" and class:match("^%u+$") or nil, index = i }
        end
    end
    return out
end

local function Name(book, name)
    local p = book.players and book.players[name]
    return ns.Colored(name, ns.ClassColor(p and p.class))
end

-- A report just in (mine, or a guildie's live one; not a sync answer): what changed is told.
-- The new champion goes to guild chat from one client: the reporter, when the winner, or the loser
-- when the winner has no addon (known to me).
function Duels.Add(book, d, live)
    local before = live and Duels.Ranking(book)
    if not ns.Data.AddDuel(book, d) then return false end
    if live and ns.db then Duels.Tell(book, d, before, Duels.Ranking(book)) end
    return true
end

function Duels.Tell(book, d, before, after)
    local me = ns.MyName()
    local lines = {}
    for _, name in ipairs({ d.w, d.l }) do
        if not before.info[name] and after.info[name] then
            lines[#lines + 1] = Name(book, name) .. " entered the duel ranking at #" .. Duels.Place(after, name)
        end
    end
    local old, new = before.champion, after.champion
    if new.name == d.w and old.name ~= d.w then
        local text = old.name and (d.w .. " took the Omen belt from " .. old.name .. "!") or (d.w .. " is the first Omen champion!")
        lines[#lines + 1] = "NEW OMEN CHAMPION: " .. text
        if ns.Toast.Champion then ns.Toast.Champion(d.w, old.name) end
        local winnerHasAddon = ns.SameChar(d.w, me) or (function()
            for peer in pairs(ns.Comm.peers or {}) do if ns.SameChar(peer, d.w) then return true end end
            return false
        end)()
        local poster = ns.SameChar(d.by, me) and (ns.SameChar(d.w, me) or not winnerHasAddon)
        if poster and ns.db.settings.guildChat then ns.Toast.Post("[Omen Deaths] NEW OMEN CHAMPION: " .. text, false, "c") end
    elseif new.name == d.w and new.defenses > (old.defenses or 0) then
        lines[#lines + 1] = Name(book, d.w) .. " defended the Omen belt against " .. Name(book, d.l)
            .. " (" .. new.defenses .. (new.defenses == 1 and " defense)" or " defenses)")
    else
        local was, now = Duels.Place(before, d.w), Duels.Place(after, d.w)
        if was and now and now < was then
            lines[#lines + 1] = Name(book, d.w) .. " beat " .. Name(book, d.l) .. " and climbed to #" .. now
        end
    end
    if ns.db.settings.chat then for _, line in ipairs(lines) do ns.Print(line) end end
end

-- The whisper button: the chat line opens filled in, the player presses Enter (the addon sends nothing).
function Duels.ChallengeText(rank, mine)
    return "I challenge you to a duel for #" .. rank .. " in the Omen ranking!" .. (mine and (" (I'm #" .. mine .. ")") or "")
end

function Duels.Challenge(name, rank, mine)
    local text = Duels.ChallengeText(rank, mine)
    if type(ChatFrame_SendTell) == "function" and pcall(ChatFrame_SendTell, name) then
        local box = type(ChatEdit_GetActiveWindow) == "function" and ChatEdit_GetActiveWindow()
        if box and box.Insert then
            box:Insert(text)
            return true
        end
    end
    if type(ChatFrame_OpenChat) == "function" then
        return pcall(ChatFrame_OpenChat, "/w " .. name .. " " .. text)
    end
    return false
end
