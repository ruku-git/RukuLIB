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

local Window = Library:CreateWindow({ Name = "iOS Exploit", Subtitle = "Premium Suite — Full Demo" })

-- ================= Main: toggle / slider / dropdown / button =================
local Main = Window:CreateTab({ Name = "Main", Icon = "terminal" })

Main:CreateLabel({ Text = "Core widgets — Toggle, Slider, Dropdown, Button" })
Main:CreateToggle({
	Name = "Fly Hack",
	Flag = "FlyHack",
	Callback = function(v) print("Fly Hack ->", v) end,
})
Main:CreateSlider({
	Name = "Speed",
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
Main:CreateButton({
	Name = "Test Button",
	Callback = function() print("Test Button fired") end,
})

-- ================= Visuals: MultiDropdown / ColorPicker =================
-- ColorPicker deliberately placed low in a short list here — this is the exact layout shape that
-- originally clipped past the sheet's bottom edge (bug found via user screenshot), so this tab doubles
-- as a live regression check for `positionFlyout`'s clip-avoidance.
local Visuals = Window:CreateTab({ Name = "Visuals", Icon = "sliders" })

Visuals:CreateLabel({ Text = "MultiDropdown + ColorPicker (flyouts, Overlay-parented)" })
Visuals:CreateMultiDropdown({
	Name = "ESP",
	Options = { "Boxes", "Names", "Tracers", "Health" },
	CurrentOptions = { "Boxes" },
	Flag = "ESP",
	Callback = function(list) print("ESP ->", table.concat(list, ", ")) end,
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
Player:CreateKeybind({
	Name = "Fly Bind",
	CurrentKeybind = "F",
	Flag = "FlyBind",
	Callback = function() print("Fly Bind pressed") end,
	ChangedCallback = function(k) print("Fly Bind rebound ->", k) end,
})

-- ================= Settings: theme, notify, floating button, config save/load =================
local Settings = Window:CreateTab({ Name = "Settings", Icon = "dot" })

Settings:CreateLabel({ Text = "Window drag: try dragging the header up top" })
Settings:CreateLabel({ Text = "Floating button (bottom-right of screen) drags freely; tap it to hide/show the whole menu" })
Settings:CreateButton({
	Name = "Theme: Dark",
	Callback = function() Library:SetTheme("Dark") end,
})
Settings:CreateButton({
	Name = "Theme: Light",
	Callback = function() Library:SetTheme("Light") end,
})
Settings:CreateKeybind({
	Name = "Toggle Menu",
	CurrentKeybind = "RightControl",
	Flag = "MenuToggleBind", -- Flag'd like any other widget, so the chosen bind itself round-trips through
	-- Library:SaveConfig/LoadConfig automatically — no special-case code needed for "a keybind in the config"
	Callback = function() Window:ToggleVisible() end,
	ChangedCallback = function(k) print("Menu toggle rebound ->", k) end,
})
Settings:CreateConfigManager({
	DefaultName = "default",
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
