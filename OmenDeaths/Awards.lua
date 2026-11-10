-- Omen Deaths: last week's awards in guild chat, once per week per guild (0.9.0, chosen by the user).
-- "[Omen Deaths] Last week's awards! Death of the week: Chrysi (23). Floor Inspector: Kwatta (5 falls).
--  Deadliest foe: Hogger (7 kills)"
-- Who posts: the first guildie on 0.9.0+ who logs in after the weekly reset (as the new-version line,
-- Comm.lua). Known as posted (book.awardsSeen = start of the week): I posted it, or heard a claim
-- A|week (sent along with every answer to a V), or a saved Health report from before this session shows
-- a guildie on 0.9.0+ online this week (they posted it, or heard that it was).
-- No "survivor" award: the addon cannot tell who played last week without dying.
local _, ns = ...
local Awards = {}
ns.Awards = Awards

Awards.FIRST = "0.9.0" -- the first version that posts them
Awards.WEEK = 604800
-- Two clients work out the start of the week from "seconds until the reset" at another moment; the
-- clock counts whole seconds, so the answers can differ by a second. Within a minute = the same week.
Awards.SAME_WEEK = 60

function Awards.WeekStart() return ns.Data.PeriodStart("week") end

local function Best(counts)
    local best, n
    for name, c in pairs(counts) do
        if not n or c > n or (c == n and name < best) then best, n = name, c end
    end
    return best, n
end

-- From the deaths in [from, to): most deaths, most falls, the killer with most kills. Battlegrounds
-- not counted (as Everywhere on the leaderboard).
function Awards.Compute(book, from, to)
    local deaths, falls, foes = {}, {}, {}
    for name, p in pairs(book.players) do
        if ns.Data.Shown(name) then
            for t, r in pairs(p.deaths) do
                if t >= from and t < to and ns.Data.InScope(r, nil) then
                    deaths[name] = (deaths[name] or 0) + 1
                    if not r.k and r.s == "Falling" then falls[name] = (falls[name] or 0) + 1 end
                    if r.k then foes[r.k] = (foes[r.k] or 0) + 1 end
                end
            end
        end
    end
    local a = {}
    a.top, a.topN = Best(deaths)
    a.faller, a.fallN = Best(falls)
    a.foe, a.foeN = Best(foes)
    return a
end

local function Plural(n, word) return n .. " " .. word .. (n == 1 and "" or "s") end

function Awards.Line(a)
    local line = "[Omen Deaths] Last week's awards! Death of the week: " .. a.top .. " (" .. a.topN .. ")"
    if a.faller then line = line .. ". Floor Inspector: " .. a.faller .. " (" .. Plural(a.fallN, "fall") .. ")" end
    if a.foe then line = line .. ". Deadliest foe: " .. a.foe .. " (" .. Plural(a.foeN, "kill") .. ")" end
    return ns.Toast.Fit(line)
end

local function Seen(book, week)
    if not book.awardsSeen or week > book.awardsSeen then book.awardsSeen = week end
end

function Awards.Heard(week)
    week = tonumber(week)
    if week and ns.db and ns.GuildName() then Seen(ns.Book(), week) end
end

-- With my answer to a V: the latest week I know was posted.
function Awards.Claim()
    local seen = ns.db and ns.GuildName() and ns.Book().awardsSeen
    if seen then return "A|" .. seen end
end

-- A saved Health report from before this session: a guildie on 0.9.0+ online this week.
function Awards.HadItBefore(week)
    local me, start = ns.MyName(), ns.Comm.SessionStart()
    for name, h in pairs(ns.Book().health or {}) do
        if type(h.v) == "string" and not ns.SameChar(name, me) and not ns.Comm.Newer(Awards.FIRST, h.v)
            and type(h.at) == "number" and start and h.at < start and h.at >= week then
            return true
        end
    end
    return false
end

function Awards.Maybe()
    if not ns.db or ns.Announced() ~= ns.VERSION or not ns.GuildName() then return end
    if not ns.db.settings.guildChat then return end
    local book, week = ns.Book(), Awards.WeekStart()
    if book.awardsSeen and book.awardsSeen >= week - Awards.SAME_WEEK then return end
    Seen(book, week)
    if Awards.HadItBefore(week) then return end
    local a = Awards.Compute(book, week - Awards.WEEK, week)
    if not a.top then return end
    ns.Comm.SendRaw("A|" .. week)
    ns.Toast.Post(Awards.Line(a))
end
