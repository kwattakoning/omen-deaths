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
    if ns.Duels.Add(ns.Book(), d, true) then ns.Comm.SendDuel(d) end
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

---------------------------------------------------------------------------
-- 3) Raid tools (24-11-2026, user: a Raids tab that shows each player where to stand). Can an addon
--    in Forever see where a player stands inside a dungeon or raid (in normal WoW it cannot), are
--    there world markers, and are the functions to invite and sort raid groups there? It only looks:
--    nothing is called that changes the group or places a marker. Every guildie measures: one short
--    report per instance type (party, raid) and version goes to the guild (G|), sent again at my
--    login and with the answer to a guildie's login, so who logs in later gets it too.
---------------------------------------------------------------------------
Probe.POS_KEEP = 8  -- samples kept (not measured: one run gives about 2-6)
Probe.POS_DELAY = 5 -- seconds after entering: the instance map is known by then (not measured)
Probe.MARK_FNS = { "PlaceRaidMarker", "ClearRaidMarker", "IsRaidMarkerActive", "SetRaidTarget" }
Probe.GROUP_FNS = { "InviteUnit", "C_PartyInfo.InviteUnit", "SetRaidSubgroup", "SwapRaidSubgroup",
    "ConvertToRaid", "C_PartyInfo.ConvertToRaid" }
Probe.MARKERS = 8   -- world marker slots in normal WoW

local function Lookup(path)
    local t = _G
    for part in path:gmatch("[^%.]+") do
        if type(t) ~= "table" then return nil end
        t = t[part]
    end
    return t
end

-- "1" per function that exists, "0" per missing one, in list order.
function Probe.Flags(list)
    local out = {}
    for i, path in ipairs(list) do out[i] = type(Lookup(path)) == "function" and "1" or "0" end
    return table.concat(out)
end

-- Codes for one position: y = numbers, n = nothing, s = secret, e = error, - = no such function.
local function Numbers(...)
    local code, parts = "n", {}
    for i = 1, select("#", ...) do
        local v = select(i, ...)
        if ns.IsSecret(v) then
            code = "s"
            parts[#parts + 1] = "secret"
        elseif type(v) == "number" then
            if code == "n" then code = "y" end
            parts[#parts + 1] = v == math.floor(v) and tostring(v) or ("%.3f"):format(v)
        else
            parts[#parts + 1] = tostring(v)
        end
    end
    return code, table.concat(parts, ",")
end

function Probe.UnitPos(unit)
    if type(UnitPosition) ~= "function" then return "-", "no function" end
    local function After(ok, ...)
        if not ok then return "e", "error " .. tostring((...)):sub(1, 60) end
        return Numbers(...)
    end
    return After(pcall(UnitPosition, unit))
end

function Probe.MapPos(unit)
    local M = C_Map
    if type(M) ~= "table" or type(M.GetBestMapForUnit) ~= "function" or type(M.GetPlayerMapPosition) ~= "function" then
        return "-", "no function"
    end
    local okm, map = pcall(M.GetBestMapForUnit, unit)
    if not okm then return "e", "map error" end
    if ns.IsSecret(map) then return "s", "map secret" end
    if type(map) ~= "number" then return "n", "no map" end
    local okp, pos = pcall(M.GetPlayerMapPosition, map, unit)
    if not okp then return "e", "map " .. map .. ": error" end
    if ns.IsSecret(pos) then return "s", "map " .. map .. ": secret" end
    if pos == nil then return "n", "map " .. map .. ": nothing" end
    local okx, x, y = pcall(function() return pos:GetXY() end)
    if not okx then return "e", "map " .. map .. ": no GetXY" end
    if ns.IsSecret(x) or ns.IsSecret(y) then return "s", "map " .. map .. ": secret" end
    if type(x) ~= "number" or type(y) ~= "number" then return "n", "map " .. map .. ": nothing" end
    return "y", ("map %d: %.4f,%.4f"):format(map, x, y)
end

-- Another player in my group, to see if their position is readable too.
local function OtherUnit()
    local n = ns.Safe(ns.Call(GetNumGroupMembers))
    if type(n) ~= "number" or n < 2 then return nil end
    if ns.Call(IsInRaid) == true then
        for i = 1, n do
            local u = "raid" .. i
            if ns.Call(UnitIsUnit, u, "player") ~= true then return u end
        end
        return nil
    end
    return "party1"
end

local function ActiveMarkers()
    if type(IsRaidMarkerActive) ~= "function" then return 0 end
    local n = 0
    for i = 1, Probe.MARKERS do
        local ok, on = pcall(IsRaidMarkerActive, i)
        if ok and ns.Safe(on) == true then n = n + 1 end
    end
    return n
end

function Probe.Position(why)
    local db = ns.db
    if not db then return end
    local pp = type(db.posProbe) == "table" and db.posProbe or {}
    db.posProbe = pp
    pp.samples, pp.first, pp.sent = pp.samples or {}, pp.first or {}, pp.sent or {}
    local where = ns.Death.Where()
    local s = { t = ns.Now(), why = why, z = where.z, it = where.it, v = ns.VERSION }
    s.mapC, s.map = Probe.MapPos("player")
    s.unitC, s.unit = Probe.UnitPos("player")
    local other = OtherUnit()
    if other then
        s.otherC, s.other = Probe.UnitPos(other)
    else
        s.otherC, s.other = "g", "not in a group"
    end
    s.marks, s.group, s.active = Probe.Flags(Probe.MARK_FNS), Probe.Flags(Probe.GROUP_FNS), ActiveMarkers()
    s.lead = ns.Call(UnitIsGroupLeader, "player") == true
    pp.samples[#pp.samples + 1] = s
    while #pp.samples > Probe.POS_KEEP do table.remove(pp.samples, 1) end
    local it = where.it
    if it == "party" or it == "raid" then
        -- the first of each version is kept for good; a later one with a group replaces one without
        local old = pp.first[it]
        if not old or old.v ~= ns.VERSION or (old.otherC == "g" and s.otherC ~= "g") then
            pp.first[it] = s
            local book = ns.GuildName() and ns.Book()
            if book then Probe.AddPosition(book, Probe.Report(ns.MyName(), s)) end
            Probe.SendPosition(s)
        end
    end
    return s
end

-- Nameplates of mobs in this instance type (part 4): one code each for name, GUID and raid mark,
-- as Numbers: y = readable, s = secret, n = nothing, - = no plate seen yet.
function Probe.PlateCodes(it)
    local pl = ns.db and ns.db.posProbe and ns.db.posProbe.plates and ns.db.posProbe.plates[it]
    if not pl or pl.v ~= ns.VERSION then return "-", "-", "-" end
    local function code(c) return (c.y or 0) > 0 and "y" or (c.s or 0) > 0 and "s" or (c.n or 0) > 0 and "n" or "-" end
    return code(pl.name), code(pl.guid), code(pl.mark)
end

-- One report as a message: G|from|version|type|map|unit|other|marks|active|group|lead|plate name|plate guid|plate mark
function Probe.EncodePosition(from, s)
    local pn, pg, pm = Probe.PlateCodes(s.it)
    return table.concat({ "G", from, s.v, s.it, s.mapC, s.unitC, s.otherC, s.marks, tostring(s.active or 0),
        s.group, s.lead and "1" or "0", pn, pg, pm }, "|")
end
function Probe.Report(from, s)
    local pn, pg, pm = Probe.PlateCodes(s.it)
    return { from = from, v = s.v, it = s.it, mapC = s.mapC, unitC = s.unitC, otherC = s.otherC, marks = s.marks,
        active = s.active or 0, group = s.group, lead = s.lead and true or false, t = s.t,
        plateName = pn, plateGuid = pg, plateMark = pm }
end
local CODE = { y = true, n = true, s = true, e = true, ["-"] = true, g = true }
function Probe.DecodePosition(msg)
    local p = {}
    for piece in (msg .. "|"):gmatch("([^|]*)|") do p[#p + 1] = piece end
    if p[1] ~= "G" or #p ~= 14 or p[2] == "" or p[3] == "" or not p[4]:match("^%a+$") then return nil end
    for _, i in ipairs({ 5, 6, 7, 12, 13, 14 }) do if not CODE[p[i]] then return nil end end
    if not p[8]:match("^[01]+$") or not p[9]:match("^%d+$") or not p[10]:match("^[01]+$") or not p[11]:match("^[01]$") then
        return nil
    end
    return { from = p[2], v = p[3], it = p[4], mapC = p[5], unitC = p[6], otherC = p[7], marks = p[8],
        active = tonumber(p[9]), group = p[10], lead = p[11] == "1", plateName = p[12], plateGuid = p[13], plateMark = p[14] }
end

-- Kept per player and instance type; the newest version wins.
function Probe.AddPosition(book, r)
    if type(r) ~= "table" or not r.from or not r.it then return false end
    book.posReports = book.posReports or {}
    local key = r.from .. "/" .. r.it
    local old = book.posReports[key]
    if old and ns.Comm.Newer(old.v, r.v) then return false end
    r.t = r.t or ns.Now()
    book.posReports[key] = r
    return true
end

function Probe.SendPosition(s)
    local me = ns.MyName()
    if not me or not ns.GuildName() or not s then return end
    ns.Comm.SendRaw(Probe.EncodePosition(me, s))
end

-- My reports of this version, at my login and with the answer to a guildie's login.
function Probe.SendMine()
    local pp = ns.db and ns.db.posProbe
    if not pp or not pp.first then return end
    for _, it in ipairs({ "party", "raid" }) do
        local s = pp.first[it]
        if s and s.v == ns.VERSION then Probe.SendPosition(s) end
    end
end

ns.On("PLAYER_ENTERING_WORLD", function()
    local where = ns.Death.Where()
    if where.it ~= "party" and where.it ~= "raid" then return end
    if C_Timer and C_Timer.After then
        C_Timer.After(Probe.POS_DELAY, function() Safely(Probe.Position, "enter") end)
    end
end)
ns.On("ENCOUNTER_START", function()
    local where = ns.Death.Where()
    if where.it == "party" or where.it == "raid" then Safely(Probe.Position, "boss") end
end)

---------------------------------------------------------------------------
-- 4) Nameplates (24-11-2026, kill order idea): in a dungeon or raid, are the name, GUID and raid
--    mark of a mob on its nameplate readable, or secret? That decides if the addon can draw its own
--    kill order icons above mobs. Only counts, nothing is shown. The first plate of an instance type
--    sends the report again with these codes.
---------------------------------------------------------------------------
local function Count(c, v)
    if ns.IsSecret(v) then c.s = (c.s or 0) + 1
    elseif v ~= nil and v ~= "" then c.y = (c.y or 0) + 1
    else c.n = (c.n or 0) + 1 end
end

function Probe.Plate(unit)
    local db = ns.db
    if not db or type(unit) ~= "string" then return end
    local it = ns.Death.Where().it
    if it ~= "party" and it ~= "raid" then return end
    if ns.Call(UnitCanAttack, "player", unit) == false then return end -- friendly players and NPCs: not mobs
    if ns.Call(UnitIsPlayer, unit) == true then return end
    local pp = type(db.posProbe) == "table" and db.posProbe or {}
    db.posProbe = pp
    pp.plates = pp.plates or {}
    local pl = pp.plates[it]
    if not pl or pl.v ~= ns.VERSION then
        pl = { v = ns.VERSION, seen = 0, name = {}, guid = {}, mark = {} }
        pp.plates[it] = pl
    end
    pl.seen = pl.seen + 1
    -- 0.9.11: the level too (for the killer's level in dungeons), with the values seen
    pl.level, pl.levels = pl.level or {}, pl.levels or {}
    local okL, level = pcall(UnitLevel, unit)
    Count(pl.level, okL and level or nil)
    if okL and type(level) == "number" and not ns.IsSecret(level) then pl.levels[tostring(level)] = (pl.levels[tostring(level)] or 0) + 1 end
    local okN, name = pcall(UnitName, unit)
    Count(pl.name, okN and name or nil)
    local okG, guid = pcall(UnitGUID, unit)
    Count(pl.guid, okG and guid or nil)
    if type(GetRaidTargetIndex) == "function" then
        local okM, mark = pcall(GetRaidTargetIndex, unit)
        -- no mark is normal: count it as readable when the call works and gives no secret
        if okM and not ns.IsSecret(mark) then pl.mark.y = (pl.mark.y or 0) + 1 else Count(pl.mark, okM and mark or nil) end
    end
    if not pl.example and okN and type(name) == "string" and not ns.IsSecret(name) then pl.example = name end
    if not pl.sent and pp.first and pp.first[it] and pp.first[it].v == ns.VERSION then
        pl.sent = true
        local book = ns.GuildName() and ns.Book()
        if book then Probe.AddPosition(book, Probe.Report(ns.MyName(), pp.first[it])) end
        Probe.SendPosition(pp.first[it])
    end
end
ns.On("NAME_PLATE_UNIT_ADDED", function(unit) Safely(Probe.Plate, ns.Safe(unit)) end)

---------------------------------------------------------------------------
-- 5) Raid marks by the addon (24-11-2026, the user's choice: start with instance and fight). Only
--    on the owner (NewUI.OWNER): a blocked call shows the game's popup, so never at guildies. When I
--    target a hostile mob without a mark in a dungeon or raid, the addon tries SetRaidTarget once per
--    instance type and calm/fight, and takes the mark off again. Kept: did the call work, did the
--    game block it (ADDON_ACTION_FORBIDDEN/BLOCKED), did the mark appear, and am I leader/assist.
---------------------------------------------------------------------------
Probe.MARK_ICON = 8   -- the skull (user's choice 24-11-2026; the function is the same for every mark)
Probe.MARK_WAIT = 1.5 -- seconds for the server to show the mark (not measured)
local markTry

function Probe.MarkKey()
    local it = ns.Death.Where().it
    if it ~= "party" and it ~= "raid" then return nil end
    return it .. "/" .. (ns.Call(InCombatLockdown) == true and "fight" or "calm")
end

-- in instances the GUID of a mob is secret (measured 24-11-2026: 935 of 935 nameplates), so the
-- same target is known by "no PLAYER_TARGET_CHANGED during the wait" instead of by GUID
local function SameTarget(r)
    return not r.switched
end

function Probe.TryMark()
    local db = ns.db
    if not db or markTry or not ns.NewUI or ns.MyName() ~= ns.NewUI.OWNER then return end
    if type(SetRaidTarget) ~= "function" or type(GetRaidTargetIndex) ~= "function" then return end
    local key = Probe.MarkKey()
    if not key then return end
    local mp = type(db.markProbe) == "table" and db.markProbe or {}
    db.markProbe = mp
    mp.results = mp.results or {}
    local done = mp.results[key]
    if done and done.v == ns.VERSION then return end
    -- read directly: ns.Call turns a secret into nil, and the GUID of a mob is secret in instances
    local okEx, exists = pcall(UnitExists, "target")
    if not okEx or exists == false or exists == nil then return end
    if ns.Call(UnitCanAttack, "player", "target") == false or ns.Call(UnitIsPlayer, "target") == true then return end
    -- read directly: ns.Call turns a secret into nil, which would look like "no mark"
    local okOld, old = pcall(GetRaidTargetIndex, "target")
    if not okOld then return end
    local r = { v = ns.VERSION, t = ns.Now(), key = key, z = ns.Death.Where().z,
        lead = ns.Call(UnitIsGroupLeader, "player") == true, assist = ns.Call(UnitIsGroupAssistant, "player") == true,
        raid = ns.Call(IsInRaid) == true, members = ns.Safe(ns.Call(GetNumGroupMembers)) }
    if ns.IsSecret(old) then
        r.call = "not tried: the mark of the target is secret"
        mp.results[key] = r
        return
    end
    if old ~= nil and old ~= 0 then return end -- someone marked it: leave it alone
    markTry = r
    local ok, err = pcall(SetRaidTarget, "target", Probe.MARK_ICON)
    r.call = ok and "ok" or ("error " .. tostring(err):sub(1, 80))
    local function finish()
        local _, now = pcall(GetRaidTargetIndex, "target")
        r.after = Seen(now)
        r.marked = ns.Safe(now) == Probe.MARK_ICON
        if r.marked and SameTarget(r) then pcall(SetRaidTarget, "target", 0) end
        if r.marked and not SameTarget(r) then r.left = "target switched: the mark stays on the mob" end
        r.switched = nil
        mp.results[key] = r
        markTry = nil
    end
    if C_Timer and C_Timer.After then C_Timer.After(Probe.MARK_WAIT, function() Safely(finish) end) else finish() end
end

for _, ev in ipairs({ "ADDON_ACTION_FORBIDDEN", "ADDON_ACTION_BLOCKED" }) do
    ns.On(ev, function(addon, fn)
        if markTry and ns.Safe(addon) == "OmenDeaths" then markTry.blocked = ev .. " " .. Seen(fn) end
    end)
end
ns.On("RAID_TARGET_UPDATE", function() if markTry then markTry.update = true end end)
ns.On("PLAYER_TARGET_CHANGED", function()
    if markTry then markTry.switched = true end
    Safely(Probe.TryMark)
end)
ns.On("PLAYER_REGEN_DISABLED", function() Safely(Probe.TryMark) end)
