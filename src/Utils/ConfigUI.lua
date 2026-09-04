local _, PTT = ...

local ConfigUI = {}
PTT.ConfigUI = ConfigUI

local PeaversCommons = _G.PeaversCommons
if not PeaversCommons then
    print("|cffff0000Error:|r PeaversCommons not found.")
    return
end

local W = PeaversCommons.Widgets

local function ResolveWidth(parentFrame, indent)
    local parentWidth = parentFrame:GetWidth() or 0
    if parentWidth > 100 then
        return parentWidth - (indent * 2) - 10
    end
    return 360
end

-- Every setting on every page ends here: save, then repaint what is already on
-- screen so the change is visible without hovering something new.
local function Apply()
    PTT.Config:Save()
    if PTT.Config.enabled then
        PTT.Skin:ApplyAll()
        PTT.HealthBar:ApplyLayout()
        PTT.Anchor:Reposition()
    end
end

--------------------------------------------------------------------------------
-- Appearance
--------------------------------------------------------------------------------

function ConfigUI:BuildAppearancePage(parentFrame)
    local y = -10
    local indent = 25
    local width = ResolveWidth(parentFrame, indent)

    local _, newY = W:CreateSectionHeader(parentFrame, "Tooltips", indent, y)
    y = newY - 8

    local toggle = W:CreateCheckbox(parentFrame, "Enable PeaversToolTip", {
        checked = PTT.Config.enabled == true,
        width = width,
        onChange = function(checked)
            PTT.Config.enabled = checked
            PTT.Config:Save()
            if checked then PTT.Skin:ApplyAll() else PTT.Skin:RestoreAll() end
            PTT.HealthBar:ApplyLayout()
        end,
    })
    toggle:SetPoint("TOPLEFT", indent, y)
    y = y - 34

    local scale = W:CreateSlider(parentFrame, "Scale", {
        min = 0.6, max = 1.6, step = 0.05,
        value = PTT.Config.scale or 1,
        width = width,
        format = function(v) return string.format("%.2f", v) end,
        onChange = function(value)
            PTT.Config.scale = value
            Apply()
        end,
    })
    scale:SetPoint("TOPLEFT", indent, y)
    y = y - 56

    local fontSize = W:CreateSlider(parentFrame, "Font size", {
        min = 8, max = 20, step = 1,
        value = PTT.Config.fontSize or 12,
        width = width,
        onChange = function(value)
            PTT.Config.fontSize = value
            PTT.Config:Save()
            PTT.Skin:ApplyFonts()
        end,
    })
    fontSize:SetPoint("TOPLEFT", indent, y)
    y = y - 62

    local _, colorY = W:CreateSectionHeader(parentFrame, "Colours", indent, y)
    y = colorY - 8

    local bg = PTT.Config.bgColor or {}
    local bgPicker = W:CreateColorPicker(parentFrame, "Background", {
        r = bg.r or 0.086, g = bg.g or 0.086, b = bg.b or 0.086,
        width = width,
        onChange = function(r, g, b)
            PTT.Config.bgColor = { r = r, g = g, b = b }
            Apply()
        end,
    })
    bgPicker:SetPoint("TOPLEFT", indent, y)
    y = y - 32

    local alpha = W:CreateSlider(parentFrame, "Background opacity", {
        min = 0, max = 1, step = 0.02,
        value = PTT.Config.bgAlpha or 0.94,
        width = width,
        format = function(v) return string.format("%d%%", math.floor(v * 100 + 0.5)) end,
        onChange = function(value)
            PTT.Config.bgAlpha = value
            Apply()
        end,
    })
    alpha:SetPoint("TOPLEFT", indent, y)
    y = y - 56

    local border = PTT.Config.borderColor or {}
    local borderPicker = W:CreateColorPicker(parentFrame, "Border", {
        r = border.r or 0.176, g = border.g or 0.176, b = border.b or 0.176,
        width = width,
        onChange = function(r, g, b)
            PTT.Config.borderColor = { r = r, g = g, b = b }
            Apply()
        end,
    })
    borderPicker:SetPoint("TOPLEFT", indent, y)
    y = y - 36

    local qualityBorder = W:CreateCheckbox(parentFrame, "Colour the border by item quality", {
        checked = PTT.Config.borderByQuality ~= false,
        width = width,
        onChange = function(checked)
            PTT.Config.borderByQuality = checked
            Apply()
        end,
    })
    qualityBorder:SetPoint("TOPLEFT", indent, y)
    y = y - 30

    local reactionBorder = W:CreateCheckbox(parentFrame, "Colour the border by unit class or reaction", {
        checked = PTT.Config.borderByReaction ~= false,
        width = width,
        onChange = function(checked)
            PTT.Config.borderByReaction = checked
            Apply()
        end,
    })
    reactionBorder:SetPoint("TOPLEFT", indent, y)
    y = y - 30

    local note = W:CreateLabel(parentFrame,
        "The border is the one part of the tooltip that carries live information: " ..
            "epic purple, an elite's red, a friendly green. The colour set above " ..
            "is what it falls back to for everything else.",
        { font = "GameFontNormalSmall", color = { 0.5, 0.5, 0.5 } })
    note:SetPoint("TOPLEFT", indent, y)
    note:SetWidth(width)
    y = y - 52

    parentFrame:SetHeight(math.abs(y) + 30)
end

--------------------------------------------------------------------------------
-- Position
--------------------------------------------------------------------------------

function ConfigUI:BuildPositionPage(parentFrame)
    local y = -10
    local indent = 25
    local width = ResolveWidth(parentFrame, indent)

    local cursorControls = {}
    local anchorControls = {}

    local function SetGroupEnabled(controls, enabled)
        for _, control in ipairs(controls) do
            control:SetAlpha(enabled and 1 or 0.4)
        end
    end

    local function RefreshGroups()
        local mode = PTT.Config.anchorMode
        SetGroupEnabled(cursorControls, mode == "cursor")
        SetGroupEnabled(anchorControls, mode == "anchor")
    end

    local _, newY = W:CreateSectionHeader(parentFrame, "Where tooltips appear", indent, y)
    y = newY - 8

    local mode = W:CreateDropdown(parentFrame, "Anchor", {
        width = width,
        selected = PTT.Config.anchorMode or "cursor",
        options = {
            { value = "cursor",   label = "Follow the mouse cursor" },
            { value = "anchor",   label = "A fixed spot I choose" },
            { value = "blizzard", label = "Leave Blizzard's default alone" },
        },
        onChange = function(value)
            PTT.Config.anchorMode = value
            PTT.Config:Save()
            RefreshGroups()
        end,
    })
    mode:SetPoint("TOPLEFT", indent, y)
    y = y - 58

    local note = W:CreateLabel(parentFrame,
        "This governs the tooltip the game positions itself - the world, units, " ..
            "action buttons. A tooltip that a bag or a character panel has " ..
            "deliberately placed beside itself stays where that frame put it.",
        { font = "GameFontNormalSmall", color = { 0.5, 0.5, 0.5 } })
    note:SetPoint("TOPLEFT", indent, y)
    note:SetWidth(width)
    y = y - 48

    local _, cursorY = W:CreateSectionHeader(parentFrame, "Cursor offset", indent, y)
    y = cursorY - 8

    local offsetX = W:CreateSlider(parentFrame, "Horizontal", {
        min = -100, max = 100, step = 1,
        value = PTT.Config.cursorOffsetX or 12,
        width = width,
        onChange = function(value)
            PTT.Config.cursorOffsetX = value
            PTT.Config:Save()
        end,
    })
    offsetX:SetPoint("TOPLEFT", indent, y)
    y = y - 56
    cursorControls[#cursorControls + 1] = offsetX

    local offsetY = W:CreateSlider(parentFrame, "Vertical", {
        min = -100, max = 100, step = 1,
        value = PTT.Config.cursorOffsetY or -12,
        width = width,
        onChange = function(value)
            PTT.Config.cursorOffsetY = value
            PTT.Config:Save()
        end,
    })
    offsetY:SetPoint("TOPLEFT", indent, y)
    y = y - 62
    cursorControls[#cursorControls + 1] = offsetY

    local _, anchorY = W:CreateSectionHeader(parentFrame, "Fixed anchor", indent, y)
    y = anchorY - 8

    local unlock = W:CreateButton(parentFrame, "Unlock and drag the anchor", {
        width = width,
        variant = "primary",
        onClick = function(self)
            local unlocked = PTT.Anchor:ToggleUnlocked()
            self:SetText(unlocked and "Lock the anchor" or "Unlock and drag the anchor")
        end,
    })
    unlock:SetPoint("TOPLEFT", indent, y)
    y = y - 34
    anchorControls[#anchorControls + 1] = unlock

    local reset = W:CreateButton(parentFrame, "Reset the anchor position", {
        width = width,
        onClick = function()
            PTT.Anchor:ResetPosition()
        end,
    })
    reset:SetPoint("TOPLEFT", indent, y)
    y = y - 42
    anchorControls[#anchorControls + 1] = reset

    RefreshGroups()

    parentFrame:SetHeight(math.abs(y) + 30)
end

--------------------------------------------------------------------------------
-- Health bar
--------------------------------------------------------------------------------

function ConfigUI:BuildHealthBarPage(parentFrame)
    local y = -10
    local indent = 25
    local width = ResolveWidth(parentFrame, indent)

    local controls = {}
    local function SetControlsEnabled(enabled)
        for _, control in ipairs(controls) do
            control:SetAlpha(enabled and 1 or 0.4)
        end
    end

    local _, newY = W:CreateSectionHeader(parentFrame, "Health bar", indent, y)
    y = newY - 8

    local toggle = W:CreateCheckbox(parentFrame, "Show a health bar on unit tooltips", {
        checked = PTT.Config.healthBar ~= false,
        width = width,
        onChange = function(checked)
            PTT.Config.healthBar = checked
            PTT.Config:Save()
            PTT.HealthBar:ApplyLayout()
            SetControlsEnabled(checked)
        end,
    })
    toggle:SetPoint("TOPLEFT", indent, y)
    y = y - 34

    local position = W:CreateDropdown(parentFrame, "Position", {
        width = width,
        selected = PTT.Config.healthBarPosition or "bottom",
        options = {
            { value = "bottom",  label = "Below the tooltip" },
            { value = "top",     label = "Above the tooltip" },
            { value = "default", label = "Inside, where Blizzard puts it" },
        },
        onChange = function(value)
            PTT.Config.healthBarPosition = value
            PTT.Config:Save()
            PTT.HealthBar:ApplyLayout()
        end,
    })
    position:SetPoint("TOPLEFT", indent, y)
    y = y - 58
    controls[#controls + 1] = position

    local height = W:CreateSlider(parentFrame, "Height", {
        min = 2, max = 24, step = 1,
        value = PTT.Config.healthBarHeight or 6,
        width = width,
        onChange = function(value)
            PTT.Config.healthBarHeight = value
            PTT.Config:Save()
            PTT.HealthBar:ApplyLayout()
        end,
    })
    height:SetPoint("TOPLEFT", indent, y)
    y = y - 62
    controls[#controls + 1] = height

    local colored = W:CreateCheckbox(parentFrame, "Colour it by class or reaction", {
        checked = PTT.Config.healthBarColorByUnit ~= false,
        width = width,
        onChange = function(checked)
            PTT.Config.healthBarColorByUnit = checked
            PTT.Config:Save()
            PTT.HealthBar:Refresh()
        end,
    })
    colored:SetPoint("TOPLEFT", indent, y)
    y = y - 38
    controls[#controls + 1] = colored

    local text = W:CreateDropdown(parentFrame, "Text", {
        width = width,
        selected = PTT.Config.healthBarText or "none",
        options = {
            { value = "none",    label = "None" },
            { value = "percent", label = "Percentage" },
            { value = "value",   label = "Current health" },
            { value = "both",    label = "Current health and percentage" },
        },
        onChange = function(value)
            PTT.Config.healthBarText = value
            PTT.Config:Save()
            PTT.HealthBar:Refresh()
        end,
    })
    text:SetPoint("TOPLEFT", indent, y)
    y = y - 58
    controls[#controls + 1] = text

    local note = W:CreateLabel(parentFrame,
        "Enemy health is restricted data in raids, keys and rated PvP. The bar and " ..
            "its text are built through the display-only calls the client provides " ..
            "for exactly that, so a boss reads the same as a party member.",
        { font = "GameFontNormalSmall", color = { 0.5, 0.5, 0.5 } })
    note:SetPoint("TOPLEFT", indent, y)
    note:SetWidth(width)
    y = y - 52

    SetControlsEnabled(PTT.Config.healthBar ~= false)

    parentFrame:SetHeight(math.abs(y) + 30)
end

--------------------------------------------------------------------------------
-- Content
--------------------------------------------------------------------------------

function ConfigUI:BuildContentPage(parentFrame)
    local y = -10
    local indent = 25
    local width = ResolveWidth(parentFrame, indent)

    local _, newY = W:CreateSectionHeader(parentFrame, "Units", indent, y)
    y = newY - 8

    local checkboxes = {
        {
            key = "classColorNames",
            label = "Colour the name by class or reaction",
            default = true,
        },
        {
            key = "showTarget",
            label = "Show what the unit is targeting",
            default = true,
        },
    }

    for _, entry in ipairs(checkboxes) do
        local current = PTT.Config[entry.key]
        if current == nil then current = entry.default end

        local box = W:CreateCheckbox(parentFrame, entry.label, {
            checked = current == true,
            width = width,
            onChange = function(checked)
                PTT.Config[entry.key] = checked
                PTT.Config:Save()
            end,
        })
        box:SetPoint("TOPLEFT", indent, y)
        y = y - 30
    end

    y = y - 8
    local _, itemsY = W:CreateSectionHeader(parentFrame, "Items and spells", indent, y)
    y = itemsY - 8

    local extras = {
        { key = "showIcon",    label = "Show the icon beside the tooltip" },
        { key = "showItemID",  label = "Show the item ID" },
        { key = "showSpellID", label = "Show the spell ID" },
    }

    for _, entry in ipairs(extras) do
        local box = W:CreateCheckbox(parentFrame, entry.label, {
            checked = PTT.Config[entry.key] == true,
            width = width,
            onChange = function(checked)
                PTT.Config[entry.key] = checked
                PTT.Config:Save()
            end,
        })
        box:SetPoint("TOPLEFT", indent, y)
        y = y - 30
    end

    y = y - 8
    local _, combatY = W:CreateSectionHeader(parentFrame, "In combat", indent, y)
    y = combatY - 8

    local hide = W:CreateDropdown(parentFrame, "Hide tooltips", {
        width = width,
        selected = PTT.Config.hideInCombat or "never",
        options = {
            { value = "never", label = "Never - always show tooltips" },
            { value = "units", label = "Only for units" },
            { value = "all",   label = "For everything" },
        },
        onChange = function(value)
            PTT.Config.hideInCombat = value
            PTT.Config:Save()
        end,
    })
    hide:SetPoint("TOPLEFT", indent, y)
    y = y - 58

    local note = W:CreateLabel(parentFrame,
        "Holding Shift always shows the tooltip, whatever this is set to, so a " ..
            "setting made out of combat never traps you in one.",
        { font = "GameFontNormalSmall", color = { 0.5, 0.5, 0.5 } })
    note:SetPoint("TOPLEFT", indent, y)
    note:SetWidth(width)
    y = y - 44

    parentFrame:SetHeight(math.abs(y) + 30)
end

--------------------------------------------------------------------------------
-- Information
--------------------------------------------------------------------------------

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
        { key = "appearance", label = "Appearance", builder = function(f) ConfigUI:BuildAppearancePage(f) end },
        { key = "position", label = "Position", builder = function(f) ConfigUI:BuildPositionPage(f) end },
        { key = "healthbar", label = "Health bar", builder = function(f) ConfigUI:BuildHealthBarPage(f) end },
        { key = "content", label = "Content", builder = function(f) ConfigUI:BuildContentPage(f) end },
    }
end

function ConfigUI:BuildIntoFrame(parentFrame)
    self:BuildAppearancePage(parentFrame)
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
