-- Omen Deaths: the game's own death count from the Statistics pane (Achievements > Statistics > Deaths).
--
-- Statistic 60 is "Total deaths" and counts from the character's first day, so deaths from
-- before the addon show in All Time. Journey Tracker (a Forever addon, MIT) reads the same
-- statistic; like it we read only out of combat, the first time 10 seconds after login
-- (its LOGIN_DELAY: "once statistics and /played have loaded").
-- The whole Deaths category is also kept in OmenDeathsDB.statDump, to see which
-- breakdowns Forever has before using any of them.
local _, ns = ...
local Stats = {}
ns.Stats = Stats

Stats.TOTAL_DEATHS = 60
-- "Deaths in <battleground>" in the Battlegrounds part of the Deaths category (statDump 08-11-2026):
-- 56 Warsong Gulch, 57 Alterac Valley, 59 Arathi Basin, 64182 Darkspear Islands. Not 593 "Deaths
-- from Vanndar Stormpike": those are Alterac Valley deaths already, counting it would count twice.
Stats.BG_DEATHS = { 56, 57, 59, 64182 }
Stats.LOGIN_DELAY = 10

-- "1,234" -> 1234; "--" (never happened) -> 0; anything else -> nil
function Stats.Number(v)
    if type(v) == "number" then return v end
    if type(v) ~= "string" then return nil end
    if v:match("^%s*%-%-%s*$") then return 0 end
    local digits = v:gsub("%D", "")
    if digits == "" then return nil end
    return tonumber(digits)
end

local function InCombat()
    if ns.Call(InCombatLockdown) == true then return true end
    return ns.Call(UnitAffectingCombat, "player") == true
end

-- The Deaths category and its subcategories: { { cat, title, id, name, value }, ... }
function Stats.Dump()
    local cats = ns.Call(GetStatisticsCategoryList)
    if type(cats) ~= "table" then return nil end
    local deaths
    for _, cat in ipairs(cats) do
        local title = ns.Call(GetCategoryInfo, cat)
        if type(title) == "string" and title:lower() == "deaths" then deaths = cat end
    end
    if not deaths then return nil end
    local list = {}
    for _, cat in ipairs(cats) do
        local title, parent = ns.Call(GetCategoryInfo, cat)
        if cat == deaths or parent == deaths then
            local n = ns.Call(GetCategoryNumAchievements, cat) or 0
            for i = 1, n do
                local id, name = ns.Call(GetAchievementInfo, cat, i)
                if type(id) == "number" then
                    local value = ns.Call(GetStatistic, id)
                    list[#list + 1] = { cat = cat, title = title, id = id, name = name,
                        value = type(value) == "string" and value or nil }
                end
            end
        end
    end
    return list
end

local dumped
-- Reads the total; shares it when it went up. Returns the number read (or nil).
function Stats.Read()
    if not ns.db or InCombat() then return nil end
    -- in a guild whose name has not loaded yet: wait, or the number lands in the wrong book
    if ns.Call(IsInGuild) == true and not ns.GuildName() then return nil end
    local total = Stats.Number(ns.Call(GetStatistic, Stats.TOTAL_DEATHS))
    if not total then return nil end
    local me = ns.MyName()
    if not me then return nil end
    local bg = 0
    for _, id in ipairs(Stats.BG_DEATHS) do
        local n = Stats.Number(ns.Call(GetStatistic, id))
        if not n then bg = nil break end
        bg = bg + n
    end
    if not dumped then
        dumped = true
        local list = Stats.Dump()
        if list then ns.db.statDump = { at = ns.Now(), char = me, list = list } end
    end
    local book = ns.Book()
    local p = book.players[me]
    -- the statistic only goes up; a lower answer means it has not loaded yet
    -- (unless the stored reading lacks the battleground part: saved by an older version)
    if p and p.stat and total <= p.stat.total and (bg == nil or p.stat.bg ~= nil) then return total end
    local _, class = ns.Call(UnitClass, "player")
    ns.Data.SetStat(book, me, math.max(total, p and p.stat and p.stat.total or 0), ns.Now(), class, bg)
    ns.Comm.SendStat(me)
    ns.Changed()
    return total
end

local loginRead
ns.On("PLAYER_ENTERING_WORLD", function()
    if loginRead then return end
    loginRead = true
    if C_Timer and C_Timer.After then
        C_Timer.After(Stats.LOGIN_DELAY, Stats.Read)
    else
        Stats.Read()
    end
end)
---------------------------------------------------------------------------
-- Deathless (0.9.11, wish of the user): every 10 levels without ever dying an achievement in guild
-- chat, each step bigger. The Hall of Fame tab ranks everyone who never died by level: 60 on top,
-- you climb by staying alive and levelling. "Never died" = the game's own Total deaths minus the
-- battleground deaths is 0 (the user: battlegrounds do not count, world pvp does). The statistic
-- counts from the character's first day, so a run from before the addon counts.
--
-- Y|name|level|t|flag|class   my level while I never died; flag "m" = a step reached (fanfare),
--                             else quiet (a level-up, login, an answer to a guildie's login)
---------------------------------------------------------------------------
Stats.DEATHLESS_STEP, Stats.DEATHLESS_TOP = 10, 60

-- Deaths outside battlegrounds, read now; nil when the game does not give the numbers.
function Stats.CleanDeaths()
    local total = Stats.Number(ns.Call(GetStatistic, Stats.TOTAL_DEATHS))
    if not total then return nil end
    local bg = 0
    for _, id in ipairs(Stats.BG_DEATHS) do
        local n = Stats.Number(ns.Call(GetStatistic, id))
        if not n then return nil end
        bg = bg + n
    end
    return total - bg
end

-- book.deathless[name] = { lv = level, t = when that level was reached, c = class }
function Stats.AddDeathless(book, name, lv, t, class)
    book.deathless = book.deathless or {}
    local e = book.deathless[name]
    if e and (e.lv > lv or (e.lv == lv and e.t <= t)) then
        if class and not e.c then e.c = class return true end
        return false
    end
    book.deathless[name] = { lv = lv, t = t, c = class or (e and e.c) }
    return true
end

-- Has this player died since (outside battlegrounds)? From the statistic and the deaths the addon saw.
function Stats.HasDied(book, name)
    local all = ns.Lines.AllTime({ t = ns.Now(), it = "none" }, name, book)
    return all ~= nil and all > 0
end

-- The Hall of Fame: who never died, highest level first; the same level: who got there first.
function Stats.Ladder(book)
    local list = {}
    for name, e in pairs(book and book.deathless or {}) do
        if not Stats.HasDied(book, name) and (not ns.Data.Shown or ns.Data.Shown(name)) then
            list[#list + 1] = { name = name, lv = e.lv, t = e.t, class = e.c }
        end
    end
    table.sort(list, function(a, b)
        if a.lv ~= b.lv then return a.lv > b.lv end
        if a.t ~= b.t then return a.t < b.t end
        return a.name < b.name
    end)
    return list
end

local function NeverDied(me, book)
    if Stats.CleanDeaths() ~= 0 then return false end
    -- a death the statistic has not counted yet (it is read out of combat) also ends the run
    return not Stats.HasDied(book, me)
end

function Stats.Encode(name, lv, t, flag, class)
    return table.concat({ "Y", name, tostring(lv), tostring(t), flag or "", class or "" }, "|")
end

local function MyClass()
    local _, class = ns.Call(UnitClass, "player")
    return type(class) == "string" and class or nil
end

-- My place on the ladder, now: kept and told to the guild (quiet). Out of combat only.
function Stats.CheckMine(dingLevel)
    if not ns.db or InCombat() or not ns.GuildName() then return end
    local me = ns.MyName()
    -- right after PLAYER_LEVEL_UP the game can still give the old level: the event's level counts
    local level = ns.Call(UnitLevel, "player")
    if type(dingLevel) == "number" and (type(level) ~= "number" or dingLevel > level) then level = dingLevel end
    if not me or type(level) ~= "number" then return end
    local book = ns.Book()
    if not NeverDied(me, book) then
        if book.deathless and book.deathless[me] then book.deathless[me] = nil ns.Changed() end
        return
    end
    local e = book.deathless and book.deathless[me]
    if not e or e.lv < level then
        Stats.AddDeathless(book, me, level, ns.Now(), MyClass())
        ns.Changed()
    end
    Stats.SendMine()
    return level
end

-- A step reached: guild chat, the guild's popups, my own popup. Once per character and step.
function Stats.Deathless(lv)
    if not ns.db or not ns.GuildName() then return end
    local me = ns.MyName()
    if not me then return end
    ns.db.deathless = ns.db.deathless or {}
    local key = me .. "/" .. lv
    if ns.db.deathless[key] then return end
    local book = ns.Book()
    if not NeverDied(me, book) then return end
    local t = ns.Now()
    ns.db.deathless[key] = t
    Stats.AddDeathless(book, me, lv, t, MyClass())
    local L = ns.Lines
    local list = L.SETS.deathless[lv]
    if ns.db.settings.guildChat and list then
        local follow = lv == Stats.DEATHLESS_TOP and L.SETS.deathless60[math.random(#L.SETS.deathless60)] or nil
        ns.Toast.Post("[Omen Deaths] " .. L.Render(list[math.random(#list)], me), false, "l",
            follow and ("[Omen Deaths] " .. L.Render(follow, me)) or nil)
    end
    ns.Comm.SendRaw(Stats.Encode(me, lv, t, "m", MyClass()))
    if ns.Toast.Deathless then ns.Toast.Deathless(me, lv) end
    ns.Changed()
end

-- Level-ups come in combat too (a kill): the check waits until the fight is over, the statistic
-- is read out of combat only (as Journey Tracker does).
local dinged
local function AfterDing()
    local level = dinged
    dinged = nil
    if level % Stats.DEATHLESS_STEP == 0 and level <= Stats.DEATHLESS_TOP then Stats.Deathless(level) end
    Stats.CheckMine(level)
end
ns.On("PLAYER_LEVEL_UP", function(level)
    level = ns.Safe(level)
    if type(level) ~= "number" then return end
    dinged = level
    if not InCombat() then AfterDing() end
end)

-- Mine at login and to a guildie who logs in (as Repair.SendMine): the ladder stays complete.
function Stats.SendMine()
    local me = ns.MyName()
    local book = me and ns.GuildName() and ns.Book()
    local e = book and book.deathless and book.deathless[me]
    if e and not Stats.HasDied(book, me) then ns.Comm.SendRaw(Stats.Encode(me, e.lv, e.t, nil, e.c)) end
end

function Stats.Heard(msg, sender)
    local p = {}
    for piece in (msg .. "|"):gmatch("([^|]*)|") do p[#p + 1] = piece end
    local name, lv, t, flag, class = p[2], tonumber(p[3]), tonumber(p[4]), p[5], p[6]
    if p[1] ~= "Y" or not name or name == "" or not lv or not t or not ns.SameChar(name, sender) then return end
    if lv < 1 or lv > Stats.DEATHLESS_TOP then return end
    if name == ns.MyName() then return end
    class = class and class:match("^%u+$") or nil
    local book = ns.Book()
    if Stats.AddDeathless(book, name, lv, t, class) then ns.Changed() end
    if flag == "m" and lv % Stats.DEATHLESS_STEP == 0 and ns.Toast.Deathless then ns.Toast.Deathless(name, lv) end
end

-- after a fight, and after coming back from a death (the count has gone up by then)
for _, event in ipairs({ "PLAYER_REGEN_ENABLED", "PLAYER_UNGHOST", "PLAYER_ALIVE" }) do
    ns.On(event, function()
        Stats.Read()
        if event == "PLAYER_REGEN_ENABLED" and dinged then AfterDing() end
    end)
end
ns.On("PLAYER_ENTERING_WORLD", function()
    if C_Timer and C_Timer.After then C_Timer.After(Stats.LOGIN_DELAY + 1, Stats.CheckMine) end
end)

