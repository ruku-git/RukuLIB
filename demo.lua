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
Main:CreateToggle({
	Name = "Fly Hack",
	Flag = "FlyHack",
	Callback = function(v) print("Fly Hack ->", v) end,
})
Main:CreateSlider({
	Name = "Speed (Click-to-Edit)",
	Range = { 16, 200 },
	CurrentValue = 16,
	Flag = "Speed",
	Callback = function(v) print("Speed ->", v) end,
})
Main:CreateDropdown({
	Name = "Mode",
	Options = { "Walk", "Noclip", "God" },
	CurrentOption = "Walk",
	Flag = "Mode",
	Callback = function(v) print("Mode ->", v) end,
})

Main:CreateDivider()

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

Visuals:CreateMultiDropdown({
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

Visuals:CreateColorPicker({
	Name = "Aura Color",
	CurrentColor = Color3.fromRGB(10, 132, 255),
	Flag = "AuraColor",
	Callback = function(c) print("Aura Color ->", c) end,
})

-- ================= Player: Input / Keybind =================
local Player = Window:CreateTab({ Name = "Player", Icon = "stack" })

Player:CreateLabel({ Text = "Text input + keybind capture" })
Player:CreateInput({
	Name = "Target Player",
	PlaceholderText = "username",
	Flag = "TargetPlayer",
	Callback = function(v) print("Target Player ->", v) end,
})
Player:CreateDivider()
Player:CreateKeybind({
	Name = "Fly Bind",
	CurrentKeybind = "F",
	Flag = "FlyBind",
	Callback = function() print("Fly Bind pressed") end,
	ChangedCallback = function(k) print("Fly Bind rebound ->", k) end,
})

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

Library:Notify({ Title = "Demo loaded", Text = "4 tabs — Main, Visuals, Player, Settings" })
