local lib = loadstring(readfile("library.lua"))()

local window = lib:CreateWindow({
    Name = "Ultimate Showcase",
    Subtitle = "All Features Demo",
    LoadingEnabled = true,   -- Shows the slick boot sequence
    DisableIntro = false     -- Let the animation play
})

-- ==========================================
-- TAB 1: CORE WIDGETS
-- ==========================================
local coreTab = window:CreateTab({ Name = "Core", Icon = 10134079822 }) -- a generic icon id
coreTab:SetBadge("New")

local labelSec = coreTab:CreateSection({ Title = "Text & Decor" })

labelSec:CreateLabel("Welcome to the Ultimate Showcase.")
local p = labelSec:CreateParagraph({ 
    Title = "About This Demo", 
    Content = "This tab demonstrates all the standard interactive controls and text displays." 
})

labelSec:CreateDivider()

labelSec:CreateButton({
    Name = "Update Paragraph & Send Notification",
    Callback = function()
        p:SetTitle("Paragraph Updated!")
        p:SetContent("You clicked the button. The text changed instantly.")
        lib:Notify({
            Title = "Action Completed",
            Text = "Paragraph content was successfully updated via script."
        })
    end
})

local widgetsSec = coreTab:CreateSection({ Title = "Values & Inputs" })

local flyToggle = widgetsSec:CreateToggle({
    Name = "Fly Hack",
    Default = false,
    Flag = "FlyHack",
    Callback = function(v)
        -- simple callback demo
    end
})

local speedSlider = widgetsSec:CreateSlider({
    Name = "Speed",
    Range = {16, 200},
    CurrentValue = 16,
    Increment = 1,
    Suffix = " walkspeed",
    Flag = "WalkSpeed",
    Callback = function(val) end
})
-- Speed depends on Fly
speedSlider:DependOn(flyToggle)

local modeDropdown = widgetsSec:CreateDropdown({
    Name = "Attack Mode",
    Options = {"Melee", "Ranged", "Magic"},
    Default = "Melee",
    Flag = "AttackMode",
    Callback = function(val) end
})

local aimbotTargets = widgetsSec:CreateMultiDropdown({
    Name = "Aimbot Targets",
    Options = {"Players", "NPCs", "Bosses", "Vehicles"},
    Default = {"Players"},
    Flag = "AimbotTargets",
    Callback = function(selections) end
})

widgetsSec:CreateInput({
    Name = "Custom Username",
    PlaceholderText = "enter name here...",
    ClearTextOnFocus = true,
    Flag = "CustomUser",
    Callback = function(text) end
})

widgetsSec:CreateKeybind({
    Name = "Panic Button",
    CurrentKeybind = "P",
    Flag = "PanicBind",
    Callback = function()
        lib:Notify({Title="Panic!", Text="Panic button pressed!"})
    end
})

widgetsSec:CreateColorPicker({
    Name = "Aura Color",
    CurrentColor = Color3.fromRGB(10, 132, 255),
    Flag = "AuraColor",
    Callback = function(color) end
})

-- ==========================================
-- TAB 2: DEPENDENCIES & DYNAMICS
-- ==========================================
local depTab = window:CreateTab({ Name = "Dynamic", Icon = 10134079822 })

local reactiveSec = depTab:CreateSection({ Title = "Reactive Dependencies" })

local masterSwitch = reactiveSec:CreateToggle({ Name = "Master Switch", Default = false })
local modeSwitch = reactiveSec:CreateDropdown({ Name = "Mode", Options = {"Basic", "Pro", "God"}, Default = "Basic" })

local dependentButton = reactiveSec:CreateButton({
    Name = "Pro/God Ability",
    Callback = function()
        lib:Notify({Title="Success", Text="You used a restricted ability."})
    end
})
-- Aggregate dependency with a custom predicate function:
dependentButton:DependOnAll({masterSwitch, modeSwitch}, function(values)
    return values[1] == true and (values[2] == "Pro" or values[2] == "God")
end)

reactiveSec:CreateDivider()

local prog = reactiveSec:CreateProgressBar({ Name = "Wait Progress", CurrentValue = 0 })

local isCasting = false
reactiveSec:CreateButton({
    Name = "Cast Spell (Progress Demo)",
    Callback = function()
        if isCasting then return end
        isCasting = true
        task.spawn(function()
            for i=1, 10 do
                prog:SetProgress(i/10)
                prog:SetText("Casting... " .. tostring(i*10) .. "%")
                task.wait(0.2)
            end
            prog:SetProgress(0)
            prog:SetText("0%")
            isCasting = false
            lib:Notify({Title="Spell Cast!", Text="The spell was successfully cast."})
        end)
    end
})

local mutateSec = depTab:CreateSection({ Title = "Control Mutations" })

local labelToChange = mutateSec:CreateLabel("Look at this label.")
mutateSec:CreateButton({
    Name = "Change Label Above",
    Callback = function()
        labelToChange:SetName("Label was changed at " .. tostring(math.floor(tick())))
    end
})

local refreshBtn = mutateSec:CreateButton({
    Name = "Refresh Dropdowns Below",
    Callback = function()
        local dd = lib:GetControl("RefreshDynamicDD")
        local md = lib:GetControl("RefreshDynamicMD")
        if dd then dd:Refresh({"New 1", "New 2", "New 3"}) end
        if md then md:Refresh({"Alpha", "Beta", "Gamma"}) end
    end
})

mutateSec:CreateDropdown({
    Name = "Dynamic Single",
    Options = {"A", "B"},
    Flag = "RefreshDynamicDD"
})
mutateSec:CreateMultiDropdown({
    Name = "Dynamic Multi",
    Options = {"X", "Y"},
    Flag = "RefreshDynamicMD"
})

-- ==========================================
-- TAB 3: SETTINGS & LIFECYCLE
-- ==========================================
local settingsTab = window:CreateTab({ Name = "Settings", Icon = 10134079822 })

local themeSec = settingsTab:CreateSection({ Title = "Appearance" })

themeSec:CreateDropdown({
    Name = "Theme",
    Options = {"Dark", "Light"},
    Default = "Dark",
    Callback = function(val)
        lib:SetTheme(val)
    end
})

themeSec:CreateColorPicker({
    Name = "Accent Color",
    CurrentColor = Color3.fromRGB(10, 132, 255),
    Callback = function(col)
        lib:SetAccent(col)
    end
})
themeSec:CreateKeybind({
    Name = "UI Toggle",
    CurrentKeybind = "RightControl",
    Flag = "UIToggle",
    Callback = function()
        window:ToggleVisible()
    end
})

local cfgSec = settingsTab:CreateSection({ Title = "Configuration" })
cfgSec:CreateConfigManager()

local dangerSec = settingsTab:CreateSection({ Title = "Danger Zone" })
local killBtn = dangerSec:CreateButton({
    Name = "Destroy First Tab Button",
    Callback = function(selfArg)
        -- Self-destruct logic demo isn't targeting self so we don't error out, let's target the label
        labelToChange:Destroy()
        -- also destroy itself so it can only be clicked once
        selfArg:Destroy()
    end
})

dangerSec:CreateButton({
    Name = "Unload UI completely",
    Callback = function()
        lib:Destroy()
    end
})

-- Start up
window:SetActiveTab(coreTab)
lib:Notify({
    Title = "Demo Loaded",
    Text = "All features are ready to explore."
})
