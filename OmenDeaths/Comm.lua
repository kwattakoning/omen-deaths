-- Omen Deaths: sharing deaths with guildies over the hidden guild addon channel.
--
-- Messages (prefix "OmenDeaths", channel GUILD, at most 250 bytes):
--   L|owner|t|class|level|type|instanceID|difficulty|zone|killer|cause   a fresh death (shows a toast)
--   R|...same fields...                                                  a record sent again (sync, or killer found later)
--   S|owner|total|readAt|class|bg                                        the game's "Total deaths" statistic of owner
--                                                                        (bg = of those in battlegrounds, from v0.8.4)
--   V|owner=count:latest:statAt,...                                     what I hold, sent at login (several if long)
--   N|owner|count|latest                                                 "I hold this much of owner, send me what I lack"
--   P|version                                                            "I run Omen Deaths", answer to V
--   W|boss                                                               "I post the summary of this boss fight"
--   H|owner|version|logged|missed|step|errors|lastError                  how my addon is doing (Health.lua)
--
-- Whoever holds more of a player's deaths than the asker sends them. Everyone hears every
-- message on the guild channel, so a record somebody else already sent is not sent again.
local _, ns = ...
local Comm = {}
ns.Comm = Comm

Comm.PREFIX = "OmenDeaths"
-- 255 is the game's limit; ForeverGuide keeps its guild messages at 250 and so do we.
Comm.MAX_LEN = 250
-- Names are "First Surname": 12 + 1 + 12 = 25 bytes at most.
Comm.NAME_LEN = 25
-- Zone, killer and cause share what is left after the fixed fields (at most 77 bytes:
-- "L|" + name 25 + time 10 + class 11 + level 2 + type 8 + ID 7 + difficulty 3 + 9 separators,
-- plus 2 separators between the three texts): (250 - 77 - 2) / 3 = 57 each.
Comm.TEXT_LEN = 57
-- Pace of sending, from ChatThrottleLib v32 (shipped with Plater in this client):
-- 800 bytes per second, bursts up to 4000 bytes, 40 bytes counted per message on top of the text.
Comm.CPS, Comm.BURST, Comm.OVERHEAD = 800, 4000, 40
-- Records others may also send wait a random 0..RELAY_JITTER seconds, so that the first
-- sender is usually heard by the rest before they start (not measured, see CONTEXT.md).
Comm.RELAY_JITTER = 3

Comm.peers = {}  -- name -> { version, seen = GetTime() }
local heard = {} -- "owner/t" -> GetTime() a record was last heard on the channel

---------------------------------------------------------------------------
-- Encoding
---------------------------------------------------------------------------
local function Clean(s, max)
    if s == nil then return "" end
    s = tostring(s):gsub("[|\r\n]", "")
    if #s > max then
        s = s:sub(1, max)
        -- do not leave half a UTF-8 character at the end
        s = s:gsub("[\192-\255][\128-\191]*$", "")
    end
    return s
end

function Comm.EncodeRecord(kind, owner, r)
    local n = Comm.TEXT_LEN
    return table.concat({ kind, Clean(owner, Comm.NAME_LEN), tostring(r.t), Clean(r.c, 11), tostring(r.l or ""),
        Clean(r.it, 8), tostring(r.id or ""), tostring(r.d or ""), Clean(r.z, n), Clean(r.k, n), Clean(r.s, n) }, "|")
end

local function Split(msg)
    local parts = {}
    for piece in (msg .. "|"):gmatch("([^|]*)|") do parts[#parts + 1] = piece end
    return parts
end

local function Text(s) if s ~= nil and s ~= "" then return s end end

-- Health report. The error text gets what is left of MAX_LEN after the other fields:
-- "H" 1 + name 25 + version 10 + logged 2 + missed 2 + step 8 + errors 6 + post 12 + 8 separators = 74.
-- post ("arrived/0.50") comes last: older versions read 8 fields and leave it.
Comm.HEALTH_POST_LEN = 12
Comm.HEALTH_TEXT_LEN = Comm.MAX_LEN - 74
function Comm.EncodeHealth(owner, h)
    return table.concat({ "H", Clean(owner, Comm.NAME_LEN), Clean(h.v, 10), tostring(h.n or 0), tostring(h.miss or 0),
        Clean(h.step, 8), tostring(h.err or 0), Clean(h.text, Comm.HEALTH_TEXT_LEN), Clean(h.post, Comm.HEALTH_POST_LEN) }, "|")
end

function Comm.DecodeHealth(msg)
    local p = Split(msg)
    if p[1] ~= "H" or #p < 8 or not Text(p[2]) then return nil end
    return p[2], { v = Text(p[3]), n = tonumber(p[4]) or 0, miss = tonumber(p[5]) or 0, step = Text(p[6]),
        err = tonumber(p[7]) or 0, text = Text(p[8]), post = Text(p[9]) }
end

function Comm.DecodeRecord(msg)
    local p = Split(msg)
    if (p[1] ~= "L" and p[1] ~= "R") or #p < 11 then return nil end
    local t = tonumber(p[3])
    if not t or not Text(p[2]) then return nil end
    return p[1], p[2], {
        t = t, c = Text(p[4]), l = tonumber(p[5]), it = Text(p[6]), id = tonumber(p[7]), d = tonumber(p[8]),
        z = Text(p[9]), k = Text(p[10]), s = Text(p[11]),
    }
end

-- "V|a=3:1790000000:1790000900,b=1:1790000500:0" split over as many messages as needed.
-- The third number is when the player's game statistic was read (0 = not known); v0.1
-- clients read only the first two.
function Comm.EncodeVector(book)
    local entries = {}
    for name, p in pairs(book.players) do
        local count, latest = ns.Data.Summary(book, name)
        local statAt = p.stat and p.stat.at or 0
        if count > 0 or statAt > 0 then entries[#entries + 1] = name .. "=" .. count .. ":" .. latest .. ":" .. statAt end
    end
    table.sort(entries)
    local msgs, cur = {}, "V|"
    for _, e in ipairs(entries) do
        local add = (cur == "V|" and "" or ",") .. e
        if #cur + #add > Comm.MAX_LEN then
            msgs[#msgs + 1] = cur
            cur = "V|" .. e
        else
            cur = cur .. add
        end
    end
    msgs[#msgs + 1] = cur
    return msgs
end

function Comm.DecodeVector(msg)
    local body = msg:match("^V|(.*)$")
    if not body then return nil end
    local v = {}
    for entry in body:gmatch("[^,]+") do
        local name, count, latest, statAt = entry:match("^([^=]+)=(%d+):(%d+):?(%d*)$")
        if name then
            v[name] = { count = tonumber(count), latest = tonumber(latest), statAt = tonumber(statAt) or 0 }
        end
    end
    return v
end

---------------------------------------------------------------------------
-- Sending: one queue, paced by a byte budget.
---------------------------------------------------------------------------
local queue = {}
local budget = Comm.BURST
-- Messages I sent, until the game echoes them back to me. The sender name on the channel
-- may lack the surname, so "is this me?" is answered by the message itself.
local echoes = {}
local lastTick
local pacer = CreateFrame("Frame")
pacer:Hide()

local function Raw(msg)
    local api = C_ChatInfo
    local fn = api and api.SendAddonMessage or SendAddonMessage
    if not fn then return "gone" end
    local ok, result = pcall(fn, Comm.PREFIX, msg, "GUILD")
    if not ok then return "gone" end
    if ns.IsSecret(result) then return "throttled" end
    local e = Enum and Enum.SendAddonMessageResult or {}
    -- throttled, or addon messages locked during a boss encounter: keep it and try again
    -- (the same results ForeverGuide's Transport.lua retries on)
    if result == (e.AddonMessageThrottle or 3) or result == (e.ChannelThrottle or 8)
        or result == (e.AddOnMessageLockdown or 11) then
        return "throttled"
    end
    return "sent"
end

-- Turns a queue item into a message, or nil when it is no longer needed.
local function Build(item)
    if item.msg then return item.msg end
    local book = ns.Book()
    if item.record then
        local owner, t = item.record.owner, item.record.t
        local h = heard[owner .. "/" .. t]
        if item.relay and h and h >= item.queued then return nil end -- someone else sent it
        local p = book.players[owner]
        local r = p and p.deaths[t]
        if not r then return nil end
        return Comm.EncodeRecord(item.record.kind or "R", owner, r)
    end
    if item.stat then
        local owner = item.stat.owner
        local p = book.players[owner]
        if not p or not p.stat then return nil end
        local h = heard["S/" .. owner .. "/" .. p.stat.at]
        if item.relay and h and h >= item.queued then return nil end
        return table.concat({ "S", owner, p.stat.total, p.stat.at, p.class or "", p.stat.bg or "" }, "|")
    end
    if item.need then
        -- still lacking? The answer may have arrived from someone else meanwhile.
        local count, latest = ns.Data.Summary(book, item.need.owner)
        if count >= item.need.count and latest >= item.need.latest then return nil end
        return table.concat({ "N", item.need.owner, count, latest }, "|")
    end
end

pacer:SetScript("OnUpdate", function()
    local now = GetTime()
    budget = math.min(Comm.BURST, budget + (now - (lastTick or now)) * Comm.CPS)
    lastTick = now
    local i = 1
    while queue[i] do
        local item = queue[i]
        if (item.notBefore or 0) > now then
            i = i + 1
        else
            local msg = Build(item)
            if not msg then
                table.remove(queue, i)
            else
                local cost = #msg + Comm.OVERHEAD
                if budget < cost then return end
                local result = Raw(msg)
                if result == "throttled" then
                    budget = 0
                    return
                end
                budget = budget - cost
                echoes[msg] = (echoes[msg] or 0) + 1
                table.remove(queue, i)
                if item.record then heard[item.record.owner .. "/" .. item.record.t] = now end
                local sp = item.stat and ns.Book().players[item.stat.owner]
                if sp and sp.stat then heard["S/" .. item.stat.owner .. "/" .. sp.stat.at] = now end
            end
        end
    end
    if not queue[1] then
        pacer:Hide()
        lastTick = nil
    end
end)

local function Push(item)
    if not ns.GuildName() then return end
    item.queued = GetTime()
    queue[#queue + 1] = item
    pacer:Show()
end

function Comm.QueueLength() return #queue end

function Comm.SendRaw(msg) Push({ msg = msg }) end

-- Sends one death record. kind "L" = fresh death, "R" = again.
function Comm.SendRecord(owner, t, kind, relay)
    local delay = relay and math.random() * Comm.RELAY_JITTER or 0
    Push({ record = { owner = owner, t = t, kind = kind }, relay = relay, notBefore = GetTime() + delay })
end

-- Sends the game statistic of `owner` (mine right away, someone else's after a random wait).
function Comm.SendStat(owner, relay)
    local delay = relay and math.random() * Comm.RELAY_JITTER or 0
    Push({ stat = { owner = owner }, relay = relay, notBefore = GetTime() + delay })
end

---------------------------------------------------------------------------
-- Sync
---------------------------------------------------------------------------
-- Someone holds `count` deaths of `owner`, the latest at `latest`. Send what they may lack.
function Comm.Answer(owner, count, latest)
    local book = ns.Book()
    local mine, _, before = ns.Data.Summary(book, owner, latest)
    if mine == 0 then return end
    local relay = owner ~= ns.MyName()
    for _, r in ipairs(ns.Data.Records(book, owner)) do
        -- newer than anything they have; or everything, if they miss some older one
        if r.t > latest or before > count then
            Comm.SendRecord(owner, r.t, "R", relay)
        end
    end
end

function Comm.SendVector()
    for _, msg in ipairs(Comm.EncodeVector(ns.Book())) do Push({ msg = msg }) end
end

local function OnVector(sender, v)
    local book = ns.Book()
    local names = {}
    for name in pairs(book.players) do names[name] = true end
    for name in pairs(v) do names[name] = true end
    for name in pairs(names) do
        local theirs = v[name] or { count = 0, latest = 0, statAt = 0 }
        Comm.Answer(name, theirs.count, theirs.latest)
        local p = book.players[name]
        if p and p.stat and p.stat.at > (theirs.statAt or 0) then
            Comm.SendStat(name, name ~= ns.MyName())
        end
        local count, latest = ns.Data.Summary(book, name)
        if theirs.count > count or theirs.latest > latest then
            Push({ need = { owner = name, count = theirs.count, latest = theirs.latest },
                notBefore = GetTime() + math.random() * Comm.RELAY_JITTER })
        end
    end
    Push({ msg = "P|" .. ns.Announced() })
end

-- "0.10.0" > "0.9.0": compares number by number.
function Comm.Newer(a, b)
    local x, y = {}, {}
    for n in tostring(a):gmatch("%d+") do x[#x + 1] = tonumber(n) end
    for n in tostring(b):gmatch("%d+") do y[#y + 1] = tonumber(n) end
    for i = 1, math.max(#x, #y) do
        local p, q = x[i] or 0, y[i] or 0
        if p ~= q then return p > q end
    end
    return false
end

-- Comm.newest = the newest version heard from a guildie when it is newer than mine, else nil.
-- The chat line comes once per version heard; the window shows it as long as it holds.
function Comm.UpdateText()
    if not Comm.newest then return nil end
    return "Omen Deaths " .. Comm.newest .. " is out (you have " .. ns.VERSION .. "). Download: " .. ns.DOWNLOAD
end

local function Seen(sender, version)
    local p = Comm.peers[sender] or {}
    p.seen = GetTime()
    if version then p.version = version end
    Comm.peers[sender] = p
    if version and Comm.Newer(version, Comm.newest or ns.VERSION) then
        Comm.newest = version
        ns.Print("|cffff9900" .. Comm.UpdateText() .. "|r")
        ns.Changed()
    end
end

function Comm.OnMessage(prefix, msg, channel, sender)
    if ns.IsSecret(prefix) or prefix ~= Comm.PREFIX or channel ~= "GUILD" then return end
    if ns.IsSecret(msg) or type(msg) ~= "string" then return end
    sender = ns.ShortName(sender)
    if not sender then return end
    if echoes[msg] and ns.SameChar(sender, ns.MyName()) then
        echoes[msg] = echoes[msg] > 1 and echoes[msg] - 1 or nil
        return
    end
    local kind = msg:sub(1, 1)
    if kind == "L" or kind == "R" then
        local k, owner, rec = Comm.DecodeRecord(msg)
        if not k then return end
        owner = ns.ShortName(owner)
        heard[owner .. "/" .. rec.t] = GetTime()
        Seen(sender)
        local result = ns.Data.Add(ns.Book(), owner, rec, ns.SameChar(owner, sender))
        if result then ns.Changed() end
        if result == "new" and k == "L" and ns.Toast then ns.Toast.Death(owner, rec) end
    elseif kind == "S" then
        local p = Split(msg)
        local owner, total, at = ns.ShortName(p[2]), tonumber(p[3]), tonumber(p[4])
        if owner and total and at then
            heard["S/" .. owner .. "/" .. at] = GetTime()
            Seen(sender)
            if ns.Data.SetStat(ns.Book(), owner, total, at, p[5], tonumber(p[6])) then ns.Changed() end
        end
    elseif kind == "V" then
        local v = Comm.DecodeVector(msg)
        if v then
            Seen(sender)
            OnVector(sender, v)
        end
    elseif kind == "N" then
        local p = Split(msg)
        local count, latest = tonumber(p[3]), tonumber(p[4])
        if p[2] and count and latest then
            Seen(sender)
            Comm.Answer(p[2], count, latest)
        end
    elseif kind == "W" then
        local key = msg:match("^W|(.+)$")
        if key and ns.Wipe then ns.Wipe.HeardClaim(key) end
    elseif kind == "P" then
        Seen(sender, msg:match("^P|(.+)$"))
    elseif kind == "H" then
        local owner, h = Comm.DecodeHealth(msg)
        -- only a player's own report counts: nobody reports for someone else
        if owner and ns.SameChar(ns.ShortName(owner), sender) then
            Seen(sender, h.v)
            ns.Health.Store(ns.ShortName(owner), h)
        end
    end
end

-- My health report to the guild; kept for myself too, so the Health page shows me.
function Comm.SendHealth()
    local me = ns.MyName()
    if not me or not ns.db or not ns.Health then return end
    local h = ns.Health.Mine()
    ns.Health.Store(me, h)
    if not ns.GuildName() then return end
    local told = {}
    for k, v in pairs(h) do told[k] = v end
    told.v = ns.Announced()
    Push({ msg = Comm.EncodeHealth(me, told) })
end

-- Guildies online with the addon: those heard from this session and online in the roster now.
function Comm.OnlinePeers()
    local online = {}
    local n = ns.Call(GetNumGuildMembers) or 0
    for i = 1, n do
        local name, _, _, _, _, _, _, _, isOnline = ns.Call(GetGuildRosterInfo, i)
        name = ns.ShortName(name)
        if name and isOnline then online[#online + 1] = name end
    end
    local count = 1 -- me
    for name in pairs(Comm.peers) do
        for _, o in ipairs(online) do
            if ns.SameChar(name, o) then
                count = count + 1
                break
            end
        end
    end
    return count
end

---------------------------------------------------------------------------
-- Start: register the prefix, and sync once the guild is known.
---------------------------------------------------------------------------
local synced, entered
local function TrySync()
    if synced or not entered or not ns.db then return end
    local guild = ns.GuildName()
    if not guild then return end
    synced = guild
    Comm.SendVector()
    Comm.SendHealth()
    if C_GuildInfo and C_GuildInfo.GuildRoster then pcall(C_GuildInfo.GuildRoster) end
    ns.Changed()
end

ns.On("PLAYER_LOGIN", function()
    local api = C_ChatInfo
    local register = api and api.RegisterAddonMessagePrefix or RegisterAddonMessagePrefix
    if register then pcall(register, Comm.PREFIX) end
end)
ns.On("PLAYER_ENTERING_WORLD", function()
    entered = true
    TrySync()
end)
ns.On("PLAYER_GUILD_UPDATE", function()
    -- joined (or changed) guild: sync the new book
    if synced and synced ~= ns.GuildName() then synced = nil end
    TrySync()
end)
-- Who is in the guild now, for the leaderboards (Data.Shown). An empty answer (not loaded yet)
-- changes nothing.
function Comm.ReadRoster()
    local guild = ns.GuildName()
    if not guild then return end
    local n = ns.Call(GetNumGuildMembers) or 0
    if type(n) ~= "number" or n <= 0 then return end
    local names = {}
    for i = 1, n do
        local name = ns.ShortName((ns.Call(GetGuildRosterInfo, i)))
        if name then names[#names + 1] = name end
    end
    if #names > 0 then ns.Data.SetMembers(guild, names) end
end

ns.On("GUILD_ROSTER_UPDATE", function()
    Comm.ReadRoster()
    TrySync()
    ns.Changed()
end)
ns.On("CHAT_MSG_ADDON", function(prefix, msg, channel, sender)
    Comm.OnMessage(prefix, msg, channel, sender)
end)
