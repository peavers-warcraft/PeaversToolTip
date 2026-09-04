--------------------------------------------------------------------------------
-- HealthBar
--
-- Restyles GameTooltipStatusBar - the thin green line under a unit tooltip -
-- into a flat bar that can sit outside the tooltip as a box of its own, carries
-- the unit's own colour, and optionally reads out a number.
--
-- The interesting constraint is Midnight's secret values. Blizzard drives that
-- bar with the unit's health, which for anything not player-controlled is
-- secret in combat, in an encounter, in a key, or in rated PvP. Once a widget
-- has been given a secret its getters return secrets too, so the bar's own
-- GetValue is no use for building text: reading it back and formatting a
-- percentage would be arithmetic on a secret, which is a hard Lua error.
--
-- So the text is never derived from the bar. It is rebuilt from the unit
-- through the blessed formatters in Secret.lua, which take a secret and hand
-- back a string. An enemy boss reads exactly like a party member.
--
-- Nothing here runs on a timer. The bar's OnValueChanged is the update signal,
-- and the client fires it when health actually changes.
--------------------------------------------------------------------------------

local addonName, PTT = ...

local HealthBar = {}
PTT.HealthBar = HealthBar

local Secret = PTT.Secret
local Skin = PTT.Skin

local GAP = 5

local function Bar()
    return _G.GameTooltipStatusBar
end

--------------------------------------------------------------------------------
-- Layout
--------------------------------------------------------------------------------

-- Blizzard re-anchors the bar every time it shows one, so the addon's own
-- geometry has to be re-asserted rather than set once. Cheap: four SetPoints on
-- a frame that is about to be drawn anyway.
function HealthBar:ApplyLayout()
    local bar = Bar()
    if not bar then return end

    local cfg = PTT.Config
    local tooltip = _G.GameTooltip

    if not cfg.enabled or not cfg.healthBar then
        bar:Hide()
        return
    end

    bar:SetHeight(cfg.healthBarHeight or 6)

    local position = cfg.healthBarPosition or "bottom"
    if position == "default" then
        -- Blizzard's own placement: inside the tooltip, at the bottom. Nothing
        -- to do but leave the anchors it just set alone.
        Skin:HideBox(bar)
        return
    end

    bar:ClearAllPoints()
    if position == "top" then
        bar:SetPoint("BOTTOMLEFT", tooltip, "TOPLEFT", 1, GAP)
        bar:SetPoint("BOTTOMRIGHT", tooltip, "TOPRIGHT", -1, GAP)
    else
        bar:SetPoint("TOPLEFT", tooltip, "BOTTOMLEFT", 1, -GAP)
        bar:SetPoint("TOPRIGHT", tooltip, "BOTTOMRIGHT", -1, -GAP)
    end

    Skin:ShowBox(bar)
end

--------------------------------------------------------------------------------
-- Colour and text
--------------------------------------------------------------------------------

function HealthBar:Refresh()
    local bar = Bar()
    if not bar then return end

    local cfg = PTT.Config
    if not cfg.enabled or not cfg.healthBar then return end

    local unit = _G.GameTooltip and _G.GameTooltip.peaversUnit

    if cfg.healthBarColorByUnit then
        local color = unit and Secret.GetUnitColor(unit)
        if color then
            bar:SetStatusBarColor(color.r, color.g, color.b)
        end
    end

    local text = bar.peaversText
    if not text then return end

    local mode = cfg.healthBarText or "none"
    if mode == "none" or not unit then
        if text:IsShown() then text:Hide() end
        return
    end

    -- SetText accepts a secret; anything that measures or compares one does not.
    text:SetText(Secret.BuildHealthText(unit, mode))
    if not text:IsShown() then text:Show() end
end

--------------------------------------------------------------------------------
-- Setup
--------------------------------------------------------------------------------

function HealthBar:Initialize()
    local bar = Bar()
    if not bar or self.initialized then return end
    self.initialized = true

    -- Outset 1: the fill covers the bar's whole rect at full health, so a border
    -- drawn on the edge would disappear exactly when the unit is healthy.
    Skin:EnsureBox(bar, 1)
    Skin:PaintBox(bar,
        { r = 0.086, g = 0.086, b = 0.086, a = 0.94 },
        { r = 0.176, g = 0.176, b = 0.176, a = 1 })

    if bar.SetStatusBarTexture then
        pcall(bar.SetStatusBarTexture, bar, Skin.WHITE_TEXTURE)
    end

    local text = bar:CreateFontString(nil, "OVERLAY", "GameTooltipTextSmall")
    text:SetPoint("CENTER", bar, "CENTER", 0, 0)
    text:SetTextColor(1, 1, 1)
    text:Hide()
    bar.peaversText = text

    -- The update signal. Health changes fire this; nothing polls.
    bar:HookScript("OnValueChanged", function()
        HealthBar:Refresh()
    end)

    -- Blizzard shows the bar and anchors it in the same breath, so this is the
    -- moment our layout has been overwritten and needs re-asserting.
    bar:HookScript("OnShow", function()
        HealthBar:ApplyLayout()
        HealthBar:Refresh()
    end)

    self:ApplyLayout()
end

-- Called when a unit tooltip is built, before the bar has been shown.
function HealthBar:OnUnit(unit)
    if not self.initialized then return end
    _G.GameTooltip.peaversUnit = unit
    self:ApplyLayout()
    self:Refresh()
end

function HealthBar:Restore()
    local bar = Bar()
    if not bar then return end

    Skin:HideBox(bar)
    if bar.peaversText then bar.peaversText:Hide() end
    if bar.SetStatusBarTexture then
        pcall(bar.SetStatusBarTexture, bar, "Interface\\TargetingFrame\\UI-StatusBar")
    end
end

return HealthBar
