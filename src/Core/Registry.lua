--------------------------------------------------------------------------------
-- Registry
--
-- Answers one question for the rest of the addon: which tooltips are ours?
--
-- The naive approach is a hardcoded list of global names, and it is wrong in a
-- way that only shows up weeks later. Half the tooltips in the game belong to
-- load-on-demand Blizzard addons - the auction house, the perks program, the
-- profession UI - and they simply do not exist at login. A static list skins
-- what is there at the time and quietly misses the rest.
--
-- So adoption happens two ways. The static list is swept once at login for the
-- tooltips that are always present, and SharedTooltip_SetBackdropStyle is
-- hooked for everything else. That function is Blizzard's own "restyle this
-- tooltip" entry point and every shared tooltip calls it as it is shown, which
-- makes it both the moment a new tooltip introduces itself and the moment our
-- skin would have been overwritten. One hook, both problems.
--
-- Skin and Content do not hook anything themselves; they register handlers here
-- and are called for each tooltip as it is adopted. That keeps the file load
-- order in the .toc from mattering and means a tooltip that appears an hour into
-- a session is set up by exactly the same code path as GameTooltip was at login.
--------------------------------------------------------------------------------

local addonName, PTT = ...

local Registry = {}
PTT.Registry = Registry

-- Always present, and worth sweeping at login so the first tooltip of the
-- session is already skinned rather than being skinned as it appears.
--
-- EmbeddedItemTooltip is deliberately absent: it is a tooltip drawn *inside*
-- another tooltip (quest rewards), so skinning it produces a box in a box.
local STATIC_TOOLTIPS = {
    "GameTooltip",
    "ItemRefTooltip",
    "ItemRefShoppingTooltip1",
    "ItemRefShoppingTooltip2",
    "ShoppingTooltip1",
    "ShoppingTooltip2",
    "WorldMapTooltip",
    "NamePlateTooltip",
    "FriendsTooltip",
    "QuestScrollFrame.StoryTooltip",
    "QuestScrollFrame.CampaignTooltip",
}

-- Never skinned, whatever route they arrive by.
local EXCLUDED = {
    EmbeddedItemTooltip = true,
}

Registry.adopted = {}   -- [tooltip] = true
Registry.list = {}      -- iteration order, oldest first

local adoptHandlers = {}
local clearHandlers = {}
local showHandlers = {}

--------------------------------------------------------------------------------
-- Handler registration
--------------------------------------------------------------------------------

-- Called once per tooltip, the first time we see it. Use for creating textures
-- and installing script hooks.
function Registry:OnAdopt(fn)
    adoptHandlers[#adoptHandlers + 1] = fn
    -- Anything already adopted was adopted before this module loaded, so run it
    -- for those too. Makes registration order irrelevant.
    for _, tooltip in ipairs(self.list) do
        fn(tooltip)
    end
end

-- Called when a tooltip is emptied, before its next contents are set. Use for
-- resetting anything the previous contents changed.
function Registry:OnCleared(fn)
    clearHandlers[#clearHandlers + 1] = fn
end

-- Called when a tooltip is shown.
function Registry:OnShow(fn)
    showHandlers[#showHandlers + 1] = fn
end

--------------------------------------------------------------------------------
-- Adoption
--------------------------------------------------------------------------------

-- Resolve a possibly-dotted global name ("QuestScrollFrame.StoryTooltip") to a
-- frame, without erroring on any missing link in the chain.
local function Resolve(path)
    local current = _G
    for segment in string.gmatch(path, "[^.]+") do
        if type(current) ~= "table" then return nil end
        current = rawget(current, segment)
        if current == nil then
            -- Frames expose children as plain fields, but a mixin may put them
            -- behind a metatable, so fall back to a normal index.
            return nil
        end
    end
    return current
end

local function IsEligible(tooltip)
    if type(tooltip) ~= "table" then return false end
    if Registry.adopted[tooltip] then return false end
    if type(tooltip.GetObjectType) ~= "function" then return false end

    local ok, isTooltip = pcall(tooltip.IsObjectType, tooltip, "GameTooltip")
    if not ok or not isTooltip then return false end

    local name = tooltip.GetName and tooltip:GetName()
    if name and EXCLUDED[name] then return false end

    return true
end

function Registry:Adopt(tooltip)
    if not IsEligible(tooltip) then return false end

    self.adopted[tooltip] = true
    self.list[#self.list + 1] = tooltip

    -- OnTooltipCleared fires before the next contents are set, which is the only
    -- reliable place to undo whatever the *previous* contents did to the border.
    if tooltip.HookScript then
        pcall(tooltip.HookScript, tooltip, "OnTooltipCleared", function(self_)
            for _, fn in ipairs(clearHandlers) do fn(self_) end
        end)

        pcall(tooltip.HookScript, tooltip, "OnShow", function(self_)
            for _, fn in ipairs(showHandlers) do fn(self_) end
        end)
    end

    for _, fn in ipairs(adoptHandlers) do fn(tooltip) end

    return true
end

function Registry:ForEach(fn)
    for _, tooltip in ipairs(self.list) do
        fn(tooltip)
    end
end

function Registry:Count()
    return #self.list
end

--------------------------------------------------------------------------------
-- Initialization
--------------------------------------------------------------------------------

function Registry:Initialize()
    if self.initialized then return end
    self.initialized = true

    for _, path in ipairs(STATIC_TOOLTIPS) do
        local tooltip = Resolve(path)
        if tooltip then self:Adopt(tooltip) end
    end

    -- The catch-all. Blizzard calls this as a shared tooltip is shown and it is
    -- what resets the backdrop we just replaced, so the hook has to both adopt
    -- new tooltips and re-assert the skin on old ones. Skin registers the
    -- re-assert through OnAdopt; here we only need to make sure the tooltip is
    -- known.
    if type(_G.SharedTooltip_SetBackdropStyle) == "function" then
        hooksecurefunc("SharedTooltip_SetBackdropStyle", function(tooltip)
            if not PTT.Config.enabled then return end
            if not Registry.adopted[tooltip] then
                Registry:Adopt(tooltip)
            end
            PTT.Skin:Reassert(tooltip)
        end)
    end
end

return Registry
