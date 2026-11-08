-- Omen Deaths: the little banner (and chat line) when a guildie dies.
local _, ns = ...
local Toast = {}
ns.Toast = Toast

-- How long the banner stays, then fades (a feel choice, not measured).
local SHOW, FADE = 6, 1

local SELF = {
    "You died. Again.",
    "You died. The Spirit Healer waves hello.",
    "You died. Your repair bill sends its regards.",
    "You died. Omen will remember this.",
    "You died. Walk it off, ghost.",
}

local frame

---------------------------------------------------------------------------
-- Guild chat: the one who died posts one funny line, so guildies without the addon see it too.
-- Only your own death, only when "Guild chat" is on. While the game holds chat back
-- (C_ChatInfo.InChatMessagingLockdown, e.g. in a boss fight) the line waits, as PPForever does.
---------------------------------------------------------------------------
Toast.CHAT_MAX = 255 -- the game's limit for a chat line
local outbox = {}
local poster = CreateFrame("Frame")
poster:Hide()

local function Locked()
    local api = C_ChatInfo
    return api and ns.Call(api.InChatMessagingLockdown) == true
end

-- How the guild chat line of my latest death went, for the Health report (08-11-2026: a guildie's
-- death got no line and nothing showed why). One word: off, bg (No BG), boss (counted as a boss
-- fight), wait (the game holds chat back), queued, err (the game refused it), noguild, sent (sent,
-- not seen back yet), arrived (seen back in guild chat), retried (seen back after the second try),
-- lost (not seen back, also not after the second try). echo = seconds until it was seen back.
function Toast.Note(result, err, echo)
    if not ns.db then return end
    ns.db.lastPost = { r = result, at = ns.Now(), echo = echo }
    if err then ns.NoteError(err, "guild chat") end
end

local function Report()
    if ns.Comm and ns.Comm.SendHealth then ns.Comm.SendHealth() end
end

local function Send(msg)
    local send = C_ChatInfo and C_ChatInfo.SendChatMessage or SendChatMessage
    if not send then return false, "no way to send chat" end
    return pcall(send, msg, "GUILD")
end

-- Echo check (08-11-2026): Chrysi's line went out without an error but never showed in guild chat,
-- while a line he typed did. Everyone sees their own guild lines come back (CHAT_MSG_GUILD). If
-- mine has not come back, it goes once more at the player's next click (Release Spirit, accepting a
-- res, a click in the world): sent from a click it goes out as a typed line does.
-- ECHO_WAIT: the echo of a line came back after 0.50 and 0.53 s (two measurements by the player, 08-11-2026);
-- a click sooner than this could send a line whose echo is still on its way, so twice.
Toast.ECHO_WAIT = 1
local waiting -- my line not seen back yet: { msg, at = GetTime() of the latest try, tries }

poster:SetScript("OnUpdate", function(self)
    if Locked() then return end
    local mine = false
    while outbox[1] do
        local item = table.remove(outbox, 1)
        if not ns.GuildName() then
            if item.mine then Toast.Note("noguild") end
        else
            local ok, err = Send(item.msg)
            if item.mine then
                Toast.Note(ok and "sent" or "err", not ok and err or nil)
                waiting = ok and { msg = item.msg, at = GetTime(), tries = 1 } or nil
                mine = true
            end
        end
    end
    self:Hide()
    -- the guild sees at once how it went
    if mine then Report() end
end)

local function Trim(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end

-- A line in guild chat: is it mine coming back?
function Toast.Heard(text, sender)
    if not waiting then return end
    local fromMe = ns.IsSecret(sender) or ns.SameChar(sender, ns.MyName())
    if not fromMe then return end
    if not ns.IsSecret(text) and (type(text) ~= "string" or Trim(text) ~= Trim(waiting.msg)) then return end
    local echo = math.floor((GetTime() - waiting.at) * 100 + 0.5) / 100
    Toast.Note(waiting.tries > 1 and "retried" or "arrived", nil, echo)
    waiting = nil
    Report()
end
ns.On("CHAT_MSG_GUILD", function(text, sender) Toast.Heard(text, sender) end)

-- The player clicked: my line not seen back yet goes once more.
function Toast.Click()
    if not waiting or GetTime() - waiting.at < Toast.ECHO_WAIT then return end
    if waiting.tries >= 2 then
        waiting = nil
        Toast.Note("lost")
        Report()
        return
    end
    local ok, err = Send(waiting.msg)
    waiting.tries, waiting.at = 2, GetTime()
    if not ok then
        waiting = nil
        Toast.Note("err", err)
        Report()
    end
end

-- Clicks to listen to: the buttons of the game's popups (StaticPopup1-4, under several names as
-- client versions differ) and clicks in the world. Only those that exist; hooked once each.
local hooked = {}
local function Hook(frame, script)
    if type(frame) ~= "table" or hooked[frame] or not frame.HookScript then return end
    hooked[frame] = true
    pcall(frame.HookScript, frame, script, function() Toast.Click() end)
end
function Toast.HookClicks()
    Hook(WorldFrame, "OnMouseDown")
    for i = 1, Toast.POPUPS do
        local p = _G["StaticPopup" .. i]
        if type(p) == "table" then
            -- rawget: a frame's child keys are plain fields; a missing one is simply nil
            local box = rawget(p, "ButtonContainer")
            for j = 1, 4 do
                Hook(rawget(p, "button" .. j), "OnClick")
                Hook(_G["StaticPopup" .. i .. "Button" .. j], "OnClick")
                if type(box) == "table" then Hook(rawget(box, "Button" .. j), "OnClick") end
            end
        end
    end
end
ns.On("PLAYER_LOGIN", function() Toast.HookClicks() end)

-- "[Omen Deaths] Hogger says hi to Benny - by Rend in Elwynn Forest. Deaths this week: 3"
function Toast.GuildLine(owner, rec)
    local text, named = ns.Lines.For(rec, owner)
    local line = "[Omen Deaths] " .. text
    local detail = ns.Lines.Detail(rec, named)
    if detail ~= "" then line = line .. " - " .. detail end
    local n = ns.Data.CountFor(ns.Book(), owner, "week")
    if n > 0 then line = line .. ". Deaths this week: " .. n end
    return Toast.Fit(line)
end

-- No "|" (chat escape codes) and at most CHAT_MAX bytes, not cutting a character in half.
function Toast.Fit(line)
    line = line:gsub("|", "")
    if #line > Toast.CHAT_MAX then
        line = line:sub(1, Toast.CHAT_MAX):gsub("[\192-\255][\128-\191]*$", "")
    end
    return line
end

-- Posts a line in guild chat as soon as chat is allowed. mine = the line of my own death.
function Toast.Post(line, mine)
    outbox[#outbox + 1] = { msg = Toast.Fit(line), mine = mine }
    if mine then Toast.Note(Locked() and "wait" or "queued") end
    poster:Show()
end

function Toast.GuildPost(owner, t)
    if not ns.db or owner ~= ns.MyName() then return end
    if not ns.db.settings.guildChat then return Toast.Note("off") end
    if not ns.GuildName() then return Toast.Note("noguild") end
    local p = ns.Book().players[owner]
    local rec = p and p.deaths[t]
    if not rec then return end
    if (rec.it == "pvp" or rec.it == "arena") and not ns.db.settings.guildChatBG then return Toast.Note("bg") end
    -- died in a boss fight: the summary after the fight covers it (Wipe.lua)
    if ns.Wipe and ns.Wipe.Covers(rec) then return Toast.Note("boss") end
    Toast.Post(Toast.GuildLine(owner, rec), true)
end

-- The game's own popups (StaticPopup1-4, "Release Spirit" among them) stand at the top of the
-- screen in a higher layer and covered the toast (08-11-2026). The toast goes under the lowest one
-- that is open, else at its own place.
Toast.TOP_Y = -140      -- own place when no popup is open (as before)
Toast.POPUP_GAP = 4     -- between the game's popup and the toast
Toast.POPUPS = 4        -- the game has StaticPopup1 to StaticPopup4
function Toast.Anchor()
    local below
    for i = 1, Toast.POPUPS do
        local p = _G["StaticPopup" .. i]
        if p and p.IsShown and p:IsShown() then below = p end
    end
    if below == frame.below then return end
    frame.below = below
    frame:ClearAllPoints()
    if below then
        frame:SetPoint("TOP", below, "BOTTOM", 0, -Toast.POPUP_GAP)
    else
        frame:SetPoint("TOP", UIParent, "TOP", 0, Toast.TOP_Y)
    end
end

local function Build()
    frame = CreateFrame("Frame", "OmenDeathsToast", UIParent, "BackdropTemplate")
    frame:SetSize(360, 64)
    frame:SetPoint("TOP", UIParent, "TOP", 0, Toast.TOP_Y)
    frame:SetFrameStrata("HIGH")
    frame:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    frame:SetBackdropColor(0.08, 0.02, 0.02, 0.92)
    frame:SetBackdropBorderColor(0.77, 0.12, 0.23)

    local skull = frame:CreateTexture(nil, "ARTWORK")
    skull:SetSize(40, 40)
    skull:SetPoint("LEFT", frame, "LEFT", 12, 0)
    skull:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcon_8")
    frame.skull = skull

    local title = frame:CreateFontString(nil, "OVERLAY")
    title:SetFont("Fonts\\MORPHEUS.TTF", 16, "OUTLINE")
    title:SetPoint("TOPLEFT", skull, "TOPRIGHT", 10, 0)
    title:SetPoint("RIGHT", frame, "RIGHT", -10, 0)
    title:SetJustifyH("LEFT")
    title:SetTextColor(1, 0.82, 0)
    frame.title = title

    local line = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    line:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
    line:SetPoint("RIGHT", frame, "RIGHT", -10, 0)
    line:SetJustifyH("LEFT")
    line:SetTextColor(0.85, 0.85, 0.85)
    frame.line = line

    frame:EnableMouse(true)
    frame:SetScript("OnMouseUp", function()
        frame:Hide()
        if ns.UI then ns.UI.Show() end
    end)
    frame:SetScript("OnUpdate", function(self)
        -- the game's popup can open (or close) just after the toast
        Toast.Anchor()
        local age = GetTime() - (self.started or 0)
        if age >= SHOW + FADE then
            self:Hide()
        elseif age > SHOW then
            self:SetAlpha(1 - (age - SHOW) / FADE)
        end
    end)
    frame:Hide()
end

local function Pick(list) return list[math.random(#list)] end

-- "to Hogger (Rend) in The Deadmines · #3 this week"
function Toast.Detail(owner, rec, named)
    local parts = {}
    local d = ns.Lines.Detail(rec, named)
    if d ~= "" then parts[#parts + 1] = d end
    local n = ns.Data.CountFor(ns.Book(), owner, "week")
    if n > 0 then parts[#parts + 1] = "#" .. n .. " this week" end
    return table.concat(parts, " · ")
end

function Toast.Death(owner, rec)
    if not ns.db or not rec then return end
    local mine = owner == ns.MyName()
    local headline, named, template
    if mine then
        headline, named = Pick(SELF), false
    else
        headline, named, template = ns.Lines.For(rec, owner)
    end
    local detail = Toast.Detail(owner, rec, named)
    Toast.last = { headline = headline, detail = detail }
    if ns.db.settings.chat then
        -- the popup's line, with the name in class colour
        local text = mine and headline or ns.Lines.Render(template, ns.Colored(owner, ns.ClassColor(rec.c)), rec.k)
        ns.Print(text .. (detail ~= "" and (" — " .. detail) or ""))
    end
    if ns.db.settings.toast then
        if not frame then Build() end
        frame.title:SetText(headline)
        frame.line:SetText(detail)
        frame.started = GetTime()
        frame:SetAlpha(1)
        Toast.Anchor()
        frame:Show()
    end
end
