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
--   U|version                                                            "I post the new-version line" (v0.8.7)
--   H|owner|version|logged|missed|step|errors|lastError                  how my addon is doing (Health.lua)
--   T|owner|t|named|week|text                                            the line I chose for my death (0.9.6), so popups match guild chat
--   D|reporter|winner|loser|K or F|t|winnerLevel|loserLevel|r            a guild duel (0.9.7, measurement; F = fled; r = answer to Q)
--   Q|from                                                               "I am complete up to this time, send me what follows"
--   K|npc|at|name                                                        the NPC number of a killer, learned by seeing it (0.9.8)
--   X|npc|at|name                                                        the same, as an answer to J
--   J|from|count|latest                                                  "I am complete up to from, and hold this many"
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
-- Duel reports per answer: what fits in one burst, so a sync never builds a queue (the stutter of
-- 0.9.4). A report is at most 100 bytes: "D" + 3 names of 25 + K/F + time 10 + 2 levels of 2 + "r" + 8 separators.
Comm.DUEL_MSG_MAX = 100
Comm.DUEL_SYNC_MAX = math.floor(Comm.BURST / (Comm.DUEL_MSG_MAX + Comm.OVERHEAD))
-- The same for NPC numbers: "K" + number 7 + time 10 + name TEXT_LEN 57 + 3 separators = 78 bytes.
Comm.NPC_MSG_MAX = 78
Comm.NPC_SYNC_MAX = math.floor(Comm.BURST / (Comm.NPC_MSG_MAX + Comm.OVERHEAD))

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

-- The raid boss (field 12, v0.8.7) and the role (field 13, v0.8.9: T, H or D) come last, so older
-- versions read their 11 or 12 fields and leave the rest. The role goes first (2 bytes); the boss
-- gets what is left of MAX_LEN, and a name that does not fit whole is left out (a cut-off name
-- would make a boss of its own on the leaderboard).
Comm.ROLE_CODE = { tank = "T", healer = "H", dps = "D" }
Comm.ROLE_FROM = { T = "tank", H = "healer", D = "dps" }
-- wait (field 15, 0.9.6): "w" = my line follows in a T message, hold the popup until then.
function Comm.EncodeRecord(kind, owner, r, wait)
    local n = Comm.TEXT_LEN
    local msg = table.concat({ kind, Clean(owner, Comm.NAME_LEN), tostring(r.t), Clean(r.c, 11), tostring(r.l or ""),
        Clean(r.it, 8), tostring(r.id or ""), tostring(r.d or ""), Clean(r.z, n), Clean(r.k, n), Clean(r.s, n) }, "|")
    -- after the fixed fields: boss (12), role (13), gender (14, 0.9.0: m/f for the death sound).
    -- Role and gender are one letter each and go before the boss in the byte budget.
    local extra = { Clean(r.b, Comm.MAX_LEN), Comm.ROLE_CODE[r.r or ""] or "", (r.g == "m" or r.g == "f") and r.g or "" }
    local function size(from, to)
        local n = 0
        for i = from, to do n = n + 1 + #extra[i] end
        return n
    end
    local last = 0
    for i = 1, 3 do if extra[i] ~= "" then last = i end end
    while last >= 2 and #msg + size(2, last) > Comm.MAX_LEN do
        extra[last] = ""
        last = last - 1
        while last >= 2 and extra[last] == "" do last = last - 1 end
    end
    if extra[1] ~= "" and #msg + size(1, math.max(last, 1)) > Comm.MAX_LEN then
        extra[1] = ""
        if last == 1 then last = 0 end
    end
    for i = 1, last do msg = msg .. "|" .. extra[i] end
    -- field 16 (0.9.8): what the killer is, an NPC number or the class of a player. Older versions
    -- read fewer fields and leave it. No room: the portrait goes first, the wait flag stays.
    local who = r.ni and tostring(r.ni) or (type(r.kc) == "string" and Clean(r.kc, 11)) or nil
    if wait or who then
        local tail = string.rep("|", 3 - last) .. "|" .. (wait and "w" or "")
        local full = who and (tail .. "|" .. who) or tail
        if #msg + #full <= Comm.MAX_LEN then
            msg = msg .. full
        elseif wait and #msg + #tail <= Comm.MAX_LEN then
            -- no room for the flag either: the receiver simply shows its popup at once, as before
            msg = msg .. tail
        end
    end
    return msg
end

-- The line of a death as it goes to guild chat (0.9.6). Before, every client drew its own random line.
-- text empty = no line in guild chat (off, boss fight, battleground): the receiver picks its own.
function Comm.EncodeLine(owner, t, text, named, week)
    local head = table.concat({ "T", Clean(owner, Comm.NAME_LEN), tostring(t), named and "1" or "0", tostring(week or 0) }, "|") .. "|"
    return head .. Clean(text, Comm.MAX_LEN - #head)
end

function Comm.DecodeLine(msg)
    local owner, t, named, week, text = msg:match("^T|([^|]+)|(%d+)|([01])|(%d+)|(.*)$")
    if not owner then return nil end
    return owner, tonumber(t), { text = text ~= "" and text or nil, named = named == "1", week = tonumber(week) }
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
-- 0.9.5: field 10 = the post log (Toast.PostLogText, "d35w12c,d35"), HEALTH_LOG_LEN bytes plus a
-- separator; older versions read 9 fields and leave it. The error text gets that much less.
Comm.HEALTH_POST_LEN = 12
Comm.HEALTH_LOG_LEN = 40
Comm.HEALTH_TEXT_LEN = Comm.MAX_LEN - 74 - 1 - Comm.HEALTH_LOG_LEN
function Comm.EncodeHealth(owner, h)
    return table.concat({ "H", Clean(owner, Comm.NAME_LEN), Clean(h.v, 10), tostring(h.n or 0), tostring(h.miss or 0),
        Clean(h.step, 8), tostring(h.err or 0), Clean(h.text, Comm.HEALTH_TEXT_LEN), Clean(h.post, Comm.HEALTH_POST_LEN),
        Clean(h.log, Comm.HEALTH_LOG_LEN) }, "|")
end

function Comm.DecodeHealth(msg)
    local p = Split(msg)
    if p[1] ~= "H" or #p < 8 or not Text(p[2]) then return nil end
    return p[2], { v = Text(p[3]), n = tonumber(p[4]) or 0, miss = tonumber(p[5]) or 0, step = Text(p[6]),
        err = tonumber(p[7]) or 0, text = Text(p[8]), post = Text(p[9]), log = Text(p[10]) }
end

function Comm.DecodeRecord(msg)
    local p = Split(msg)
    if (p[1] ~= "L" and p[1] ~= "R") or #p < 11 then return nil end
    local t = tonumber(p[3])
    if not t or not Text(p[2]) then return nil end
    return p[1], p[2], {
        t = t, c = Text(p[4]), l = tonumber(p[5]), it = Text(p[6]), id = tonumber(p[7]), d = tonumber(p[8]),
        z = Text(p[9]), k = Text(p[10]), s = Text(p[11]), b = Text(p[12]), r = Comm.ROLE_FROM[p[13] or ""],
        g = (p[14] == "m" or p[14] == "f") and p[14] or nil,
        ni = tonumber(p[16]), kc = not tonumber(p[16]) and p[16] and p[16]:match("^%u+$") or nil,
    }, p[15] == "w"
end

function Comm.EncodeNpc(e, answer)
    return table.concat({ answer and "X" or "K", tostring(e.id), tostring(e.at), Clean(e.name, Comm.TEXT_LEN) }, "|")
end

function Comm.DecodeNpc(msg)
    local id, at, name = msg:match("^[KX]|(%d+)|(%d+)|(.+)$")
    if not id then return nil end
    return { id = tonumber(id), at = tonumber(at), name = name }
end

function Comm.EncodeDuel(d, answer)
    return table.concat({ "D", Clean(d.by, Comm.NAME_LEN), Clean(d.w, Comm.NAME_LEN), Clean(d.l, Comm.NAME_LEN), d.k,
        tostring(d.t), tostring(d.wl or ""), tostring(d.ll or "") }, "|") .. (answer and "|r" or "")
end

-- Only a report by one of the two duelists counts.
function Comm.DecodeDuel(msg)
    local p = Split(msg)
    if p[1] ~= "D" or #p < 8 or (p[5] ~= "K" and p[5] ~= "F") then return nil end
    local by, w, l, t = ns.ShortName(p[2]), ns.ShortName(p[3]), ns.ShortName(p[4]), tonumber(p[6])
    if not by or not w or not l or not t or w == l then return nil end
    if not ns.SameChar(by, w) and not ns.SameChar(by, l) then return nil end
    return { by = by, w = w, l = l, k = p[5], t = t, wl = tonumber(p[7]), ll = tonumber(p[8]) }, p[9] == "r"
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
    -- Each part ends with ",#k/n" (part k of n, 0.9.5), so the receiver knows when it has the whole
    -- list. Room kept for it: "," + "#" + "/" + twice the digits of n (n <= number of entries).
    local reserve = 3 + 2 * #tostring(math.max(1, #entries))
    local parts, cur = {}, "V|"
    for _, e in ipairs(entries) do
        local add = (cur == "V|" and "" or ",") .. e
        if #cur + #add + reserve > Comm.MAX_LEN then
            parts[#parts + 1] = cur
            cur = "V|" .. e
        else
            cur = cur .. add
        end
    end
    parts[#parts + 1] = cur
    local msgs = {}
    for k, part in ipairs(parts) do
        msgs[k] = part .. (part == "V|" and "" or ",") .. "#" .. k .. "/" .. #parts
    end
    return msgs
end

-- Returns the entries, and for a 0.9.5+ sender the part number and the number of parts.
-- Older versions skip the "#k/n" entry: it does not match an entry.
function Comm.DecodeVector(msg)
    local body = msg:match("^V|(.*)$")
    if not body then return nil end
    local v, k, n = {}, nil, nil
    for entry in body:gmatch("[^,]+") do
        local name, count, latest, statAt = entry:match("^([^=]+)=(%d+):(%d+):?(%d*)$")
        if name then
            v[name] = { count = tonumber(count), latest = tonumber(latest), statAt = tonumber(statAt) or 0 }
        else
            local pk, pn = entry:match("^#(%d+)/(%d+)$")
            if pk then k, n = tonumber(pk), tonumber(pn) end
        end
    end
    return v, k, n
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
        return Comm.EncodeRecord(item.record.kind or "R", owner, r, item.record.wait)
    end
    if item.npc then
        local h = heard["K/" .. item.npc.name]
        if item.relay and h and h >= item.queued then return nil end -- someone else sent it
        return Comm.EncodeNpc(item.npc, item.relay)
    end
    if item.duel then
        local h = heard["D/" .. ns.Data.DuelKey(item.duel)]
        if item.relay and h and h >= item.queued then return nil end -- someone else sent it
        return Comm.EncodeDuel(item.duel, item.relay)
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
    -- One pass that keeps what still has to go, in order (0.9.5). table.remove per item shifted the
    -- whole queue each time: with thousands of items that was heavy for one frame.
    local kept, stop = {}, false
    for _, item in ipairs(queue) do
        if stop or (item.notBefore or 0) > now then
            kept[#kept + 1] = item
        else
            local msg = Build(item)
            if msg then
                local cost = #msg + Comm.OVERHEAD
                local result = budget >= cost and Raw(msg) or "wait"
                if result == "wait" or result == "throttled" then
                    if result == "throttled" then budget = 0 end
                    stop = true
                    kept[#kept + 1] = item
                else
                    budget = budget - cost
                    echoes[msg] = (echoes[msg] or 0) + 1
                    if item.record then heard[item.record.owner .. "/" .. item.record.t] = now end
                    if item.duel then heard["D/" .. ns.Data.DuelKey(item.duel)] = now end
                    if item.npc then heard["K/" .. item.npc.name] = now end
                    local sp = item.stat and ns.Book().players[item.stat.owner]
                    if sp and sp.stat then heard["S/" .. item.stat.owner .. "/" .. sp.stat.at] = now end
                end
            end
        end
    end
    queue = kept
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
function Comm.SendRecord(owner, t, kind, relay, wait)
    local delay = relay and math.random() * Comm.RELAY_JITTER or 0
    Push({ record = { owner = owner, t = t, kind = kind, wait = wait }, relay = relay, notBefore = GetTime() + delay })
end

function Comm.SendDuel(d) Push({ duel = d }) end

function Comm.SendNpc(name, id, at) Push({ npc = { name = name, id = id, at = at } }) end

-- Someone holds `count` numbers, the newest from `latest`, and is complete up to `from` (the newest
-- answer it got; a number heard live says nothing about older ones it missed while offline). Nothing
-- to add: stay quiet. Oldest first from `from`; the next login gets the rest.
function Comm.AnswerNpcs(from, count, latest)
    local book = ns.Book()
    local mine, newest = ns.Data.NpcSummary(book)
    if mine <= count and newest <= latest then return end
    for _, e in ipairs(ns.Data.NpcsFrom(book, from, Comm.NPC_SYNC_MAX)) do
        Push({ npc = e, relay = true, notBefore = GetTime() + math.random() * Comm.RELAY_JITTER })
    end
end

-- Someone asks for the duel reports after `after`: the oldest first, so the next login gets the rest.
function Comm.AnswerDuels(after)
    for _, d in ipairs(ns.Data.DuelsAfter(ns.Book(), after, Comm.DUEL_SYNC_MAX)) do
        Push({ duel = d, relay = true, notBefore = GetTime() + math.random() * Comm.RELAY_JITTER })
    end
end

function Comm.SendLine(owner, t, text, named, week)
    Push({ msg = Comm.EncodeLine(owner, t, text, named, week) })
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

-- One player: what they hold of `name` against what I hold.
local function Compare(book, name, theirs)
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

-- A V list comes in parts when it is long (Omen 18-11-2026: 48 players = 8 parts). Up to 0.9.4 every
-- part was read as the whole list: everyone not in that part counted as "holds 0", so each login
-- made every guildie queue all records again (measured: 4367 items, 742 needless R messages) and the
-- game stuttered. Now a part only counts for the names in it. Players the sender lacks entirely are
-- sent only once all n parts of a 0.9.5+ sender have arrived.
local vectors = {} -- sender -> { names = {}, got, last }
local function OnVector(sender, v, k, n)
    local book = ns.Book()
    local lo, hi
    for name in pairs(v) do
        local key = name .. "=" -- the sender sorted its entries "name=...", so compare like that
        if not lo or key < lo then lo = key end
        if not hi or key > hi then hi = key end
    end
    local st = vectors[sender]
    local first
    if k then
        first = k == 1
    else
        -- older sender: a new list starts when this part does not follow the previous one
        first = not st or not lo or not st.last or lo <= st.last
    end
    if first or not st then
        st = { names = {}, got = 0 }
        vectors[sender] = st
    end
    st.got, st.last = st.got + 1, hi
    for name, theirs in pairs(v) do
        st.names[name] = true
        Compare(book, name, theirs)
    end
    if k and n and k == n then
        if st.got == n then
            for name in pairs(book.players) do
                if not st.names[name] then Compare(book, name, { count = 0, latest = 0, statAt = 0 }) end
            end
        end
        vectors[sender] = nil
    end
    if not first then return end
    -- once per list, not once per part
    Push({ msg = "P|" .. ns.Announced() })
    local claim = Comm.UpdateClaim()
    if claim then Push({ msg = claim }) end
    local awards = ns.Awards and ns.Awards.Claim()
    if awards then Push({ msg = awards }) end
    if ns.Repair then ns.Repair.SendMine() end
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
    -- the addon cannot see files on disk: a version downloaded but not loaded yet still says the old
    -- number, hence the hint (08-11-2026). A restart, not /reload (09-11-2026): a new file in the
    -- addon (the logo of 0.8.8) only loads after a restart, and this old version cannot know
    -- whether the new one has such a file. A restart always works.
    return "Omen Deaths " .. Comm.newest .. " is out (you have " .. ns.VERSION .. "). Update in the CurseForge app or at " .. ns.DOWNLOAD
        .. " - this update requires a game restart"
end

local function Seen(sender, version)
    local p = Comm.peers[sender] or {}
    p.seen = GetTime()
    if version then p.version = version end
    Comm.peers[sender] = p
    if version and Comm.Newer(version, Comm.newest or ns.VERSION) then
        Comm.newest = version
        ns.Print("|cffff9900" .. Comm.UpdateText() .. "|r")
        if ns.Toast then ns.Toast.Update(version) end
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
        local k, owner, rec, wait = Comm.DecodeRecord(msg)
        if not k then return end
        owner = ns.ShortName(owner)
        heard[owner .. "/" .. rec.t] = GetTime()
        Seen(sender)
        local result = ns.Data.Add(ns.Book(), owner, rec, ns.SameChar(owner, sender))
        if result then ns.Changed() end
        if result == "new" and k == "L" and ns.Toast then ns.Toast.Incoming(owner, rec, wait) end
    elseif kind == "T" then
        local owner, t, line = Comm.DecodeLine(msg)
        if not owner then return end
        owner = ns.ShortName(owner)
        -- only who died speaks for that death
        if owner and ns.SameChar(owner, sender) and ns.Toast then
            Seen(sender)
            ns.Toast.HeardLine(owner, t, line)
        end
    elseif kind == "D" then
        local d, answer = Comm.DecodeDuel(msg)
        if d then
            heard["D/" .. ns.Data.DuelKey(d)] = GetTime()
            Seen(sender)
            local book = ns.Book()
            -- only an answer moves this: a duel heard live says nothing about older ones missed offline
            if answer and d.t > (book.duelFrom or 0) then book.duelFrom = d.t end
            ns.Data.AddDuel(book, d)
        end
    elseif kind == "K" or kind == "X" then
        local e = Comm.DecodeNpc(msg)
        if e then
            heard["K/" .. e.name] = GetTime()
            Seen(sender)
            local book = ns.Book()
            if kind == "X" and e.at > (book.npcFrom or 0) then book.npcFrom = e.at end
            if ns.Data.LearnNpc(book, e.name, e.id, e.at) then ns.Changed() end
        end
    elseif kind == "J" then
        local from, count, latest = msg:match("^J|(%d+)|(%d+)|(%d+)$")
        if from then
            Seen(sender)
            Comm.AnswerNpcs(tonumber(from), tonumber(count), tonumber(latest))
        end
    elseif kind == "Q" then
        local after = tonumber(msg:match("^Q|(%d+)$"))
        if after then
            Seen(sender)
            Comm.AnswerDuels(after)
        end
    elseif kind == "S" then
        local p = Split(msg)
        local owner, total, at = ns.ShortName(p[2]), tonumber(p[3]), tonumber(p[4])
        if owner and total and at then
            heard["S/" .. owner .. "/" .. at] = GetTime()
            Seen(sender)
            if ns.Data.SetStat(ns.Book(), owner, total, at, p[5], tonumber(p[6])) then ns.Changed() end
        end
    elseif kind == "V" then
        local v, k, n = Comm.DecodeVector(msg)
        if v then
            Seen(sender)
            OnVector(sender, v, k, n)
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
    elseif kind == "M" then
        -- repairs: only a player's report about themselves counts
        local owner, days
        if ns.Repair then owner, days = ns.Repair.Decode(msg) end
        if owner then
            owner = ns.ShortName(owner)
            Seen(sender)
            local changed = false
            if ns.SameChar(owner, sender) then
                for _, d in ipairs(days) do
                    if ns.Repair.Add(ns.Book(), owner, d.day, d.c, d.n) then changed = true end
                end
            end
            if changed then ns.Changed() end
        end
    elseif kind == "A" then
        local week = msg:match("^A|(%d+)$")
        if week and ns.Awards then ns.Awards.Heard(week) end
    elseif kind == "U" then
        local v = msg:match("^U|(.+)$")
        if v then Comm.HeardUpdateClaim(v) end
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

---------------------------------------------------------------------------
-- New version in guild chat (09-11-2026, wish of the user): the first guildie who loads a new
-- released version posts one line, once per version per guild. Not from a test copy (it tells
-- the guild the released version: ns.Announced() ~= ns.VERSION), not when Guild chat is Off.
-- Known as posted (book.updateSeen): I posted it, or heard a claim U|version. Whoever knows sends
-- the claim along with the answer to every V (a guildie logging in), so a late loader hears it.
-- Also posted already: a saved Health report from an earlier session shows a guildie on this
-- version or newer (they loaded it first). A guildie seen on it only this session is no proof:
-- two loading it at the same time would then both stay quiet.
---------------------------------------------------------------------------
-- Wait after the sync: answers to my V (P and U) are sent at once; plus 0.55 s on the way (the
-- slowest echo measured, 08-11-2026) and RELAY_JITTER for the paced queue. Then a random
-- 0..RELAY_JITTER, so two loading at the same time do not both post (as Wipe does).
Comm.UPDATE_WAIT = Comm.RELAY_JITTER + 0.55
local sessionStart
function Comm.SessionStart() return sessionStart end

local function SeenVersion(book, version)
    if not book.updateSeen or Comm.Newer(version, book.updateSeen) then book.updateSeen = version end
end

function Comm.HeardUpdateClaim(version)
    if ns.db and ns.GuildName() then SeenVersion(ns.Book(), version) end
end

-- What this version brings, for the line in guild chat. Change it with each release.
Comm.UPDATE_NEWS = "to get your own funny death line in every dungeon boss fight"
function Comm.UpdateLine()
    return ns.Toast.Fit("[Omen Deaths] Hey you! Omen Deaths " .. ns.VERSION .. " is out. Install the newest version "
        .. Comm.UPDATE_NEWS .. ": CurseForge app or " .. ns.DOWNLOAD)
end

-- A saved Health report from before this session: another guildie on this version or newer.
function Comm.HadItBefore(version)
    local me = ns.MyName()
    for name, h in pairs(ns.Book().health or {}) do
        if type(h.v) == "string" and not ns.SameChar(name, me) and not Comm.Newer(version, h.v)
            and type(h.at) == "number" and sessionStart and h.at < sessionStart then
            return true
        end
    end
    return false
end

function Comm.MaybeAnnounce()
    if not ns.db or ns.Announced() ~= ns.VERSION or not ns.GuildName() then return end
    if not ns.db.settings.guildChat then return end
    local book = ns.Book()
    if book.updateSeen and not Comm.Newer(ns.VERSION, book.updateSeen) then return end
    SeenVersion(book, ns.VERSION)
    if Comm.HadItBefore(ns.VERSION) then return end
    Comm.SendRaw("U|" .. ns.VERSION)
    ns.Toast.Post(Comm.UpdateLine(), false, "u")
end

-- With my answer to a V: the newest version I know was posted.
function Comm.UpdateClaim()
    local seen = ns.db and ns.GuildName() and ns.Book().updateSeen
    if seen then return "U|" .. seen end
end

-- A guild member by name: the name as the roster has it, and their level. nil when not in the guild.
function Comm.RosterMember(wanted)
    local n = ns.Call(GetNumGuildMembers) or 0
    for i = 1, n do
        local name, _, _, level = ns.Call(GetGuildRosterInfo, i)
        name = ns.ShortName(name)
        if name and ns.SameChar(name, wanted) then return name, type(level) == "number" and level or nil end
    end
end

-- Who has the addon and is online, by first name in a fixed order: every client gets the same list,
-- so they can take turns (the boss summary, 0.9.6). First names: a sender's name may lack the surname.
function Comm.OnlineOrder()
    local me, list = ns.MyName(), {}
    local n = ns.Call(GetNumGuildMembers) or 0
    for i = 1, n do
        local name, _, _, _, _, _, _, _, isOnline = ns.Call(GetGuildRosterInfo, i)
        name = ns.ShortName(name)
        if name and isOnline then
            local has = ns.SameChar(name, me)
            if not has then
                for peer in pairs(Comm.peers) do
                    if ns.SameChar(peer, name) then has = true break end
                end
            end
            if has then list[#list + 1] = ns.FirstName(name) or name end
        end
    end
    table.sort(list)
    return list
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
    sessionStart = sessionStart or ns.Now()
    Comm.SendVector()
    Push({ msg = "Q|" .. (ns.Book().duelFrom or 0) })
    local npcCount, npcLatest = ns.Data.NpcSummary(ns.Book())
    Push({ msg = "J|" .. (ns.Book().npcFrom or 0) .. "|" .. npcCount .. "|" .. npcLatest })
    Comm.SendHealth()
    if ns.Repair then ns.Repair.SendMine() end
    local wait = Comm.UPDATE_WAIT + math.random() * Comm.RELAY_JITTER
    if C_Timer and C_Timer.After then
        C_Timer.After(wait, function()
            Comm.MaybeAnnounce()
            if ns.Awards then ns.Awards.Maybe() end
        end)
    end
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
