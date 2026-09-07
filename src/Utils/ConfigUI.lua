local _, PTT = ...

local ConfigUI = {}
PTT.ConfigUI = ConfigUI

local PeaversCommons = _G.PeaversCommons
if not PeaversCommons then
    print("|cffff0000Error:|r PeaversCommons not found.")
    return
end

-- Applying a setting lives with the addon's schema now, in EditMode.lua, so the
-- settings page and the Edit Mode panel cannot disagree about what a change
-- should do.

function ConfigUI:BuildInfoPage(parentFrame)
    PeaversCommons.ConfigUIUtils.BuildInfoPage(parentFrame, "ToolTip", {
        "Redraws the game's tooltips as a flat black box with a 1px border, and " ..
            "puts that border to work: it carries the item's quality or the " ..
            "unit's class and reaction, so the colour tells you what you are " ..
            "looking at before you have read a word.",
        { command = "/ptt", desc = "open the settings" },
        { command = "/ptt anchor", desc = "unlock the anchor and drag it" },
        { command = "/ptt cursor", desc = "follow the mouse cursor" },
        { command = "/ptt scale N", desc = "set the tooltip scale" },
        { command = "/ptt disable", desc = "give every tooltip back to Blizzard" },

        { header = "Settings are in Edit Mode" },
        "Open Edit Mode from the game menu and select the tooltip. Everything " ..
            "is there: the colours and the border, where tooltips appear, the " ..
            "health bar, and what the tooltip is allowed to add.",

        { header = "What it deliberately does not do" },
        "It never removes or rewrites a line the game wrote. A tooltip line " ..
            "cannot be deleted once it has been added, only blanked, which leaves " ..
            "an empty row behind - and the alternative, rebuilding the whole " ..
            "tooltip, breaks embedded widgets and every other addon's additions. " ..
            "So this addon recolours and appends, and stops there. That is the " ..
            "difference between a tooltip that stays correct and one that needs " ..
            "a patch every time Blizzard adds a line.",

        { header = "Restricted data" },
        "Since the 12.0 pre-patch the client hides enemy health, names and class " ..
            "behind restricted values that an addon may pass along but not read. " ..
            "Every unit read here goes through guards that keep the value sealed " ..
            "and hand it to a formatter allowed to consume it, so tooltips keep " ..
            "working in raids, keys and rated PvP rather than going blank.",

        { header = "Performance" },
        "Nothing in this addon runs per frame and nothing runs on a timer. " ..
            "Following the cursor is done by the client's own cursor anchoring, " ..
            "which costs no Lua at all; the health bar updates from the event " ..
            "that changes it. The skin itself is five textures per tooltip, " ..
            "created once and afterwards only recoloured.",
    })
end

function ConfigUI:GetPages()
    return {
        { key = "info", label = "Information", builder = function(f) ConfigUI:BuildInfoPage(f) end },
    }
end

function ConfigUI:BuildIntoFrame(parentFrame)
    self:BuildInfoPage(parentFrame)
    return parentFrame
end

function ConfigUI:OpenOptions()
    if _G.PeaversConfig and _G.PeaversConfig.MainFrame then
        _G.PeaversConfig.MainFrame:Show()
        _G.PeaversConfig.MainFrame:SelectAddon("PeaversToolTip")
        return
    end

    if Settings and Settings.OpenToCategory then
        if PTT.directSettingsCategoryID then
            local success = pcall(Settings.OpenToCategory, PTT.directSettingsCategoryID)
            if success then return end
        end
        if PTT.directCategoryID then
            local success = pcall(Settings.OpenToCategory, PTT.directCategoryID)
            if success then return end
        end
    end

    if SettingsPanel then
        SettingsPanel:Open()
    end
end

function ConfigUI:Initialize()
end

return ConfigUI
