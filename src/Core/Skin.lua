--------------------------------------------------------------------------------
-- Skin
--
-- Turns a Blizzard tooltip into the flat black box the rest of the Peavers suite
-- is drawn in: a single #161616 field with a 1px hairline border and nothing
-- else. No gradients, no inset bevel, no gold frame.
--
-- Two decisions here are worth explaining, because both look like the harder
-- option until you try the easy one.
--
-- 1. The box is drawn with textures created directly on the tooltip, in the
--    BACKGROUND draw layer, rather than with a BackdropTemplate frame. A child
--    frame always draws above its parent's regions, so a backdrop frame would
--    have to fight the tooltip's own text for depth and would need frame-level
--    arithmetic that breaks the moment Blizzard reparents something. Regions in
--    BACKGROUND are behind the text by definition, and they cost nothing to
--    keep there.
--
-- 2. Blizzard's chrome is hidden rather than recoloured. NineSlice can be tinted
--    through SetBorderColor, but its border is a textured frame with corners, so
--    tinting it gives a coloured gold frame, not a hairline. Hiding it and
--    drawing our own is what produces the flat look.
--
-- The hairline is measured in real screen pixels via PixelUtil. A "1" in frame
-- units is not one pixel once the UI scale is anything but 1, and a border that
-- lands between pixels is the difference between a crisp box and a soft grey
-- smear.
--------------------------------------------------------------------------------

local addonName, PTT = ...

local Skin = {}
PTT.Skin = Skin

local Registry = PTT.Registry

local WHITE = "Interface\\Buttons\\WHITE8X8"

local EDGES = { "top", "bottom", "left", "right" }

-- Font objects the tooltips draw with. These belong to the tooltip system alone,
-- so resizing them does not leak into the rest of the UI. Originals are captured
-- the first time they are touched so that disabling the addon puts them back.
local FONT_OBJECTS = {
    { name = "GameTooltipHeaderText", delta = 2 },
    { name = "GameTooltipText",       delta = 0 },
    { name = "GameTooltipTextSmall",  delta = -2 },
    { name = "Tooltip_Med",           delta = 0 },
    { name = "Tooltip_Small",         delta = -2 },
}

local originalFonts = nil

--------------------------------------------------------------------------------
-- Pixel-exact hairlines
--------------------------------------------------------------------------------

local function Hairline(frame)
    local pixelUtil = _G.PixelUtil
    if pixelUtil and pixelUtil.GetNearestPixelSize and frame.GetEffectiveScale then
        local ok, size = pcall(pixelUtil.GetNearestPixelSize, 1, frame:GetEffectiveScale(), 1)
        if ok and size and size > 0 then return size end
    end
    return 1
end

--------------------------------------------------------------------------------
-- The box
--
-- Five textures: one fill and four edges. Built once per tooltip and then only
-- ever recoloured, so a tooltip showing costs no allocation.
--------------------------------------------------------------------------------

-- `outset` pushes the box out beyond the frame's own rect. Tooltips use 0 - the
-- border sits on the edge. The health bar uses 1, because a status bar's fill
-- texture always covers its whole rect and would paint straight over a border
-- drawn on the edge the moment the unit hit full health.
function Skin:EnsureBox(frame, outset)
    if frame.peaversBox then return frame.peaversBox end
    if type(frame.CreateTexture) ~= "function" then return nil end

    local o = outset or 0
    local box = {}

    box.bg = frame:CreateTexture(nil, "BACKGROUND", nil, -8)
    box.bg:SetPoint("TOPLEFT", frame, "TOPLEFT", -o, o)
    box.bg:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", o, -o)

    box.top = frame:CreateTexture(nil, "BACKGROUND", nil, -7)
    box.top:SetPoint("TOPLEFT", frame, "TOPLEFT", -o, o)
    box.top:SetPoint("TOPRIGHT", frame, "TOPRIGHT", o, o)

    box.bottom = frame:CreateTexture(nil, "BACKGROUND", nil, -7)
    box.bottom:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", -o, -o)
    box.bottom:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", o, -o)

    box.left = frame:CreateTexture(nil, "BACKGROUND", nil, -7)
    box.left:SetPoint("TOPLEFT", frame, "TOPLEFT", -o, o)
    box.left:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", -o, -o)

    box.right = frame:CreateTexture(nil, "BACKGROUND", nil, -7)
    box.right:SetPoint("TOPRIGHT", frame, "TOPRIGHT", o, o)
    box.right:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", o, -o)

    frame.peaversBox = box
    return box
end

-- Paint an existing box. Split from EnsureBox so that recolouring a tooltip on
-- every show does not go anywhere near frame creation.
function Skin:PaintBox(frame, bg, border)
    local box = frame.peaversBox
    if not box then return end

    local px = Hairline(frame)

    box.bg:SetColorTexture(bg.r, bg.g, bg.b, bg.a)
    box.top:SetHeight(px)
    box.bottom:SetHeight(px)
    box.left:SetWidth(px)
    box.right:SetWidth(px)

    for _, key in ipairs(EDGES) do
        box[key]:SetColorTexture(border.r, border.g, border.b, border.a or 1)
    end
end

function Skin:ShowBox(frame)
    local box = frame.peaversBox
    if not box then return end
    for _, texture in pairs(box) do
        if not texture:IsShown() then texture:Show() end
    end
end

function Skin:HideBox(frame)
    local box = frame.peaversBox
    if not box then return end
    for _, texture in pairs(box) do
        if texture:IsShown() then texture:Hide() end
    end
end

--------------------------------------------------------------------------------
-- Blizzard's own chrome
--------------------------------------------------------------------------------

-- Hidden rather than removed: SharedTooltip_SetBackdropStyle rebuilds and shows
-- it again whenever a tooltip changes style, and the addon has to be able to
-- give it back intact when it is turned off.
function Skin:HideBlizzardChrome(tooltip)
    local nineSlice = tooltip.NineSlice
    if nineSlice then
        if nineSlice:IsShown() then nineSlice:Hide() end
        if nineSlice.GetAlpha and nineSlice:GetAlpha() ~= 0 then nineSlice:SetAlpha(0) end
    end

    -- Pre-NineSlice builds, and a handful of templates that still carry a real
    -- backdrop of their own.
    if type(tooltip.SetBackdrop) == "function" and tooltip.GetBackdrop and tooltip:GetBackdrop() then
        pcall(tooltip.SetBackdrop, tooltip, nil)
    end
end

function Skin:RestoreBlizzardChrome(tooltip)
    local nineSlice = tooltip.NineSlice
    if nineSlice then
        nineSlice:SetAlpha(1)
        nineSlice:Show()
    end
end

--------------------------------------------------------------------------------
-- Applying
--------------------------------------------------------------------------------

local function ConfiguredColors()
    local cfg = PTT.Config
    local bg = cfg.bgColor or {}
    local border = cfg.borderColor or {}
    return
        { r = bg.r or 0.086, g = bg.g or 0.086, b = bg.b or 0.086, a = cfg.bgAlpha or 0.94 },
        { r = border.r or 0.176, g = border.g or 0.176, b = border.b or 0.176, a = 1 }
end

-- The full treatment: build the box if needed, paint it from the config, set the
-- scale, and take Blizzard's frame down. Called on adoption and whenever a
-- setting changes - not on every show.
function Skin:Apply(tooltip)
    if not PTT.Config.enabled then return end
    if not tooltip or not Registry.adopted[tooltip] then return end

    if not self:EnsureBox(tooltip) then return end

    -- Scale first, then paint. The hairline width is derived from the frame's
    -- effective scale, so painting before scaling would size the border against
    -- the scale the tooltip is about to stop having.
    if tooltip.SetScale then
        if tooltip.peaversOriginalScale == nil then
            tooltip.peaversOriginalScale = tooltip:GetScale()
        end
        local scale = PTT.Config.scale or 1
        if tooltip:GetScale() ~= scale then
            tooltip:SetScale(scale)
        end
    end

    local bg, border = ConfiguredColors()

    -- A tooltip carrying a live quality or reaction colour keeps it; only the
    -- default border is repainted from the config.
    local override = tooltip.peaversBorderOverride
    if override then border = override end

    self:PaintBox(tooltip, bg, border)
    self:ShowBox(tooltip)
    self:HideBlizzardChrome(tooltip)
end

-- The cheap path, run from the SharedTooltip_SetBackdropStyle hook on every
-- tooltip that shows. Everything here is guarded by a state read first, so a
-- tooltip that is already in the right state costs nothing but the reads.
function Skin:Reassert(tooltip)
    if not PTT.Config.enabled then return end
    if not tooltip.peaversBox then
        self:Apply(tooltip)
        return
    end
    self:HideBlizzardChrome(tooltip)
    self:ShowBox(tooltip)
end

function Skin:Restore(tooltip)
    self:HideBox(tooltip)
    self:RestoreBlizzardChrome(tooltip)
    -- Back to the scale the tooltip had before we touched it, which is not
    -- necessarily 1: NamePlateTooltip in particular ships scaled.
    if tooltip.SetScale and tooltip.peaversOriginalScale then
        tooltip:SetScale(tooltip.peaversOriginalScale)
    end
    tooltip.peaversBorderOverride = nil
end

function Skin:ApplyAll()
    Registry:ForEach(function(tooltip) Skin:Apply(tooltip) end)
    self:ApplyFonts()
end

function Skin:RestoreAll()
    Registry:ForEach(function(tooltip) Skin:Restore(tooltip) end)
    self:RestoreFonts()
end

--------------------------------------------------------------------------------
-- Border colour
--
-- The one piece of live information the skin carries. Content decides what the
-- colour means; Skin only knows how to paint it and how to put it back.
--------------------------------------------------------------------------------

function Skin:SetBorderColor(tooltip, r, g, b)
    if not PTT.Config.enabled then return end
    local box = tooltip.peaversBox
    if not box then return end

    tooltip.peaversBorderOverride = { r = r, g = g, b = b, a = 1 }

    box.top:SetColorTexture(r, g, b, 1)
    box.bottom:SetColorTexture(r, g, b, 1)
    box.left:SetColorTexture(r, g, b, 1)
    box.right:SetColorTexture(r, g, b, 1)
end

function Skin:ResetBorderColor(tooltip)
    local box = tooltip.peaversBox
    if not box then return end
    if not tooltip.peaversBorderOverride then return end

    tooltip.peaversBorderOverride = nil

    local _, border = ConfiguredColors()
    box.top:SetColorTexture(border.r, border.g, border.b, 1)
    box.bottom:SetColorTexture(border.r, border.g, border.b, 1)
    box.left:SetColorTexture(border.r, border.g, border.b, 1)
    box.right:SetColorTexture(border.r, border.g, border.b, 1)
end

--------------------------------------------------------------------------------
-- Fonts
--
-- Size only. A font *family* picker would mean shipping fonts, a media library,
-- and a settings page of its own to solve a problem the game's own font already
-- solves; the thing people actually want from a tooltip addon is for it to stop
-- being too small to read.
--------------------------------------------------------------------------------

local function CaptureFonts()
    if originalFonts then return originalFonts end
    originalFonts = {}
    for _, entry in ipairs(FONT_OBJECTS) do
        local object = _G[entry.name]
        if object and object.GetFont then
            local file, size, flags = object:GetFont()
            if file then
                originalFonts[entry.name] = { file = file, size = size, flags = flags }
            end
        end
    end
    return originalFonts
end

function Skin:ApplyFonts()
    if not PTT.Config.enabled then return end
    local originals = CaptureFonts()
    local base = PTT.Config.fontSize or 12

    for _, entry in ipairs(FONT_OBJECTS) do
        local object = _G[entry.name]
        local original = originals[entry.name]
        if object and original and object.SetFont then
            pcall(object.SetFont, object, original.file, base + entry.delta, original.flags)
        end
    end
end

function Skin:RestoreFonts()
    if not originalFonts then return end
    for name, original in pairs(originalFonts) do
        local object = _G[name]
        if object and object.SetFont then
            pcall(object.SetFont, object, original.file, original.size, original.flags)
        end
    end
end

--------------------------------------------------------------------------------
-- Wiring
--------------------------------------------------------------------------------

function Skin:Initialize()
    Registry:OnAdopt(function(tooltip)
        Skin:Apply(tooltip)
    end)

    Registry:OnCleared(function(tooltip)
        Skin:ResetBorderColor(tooltip)
    end)
end

Skin.WHITE_TEXTURE = WHITE

return Skin
