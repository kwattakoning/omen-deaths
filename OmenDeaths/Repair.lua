-- Omen Deaths: auto repair at a merchant, and who pays the most for repairs (0.9.0, wish of the user:
-- on by default, with a leaderboard).
-- Counting: while a merchant that repairs is open, every drop of the repair bill (GetRepairAllCost) is a
-- repair: automatic, by hand (Repair All or one item) alike. Buying something does not change the bill.
-- Kept per day: book.players[name].rep[dayStart] = { c = copper, n = repairs }. Each player sends only
-- their own (M|owner|day|copper|n), at a repair and at login for the last SYNC_DAYS days.
local _, ns = ...
local Repair = {}
ns.Repair = Repair

Repair.SYNC_DAYS = 31 -- the longest tab with its own period, This Month, has at most 31 days
-- Day starts come from "seconds until the daily reset" on each client; whole seconds, so they can
-- differ by a second. A bucket within a minute of the start of a period belongs to it.
Repair.SAME_DAY = 60

local function Cost()
    local c = ns.Safe(ns.Call(GetRepairAllCost))
    return type(c) == "number" and c or nil
end

-- "1g 23s 45c" without the parts that are 0
function Repair.Money(copper)
    copper = math.floor(copper or 0)
    local g, s, c = math.floor(copper / 10000), math.floor(copper / 100) % 100, copper % 100
    local parts = {}
    if g > 0 then parts[#parts + 1] = g .. "g" end
    if s > 0 then parts[#parts + 1] = s .. "s" end
    if c > 0 or #parts == 0 then parts[#parts + 1] = c .. "c" end
    return table.concat(parts, " ")
end

-- For the number column, as the game shows money: a coin icon after each number, the two biggest
-- coins only (fits the column). 0.9.0 showed "14s" in the window's font next to a gold coin, which
-- read as "148" gold (user, 10-11-2026).
Repair.ICONS = { g = "Interface\\MoneyFrame\\UI-GoldIcon", s = "Interface\\MoneyFrame\\UI-SilverIcon",
    c = "Interface\\MoneyFrame\\UI-CopperIcon" }
function Repair.Coins(copper)
    copper = math.floor(copper or 0)
    local parts = { { "g", math.floor(copper / 10000) }, { "s", math.floor(copper / 100) % 100 }, { "c", copper % 100 } }
    local first = 3
    for i = 1, 3 do if parts[i][2] > 0 then first = i break end end
    local out = {}
    for i = first, math.min(first + 1, 3) do
        out[#out + 1] = parts[i][2] .. "|T" .. Repair.ICONS[parts[i][1]] .. ":0:0:2:0|t"
    end
    return table.concat(out, " ")
end

-- Short, as text: only the biggest coin ("12g", "34s", "56c").
function Repair.Short(copper)
    copper = math.floor(copper or 0)
    if copper >= 10000 then return math.floor(copper / 10000) .. "g" end
    if copper >= 100 then return math.floor(copper / 100) .. "s" end
    return copper .. "c"
end

-- Stores a day of `owner`. The owner's own report always wins (it is the only source).
function Repair.Add(book, owner, day, copper, n)
    if type(owner) ~= "string" or owner == "" or type(day) ~= "number" or type(copper) ~= "number" then return false end
    local p = book.players[owner]
    if not p then
        p = { deaths = {} }
        book.players[owner] = p
    end
    p.rep = p.rep or {}
    local old = p.rep[day]
    if old and old.c == copper and old.n == n then return false end
    p.rep[day] = { c = copper, n = n or 0 }
    return true
end

-- Messages: "M|owner|day,copper,n;day,copper,n;..." with as many days as fit in MAX bytes.
Repair.MAX = 250 -- the game's limit for one addon message
function Repair.Encode(owner, days)
    local head, out, parts = "M|" .. owner .. "|", {}, {}
    local function flush()
        if #parts > 0 then out[#out + 1] = head .. table.concat(parts, ";") end
        parts = {}
    end
    for _, d in ipairs(days) do
        local part = ("%d,%d,%d"):format(d.day, d.c, d.n or 0)
        if #head + #table.concat(parts, ";") + 1 + #part > Repair.MAX then flush() end
        parts[#parts + 1] = part
    end
    flush()
    return out
end
function Repair.Decode(msg)
    local owner, rest = msg:match("^M|([^|]+)|(.+)$")
    if not owner then return nil end
    local days = {}
    for day, c, n in rest:gmatch("(%d+),(%d+),(%d+)") do
        days[#days + 1] = { day = tonumber(day), c = tonumber(c), n = tonumber(n) }
    end
    return owner, days
end

local function Send(owner, days)
    if not ns.GuildName() then return end
    for _, msg in ipairs(Repair.Encode(owner, days)) do ns.Comm.SendRaw(msg) end
end

-- My days of the last SYNC_DAYS days to the guild: at my login, and when a guildie logs in (with the
-- answer to their V), so who logs in later sees them too.
function Repair.SendMine()
    local me = ns.MyName()
    local p = me and ns.db and ns.Book().players[me]
    if not p or not p.rep then return end
    local from, days = ns.Now() - Repair.SYNC_DAYS * 86400, {}
    for day, b in pairs(p.rep) do
        if day >= from then days[#days + 1] = { day = day, c = b.c, n = b.n } end
    end
    table.sort(days, function(x, y) return x.day < y.day end)
    Send(me, days)
end

local open, auto -- open = { cost = bill now } while a merchant that repairs is open; auto = I repaired

function Repair.Paid(copper)
    local me = ns.MyName()
    if not me or not ns.db or copper <= 0 then return end
    local book, day = ns.Book(), ns.Data.PeriodStart("day")
    local p = book.players[me] or { deaths = {} }
    book.players[me] = p
    p.rep = p.rep or {}
    local b = p.rep[day] or { c = 0, n = 0 }
    b.c, b.n = b.c + copper, b.n + 1
    p.rep[day] = b
    if auto then ns.Print("Repaired for " .. Repair.Money(copper) .. ".") end
    Send(me, { { day = day, c = b.c, n = b.n } })
    ns.Changed()
end

-- The bill went down while the merchant is open: that much was repaired.
function Repair.Check()
    if not open then return end
    local c = Cost()
    if not c then return end
    if c < open.cost then
        local paid = open.cost - c
        open.cost = c
        Repair.Paid(paid)
    else
        open.cost = c
    end
end

function Repair.Show()
    open, auto = nil, false
    if ns.Call(CanMerchantRepair) ~= true then return end
    local cost = Cost() or 0
    open = { cost = cost }
    if not (ns.db and ns.db.settings.autoRepair) or cost <= 0 or not RepairAllItems then return end
    local _, can = ns.Call(GetRepairAllCost)
    if ns.Safe(can) == false then return end
    -- the guild pays when it lets me (guild banks may not exist in Forever: only if the client has it)
    local guild = CanGuildBankRepair and ns.Call(CanGuildBankRepair) == true
    if guild and GetGuildBankWithdrawMoney then
        local left = ns.Safe(ns.Call(GetGuildBankWithdrawMoney))
        guild = type(left) == "number" and (left == -1 or left >= cost)
    end
    if not guild then
        local money = ns.Safe(ns.Call(GetMoney))
        if type(money) ~= "number" or money < cost then return end
    end
    auto = true
    pcall(RepairAllItems, guild or nil)
    Repair.Check()
end

ns.On("MERCHANT_SHOW", function() Repair.Show() end)
ns.On("MERCHANT_CLOSED", function()
    Repair.Check()
    open, auto = nil, false
end)
for _, event in ipairs({ "UPDATE_INVENTORY_DURABILITY", "PLAYER_MONEY", "MERCHANT_UPDATE" }) do
    ns.On(event, function() Repair.Check() end)
end

-- Who paid the most: { name, class, count = copper, n = repairs }, most first.
function Repair.Board(book, period, now)
    local from = period == "all" and 0 or ns.Data.PeriodStart(period, now) - Repair.SAME_DAY
    local list = {}
    for name, p in pairs(book.players) do
        if p.rep and ns.Data.Shown(name) then
            local c, n = 0, 0
            for day, b in pairs(p.rep) do
                if day >= from then c, n = c + b.c, n + (b.n or 0) end
            end
            if c > 0 then list[#list + 1] = { name = name, class = p.class, count = c, n = n } end
        end
    end
    table.sort(list, function(a, b)
        if a.count ~= b.count then return a.count > b.count end
        return a.name < b.name
    end)
    return list
end
