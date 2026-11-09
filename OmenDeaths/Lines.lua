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

function Lines.Render(template, name, killer, n)
    return (template:gsub("{name}", function() return name end):gsub("{killer}", function() return killer or "" end)
        :gsub("{n}", function() return tostring(n or "") end))
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

-- A line for this death, whether it already names the killer, the template it came from, and the
-- number in a row ({n}).
function Lines.For(rec, name, book)
    local n = Lines.Streak(rec, name, book)
    local list, named = Lines.StreakList(rec, n), rec.k ~= nil
    if not list then
        local set = Lines.SETS[Lines.Situation(rec)]
        local role = set.roles and rec.r and set.roles[rec.r]
        list, named = Lines.SETS.generic.plain, false
        if rec.k and set.killer then
            list, named = set.killer, true
            if role and role.killer then list = Lines.Merge(list, role.killer) end
        elseif set.plain then
            list = set.plain
            if role and role.plain then list = Lines.Merge(list, role.plain) end
        end
    end
    local template = list[math.random(#list)]
    return Lines.Render(template, name, rec.k, n), named, template, n
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
