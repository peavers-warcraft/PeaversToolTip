--------------------------------------------------------------------------------
-- Anchor
--
-- Where the main tooltip appears, and whether it appears at all.
--
-- Both questions are answered in the same place because the game asks them in
-- the same place: GameTooltip_SetDefaultAnchor is the one function the client
-- calls when nothing else has claimed the tooltip, which makes it the only hook
-- point that catches "hovering the world, a unit, an action button" without
-- also catching "hovering a bag slot", where the owning frame has deliberately
-- anchored the tooltip next to itself and should keep it there.
--
-- Cursor mode hands the job straight back to the client. ANCHOR_CURSOR_RIGHT is
-- followed in C, every frame, for free - so the addon can offer a tooltip that
-- tracks the mouse without running a single line of Lua per frame. Doing it by
-- hand in OnUpdate is the obvious implementation and it is the reason tooltip
-- addons show up in performance profiles.
--------------------------------------------------------------------------------

local addonName, PTT = ...

local Anchor = {}
PTT.Anchor = Anchor

local Registry = PTT.Registry

local MOVER_WIDTH, MOVER_HEIGHT = 150, 36

--------------------------------------------------------------------------------
-- The mover
--
-- A real frame the user drags, rather than an X/Y pair typed into two sliders.
-- It is hidden and mouse-transparent while locked, so in normal play it does not
-- exist as far as the mouse is concerned.
--------------------------------------------------------------------------------

function Anchor:GetMover()
    if self.mover then return self.mover end

    local mover = CreateFrame("Frame", "PeaversToolTipAnchor", UIParent)
    mover:SetSize(MOVER_WIDTH, MOVER_HEIGHT)
    mover:SetClampedToScreen(true)
    mover:SetMovable(true)
    mover:SetFrameStrata("TOOLTIP")
    mover:EnableMouse(false)
    mover:RegisterForDrag("LeftButton")
    mover:Hide()

    PTT.Skin:EnsureBox(mover)
    PTT.Skin:PaintBox(mover,
        { r = 0.086, g = 0.086, b = 0.086, a = 0.9 },
        { r = 0.506, g = 0.549, b = 0.973, a = 1 })

    local label = mover:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("CENTER")
    label:SetText("Tooltip anchor")
    label:SetTextColor(0.725, 0.725, 0.725)

    mover:SetScript("OnDragStart", function(self_) self_:StartMoving() end)
    mover:SetScript("OnDragStop", function(self_)
        self_:StopMovingOrSizing()
        Anchor:SavePosition()
    end)

    self.mover = mover
    self:Reposition()
    return mover
end

function Anchor:Reposition()
    local mover = self.mover
    if not mover then return end

    local cfg = PTT.Config
    mover:ClearAllPoints()
    mover:SetPoint(cfg.anchorPoint or "BOTTOMRIGHT", UIParent,
        cfg.anchorPoint or "BOTTOMRIGHT", cfg.anchorX or -230, cfg.anchorY or 230)
end

function Anchor:SavePosition()
    local mover = self.mover
    if not mover then return end

    local point, _, _, x, y = mover:GetPoint()
    PTT.Config.anchorPoint = point
    PTT.Config.anchorX = math.floor(x + 0.5)
    PTT.Config.anchorY = math.floor(y + 0.5)
    PTT.Config:Save()
end

function Anchor:SetUnlocked(unlocked)
    local mover = self:GetMover()

    PTT.Config.anchorUnlocked = unlocked and true or false
    PTT.Config:Save()

    mover:EnableMouse(unlocked and true or false)
    if unlocked then mover:Show() else mover:Hide() end
end

function Anchor:ToggleUnlocked()
    self:SetUnlocked(not PTT.Config.anchorUnlocked)
    return PTT.Config.anchorUnlocked
end

function Anchor:ResetPosition()
    PTT.Config.anchorPoint = "BOTTOMRIGHT"
    PTT.Config.anchorX = -230
    PTT.Config.anchorY = 230
    PTT.Config:Save()
    self:Reposition()
end

-- Which corner of the tooltip meets the anchor. Derived from where the anchor
-- sits on screen rather than asked as a setting: an anchor in the bottom-right
-- should grow the tooltip up and to the left, and there is no case where the
-- opposite is what somebody wanted.
function Anchor:DerivePoint()
    local mover = self.mover
    if not mover then return "BOTTOMRIGHT" end

    local x, y = mover:GetCenter()
    local px, py = UIParent:GetCenter()
    if not x or not px then return "BOTTOMRIGHT" end

    local vertical = (y < py) and "BOTTOM" or "TOP"
    local horizontal = (x < px) and "LEFT" or "RIGHT"
    return vertical .. horizontal
end

--------------------------------------------------------------------------------
-- Combat visibility
--
-- Shift is a deliberate escape hatch rather than a setting. Somebody who turns
-- tooltips off in combat still needs to read one occasionally, and a setting
-- they would have to leave the fight to change is not an answer.
--------------------------------------------------------------------------------

function Anchor:ShouldHide(isUnit)
    local mode = PTT.Config.hideInCombat
    if mode == nil or mode == "never" then return false end
    if not InCombatLockdown() then return false end
    if IsShiftKeyDown() then return false end
    if mode == "units" then return isUnit and true or false end
    return true
end

--------------------------------------------------------------------------------
-- The hook
--------------------------------------------------------------------------------

local function ApplyDefaultAnchor(tooltip, parent)
    if not PTT.Config.enabled then return end
    if tooltip ~= _G.GameTooltip then return end

    if Anchor:ShouldHide(false) then
        tooltip:Hide()
        return
    end

    local mode = PTT.Config.anchorMode
    if mode == "blizzard" then return end

    if mode == "cursor" then
        -- SetOwner is safe here: GameTooltip_SetDefaultAnchor runs before any
        -- content is added, so there is nothing to clear.
        tooltip:SetOwner(parent or UIParent, "ANCHOR_CURSOR_RIGHT",
            PTT.Config.cursorOffsetX or 12, PTT.Config.cursorOffsetY or -12)
        -- SetOwner clears the flag the function we are hooking had just set, and
        -- Blizzard reads it to decide whether the tooltip owns its own position.
        -- Losing it leaves tooltips that fail to reposition on the next hover.
        tooltip.default = 1
        return
    end

    local mover = Anchor:GetMover()
    local point = Anchor:DerivePoint()
    tooltip:ClearAllPoints()
    tooltip:SetPoint(point, mover, point, 0, 0)
end

function Anchor:Initialize()
    if self.initialized then return end
    self.initialized = true

    self:GetMover()
    if PTT.Config.anchorUnlocked then
        self:SetUnlocked(true)
    end

    if type(_G.GameTooltip_SetDefaultAnchor) == "function" then
        hooksecurefunc("GameTooltip_SetDefaultAnchor", ApplyDefaultAnchor)
    end

    -- The default-anchor hook covers tooltips the client positions itself. A
    -- tooltip an addon or a bag frame owns never goes through it, so hiding
    -- everything in combat needs a second gate on the show itself. ShouldHide is
    -- asked with isUnit=false, so this fires only for the "all" setting - unit
    -- tooltips are handled where the unit is actually known, in Content.
    Registry:OnShow(function(tooltip)
        if not PTT.Config.enabled then return end
        if Anchor:ShouldHide(false) then tooltip:Hide() end
    end)
end

return Anchor
