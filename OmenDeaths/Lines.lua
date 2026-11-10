-- Omen Deaths: a funny line that fits how someone died.
-- {name} = who died, {killer} = what killed them, {n} = how many times in a row (streak lines).
-- Lines with {killer} are only used when it is known.
local _, ns = ...
local Lines = {}
ns.Lines = Lines

Lines.SETS = {
    fall = {
        plain = { "{name} tested gravity. Gravity won.", "{name} forgot their parachute",
            "{name} took the express route down", "{name} asked the floor for a hug" },
    },
    drown = {
        plain = { "{name} forgot to come up for air", "{name} is sleeping with the fishes",
            "{name} tried to breathe underwater" },
    },
    lava = {
        plain = { "{name} went for a swim in the lava", "{name} found out the floor is lava",
            "{name} is now extra crispy" },
    },
    fatigue = {
        plain = { "{name} swam a bit too far from shore", "{name} tried to swim to the next continent" },
    },
    slime = {
        plain = { "{name} got slimed", "{name} lost a fight with a puddle of slime" },
    },
    pvp = {
        killer = { "{name} met {killer} up close", "{killer} collected an honorable kill: {name}" },
        plain = { "{name} gave the enemy an honorable kill", "{name} paid the toll for that flag" },
    },
    raid = {
        killer = { "{killer} says hi to {name}", "{name} became a raid statistic, courtesy of {killer}",
            "{name} stood in the wrong spot vs {killer}" },
        plain = { "{name} became a raid statistic", "{name} stood in something purple" },
    },
    -- Dungeon lines per role (09-11-2026: a tank got "found out why the tank goes first"). killer/plain fit
    -- every role; roles[r] adds lines for a known role (rec.r). Unknown role: only the ones for every role.
    dungeon = {
        killer = { "{killer} cleared {name} from the dungeon", "{name} took one hit too many from {killer}" },
        plain = { "{name} did not survive this pull", "{name} is waiting for a res at the entrance" },
        roles = {
            tank = {
                killer = { "{killer} chewed through {name}'s shield", "{name} held aggro on {killer} a little too well",
                    "{name} pulled {killer} a little too early" },
                plain = { "{name} pulled one mob too many", "The tank is down! {name} leads the corpse run now" },
            },
            healer = {
                killer = { "{killer} went for the healer. {name} did not like that",
                    "{name} healed everyone but themselves vs {killer}" },
                plain = { "{name} healed everyone but themselves", "The healer is down. Good luck, everyone." },
            },
            dps = {
                killer = { "{name} found out why the tank goes first ({killer})", "{name} pulled aggro from {killer} and regretted it" },
                plain = { "{name} found out why the tank goes first", "{name} pulled aggro. Bad idea." },
            },
        },
    },
    -- "lost a fair fight" was read literally by a guildie who died to a skull mob (08-11-2026)
    world = {
        killer = { "{name} picked the wrong fight with {killer}", "{killer} added {name} to their trophy wall",
            "{name} underestimated {killer}", "{name} was humbled by {killer}" },
    },
    -- open world, killer far above my level: red or skull, as the game colours its level
    above = {
        killer = { "{name} picked a fight way above their pay grade: {killer}",
            "{name} saw {killer}'s level and went for it anyway", "{killer} was a few levels out of {name}'s league" },
    },
    -- open world, killer gray: gives no experience, still got me
    gray = {
        killer = { "{name} lost to {killer}. Yes, the gray one.", "{killer} gives no XP, but it did get {name}",
            "{name} was taken out by {killer}, a gray mob" },
    },
    -- The same killer or cause as the death before, on the same day (09-11-2026, wish of the user):
    -- "in a row", replaces the line. Steps: 2nd time, 3rd and 4th, 5th and more (chosen by the user).
    streak = {
        killer = {
            [2] = { "{name} lost to {killer}. Again. {killer} is starting to recognise them.",
                "{name} vs {killer}, round two. Same result." },
            [3] = { "{killer} {n}, {name} 0. Someone call for backup.", "{name} died to {killer} {n} times in a row. Rematch?" },
            [5] = { "{name} has died to {killer} {n} times in a row. At this point {killer} should get a guild invite.",
                "{killer} has claimed {name} {n} times in a row. Somebody stop this." },
        },
        fall = {
            [2] = { "{name} fell to their death. Again. The stairs are right there." },
            [3] = { "{name} fell to their death {n} times in a row. Gravity: undefeated." },
            [5] = { "{name} has fallen to their death {n} times in a row. Wings are not included." },
        },
        lava = {
            [2] = { "{name} went for another lava bath. They clearly like it warm." },
            [3] = { "{name} took lava bath number {n} in a row. Somebody hide the lava." },
            [5] = { "{name} has gone for a lava bath {n} times in a row. It's a lifestyle now." },
        },
        drown = {
            [2] = { "{name} forgot to breathe. Again. Gills not included." },
            [3] = { "{name} drowned {n} times in a row. Swimming lessons, anyone?" },
            [5] = { "{name} has drowned {n} times in a row. The fish are starting to worry." },
        },
        other = {
            [2] = { "{name} died the same way. Again." },
            [3] = { "{name} died the same way {n} times in a row. A pattern is forming." },
            [5] = { "{name} has died the same way {n} times in a row. That's a tradition now." },
        },
    },
    -- 0.9.0 (10-11-2026, all ten ideas chosen by the user). {nth} = 200th, {other} = a guildie.
    -- All Time reaches 10, 25, 50, 100, 200, ... (steps chosen by the user)
    milestone = {
        plain = { "{name} just died for the {nth} time! Achievement unlocked: Professional Corpse",
            "Death number {n} for {name}! The Spirit Healer is baking a cake",
            "{name} reached {n} deaths. Somebody frame this one." },
    },
    -- a guildie died in the same fight and place just before
    together = {
        killer = { "{name} joined {other} in the afterlife, courtesy of {killer}. Together forever.",
            "{killer} took out {other} and {name}. Buy one, get one free." },
        plain = { "{name} joined {other} in the afterlife. Together forever.", "{other} and {name} died side by side. How romantic." },
    },
    -- this killer got another guildie today as well ({n} of us)
    plague = {
        killer = { "{killer} claims another Omen soul: {name}. That's {n} of us today.",
            "{killer} has now killed {n} Omen members today. {name} is the latest." },
    },
    -- the first death in more than 3 days ({n} days, chosen by the user)
    clean = {
        plain = { "{name} died for the first time in {n} days. It was nice while it lasted.",
            "{name}'s {n}-day survival streak is over." },
    },
    -- the first death after a level-up this session ({n} = the new level)
    levelup = {
        plain = { "{name} dinged {n} and celebrated by dying", "{name} hit level {n} and immediately tested it. It failed." },
    },
    -- from full health to dead in one hit (own death recap)
    oneshot = {
        killer = { "{killer} took {name} from full health to dead in one hit", "{name} was one-shot by {killer}. Didn't even see it coming." },
    },
    -- mixed into the usual lines, for the class of who died
    class = {
        WARRIOR = { killer = { "{name} charged {killer}. {killer} charged back." }, plain = { "{name} raged all the way to the graveyard" } },
        PALADIN = { killer = { "{name}'s bubble was on cooldown vs {killer}" }, plain = { "{name} forgot Divine Shield exists", "Even the Light could not save {name}" } },
        HUNTER = { killer = { "{name}'s Feign Death did not fool {killer}", "{name}'s pet watched {killer} do it" }, plain = { "{name}'s pet is looking for a new owner" } },
        ROGUE = { killer = { "{name} vanished. Just not from {killer}" }, plain = { "{name} went into stealth. Permanently." } },
        PRIEST = { killer = { "{name} forgot to shield themselves vs {killer}" }, plain = { "{name} ran out of mana and out of life" } },
        SHAMAN = { killer = { "{name}'s totems did nothing against {killer}" }, plain = { "{name}'s totems are still standing. {name} is not." } },
        MAGE = { killer = { "Blink did not take {name} far enough from {killer}" }, plain = { "{name} blinked straight into the afterlife" } },
        WARLOCK = { killer = { "{name}'s demon survived {killer}. {name} did not." }, plain = { "{name} paid for that Life Tap with a life" } },
        DRUID = { killer = { "{name} shapeshifted into a corpse vs {killer}" }, plain = { "{name} turned into a tree. A dead one." } },
    },
    generic = {
        plain = { "{name} bit the dust", "{name} is taking a dirt nap", "{name} joined the Spirit Healer fan club",
            "{name} is now a ghost. Spooky.", "Pour one out for {name}", "{name} took a shortcut to the graveyard",
            "{name} has left the land of the living (temporarily)" },
    },
}

-- Kinds of damage from the death recap (environmentalType, shown as "Falling", "Lava", ...).
local ENV = { Falling = "fall", Drowning = "drown", Lava = "lava", Fire = "lava", Fatigue = "fatigue", Slime = "slime" }

-- Which set fits this death.
function Lines.Situation(rec)
    if not rec.k and rec.s and ENV[rec.s] then return ENV[rec.s] end
    local it = rec.it or "none"
    if it == "pvp" or it == "arena" then return "pvp" end
    if it == "raid" then return "raid" end
    if it == "party" then return "dungeon" end
    if rec.k then
        -- kt = how the game coloured the killer's level at the death (only known to who died)
        if rec.kt == "skull" or rec.kt == "red" then return "above" end
        if rec.kt == "gray" then return "gray" end
        return "world"
    end
    return "generic"
end

-- "1st", "2nd", "3rd", "4th", "11th", "200th"
function Lines.Nth(n)
    local last, two = n % 10, n % 100
    local suffix = (two >= 11 and two <= 13) and "th" or last == 1 and "st" or last == 2 and "nd" or last == 3 and "rd" or "th"
    return n .. suffix
end

-- vars: a number ({n}, as before 0.9.0) or { n = ..., other = ... }.
function Lines.Render(template, name, killer, vars)
    if type(vars) ~= "table" then vars = { n = vars } end
    local n = vars.n
    return (template:gsub("{name}", function() return name end):gsub("{killer}", function() return killer or "" end)
        :gsub("{nth}", function() return type(n) == "number" and Lines.Nth(n) or "" end)
        :gsub("{n}", function() return tostring(n or "") end)
        :gsub("{other}", function() return vars.other or "" end))
end

-- What the streak looks at: the killer, else a kind of damage from the recap (Falling, Lava...).
local function StreakKey(r)
    if r.k then return "k:" .. r.k end
    if r.s and ENV[r.s] then return "s:" .. r.s end
end

-- How many deaths in a row (this one included) had the same killer or cause, on the same day.
function Lines.Streak(rec, owner, book)
    local key = StreakKey(rec)
    if not key or not owner or type(rec.t) ~= "number" then return 1 end
    book = book or (ns.Book and ns.Book())
    local p = book and book.players[owner]
    if not p then return 1 end
    local from = ns.Data.PeriodStart("day", rec.t)
    local before = {}
    for t, r in pairs(p.deaths) do
        if t < rec.t and t >= from then before[#before + 1] = r end
    end
    table.sort(before, function(a, b) return a.t > b.t end)
    local n = 1
    for _, r in ipairs(before) do
        if StreakKey(r) ~= key then break end
        n = n + 1
    end
    return n
end

-- The streak list for n deaths in a row, nil below 2.
function Lines.StreakList(rec, n)
    if n < 2 then return nil end
    local set = Lines.SETS.streak[rec.k and "killer" or ENV[rec.s]] or Lines.SETS.streak.other
    return set[n >= 5 and 5 or n >= 3 and 3 or 2]
end

-- All Time of the owner up to and including this death: the game's statistic (without battlegrounds)
-- plus the deaths after it was read, or the deaths the addon saw if that is more (as the leaderboard).
function Lines.AllTime(rec, owner, book)
    local p = book and owner and book.players[owner]
    if not p or type(rec.t) ~= "number" or not ns.Data.InScope(rec, nil) then return nil end
    local seen, after = 0, 0
    local st = p.stat
    for t, r in pairs(p.deaths) do
        if t <= rec.t and ns.Data.InScope(r, nil) then
            seen = seen + 1
            if st and t > st.at then after = after + 1 end
        end
    end
    local fromStat = st and (st.total - (st.bg or 0) + after) or 0
    return math.max(seen, fromStat)
end

Lines.MILESTONES = { [10] = true, [25] = true, [50] = true } -- then every 100 (chosen by the user)
function Lines.IsMilestone(n)
    return type(n) == "number" and (Lines.MILESTONES[n] or (n >= 100 and n % 100 == 0)) or false
end

-- A guildie who died in the same fight (since rec.fs, when my fight began; own deaths only) and
-- the same place, before me: their name.
function Lines.Together(rec, owner, book)
    if type(rec.fs) ~= "number" or not book then return nil end
    local best, bestT
    for name, p in pairs(book.players) do
        if name ~= owner and ns.Data.Shown(name) then
            for t, r in pairs(p.deaths) do
                local here = rec.id and r.id == rec.id or (not rec.id and not r.id and r.z == rec.z)
                if t >= rec.fs and t <= rec.t and here and (not bestT or t > bestT) then best, bestT = name, t end
            end
        end
    end
    return best
end

-- How many of us this killer got today, this death included (only when someone else is among them).
function Lines.Plague(rec, owner, book)
    if not rec.k or type(rec.t) ~= "number" or not book then return 0 end
    local from, who, others = ns.Data.PeriodStart("day", rec.t), {}, 0
    for name, p in pairs(book.players) do
        if ns.Data.Shown(name) or name == owner then
            for t, r in pairs(p.deaths) do
                if t >= from and t <= rec.t and r.k == rec.k and not who[name] then
                    who[name] = true
                    if name ~= owner then others = others + 1 end
                end
            end
        end
    end
    return others > 0 and (others + 1) or 0
end

-- Days since the death before this one, when that is more than CLEAN_DAYS (else nil).
Lines.CLEAN_DAYS = 3 -- chosen by the user (10-11-2026)
function Lines.CleanDays(rec, owner, book)
    local p = book and owner and book.players[owner]
    if not p or type(rec.t) ~= "number" then return nil end
    local prev
    for t in pairs(p.deaths) do
        if t < rec.t and (not prev or t > prev) then prev = t end
    end
    if not prev then return nil end
    local days = math.floor((rec.t - prev) / 86400)
    return (rec.t - prev > Lines.CLEAN_DAYS * 86400) and days or nil
end

-- The special line that fits, first in this order (one line per death): milestone, together,
-- streak, plague, clean, level-up, one-shot. Returns list, named, vars; nil when none fits.
function Lines.Special(rec, name, book)
    local S = Lines.SETS
    local function pick(set, vars)
        if rec.k and set.killer then return set.killer, true, vars end
        if set.plain then return set.plain, false, vars end
    end
    local all = Lines.AllTime(rec, name, book)
    if Lines.IsMilestone(all) then return S.milestone.plain, false, { n = all } end
    local other = Lines.Together(rec, name, book)
    if other then return pick(S.together, { other = other }) end
    local n = Lines.Streak(rec, name, book)
    local streak = Lines.StreakList(rec, n)
    if streak then return streak, rec.k ~= nil, { n = n } end
    local plague = Lines.Plague(rec, name, book)
    if plague >= 2 then return S.plague.killer, true, { n = plague } end
    local days = Lines.CleanDays(rec, name, book)
    if days then return S.clean.plain, false, { n = days } end
    if type(rec.lu) == "number" then return S.levelup.plain, false, { n = rec.lu } end
    if rec.os and rec.k then return S.oneshot.killer, true, {} end
end

-- A line for this death, whether it already names the killer, the template it came from, and its
-- values ({n}, {other}) for Render.
function Lines.For(rec, name, book)
    book = book or (ns.Book and ns.Book())
    local list, named, vars = Lines.Special(rec, name, book)
    if not list then
        vars = {}
        local situation = Lines.Situation(rec)
        local set = Lines.SETS[situation]
        local role = set.roles and rec.r and set.roles[rec.r]
        -- class lines mix in, not for falls, lava and other kinds of damage
        local envKind = not rec.k and rec.s and ENV[rec.s]
        local class = not envKind and Lines.SETS.class[rec.c or ""] or nil
        list, named = Lines.SETS.generic.plain, false
        if rec.k and set.killer then
            list, named = set.killer, true
            if role and role.killer then list = Lines.Merge(list, role.killer) end
            if class and class.killer then list = Lines.Merge(list, class.killer) end
        elseif set.plain then
            list = set.plain
            if role and role.plain then list = Lines.Merge(list, role.plain) end
            if class and class.plain then list = Lines.Merge(list, class.plain) end
        elseif class and class.plain then
            list = Lines.Merge(list, class.plain)
        end
    end
    local template = list[math.random(#list)]
    return Lines.Render(template, name, rec.k, vars), named, template, vars
end

function Lines.Merge(a, b)
    local out = {}
    for _, v in ipairs(a) do out[#out + 1] = v end
    for _, v in ipairs(b) do out[#out + 1] = v end
    return out
end

-- What follows the line: " - to Hogger (Rend) in Elwynn Forest", without the killer if the line has it.
function Lines.Detail(rec, namedKiller)
    local cause
    if rec.k and not namedKiller then
        cause = "to " .. rec.k .. (rec.s and (" (" .. rec.s .. ")") or "")
    elseif rec.k and rec.s then
        cause = "by " .. rec.s
    elseif not rec.k and rec.s and not ENV[rec.s] then
        cause = "to " .. rec.s
    end
    local parts = {}
    if cause then parts[#parts + 1] = cause end
    if rec.z then parts[#parts + 1] = "in " .. rec.z end
    return table.concat(parts, " ")
end
