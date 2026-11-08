-- Omen Deaths: the death records and the leaderboards built from them.
--
-- book.players[name] = { class = "PRIEST", deaths = { [t] = record } }
-- record = { t = server time, c = class, l = level, it = instance type ("none", "party", "raid",
--            "pvp", "arena", ...), id = instance ID, d = difficulty ID, z = zone or instance name,
--            k = killer name, s = spell or cause }
-- A death is known by its owner and its second (t): nobody dies twice in one second.
local _, ns = ...
local Data = {}
ns.Data = Data

local FIELDS = { "c", "l", "it", "id", "d", "z", "k", "s" }

-- Adds or completes a record. `authoritative` = the owner sent it, so it may overwrite.
-- Returns "new", "updated" or nil (nothing changed).
function Data.Add(book, owner, rec, authoritative)
    if type(owner) ~= "string" or owner == "" or type(rec) ~= "table" or type(rec.t) ~= "number" then return nil end
    local p = book.players[owner]
    if not p then
        p = { deaths = {} }
        book.players[owner] = p
    end
    if rec.c and rec.c ~= "" then p.class = rec.c end
    local old = p.deaths[rec.t]
    if not old then
        local copy = { t = rec.t }
        for _, f in ipairs(FIELDS) do copy[f] = rec[f] end
        p.deaths[rec.t] = copy
        return "new"
    end
    local changed = false
    for _, f in ipairs(FIELDS) do
        local v = rec[f]
        if v ~= nil and v ~= "" and old[f] ~= v and (authoritative or old[f] == nil or old[f] == "") then
            old[f] = v
            changed = true
        end
    end
    return changed and "updated" or nil
end

-- The game's own "Total deaths" statistic of a player: { total, at = server time it was read }.
-- Counts from the character's first day, so it covers deaths from before the addon.
-- A newer reading wins; returns true when it was taken.
function Data.SetStat(book, owner, total, at, class)
    if type(owner) ~= "string" or owner == "" or type(total) ~= "number" or type(at) ~= "number" then return false end
    local p = book.players[owner]
    if not p then
        p = { deaths = {} }
        book.players[owner] = p
    end
    if class and class ~= "" and not p.class then p.class = class end
    if p.stat and p.stat.at >= at then return false end
    p.stat = { total = total, at = at }
    return true
end

-- All Time, everywhere: the game's statistic fills in deaths from before the addon.
local function UsesStats(period, scope)
    return period == "all" and (scope == nil or scope.kind == "all")
end
Data.UsesStats = UsesStats

-- Before v0.5 deaths were kept under the first name only. Moves this character's from
-- "Mira" to "Mira Stone" (only our own: for others we cannot tell which surname).
function Data.MoveToFullName(book, first, full)
    if not first or not full or first == full then return false end
    local old = book.players[first]
    if not old then return false end
    local p = book.players[full] or { deaths = {} }
    for t, r in pairs(old.deaths) do
        if not p.deaths[t] then p.deaths[t] = r end
    end
    if old.stat and (not p.stat or old.stat.at > p.stat.at) then p.stat = old.stat end
    p.class = p.class or old.class
    book.players[full] = p
    book.players[first] = nil
    return true
end

-- How many deaths of `owner` this book holds, the latest second, and how many are at or before `upTo`.
function Data.Summary(book, owner, upTo)
    local p = book.players[owner]
    local count, latest, before = 0, 0, 0
    if p then
        for t in pairs(p.deaths) do
            count = count + 1
            if t > latest then latest = t end
            if upTo and t <= upTo then before = before + 1 end
        end
    end
    return count, latest, before
end

-- Records of `owner`, oldest first.
function Data.Records(book, owner)
    local list = {}
    local p = book.players[owner]
    if p then
        for _, r in pairs(p.deaths) do list[#list + 1] = r end
    end
    table.sort(list, function(a, b) return a.t < b.t end)
    return list
end

---------------------------------------------------------------------------
-- Periods. Day and week follow the game's own reset times when the client
-- tells them (raid weeks line up with the leaderboard week); month is the calendar month.
---------------------------------------------------------------------------
local DAY, WEEK = 86400, 604800
Data.PERIODS = { "day", "week", "month", "all" }
Data.PERIOD_LABEL = { day = "Today", week = "This Week", month = "This Month", all = "All Time" }

local function LocalMidnight(now)
    local d = date("*t", now)
    return time({ year = d.year, month = d.month, day = d.day, hour = 0, min = 0, sec = 0 })
end

function Data.PeriodStart(period, now)
    now = now or ns.Now()
    if period == "day" then
        local api = C_DateAndTime
        local left = api and ns.Call(api.GetSecondsUntilDailyReset)
        if type(left) ~= "number" then left = ns.Call(GetQuestResetTime) end
        if type(left) == "number" and left > 0 and left <= DAY then return now + left - DAY end
        return LocalMidnight(now)
    elseif period == "week" then
        local api = C_DateAndTime
        local left = api and ns.Call(api.GetSecondsUntilWeeklyReset)
        if type(left) == "number" and left > 0 and left <= WEEK then return now + left - WEEK end
        -- no answer from the client: Monday 00:00 local
        local d = date("*t", now)
        local back = (d.wday + 5) % 7 -- wday 1 = Sunday
        return LocalMidnight(now) - back * DAY
    elseif period == "month" then
        local d = date("*t", now)
        return time({ year = d.year, month = d.month, day = 1, hour = 0, min = 0, sec = 0 })
    end
    return 0
end

---------------------------------------------------------------------------
-- Places. "all" leaves out battlegrounds and arenas: dying there is part of the game.
---------------------------------------------------------------------------
function Data.InScope(rec, scope)
    local kind = scope and scope.kind or "all"
    local it = rec.it or "none"
    if kind == "all" then return it ~= "pvp" and it ~= "arena" end
    if kind == "world" then return it == "none" or it == "" end
    if kind == "party" then return it == "party" end
    if kind == "raid" then return it == "raid" end
    if kind == "pvp" then return it == "pvp" or it == "arena" end
    if kind == "instance" then return rec.id == scope.id end
    return true
end

-- The list the location button cycles through: fixed kinds, then every raid seen in the book.
function Data.Scopes(book)
    local list = {
        { kind = "all", label = "Everywhere" },
        { kind = "world", label = "Open World" },
        { kind = "party", label = "Dungeons" },
        { kind = "raid", label = "All Raids" },
        { kind = "pvp", label = "Battlegrounds" },
    }
    local raids, seen = {}, {}
    for _, p in pairs(book.players) do
        for _, r in pairs(p.deaths) do
            if r.it == "raid" and r.id and not seen[r.id] then
                seen[r.id] = true
                raids[#raids + 1] = { kind = "instance", id = r.id, label = r.z or ("Raid " .. r.id) }
            end
        end
    end
    table.sort(raids, function(a, b) return a.label < b.label end)
    for _, r in ipairs(raids) do list[#list + 1] = r end
    return list
end

local function Each(book, period, scope, now, fn)
    local from = Data.PeriodStart(period, now)
    for name, p in pairs(book.players) do
        for _, r in pairs(p.deaths) do
            if r.t >= from and Data.InScope(r, scope) then fn(name, p, r) end
        end
    end
end

-- Cause of death as shown: the killer, else the spell or kind of damage (falling, lava...).
function Data.Cause(r)
    if r.k and r.k ~= "" then return r.k end
    if r.s and r.s ~= "" then return r.s end
    return nil
end

-- Players by deaths: { name, class, count, last = latest record }, most deaths first.
function Data.Leaderboard(book, period, scope, now)
    local by = {}
    Each(book, period, scope, now, function(name, p, r)
        local row = by[name]
        if not row then
            row = { name = name, class = p.class, count = 0, causes = {} }
            by[name] = row
        end
        row.count = row.count + 1
        if not row.last or r.t > row.last.t then row.last = r end
        local cause = Data.Cause(r)
        if cause then row.causes[cause] = (row.causes[cause] or 0) + 1 end
    end)
    if UsesStats(period, scope) then
        for name, p in pairs(book.players) do
            local tracked = by[name] and by[name].count or 0
            if p.stat and p.stat.total > tracked then
                local row = by[name] or { name = name, class = p.class, causes = {} }
                row.tracked, row.count, row.fromStats = tracked, p.stat.total, true
                by[name] = row
            end
        end
    end
    local list = {}
    for _, row in pairs(by) do
        local best, n = nil, 0
        for cause, c in pairs(row.causes) do
            if c > n or (c == n and cause < best) then best, n = cause, c end
        end
        row.nemesis, row.nemesisCount = best, n
        list[#list + 1] = row
    end
    table.sort(list, function(a, b)
        if a.count ~= b.count then return a.count > b.count end
        return a.name < b.name
    end)
    return list
end

-- What killed us: { name, count, victims = { name = n } }, deadliest first. Unknown causes are one row,
-- and in All Time the deaths only the game's statistic knows (from before the addon) are another.
Data.UNKNOWN = "Unknown causes"
Data.BEFORE = "Before Omen Deaths"
local function Tail(name) return name == Data.UNKNOWN and 1 or name == Data.BEFORE and 2 or 0 end
function Data.Killers(book, period, scope, now)
    local by = {}
    Each(book, period, scope, now, function(name, _, r)
        local cause = Data.Cause(r) or Data.UNKNOWN
        local row = by[cause]
        if not row then
            row = { name = cause, count = 0, victims = {} }
            by[cause] = row
        end
        row.count = row.count + 1
        row.victims[name] = (row.victims[name] or 0) + 1
        if not row.last or r.t > row.last.t then row.last = r end
    end)
    if UsesStats(period, scope) then
        for _, row in ipairs(Data.Leaderboard(book, period, scope, now)) do
            if row.fromStats and row.count > row.tracked then
                local before = by[Data.BEFORE] or { name = Data.BEFORE, count = 0, victims = {} }
                by[Data.BEFORE] = before
                before.count = before.count + row.count - row.tracked
                before.victims[row.name] = row.count - row.tracked
            end
        end
    end
    local list = {}
    for _, row in pairs(by) do list[#list + 1] = row end
    table.sort(list, function(a, b)
        if Tail(a.name) ~= Tail(b.name) then return Tail(a.name) < Tail(b.name) end
        if a.count ~= b.count then return a.count > b.count end
        return a.name < b.name
    end)
    return list
end

-- Total deaths in the view (with the game's statistics where they apply).
function Data.Total(book, period, scope, now)
    local n = 0
    for _, row in ipairs(Data.Leaderboard(book, period, scope, now)) do n = n + row.count end
    return n
end

-- How many deaths `name` has in a period (all places except battlegrounds), for toasts.
function Data.CountFor(book, name, period, now)
    local p = book.players[name]
    if not p then return 0 end
    local from, n = Data.PeriodStart(period, now), 0
    for _, r in pairs(p.deaths) do
        if r.t >= from and Data.InScope(r, nil) then n = n + 1 end
    end
    return n
end
