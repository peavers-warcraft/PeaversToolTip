local addonName, PTT = ...

--------------------------------------------------------------------------------
-- Edit Mode
--
-- This addon does not own a frame - it reskins Blizzard's tooltips, and the
-- game tooltip is already a system in Edit Mode with its own position. So the
-- settings attach to that system rather than registering a frame of our own.
--
-- Which is also where a person would look for them. Someone who wants the
-- tooltip somewhere else opens Edit Mode and clicks the tooltip; finding
-- everything else about it in the same place is the whole point of this move.
--------------------------------------------------------------------------------

local PeaversCommons = _G.PeaversCommons

local EditMode = {}
PTT.EditMode = EditMode

--------------------------------------------------------------------------------
-- Applying a change
--
-- Every setting ends here: repaint what is already on screen so a change shows
-- without having to hover something new.
--------------------------------------------------------------------------------

function PTT.ApplySetting()
    if not PTT.Config.enabled then
        -- Turning the addon off has to run too, or Blizzard's own look never
        -- comes back until something else triggers a repaint.
        if PTT.Skin and PTT.Skin.ApplyAll then PTT.Skin:ApplyAll() end
        return
    end

    if PTT.Skin then PTT.Skin:ApplyAll() end
    if PTT.HealthBar then PTT.HealthBar:ApplyLayout() end
    if PTT.Anchor then PTT.Anchor:Reposition() end
end

--------------------------------------------------------------------------------
-- Groups
--------------------------------------------------------------------------------

EditMode.SECTIONS = {
    { key = "appearance", label = "Appearance" },
    { key = "position", label = "Position" },
    { key = "health", label = "Health Bar" },
    { key = "content", label = "Content" },
}

-- The anchor settings only mean something in their own mode, and showing all
-- three modes' settings at once is what made the settings page need a greying
-- pass of its own.
local function OnlyWhenCursor(cfg) return (cfg.anchorMode or "cursor") ~= "cursor" end
local function OnlyWhenAnchored(cfg) return (cfg.anchorMode or "cursor") ~= "anchor" end

EditMode.ENTRIES = {
    ------------------------------------------------------------ appearance ---
    {
        key = "enabled", label = "Enabled", kind = "checkbox", section = "appearance",
        default = true,
        desc = "Off restores every tooltip to Blizzard's own look, live, with no reload.",
    },
    {
        key = "scale", label = "Scale", kind = "slider", section = "appearance",
        min = 0.5, max = 2.0, step = 0.05, unit = "percent", default = 1.0,
    },
    {
        key = "fontSize", label = "Font Size", kind = "slider", section = "appearance",
        min = 8, max = 20, step = 1, unit = "pt", default = 12,
    },
    {
        key = "bgColor", label = "Background Colour", kind = "color",
        section = "appearance", default = { r = 0.086, g = 0.086, b = 0.086 },
    },
    {
        key = "bgAlpha", label = "Background Opacity", kind = "slider",
        section = "appearance", min = 0, max = 1, step = 0.02, unit = "percent", default = 0.94,
    },
    {
        key = "borderColor", label = "Border Colour", kind = "color",
        section = "appearance", default = { r = 0.176, g = 0.176, b = 0.176 },
        -- Pointless while the border is taking its colour from what is under it.
        hidden = function(cfg) return cfg.borderByQuality or cfg.borderByReaction end,
    },
    {
        key = "borderByQuality", label = "Colour Border By Item Quality",
        kind = "checkbox", section = "appearance", default = true, revealsOthers = true,
    },
    {
        key = "borderByReaction", label = "Colour Border By Unit Reaction",
        kind = "checkbox", section = "appearance", default = true, revealsOthers = true,
    },

    -------------------------------------------------------------- position ---
    {
        key = "anchorMode", label = "Where Tooltips Appear", kind = "dropdown",
        section = "position", fallback = "cursor", revealsOthers = true,
        desc = "Governs the tooltip the game positions itself. One that a bag or "
            .. "a character panel deliberately placed stays where that frame put it.",
        values = {
            { value = "cursor", label = "Follow the mouse cursor" },
            { value = "anchor", label = "A fixed spot I choose" },
            { value = "blizzard", label = "Leave Blizzard's default alone" },
        },
    },
    {
        key = "cursorOffsetX", label = "Cursor X Offset", kind = "slider",
        section = "position", min = -100, max = 100, step = 1, unit = "px", default = 12,
        hidden = OnlyWhenCursor,
    },
    {
        key = "cursorOffsetY", label = "Cursor Y Offset", kind = "slider",
        section = "position", min = -100, max = 100, step = 1, unit = "px", default = -12,
        hidden = OnlyWhenCursor,
    },
    {
        key = "anchorPoint", label = "Corner", kind = "dropdown", section = "position",
        fallback = "BOTTOMRIGHT", hidden = OnlyWhenAnchored,
        values = {
            { value = "TOPLEFT", label = "Top left" },
            { value = "TOPRIGHT", label = "Top right" },
            { value = "BOTTOMLEFT", label = "Bottom left" },
            { value = "BOTTOMRIGHT", label = "Bottom right" },
            { value = "CENTER", label = "Centre" },
        },
    },
    {
        key = "anchorX", label = "X Offset", kind = "number", section = "position",
        default = -230, hidden = OnlyWhenAnchored,
    },
    {
        key = "anchorY", label = "Y Offset", kind = "number", section = "position",
        default = 230, hidden = OnlyWhenAnchored,
    },
    {
        key = "anchorUnlocked", label = "Show The Drag Handle", kind = "checkbox",
        section = "position", default = false, hidden = OnlyWhenAnchored,
        desc = "Puts a handle on screen so the fixed spot can be dragged rather "
            .. "than typed.",
    },

    ---------------------------------------------------------------- health ---
    {
        key = "healthBar", label = "Show A Health Bar", kind = "checkbox",
        section = "health", default = true, revealsOthers = true,
    },
    {
        key = "healthBarPosition", label = "Position", kind = "dropdown",
        section = "health", fallback = "bottom",
        hidden = function(cfg) return not cfg.healthBar end,
        values = {
            { value = "default", label = "Where Blizzard puts it" },
            { value = "top", label = "Above the tooltip" },
            { value = "bottom", label = "Below the tooltip" },
        },
    },
    {
        key = "healthBarHeight", label = "Height", kind = "slider", section = "health",
        min = 2, max = 20, step = 1, unit = "px", default = 6,
        hidden = function(cfg) return not cfg.healthBar end,
    },
    {
        key = "healthBarColorByUnit", label = "Colour By Class Or Reaction",
        kind = "checkbox", section = "health", default = true,
        hidden = function(cfg) return not cfg.healthBar end,
    },
    {
        key = "healthBarText", label = "Text", kind = "dropdown", section = "health",
        fallback = "none", hidden = function(cfg) return not cfg.healthBar end,
        values = {
            { value = "none", label = "None" },
            { value = "percent", label = "Percent" },
            { value = "value", label = "Value" },
            { value = "both", label = "Value and percent" },
        },
    },

    --------------------------------------------------------------- content ---
    {
        key = "classColorNames", label = "Colour Names By Class", kind = "checkbox",
        section = "content", default = true,
    },
    {
        key = "showTarget", label = "Show What A Unit Is Targeting",
        kind = "checkbox", section = "content", default = true,
    },
    {
        key = "showIcon", label = "Show The Item Or Spell Icon", kind = "checkbox",
        section = "content", default = false,
    },
    {
        key = "showItemID", label = "Show Item IDs", kind = "checkbox",
        section = "content", default = false,
    },
    {
        key = "showSpellID", label = "Show Spell IDs", kind = "checkbox",
        section = "content", default = false,
    },
    {
        key = "hideInCombat", label = "Hide In Combat", kind = "dropdown",
        section = "content", fallback = "never",
        desc = "Holding Shift shows the tooltip anyway, so this never becomes a "
            .. "trap you cannot get out of mid-fight.",
        values = {
            { value = "never", label = "Never" },
            { value = "units", label = "Only for units" },
            { value = "all", label = "For everything" },
        },
    },
}

--------------------------------------------------------------------------------
-- Registration
--------------------------------------------------------------------------------

function EditMode:BuildSchema()
    if self.schema then return self.schema end

    self.schema = PeaversCommons.SettingsSchema:New({
        config = PTT.Config,
        sections = self.SECTIONS,
        entries = self.ENTRIES,
        apply = function() PTT.ApplySetting() end,
    })

    return self.schema
end

function EditMode:Register()
    if not PeaversCommons.EditMode or not PeaversCommons.EditMode.available then
        return false
    end
    if not (Enum and Enum.EditModeSystem and Enum.EditModeSystem.HudTooltip) then
        return false
    end

    PeaversCommons.EditMode:RegisterSystem({
        systemID = Enum.EditModeSystem.HudTooltip,
        name = "Peavers ToolTip",
        schema = self:BuildSchema(),
    })

    return true
end

return EditMode
