local addonName, PTT = ...

-- Access the PeaversCommons library
local PeaversCommons = _G.PeaversCommons
local Utils = PeaversCommons.Utils

-- Initialize addon namespace
PTT.name = addonName
PTT.version = C_AddOns.GetAddOnMetadata(addonName, "Version") or "1.0.0"

-- Register slash commands
PeaversCommons.SlashCommands:Register(addonName, "ptt", {
    default = function()
        PTT.ConfigUI:OpenOptions()
    end,
    enable = function()
        PTT.Config.enabled = true
        PTT.Config:Save()
        PTT.Skin:ApplyAll()
        PTT.HealthBar:ApplyLayout()
        Utils.Print(PTT, "Tooltips skinned.")
    end,
    disable = function()
        PTT.Config.enabled = false
        PTT.Config:Save()
        PTT.Skin:RestoreAll()
        PTT.HealthBar:Restore()
        Utils.Print(PTT, "Every tooltip handed back to Blizzard.")
    end,
    anchor = function()
        PTT.Config.anchorMode = "anchor"
        PTT.Config:Save()
        local unlocked = PTT.Anchor:ToggleUnlocked()
        Utils.Print(PTT, unlocked
            and "Anchor unlocked - drag it where you want tooltips to appear."
            or "Anchor locked.")
    end,
    cursor = function()
        PTT.Config.anchorMode = "cursor"
        PTT.Config:Save()
        PTT.Anchor:SetUnlocked(false)
        Utils.Print(PTT, "Tooltips now follow the cursor.")
    end,
    scale = function(rest)
        local value = tonumber(rest)
        if not value then
            Utils.Print(PTT, "Usage: /ptt scale 1.1 (0.60-1.60)")
            return
        end
        PTT.Config.scale = math.max(0.6, math.min(1.6, value))
        PTT.Config:Save()
        PTT.Skin:ApplyAll()
        Utils.Print(PTT, string.format("Tooltip scale set to %.2f.", PTT.Config.scale))
    end,
    info = function()
        Utils.Print(PTT, string.format("%d tooltip(s) skinned. Anchor: %s. Scale: %.2f.",
            PTT.Registry:Count(), PTT.Config.anchorMode or "cursor", PTT.Config.scale or 1))
    end,
    debug = function()
        PTT.Config.debugMode = not PTT.Config.debugMode
        PTT.Config.DEBUG_ENABLED = PTT.Config.debugMode
        PTT.Config:Save()
        Utils.Print(PTT, "Debug mode " .. (PTT.Config.debugMode and "enabled" or "disabled"))
    end,
    help = function()
        Utils.Print(PTT, "Commands:")
        print("  /ptt - Open settings")
        print("  /ptt enable - Skin every tooltip")
        print("  /ptt disable - Give every tooltip back to Blizzard")
        print("  /ptt anchor - Unlock the fixed anchor and drag it")
        print("  /ptt cursor - Follow the mouse cursor instead")
        print("  /ptt scale N - Set the tooltip scale")
        print("  /ptt info - Print what is currently skinned")
    end
})

-- Initialize the addon
PeaversCommons.Events:Init(addonName, function()
    PTT.Config:Initialize()

    -- Order matters, and only in one place: Skin and Content install themselves
    -- as Registry handlers, so they have to be wired before Registry sweeps the
    -- static tooltip list. Registry replays adoption for handlers that register
    -- late, which makes everything after that point order-independent.
    PTT.Skin:Initialize()
    PTT.Content:Initialize()
    PTT.Registry:Initialize()
    PTT.Anchor:Initialize()
    PTT.HealthBar:Initialize()

    if PTT.ConfigUI and PTT.ConfigUI.Initialize then
        PTT.ConfigUI:Initialize()
    end

    if PTT.Patrons and PTT.Patrons.Initialize then
        PTT.Patrons:Initialize()
    end

    -- A load-on-demand Blizzard addon brings its own tooltips with it. Most
    -- announce themselves through SharedTooltip_SetBackdropStyle the first time
    -- they are shown, which Registry already hooks; the sweep here catches the
    -- handful that are created and shown in the same frame, before that hook has
    -- had a chance to skin them.
    PeaversCommons.Events:RegisterEvent("PLAYER_ENTERING_WORLD", function()
        if PTT.Config.enabled then
            PTT.Skin:ApplyAll()
            PTT.HealthBar:ApplyLayout()
        end
    end)

    -- Use the centralized SettingsUI system from PeaversCommons
    C_Timer.After(0.5, function()
        PeaversCommons.SettingsUI:CreateRedirectPage(PTT, "PeaversToolTip", "Peavers ToolTip")
    end)

    -- Register with PeaversConfig registry
    if PeaversCommons.ConfigRegistry then
        PeaversCommons.ConfigRegistry:Register({
            name = "PeaversToolTip",
            displayName = "ToolTip",
            description = "Flat black-box tooltips with an informative border",
            addonRef = PTT,
            config = PTT.Config,
            pages = PTT.ConfigUI:GetPages(),
            order = 14,
        })
    end
end, {
    suppressAnnouncement = true
})

_G.PeaversToolTip = PTT
