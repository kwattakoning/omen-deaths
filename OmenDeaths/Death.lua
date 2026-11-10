-- Omen Deaths: noticing your own death, where it happened and (when the client tells) what did it.
--
-- PLAYER_DEAD is the source: the combat log is closed to addons on this client.
-- The killer comes from the death recap (C_DamageMeter deaths list -> deathRecapID ->
-- C_DeathRecap.GetRecapEvents), the way ForeverMeter reads it. During combat those answers
-- can be secret; then we try again on the next meter update or when combat ends, and give up
-- once you are alive again. A death without a known killer still counts.
local _, ns = ...
local Death = {}
ns.Death = Death

local SESSION_OVERALL, SESSION_CURRENT = 0, 1 -- as ForeverMeter uses them
local armed = true   -- one death per life: PLAYER_DEAD again before being alive does not count twice
local pending        -- { owner, t } still waiting for its killer

local function Title(s)
    s = tostring(s):lower():gsub("_", " ")
    return (s:gsub("^%l", string.upper))
end

-- Where am I? Instance name in dungeons and raids, else the zone.
function Death.Where()
    local name, itype, difficulty, _, _, _, _, instanceID = ns.Call(GetInstanceInfo)
    if type(itype) ~= "string" or itype == "" then itype = "none" end
    local zone
    if itype == "none" then
        zone = ns.Call(GetRealZoneText) or ns.Call(GetZoneText) or name
    else
        zone = name or ns.Call(GetRealZoneText)
    end
    if type(zone) ~= "string" or zone == "" then zone = nil end
    return {
        it = itype,
        id = itype ~= "none" and type(instanceID) == "number" and instanceID or nil,
        d = type(difficulty) == "number" and difficulty or nil,
        z = zone,
    }
end

-- Measurement log (08-11-2026): a fall death got no cause, and it is not known at which step
-- the death recap stopped. Per death we keep how far each step came and what the game gave.
Death.LOG_KEEP = 20 -- deaths kept in OmenDeathsDB.recapLog

-- A value as the log shows it: "secret", a short text, a number, or its type.
local function Seen(v)
    if ns.IsSecret(v) then return "secret" end
    local t = type(v)
    if t == "string" then return '"' .. v:sub(1, 60) .. '"' end
    if t == "number" or t == "boolean" then return tostring(v) end
    if t == "table" then return "table(" .. #v .. ")" end
    return t
end

-- The names of the functions an API table has, sorted; nil when the table is missing.
local function Names(api)
    if type(api) ~= "table" then return nil end
    local out = {}
    for k in pairs(api) do if type(k) == "string" then out[#out + 1] = k end end
    table.sort(out)
    return out
end

-- The killing blow from the death recap: killer name and spell or kind of damage. nil when unknown.
-- `tr` (optional) gets how far each step came.
-- Reserve way (v0.7.0): the latest recap without an ID, used only when its killing blow was on me
-- and at most RECENT_BEFORE seconds before the death (measured 0.24 and 0.41 s; plus 1 s of the
-- second look in CheckDeath, plus 1 s because the death time is whole seconds) and at most
-- RECENT_AFTER after it (the whole-second death time can lie up to 1 s before the blow).
Death.RECENT_BEFORE, Death.RECENT_AFTER = 3, 1
local function LatestRecap(tr, deathT)
    local recap = C_DeathRecap
    if not (recap and recap.GetRecapEvents) or type(deathT) ~= "number" then return end
    local events = ns.Call(recap.GetRecapEvents)
    tr.latest = Seen(events)
    if type(events) ~= "table" or #events == 0 then return end
    local blow, latest = events[1], nil
    for _, e in ipairs(events) do
        local ts = ns.Safe(e.timestamp)
        if type(ts) == "number" and (not latest or ts > latest) then blow, latest = e, ts end
    end
    if not latest or deathT - latest > Death.RECENT_BEFORE or latest - deathT > Death.RECENT_AFTER then
        tr.latest = tr.latest .. ", too old or no time"
        return
    end
    local me, dest = ns.Call(UnitGUID, "player"), ns.Safe(blow.destGUID)
    if not me or dest ~= me then
        tr.latest = tr.latest .. ", not on me"
        return
    end
    tr.latest = tr.latest .. ", used"
    return events
end

-- How the game colours the killer's level (09-11-2026, a guildie read "lost a fair fight" literally
-- after a skull mob). The death recap has no level (measured: sourceName, sourceGUID, flags, damage),
-- so the killer is looked up among the units the client knows right now, by its GUID.
-- The colour is the game's own, as on its unit frames; no level gap of our own:
-- - skull: UnitLevel gives -1 (the game hides the level: "??")
-- - C_PlayerInfo.GetContentDifficultyCreatureForPlayer(unit) -> Enum.RelativeContentDifficulty
-- - else GetCreatureDifficultyColor(level) compared with QuestDifficultyColors.impossible / .trivial
-- Not proven in this client yet: tr.level logs what each way gave.
Death.NAMEPLATES = 40 -- the game's unit tokens nameplate1 to nameplate40
function Death.FindUnit(guid)
    if type(guid) ~= "string" or guid == "" then return end
    local units = { "target", "focus", "mouseover", "softenemy" }
    for i = 1, Death.NAMEPLATES do units[#units + 1] = "nameplate" .. i end
    for _, unit in ipairs(units) do
        if ns.Call(UnitGUID, unit) == guid then return unit end
    end
end

function Death.KillerTier(guid, tr)
    tr = tr or {}
    local unit = Death.FindUnit(guid)
    if not unit then
        tr.level = "not found"
        return
    end
    local level = ns.Call(UnitLevel, unit)
    tr.level = unit .. " level " .. Seen(level)
    if level == -1 then return "skull" end
    local pi, enum = C_PlayerInfo, Enum and Enum.RelativeContentDifficulty
    if pi and pi.GetContentDifficultyCreatureForPlayer and type(enum) == "table" then
        local d = ns.Call(pi.GetContentDifficultyCreatureForPlayer, unit)
        tr.level = tr.level .. ", difficulty " .. Seen(d)
        if d ~= nil then
            if d == enum.Impossible then return "red" end
            if d == enum.Trivial then return "gray" end
            return
        end
    end
    local colors = QuestDifficultyColors
    if type(level) == "number" and type(colors) == "table" then
        local color = ns.Call(GetCreatureDifficultyColor, level)
        if type(color) == "table" then
            tr.level = tr.level .. ", colour " .. (color == colors.impossible and "impossible"
                or color == colors.trivial and "trivial" or "other")
            if color == colors.impossible then return "red" end
            if color == colors.trivial then return "gray" end
            return
        end
    end
    tr.level = tr.level .. ", no colour"
end

function Death.ReadKiller(tr, deathT)
    tr = tr or {}
    local meter, recap = C_DamageMeter, C_DeathRecap
    tr.step = "api"
    tr.meter, tr.recap = type(meter), type(recap)
    if not (meter and recap and meter.GetCombatSessionFromType and recap.GetRecapEvents) then return end
    local deaths = Enum and Enum.DamageMeterType and Enum.DamageMeterType.Deaths or 9
    tr.deathsType = Seen(deaths)
    tr.step = "session"
    local recapID
    for _, session in ipairs({ SESSION_CURRENT, SESSION_OVERALL }) do
        local ok, raw = pcall(meter.GetCombatSessionFromType, session, deaths)
        local s = ok and ns.Safe(raw) or nil
        local note = ok and Seen(raw) or ("error " .. tostring(raw):sub(1, 80))
        if type(s) == "table" then
            local sources = ns.Safe(s.combatSources)
            note = note .. ", sources " .. Seen(sources)
            if type(sources) == "table" then
                for _, src in ipairs(sources) do
                    if ns.Safe(src.isLocalPlayer) == true then
                        note = note .. ", me found, recapID " .. Seen(src.deathRecapID)
                        recapID = ns.Safe(src.deathRecapID)
                        break
                    end
                end
            end
        end
        tr["session" .. session] = note
        if recapID then break end
    end
    tr.step = "recapID"
    local events
    if type(recapID) == "number" and recapID ~= -1 then
        tr.step = "has"
        local has = true
        if recap.HasRecapEvents then
            local ok, h = pcall(recap.HasRecapEvents, recapID)
            tr.has = ok and Seen(h) or "error"
            has = ns.Safe(h) == true
        end
        if has then
            tr.step = "events"
            events = ns.Call(recap.GetRecapEvents, recapID)
            tr.events = Seen(events)
        end
    end
    if type(events) ~= "table" or #events == 0 then
        -- not in the damage meter (two falls on 07-11-2026): the latest recap, if it is this death
        tr.step = "latest"
        events = LatestRecap(tr, deathT)
        if not events then return end
    end
    tr.step = "blow"
    -- the latest event is the killing blow; Blizzard lists it first, the timestamps decide
    local blow, latest = events[1], nil
    for _, e in ipairs(events) do
        local ts = ns.Safe(e.timestamp)
        if type(ts) == "number" and (not latest or ts > latest) then blow, latest = e, ts end
    end
    -- every field of the killing blow as the game gave it
    tr.blow = {}
    if type(blow) == "table" then
        for k, v in pairs(blow) do
            if type(k) == "string" then tr.blow[k] = Seen(v) end
        end
    end
    tr.step = "read"
    local killer = ns.Safe(blow.sourceName)
    local cause = ns.Safe(blow.spellName)
    local spellId = ns.Safe(blow.spellId)
    if not cause and type(spellId) == "number" and C_Spell and C_Spell.GetSpellName then
        cause = ns.Call(C_Spell.GetSpellName, spellId)
    end
    local env = ns.Safe(blow.environmentalType)
    if not cause and type(env) == "string" and env ~= "" then cause = Title(env) end
    if type(killer) ~= "string" or killer == "" then killer = nil end
    if type(cause) ~= "string" or cause == "" then cause = nil end
    local tier
    if killer then tier = Death.KillerTier(ns.Safe(blow.sourceGUID), tr) end
    -- one hit from full health (0.9.0): health before the blow at least the recap's max health.
    -- Measured 10-11-2026: after death the game gives a max a bit lower than the real one
    -- (1406 vs 1526 before a fall from full), every fall from full health had currentHP >= max.
    local oneShot
    if killer and recap.GetRecapMaxHealth then
        local max = type(recapID) == "number" and ns.Call(recap.GetRecapMaxHealth, recapID) or ns.Call(recap.GetRecapMaxHealth)
        local hp = ns.Safe(blow.currentHP)
        tr.maxHealth = Seen(max)
        oneShot = type(max) == "number" and max > 0 and type(hp) == "number" and hp >= max or nil
    end
    if killer or cause then return killer, cause, tier, oneShot end
end

-- The death is complete (killer known, or given up on): time for the guild chat line.
local function Done()
    local owner, t = pending.owner, pending.t
    pending = nil
    if ns.Toast and ns.Toast.GuildPost then ns.Toast.GuildPost(owner, t) end
    -- the measurement log changed: tell the guild how the addon is doing
    if ns.Comm.SendHealth then ns.Comm.SendHealth() end
end

local function TryKiller(final, why)
    if not pending then return end
    local tr = { why = why or "?" }
    local killer, cause, tier, oneShot = Death.ReadKiller(tr, pending.t)
    local e = pending.log
    if e then
        tr.after = ns.Now() - pending.t -- seconds after the death
        tr.killer, tr.cause = killer, cause
        e.tries = e.tries + 1
        if not e.first then e.first = tr else e.last = tr end
        if killer or cause then e.found = true end
    end
    if killer or cause then
        local book = ns.Book()
        local p = book.players[pending.owner]
        local r = p and p.deaths[pending.t]
        if r then
            r.k, r.s = killer, cause
            -- only who died knows it; the line and popup of others go without it
            r.kt = tier
            r.os = oneShot
            if pending.sent then ns.Comm.SendRecord(pending.owner, pending.t, "R") end
            ns.Changed()
        end
        Done()
    elseif final then
        Done()
    end
end

-- My role, for lines that fit it (09-11-2026: a tank got "found out why the tank goes first").
-- 1) the role chosen in the group (UnitGroupRolesAssigned, as HealKit reads it in this client);
-- 2) else the talent tree with the most points (as ForeverGuide reads GetTalentTabInfo: the first
--    number from the third answer on). A feral druid can be bear or cat: unknown.
-- Unknown = nil: lines that fit every role.
Death.ROLE_NAMES = { TANK = "tank", HEALER = "healer", DAMAGER = "dps" }
Death.TREE_ROLES = {
    WARRIOR = { "dps", "dps", "tank" }, PALADIN = { "healer", "tank", "dps" }, PRIEST = { "healer", "healer", "dps" },
    SHAMAN = { "dps", "dps", "healer" }, DRUID = { "dps", nil, "healer" },
    MAGE = { "dps", "dps", "dps" }, ROGUE = { "dps", "dps", "dps" }, HUNTER = { "dps", "dps", "dps" },
    WARLOCK = { "dps", "dps", "dps" },
}
function Death.Role()
    local chosen = Death.ROLE_NAMES[ns.Call(UnitGroupRolesAssigned, "player") or ""]
    if chosen then return chosen end
    local _, class = ns.Call(UnitClass, "player")
    local map = Death.TREE_ROLES[class or ""]
    if not map or type(GetTalentTabInfo) ~= "function" then return nil end
    local best, bi = 0, nil
    for i = 1, 3 do
        local r = { pcall(GetTalentTabInfo, i) }
        if r[1] then
            local pts
            for j = 4, #r do
                if not pts and not ns.IsSecret(r[j]) and type(r[j]) == "number" and r[j] >= 0 and r[j] <= 61 then pts = r[j] end
            end
            if pts and pts > best then best, bi = pts, i end
        end
    end
    return bi and map[bi] or nil
end

function Death.Record()
    local me = ns.MyName()
    if not me or not ns.db then return end
    local where = Death.Where()
    local _, class = ns.Call(UnitClass, "player")
    local rec = {
        t = ns.Now(), c = class, l = ns.Call(UnitLevel, "player"),
        it = where.it, id = where.id, d = where.d, z = where.z,
    }
    rec.r = Death.Role()
    -- 0.9.0: the death sound of guildies follows the gender (UnitSex: 2 = male, 3 = female)
    local sex = ns.Safe(ns.Call(UnitSex, "player"))
    rec.g = sex == 3 and "f" or sex == 2 and "m" or nil
    -- died in a raid boss fight: under that boss on the leaderboard
    if rec.it == "raid" and ns.Wipe and ns.Wipe.Boss then rec.b = ns.Wipe.Boss(rec) end
    local book = ns.Book()
    -- a second death within the same second is the same death
    if not ns.Data.Add(book, me, rec, true) then return end
    -- only for my own line, not sent (0.9.0): when my fight began (together), a level-up this session
    local stored = book.players[me].deaths[rec.t]
    stored.fs = Death.FightStart(rec.t)
    stored.lu, Death.dinged = Death.dinged, nil
    pending = { owner = me, t = rec.t }
    -- the measurement log entry of this death; the oldest goes past LOG_KEEP
    local log = ns.db.recapLog or {}
    ns.db.recapLog = log
    local entry = { t = rec.t, z = rec.z, it = rec.it, tries = 0 }
    log[#log + 1] = entry
    while #log > Death.LOG_KEEP do table.remove(log, 1) end
    pending.log = entry
    -- which functions the two APIs have in this client: shows other ways to the recap
    ns.db.recapApi = { meter = Names(C_DamageMeter), recap = Names(C_DeathRecap), version = ns.VERSION }
    TryKiller(false, "death") -- usually known at once; then the guild hears it with the killer
    if pending then pending.sent = true end
    ns.Comm.SendRecord(me, rec.t, "L")
    ns.Changed()
    if ns.Toast then ns.Toast.Death(me, book.players[me].deaths[rec.t]) end
end

-- My fight (0.9.0, "together"): from PLAYER_REGEN_DISABLED. Dying ends the fight, so REGEN_ENABLED can
-- come just before PLAYER_DEAD; ended in the second of the death (or the one before, as the clock
-- counts whole seconds) still counts. Out of a fight (a fall): only deaths in the same second.
local fight = {}
ns.On("PLAYER_REGEN_DISABLED", function() fight.start, fight.ended = ns.Now(), nil end)
ns.On("PLAYER_REGEN_ENABLED", function() fight.ended = ns.Now() end)
function Death.FightStart(t)
    if fight.start and (not fight.ended or fight.ended >= t - 1) then return fight.start end
    return t
end

-- A level-up this session (0.9.0): the next death says so.
ns.On("PLAYER_LEVEL_UP", function(level)
    level = ns.Safe(level)
    Death.dinged = type(level) == "number" and level or ns.Call(UnitLevel, "player")
end)

-- Measurement (0.9.0): how did I come back? Spirit Healer or own corpse. CONFIRM_XP_LOSS is the
-- Spirit Healer's question in other WoW versions, Resurrection Sickness (15007) its debuff.
-- Not proven in Forever: logged per death in recapLog[..].back, check-data.js shows it.
Death.SICKNESS = 15007
local xpLossAsked
ns.On("CONFIRM_XP_LOSS", function() xpLossAsked = ns.Now() end)
local function Sick()
    local api = C_UnitAuras
    if not (api and api.GetPlayerAuraBySpellID) then return "no api" end
    local ok, aura = pcall(api.GetPlayerAuraBySpellID, Death.SICKNESS)
    if not ok then return "error" end
    if ns.IsSecret(aura) then return "secret" end
    return aura and "yes" or "no"
end
local function NoteBack(event)
    local log = ns.db and ns.db.recapLog
    local e = log and log[#log]
    if not e or e.back then return end
    local now = ns.Now()
    e.back = { event = event, after = now - e.t, ghost = tostring(ns.Call(UnitIsGhost, "player")),
        xpLoss = xpLossAsked and xpLossAsked >= e.t and (now - xpLossAsked) or nil }
    xpLossAsked = nil
    -- the debuff can come a moment later
    if C_Timer and C_Timer.After then
        C_Timer.After(Death.RECHECK, function() e.back.sick = Sick() end)
    else
        e.back.sick = Sick()
    end
end
ns.On("PLAYER_UNGHOST", function() NoteBack("PLAYER_UNGHOST") end)
ns.On("PLAYER_ALIVE", function()
    -- PLAYER_ALIVE also comes at Release Spirit (then a ghost): only alive counts
    if ns.Call(UnitIsGhost, "player") ~= true then NoteBack("PLAYER_ALIVE") end
end)

-- Deaths saved under the first name only (before v0.5) move to the full name.
ns.On("PLAYER_LOGIN", function()
    if not ns.db then return end
    local me = ns.MyName()
    for _, book in pairs(ns.db.guilds) do ns.Data.MoveToFullName(book, ns.FirstName(me), me) end
end)

ns.On("PLAYER_ENTERING_WORLD", function()
    -- logged in while dead: that death was counted before (or happened without the addon)
    if ns.Call(UnitIsDeadOrGhost, "player") == true then armed = false end
end)
-- PLAYER_DEAD also comes when your pet dies (Journey Tracker measured warlocks at 1.55x and
-- hunters at 1.33x the game's death count). So it is your death only if you are dead:
-- not feigning, not already a ghost. The dead state can lag the event; one more look a
-- second later, as Journey Tracker does.
Death.RECHECK = 1
local function CheckDeath(again)
    if not armed then return end
    if ns.Call(UnitIsFeignDeath, "player") == true or ns.Call(UnitIsGhost, "player") == true then return end
    if ns.Call(UnitIsDeadOrGhost, "player") == false then
        if not again and C_Timer and C_Timer.After then
            C_Timer.After(Death.RECHECK, function() CheckDeath(true) end)
        end
        return
    end
    armed = false
    Death.Record()
end
ns.On("PLAYER_DEAD", function() CheckDeath(false) end)
ns.On("PLAYER_ALIVE", function()
    TryKiller(true, "PLAYER_ALIVE")
    armed = true
end)
ns.On("PLAYER_UNGHOST", function()
    TryKiller(true, "PLAYER_UNGHOST")
    armed = true
end)
for _, event in ipairs({ "DAMAGE_METER_COMBAT_SESSION_UPDATED", "DAMAGE_METER_CURRENT_SESSION_UPDATED", "PLAYER_REGEN_ENABLED" }) do
    ns.On(event, function() TryKiller(false, event) end)
end

Death.TryKiller = TryKiller
