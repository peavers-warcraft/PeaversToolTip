--------------------------------------------------------------------------------
-- PeaversToolTip Configuration
--
-- Account-wide by design. Where a tooltip sits and what it looks like are
-- properties of the screen rather than of the character, so this uses the flat
-- (non-profile) ConfigManager variant, exactly as PeaversMiniMap does.
--
-- Every default here is chosen so that a fresh install already looks like the
-- rest of the Peavers suite: the same #161616 paper and the same 1px hairline
-- that PeaversCommons.Theme paints every config surface with.
--------------------------------------------------------------------------------

local addonName, PTT = ...

local PeaversCommons = _G.PeaversCommons
local ConfigManager = PeaversCommons.ConfigManager

PTT.name = PTT.name or addonName

local PTT_DEFAULTS = {
    -- Master toggle. Off restores every tooltip to Blizzard's own look, live,
    -- without a reload.
    enabled = true,

    ----------------------------------------------------------------------------
    -- Appearance
    ----------------------------------------------------------------------------
    scale = 1.0,
    fontSize = 12,              -- Blizzard's own default, so 12 is a no-op

    -- Theme.Colors.bgBase / Theme.Colors.border, spelled out rather than read
    -- from the theme so that a future reskin of the config UI does not silently
    -- restyle everybody's tooltips.
    bgColor = { r = 0.086, g = 0.086, b = 0.086 },
    bgAlpha = 0.94,
    borderColor = { r = 0.176, g = 0.176, b = 0.176 },

    -- The border is the addon's one piece of live information: it carries the
    -- item's quality or the unit's reaction, so the colour tells you what you
    -- are looking at before you have read a word of it.
    borderByQuality = true,
    borderByReaction = true,

    ----------------------------------------------------------------------------
    -- Position
    --
    -- "cursor" uses the client's own cursor anchoring, which is followed in C.
    -- Nothing in this addon runs per frame to keep a tooltip on the mouse.
    ----------------------------------------------------------------------------
    anchorMode = "cursor",      -- "cursor" | "anchor" | "blizzard"
    cursorOffsetX = 12,
    cursorOffsetY = -12,
    anchorPoint = "BOTTOMRIGHT",
    anchorX = -230,
    anchorY = 230,
    anchorUnlocked = false,

    ----------------------------------------------------------------------------
    -- Health bar
    ----------------------------------------------------------------------------
    healthBar = true,
    healthBarPosition = "bottom",   -- "default" | "top" | "bottom"
    healthBarHeight = 6,
    healthBarColorByUnit = true,
    healthBarText = "none",         -- "none" | "percent" | "value" | "both"

    ----------------------------------------------------------------------------
    -- Content
    ----------------------------------------------------------------------------
    classColorNames = true,
    showTarget = true,
    showItemID = false,
    showSpellID = false,
    showIcon = false,

    -- "never" | "units" | "all". Holding Shift always shows the tooltip anyway,
    -- so this never becomes a trap you cannot get out of mid-fight.
    hideInCombat = "never",

    debugMode = false,
    DEBUG_ENABLED = false,
}

PTT.Config = ConfigManager:New(PTT, PTT_DEFAULTS, {
    savedVariablesName = "PeaversToolTipDB",
})

return PTT.Config
