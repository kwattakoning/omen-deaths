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
    if not dumped then
        dumped = true
        local list = Stats.Dump()
        if list then ns.db.statDump = { at = ns.Now(), char = me, list = list } end
    end
    local book = ns.Book()
    local p = book.players[me]
    -- the statistic only goes up; a lower answer means it has not loaded yet
    if p and p.stat and total <= p.stat.total then return total end
    local _, class = ns.Call(UnitClass, "player")
    ns.Data.SetStat(book, me, total, ns.Now(), class)
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
-- after a fight, and after coming back from a death (the count has gone up by then)
for _, event in ipairs({ "PLAYER_REGEN_ENABLED", "PLAYER_UNGHOST", "PLAYER_ALIVE" }) do
    ns.On(event, function() Stats.Read() end)
end
