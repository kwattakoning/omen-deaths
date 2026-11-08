-- Omen Deaths: how the addon is doing for each guildie (08-11-2026, wish of the player:
-- "if someone reports a bug, can I see it?").
-- Every addon tells its own health in one hidden guild message, at login and after each death:
--   H|owner|version|logged|missed|step|errors|lastError|post
-- logged = deaths in the measurement log (the last Death.LOG_KEEP), missed = of those without
-- killer and cause, step = where the latest missed one stopped, errors = errors caught in the
-- addon's own event handlers since this version, lastError = the text of the latest one,
-- post = how the guild chat line of the latest death went (Toast.Note; from v0.8.4).
-- Each player keeps what they heard per guild, in book.health[name].
local _, ns = ...
local Health = {}
ns.Health = Health

-- What my own addon would report now.
function Health.Mine()
    local db = ns.db or {}
    local log = db.recapLog or {}
    local missed, step = 0, nil
    for _, e in ipairs(log) do
        if not e.found then
            missed = missed + 1
            local tr = e.last or e.first
            step = tr and tr.step or "?"
        end
    end
    local err = db.errors or {}
    local lp = db.lastPost
    local post = lp and lp.r and (lp.r .. (lp.echo and ("/" .. string.format("%.2f", lp.echo)) or ""))
    return { v = ns.VERSION, n = #log, miss = missed, step = step, err = err.n or 0, text = err.text, post = post }
end

-- A report heard (or my own): kept with the time it came in.
function Health.Store(owner, h)
    if type(owner) ~= "string" or owner == "" or type(h) ~= "table" then return end
    local book = ns.Book()
    book.health = book.health or {}
    h.at = ns.Now()
    book.health[owner] = h
    ns.Changed()
end

-- Problems of a report: deaths without a cause plus errors.
function Health.Problems(h)
    return (h.miss or 0) + (h.err or 0)
end

-- The reports of this guild for the Health page: most problems first, then by name.
function Health.List(book)
    local list = {}
    for name, h in pairs(book.health or {}) do
        local p = book.players and book.players[name]
        if ns.Data.Shown(name) then
            list[#list + 1] = { name = name, class = p and p.class, count = Health.Problems(h), h = h }
        end
    end
    table.sort(list, function(a, b)
        if a.count ~= b.count then return a.count > b.count end
        return a.name < b.name
    end)
    return list
end

-- The guild chat result in words, for the tooltip.
Health.POST_TEXT = {
    sent = "sent", off = "not sent: Guild chat is Off", bg = "not sent: battleground (No BG)",
    boss = "not sent: counted as a boss fight", wait = "waiting: the game holds chat back",
    queued = "about to be sent", err = "failed: the game refused it (see latest error)",
    noguild = "not sent: not in a guild", sent = "sent, not seen in guild chat yet",
    arrived = "arrived in guild chat", retried = "arrived after a second try (at a click)",
    lost = "did not arrive, also not after a second try",
}
Health.POST_BAD = { err = true, boss = true, lost = true }

-- "arrived/0.50" -> "arrived in guild chat (after 0.50 s)", bad
function Health.PostText(post)
    local code, echo = post:match("^([^/]+)/?(.*)$")
    local text = Health.POST_TEXT[code] or code
    if echo and echo ~= "" then text = text .. " (after " .. echo .. " s)" end
    return text, Health.POST_BAD[code] == true
end

-- One line about a report: "v0.8.0 · 1 of 20 deaths without a cause (stopped at latest) · 0 errors".
function Health.Line(h)
    local v = "v" .. tostring(h.v or "?")
    if h.v and ns.Comm.Newer(ns.VERSION, h.v) then v = v .. " (old)" end
    local deaths = (h.n or 0) == 0 and "no deaths logged yet" or (h.miss or 0) > 0
        and ((h.miss .. " of " .. (h.n or 0) .. " without a cause") .. (h.step and (" (stopped at " .. h.step .. ")") or ""))
        or ((h.n or 0) .. " deaths, all with a cause")
    local err = (h.err or 0) == 1 and "1 error" or ((h.err or 0) .. " errors")
    return v .. " · " .. deaths .. " · " .. err
end
