--[[
	iOS Roblox UI Lib — Test Hub
	Unlike demo.lua (a pure widget showcase — every callback just prints), every control here does
	something real to the local player/character. Built to exercise the library's full surface area:
	Toggle, Slider, Dropdown, MultiDropdown, Input, Keybind, ColorPicker, Button, Label, Paragraph,
	Divider, ProgressBar, ConfigManager, and Section all get used for an actual purpose, not just demonstrated.

	Usage: point PATH at your library.lua (local dev) or swap to game:HttpGet(...) for a hosted copy.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer
if not LocalPlayer.Character then
	LocalPlayer.CharacterAdded:Wait()
end

local PATH = "library.lua" -- adjust for your environment; executor's own workspace, not a real OS path
local Library = loadstring(readfile(PATH))()

-- ================= Dynamic Custom Theme Registration (Tier 2) =================
Library:RegisterTheme("Midnight", {
	BgWindow       = Color3.fromRGB(12, 14, 20),
	BgSheet        = Color3.fromRGB(18, 22, 32),
	BgDock         = Color3.fromRGB(14, 18, 26),
	BgSlot         = Color3.fromRGB(24, 30, 44),
	BgSlotSelected = Color3.fromRGB(36, 46, 68),
	BgCard         = Color3.fromRGB(22, 28, 40),
	BgFrame        = Color3.fromRGB(28, 36, 52),
	BorderSubtle   = Color3.fromRGB(50, 65, 95),
	BorderGlow     = Color3.fromRGB(88, 86, 214),
	TextPrimary    = Color3.fromRGB(240, 244, 255),
	TextSecondary  = Color3.fromRGB(150, 165, 195),
	TextTertiary   = Color3.fromRGB(100, 115, 145),
	AccentBlue     = Color3.fromRGB(88, 86, 214), -- purple glow accent
	AccentRed      = Color3.fromRGB(255, 69, 58),
	Divider        = Color3.fromRGB(40, 52, 75),
	DockBorder     = Color3.fromRGB(50, 65, 95),
	SliderFill     = Color3.fromRGB(88, 86, 214),
})

local Window = Library:CreateWindow({ Name = "Test Hub", Subtitle = "Local Player Cheats" })

-- ================= character-safe accessors =================
-- Every one of these re-reads LocalPlayer.Character live rather than caching it, since the character gets
-- fully replaced (not mutated) on every respawn.
local function getCharacter()
	return LocalPlayer.Character
end
local function getHumanoid()
	local char = getCharacter()
	return char and char:FindFirstChildOfClass("Humanoid")
end
local function getHRP()
	local char = getCharacter()
	return char and char:FindFirstChild("HumanoidRootPart")
end

local DEFAULT_WALKSPEED = 16
local DEFAULT_JUMPPOWER = 50

-- ================= persistent state (re-applied on every respawn, see CharacterAdded below) =================
local state = {
	Color = nil, -- Color3 or nil (no override)
	Material = nil, -- Enum.Material or nil
	WalkSpeedEnabled = false,
	WalkSpeed = DEFAULT_WALKSPEED,
	JumpPowerEnabled = false,
	JumpPower = DEFAULT_JUMPPOWER,
	Flying = false,
	FlySpeed = 50,
	Noclip = false,
	HighlightFill = false,
	HighlightOutline = false,
	HighlightColor = Color3.fromRGB(10, 132, 255),
}

-- ---- color / material ----
local function applyColor()
	local char = getCharacter()
	if not char or not state.Color then
		return
	end
	for _, part in ipairs(char:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Color = state.Color
		end
	end
end

local function applyMaterial()
	local char = getCharacter()
	if not char then
		return
	end
	for _, part in ipairs(char:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Material = state.Material or Enum.Material.Plastic
		end
	end
end

-- ---- highlight overlay ----
local highlight = Instance.new("Highlight")
highlight.Name = "TestHubHighlight"
highlight.FillTransparency = 1
highlight.OutlineTransparency = 1
highlight.FillColor = state.HighlightColor
highlight.OutlineColor = state.HighlightColor
highlight.Enabled = false

local function applyHighlight()
	highlight.FillTransparency = state.HighlightFill and 0.5 or 1
	highlight.OutlineTransparency = state.HighlightOutline and 0 or 1
	highlight.FillColor = state.HighlightColor
	highlight.OutlineColor = state.HighlightColor
	highlight.Enabled = state.HighlightFill or state.HighlightOutline
	local char = getCharacter()
	if char and highlight.Parent ~= char then
		highlight.Parent = char
	end
end

-- ---- walkspeed / jumppower ----
local function applyWalkSpeed()
	local hum = getHumanoid()
	if hum then
		hum.WalkSpeed = state.WalkSpeedEnabled and state.WalkSpeed or DEFAULT_WALKSPEED
	end
end

local function applyJumpPower()
	local hum = getHumanoid()
	if hum then
		hum.JumpPower = state.JumpPowerEnabled and state.JumpPower or DEFAULT_JUMPPOWER
	end
end

-- ---- fly ----
local flyVelocity, flyGyro, flyConn

local function stopFly()
	state.Flying = false
	if flyConn then
		flyConn:Disconnect()
		flyConn = nil
	end
	if flyVelocity then
		flyVelocity:Destroy()
		flyVelocity = nil
	end
	if flyGyro then
		flyGyro:Destroy()
		flyGyro = nil
	end
end

local function startFly()
	local hrp = getHRP()
	if not hrp then
		Library:Notify({ Title = "Fly Failed", Text = "No character/HumanoidRootPart yet", Duration = 3 })
		state.Flying = false
		return
	end
	stopFly()
	state.Flying = true

	flyVelocity = Instance.new("BodyVelocity")
	flyVelocity.Name = "TestHubFlyVelocity"
	flyVelocity.MaxForce = Vector3.new(1, 1, 1) * 1e9
	flyVelocity.Velocity = Vector3.new(0, 0, 0)
	flyVelocity.Parent = hrp

	flyGyro = Instance.new("BodyGyro")
	flyGyro.Name = "TestHubFlyGyro"
	flyGyro.MaxTorque = Vector3.new(1, 1, 1) * 1e9
	flyGyro.P = 3000
	flyGyro.Parent = hrp

	flyConn = RunService.RenderStepped:Connect(function()
		if not state.Flying or getHRP() ~= hrp then
			stopFly()
			return
		end
		local camera = workspace.CurrentCamera
		local move = Vector3.new(0, 0, 0)
		if UserInputService:IsKeyDown(Enum.KeyCode.W) then
			move += camera.CFrame.LookVector
		end
		if UserInputService:IsKeyDown(Enum.KeyCode.S) then
			move -= camera.CFrame.LookVector
		end
		if UserInputService:IsKeyDown(Enum.KeyCode.A) then
			move -= camera.CFrame.RightVector
		end
		if UserInputService:IsKeyDown(Enum.KeyCode.D) then
			move += camera.CFrame.RightVector
		end
		if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
			move += Vector3.new(0, 1, 0)
		end
		if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
			move -= Vector3.new(0, 1, 0)
		end
		if move.Magnitude > 0 then
			move = move.Unit * state.FlySpeed
		end
		flyVelocity.Velocity = move
		flyGyro.CFrame = camera.CFrame
	end)
end

-- ---- noclip ----
local noclipConn

local function setNoclip(enabled)
	state.Noclip = enabled
	if noclipConn then
		noclipConn:Disconnect()
		noclipConn = nil
	end
	if enabled then
		noclipConn = RunService.Stepped:Connect(function()
			local char = getCharacter()
			if not char then
				return
			end
			for _, part in ipairs(char:GetDescendants()) do
				if part:IsA("BasePart") then
					part.CanCollide = false
				end
			end
		end)
	else
		local char = getCharacter()
		if char then
			for _, part in ipairs(char:GetDescendants()) do
				if part:IsA("BasePart") then
					part.CanCollide = true
				end
			end
		end
	end
end

-- ---- re-apply every persistent effect on respawn ----
local healthConn
local updateHealthBar = function() end

LocalPlayer.CharacterAdded:Connect(function()
	stopFly()
	task.wait(0.5)
	applyColor()
	applyMaterial()
	applyHighlight()
	applyWalkSpeed()
	applyJumpPower()
	if state.Noclip then
		setNoclip(true)
	end
	updateHealthBar()
	local hum = getHumanoid()
	if hum then
		if healthConn then healthConn:Disconnect() end
		healthConn = hum.HealthChanged:Connect(updateHealthBar)
	end
end)

-- ================= Character tab: appearance + movement + vitals =================
local Character = Window:CreateTab({ Name = "Character", Icon = "terminal" })

Character:CreateParagraph({
	Title = "Character Telemetry",
	Content = "Active player controls and movement modifiers. Use the sections below to customize your avatar appearance and flight physics.",
})

local Vitals = Character:CreateSection({ Title = "Vitals" })
local healthBar = Vitals:CreateProgressBar({
	Name = "Health",
	CurrentValue = 1,
	Flag = "PlayerHealth",
})

updateHealthBar = function()
	local hum = getHumanoid()
	if hum then
		local maxHp = math.max(hum.MaxHealth, 1)
		local frac = math.clamp(hum.Health / maxHp, 0, 1)
		healthBar:SetProgress(frac, true)
		healthBar:SetText(string.format("%d / %d HP", math.floor(hum.Health + 0.5), math.floor(maxHp + 0.5)))
	end
end

local initHum = getHumanoid()
if initHum then
	updateHealthBar()
	healthConn = initHum.HealthChanged:Connect(updateHealthBar)
end

local Appearance = Character:CreateSection({ Title = "Appearance" })
Appearance:CreateColorPicker({
	Name = "Character Color",
	CurrentColor = Color3.fromRGB(245, 245, 247),
	Flag = "CharColor",
	Callback = function(c)
		state.Color = c
		applyColor()
	end,
})
Appearance:CreateDivider()
Appearance:CreateDropdown({
	Name = "Material",
	Description = "Select or search avatar material",
	Searchable = true,
	MaxVisible = 4,
	Options = { "Default", "Neon", "Glass", "ForceField", "Metal", "Wood", "Ice", "Cobblestone", "Granite", "Brick" },
	CurrentOption = "Default",
	Flag = "CharMaterial",
	Callback = function(v)
		state.Material = (v ~= "Default") and Enum.Material[v] or nil
		applyMaterial()
	end,
})

local Movement = Character:CreateSection({ Title = "Movement" })

local flyToggle = Movement:CreateToggle({
	Name = "Fly",
	Flag = "Fly",
	Callback = function(v)
		if v then
			startFly()
		else
			stopFly()
		end
	end,
})
Movement:CreateSlider({
	Name = "Fly Speed",
	Range = { 10, 200 },
	CurrentValue = 50,
	Flag = "FlySpeed",
	Callback = function(v)
		state.FlySpeed = v
	end,
})
Movement:CreateKeybind({
	Name = "Fly Bind",
	CurrentKeybind = "F",
	Flag = "FlyBind",
	Callback = function()
		flyToggle:Set(not flyToggle:Get())
	end,
})

Movement:CreateDivider()

local noclipToggle = Movement:CreateToggle({
	Name = "Noclip",
	Flag = "Noclip",
	Callback = function(v)
		setNoclip(v)
	end,
})
Movement:CreateKeybind({
	Name = "Noclip Bind",
	CurrentKeybind = "N",
	Flag = "NoclipBind",
	Callback = function()
		noclipToggle:Set(not noclipToggle:Get())
	end,
})

Movement:CreateDivider()

Movement:CreateToggle({
	Name = "Custom WalkSpeed",
	Flag = "WalkSpeedEnabled",
	Callback = function(v)
		state.WalkSpeedEnabled = v
		applyWalkSpeed()
	end,
})
Movement:CreateSlider({
	Name = "WalkSpeed",
	Range = { 16, 300 },
	CurrentValue = DEFAULT_WALKSPEED,
	Flag = "WalkSpeed",
	Callback = function(v)
		state.WalkSpeed = v
		applyWalkSpeed()
	end,
})

Movement:CreateDivider()

Movement:CreateToggle({
	Name = "Custom JumpPower",
	Flag = "JumpPowerEnabled",
	Callback = function(v)
		state.JumpPowerEnabled = v
		applyJumpPower()
	end,
})
Movement:CreateSlider({
	Name = "JumpPower",
	Range = { 50, 300 },
	CurrentValue = DEFAULT_JUMPPOWER,
	Flag = "JumpPower",
	Callback = function(v)
		state.JumpPower = v
		applyJumpPower()
	end,
})

-- ================= Visuals tab: highlight overlay & searchable filters =================
local Visuals = Window:CreateTab({ Name = "Visuals", Icon = "sliders" })

Visuals:CreateLabel({ Text = "Highlight overlay on your own character" })
Visuals:CreateMultiDropdown({
	Name = "Highlight",
	Description = "Search and toggle highlight layers",
	Searchable = true,
	MaxVisible = 3,
	Options = { "Fill", "Outline" },
	CurrentOptions = {},
	Flag = "Highlight",
	Callback = function(list)
		state.HighlightFill = false
		state.HighlightOutline = false
		for _, v in ipairs(list) do
			if v == "Fill" then
				state.HighlightFill = true
			elseif v == "Outline" then
				state.HighlightOutline = true
			end
		end
		applyHighlight()
	end,
})
Visuals:CreateColorPicker({
	Name = "Highlight Color",
	CurrentColor = state.HighlightColor,
	Flag = "HighlightColor",
	Callback = function(c)
		state.HighlightColor = c
		applyHighlight()
	end,
})
Visuals:CreateDivider()
Visuals:CreateButton({
	Name = "Reset Appearance",
	Callback = function()
		state.Color = nil
		state.Material = nil
		state.HighlightFill = false
		state.HighlightOutline = false
		local char = getCharacter()
		if char then
			for _, part in ipairs(char:GetDescendants()) do
				if part:IsA("BasePart") then
					part.Material = Enum.Material.Plastic
					part.Color = Color3.fromRGB(163, 162, 165)
				end
			end
		end
		applyHighlight()
		Library:Notify({ Title = "Appearance Reset", Text = "Color/material/highlight cleared", Duration = 3 })
	end,
})

-- ================= Players tab: live roster with dynamic tab badge =================
local PlayersTab = Window:CreateTab({ Name = "Players", Icon = "stack" })

-- Dynamic Tab Badge for live player count
local function updatePlayersBadge()
	local count = #Players:GetPlayers()
	PlayersTab:SetBadge(count > 0 and count or nil)
end
updatePlayersBadge()

PlayersTab:CreateLabel({ Text = "Every player currently in the server, with their avatar" })

local rebuildPlayerList = function() end
local filterText = ""
PlayersTab:CreateInput({
	Name = "Filter",
	PlaceholderText = "player name...",
	Callback = function(v)
		filterText = v:lower()
		rebuildPlayerList()
	end,
})

local ROW_BG = Color3.fromRGB(35, 35, 37)
local ROW_STROKE = Color3.fromRGB(58, 58, 60)
local TEXT_PRIMARY = Color3.fromRGB(245, 245, 247)
local TEXT_SECONDARY = Color3.fromRGB(142, 142, 147)
local ACCENT_BLUE = Color3.fromRGB(10, 132, 255)

local playerRows = {}

local function clearPlayerRows()
	for _, row in ipairs(playerRows) do
		row:Destroy()
	end
	playerRows = {}
end

local function teleportToPlayer(target)
	local myHRP = getHRP()
	local targetChar = target.Character
	local targetHRP = targetChar and targetChar:FindFirstChild("HumanoidRootPart")
	if not myHRP or not targetHRP then
		Library:Notify({ Title = "Teleport Failed", Text = "Character not available", Duration = 3 })
		return
	end
	myHRP.CFrame = targetHRP.CFrame * CFrame.new(0, 0, 3)
	Library:Notify({ Title = "Teleported", Text = "Teleported to " .. target.Name, Duration = 3 })
end

rebuildPlayerList = function()
	clearPlayerRows()
	local order = 1000
	for _, plr in ipairs(Players:GetPlayers()) do
		if filterText == "" or plr.Name:lower():find(filterText, 1, true) then
			order += 1

			local row = Instance.new("Frame")
			row.Name = "PlayerRow" .. plr.UserId
			row.Size = UDim2.new(1, 0, 0, 44)
			row.BackgroundColor3 = ROW_BG
			row.BackgroundTransparency = 0.5
			row.LayoutOrder = order
			row.Parent = PlayersTab.Page

			local rowCorner = Instance.new("UICorner")
			rowCorner.CornerRadius = UDim.new(0, 12)
			rowCorner.Parent = row
			local rowStroke = Instance.new("UIStroke")
			rowStroke.Color = ROW_STROKE
			rowStroke.Transparency = 0.85
			rowStroke.Thickness = 1
			rowStroke.Parent = row

			local avatar = Instance.new("ImageLabel")
			avatar.Name = "Avatar"
			avatar.AnchorPoint = Vector2.new(0, 0.5)
			avatar.Position = UDim2.new(0, 8, 0.5, 0)
			avatar.Size = UDim2.fromOffset(32, 32)
			avatar.BackgroundColor3 = ROW_BG
			avatar.Image = ""
			avatar.Parent = row
			local avatarCorner = Instance.new("UICorner")
			avatarCorner.CornerRadius = UDim.new(1, 0)
			avatarCorner.Parent = avatar

			task.spawn(function()
				local ok, content = pcall(function()
					return Players:GetUserThumbnailAsync(plr.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
				end)
				if ok and avatar.Parent then
					avatar.Image = content
				end
			end)

			local isLocal = plr == LocalPlayer
			local nameLabel = Instance.new("TextLabel")
			nameLabel.Font = Enum.Font.GothamMedium
			nameLabel.Text = plr.Name .. (isLocal and " (You)" or "")
			nameLabel.TextSize = 13
			nameLabel.TextColor3 = TEXT_PRIMARY
			nameLabel.TextXAlignment = Enum.TextXAlignment.Left
			nameLabel.BackgroundTransparency = 1
			nameLabel.Position = UDim2.new(0, 48, 0, 6)
			nameLabel.Size = UDim2.new(1, -140, 0, 16)
			nameLabel.Parent = row

			local idLabel = Instance.new("TextLabel")
			idLabel.Font = Enum.Font.Gotham
			idLabel.Text = "UserId " .. tostring(plr.UserId)
			idLabel.TextSize = 10
			idLabel.TextColor3 = TEXT_SECONDARY
			idLabel.TextXAlignment = Enum.TextXAlignment.Left
			idLabel.BackgroundTransparency = 1
			idLabel.Position = UDim2.new(0, 48, 0, 22)
			idLabel.Size = UDim2.new(1, -140, 0, 12)
			idLabel.Parent = row

			if not isLocal then
				local teleportBtn = Instance.new("TextButton")
				teleportBtn.AnchorPoint = Vector2.new(1, 0.5)
				teleportBtn.Position = UDim2.new(1, -8, 0.5, 0)
				teleportBtn.Size = UDim2.fromOffset(76, 26)
				teleportBtn.BackgroundColor3 = ACCENT_BLUE
				teleportBtn.AutoButtonColor = false
				teleportBtn.Text = ""
				teleportBtn.Parent = row
				local btnCorner = Instance.new("UICorner")
				btnCorner.CornerRadius = UDim.new(0, 10)
				btnCorner.Parent = teleportBtn
				local btnLabel = Instance.new("TextLabel")
				btnLabel.Font = Enum.Font.GothamMedium
				btnLabel.Text = "Teleport"
				btnLabel.TextSize = 11
				btnLabel.TextColor3 = TEXT_PRIMARY
				btnLabel.BackgroundTransparency = 1
				btnLabel.Size = UDim2.fromScale(1, 1)
				btnLabel.Parent = teleportBtn
				teleportBtn.MouseButton1Click:Connect(function()
					teleportToPlayer(plr)
				end)
			end

			table.insert(playerRows, row)
		end
	end
end

rebuildPlayerList()
Players.PlayerAdded:Connect(function()
	rebuildPlayerList()
	updatePlayersBadge()
end)
Players.PlayerRemoving:Connect(function()
	rebuildPlayerList()
	updatePlayersBadge()
end)

-- ================= Settings tab: theme, reactive accents, menu toggle, config =================
local Settings = Window:CreateTab({ Name = "Settings", Icon = "dot" })

Settings:CreateLabel({ Text = "Floating button (bottom-right of screen) drags freely; tap it to hide/show the whole menu" })
Settings:CreateKeybind({
	Name = "Toggle Menu",
	CurrentKeybind = "RightControl",
	Flag = "MenuToggleBind",
	Callback = function()
		Window:ToggleVisible()
	end,
})

local NavSection = Settings:CreateSection({ Title = "Quick Navigation" })
NavSection:CreateButton({
	Name = "View Player Roster",
	Callback = function()
		Window:SetActiveTab("Players")
	end,
})

local ThemeSection = Settings:CreateSection({ Title = "Theme & Customization" })
ThemeSection:CreateDropdown({
	Name = "Theme",
	Options = { "Dark", "Light", "Midnight" },
	CurrentOption = "Dark",
	Callback = function(v)
		Library:SetTheme(v)
	end,
})
ThemeSection:CreateDropdown({
	Name = "Accent Color",
	Options = { "iOS Blue", "Purple Glow", "Emerald Green", "Sunset Orange", "Hot Pink" },
	CurrentOption = "iOS Blue",
	Callback = function(choice)
		if choice == "iOS Blue" then
			Library:SetAccent(Color3.fromRGB(10, 132, 255))
		elseif choice == "Purple Glow" then
			Library:SetAccent(Color3.fromRGB(88, 86, 214))
		elseif choice == "Emerald Green" then
			Library:SetAccent(Color3.fromRGB(52, 199, 89))
		elseif choice == "Sunset Orange" then
			Library:SetAccent(Color3.fromRGB(255, 149, 0))
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

Library:Notify({ Title = "Test Hub Loaded", Text = "4 tabs — Character, Visuals, Players, Settings" })
