-- Omen Deaths: the button with the guild logo on the minimap. Click opens the window, drag moves it around the edge.
local _, ns = ...
local Mini = {}
ns.Minimap = Mini

-- Distance from the minimap centre: half its real width plus 5, as LibDBIcon-1.0 does
-- (shipped with ForeverGuide in this client). A fixed number put the button inside the map.
Mini.OUTSIDE = 5
function Mini.Radius()
    local w = Minimap.GetWidth and Minimap:GetWidth() or 0
    return w / 2 + Mini.OUTSIDE
end

function Mini.Place(button, angle)
    local rad, r = math.rad(angle), Mini.Radius()
    button:ClearAllPoints()
    button:SetPoint("CENTER", Minimap, "CENTER", math.cos(rad) * r, math.sin(rad) * r)
end

Mini.ICON = "Interface\\AddOns\\OmenDeaths\\OmenLogo"

local function Build()
    if not Minimap then return end
    local b = CreateFrame("Button", "OmenDeathsMinimapButton", Minimap)
    b:SetSize(32, 32)
    b:SetFrameStrata("MEDIUM")
    b:SetFrameLevel(8)
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b:RegisterForDrag("LeftButton")
    b:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

    local bg = b:CreateTexture(nil, "BACKGROUND")
    bg:SetSize(20, 20)
    bg:SetPoint("CENTER", b, "CENTER", 0, 0)
    bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")

    local icon = b:CreateTexture(nil, "ARTWORK")
    -- the guild logo (09-11-2026): the tree from Omen.png, cut round, 64x64 TGA; as big as the
    -- round background under it (20)
    icon:SetSize(20, 20)
    icon:SetPoint("CENTER", b, "CENTER", 0, 0)
    icon:SetTexture(Mini.ICON)

    local border = b:CreateTexture(nil, "OVERLAY")
    border:SetSize(54, 54)
    border:SetPoint("TOPLEFT", b, "TOPLEFT", 0, 0)
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

    b:SetScript("OnClick", function() ns.UI.Toggle() end)
    b:SetScript("OnDragStart", function(self)
        self:SetScript("OnUpdate", function()
            local mx, my = Minimap:GetCenter()
            local scale = Minimap:GetEffectiveScale()
            local cx, cy = GetCursorPosition()
            local angle = math.deg((math.atan2 or math.atan)(cy / scale - my, cx / scale - mx))
            ns.db.settings.minimapAngle = angle
            Mini.Place(self, angle)
        end)
    end)
    b:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
    b:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText("Omen Deaths", 1, 0.82, 0)
        local book = ns.Book()
        local week = ns.Data.Leaderboard(book, "week", nil)
        if week[1] then
            GameTooltip:AddLine("Top of the week: " .. week[1].name .. " (" .. week[1].count .. ")", 1, 1, 1)
        else
            GameTooltip:AddLine("Nobody died this week. Yet.", 1, 1, 1)
        end
        GameTooltip:AddLine("Your deaths this week: " .. ns.Data.CountFor(book, ns.MyName() or "", "week"), 0.8, 0.8, 0.8)
        GameTooltip:AddLine("Click to open, drag to move", 0.5, 0.5, 0.5)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    Mini.Place(b, ns.db.settings.minimapAngle)
    Mini.button = b
end

ns.On("PLAYER_LOGIN", function()
    if ns.db then Build() end
end)
