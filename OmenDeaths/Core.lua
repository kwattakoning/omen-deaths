-- Omen Deaths: shared basics (saved data, events, safe calls, names).
local ADDON, ns = ...
_G.OmenDeaths = ns

ns.VERSION = "0.8.2"
ns.NO_GUILD = "(no guild)"
-- Where the newest version is: the page with the download button (short, as it has to be typed over:
-- links in WoW chat cannot be clicked).
ns.DOWNLOAD = "github.com/kwattakoning/omen-deaths"

---------------------------------------------------------------------------
-- Secret values: in this client some answers can be "secret" during combat.
-- They may be shown but not compared, so we treat them as unknown.
---------------------------------------------------------------------------
local function IsSecret(v) return issecretvalue ~= nil and issecretvalue(v) end
ns.IsSecret = IsSecret

function ns.Safe(v)
    if IsSecret(v) then return nil end
    return v
end

local function pack(...) return { n = select("#", ...), ... } end

-- Calls fn safely: an error or a secret answer comes back as nil.
function ns.Call(fn, ...)
    if type(fn) ~= "function" then return end
    local r = pack(pcall(fn, ...))
    if not r[1] then return end
    for i = 2, r.n do
        if IsSecret(r[i]) then r[i] = nil end
    end
    return unpack(r, 2, r.n)
end

function ns.Now()
    local t = ns.Call(GetServerTime)
    if type(t) == "number" then return t end
    return time()
end

-- "Name-Realm" -> "Name". Forever has no realms to tell apart inside one guild.
-- A surname stays: "Mira Stone-Realm" -> "Mira Stone".
function ns.ShortName(name)
    if type(name) ~= "string" or IsSecret(name) or name == "" then return nil end
    return (name:match("^[^%-]+")) or name
end

-- Forever characters have a first name and a surname ("Mira Stone"); the full name is
-- unique in the region, the first name alone is not. UnitName gives only the first name;
-- UnitNameUnmodified gives both when RegionalUniqueNamesEnabled() (as AceDB-3.0 in this
-- client builds its "Name Surname" profile keys). Elsewhere its second answer is a realm.
function ns.MyName()
    if ns.Call(RegionalUniqueNamesEnabled) == true then
        local first, surname = ns.Call(UnitNameUnmodified, "player")
        if type(first) == "string" and first ~= "" then
            if type(surname) == "string" and surname ~= "" then return first .. " " .. surname end
            return first
        end
    end
    return ns.ShortName(ns.Call(UnitName, "player"))
end

function ns.FirstName(name)
    if type(name) ~= "string" then return nil end
    return name:match("^[^%s%-]+")
end

-- Same character? One side may lack the surname (the addon channel's sender name, or a
-- guildie on an older version); then the first names decide.
function ns.SameChar(a, b)
    a, b = ns.ShortName(a), ns.ShortName(b)
    if not a or not b then return false end
    if a == b then return true end
    if a:find(" ", 1, true) and b:find(" ", 1, true) then return false end
    return ns.FirstName(a) == ns.FirstName(b)
end

function ns.Print(msg)
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cffc41e3aOmen Deaths|r: " .. tostring(msg))
    end
end

---------------------------------------------------------------------------
-- Events: ns.On(event, fn). Unknown events are skipped instead of breaking the addon.
---------------------------------------------------------------------------
local frame = CreateFrame("Frame")
ns.eventFrame = frame
local handlers = {}

function ns.On(event, fn)
    if not handlers[event] then
        handlers[event] = {}
        pcall(frame.RegisterEvent, frame, event)
    end
    table.insert(handlers[event], fn)
end

frame:SetScript("OnEvent", function(_, event, ...)
    for _, fn in ipairs(handlers[event] or {}) do
        local ok, err = pcall(fn, ...)
        if not ok then
            -- kept for the Health report; counted again from 0 with each new version
            if ns.db then
                local e = ns.db.errors
                if type(e) ~= "table" or e.v ~= ns.VERSION then e = { n = 0, v = ns.VERSION } end
                e.n, e.text, e.at, e.event = e.n + 1, tostring(err):sub(1, 300), ns.Now and ns.Now() or nil, event
                ns.db.errors = e
            end
            if geterrorhandler then geterrorhandler()(err) end
        end
    end
end)

---------------------------------------------------------------------------
-- Saved data. One "book" of deaths per guild, so an alt in another guild
-- keeps its own leaderboard.
---------------------------------------------------------------------------
local DEFAULT_SETTINGS = { toast = true, chat = true, guildChat = true, minimapAngle = 200 }

ns.On("ADDON_LOADED", function(name)
    if name ~= ADDON then return end
    OmenDeathsDB = type(OmenDeathsDB) == "table" and OmenDeathsDB or {}
    local db = OmenDeathsDB
    db.guilds = db.guilds or {}
    db.settings = db.settings or {}
    for k, v in pairs(DEFAULT_SETTINGS) do
        if db.settings[k] == nil then db.settings[k] = v end
    end
    ns.db = db
end)

function ns.GuildName()
    if IsInGuild and not ns.Call(IsInGuild) then return nil end
    local name = ns.Call(GetGuildInfo, "player")
    if type(name) == "string" and name ~= "" then return name end
end

function ns.Book(guild)
    guild = guild or ns.GuildName() or ns.NO_GUILD
    local book = ns.db.guilds[guild]
    if not book then
        book = { players = {} }
        ns.db.guilds[guild] = book
    end
    return book
end

-- Classes for colours and icons: "PRIEST" -> class colour / "Priest" icon name.
function ns.ClassColor(class)
    local c = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
    if c then return c.r, c.g, c.b end
    return 0.85, 0.85, 0.85
end

function ns.Colored(text, r, g, b)
    local function byte(x) return math.floor(math.max(0, math.min(1, x)) * 255 + 0.5) end
    return ("|cff%02x%02x%02x%s|r"):format(byte(r), byte(g), byte(b), text)
end

function ns.ClassIcon(class)
    if type(class) ~= "string" or class == "" then
        return "Interface\\Icons\\INV_Misc_Bone_HumanSkull_01"
    end
    return "Interface\\Icons\\ClassIcon_" .. class:sub(1, 1) .. class:sub(2):lower()
end

-- Something changed: redraw whatever is open.
function ns.Changed()
    if ns.UI and ns.UI.Refresh then ns.UI.Refresh() end
end
