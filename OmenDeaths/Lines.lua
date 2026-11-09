-- Omen Deaths: a funny line that fits how someone died.
-- {name} = who died, {killer} = what killed them. Lines with {killer} are only used when it is known.
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
    dungeon = {
        killer = { "{name} found out why the tank goes first ({killer})", "{killer} cleared {name} from the dungeon",
            "{name} pulled {killer} a little too early" },
        plain = { "{name} pulled one mob too many", "{name} found out why the tank goes first" },
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

function Lines.Render(template, name, killer)
    return (template:gsub("{name}", function() return name end):gsub("{killer}", function() return killer or "" end))
end

-- A line for this death, whether it already names the killer, and the template it came from.
function Lines.For(rec, name)
    local set = Lines.SETS[Lines.Situation(rec)]
    local list, named = Lines.SETS.generic.plain, false
    if rec.k and set.killer then
        list, named = set.killer, true
    elseif set.plain then
        list = set.plain
    end
    local template = list[math.random(#list)]
    return Lines.Render(template, name, rec.k), named, template
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
