--------------------------------------------------------------------------------
-- Secret value guards
--
-- Since 12.0 the client hands addons *secret* values for restricted unit data:
-- health, names, class, reaction. A secret can be stored, passed on, and given
-- to a widget setter or a blessed formatter, but arithmetic, comparison, length,
-- and use as a table key are all hard Lua errors.
--
-- A tooltip addon runs into this constantly, because almost everything a
-- tooltip describes is a unit somebody is fighting. The rule that keeps this
-- module honest is the one PeaversUnitFrames learned the hard way: never try to
-- make a secret readable. Keep it secret and hand it to something allowed to
-- consume it. Rejecting secrets is what produces blank text and grey borders.
--
-- Note the deliberate asymmetry below: colouring a name is always safe, because
-- SetTextColor does not look at the text. So the addon recolours where it can
-- and only ever refuses to *choose* a colour, never to apply one.
--------------------------------------------------------------------------------

local addonName, PTT = ...

local Secret = {}
PTT.Secret = Secret

local format = string.format

--------------------------------------------------------------------------------
-- Primitives
--------------------------------------------------------------------------------

-- issecretvalue only exists from 12.0 onwards; on an older build nothing is
-- secret and this is a constant false.
function Secret.IsSecret(value)
    return type(issecretvalue) == "function" and issecretvalue(value) or false
end

local IsSecret = Secret.IsSecret

-- Call a game API that may be restricted, or simply missing on an older build,
-- without letting the error escape into a tooltip hook. An error thrown from a
-- TooltipDataProcessor post-call breaks the whole tooltip, not just our line.
--
-- Ten flat results rather than a packed table: this sits on the show path of
-- every tooltip in the game, and the flat form does not allocate.
function Secret.Safe(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a, b, c, d, e, f, g, h, i, j = pcall(fn, ...)
    if ok then return a, b, c, d, e, f, g, h, i, j end
    return nil
end

local Safe = Secret.Safe

-- Booleans are the sharp edge. A secret string or number can at least be
-- truth-tested; a secret *boolean* cannot be tested or compared at all. So every
-- boolean the client hands back comes through here as a plain true/false, or nil
-- meaning "not allowed to know".
--
-- Order matters: issecretvalue is safe to call on anything, so it is asked
-- before the nil comparison, which would itself be illegal on a secret.
function Secret.ReadBool(value)
    if IsSecret(value) then return nil end
    if value == nil then return nil end
    return value and true or false
end

local ReadBool = Secret.ReadBool

function Secret.SafeBool(fn, ...)
    return ReadBool(Safe(fn, ...))
end

local SafeBool = Secret.SafeBool

-- Truth-test something known not to be a boolean - a name, an icon, an id.
-- Testing those is permitted, comparing them is not, so this keeps the nil
-- comparison out of the call sites.
function Secret.Present(value)
    if IsSecret(value) then return true end
    return value ~= nil
end

local Present = Secret.Present

-- A value we are allowed to look at. Anything failing this must not be
-- compared, keyed, or measured - only stored, passed on, or set.
function Secret.Readable(value)
    if IsSecret(value) then return nil end
    return value
end

--------------------------------------------------------------------------------
-- Colours
--------------------------------------------------------------------------------

Secret.Colors = {
    unknown = { r = 0.60, g = 0.60, b = 0.60 },
    dead    = { r = 0.40, g = 0.40, b = 0.40 },
}

-- Class colour for players, faction colour for anything else. Returning nil
-- means "no opinion": the caller then leaves Blizzard's own colour alone rather
-- than painting over it with grey, which is what makes a restricted target look
-- untouched instead of broken.
function Secret.GetUnitColor(unit)
    if not unit then return nil end
    if SafeBool(UnitExists, unit) == false then return nil end

    if SafeBool(UnitIsPlayer, unit) then
        local class = Safe(function() return select(2, UnitClass(unit)) end)
        -- The class token has to be readable before it can be a table key.
        if not IsSecret(class) and class then
            local color = (_G.CUSTOM_CLASS_COLORS and _G.CUSTOM_CLASS_COLORS[class])
                or (_G.RAID_CLASS_COLORS and _G.RAID_CLASS_COLORS[class])
            if color then return color end
        end
        return nil
    end

    if SafeBool(UnitIsDeadOrGhost, unit) then return Secret.Colors.dead end

    local reaction = Safe(UnitReaction, unit, "player")
    if not IsSecret(reaction) and reaction and _G.FACTION_BAR_COLORS then
        local color = _G.FACTION_BAR_COLORS[reaction]
        if color then return color end
    end

    return nil
end

--------------------------------------------------------------------------------
-- Health text
--
-- Formatters that accept secrets are what make this work: AbbreviateNumbers
-- turns a restricted 287431 into "287k" without a comparison on our side, and
-- RoundToNearestString does the same for a percentage. An enemy in an encounter
-- reads exactly like a party member.
--------------------------------------------------------------------------------

local AbbreviateNumbers = _G.AbbreviateNumbers or _G.AbbreviateLargeNumbers
local RoundToNearestString = _G.C_StringUtil and _G.C_StringUtil.RoundToNearestString
local ScaleTo100 = _G.CurveConstants and _G.CurveConstants.ScaleTo100

-- A 0-100 percentage, frequently secret. Display only, never compared.
function Secret.GetHealthPercent(unit)
    if type(_G.UnitHealthPercent) == "function" then
        return Safe(_G.UnitHealthPercent, unit, true, ScaleTo100)
    end

    local cur, max = Safe(UnitHealth, unit), Safe(UnitHealthMax, unit)
    if IsSecret(cur) or IsSecret(max) then return nil end
    if cur == nil or max == nil or max == 0 then return nil end
    return (cur / max) * 100
end

local function PercentText(pct)
    if IsSecret(pct) then
        if RoundToNearestString then return RoundToNearestString(pct, 1) .. "%" end
        return nil
    end
    if pct == nil then return nil end
    return format("%d%%", math.floor(pct + 0.5))
end

local function ValueText(value)
    if IsSecret(value) then
        if AbbreviateNumbers then return AbbreviateNumbers(value) end
        -- No abbreviator on this build: string.format still accepts a secret,
        -- so the raw number is shown rather than nothing at all.
        return format("%s", value)
    end
    if value == nil then return nil end
    if AbbreviateNumbers then return AbbreviateNumbers(value) end
    return tostring(value)
end

Secret.PercentText = PercentText
Secret.ValueText = ValueText

-- Health readout honouring the configured mode, degrading to a percentage
-- whenever the absolute numbers are restricted and to an empty string when
-- neither is available. Concatenating two secret strings is permitted.
function Secret.BuildHealthText(unit, mode)
    if not unit or mode == nil or mode == "none" then return "" end

    if SafeBool(UnitIsConnected, unit) == false then return "Offline" end
    if SafeBool(UnitIsDeadOrGhost, unit) then return "Dead" end

    local pctText = PercentText(Secret.GetHealthPercent(unit))
    local curText = ValueText(Safe(UnitHealth, unit))

    if mode == "percent" and pctText then return pctText end
    if mode == "value" and curText then return curText end
    if mode == "both" and curText and pctText then return curText .. "  " .. pctText end

    return pctText or curText or ""
end

-- Unit name for display. SetText accepts secrets, so the caller can show it; we
-- simply must not measure, truncate or compare it here.
function Secret.GetUnitName(unit)
    local name = Safe(UnitName, unit)
    if not Present(name) then return nil end
    return name
end

return Secret
