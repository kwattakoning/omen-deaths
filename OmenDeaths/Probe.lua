-- Omen Deaths: measurements only (0.9.5). Nothing is shown in the game; the results are in
-- OmenDeathsDB and tools\check-data.js prints them. Sent: only the result of a guild duel (0.9.7).
--
-- 1) Damage meter (boss fights plan, phase 0 in CONTEXT.md): after each fight, what the game's meter
--    gives for damage taken, avoidable damage taken and deaths. Per type: the session, how many
--    sources, the fields of the first source and of its first spell, and whether values are secret.
--    Types from Enum.DamageMeterType; when the enum lacks one, the number from warcraft.wiki.gg
--    (API 12.0.1: DamageTaken 7, AvoidableDamageTaken 8, Deaths 9; Deaths 9 is what this addon
--    already reads in Forever). Not proven in Forever: that is what this measures.
-- 2) Duels (user's question 14-11-2026: can duels be recognised?). Losing a duel is not a death
--    (no PLAYER_DEAD), so nothing counts it now. Measured: the game's duel events and the system
--    line "X has defeated Y in a duel" (DUEL_WINNER_KNOCKOUT) / "Y has fled from X in a duel"
--    (DUEL_WINNER_RETREAT): do they come, and are they readable or secret?
local _, ns = ...
local Probe = {}
ns.Probe = Probe

-- Samples kept. The first sample with sources of each meter type is kept apart for good (proof),
-- so a few recent ones are enough to see what changed (not measured).
Probe.KEEP = 5
Probe.DUEL_KEEP = 20 -- duel log entries (not measured: one duel gives about 2-4)
Probe.AROUND = 3     -- system lines kept from just before a duel ends, and taken after it
Probe.TYPES = { "DamageTaken", "AvoidableDamageTaken", "Deaths" }
Probe.FALLBACK = { DamageTaken = 7, AvoidableDamageTaken = 8, Deaths = 9 }
local SESSION_CURRENT = 1 -- as Death.lua (ForeverMeter uses it)
Probe.FIELDS_MAX = 300    -- bytes of a fields text in the saved data (only for reading it back)

local function Seen(v) return ns.Death.Seen(v) end

-- "name=value, ..." for the fields of a table, sorted; a secret or other value as Seen shows it.
function Probe.Fields(t)
    if ns.IsSecret(t) or type(t) ~= "table" then return Seen(t) end
    local out = {}
    for k, v in pairs(t) do out[#out + 1] = tostring(k) .. "=" .. Seen(v) end
    table.sort(out)
    return table.concat(out, ", "):sub(1, Probe.FIELDS_MAX)
end

local function Call(fn, ...)
    local ok, raw = pcall(fn, ...)
    if not ok then return nil, "error " .. tostring(raw):sub(1, 80) end
    return ns.Safe(raw), Seen(raw)
end

-- One meter type after a fight.
function Probe.MeterType(meter, ty)
    local e = { type = Seen(ty) }
    if type(meter) ~= "table" or type(meter.GetCombatSessionFromType) ~= "function" then
        e.session = "no meter"
        return e
    end
    local sess
    sess, e.session = Call(meter.GetCombatSessionFromType, SESSION_CURRENT, ty)
    if type(sess) ~= "table" then return e end
    e.fields = Probe.Fields(sess)
    local sources = ns.Safe(sess.combatSources)
    if type(sources) ~= "table" then return e end
    e.sources = #sources
    local first = ns.Safe(sources[1])
    if type(first) ~= "table" then return e end
    e.source1 = Probe.Fields(first)
    if type(meter.GetCombatSessionSourceFromType) == "function" then
        local det
        det, e.detail = Call(meter.GetCombatSessionSourceFromType, SESSION_CURRENT, ty, ns.Safe(first.sourceGUID))
        if type(det) == "table" then
            e.detailFields = Probe.Fields(det)
            local spells = ns.Safe(det.combatSpells)
            if type(spells) == "table" then
                e.spells = #spells
                e.spell1 = Probe.Fields(ns.Safe(spells[1]))
            end
        end
    end
    return e
end

function Probe.Meter(why)
    local db = ns.db
    if not db then return end
    local mp = type(db.meterProbe) == "table" and db.meterProbe or {}
    db.meterProbe = mp
    mp.proof = mp.proof or {}
    mp.samples = mp.samples or {}
    local meter = C_DamageMeter
    local enum = Enum and Enum.DamageMeterType
    local where = ns.Death.Where()
    local s = { t = ns.Now(), why = why, z = where.z, it = where.it, v = ns.VERSION }
    if type(meter) == "table" and type(meter.GetAvailableCombatSessions) == "function" then
        local _, seen = Call(meter.GetAvailableCombatSessions)
        s.sessions = seen
    end
    for _, name in ipairs(Probe.TYPES) do
        local ty = type(enum) == "table" and ns.Safe(enum[name]) or nil
        if ty == nil then ty = Probe.FALLBACK[name] end
        local e = Probe.MeterType(meter, ty)
        s[name] = e
        if (e.sources or 0) > 0 and not mp.proof[name] then
            mp.proof[name] = { t = s.t, why = why, z = s.z, it = s.it, e = e }
        end
    end
    mp.samples[#mp.samples + 1] = s
    while #mp.samples > Probe.KEEP do table.remove(mp.samples, 1) end
    if why == "encounter" then mp.lastEncounter = s end
end

local function Safely(fn, ...)
    local ok, err = pcall(fn, ...)
    if not ok then ns.NoteError(err, "probe") end
end

ns.On("PLAYER_LOGIN", function()
    if not ns.db then return end
    local mp = type(ns.db.meterProbe) == "table" and ns.db.meterProbe or {}
    ns.db.meterProbe = mp
    mp.enum = Probe.Fields(Enum and Enum.DamageMeterType)
    Probe.DuelStart()
end)
ns.On("PLAYER_REGEN_ENABLED", function() Safely(Probe.Meter, "combat") end)
ns.On("ENCOUNTER_END", function() Safely(Probe.Meter, "encounter") end)

---------------------------------------------------------------------------
-- Duels
---------------------------------------------------------------------------
-- A game format string as a Lua pattern: "%1$s has defeated %2$s in a duel" -> pattern plus the
-- order of the numbered parts ({1, 2}); "%s" counts up. nil for a missing or secret string.
function Probe.Pattern(fmt)
    if type(fmt) ~= "string" or ns.IsSecret(fmt) then return nil end
    local order, n = {}, 0
    local marked = fmt:gsub("%%(%d*)%$?s", function(d)
        n = n + 1
        order[#order + 1] = tonumber(d) or n
        return "\1"
    end)
    local p = marked:gsub("[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0"):gsub("\1", "(.+)")
    return "^" .. p .. "$", order
end

-- winner, loser of a duel line; nil when it is not one.
function Probe.DuelLine(text)
    if type(text) ~= "string" or ns.IsSecret(text) then return nil end
    for _, kind in ipairs({ "knockout", "retreat" }) do
        local pat = Probe.patterns and Probe.patterns[kind]
        if pat then
            local caps = { text:match(pat.p) }
            if #caps > 0 then
                local by = {}
                for i, idx in ipairs(pat.order) do by[idx] = caps[i] end
                return by[1], by[2], kind
            end
        end
    end
end

local function DuelLog(entry)
    local dp = ns.db and ns.db.duelProbe
    if not dp then return end
    entry.t = ns.Now()
    entry.gt = GetTime and math.floor(GetTime() * 100 + 0.5) / 100 or nil
    dp.log[#dp.log + 1] = entry
    while #dp.log > Probe.DUEL_KEEP do table.remove(dp.log, 1) end
end

local recentSystem = {} -- the last AROUND system lines (text as Seen), not saved
local after = 0         -- system lines still to take after a duel ended

function Probe.DuelStart()
    local dp = type(ns.db.duelProbe) == "table" and ns.db.duelProbe or {}
    ns.db.duelProbe = dp
    dp.log = dp.log or {}
    dp.strings = { knockout = Seen(_G.DUEL_WINNER_KNOCKOUT), retreat = Seen(_G.DUEL_WINNER_RETREAT) }
    Probe.patterns = {}
    for kind, name in pairs({ knockout = "DUEL_WINNER_KNOCKOUT", retreat = "DUEL_WINNER_RETREAT" }) do
        local p, order = Probe.Pattern(_G[name])
        if p then Probe.patterns[kind] = { p = p, order = order } end
    end
end

Probe.DUEL_EVENTS = { "DUEL_REQUESTED", "DUEL_INBOUNDS", "DUEL_OUTOFBOUNDS", "DUEL_FINISHED" }
for _, ev in ipairs(Probe.DUEL_EVENTS) do
    ns.On(ev, function(...)
        if not (ns.db and ns.db.duelProbe) then return end
        local args = {}
        for i = 1, select("#", ...) do args[#args + 1] = Seen((select(i, ...))) end
        local entry = { ev = ev, args = table.concat(args, ", ") }
        if ev == "DUEL_FINISHED" then
            entry.before = table.concat(recentSystem, " / ")
            after = Probe.AROUND
        end
        DuelLog(entry)
    end)
end

-- 0.9.7 (user: everyone should be able to measure, not only next to me): a duel I fought myself
-- against a guildie goes to the guild. Bystanders and duels with strangers report nothing.
Probe.DUEL_CODE = { knockout = "K", retreat = "F" }
function Probe.ReportDuel(winner, loser, kind)
    local me = ns.MyName()
    if not me or not ns.GuildName() then return end
    local iWon, iLost = ns.SameChar(winner, me), ns.SameChar(loser, me)
    if iWon == iLost then return end
    local other, otherLevel = ns.Comm.RosterMember(iWon and loser or winner)
    if not other then return end
    local myLevel = ns.Call(UnitLevel, "player")
    if type(myLevel) ~= "number" then myLevel = nil end
    local d = { by = me, w = iWon and me or other, l = iWon and other or me, k = Probe.DUEL_CODE[kind], t = ns.Now(),
        wl = iWon and myLevel or otherLevel, ll = iWon and otherLevel or myLevel }
    if ns.Data.AddDuel(ns.Book(), d) then ns.Comm.SendDuel(d) end
end

function Probe.System(text)
    if not (ns.db and ns.db.duelProbe) then return end
    local seen = Seen(text)
    local winner, loser, kind = Probe.DuelLine(text)
    if winner then
        DuelLog({ ev = "line", kind = kind, winner = winner, loser = loser })
        Probe.ReportDuel(winner, loser, kind)
    elseif after > 0 then
        DuelLog({ ev = "system after", text = seen })
    end
    if after > 0 then after = after - 1 end
    recentSystem[#recentSystem + 1] = seen
    while #recentSystem > Probe.AROUND do table.remove(recentSystem, 1) end
end
ns.On("CHAT_MSG_SYSTEM", function(text) Safely(Probe.System, text) end)
