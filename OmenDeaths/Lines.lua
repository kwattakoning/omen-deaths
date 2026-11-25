-- Omen Deaths: a funny line that fits how someone died.
-- {name} = who died, {killer} = what killed them, {n} = how many times in a row (streak lines).
-- {NAME}, {KILLER} = the same in capitals (the loudest streak lines).
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
        -- 0.9.6: role lines outside dungeons too (wish of the user, 21-11-2026)
        roles = {
            tank = {
                killer = { "{killer} went through {name} and is now looking at the rest of the raid" },
                plain = { "Main tank down! {name} has delegated aggro to whoever is closest" },
            },
            healer = {
                killer = { "{killer} found the healer. {name}'s raid frames send their condolences" },
                plain = { "{name} stopped healing. Raid frames are turning a worrying shade of red" },
            },
            dps = {
                killer = { "{name} was busy parsing and did not notice {killer}" },
                plain = { "{name} was top DPS right up until the floor turned purple" },
            },
        },
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
        roles = {
            tank = { killer = { "{name} tried to tank {killer} with nobody watching. Nobody healed either." } },
            healer = { killer = { "{name} tried to heal through {killer}. Solo. With a mace." } },
            dps = { killer = { "{name} looked around for a tank. {killer} did not wait." } },
        },
    },
    -- open world, killer far above my level: red or skull, as the game colours its level
    above = {
        killer = { "{name} picked a fight way above their pay grade: {killer}",
            "{name} saw the level of {killer} and went for it anyway", "{killer} was a few levels out of {name}'s league" },
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
            [4] = { "{name} keeps going back to {killer}. This is no longer a fight, it's a relationship." },
            [5] = { "{KILLER} OWNS {NAME} NOW. Somebody stop this.",
                "{name} has died to {killer} {n} times in a row. At this point {killer} should get a guild invite.",
                "{killer} has claimed {name} {n} times in a row. Somebody stop this." },
            [10] = { "{name} has died to {killer} {n} times in a row. {killer} has been promoted to Guild Master." },
        },
        fall = {
            [2] = { "{name} fell to their death. Again. The stairs are right there." },
            [3] = { "{name} fell to their death {n} times in a row. Gravity: undefeated." },
            [4] = { "{name} fell again. The ground has started saving them a spot." },
            [5] = { "{name} has fallen to their death {n} times in a row. Wings are not included." },
            [10] = { "{name} has fallen to their death {n} times in a row. GRAVITY HAS BEEN PROMOTED TO GUILD MASTER." },
        },
        lava = {
            [2] = { "{name} went for another lava bath. They clearly like it warm." },
            [3] = { "{name} took lava bath number {n} in a row. Somebody hide the lava." },
            [4] = { "{name} is back in the lava. They have a favourite spot now." },
            [5] = { "{name} has gone for a lava bath {n} times in a row. It's a lifestyle now." },
            [10] = { "{name} has gone for a lava bath {n} times in a row. THE LAVA NOW PAYS RENT TO {NAME}." },
        },
        drown = {
            [2] = { "{name} forgot to breathe. Again. Gills not included." },
            [3] = { "{name} drowned {n} times in a row. Swimming lessons, anyone?" },
            [4] = { "{name} drowned again. The fish know them by name now." },
            [5] = { "{name} has drowned {n} times in a row. The fish are starting to worry." },
            [10] = { "{name} has drowned {n} times in a row. THE FISH HAVE ELECTED {NAME} AS THEIR KING." },
        },
        other = {
            [2] = { "{name} died the same way. Again." },
            [3] = { "{name} died the same way {n} times in a row. A pattern is forming." },
            [4] = { "{name} died the same way again. Scientists are taking notes." },
            [5] = { "{name} has died the same way {n} times in a row. That's a tradition now." },
            [10] = { "{name} has died the same way {n} times in a row. THIS IS NOW A GUILD HOLIDAY." },
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
    -- 0.9.6: came back at the Spirit Healer (asked + Resurrection Sickness, measured 2 of 20 returns)
    spirit = {
        plain = { "{name} paid the Spirit Healer rather than walk. Shameful.",
            "{name} looked at the corpse run and chose Resurrection Sickness instead",
            "{name} took the Spirit Healer's deal. Their gear will remember this." },
    },
    -- 0.9.6: passing someone in the All Time top 3, a second line in guild chat
    rank = {
        top3 = { "[ALL TIME TOP 3] {name} passes {other} with death number {n}. This one goes in the guild archives." },
        [2] = { "[ALL TIME #2] {name} overtakes {other} with {n} deaths. Only {leader} stands between them and eternal shame." },
        [1] = { "[ALL TIME #1] ALL HAIL {NAME}! {n} deaths, {other} has been dethroned. Omen has a new Lord of the Graveyard." },
    },
    -- mixed into the usual lines, for the class of who died
    class = {
        WARRIOR = { killer = { "{name} charged {killer}. {killer} charged back.", "{name} saved Shield Wall for later. There was no later vs {killer}" },
            plain = { "{name} raged all the way to the graveyard", "{name} ran out of rage and then out of health" } },
        PALADIN = { killer = { "{name}'s bubble was on cooldown vs {killer}", "{name} tried to judge {killer}. {killer} judged back." },
            plain = { "{name} forgot Divine Shield exists", "Even the Light could not save {name}" } },
        HUNTER = { killer = { "{name}'s Feign Death did not fool {killer}", "{name}'s pet watched {killer} do it", "{name} kited {killer} straight into a wall" },
            plain = { "{name}'s pet is looking for a new owner", "{name}'s pet held aggro for a full two seconds" } },
        ROGUE = { killer = { "{name} vanished. Just not from {killer}", "{name} used Evasion. {killer} used hitting them anyway." },
            plain = { "{name} went into stealth. Permanently.", "{name} backstabbed the air and the air won" } },
        PRIEST = { killer = { "{name} forgot to shield themselves vs {killer}", "{killer} walked right through {name}'s Power Word: Shield" },
            plain = { "{name} ran out of mana and out of life", "{name} prayed. Nobody picked up." } },
        SHAMAN = { killer = { "{name}'s totems did nothing against {killer}", "{name} dropped every totem they had and {killer} stepped over them" },
            plain = { "{name}'s totems are still standing. {name} is not.", "{name}'s Reincarnation is on cooldown. So is {name}." } },
        MAGE = { killer = { "Blink did not take {name} far enough from {killer}", "{name} tried to polymorph {killer}. {killer} declined." },
            plain = { "{name} blinked straight into the afterlife", "{name} had Ice Block ready. {name} also had other plans, apparently." } },
        WARLOCK = { killer = { "{name}'s demon survived {killer}. {name} did not.", "{name} tried to fear {killer}. {killer} was not afraid." },
            plain = { "{name} paid for that Life Tap with a life", "{name}'s Soulstone was in the other bag" } },
        DRUID = { killer = { "{name} shapeshifted into a corpse vs {killer}", "{name} went bear, then cat, then corpse vs {killer}" },
            plain = { "{name} turned into a tree. A dead one.", "{name} had nine forms to choose from and picked corpse" } },
    },
    -- 0.9.6: class and role together, only in dungeons and raids (they talk about a group)
    classRole = {
        WARRIOR = {
            tank = { killer = { "{killer} got through {name}'s shield and the armor behind it" }, plain = { "{name}'s Shield Wall lasted longer than {name} did" } },
            dps = { killer = { "{name} hit {killer} really hard for about four seconds" }, plain = { "{name} brought two weapons and zero survival" } },
        },
        PALADIN = {
            tank = { killer = { "{name}'s Divine Shield worked perfectly. {killer} just went for the healer, then came back." }, plain = { "{name} consecrated the floor they are now lying on" } },
            healer = { killer = { "{name} was busy flashing everyone else when {killer} showed up" }, plain = { "{name} had Lay on Hands ready and gave it to the wrong person: everyone else" } },
            dps = { killer = { "{name} went in swinging at {killer} and forgot to bubble" }, plain = { "{name} brought a two-hander and no plan" } },
        },
        DRUID = {
            tank = { killer = { "{name} went bear. {killer} went hunting." }, plain = { "{name}'s bear form has gone into hibernation" } },
            healer = { killer = { "{killer} walked through {name}'s HoTs like they were not there" }, plain = { "{name} kept everyone's HoTs rolling, except their own" } },
            dps = { killer = { "{name} was mid-rotation when {killer} ended it" }, plain = { "{name} ran out of energy and out of options" } },
        },
        PRIEST = {
            healer = { killer = { "{name} had a Renew on everyone but themselves vs {killer}" }, plain = { "{name} healed the whole group. The group did not return the favour." } },
            dps = { killer = { "{name} tried to mind flay {killer}. {killer} flayed back." }, plain = { "{name} went Shadow and took the darkness a bit too literally" } },
        },
        SHAMAN = {
            healer = { killer = { "{killer} kicked over {name}'s Mana Spring and kept going" }, plain = { "{name} chain healed everyone but the last link: themselves" } },
            dps = { killer = { "{name} threw lightning at {killer}. {killer} threw {name}." }, plain = { "{name} grounded themselves. Six feet deep." } },
        },
    },
    -- Deathless (0.9.11, wish of the user): every 10 levels without ever dying, each step bigger.
    -- {n} = the level. No pronouns (the user's choice: none, else "their").
    deathless = {
        [10] = { "Achievement: {name} reached level 10 without dying. A careful start.",
            "Achievement: {name} reached level 10 without a single death. The Spirit Healer is still waiting for a first visit." },
        [20] = { "Achievement: {name} reached level 20 deathless. Twenty levels, zero corpse runs.",
            "Achievement: {name} reached level 20 without dying. The graveyard has started asking questions." },
        [30] = { "Achievement: {name} reached level 30 without dying! Halfway there, and not a scratch.",
            "Achievement: {name} hit level 30 deathless! Even the murlocs have given up." },
        [40] = { "ACHIEVEMENT: {name} reached level 40 WITHOUT DYING! Mounted, armed and still never seen a graveyard.",
            "ACHIEVEMENT: {name} reached level 40 deathless! The Spirit Healer has filed a missing person report." },
        [50] = { "ACHIEVEMENT: {name} reached level 50 WITHOUT A SINGLE DEATH! Ten more levels. The whole guild is watching. No pressure.",
            "ACHIEVEMENT: {name} reached level 50 deathless! Legends are whispered in Orgrimmar and Stormwind alike." },
        [60] = { "LEGEND: {name} reached level 60 WITHOUT DYING ONCE!" },
    },
    deathless60 = { "60 levels. Zero deaths. Bow down, mortals. {name} enters the Hall of the Deathless." },
    -- The very first death of a character (0.9.11): always its own line, bigger after a longer run.
    -- {n} = the level, {levels} = the levels it stayed alive.
    first = {
        low = { killer = { "First blood: {name} died for the first time at level {n}, to {killer}. Welcome to the club." },
            plain = { "First blood: {name} died for the first time at level {n}. Welcome to the club." } },
        high = { killer = { "The deathless run is over: {name} died for the first time at level {n}, to {killer}. {levels} levels of perfection, gone." },
            plain = { "The deathless run is over: {name} died for the first time at level {n}. {levels} levels of perfection, gone." } },
        close = { killer = { "SO CLOSE: {name} died for the first time at level {n}, to {killer}, one level before Deathless 60. The guild will never forget." },
            plain = { "SO CLOSE: {name} died for the first time at level {n}, one level before Deathless 60. The guild will never forget." } },
        -- already Deathless 60: the fall of a legend
        top = { killer = { "A LEGEND FALLS: {name}, Deathless 60, died for the first time, to {killer}. The Hall of Fame has one name less." },
            plain = { "A LEGEND FALLS: {name}, Deathless 60, died for the first time. The Hall of Fame has one name less." } },
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
        :gsub("{other}", function() return vars.other or "" end)
        :gsub("{leader}", function() return vars.leader or "" end)
        :gsub("{levels}", function() return tostring(vars.levels or "") end)
        :gsub("{NAME}", function() return Lines.Loud(name) end)
        :gsub("{KILLER}", function() return Lines.Loud(killer or "") end))
end

-- In capitals, leaving a colour code around the text intact (the popup's chat line colours the name).
function Lines.Loud(s)
    local open, body, close = s:match("^(|c%x%x%x%x%x%x%x%x)(.-)(|r)$")
    if open then return open .. body:upper() .. close end
    return s:upper()
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
    local step = n >= 10 and 10 or n >= 5 and 5 or n
    -- 0.9.6: the count up front, so a streak stands out in guild chat (no colours there)
    local tag = "[{n}x STREAK" .. (n >= 10 and "!!!" or n >= 5 and "!" or "") .. "] "
    local list = {}
    for i, template in ipairs(set[step]) do list[i] = tag .. template end
    return list
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

-- Did this death move me up the All Time board? Returns { from, to, n, other, leader } or nil.
-- Only really passing counts: someone with as many deaths as me stays ahead of me, in both the
-- rank before and after (the board itself orders equal counts by name). Not on my first death.
function Lines.RankUp(rec, owner, book)
    if not book or not owner then return nil end
    local mine = Lines.AllTime(rec, owner, book)
    if not mine or mine < 2 then return nil end
    local ahead, passed = {}, {}
    for name in pairs(book.players) do
        if name ~= owner and ns.Data.Shown(name) then
            local n = Lines.AllTime({ t = rec.t, it = "none" }, name, book) or 0
            if n >= mine then ahead[#ahead + 1] = { name = name, n = n }
            elseif n == mine - 1 then passed[#passed + 1] = name end
        end
    end
    if #passed == 0 then return nil end
    table.sort(passed)
    table.sort(ahead, function(a, b)
        if a.n ~= b.n then return a.n > b.n end
        return a.name < b.name
    end)
    local to = #ahead + 1
    return { from = to + #passed, to = to, n = mine, other = passed[1], leader = ahead[1] and ahead[1].name }
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

-- The first death (0.9.11): low under 30, high from 30, close at 59 (one level before Deathless 60).
-- 30 is where the deathless popups start; the user approved these steps (25-11-2026).
-- At 60 (already Deathless 60): "top".
Lines.FIRST_HIGH, Lines.FIRST_CLOSE, Lines.FIRST_TOP = 30, 59, 60
function Lines.FirstTier(level)
    if level >= Lines.FIRST_TOP then return "top" end
    if level >= Lines.FIRST_CLOSE then return "close" end
    if level >= Lines.FIRST_HIGH then return "high" end
    return "low"
end

-- Is this (not yet stored) death the character's very first? Only when the game's own statistic
-- is known: without it, someone who got the addon late would get a false "first death".
-- AllTime = the statistic without battlegrounds plus the deaths seen after it was read.
function Lines.IsFirst(rec, owner, book)
    local p = book and owner and book.players[owner]
    if not p or not p.stat then return false end
    return Lines.AllTime(rec, owner, book) == 0
end

-- The special line that fits, first in this order (one line per death): milestone, together,
-- streak, plague, clean, level-up, one-shot. Returns list, named, vars; nil when none fits.
function Lines.Special(rec, name, book)
    local S = Lines.SETS
    local function pick(set, vars)
        if rec.k and set.killer then return set.killer, true, vars end
        if set.plain then return set.plain, false, vars end
    end
    -- the very first death goes before everything (0.9.11)
    if rec.fd then
        local lv = type(rec.l) == "number" and rec.l or 1
        local set = S.first[Lines.FirstTier(lv)]
        local list, named = pick(set, nil)
        return list, named, { n = lv, levels = math.max(0, lv - 1) }
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
        local inGroup = rec.it == "party" or rec.it == "raid"
        local combo = inGroup and not envKind and rec.r and (Lines.SETS.classRole[rec.c or ""] or {})[rec.r] or nil
        list, named = Lines.SETS.generic.plain, false
        if rec.k and set.killer then
            list, named = set.killer, true
            if role and role.killer then list = Lines.Merge(list, role.killer) end
            if class and class.killer then list = Lines.Merge(list, class.killer) end
            if combo and combo.killer then list = Lines.Merge(list, combo.killer) end
        elseif set.plain then
            list = set.plain
            if role and role.plain then list = Lines.Merge(list, role.plain) end
            if class and class.plain then list = Lines.Merge(list, class.plain) end
            if combo and combo.plain then list = Lines.Merge(list, combo.plain) end
        elseif class and class.plain then
            list = Lines.Merge(list, class.plain)
        end
    end
    local template = list[math.random(#list)]
    return Lines.Render(Lines.WithLevel(template, rec), name, rec.k, vars), named, template, vars
end

-- The killer's level as the game shows it: -1 = "??" (a skull mob).
function Lines.Level(kl)
    if type(kl) ~= "number" then return nil end
    return kl == -1 and "??" or tostring(kl)
end

-- The level goes right after the first time the line names the killer (0.9.11, asked by the guild):
-- "Hogger (lvl 12) says hi to Bob". Lines without the killer get it in Lines.Detail.
function Lines.WithLevel(template, rec)
    local lvl = rec.k and Lines.Level(rec.kl)
    if not lvl then return template end
    local a = template:find("{killer}", 1, true)
    local b = template:find("{KILLER}", 1, true)
    local at = a and b and math.min(a, b) or a or b
    if not at then return template end
    return template:sub(1, at + 7) .. " (lvl " .. lvl .. ")" .. template:sub(at + 8)
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
        local lvl = Lines.Level(rec.kl)
        local inside = lvl and ("lvl " .. lvl .. (rec.s and (", " .. rec.s) or "")) or rec.s
        cause = "to " .. rec.k .. (inside and (" (" .. inside .. ")") or "")
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
