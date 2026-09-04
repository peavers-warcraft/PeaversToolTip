--------------------------------------------------------------------------------
-- Ultra Performance case: what PeaversToolTip costs while you play.
--
-- Tooltip addons have a bad reputation for performance, and it is earned. The
-- usual implementation keeps a tooltip on the mouse by moving it in an OnUpdate,
-- which is work on every single frame the tooltip is visible, and several of the
-- popular ones re-skin the whole frame on every show. So the claim being tested
-- here is a specific one, in two halves:
--
--   1. Nothing runs per frame. Cursor following is done by the client's own
--      ANCHOR_CURSOR_RIGHT, in C, so the addon has no OnUpdate to run at all.
--   2. What a tooltip costs, it costs once, when you hover something.
--
-- The first half is a negative claim, which is exactly the kind that rots
-- quietly, so it is measured rather than asserted: the case loads the real
-- Skin, Registry, Anchor, HealthBar and Content, drives a login and three
-- hundred hovers, then hunts down every OnUpdate handler the addon installed on
-- any frame it created and ticks them for a simulated second. If somebody adds
-- a ticker later, these numbers stop being zero.
--
-- The second half is reported per second rather than per frame, because per
-- frame is the wrong unit for something that only happens when the mouse lands
-- on a new thing. The rate is one tooltip a second, which is roughly what
-- sustained play looks like; mousing quickly along an action bar is a burst of
-- four or five a second, and the cost scales linearly, so multiply the notes
-- column rather than reading the headline as a ceiling.
--
-- Main.lua is not loaded: it needs PeaversCommons, which is a different addon.
-- The case wires the modules together in the same order Main.lua does, and that
-- order is asserted below so the two cannot drift apart silently.
--------------------------------------------------------------------------------

-- Not addon code: this runs in the harness's fengari VM (Lua 5.3), outside WoW,
-- against globals the runner injects. Linting it as a WoW addon is a category
-- error - HARNESS_LIB and ADDON_DIR come from the runner, `unpack` is
-- deliberately reassigned because fengari is 5.3, and the case overwrites
-- Blizzard globals on purpose to drive the code under test.
---@diagnostic disable: undefined-global, deprecated, duplicate-set-field, missing-fields

local Stubs = dofile(HARNESS_LIB .. "/wow-stubs.lua").Install()

-- fengari is Lua 5.3; the addon is written against WoW's Lua 5.1, where unpack
-- is a global.
_G.unpack = _G.unpack or table.unpack

local Count = Stubs.Count

--------------------------------------------------------------------------------
-- A tooltip-shaped frame
--
-- The shared stub turns an unknown method into an inert counted no-op, which is
-- right for SetColorTexture and wrong for GetUnit: code that asks a tooltip what
-- it is describing and gets nil back takes an early return, and the case would
-- measure the addon doing nothing. Everything added here is either a real read
-- the addon makes decisions on, or a piece of state it writes and reads back.
--
-- Counting follows the harness rule: mutations and layout-forcing geometry reads
-- are counted, trivial state reads are not.
--------------------------------------------------------------------------------

local baseCreateFrame = _G.CreateFrame
local createdFrames = {}

-- The stub's catch-all __index hands back a callable for any unknown key, which
-- is exactly the trap the harness README warns about: the addon stores its own
-- state on the frame (`tooltip.peaversBox`, `tooltip.peaversIcon`), and in the
-- game those read back nil until they are set. Under the bare stub they read
-- back as a function, every "have I built this yet?" check answers yes, and the
-- addon skips the work the case exists to measure. Guarding the addon's own
-- prefix restores WoW's behaviour without weakening the counting.
local function Guard(frame)
    local baseIndex = getmetatable(frame).__index
    setmetatable(frame, {
        __index = function(t, key)
            if type(key) == "string" and key:sub(1, 7) == "peavers" then return nil end
            return baseIndex(t, key)
        end,
    })
    return frame
end

_G.CreateFrame = function(...)
    local frame = Guard(baseCreateFrame(...))
    createdFrames[#createdFrames + 1] = frame
    return frame
end

local function NewFontString()
    return Guard(Stubs.NewTexture())
end

local function NewTooltip(name)
    local tooltip = Guard(baseCreateFrame())
    createdFrames[#createdFrames + 1] = tooltip

    tooltip._name = name
    tooltip._scale = 1
    tooltip._unit = "mouseover"

    function tooltip:GetName() return self._name end
    function tooltip:GetObjectType() return "GameTooltip" end
    function tooltip:IsObjectType(t) return t == "GameTooltip" end
    function tooltip:GetScale() return self._scale end
    function tooltip:SetScale(v) Count("SetScale") self._scale = v end
    function tooltip:GetEffectiveScale() return self._scale end
    function tooltip:GetUnit() return "Target Dummy", self._unit end
    function tooltip:SetOwner() Count("SetOwner") end
    function tooltip:AddDoubleLine() Count("AddDoubleLine") end
    function tooltip:AddLine() Count("AddLine") end
    function tooltip:GetBackdrop() return nil end

    -- NineSlice is the piece of Blizzard chrome the skin takes down, and the
    -- cost of doing so on every show is a real part of the number, so it is a
    -- real frame with real shown/alpha state rather than a no-op.
    tooltip.NineSlice = Guard(baseCreateFrame())
    tooltip.NineSlice._shown = true
    tooltip.NineSlice._alpha = 1

    _G[name .. "TextLeft1"] = NewFontString()

    return tooltip
end

--------------------------------------------------------------------------------
-- The rest of the client
--------------------------------------------------------------------------------

_G.hooksecurefunc = function(name, fn)
    local original = _G[name]
    _G[name] = function(...)
        original(...)
        fn(...)
    end
end

_G.PixelUtil = { GetNearestPixelSize = function() return 1 end }

_G.InCombatLockdown = function() return false end
_G.IsShiftKeyDown = function() return false end

_G.UnitIsPlayer = function() return true end
_G.UnitClass = function() return "Mage", "MAGE" end
_G.UnitName = function() return "Target Dummy" end
_G.UnitIsUnit = function() return false end
_G.UnitIsDeadOrGhost = function() return false end
_G.UnitIsConnected = function() return true end
_G.UnitReaction = function() return 4 end
_G.UnitHealth = function() return 287431 end
_G.UnitHealthMax = function() return 500000 end
_G.UnitHealthPercent = function() return 57.5 end

_G.RAID_CLASS_COLORS = { MAGE = { r = 0.41, g = 0.80, b = 0.94 } }
_G.FACTION_BAR_COLORS = { [4] = { r = 1, g = 1, b = 0 } }
_G.CurveConstants = { ScaleTo100 = 1 }
_G.AbbreviateNumbers = function(v) return tostring(v) end
_G.C_StringUtil = { RoundToNearestString = function(v) return tostring(v) end }

_G.C_Item = {
    GetItemInfo = function()
        return "Cloak", "|cffa335ee|Hitem:1|h[Cloak]|h|r", 4, 620, 80, "Armor",
            "Cloth", 1, "INVTYPE_CLOAK", "Interface\\Icons\\INV_Cloak_01"
    end,
    GetItemQualityColor = function() return 0.64, 0.21, 0.93 end,
    GetItemQualityByID = function() return 4 end,
}
_G.C_Spell = { GetSpellInfo = function(id) return { iconID = 135, spellID = id } end }

_G.Enum = { TooltipDataType = { Item = 0, Spell = 1, Unit = 2, UnitAura = 3 } }

local postCalls = {}
_G.TooltipDataProcessor = {
    AddTooltipPostCall = function(dataType, fn)
        postCalls[dataType] = postCalls[dataType] or {}
        table.insert(postCalls[dataType], fn)
    end,
}

-- Font objects the skin resizes.
for _, name in ipairs({ "GameTooltipHeaderText", "GameTooltipText", "GameTooltipTextSmall" }) do
    _G[name] = {
        GetFont = function() return "Fonts\\FRIZQT__.TTF", 12, "" end,
        SetFont = function() Count("SetFont") end,
    }
end

local GameTooltip = NewTooltip("GameTooltip")
_G.GameTooltip = GameTooltip
_G.ItemRefTooltip = NewTooltip("ItemRefTooltip")
_G.ShoppingTooltip1 = NewTooltip("ShoppingTooltip1")
_G.ShoppingTooltip2 = NewTooltip("ShoppingTooltip2")

local statusBar = Guard(baseCreateFrame())
createdFrames[#createdFrames + 1] = statusBar
_G.GameTooltipStatusBar = statusBar

-- Blizzard's own entry points, which the addon hooks rather than replaces.
_G.SharedTooltip_SetBackdropStyle = function() end
_G.GameTooltip_SetDefaultAnchor = function() end

--------------------------------------------------------------------------------
-- The addon
--------------------------------------------------------------------------------

local PTT = {}

-- Config.lua is not loaded: it builds a real ConfigManager out of
-- PeaversCommons. These are the same defaults, with every optional feature ON,
-- because a budget written against the cheap configuration is not a budget.
PTT.Config = {
    enabled = true,
    scale = 1.0,
    fontSize = 12,
    bgColor = { r = 0.086, g = 0.086, b = 0.086 },
    bgAlpha = 0.94,
    borderColor = { r = 0.176, g = 0.176, b = 0.176 },
    borderByQuality = true,
    borderByReaction = true,
    anchorMode = "cursor",
    cursorOffsetX = 12,
    cursorOffsetY = -12,
    anchorPoint = "BOTTOMRIGHT",
    anchorX = -230,
    anchorY = 230,
    anchorUnlocked = false,
    healthBar = true,
    healthBarPosition = "bottom",
    healthBarHeight = 6,
    healthBarColorByUnit = true,
    healthBarText = "both",
    classColorNames = true,
    showTarget = true,
    showItemID = true,
    showSpellID = true,
    showIcon = true,
    hideInCombat = "never",
    Save = function() end,
}

local function Load(path)
    return assert(loadfile(ADDON_DIR .. "/src/" .. path))("PeaversToolTip", PTT)
end

Load("Utils/Secret.lua")
Load("Core/Registry.lua")
Load("Core/Skin.lua")
Load("Core/Anchor.lua")
Load("Core/HealthBar.lua")
Load("Core/Content.lua")

-- Same order as Main.lua: Skin and Content install themselves as Registry
-- handlers, so both have to be wired before Registry sweeps the static list.
PTT.Skin:Initialize()
PTT.Content:Initialize()
PTT.Registry:Initialize()
PTT.Anchor:Initialize()
PTT.HealthBar:Initialize()

assert(PTT.Registry:Count() >= 4, "the static sweep adopted nothing - the case is measuring an inert addon")
assert(postCalls[_G.Enum.TooltipDataType.Unit], "no unit post-call registered")
assert(GameTooltip.peaversBox, "GameTooltip was never skinned")

--------------------------------------------------------------------------------
-- Driving a hover
--
-- The client's own sequence: clear the last tooltip, anchor the new one, restyle
-- it, fill it in, show it.
--------------------------------------------------------------------------------

local function Fire(dataType, tooltip, data)
    for _, fn in ipairs(postCalls[dataType] or {}) do fn(tooltip, data) end
end

local function RunScript(frame, script, ...)
    local fn = frame:GetScript(script)
    if fn then fn(frame, ...) end
end

local function HoverUnit()
    RunScript(GameTooltip, "OnTooltipCleared")
    _G.GameTooltip_SetDefaultAnchor(GameTooltip, _G.UIParent)
    _G.SharedTooltip_SetBackdropStyle(GameTooltip)
    Fire(_G.Enum.TooltipDataType.Unit, GameTooltip)
    RunScript(GameTooltip, "OnShow")
    RunScript(statusBar, "OnShow")
    -- One health tick while the tooltip is up.
    RunScript(statusBar, "OnValueChanged")
end

local function HoverItem()
    RunScript(GameTooltip, "OnTooltipCleared")
    _G.GameTooltip_SetDefaultAnchor(GameTooltip, _G.UIParent)
    _G.SharedTooltip_SetBackdropStyle(GameTooltip)
    Fire(_G.Enum.TooltipDataType.Item, GameTooltip, { id = 1, hyperlink = "item:1" })
    RunScript(GameTooltip, "OnShow")
end

local function CostPer(fn, iterations)
    Stubs.ResetCounts()
    for _ = 1, iterations do fn() end
    return Stubs.TotalCalls() / iterations
end

-- Warm the lazily-built pieces (the icon holder) so the measurement is steady
-- state rather than first-hover setup amortised over the run.
HoverUnit()
HoverItem()

local HOVERS_PER_SECOND = 1

local unitCost = CostPer(HoverUnit, 300)
local itemCost = CostPer(HoverItem, 300)

--------------------------------------------------------------------------------
-- The idle claim
--
-- Every frame the addon created, hunted for an OnUpdate. WoW does not tick a
-- hidden frame, so a shown frame with a handler is the only thing that could
-- cost anything while nothing is happening.
--------------------------------------------------------------------------------

local function IdleCallsPerSecond()
    local handlers = {}
    for _, frame in ipairs(createdFrames) do
        local fn = frame.GetScript and frame:GetScript("OnUpdate")
        if fn and frame:IsShown() then
            handlers[#handlers + 1] = { frame = frame, fn = fn }
        end
    end

    if #handlers == 0 then return 0, 0 end

    Stubs.ResetCounts()
    local step = 1 / 144
    for _ = 1, 144 do
        Stubs.time = Stubs.time + step
        for _, handler in ipairs(handlers) do
            handler.fn(handler.frame, step)
        end
    end
    return Stubs.TotalCalls(), #handlers
end

local idleCalls, handlerCount = IdleCallsPerSecond()

return {
    {
        name = "hovering units, 1 tooltip/sec",
        callsPerFrame = 0,
        callsPerSecond = unitCost * HOVERS_PER_SECOND,
        idleCallsPerSecond = 0,
        notes = string.format(
            "%.0f calls per tooltip: skin re-asserted, border coloured, health bar placed and read",
            unitCost),
    },
    {
        name = "hovering items, 1 tooltip/sec",
        callsPerFrame = 0,
        callsPerSecond = itemCost * HOVERS_PER_SECOND,
        idleCallsPerSecond = 0,
        notes = string.format("%.0f calls per tooltip, icon and item ID both on", itemCost),
    },
    {
        name = "idle, tooltip on screen",
        callsPerFrame = 0,
        idleCallsPerSecond = idleCalls,
        notes = string.format("%d OnUpdate handlers installed; the cursor is followed by the client",
            handlerCount),
    },
}
