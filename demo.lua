--[[
	iOS Roblox UI Lib — full feature demo / preview.
	Loads library.lua (adjust the path/HttpGet below to however you're distributing it) and builds one
	window exercising every widget and library-level feature, split across tabs by category. Kept as a
	permanent reference file — NOT a throwaway smoke test — for showing the library to someone or sanity
	-checking a change against the whole surface area at once.

	Usage: point PATH at your library.lua (local dev) or swap to game:HttpGet(...) for a hosted copy.
]]

local PATH = "library.lua" -- adjust for your environment; executor's own workspace, not a real OS path
local Library = loadstring(readfile(PATH))()

-- ================= Dynamic Custom Theme Registration (Tier 2) =================
Library:RegisterTheme("Emerald", {
	BgWindow       = Color3.fromRGB(16, 24, 20),
	BgSheet        = Color3.fromRGB(24, 36, 30),
	BgDock         = Color3.fromRGB(20, 30, 25),
	BgSlot         = Color3.fromRGB(32, 48, 40),
	BgSlotSelected = Color3.fromRGB(44, 68, 56),
	BgCard         = Color3.fromRGB(28, 42, 35),
	BgFrame        = Color3.fromRGB(36, 54, 45),
	BorderSubtle   = Color3.fromRGB(60, 90, 75),
	BorderGlow     = Color3.fromRGB(52, 199, 89),
	TextPrimary    = Color3.fromRGB(235, 250, 240),
	TextSecondary  = Color3.fromRGB(160, 190, 175),
	TextTertiary   = Color3.fromRGB(110, 140, 125),
	AccentBlue     = Color3.fromRGB(52, 199, 89), -- emerald green accent
	AccentRed      = Color3.fromRGB(255, 69, 58),
	Divider        = Color3.fromRGB(50, 75, 62),
	DockBorder     = Color3.fromRGB(60, 90, 75),
	SliderFill     = Color3.fromRGB(52, 199, 89),
})

local Window = Library:CreateWindow({ Name = "iOS Exploit", Subtitle = "Premium Suite — Full Demo" })

-- ================= Main: toggle / slider / dropdown / progress / divider / button =================
local Main = Window:CreateTab({ Name = "Main", Icon = "terminal" })
Main:SetBadge("3") -- Tab badge demo

Main:CreateParagraph({
	Title = "Welcome to iOS Roblox UI Lib v2",
	Content = "A high-fidelity glassmorphism interface library built purely in Luau with zero external assets. Features reactive dynamic theming, searchable dropdowns, tab badges, and full config persistence.",
})

Main:CreateLabel({ Text = "Core widgets — Toggle, Slider, Dropdown, ProgressBar, Divider, Button" })
local Fly = Main:CreateToggle({
	Name = "Fly Hack",
	Flag = "FlyHack",
	Callback = function(v) print("Fly Hack ->", v) end,
})
local Speed = Main:CreateSlider({
	Name = "Speed (Click-to-Edit)",
	Range = { 16, 200 },
	CurrentValue = 16,
	Flag = "Speed",
	Callback = function(v) print("Speed ->", v) end,
})
local Mode = Main:CreateDropdown({
	Name = "Mode",
	Options = { "Walk", "Noclip", "God", "Advanced" },
	CurrentOption = "Walk",
	Flag = "Mode",
	Callback = function(v) print("Mode ->", v) end,
})

-- Dependencies evaluate immediately and react to both UI input and programmatic :Set calls.
Speed:DependOn(Fly)
local AdvancedSpeed = Main:CreateSlider({
	Name = "Advanced Speed",
	Range = { 16, 350 },
	CurrentValue = 120,
	Callback = function(v) print("Advanced Speed ->", v) end,
})
AdvancedSpeed:DependOn(Mode, function(value)
	return value == "Advanced"
end)

local AdvancedMode = Main:CreateToggle({
	Name = "Advanced Mode Enabled",
	Callback = function(v) print("Advanced Mode Enabled ->", v) end,
})
local AirControl = Main:CreateSlider({
	Name = "Air Control",
	Range = { 0, 100 },
	CurrentValue = 50,
	Callback = function(v) print("Air Control ->", v) end,
})
AirControl:DependOnAll({ Fly, AdvancedMode })
local PrecisionBurst = Main:CreateButton({
	Name = "Precision Burst (Aggregate Dependency)",
	Callback = function() print("Precision burst fired") end,
})
PrecisionBurst:DependOnAll({ Fly, Mode, AdvancedMode }, function(values)
	return values[1] == true and values[2] == "Advanced" and values[3] == true
end)

Main:CreateDivider()

Main:CreateParagraph({
	Title = "Reactive dependencies",
	Content = "Speed follows Fly Hack. Advanced Speed requires Mode = Advanced. Air Control requires both Fly Hack and Advanced Mode Enabled.",
})

Main:CreateButton({
	Name = "Programmatic Dependency Probe",
	Callback = function()
		Fly:Set(true)
		Mode:Set("Advanced")
		AdvancedMode:Set(true)
		Library:Notify({ Title = "Dependencies Updated", Text = "All three dependent sliders were updated through public :Set calls." })
	end,
})

Main:CreateButton({
	Name = "Manually Disable Speed",
	Callback = function()
		Speed:SetEnabled(false)
		Library:Notify({ Title = "Manual Gate", Text = "Speed stays disabled even while Fly Hack is enabled." })
	end,
})

Main:CreateButton({
	Name = "Manually Enable Speed",
	Callback = function()
		Speed:SetEnabled(true)
		Library:Notify({ Title = "Manual Gate", Text = "Speed is enabled only if Fly Hack also passes its dependency." })
	end,
})

local dependencyListener = Fly:OnChanged(function(value)
	print("Fly dependency source changed ->", value)
end)

local DemoProgress = Main:CreateProgressBar({
	Name = "Task Progress",
	CurrentValue = 0.35,
	Flag = "DemoProg",
})

Main:CreateButton({
	Name = "Step Progress (+20%)",
	Callback = function()
		-- Demonstrating flag lookup via Library:GetControl and animated progress stepping
		local prog = Library:GetControl("DemoProg")
		if prog then
			local nextVal = (prog:GetProgress() + 0.2)
			if nextVal > 1.05 then
				nextVal = 0
			end
			prog:SetProgress(math.min(nextVal, 1), true)
			if nextVal >= 1 then
				prog:SetText("Complete!")
			else
				prog:SetText(nil) -- restore default percentage label
			end
		end
	end,
})

Main:CreateButton({
	Name = "Test Button",
	Callback = function() print("Test Button fired") end,
})

-- ================= Visuals: Searchable Dropdowns / MultiDropdown / ColorPicker =================
local Visuals = Window:CreateTab({ Name = "Visuals", Icon = "sliders" })
Visuals:SetBadge("NEW")

Visuals:CreateLabel({ Text = "Searchable & Scrolling Dropdowns (Tier 2)" })

Visuals:CreateDropdown({
	Name = "Target Item",
	Description = "Type in search box to filter",
	Searchable = true,
	MaxVisible = 5,
	Options = {
		"AK-47", "M4A1", "AWP Sniper", "Desert Eagle", "MP5-SD",
		"Combat Knife", "Flashbang", "Smoke Grenade", "HE Grenade",
		"Health Kit", "Armor Plate", "Night Vision", "C4 Explosive",
	},
	CurrentOption = "AWP Sniper",
	Flag = "TargetItem",
	Callback = function(v) print("Target Item ->", v) end,
})

local ESPFilters = Visuals:CreateMultiDropdown({
	Name = "ESP Filters",
	Description = "Searchable multi-select",
	Searchable = true,
	MaxVisible = 4,
	Options = {
		"Enemy Players", "Team Players", "Dead Bodies", "Dropped Weapons",
		"Vehicles", "Loot Crates", "Health Packs", "Objective Points",
	},
	CurrentOptions = { "Enemy Players", "Loot Crates" },
	Flag = "ESPFilters",
	Callback = function(list) print("ESP Filters ->", table.concat(list, ", ")) end,
})

local FilteredAction = Visuals:CreateButton({
	Name = "Enemy Filter Action",
	Callback = function() print("Enemy filter action fired") end,
})
FilteredAction:DependOn(ESPFilters, function(selected)
	return table.find(selected, "Enemy Players") ~= nil
end)

local AuraColor = Visuals:CreateColorPicker({
	Name = "Aura Color",
	CurrentColor = Color3.fromRGB(10, 132, 255),
	Flag = "AuraColor",
	Callback = function(c) print("Aura Color ->", c) end,
})

local Brightness = Visuals:CreateSlider({
	Name = "Brightness (Color Dependency)",
	Range = { 0, 100 },
	CurrentValue = 75,
	Callback = function(v) print("Brightness ->", v) end,
})
Brightness:DependOn(AuraColor, function(color)
	local _, _, value = color:ToHSV()
	return value > 0.45
end)

Visuals:CreateButton({
	Name = "Refresh Visual Options",
	Callback = function()
		local target = Library:GetControl("TargetItem")
		if target then
			target:Refresh({ "AK-47", "M4A1", "AWP Sniper", "Night Vision", "Thermal Scope" })
		end
		local filters = Library:GetControl("ESPFilters")
		if filters then
			filters:Refresh({ "Enemy Players", "Team Players", "Vehicles", "Aura" })
		end
		Library:Notify({ Title = "Options Refreshed", Text = "Dropdown and multi-dropdown refresh APIs exercised." })
	end,
})

-- ================= Player: Input / Keybind =================
local Player = Window:CreateTab({ Name = "Player", Icon = "stack" })

Player:CreateLabel({ Text = "Text input + keybind capture" })
local TargetPlayer = Player:CreateInput({
	Name = "Target Player",
	PlaceholderText = "username",
	Flag = "TargetPlayer",
	Callback = function(v) print("Target Player ->", v) end,
})
local NumericInput = Player:CreateInput({
	Name = "Numeric Only Example",
	PlaceholderText = "0 - 999",
	NumbersOnly = true,
	CurrentValue = "42",
	Callback = function(v) print("Numeric input ->", v) end,
})
local TargetAction = Player:CreateButton({
	Name = "Targeted Action",
	Callback = function() print("Targeted action fired") end,
})
TargetAction:DependOn(TargetPlayer, function(value)
	return value ~= ""
end)
Player:CreateDivider()
local FlyBind = Player:CreateKeybind({
	Name = "Fly Bind",
	CurrentKeybind = "F",
	Flag = "FlyBind",
	Callback = function() print("Fly Bind pressed") end,
	ChangedCallback = function(k) print("Fly Bind rebound ->", k) end,
})

local BoundAction = Player:CreateButton({
	Name = "K-Bound Action",
	Callback = function() print("K-Bound Action fired") end,
})
BoundAction:DependOn(FlyBind, function(keyName)
	return keyName == "K"
end)

local NavSection = Player:CreateSection({ Title = "Programmatic Navigation" })
NavSection:CreateButton({
	Name = "Jump to Settings Tab",
	Callback = function()
		Window:SetActiveTab("Settings")
	end,
})
NavSection:CreateButton({
	Name = "Clear Main Tab Badge",
	Callback = function()
		Main:SetBadge(nil)
		Library:Notify({ Title = "Badge Cleared", Text = "Main tab badge removed." })
	end,
})

-- ================= Settings: theme, dynamic accent, notify, config save/load =================
local Settings = Window:CreateTab({ Name = "Settings", Icon = "dot" })

Settings:CreateLabel({ Text = "Window drag: try dragging the header up top" })
Settings:CreateLabel({ Text = "Floating button (bottom-right of screen) drags freely; tap it to hide/show the whole menu" })
Settings:CreateKeybind({
	Name = "Toggle Menu",
	CurrentKeybind = "RightControl",
	Flag = "MenuToggleBind",
	Callback = function() Window:ToggleVisible() end,
	ChangedCallback = function(k) print("Menu toggle rebound ->", k) end,
})

local ThemeSection = Settings:CreateSection({ Title = "Theme & Accents (Reactive)" })
ThemeSection:CreateDropdown({
	Name = "Theme",
	Options = { "Dark", "Light", "Emerald" },
	CurrentOption = "Dark",
	Callback = function(v) Library:SetTheme(v) end,
})

ThemeSection:CreateDropdown({
	Name = "Accent Color",
	Options = { "iOS Blue", "Sunset Orange", "Emerald Green", "Purple Glow", "Hot Pink" },
	CurrentOption = "iOS Blue",
	Callback = function(choice)
		if choice == "iOS Blue" then
			Library:SetAccent(Color3.fromRGB(10, 132, 255))
		elseif choice == "Sunset Orange" then
			Library:SetAccent(Color3.fromRGB(255, 149, 0))
		elseif choice == "Emerald Green" then
			Library:SetAccent(Color3.fromRGB(52, 199, 89))
		elseif choice == "Purple Glow" then
			Library:SetAccent(Color3.fromRGB(175, 82, 222))
		elseif choice == "Hot Pink" then
			Library:SetAccent(Color3.fromRGB(255, 45, 85))
		end
	end,
})

local ConfigSection = Settings:CreateSection({ Title = "Config" })
ConfigSection:CreateConfigManager({
	Callback = function(action, name, ok, err)
		if action == "save" then
			Library:Notify({
				Title = ok and ("Saved \"" .. name .. "\"") or "Save Failed",
				Text = ok and "Every flagged widget's value was written to disk." or tostring(err),
			})
		elseif action == "load" then
			Library:Notify({
				Title = ok and ("Loaded \"" .. name .. "\"") or "Load Failed",
				Text = ok and "Every flagged widget was restored (callbacks included)." or tostring(err),
			})
		end
	end,
})

Settings:CreateButton({
	Name = "Test Notify",
	Callback = function()
		Library:Notify({ Title = "Hey", Text = "This is a toast notification.", Duration = 4 })
	end,
})

local LifecycleSection = Settings:CreateSection({ Title = "Lifecycle API" })
local LifecycleParagraph = LifecycleSection:CreateParagraph({
	Title = "Mutable paragraph",
	Content = "Buttons below exercise paragraph mutation, visibility, and per-control destruction.",
})
LifecycleSection:CreateButton({
	Name = "Update Paragraph",
	Callback = function()
		LifecycleParagraph:Set({ Title = "Updated", Content = "SetTitle, SetContent, and Set all remain available." })
	end,
})
LifecycleSection:CreateButton({
	Name = "Toggle Paragraph Visibility",
	Callback = function()
		LifecycleParagraph:SetVisible(not LifecycleParagraph.__demoVisible)
		LifecycleParagraph.__demoVisible = not LifecycleParagraph.__demoVisible
	end,
})
LifecycleParagraph.__demoVisible = true
local LifecycleToggle = LifecycleSection:CreateToggle({
	Name = "Lifecycle target",
	Description = "Buttons below mutate its standard lifecycle surface.",
	Callback = function(v) print("Lifecycle target ->", v) end,
})
LifecycleSection:CreateButton({
	Name = "Rename Lifecycle Target",
	Callback = function()
		LifecycleToggle:SetName("Lifecycle Target Updated")
		LifecycleToggle:SetDescription("SetName and SetDescription updated this toggle in place.")
	end,
})
LifecycleSection:CreateButton({
	Name = "Destroy Lifecycle Target",
	Callback = function()
		LifecycleToggle:Destroy()
		Library:Notify({ Title = "Control Destroyed", Text = "Per-control destruction cleaned up the target row." })
	end,
})
LifecycleSection:CreateButton({
	Name = "Disconnect Fly Listener",
	Callback = function()
		dependencyListener:Disconnect()
		Library:Notify({ Title = "Listener Disconnected", Text = "Fly:OnChanged connection cleaned up." })
	end,
})
LifecycleSection:CreateButton({
	Name = "Clear Speed Dependencies",
	Callback = function()
		Speed:ClearDependencies()
		Library:Notify({ Title = "Dependencies Cleared", Text = "Speed now obeys only its manual enabled state." })
	end,
})

Library:Notify({ Title = "Demo loaded", Text = "4 tabs — Main, Visuals, Player, Settings" })
