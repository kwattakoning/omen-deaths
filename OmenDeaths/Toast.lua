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

poster:SetScript("OnUpdate", function(self)
    if Locked() then return end
    local send = C_ChatInfo and C_ChatInfo.SendChatMessage or SendChatMessage
    while outbox[1] do
        local msg = table.remove(outbox, 1)
        if send and ns.GuildName() then pcall(send, msg, "GUILD") end
    end
    self:Hide()
end)

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

-- Posts a line in guild chat as soon as chat is allowed.
function Toast.Post(line)
    outbox[#outbox + 1] = Toast.Fit(line)
    poster:Show()
end

function Toast.GuildPost(owner, t)
    if not ns.db or not ns.db.settings.guildChat or owner ~= ns.MyName() or not ns.GuildName() then return end
    local p = ns.Book().players[owner]
    local rec = p and p.deaths[t]
    if not rec then return end
    -- died in a boss fight: the summary after the fight covers it (Wipe.lua)
    if ns.Wipe and ns.Wipe.Covers(rec.t) then return end
    Toast.Post(Toast.GuildLine(owner, rec))
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
