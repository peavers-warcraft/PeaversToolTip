--------------------------------------------------------------------------------
-- Content
--
-- What the tooltip says, and what colour its border ends up.
--
-- Everything here goes through TooltipDataProcessor, the post-call system the
-- client has used since 10.0. Two properties of it shape this file:
--
--   * A post-call runs after the tooltip's contents are set but before it is
--     shown, which is exactly when a border colour can be chosen from what the
--     tooltip is actually describing.
--   * An error thrown inside a post-call takes the whole tooltip down, not just
--     one line. So every game API called from here goes through Secret.Safe,
--     and every value that might be restricted is checked before it is compared.
--
-- The addon only ever *adds*. It does not remove or rewrite Blizzard's lines.
-- That is a deliberate limit rather than an oversight: a tooltip line cannot be
-- deleted once added, only blanked, and a blanked line leaves an empty row where
-- the text used to be. Addons that offer to hide the PvP line are either leaving
-- that gap behind or rebuilding the entire tooltip from scratch, which breaks
-- embedded widgets and every other addon's additions. Recolouring and appending
-- are the operations that stay correct.
--------------------------------------------------------------------------------

local addonName, PTT = ...

local Content = {}
PTT.Content = Content

local Registry = PTT.Registry
local Secret = PTT.Secret
local Skin = PTT.Skin

local Safe, SafeBool, Present = Secret.Safe, Secret.SafeBool, Secret.Present

-- These moved into C_Item over the 10.x-11.x cycle. Resolving both keeps the
-- addon loadable on whichever of the supported interface versions is running.
local GetItemInfo = (_G.C_Item and _G.C_Item.GetItemInfo) or _G.GetItemInfo
local GetItemQualityColor = (_G.C_Item and _G.C_Item.GetItemQualityColor) or _G.GetItemQualityColor
local GetItemQualityByID = _G.C_Item and _G.C_Item.GetItemQualityByID

local LABEL = "|cff949494%s|r"

--------------------------------------------------------------------------------
-- The icon
--
-- Built lazily, once per tooltip, and only if somebody turns it on. A holder
-- frame rather than a bare texture so the icon gets the same hairline box as the
-- tooltip it hangs off.
--------------------------------------------------------------------------------

local ICON_SIZE = 32

local function EnsureIcon(tooltip)
    if tooltip.peaversIcon then return tooltip.peaversIcon end

    local holder = CreateFrame("Frame", nil, tooltip)
    holder:SetSize(ICON_SIZE, ICON_SIZE)
    holder:SetPoint("TOPRIGHT", tooltip, "TOPLEFT", -6, 0)

    Skin:EnsureBox(holder, 1)
    Skin:PaintBox(holder,
        { r = 0.086, g = 0.086, b = 0.086, a = 0.94 },
        { r = 0.176, g = 0.176, b = 0.176, a = 1 })

    local texture = holder:CreateTexture(nil, "ARTWORK")
    texture:SetAllPoints(holder)
    -- Trims the baked-in border off Blizzard's icon art so it sits flush inside
    -- the hairline instead of inside two borders.
    texture:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    holder.texture = texture

    holder:Hide()
    tooltip.peaversIcon = holder
    return holder
end

local function ShowIcon(tooltip, texturePath)
    if not PTT.Config.showIcon then return end
    if not Present(texturePath) then return end

    local holder = EnsureIcon(tooltip)
    holder.texture:SetTexture(texturePath)
    holder:Show()
end

local function HideIcon(tooltip)
    local holder = tooltip.peaversIcon
    if holder and holder:IsShown() then holder:Hide() end
end

--------------------------------------------------------------------------------
-- Units
--------------------------------------------------------------------------------

-- Recolouring the title is always safe, even when the name itself is secret:
-- SetTextColor does not look at the text. Only the *choice* of colour needs the
-- unit to be readable, and GetUnitColor returns nil rather than grey when it is
-- not - so a restricted target keeps Blizzard's colour instead of being painted
-- over with "unknown".
local function ColorTitle(tooltip, color)
    local name = tooltip.GetName and tooltip:GetName()
    if not name then return end

    local line = _G[name .. "TextLeft1"]
    if line and line.SetTextColor then
        line:SetTextColor(color.r, color.g, color.b)
    end
end

local function AddTargetLine(tooltip, unit)
    local target = unit .. "target"
    if SafeBool(UnitExists, target) == false then return end

    if SafeBool(UnitIsUnit, target, "player") then
        tooltip:AddDoubleLine(LABEL:format("Target"), "|cfff87171You|r")
        return
    end

    local targetName = Secret.GetUnitName(target)
    if not targetName then return end

    local color = Secret.GetUnitColor(target) or { r = 1, g = 1, b = 1 }
    -- AddDoubleLine ends in SetText, which accepts a secret. Wrapped anyway:
    -- this is the one call in the file handing restricted data to a Blizzard
    -- function whose internals we do not control.
    Safe(function()
        tooltip:AddDoubleLine(LABEL:format("Target"), targetName, nil, nil, nil,
            color.r, color.g, color.b)
    end)
end

function Content:OnUnit(tooltip)
    if not Registry.adopted[tooltip] then return end
    if not PTT.Config.enabled then return end

    local _, unit = Safe(tooltip.GetUnit, tooltip)
    if not unit then return end

    if PTT.Anchor:ShouldHide(true) then
        tooltip:Hide()
        return
    end

    local color = Secret.GetUnitColor(unit)

    if color and PTT.Config.classColorNames then
        ColorTitle(tooltip, color)
    end

    if color and PTT.Config.borderByReaction then
        Skin:SetBorderColor(tooltip, color.r, color.g, color.b)
    end

    if PTT.Config.showTarget then
        AddTargetLine(tooltip, unit)
    end

    if tooltip == _G.GameTooltip then
        PTT.HealthBar:OnUnit(unit)
    end
end

--------------------------------------------------------------------------------
-- Items
--
-- Item level is deliberately absent: the client has printed it on every
-- equippable tooltip since Legion, and a second copy of a number that is
-- already there is exactly the kind of thing that turns a tooltip addon into a
-- wall of text.
--------------------------------------------------------------------------------

local function ItemQuality(data)
    local link = data and (data.hyperlink or data.id)
    if not link then return nil end

    local quality = Safe(function() return select(3, GetItemInfo(link)) end)
    if quality == nil and GetItemQualityByID and data.id then
        quality = Safe(GetItemQualityByID, data.id)
    end

    -- A quality is a table key and a comparison target, so it has to be
    -- genuinely readable, not merely present.
    return Secret.Readable(quality)
end

function Content:OnItem(tooltip, data)
    if not Registry.adopted[tooltip] then return end
    if not PTT.Config.enabled then return end

    if PTT.Config.borderByQuality and GetItemQualityColor then
        local quality = ItemQuality(data)
        if quality then
            local r, g, b = Safe(GetItemQualityColor, quality)
            if r then Skin:SetBorderColor(tooltip, r, g, b) end
        end
    end

    if PTT.Config.showIcon and data and data.id then
        local icon = Safe(function() return select(10, GetItemInfo(data.hyperlink or data.id)) end)
        ShowIcon(tooltip, icon)
    end

    if PTT.Config.showItemID and data and data.id then
        tooltip:AddDoubleLine(LABEL:format("Item ID"), tostring(data.id))
    end
end

--------------------------------------------------------------------------------
-- Spells and auras
--------------------------------------------------------------------------------

function Content:OnSpell(tooltip, data)
    if not Registry.adopted[tooltip] then return end
    if not PTT.Config.enabled then return end
    if not data or not data.id then return end

    if PTT.Config.showIcon then
        local info = Safe(function() return _G.C_Spell.GetSpellInfo(data.id) end)
        if type(info) == "table" and info.iconID then
            ShowIcon(tooltip, info.iconID)
        end
    end

    if PTT.Config.showSpellID then
        tooltip:AddDoubleLine(LABEL:format("Spell ID"), tostring(data.id))
    end
end

--------------------------------------------------------------------------------
-- Wiring
--------------------------------------------------------------------------------

function Content:Initialize()
    if self.initialized then return end
    self.initialized = true

    Registry:OnCleared(function(tooltip)
        HideIcon(tooltip)
        if tooltip == _G.GameTooltip then tooltip.peaversUnit = nil end
    end)

    local processor = _G.TooltipDataProcessor
    local types = _G.Enum and _G.Enum.TooltipDataType
    if not processor or not processor.AddTooltipPostCall or not types then return end

    local function Register(dataType, handler)
        if dataType == nil then return end
        processor.AddTooltipPostCall(dataType, handler)
    end

    Register(types.Unit, function(tooltip) Content:OnUnit(tooltip) end)
    Register(types.Item, function(tooltip, data) Content:OnItem(tooltip, data) end)
    Register(types.Spell, function(tooltip, data) Content:OnSpell(tooltip, data) end)
    Register(types.UnitAura, function(tooltip, data) Content:OnSpell(tooltip, data) end)
end

return Content
