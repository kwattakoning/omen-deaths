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

-- 0.9.14 (the user's choice): three prizes a week, and the three most remarkable ones win. Every
-- prize compares its winner with a normal week: 10 falls when the winner usually has 3 is more
-- remarkable than 31 deaths when the winner usually has 31. First prize = the most remarkable.
-- Only prizes that had a winner in each of the 3 weeks measured (8-27 Nov 2026): falls 7-13
-- guildies a week, lava 1-5, drowning 1-3, dungeon deaths 16-23, places 24-39, foes 128-199.
-- Not taken: raids, gray mobs, one-shots (0 in all 3 weeks), duels (only in 1 of 3 weeks).
-- count(r, name) gives the key that scores (a player, or the killer for the foe), or nil.
-- normal = the winner's score in a normal week, the median of those 3 weeks: used only when the
-- guild has no earlier week of its own yet.
Awards.PRIZES = {
    { id = "top", title = "Death of the Week", help = "Died the most", unit = "death", normal = 31 },
    { id = "fall", title = "Floor Inspector", help = "Fell the most", unit = "fall", normal = 3,
        count = function(r, name) return not r.k and r.s == "Falling" and name or nil end },
    { id = "foe", title = "Deadliest Foe", help = "Killed the most of us", unit = "kill", foe = true, normal = 5,
        count = function(r) return r.k end },
    { id = "lava", title = "Lava Lover", help = "Most deaths to lava and fire", unit = "lava bath", units = "lava baths", normal = 1,
        count = function(r, name) return not r.k and (r.s == "Lava" or r.s == "Fire") and name or nil end },
    { id = "drown", title = "Fish Food", help = "Drowned the most", unit = "drowning", normal = 1,
        count = function(r, name) return not r.k and (r.s == "Drowning" or r.s == "Fatigue") and name or nil end },
    { id = "dungeon", title = "Dungeon Disaster", help = "Most deaths in dungeons", unit = "death", normal = 19,
        count = function(r, name) return r.it == "party" and name or nil end },
    { id = "places", title = "Grave Tourist", help = "Died in the most places", unit = "place", distinct = true, normal = 12,
        count = function(r, name) return r.z and name or nil end },
}
Awards.SLOTS = 3
-- A normal week = the average winner's score of the weeks before (up to BACK weeks that had any
-- death). 4 = about a month; not measured: the guild has 3 weeks of data (since 8-11-2026).
Awards.BACK = 4

-- The winner of every prize in [from, to): { [i] = { def, who, n } }, and how many deaths in all.
-- Battlegrounds not counted (as Everywhere on the leaderboard).
function Awards.Tally(book, from, to)
    local defs = Awards.PRIZES
    local counts, places, total = {}, {}, 0
    for i = 1, #defs do counts[i], places[i] = {}, {} end
    for name, p in pairs(book.players) do
        if ns.Data.Shown(name) then
            for t, r in pairs(p.deaths) do
                if t >= from and t < to and ns.Data.InScope(r, nil) then
                    total = total + 1
                    for i, def in ipairs(defs) do
                        local key = def.count and def.count(r, name) or (not def.count and name)
                        if key and def.distinct then
                            local seen = places[i][key] or {}
                            places[i][key] = seen
                            if seen[r.z] then key = nil else seen[r.z] = true end
                        end
                        if key then counts[i][key] = (counts[i][key] or 0) + 1 end
                    end
                end
            end
        end
    end
    local out = {}
    for i, def in ipairs(defs) do
        local who, n = Best(counts[i])
        out[i] = { def = def, who = who, n = n }
    end
    return out, total
end

-- The normal winner's score of each prize, from the weeks before `from`.
function Awards.Normal(book, from)
    local sum, weeks = {}, 0
    for back = 1, Awards.BACK do
        local w, total = Awards.Tally(book, from - back * Awards.WEEK, from - (back - 1) * Awards.WEEK)
        if total > 0 then
            weeks = weeks + 1
            for i, x in ipairs(w) do sum[i] = (sum[i] or 0) + (x.n or 0) end
        end
    end
    local out = {}
    for i, def in ipairs(Awards.PRIZES) do out[i] = weeks > 0 and sum[i] / weeks or def.normal end
    return out
end

-- The three most remarkable prizes of [from, to), most remarkable first: a.prizes[i] = { def, who,
-- n, times } (times = how many times a normal week). Below 1 = a normal winner: a floor of 1 keeps
-- a rare prize with a normal of 0.3 from winning with a single death. Equal: the order of PRIZES.
-- a.top = the first prize's winner (nil: nobody died).
function Awards.Compute(book, from, to)
    local w = Awards.Tally(book, from, to)
    local normal = Awards.Normal(book, from)
    local list = {}
    for i, x in ipairs(w) do
        if x.who then
            x.times = x.n / math.max(normal[i], 1)
            x.order = i
            list[#list + 1] = x
        end
    end
    table.sort(list, function(a, b)
        if a.times ~= b.times then return a.times > b.times end
        return a.order < b.order
    end)
    local a = { prizes = {} }
    for i = 1, math.min(Awards.SLOTS, #list) do a.prizes[i] = list[i] end
    a.top = a.prizes[1] and a.prizes[1].who
    return a
end

function Awards.Score(def, n) return n .. " " .. (n == 1 and def.unit or (def.units or (def.unit .. "s"))) end

function Awards.Line(a)
    local parts = {}
    for _, w in ipairs(a.prizes) do parts[#parts + 1] = w.def.title .. ": " .. w.who .. " (" .. Awards.Score(w.def, w.n) .. ")" end
    return ns.Toast.Fit("[Omen Deaths] Last week's awards! " .. table.concat(parts, ". "))
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
    ns.Toast.Post(Awards.Line(a), false, "a")
end
