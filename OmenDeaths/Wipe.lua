-- Omen Deaths: one guild chat summary per boss fight instead of a line per death.
--
-- Deaths between ENCOUNTER_START and ENCOUNTER_END get no line of their own. After the fight
-- one guildie posts the summary: everyone who was in the fight waits WAIT seconds (so the
-- deaths the game held back during the fight have arrived over the addon channel) plus a
-- random 0..RELAY_JITTER, then the first to go sends a claim "W|<boss>" on the addon channel
-- and posts; whoever hears a claim first stays quiet.
local _, ns = ...
local Wipe = {}
ns.Wipe = Wipe

Wipe.WAIT = 5            -- seconds after the fight (not measured, see CONTEXT.md)
Wipe.CLAIM_WINDOW = 120  -- a claim for the same boss within this many seconds counts as "already posted"
Wipe.KEEP = 5            -- recent fights remembered

local fights = {}        -- recent fights: { key, name, iid, z, start, stop, success }
local current
local claims = {}        -- key -> GetTime() a summary for that boss was claimed

-- Was this death inside a boss fight (one that is going on, or one of the recent ones)?
-- Only at the place of the fight: a fight whose end never came (08-11-2026, a guildie's open-world
-- death got no guild chat line; most likely cause) cannot swallow deaths elsewhere.
function Wipe.Covers(rec)
    for _, f in ipairs(fights) do
        local here = f.iid and rec.id == f.iid or (not f.iid and rec.z == f.z)
        if here and rec.t >= f.start and (not f.stop or rec.t <= f.stop + 1) then return true end
    end
    return false
end

-- The boss of the fight this death was in (same rules as Covers); nil when none or its name is unknown.
function Wipe.Boss(rec)
    for i = #fights, 1, -1 do
        local f = fights[i]
        local here = f.iid and rec.id == f.iid or (not f.iid and rec.z == f.z)
        if here and rec.t >= f.start and (not f.stop or rec.t <= f.stop + 1) then return f.name end
    end
end

function Wipe.Claimed(key)
    local at = claims[key]
    return at ~= nil and GetTime() - at < Wipe.CLAIM_WINDOW
end

function Wipe.HeardClaim(key)
    claims[key] = GetTime()
end

local WIPE_LINES = {
    "Wipe at {boss}! {n} brave {souls} fell: {names}",
    "{boss} 1, {guild} 0. Fallen: {names}",
    "Corpse run party after {boss}! {n} {souls} down: {names}",
}
local KILL_LINES = {
    "{boss} is down! It only cost {n} {lives}: {names}",
    "Victory over {boss}! A moment of silence for {names}",
}

-- Deaths in this fight, in the order they fell: names (once each) and the number of deaths.
function Wipe.Fallen(f)
    local book = ns.Book()
    local list = {}
    for name, p in pairs(book.players) do
        for _, r in pairs(p.deaths) do
            local here = f.iid and r.id == f.iid or (not f.iid and r.z == f.z)
            if here and r.t >= f.start and r.t <= f.stop + 1 then
                list[#list + 1] = { name = name, t = r.t }
            end
        end
    end
    table.sort(list, function(a, b)
        if a.t ~= b.t then return a.t < b.t end
        return a.name < b.name
    end)
    local names, seen = {}, {}
    for _, d in ipairs(list) do
        if not seen[d.name] then
            seen[d.name] = true
            names[#names + 1] = d.name
        end
    end
    return names, #list
end

-- The summary line, names cut off with "and N more" to stay within the chat limit.
function Wipe.Line(f, names, count, pick)
    pick = pick or function(list) return list[math.random(#list)] end
    local template = pick(f.success and KILL_LINES or WIPE_LINES)
    local function Build(shown)
        local text = table.concat(names, ", ", 1, shown)
        if shown < #names then text = text .. " and " .. (#names - shown) .. " more" end
        local line = template
            :gsub("{boss}", function() return f.name or f.z or "the boss" end)
            :gsub("{guild}", function() return ns.GuildName() or "us" end)
            :gsub("{n}", function() return tostring(count) end)
            :gsub("{souls}", function() return count == 1 and "soul" or "souls" end)
            :gsub("{lives}", function() return count == 1 and "life" or "lives" end)
            :gsub("{names}", function() return text end)
        return "[Omen Deaths] " .. line
    end
    for shown = #names, 1, -1 do
        local line = Build(shown)
        if #line <= ns.Toast.CHAT_MAX then return line end
    end
    return Build(1)
end

function Wipe.Summarize(f)
    if not ns.db or not ns.db.settings.guildChat or not ns.GuildName() then return end
    if Wipe.Claimed(f.key) then return end
    local names, count = Wipe.Fallen(f)
    if count == 0 then return end
    Wipe.HeardClaim(f.key)
    ns.Comm.SendRaw("W|" .. f.key)
    ns.Toast.Post(Wipe.Line(f, names, count))
end

ns.On("ENCOUNTER_START", function(id, name)
    id, name = ns.Safe(id), ns.Safe(name)
    local where = ns.Death.Where()
    current = {
        key = tostring(id or name or where.z or "?"),
        name = type(name) == "string" and name ~= "" and name or nil,
        iid = where.id, z = where.z, start = ns.Now(),
    }
    table.insert(fights, current)
    while #fights > Wipe.KEEP do table.remove(fights, 1) end
end)

ns.On("ENCOUNTER_END", function(_, _, _, _, success)
    local f = current
    if not f then return end
    current = nil
    f.stop = ns.Now()
    f.success = ns.Safe(success) == 1
    local wait = Wipe.WAIT + math.random() * ns.Comm.RELAY_JITTER
    if C_Timer and C_Timer.After then
        C_Timer.After(wait, function() Wipe.Summarize(f) end)
    else
        Wipe.Summarize(f)
    end
end)

-- Left the instance mid-fight (released, disconnected): the fight is over for us.
ns.On("PLAYER_ENTERING_WORLD", function()
    if current then
        current.stop = ns.Now()
        current = nil
    end
end)
