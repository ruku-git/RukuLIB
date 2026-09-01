--[[
	iOS Roblox UI Lib
	Rayfield-Gen2-shaped developer API, Apple HIG dark-mode + glassmorphism skin.
	Built entirely from Instance.new — no models, no asset dependencies.
	Tokens (color / radius / spacing / motion) mirror MASTER.md 1:1.

	local UI = loadstring(game:HttpGet("..."))()
	local Window = UI:CreateWindow({Name = "iOS Exploit", Subtitle = "Premium Suite"}) -- drag by the header to move it, drag the bottom-right corner grip to resize (400x280 to 900x700)
	local Tab = Window:CreateTab({Name = "Main", Icon = 12345})
	Tab:CreateToggle({Name = "Fly Hack", Flag = "FlyHack", Callback = function(v) print(v) end})
	local speedSlider = Tab:CreateSlider({Name = "Speed", Range = {16, 200}, CurrentValue = 16, Flag = "Speed", Callback = function(v) end})
	local modeDropdown = Tab:CreateDropdown({Name = "Mode", Options = {"Walk", "Noclip"}, Flag = "Mode", Callback = function(v) end})
	Tab:CreateMultiDropdown({Name = "ESP", Options = {"Boxes", "Names"}, Flag = "ESP", Callback = function(list) end})
	Tab:CreateInput({Name = "Player", PlaceholderText = "username", Flag = "Player", Callback = function(v) end})
	Tab:CreateKeybind({Name = "Fly Bind", CurrentKeybind = "F", Flag = "FlyBind", Callback = function() end})
	Tab:CreateColorPicker({Name = "Aura Color", CurrentColor = Color3.new(1, 0, 0), Flag = "AuraColor", Callback = function(c) end})
	Tab:CreateButton({Name = "Test Button", Callback = function() end})
	Tab:CreateKeybind({Name = "Toggle Menu", CurrentKeybind = "RightControl", Flag = "MenuToggleBind",
		Callback = function() Window:ToggleVisible() end}) -- Flag'd, so the bind itself persists via SaveConfig
	Tab:CreateDivider() -- 1px visual separator, cheaper than a full CreateSection
	local progress = Tab:CreateProgressBar({Name = "Download", CurrentValue = 0}) -- display-only, no Flag
	progress:SetProgress(0.4) -- 0-1; :SetText("12.4 / 80 MB") to override the auto "%" readout

	-- every widget above shares this lifecycle: control:SetVisible(bool), control:SetEnabled(bool) (dims +
	-- blocks input, doesn't just ignore the value), control:SetName(str), control:SetDescription(str) (no-op
	-- on a widget with no label/description slot — Button/Label/Slider), control:Destroy() (tears down just
	-- this row, unregisters its Flag). Every control table also carries a `.Type` string (e.g. "Toggle",
	-- "Slider") so host code can branch on widget kind without inspecting method signatures.
	speedSlider:SetEnabled(false) -- e.g. grey out until some other toggle turns the feature on
	-- (in-app: clicking a slider's own value label turns it into a TextBox for typing an exact number)
	modeDropdown:Refresh({"Walk", "Noclip", "Fly"}) -- Dropdown/MultiDropdown only: swap the option list live
	Library:GetControl("Speed") -- same object as Library.Flags["Speed"], but warns on a typo'd/missing Flag

	local Config = Tab:CreateSection({Title = "Config"}) -- groups widgets under one titled card
	Config:CreateConfigManager() -- [Save Config][name box], [Load Config][selection box] (flyout of saved configs)

	Library:Notify({Title = "Loaded", Text = "Script ready"})
	Library:SetTheme("Light") -- or "Dark", or a raw {BgFrame = Color3...} table for a fully custom palette
	Library:SaveConfig("default") -- writes every Flag'd control's current value to IOSRobloxUILib_Configs/default.json
	Library:LoadConfig("default") -- reads it back and re-applies (fires each control's Callback too)
	Window:ToggleVisible() -- show/hide the whole window; also driven by the draggable floating button and any Keybind wired to it
	Library:Destroy() -- or Window:Destroy() — full teardown: connections, ThemeListeners, Flags, the GUI itself
]]

local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")

local LocalPlayer = Players.LocalPlayer

-- ================= TOKENS (MASTER.md) =================

local Colors = {
	BgBase        = Color3.fromRGB(11, 11, 12),
	BgFrame       = Color3.fromRGB(28, 28, 30),
	BgDock        = Color3.fromRGB(20, 20, 22),
	BgCard        = Color3.fromRGB(35, 35, 37),
	BgEditor      = Color3.fromRGB(11, 11, 12),
	BorderSubtle  = Color3.fromRGB(58, 58, 60),
	TextPrimary   = Color3.fromRGB(245, 245, 247),
	TextSecondary = Color3.fromRGB(142, 142, 147),
	TextTertiary  = Color3.fromRGB(99, 99, 102),
	AccentBlue    = Color3.fromRGB(10, 132, 255),
	AccentGreen   = Color3.fromRGB(52, 199, 89),
	AccentRed     = Color3.fromRGB(255, 69, 58),
	AccentOrange  = Color3.fromRGB(255, 159, 10),
}

local Radius = {
	Sheet = 20,
	Card  = 14,
	Slot  = 10,
	Pill  = 999,
}

local Spacing = {
	SheetPadV  = 16,
	SheetPadH  = 22,
	EditorPad  = 12,
	RowGap     = 8,
	DockWidth  = 64,
	SlotSize   = 32,
}

local WindowSize = Vector2.new(550, 350)
-- Bounds for the drag-to-resize handle (bottom-right corner of the sheet). Min keeps the dock (64px) plus
-- enough content width/height to still be usable rather than degenerating into a sliver; max is generous
-- but not "grows to fill the phone screen" — same "no clamping against the actual screen" precedent as the
-- window/float-button drag already sets, just bounded on the size axis instead of the position one.
local WindowMinSize = Vector2.new(400, 280)
local WindowMaxSize = Vector2.new(900, 700)

local Motion = {
	Open   = TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
	Tab    = TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
	Toggle = TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut),
	Hover  = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
	Press  = TweenInfo.new(0.10, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
}

local Fonts = {
	Title    = Enum.Font.GothamMedium,
	Caption  = Enum.Font.Gotham,
	Body     = Enum.Font.GothamMedium,
	SubBody  = Enum.Font.Gotham,
	Code     = Enum.Font.Code,
}

-- ================= HELPERS =================

local function new(class, props, children)
	local inst = Instance.new(class)
	for prop, value in pairs(props or {}) do
		if prop ~= "Parent" then
			inst[prop] = value
		end
	end
	for _, child in ipairs(children or {}) do
		child.Parent = inst
	end
	if props and props.Parent then
		inst.Parent = props.Parent
	end
	return inst
end

local function corner(parent, radius)
	return new("UICorner", { CornerRadius = UDim.new(0, radius), Parent = parent })
end

local function stroke(parent, transparency, thickness)
	return new("UIStroke", {
		Color = Color3.new(1, 1, 1),
		Transparency = transparency or 0.9,
		Thickness = thickness or 1,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = parent,
	})
end

local function pad(parent, all, top, right, bottom, left)
	return new("UIPadding", {
		PaddingTop = UDim.new(0, top or all or 0),
		PaddingRight = UDim.new(0, right or all or 0),
		PaddingBottom = UDim.new(0, bottom or all or 0),
		PaddingLeft = UDim.new(0, left or all or 0),
		Parent = parent,
	})
end

local function tween(obj, info, props)
	local tw = TweenService:Create(obj, info, props)
	tw:Play()
	return tw
end

-- ================= THEME =================
-- `Colors` above is a single shared table every widget reads from. Two ways code stays theme-reactive
-- after `Library:SetTheme` mutates it: (1) code that RE-READS Colors.X at event-time (tween callbacks,
-- click handlers) already picks up new values for free on the next interaction — no registration needed.
-- (2) static values baked in once at creation (a row's idle background, a label's idle text color) need
-- to be told to re-apply. `onTheme` registers a closure for case (2); `themed` is a convenience wrapper
-- for the common "just re-set one property from one Colors key" shape. Registered closures are pruned
-- lazily (skipped, not removed) if their instance is gone — fine for a UI library's lifetime.
local ThemeListeners = {}

-- Every lifecycle-attached control is registered weakly so full window teardown can invalidate
-- dependency graphs even when the host script still holds a reference to an old control table.
local ControlRegistry = setmetatable({}, { __mode = "k" })
local clearControlDependencies

local function onTheme(fn)
	table.insert(ThemeListeners, fn)
	return fn
end

local function themed(inst, prop, key)
	onTheme(function()
		if inst and inst.Parent then
			inst[prop] = Colors[key]
		end
	end)
	return inst
end

-- Every `UserInputService.Input*:Connect` in this file (window drag, floating-button drag, slider drag,
-- keybind listener, color picker drag) is service-level, not tied to any per-widget Instance — destroying
-- the widget/window that created one does NOT disconnect it, since `UserInputService` itself outlives
-- everything. Left unaddressed, re-running `CreateWindow` (which this project's own dev loop does
-- constantly) stacks a brand new set of these on every run: a keybind fires once per stacked connection,
-- every drag delta applies once per stacked connection, etc. `trackConnection` records every one of them
-- so `CreateWindow` (see below) can disconnect the previous run's entire set before building a new one —
-- consistent with this library's existing "re-running CreateWindow replaces, never stacks" design intent.
--
-- A plain `local` here only covers CreateWindow being called twice against the SAME loaded Library
-- instance — it does nothing for the far more common case of the whole script being re-executed from
-- scratch (pressing "Execute" again), since a fresh `loadstring(...)()` call creates a brand new chunk
-- with its own empty `GlobalConnections`, with no Lua-level reference back to the PREVIOUS execution's
-- connections at all. Those old connections don't care that the script that made them is gone, though —
-- they live on UserInputService's own signal, not in anything the new execution can reach or garbage-
-- collect. `getgenv()` (a standard executor API for exactly this: state that survives a fresh script load,
-- unlike ordinary Lua locals/globals) lets a new execution find and disconnect the previous one's list.
-- Falls back to a plain local (same as before) on an executor without `getgenv()` — same-instance cleanup
-- still works, cross-execution cleanup just can't.
local genvOk, genv = pcall(getgenv)
if not genvOk or type(genv) ~= "table" then
	genv = {}
end
if genv.__IOSRobloxUILibConnections then
	for _, conn in ipairs(genv.__IOSRobloxUILibConnections) do
		pcall(function()
			conn:Disconnect()
		end)
	end
end
genv.__IOSRobloxUILibConnections = {}
local GlobalConnections = genv.__IOSRobloxUILibConnections

local function trackConnection(conn)
	table.insert(GlobalConnections, conn)
	return conn
end

-- Clears IN PLACE (never rebinds `GlobalConnections` to a new table) so the local upvalue and
-- `genv.__IOSRobloxUILibConnections` stay the exact same table for the rest of this execution's lifetime —
-- a rebind here would silently break the cross-execution lookup above for whatever runs after this one.
local function clearGlobalConnections()
	for _, conn in ipairs(GlobalConnections) do
		pcall(function()
			conn:Disconnect()
		end)
	end
	for i = #GlobalConnections, 1, -1 do
		GlobalConnections[i] = nil
	end
end

-- ================= ICONS (vector, zero-asset) =================

local function iconCanvas(parent)
	return new("Frame", {
		Name = "Icon",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(16, 16),
		BackgroundTransparency = 1,
		Parent = parent,
	})
end

local function tintIcon(container, color)
	local function apply(inst)
		if inst:IsA("Frame") and inst.Name ~= "IconTrack" then
			tween(inst, Motion.Tab, { BackgroundColor3 = color })
		elseif inst:IsA("ImageLabel") then
			tween(inst, Motion.Tab, { ImageColor3 = color })
		elseif inst:IsA("UIStroke") then
			tween(inst, Motion.Tab, { Color = color })
		end
	end
	apply(container)
	for _, descendant in ipairs(container:GetDescendants()) do
		apply(descendant)
	end
end

-- Hand-built minimalist glyphs: one stroke weight, no fill flourish, no emoji.
local IconBuilders = {}

IconBuilders.terminal = function(parent, color) -- Executor: console screen + cursor
	local canvas = iconCanvas(parent)
	local screen = new("Frame", {
		Size = UDim2.fromOffset(12, 9),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		BackgroundTransparency = 1,
		Parent = canvas,
	})
	corner(screen, 2)
	stroke(screen, 0, 1.4)
	new("Frame", {
		Name = "Cursor",
		Size = UDim2.fromOffset(4, 1.6),
		Position = UDim2.fromOffset(2, 6),
		BackgroundColor3 = color,
		Parent = screen,
	})
	return canvas
end

IconBuilders.stack = function(parent, color) -- Script Hub: stacked list bars
	local canvas = iconCanvas(parent)
	for i = 0, 2 do
		local bar = new("Frame", {
			Name = "Bar" .. i,
			Size = UDim2.fromOffset(12, 1.6),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 0.5, (i - 1) * 4.5),
			BackgroundColor3 = color,
			Parent = canvas,
		})
		corner(bar, 1)
	end
	return canvas
end

IconBuilders.sliders = function(parent, color) -- Settings: adjustment tracks + knobs
	local canvas = iconCanvas(parent)
	local knobOffsets = { -3, 2, -2 }
	for i = 0, 2 do
		local y = (i - 1) * 5
		local track = new("Frame", {
			Name = "IconTrack",
			Size = UDim2.fromOffset(12, 1.4),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 0.5, y),
			BackgroundColor3 = Colors.BorderSubtle,
			Parent = canvas,
		})
		corner(track, 1)
		local knob = new("Frame", {
			Size = UDim2.fromOffset(3.5, 3.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, knobOffsets[i + 1], 0.5, y),
			BackgroundColor3 = color,
			Parent = canvas,
		})
		corner(knob, Radius.Pill)
	end
	return canvas
end

IconBuilders.dot = function(parent, color) -- fallback: neutral marker
	local canvas = iconCanvas(parent)
	local dot = new("Frame", {
		Size = UDim2.fromOffset(6, 6),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		BackgroundColor3 = color,
		Parent = canvas,
	})
	corner(dot, Radius.Pill)
	return canvas
end

IconBuilders.gear = function(parent, color) -- Settings: compact hand-built cog
	local canvas = iconCanvas(parent)
	for i = 0, 7 do
		local angle = math.rad(i * 45)
		local tooth = new("Frame", {
			Size = UDim2.fromOffset(3, 5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, math.sin(angle) * 5.5, 0.5, -math.cos(angle) * 5.5),
			Rotation = i * 45,
			BackgroundColor3 = color,
			BorderSizePixel = 0,
			Parent = canvas,
		})
	end
	local ring = new("Frame", {
		Size = UDim2.fromOffset(11, 11),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		Parent = canvas,
	})
	corner(ring, Radius.Pill)
	local cutout = new("Frame", {
		Size = UDim2.fromOffset(5, 5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		BackgroundColor3 = Colors.BgDock,
		BorderSizePixel = 0,
		Parent = ring,
	})
	corner(cutout, Radius.Pill)
	return canvas
end

-- iconConfig: nil -> dot fallback | number -> rbxassetid image | string -> named vector glyph
local function buildIcon(parent, iconConfig, color)
	if typeof(iconConfig) == "number" then
		return new("ImageLabel", {
			Name = "Icon",
			Image = "rbxassetid://" .. tostring(iconConfig),
			BackgroundTransparency = 1,
			Size = UDim2.fromOffset(15, 15),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			ImageColor3 = color,
			Parent = parent,
		})
	end
	local builder = IconBuilders[iconConfig] or IconBuilders.dot
	return builder(parent, color)
end

local function getGuiParent()
	local ok, hidden = pcall(function()
		return gethui()
	end)
	if ok and hidden then
		return hidden
	end
	local ok2, core = pcall(function()
		return game:GetService("CoreGui")
	end)
	if ok2 and core then
		return core
	end
	return LocalPlayer:WaitForChild("PlayerGui")
end

local function protect(gui)
	local ok = pcall(function()
		syn.protect_gui(gui)
	end)
	if not ok then
		pcall(function()
			gui.Parent = getGuiParent()
		end)
	end
end

-- ================= LIBRARY =================

local Library = {}
Library.__index = Library
Library.Flags = {} -- Flag name -> control object ({Set, Get}), populated by any widget given a `Flag` field
Library.Themes = { Dark = {} }
for key, value in pairs(Colors) do
	Library.Themes.Dark[key] = value -- snapshot the built-in palette so `SetTheme("Dark")` can restore it
end
Library.Themes.Light = {
	BgBase        = Color3.fromRGB(242, 242, 247),
	BgFrame       = Color3.fromRGB(255, 255, 255),
	BgDock        = Color3.fromRGB(235, 235, 240),
	BgCard        = Color3.fromRGB(246, 246, 248),
	BgEditor      = Color3.fromRGB(255, 255, 255),
	BorderSubtle  = Color3.fromRGB(210, 210, 214),
	TextPrimary   = Color3.fromRGB(20, 20, 22),
	TextSecondary = Color3.fromRGB(90, 90, 95),
	TextTertiary  = Color3.fromRGB(140, 140, 145),
	AccentBlue    = Color3.fromRGB(0, 122, 255),
	AccentGreen   = Color3.fromRGB(48, 179, 80),
	AccentRed     = Color3.fromRGB(255, 59, 48),
	AccentOrange  = Color3.fromRGB(255, 149, 0),
}

-- Merges a theme (by name from Library.Themes, or a raw {Key = Color3} table for a fully custom
-- palette) into the shared Colors table, then re-runs every registered `onTheme` closure so already-built
-- UI updates in place — no window recreation needed. Anything a widget set up via `themed()`/`onTheme`
-- picks this up; a handful of things intentionally never call `Colors` again after creation (e.g. a
-- color picker's own hue/saturation swatches, which are HSV-driven, not theme-driven) and are unaffected.
function Library:SetTheme(theme)
	local resolved = theme
	if typeof(theme) == "string" then
		resolved = self.Themes[theme]
		if not resolved then
			warn("[iOSRobloxUILib] SetTheme: unknown theme name '" .. tostring(theme) .. "'")
			return
		end
	end
	for key, value in pairs(resolved or {}) do
		Colors[key] = value
	end
	for _, fn in ipairs(ThemeListeners) do
		pcall(fn)
	end
end

-- Registers a custom theme preset into Library.Themes so it can be activated anytime via Library:SetTheme(name).
-- Any tokens omitted from the custom `tokens` table automatically fallback to the built-in Dark theme palette.
function Library:RegisterTheme(name, tokens)
	if typeof(name) ~= "string" or typeof(tokens) ~= "table" then
		warn("[iOSRobloxUILib] RegisterTheme: name must be a string and tokens must be a table")
		return
	end
	local newTheme = {}
	for k, v in pairs(self.Themes.Dark) do
		newTheme[k] = v
	end
	for k, v in pairs(tokens) do
		newTheme[k] = v
	end
	self.Themes[name] = newTheme
	return self
end

-- Dynamically mutates the library's primary accent color token (Colors.AccentBlue) and broadcasts
-- the change to all registered UI theme listeners across all open widgets and tabs in real time.
function Library:SetAccent(color)
	if typeof(color) ~= "Color3" then
		warn("[iOSRobloxUILib] SetAccent: expected Color3, got " .. typeof(color))
		return
	end
	Colors.AccentBlue = color
	for _, fn in ipairs(ThemeListeners) do
		pcall(fn)
	end
end

-- Config files are named (not one fixed file) so a script can offer multiple saved presets — see
-- Library:ListConfigs / CreateConfigManager below. All live under one folder in the executor's own
-- sandboxed workspace (same writefile/readfile sandboxing note as everywhere else here, not a real OS path).
Library.ConfigFolder = "IOSRobloxUILib_Configs"

local function ensureConfigFolder()
	local ok = pcall(function()
		if not isfolder(Library.ConfigFolder) then
			makefolder(Library.ConfigFolder)
		end
	end)
	return ok
end

-- Strips anything that isn't filename-safe, so a typed name can't escape the config folder (e.g. a stray
-- "../") or trip an executor's writefile/readfile on an unexpected character. Falls back to "config" for
-- an empty/all-stripped name so Save never silently no-ops on a blank TextBox.
local function sanitizeConfigName(name)
	name = tostring(name or ""):gsub("[^%w%s%-_]", ""):gsub("^%s+", ""):gsub("%s+$", "")
	if name == "" then
		name = "config"
	end
	return name
end

-- Serializes every flagged control's current value to a named JSON file under Library.ConfigFolder. Color3
-- values aren't native JSON types, so they're wrapped as {__color3=true, R=,G=,B=} and unwrapped on load.
function Library:SaveConfig(name)
	name = sanitizeConfigName(name or "default")
	ensureConfigFolder()
	local path = Library.ConfigFolder .. "/" .. name .. ".json"
	local data = {}
	for flag, control in pairs(self.Flags) do
		local ok, value = pcall(function()
			return control:Get()
		end)
		if ok then
			if typeof(value) == "Color3" then
				data[flag] = { __color3 = true, R = value.R, G = value.G, B = value.B }
			else
				data[flag] = value
			end
		end
	end
	local ok, encoded = pcall(function()
		return HttpService:JSONEncode(data)
	end)
	if not ok then
		return false, "JSONEncode failed: " .. tostring(encoded)
	end
	local ok2, err = pcall(function()
		writefile(path, encoded)
	end)
	if not ok2 then
		return false, "writefile failed: " .. tostring(err)
	end
	return true, name
end

-- Reads a named config's JSON file back and calls :Set on every flagged control that has a matching key.
-- Silently skips flags with no live control (e.g. config was saved by a script version with more widgets)
-- and flags whose Set errors (e.g. a stale value out of a slider's current Range) rather than aborting.
function Library:LoadConfig(name)
	name = sanitizeConfigName(name or "default")
	local path = Library.ConfigFolder .. "/" .. name .. ".json"
	local ok, raw = pcall(function()
		return readfile(path)
	end)
	if not ok or not raw then
		return false, "no config file (readfile failed): " .. tostring(raw)
	end
	local ok2, data = pcall(function()
		return HttpService:JSONDecode(raw)
	end)
	if not ok2 then
		return false, "JSONDecode failed: " .. tostring(data)
	end
	for flag, value in pairs(data) do
		local control = self.Flags[flag]
		if control then
			if typeof(value) == "table" and value.__color3 then
				pcall(function()
					control:Set(Color3.new(value.R, value.G, value.B))
				end)
			else
				pcall(function()
					control:Set(value)
				end)
			end
		end
	end
	return true, name
end

-- Lists saved config names (extension stripped), sorted alphabetically — feeds CreateConfigManager's
-- "load" flyout. Returns {} (never errors) if the folder doesn't exist yet or listfiles isn't available.
function Library:ListConfigs()
	if not ensureConfigFolder() then
		return {}
	end
	local ok, files = pcall(function()
		return listfiles(Library.ConfigFolder)
	end)
	if not ok or not files then
		return {}
	end
	local names = {}
	for _, full in ipairs(files) do
		local fname = full:match("([^/\\]+)$")
		local nameOnly = fname and fname:match("^(.*)%.json$")
		if nameOnly then
			table.insert(names, nameOnly)
		end
	end
	table.sort(names)
	return names
end

-- Deletes one saved config file by name. Used by CreateConfigManager's per-row delete affordance.
function Library:DeleteConfig(name)
	name = sanitizeConfigName(name or "")
	local path = Library.ConfigFolder .. "/" .. name .. ".json"
	-- Some executors' delfile silently no-ops on a path that was never there instead of erroring, which
	-- used to let this function claim `true` (success) for a delete that never happened. Checking isfile
	-- first makes the return value actually mean "something was deleted" — if isfile itself isn't
	-- available (checkOk false), fall through to the old behavior rather than blocking the delete attempt.
	local checkOk, existed = pcall(function()
		return isfile(path)
	end)
	if checkOk and not existed then
		return false, "no such config: " .. name
	end
	local ok, err = pcall(function()
		delfile(path)
	end)
	if not ok then
		return false, "delfile failed: " .. tostring(err)
	end
	return true
end

-- Look up a control by its Flag name. Returns the control table (or nil if not found, with a warning).
function Library:GetControl(flagName)
	local control = self.Flags[flagName]
	if not control then
		warn("[iOSRobloxUILib] GetControl: no control registered under Flag '" .. tostring(flagName) .. "'")
	end
	return control
end

-- ---- toast notifications ----
-- Lazily-created top-level ScreenGui, independent of any Window, since Notify can be called before
-- CreateWindow or to surface something outside the window entirely. Toasts stack bottom-right; the
-- stack Frame is anchored (1,1) with AutomaticSize.Y, so as it grows the stack's bottom-right corner
-- stays pinned to the screen corner and it grows upward — oldest toast at top, newest at the bottom.
local notifyGui, notifyStack, notifyCounter = nil, nil, 0

local function ensureNotifyLayer()
	if notifyStack and notifyStack.Parent then
		return notifyStack
	end
	-- `notifyGui`/`notifyStack` are plain locals, so a full script re-execution (fresh `loadstring()`, this
	-- project's own normal dev loop) starts them at nil with no idea a previous execution's toast layer is
	-- still sitting in `guiParent` under the same name — unlike "IOSRobloxUILib" itself, which CreateWindow
	-- already finds-and-destroys by name for exactly this reason. Left unfixed, every re-execution left
	-- behind one more orphaned (if empty, since toasts self-destruct) "IOSRobloxUILibNotify" ScreenGui.
	local guiParent = getGuiParent()
	local existing = guiParent:FindFirstChild("IOSRobloxUILibNotify")
	if existing then
		existing:Destroy()
	end
	notifyGui = new("ScreenGui", {
		Name = "IOSRobloxUILibNotify",
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Global,
		DisplayOrder = 1000, -- above the main window (999) so a toast is never hidden behind it
		Parent = guiParent,
	})
	protect(notifyGui)
	notifyStack = new("Frame", {
		Name = "Stack",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -16, 1, -16),
		Size = UDim2.fromOffset(260, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Parent = notifyGui,
	})
	new("UIListLayout", {
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 8),
		Parent = notifyStack,
	})
	return notifyStack
end

local function fadeOutAndDestroy(inst, info)
	tween(inst, info, { BackgroundTransparency = 1 })
	for _, d in ipairs(inst:GetDescendants()) do
		if d:IsA("TextLabel") then
			tween(d, info, { TextTransparency = 1 })
		elseif d:IsA("UIStroke") then
			tween(d, info, { Transparency = 1 })
		end
	end
	task.delay(info.Time, function()
		if inst then
			inst:Destroy()
		end
	end)
end

function Library:Notify(config)
	config = config or {}
	local title = config.Title or ""
	local text = config.Text or ""
	local duration = config.Duration or 4

	local stack = ensureNotifyLayer()
	notifyCounter += 1

	local toast = new("Frame", {
		Name = "Toast",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Colors.BgCard,
		BackgroundTransparency = 1, -- tweened in below
		ClipsDescendants = true,
		LayoutOrder = notifyCounter,
		Parent = stack,
	})
	themed(toast, "BackgroundColor3", "BgCard")
	corner(toast, Radius.Card)
	stroke(toast, 0.85, 1)
	pad(toast, nil, 10, 12, 10, 12)
	new("UIListLayout", {
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 2),
		Parent = toast,
	})

	if title ~= "" then
		local titleLabel = new("TextLabel", {
			Font = Fonts.Body,
			Text = title,
			TextSize = 13,
			TextColor3 = Colors.TextPrimary,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextWrapped = true,
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 16),
			LayoutOrder = 1,
			Parent = toast,
		})
		themed(titleLabel, "TextColor3", "TextPrimary")
	end
	if text ~= "" then
		local textLabel = new("TextLabel", {
			Font = Fonts.SubBody,
			Text = text,
			TextSize = 11,
			TextColor3 = Colors.TextSecondary,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextWrapped = true,
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			LayoutOrder = 2,
			Parent = toast,
		})
		themed(textLabel, "TextColor3", "TextSecondary")
	end

	tween(toast, Motion.Open, { BackgroundTransparency = 0.05 })

	task.delay(duration, function()
		if toast and toast.Parent then
			fadeOutAndDestroy(toast, Motion.Tab)
		end
	end)

	return toast
end

local WindowMeta = {}
WindowMeta.__index = WindowMeta

local TabMeta = {}
TabMeta.__index = TabMeta

-- Defined after attachLifecycle so it can call each control's cleanup method, but CreateWindow is defined
-- earlier in this source. Install a harmless no-op now; attachLifecycle replaces it before any public
-- CreateWindow call can run.
clearControlDependencies = function() end

function Library:CreateWindow(config)
	config = config or {}
	local windowName = config.Name or "Window"
	local subtitle = config.Subtitle or ""

	local guiParent = getGuiParent()
	-- Invalidate retained control tables before tearing down their rows/flyouts, so relationship cleanup
	-- never tries to repaint an Instance that has already been destroyed.
	clearControlDependencies()
	for _, child in ipairs(guiParent:GetChildren()) do
		if child.Name == "IOSRobloxUILib" then
			child:Destroy() -- re-running CreateWindow (e.g. re-executing the script) replaces, never stacks
		end
	end

	-- The three lines below make that same "replaces, never stacks" promise actually hold for everything
	-- that ISN'T a child Instance (so `:Destroy()` above doesn't touch it): the previous run's global
	-- UserInputService connections (window/float-button drag, slider drag, keybind listener, color picker
	-- drag — all service-level, survive their own widget's destruction otherwise), the previous run's
	-- ThemeListeners closures (grow forever otherwise — `themed()`/`onTheme` never prune on their own), and
	-- the previous run's Flags (a flag not reused by the new window would otherwise sit forever pointing at
	-- destroyed widgets, polluting SaveConfig's output). Confirmed via code review this session (bug batch
	-- from an external review) that re-executing the script repeatedly — this project's own normal dev
	-- loop — was stacking all three without this.
	clearGlobalConnections()
	ThemeListeners = {}
	self.Flags = {}

	local screenGui = new("ScreenGui", {
		Name = "IOSRobloxUILib",
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Global, -- Sibling scopes ZIndex to same-parent comparisons only;
		-- the dropdown flyout (ZIndex 10/11) and dock-toggle glyphs (25-27) were written assuming global
		-- stacking, so Sibling let a later sibling row (e.g. Test Button) paint over an open dropdown
		-- from an unrelated branch regardless of its ZIndex. Global makes those numbers mean what they say.
		DisplayOrder = 999,
		Parent = guiParent,
	})
	protect(screenGui)

	local sheet = new("Frame", {
		Name = "Sheet",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(WindowSize.X, WindowSize.Y),
		BackgroundColor3 = Colors.BgFrame,
		BackgroundTransparency = 1, -- tweened in on open
		ClipsDescendants = true,
		Parent = screenGui,
	})
	themed(sheet, "BackgroundColor3", "BgFrame")
	corner(sheet, Radius.Sheet)
	stroke(sheet, 0.9, 1)

	local dock = new("Frame", {
		Name = "Dock",
		Size = UDim2.new(0, Spacing.DockWidth, 1, 0),
		BackgroundColor3 = Colors.BgDock,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Parent = sheet,
	})
	themed(dock, "BackgroundColor3", "BgDock")
	-- sheet's ClipsDescendants only clips to its rectangular bounds, not its rounded silhouette,
	-- so the dock needs its own matching UICorner or its square corners poke past the window curve.
	-- UICorner rounds all 4 corners of whatever it's on — there's no per-corner radius in Roblox — but
	-- only the LEFT two corners are ever near the sheet's own rounded silhouette; the right two are a
	-- purely internal seam against `content`. Rounding all 4 made `dock` render as its own fully-rounded
	-- rectangle, reading as a separate panel bolted onto the sheet instead of one continuous frame (user
	-- screenshot: "that's off the main frame... coming from outside"). Squared the right side back off
	-- with a same-color flush patch below, so only the left corners stay visibly rounded.
	local dockCorner = corner(dock, Radius.Sheet)
	local dockRightSquareOff = new("Frame", {
		Name = "RightSquareOff",
		-- covers the rightmost `Radius.Sheet`-wide strip of dock with a flat-cornered rectangle in the
		-- same BgDock color, painting over the right corners' curve so they read as square again while
		-- the left corners (untouched by this patch) keep the rounding that matches the sheet's edge.
		-- Must stay a sibling of `dockList` below, NOT a child of it — UIListLayout arranges every
		-- GuiObject child of whatever it's parented to regardless of intent, and this patch's full-height
		-- Size was getting treated as a giant first list item, shoving the real tab slots down past it
		-- (confirmed live via user screenshot: tab dot rendered at the very bottom of the dock instead
		-- of under the menu button). Keeping it outside `dockList` keeps it invisible to the layout.
		Position = UDim2.new(1, -Radius.Sheet, 0, 0),
		Size = UDim2.new(0, Radius.Sheet, 1, 0),
		BackgroundColor3 = Colors.BgDock,
		BorderSizePixel = 0,
		Parent = dock,
	})
	themed(dockRightSquareOff, "BackgroundColor3", "BgDock")

	-- Tab slots + their UIListLayout live in this nested frame, not directly on `dock`, specifically so
	-- RightSquareOff (a plain decorative sibling, not a list item) never gets swept into the layout.
	local dockList = new("Frame", {
		Name = "DockList",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Parent = dock,
	})
	new("UIListLayout", {
		FillDirection = Enum.FillDirection.Vertical,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 8),
		Parent = dockList,
	})
	pad(dockList, nil, 46, 0, 12, 0) -- top clears the round dock-toggle button

	-- Top-level layer for floating UI (dropdown flyouts, etc.) that must never be structurally nested
	-- inside a row. Reparenting a flyout here instead of into its own row keeps it a completely
	-- separate branch from every row, so there's no sibling-row button anywhere "behind" it in the
	-- tree for a click to also land on (this is what actually fixed dropdown-vs-Test-Button).
	--
	-- ZIndex history, don't redo this: first tried leaving `overlay` at the default ZIndex and relying
	-- on creation ORDER (insertion-order tie-break under Global ZIndexBehavior) to control whether it
	-- sits above or below `content` — overlay-after-content fixed the dropdown/Test-Button conflict but
	-- silently ate ALL clicks to content (Toggle, Test Button, everything); overlay-before-content fixed
	-- Toggle/Test Button but un-fixed the dropdown conflict. Insertion order was never a reliable knob
	-- here — it flips one bug on to flip the other off. Fixed for real by giving `overlay` an EXPLICIT
	-- ZIndex below content's default (1), so it never wins input priority over content regardless of
	-- creation order, while a flyout's own `list` (ZIndex = 10, a child of overlay — children don't
	-- inherit a parent's ZIndex in Roblox) still unconditionally draws/receives input above content
	-- whenever it's actually open. Deterministic either way now, order no longer matters.
	local overlay = new("Frame", {
		Name = "Overlay",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = 0,
		Parent = sheet,
	})

	local content = new("Frame", {
		Name = "Content",
		Position = UDim2.new(0, Spacing.DockWidth, 0, 0),
		Size = UDim2.new(1, -Spacing.DockWidth, 1, 0),
		BackgroundTransparency = 1,
		Parent = sheet,
	})
	local contentPadding = pad(content, nil, Spacing.SheetPadV, Spacing.SheetPadH, Spacing.SheetPadV, Spacing.SheetPadH)

	local header = new("Frame", {
		Name = "Header",
		Size = UDim2.new(1, 0, 0, 25),
		BackgroundTransparency = 1,
		Active = true, -- needs to be true for InputBegan to fire reliably on a plain Frame (see drag below)
		Parent = content,
	})
	local titleLabel = new("TextLabel", {
		Name = "Title",
		Font = Fonts.Title,
		Text = windowName,
		TextSize = 16,
		TextColor3 = Colors.TextPrimary,
		TextXAlignment = Enum.TextXAlignment.Left,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 18),
		Position = UDim2.fromOffset(0, 0),
		Parent = header,
	})
	themed(titleLabel, "TextColor3", "TextPrimary")
	local subtitleLabel = new("TextLabel", {
		Name = "Subtitle",
		Font = Fonts.Caption,
		Text = subtitle,
		TextSize = 11,
		TextColor3 = Colors.TextSecondary,
		TextXAlignment = Enum.TextXAlignment.Left,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 13),
		Position = UDim2.fromOffset(0, 18),
		Parent = header,
	})
	themed(subtitleLabel, "TextColor3", "TextSecondary")

	-- ---- window drag (via header) ----
	-- Classic offset-accumulation drag: capture the sheet's Position at drag-start, then on every move
	-- add the pixel delta to the Offset components only (Scale untouched), same idiom the slider's own
	-- drag already uses via UserInputService.InputEnded (global, not input.Changed) for reliability.
	do
		local dragging = false
		local dragStart, startPos
		header.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				dragging = true
				dragStart = input.Position
				startPos = sheet.Position
			end
		end)
		trackConnection(UserInputService.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				dragging = false
			end
		end))
		trackConnection(UserInputService.InputChanged:Connect(function(input)
			if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
				local delta = input.Position - dragStart
				sheet.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
			end
		end))
	end

	-- ---- window resize (bottom-right corner handle) ----
	-- Same offset-accumulation drag idiom as the header drag just above, but grows/shrinks `sheet.Size`
	-- instead of moving `sheet.Position`, clamped to WindowMinSize/WindowMaxSize. Nothing downstream needed
	-- any changes for this to work: Dock/Content/Pages/tab rows are all already Scale-relative to `sheet`,
	-- and `positionFlyout` already reads `sheet.AbsoluteSize` fresh at open-time rather than caching it —
	-- both were built that way for the dock-collapse/expand tween, which already resizes `content` live.
	local resizeHandle = new("TextButton", {
		Name = "ResizeHandle",
		AnchorPoint = Vector2.new(1, 1),
		-- inset by roughly Radius.Sheet (20px), not just a couple pixels — `sheet`'s ClipsDescendants only
		-- clips to its rectangular bounds (not the rounded silhouette, same caveat as the dock's own
		-- RightSquareOff patch notes elsewhere in this file), so a handle sitting right at the literal
		-- pixel corner would visually straddle the curve, appearing to float past the rounded edge onto
		-- whatever's behind the sheet, instead of reading as part of the sheet itself.
		Position = UDim2.new(1, -(Radius.Sheet - 2), 1, -(Radius.Sheet - 2)),
		Size = UDim2.fromOffset(18, 18),
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Text = "",
		ZIndex = 30, -- above the dock-toggle glyphs (top out at 27); flyouts (10/11, 500 for FloatButton)
		-- never overlap this corner so ordering against them doesn't matter
		Parent = sheet,
	})
	local resizeGlyph = new("Frame", {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -4, 1, -4),
		Size = UDim2.fromOffset(10, 10),
		BackgroundTransparency = 1,
		ZIndex = 31,
		Parent = resizeHandle,
	})
	-- classic 6-dot triangular resize grip: 3 diagonal rows (1, 2, 3 dots) built from the glyph's own
	-- bottom-right corner outward — same hand-built zero-asset idiom as every other icon in this file
	for diag = 0, 2 do
		for i = 0, diag do
			local dx, dy = i * 4, (diag - i) * 4
			local dot = new("Frame", {
				AnchorPoint = Vector2.new(1, 1),
				Position = UDim2.new(1, -dx, 1, -dy),
				Size = UDim2.fromOffset(2, 2),
				BackgroundColor3 = Colors.TextTertiary,
				BackgroundTransparency = 0.3,
				ZIndex = 31,
				Parent = resizeGlyph,
			})
			corner(dot, 1)
			themed(dot, "BackgroundColor3", "TextTertiary")
		end
	end

	do
		local dragging = false
		local dragStart, startSize
		resizeHandle.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				dragging = true
				dragStart = input.Position
				startSize = sheet.Size
			end
		end)
		trackConnection(UserInputService.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				dragging = false
			end
		end))
		trackConnection(UserInputService.InputChanged:Connect(function(input)
			if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
				local delta = input.Position - dragStart
				local newWidth = math.clamp(startSize.X.Offset + delta.X, WindowMinSize.X, WindowMaxSize.X)
				local newHeight = math.clamp(startSize.Y.Offset + delta.Y, WindowMinSize.Y, WindowMaxSize.Y)
				sheet.Size = UDim2.new(startSize.X.Scale, newWidth, startSize.Y.Scale, newHeight)
			end
		end))
	end

	local pages = new("Frame", {
		Name = "Pages",
		Position = UDim2.new(0, 0, 0, 32),
		Size = UDim2.new(1, 0, 1, -32),
		BackgroundTransparency = 1,
		Parent = content,
	})

	-- round dock-toggle button — floats above dock+content so it's always reachable
	local menuBtn = new("TextButton", {
		Name = "MenuToggle",
		Position = UDim2.fromOffset(12, 10),
		Size = UDim2.fromOffset(24, 24),
		BackgroundColor3 = Colors.BgCard,
		BackgroundTransparency = 0.15,
		AutoButtonColor = false,
		Text = "",
		ZIndex = 25,
		Parent = sheet,
	})
	themed(menuBtn, "BackgroundColor3", "BgCard")
	corner(menuBtn, Radius.Pill)
	stroke(menuBtn, 0.8, 1)

	local menuIcon = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(12, 10),
		BackgroundTransparency = 1,
		ZIndex = 26,
		Parent = menuBtn,
	})
	local menuOutline = new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = 26,
		Parent = menuIcon,
	})
	corner(menuOutline, 2)
	stroke(menuOutline, 0.2, 1.3)
	new("Frame", {
		Name = "Divider",
		Size = UDim2.new(0, 1.3, 1, 0),
		Position = UDim2.new(0, 4, 0, 0),
		BackgroundColor3 = Colors.TextSecondary,
		BackgroundTransparency = 0.1,
		ZIndex = 27,
		Parent = menuIcon,
	})

	local dockOpen = true
	menuBtn.MouseButton1Click:Connect(function()
		dockOpen = not dockOpen
		if dockOpen then
			tween(dock, Motion.Tab, { Size = UDim2.new(0, Spacing.DockWidth, 1, 0) })
			tween(dockCorner, Motion.Tab, { CornerRadius = UDim.new(0, Radius.Sheet) })
			tween(content, Motion.Tab, {
				Position = UDim2.new(0, Spacing.DockWidth, 0, 0),
				Size = UDim2.new(1, -Spacing.DockWidth, 1, 0),
			})
			tween(contentPadding, Motion.Tab, { PaddingLeft = UDim.new(0, Spacing.SheetPadH) })
		else
			tween(dock, Motion.Tab, { Size = UDim2.new(0, 0, 1, 0) })
			-- radius rides down to 0 in lockstep with width so the corner never exceeds half the
			-- frame's current size mid-tween (that mismatch is what rendered as a floating blob).
			tween(dockCorner, Motion.Tab, { CornerRadius = UDim.new(0, 0) })
			tween(content, Motion.Tab, {
				Position = UDim2.new(0, 0, 0, 0),
				Size = UDim2.new(1, 0, 1, 0),
			})
			tween(contentPadding, Motion.Tab, { PaddingLeft = UDim.new(0, 46) })
		end
	end)
	menuBtn.MouseEnter:Connect(function()
		tween(menuBtn, Motion.Hover, { BackgroundTransparency = 0 })
	end)
	menuBtn.MouseLeave:Connect(function()
		tween(menuBtn, Motion.Hover, { BackgroundTransparency = 0.15 })
	end)

	-- open animation
	sheet.Size = UDim2.fromOffset(WindowSize.X * 0.96, WindowSize.Y * 0.96)
	tween(sheet, Motion.Open, {
		BackgroundTransparency = 0.04,
		Size = UDim2.fromOffset(WindowSize.X, WindowSize.Y),
	})

	-- ---- floating menu toggle button ----
	-- A sibling of `sheet` on `screenGui`, not a child of it — so it stays visible and tappable even while
	-- the menu itself is hidden (`Window:SetVisible(false)`), which is the whole point of a floating
	-- toggle. Draggable with the same offset-accumulation idiom as the header drag above, but distinguishes
	-- a drag from a tap by total pointer travel (`DRAG_THRESHOLD`) so dragging it around the screen doesn't
	-- also toggle the menu on release.
	local floatBtn = new("TextButton", {
		Name = "FloatButton",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -24, 1, -24),
		Size = UDim2.fromOffset(48, 48),
		BackgroundColor3 = Colors.BgCard,
		BackgroundTransparency = 0.1,
		AutoButtonColor = false,
		Text = "",
		Active = true,
		ZIndex = 500, -- above every ZIndex used inside `sheet` (dock-toggle glyphs top out at 27, flyouts
		-- at 10/11) so it's always reachable regardless of what's open when the menu gets hidden.
		Parent = screenGui,
	})
	themed(floatBtn, "BackgroundColor3", "BgCard")
	corner(floatBtn, Radius.Pill)
	stroke(floatBtn, 0.75, 1.2)

	-- simple 3-bar zero-asset "menu" glyph, same hand-built idiom as the dock-toggle's own icon above
	local floatIcon = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(18, 12),
		BackgroundTransparency = 1,
		Parent = floatBtn,
	})
	-- Roblox's Enum.VerticalAlignment has no "SpaceBetween" (only Top/Center/Bottom) — even spacing between
	-- 3 fixed-height bars comes from Padding instead: 3 * 2px bars + 2 * 3px gaps = 12px, exactly filling
	-- floatIcon's height, so Center/Top read identically here.
	new("UIListLayout", {
		FillDirection = Enum.FillDirection.Vertical,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 3),
		Parent = floatIcon,
	})
	for i = 1, 3 do
		local bar = new("Frame", {
			Size = UDim2.new(1, 0, 0, 2),
			BackgroundColor3 = Colors.TextPrimary,
			BackgroundTransparency = 0.1,
			BorderSizePixel = 0,
			LayoutOrder = i,
			Parent = floatIcon,
		})
		themed(bar, "BackgroundColor3", "TextPrimary")
	end

	-- forward-declared: assigned once `Window` exists below, called from the drag block's tap branch
	local requestToggle = function() end
	do
		local dragging, dragStart, startPos, moved = false, nil, nil, false
		local DRAG_THRESHOLD = 6 -- pixels; below this on release, treat it as a tap instead of a drag
		floatBtn.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				dragging = true
				moved = false
				dragStart = input.Position
				startPos = floatBtn.Position
			end
		end)
		trackConnection(UserInputService.InputChanged:Connect(function(input)
			if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
				local delta = input.Position - dragStart
				if not moved and delta.Magnitude > DRAG_THRESHOLD then
					moved = true
				end
				floatBtn.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
			end
		end))
		trackConnection(UserInputService.InputEnded:Connect(function(input)
			if dragging and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
				dragging = false
				if not moved then
					requestToggle()
				end
			end
		end))
	end

	local Window = setmetatable({
		ScreenGui = screenGui,
		Sheet = sheet,
		Dock = dock,
		DockList = dockList,
		Pages = pages,
		Overlay = overlay,
		FloatButton = floatBtn,
		Tabs = {},
		ActiveTab = nil,
		Visible = true, -- whole-window visibility (Window:SetVisible/:ToggleVisible), distinct from the
		-- dock-collapse toggle above which only hides the side dock while keeping the window itself shown
		-- Every flyout-having widget (Dropdown/MultiDropdown/ColorPicker) re-points this to its own
		-- "close myself" closure right when it opens, after first calling whatever was here before —
		-- so opening one flyout auto-closes any other, and (see CreateTab's `activate`) switching tabs
		-- closes whatever's open too. Needed because flyouts live in `Overlay`, a Window-level layer,
		-- not inside any Tab's own Page — nothing about switching pages naturally hides them (confirmed
		-- live via user screenshot: an open color picker panel stayed visible after switching tabs).
		CloseActiveFlyout = function() end,
	}, WindowMeta)

	requestToggle = function()
		Window:ToggleVisible()
	end

	self.Window = Window -- lets Library:Destroy() find the current window without the caller having to
	-- keep their own reference to it around

	return Window
end

-- Full explicit teardown: disconnects every tracked global connection (via clearGlobalConnections, which
-- — see its own comment above — also catches a PREVIOUS full script execution's leftover connections
-- through getgenv()), resets ThemeListeners and Flags the same way CreateWindow does before building a
-- new window, and destroys the actual GUI (found by name, the same way CreateWindow finds a previous
-- window to replace — not via `self.Window`, so this still works even if that reference was never set,
-- e.g. Destroy() called on a freshly-loaded Library instance before CreateWindow has run on it). Doesn't
-- touch the independent Notify toast layer, which is deliberately decoupled from any Window's lifecycle.
function Library:Destroy()
	clearGlobalConnections()
	clearControlDependencies()
	ThemeListeners = {}
	self.Flags = {}
	local guiParent = getGuiParent()
	local existing = guiParent:FindFirstChild("IOSRobloxUILib")
	if existing then
		existing:Destroy()
	end
	self.Window = nil
end

-- Convenience alias for a script that kept its own `Window` variable instead of the `Library` one — both
-- fully tear down the same way, since this just delegates straight to Library:Destroy().
function WindowMeta:Destroy()
	Library:Destroy()
end

-- Shows/hides the whole window (`Sheet`) — what the floating button and any keybind wired to it call.
-- Independent of the dock-collapse toggle (`menuBtn` in CreateWindow, which only collapses the side dock
-- while keeping the window itself visible). Also closes whatever flyout might be open, so hiding the menu
-- never leaves a dropdown/multi-dropdown/color-picker panel visually stranded behind a hidden sheet.
function WindowMeta:SetVisible(visible)
	if self.Visible == visible then
		return
	end
	self.Visible = visible
	self.CloseActiveFlyout()
	if visible then
		self.Sheet.Visible = true
		tween(self.Sheet, Motion.Open, { BackgroundTransparency = 0.04 })
	else
		local closeTween = tween(self.Sheet, Motion.Tab, { BackgroundTransparency = 1 })
		closeTween.Completed:Connect(function(state)
			if state == Enum.PlaybackState.Completed and not self.Visible then
				self.Sheet.Visible = false
			end
		end)
	end
end

function WindowMeta:ToggleVisible()
	self:SetVisible(not self.Visible)
end

function WindowMeta:_ClearTooltipNow()
	if self._tooltip then
		local t = self._tooltip
		self._tooltip = nil
		self._tooltipStroke = nil
		self._tooltipLabels = nil
		if t.Parent then t:Destroy() end
	end
end

function WindowMeta:ShowTooltip(targetNode, title, desc)
	self._tooltipGen = (self._tooltipGen or 0) + 1
	local myGen = self._tooltipGen
	self:_ClearTooltipNow()

	local tooltip = new("Frame", {
		Name = "Tooltip",
		BackgroundColor3 = Colors.BgCard,
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(0, 0),
		AutomaticSize = Enum.AutomaticSize.XY,
		ZIndex = 110,
		Parent = self.Overlay,
	})
	corner(tooltip, Radius.Card)
	local tooltipStroke = stroke(tooltip, 1, 1)
	tooltipStroke.ZIndex = 111

	pad(tooltip, nil, 8, 12, 8, 12)
	new("UIListLayout", {
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 4),
		Parent = tooltip,
	})

	local labels = {}

	if title and title ~= "" then
		local titleLbl = new("TextLabel", {
			Name = "Title",
			Font = Fonts.Title,
			Text = title,
			TextSize = 14,
			TextColor3 = Colors.TextPrimary,
			TextTransparency = 1,
			TextXAlignment = Enum.TextXAlignment.Left,
			BackgroundTransparency = 1,
			Size = UDim2.fromOffset(0, 16),
			AutomaticSize = Enum.AutomaticSize.XY,
			ZIndex = 112,
			LayoutOrder = 1,
			Parent = tooltip,
		})
		themed(titleLbl, "TextColor3", "TextPrimary")
		table.insert(labels, titleLbl)
	end

	if desc and desc ~= "" then
		local descLbl = new("TextLabel", {
			Name = "Desc",
			Font = Fonts.Body,
			Text = desc,
			TextSize = 13,
			TextColor3 = Colors.TextSecondary,
			TextTransparency = 1,
			TextXAlignment = Enum.TextXAlignment.Left,
			BackgroundTransparency = 1,
			Size = UDim2.fromOffset(0, 14),
			AutomaticSize = Enum.AutomaticSize.XY,
			TextWrapped = true,
			ZIndex = 112,
			LayoutOrder = 2,
			Parent = tooltip,
		})
		themed(descLbl, "TextColor3", "TextSecondary")
		new("UISizeConstraint", { MaxSize = Vector2.new(200, 9999), Parent = tooltip })
		table.insert(labels, descLbl)
	end

	task.spawn(function()
		task.wait()
		if not tooltip.Parent or self._tooltipGen ~= myGen then return end
		local targetPos = targetNode.AbsolutePosition
		local targetSize = targetNode.AbsoluteSize
		local sheetPos = self.Sheet.AbsolutePosition

		local px = (targetPos.X - sheetPos.X) + targetSize.X + 12
		local py = (targetPos.Y - sheetPos.Y) + (targetSize.Y / 2) - (tooltip.AbsoluteSize.Y / 2)

		tooltip.Position = UDim2.fromOffset(px - 5, py)

		tween(tooltip, Motion.Hover, { Position = UDim2.fromOffset(px, py), BackgroundTransparency = 0 })
		tween(tooltipStroke, Motion.Tab, { Transparency = 0.9 })
		for _, lbl in ipairs(labels) do
			tween(lbl, Motion.Tab, { TextTransparency = 0 })
		end
	end)

	self._tooltip = tooltip
	self._tooltipStroke = tooltipStroke
	self._tooltipLabels = labels
end

function WindowMeta:HideTooltip()
	self._tooltipGen = (self._tooltipGen or 0) + 1
	local myGen = self._tooltipGen

	task.delay(0.08, function()
		if self._tooltipGen ~= myGen then return end
		if self._tooltip then
			local t = self._tooltip
			local tS = self._tooltipStroke
			local tL = self._tooltipLabels
			self._tooltip = nil
			self._tooltipStroke = nil
			self._tooltipLabels = nil

			local tw = tween(t, Motion.Hover, { BackgroundTransparency = 1, Position = t.Position - UDim2.fromOffset(5, 0) })
			if tS then tween(tS, Motion.Tab, { Transparency = 1 }) end
			if tL then
				for _, lbl in ipairs(tL) do
					tween(lbl, Motion.Tab, { TextTransparency = 1 })
				end
			end

			tw.Completed:Connect(function()
				if t.Parent then t:Destroy() end
			end)
		end
	end)
end

function WindowMeta:CreateTab(config)
	config = config or {}
	local tabName = config.Name or "Tab"
	local icon = config.Icon

	local slot = new("TextButton", {
		Name = tabName .. "Slot",
		Size = UDim2.fromOffset(Spacing.SlotSize, Spacing.SlotSize),
		BackgroundColor3 = Colors.BgCard,
		BackgroundTransparency = 0.3,
		AutoButtonColor = false,
		Text = "",
		LayoutOrder = #self.Tabs + 1,
		Parent = self.DockList,
	})
	corner(slot, Radius.Slot)
	local slotStroke = stroke(slot, 0.9, 1)

	buildIcon(slot, icon, Colors.TextSecondary)

	local page = new("ScrollingFrame", {
		Name = tabName .. "Page",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 3,
		ScrollBarImageColor3 = Colors.TextTertiary,
		CanvasSize = UDim2.new(0, 0, 0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		Visible = false,
		Parent = self.Pages,
	})
	local layout = new("UIListLayout", {
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, Spacing.RowGap),
		Parent = page,
	})

	local Tab = setmetatable({
		Window = self,
		Name = tabName,
		Slot = slot,
		Page = page,
		Layout = layout,
		RowCount = 0,
	}, TabMeta)

	local function activate()
		if self.ActiveTab == Tab then
			return
		end
		self.CloseActiveFlyout() -- see Window.CloseActiveFlyout's comment: flyouts live in Overlay, outlive a page switch otherwise
		if self.ActiveTab then
			local prev = self.ActiveTab
			tween(prev.Slot, Motion.Tab, { BackgroundColor3 = Colors.BgCard })
			tween(prev.Slot:FindFirstChild("UIStroke"), Motion.Tab, { Color = Color3.new(1, 1, 1), Transparency = 0.9 })
			local prevIcon = prev.Slot:FindFirstChild("Icon")
			if prevIcon then
				tintIcon(prevIcon, Colors.TextSecondary)
			end
			prev.Page.Visible = false
		end
		page.Visible = true
		tween(slot, Motion.Tab, { BackgroundColor3 = Colors.AccentBlue, BackgroundTransparency = 0.82 })
		tween(slotStroke, Motion.Tab, { Color = Colors.AccentBlue, Transparency = 0.5 })
		local activeIcon = slot:FindFirstChild("Icon")
		if activeIcon then
			tintIcon(activeIcon, Colors.TextPrimary)
		end
		self.ActiveTab = Tab
	end

	Tab.ActivateTab = activate

	onTheme(function()
		if slot and slot.Parent then
			if self.ActiveTab == Tab then
				slot.BackgroundColor3 = Colors.AccentBlue
				slotStroke.Color = Colors.AccentBlue
				local activeIcon = slot:FindFirstChild("Icon")
				if activeIcon then
					tintIcon(activeIcon, Colors.TextPrimary)
				end
			else
				slot.BackgroundColor3 = Colors.BgCard
				slotStroke.Color = Color3.new(1, 1, 1)
				local idleIcon = slot:FindFirstChild("Icon")
				if idleIcon then
					tintIcon(idleIcon, Colors.TextSecondary)
				end
			end
		end
	end)

	slot.MouseButton1Click:Connect(activate)
	slot.MouseEnter:Connect(function()
		if self.ActiveTab ~= Tab then
			tween(slot, Motion.Hover, { BackgroundTransparency = 0.1 })
		end
		self:ShowTooltip(slot, Tab.Name, config.Description)
	end)
	slot.MouseLeave:Connect(function()
		if self.ActiveTab ~= Tab then
			tween(slot, Motion.Hover, { BackgroundTransparency = 0.3 })
		end
		self:HideTooltip()
	end)

	table.insert(self.Tabs, Tab)
	if #self.Tabs == 1 then
		activate()
	end

	return Tab
end

-- Programmatically switches the active tab by instance reference, name (case-insensitive), or 1-based index.
function WindowMeta:SetActiveTab(tabTarget)
	if typeof(tabTarget) == "table" and tabTarget.ActivateTab then
		tabTarget:Activate()
		return tabTarget
	elseif typeof(tabTarget) == "string" then
		local lowerTarget = string.lower(tabTarget)
		for _, tab in ipairs(self.Tabs) do
			if string.lower(tab.Name) == lowerTarget then
				tab:Activate()
				return tab
			end
		end
		warn("[iOSRobloxUILib] SetActiveTab: no tab found with name '" .. tostring(tabTarget) .. "'")
	elseif typeof(tabTarget) == "number" then
		local tab = self.Tabs[tabTarget]
		if tab then
			tab:Activate()
			return tab
		else
			warn("[iOSRobloxUILib] SetActiveTab: index " .. tostring(tabTarget) .. " out of bounds")
		end
	end
end

-- Programmatically activates this tab.
function TabMeta:Activate()
	if self.ActivateTab then
		self.ActivateTab()
	end
	return self
end

-- Sets or clears a numeric or text badge pill on the tab's dock button (e.g. 3, "!", "NEW", 99+).
-- Passing nil, false, "", or 0 hides the badge.
function TabMeta:SetBadge(badgeValue)
	local slot = self.Slot
	if not slot then
		return self
	end
	local badge = slot:FindFirstChild("Badge")
	if badgeValue == nil or badgeValue == false or badgeValue == "" or badgeValue == 0 then
		if badge then
			badge.Visible = false
		end
		return self
	end

	local text = tostring(badgeValue)
	if typeof(badgeValue) == "number" and badgeValue > 99 then
		text = "99+"
	end

	if not badge then
		badge = new("Frame", {
			Name = "Badge",
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, 4, 0, -4),
			Size = UDim2.fromOffset(16, 16),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundColor3 = Colors.AccentRed,
			BackgroundTransparency = 0,
			ZIndex = 5,
			Parent = slot,
		})
		themed(badge, "BackgroundColor3", "AccentRed")
		corner(badge, Radius.Pill)
		pad(badge, nil, 1, 4, 1, 4)

		local label = new("TextLabel", {
			Name = "BadgeText",
			Font = Fonts.Body,
			Text = text,
			TextSize = 9,
			TextColor3 = Color3.new(1, 1, 1),
			TextXAlignment = Enum.TextXAlignment.Center,
			TextYAlignment = Enum.TextYAlignment.Center,
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			ZIndex = 6,
			Parent = badge,
		})
	else
		local label = badge:FindFirstChild("BadgeText")
		if label then
			label.Text = text
		end
		badge.Visible = true
	end

	return self
end

-- ---- shared row scaffold ----

-- `tab.FlatRows` (set by CreateSection below) skips each row's own BgCard tint — used when rows are
-- already sitting inside a Section's own card, where a per-row tint on top of the section's card would
-- double up into a slightly muddy card-on-card look instead of one clean grouped card.
local function baseRow(tab, height)
	tab.RowCount += 1
	local row = new("Frame", {
		Name = "Row" .. tab.RowCount,
		Size = UDim2.new(1, 0, 0, height or 40),
		BackgroundColor3 = Colors.BgCard,
		BackgroundTransparency = tab.FlatRows and 1 or 0.5,
		LayoutOrder = tab.RowCount,
		Parent = tab.Page,
	})
	if not tab.FlatRows then
		themed(row, "BackgroundColor3", "BgCard") -- covers every widget's row background in one place
	end
	corner(row, Radius.Card - 2)
	pad(row, nil, 8, 10, 8, 10)

	-- Dim-and-block layer every widget's `SetEnabled(false)` shows/hides, instead of each `CreateXxx`
	-- reinventing its own disabled look. Built here (not per-widget) so it sits above whatever content a
	-- widget adds afterward regardless of creation order — this file's ZIndexBehavior is Global (see
	-- CreateWindow's own comment on why), so an explicit ZIndex wins over insertion order either way.
	-- Active=true so it actually eats clicks/drags meant for the row's real controls while shown; Visible
	-- starts false so a control that's never disabled pays nothing beyond one extra idle Instance.
	-- A GuiButton reliably consumes mouse/touch input; an Active Frame can still leak
	-- activation to controls underneath on some Roblox input paths.
	local disableOverlay = new("TextButton", {
		Name = "DisabledOverlay",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Colors.BgBase,
		BackgroundTransparency = 0.45,
		Active = true,
		AutoButtonColor = false,
		Text = "",
		Visible = false,
		ZIndex = 5,
		Parent = row,
	})
	corner(disableOverlay, Radius.Card - 2)
	themed(disableOverlay, "BackgroundColor3", "BgBase")

	return row, disableOverlay
end

local function labelBlock(row, title, desc)
	local block = new("Frame", {
		Size = UDim2.new(1, -56, 1, 0),
		BackgroundTransparency = 1,
		Parent = row,
	})
	local titleLabel = new("TextLabel", {
		Font = Fonts.Body,
		Text = title,
		TextSize = 13,
		TextColor3 = Colors.TextPrimary,
		TextXAlignment = Enum.TextXAlignment.Left,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 16),
		Parent = block,
	})
	themed(titleLabel, "TextColor3", "TextPrimary")
	local descLabel = nil
	if desc and desc ~= "" then
		descLabel = new("TextLabel", {
			Font = Fonts.SubBody,
			Text = desc,
			TextSize = 10,
			TextColor3 = Colors.TextTertiary,
			TextXAlignment = Enum.TextXAlignment.Left,
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(0, 16),
			Size = UDim2.new(1, 0, 0, 12),
			Parent = block,
		})
		themed(descLabel, "TextColor3", "TextTertiary")
	end
	return block, titleLabel, descLabel
end

-- Shared lifecycle every widget's returned control table gets, attached in one place instead of
-- reimplemented per-`CreateXxx`. Besides the visual lifecycle, it owns the dependency graph: public
-- SetEnabled tracks host intent, while dependency state is a second gate, so a parent transition can never
-- undo a manual disable. Every attached control receives OnChanged, DependOn, DependOnAll, and
-- ClearDependencies; controls without Get simply cannot be dependency sources.
local function attachLifecycle(control, row, disableOverlay, titleLabel, descLabel, descParent, flagName)
	local function applyEnabledState()
		local enabled = control.__manualEnabled and control.__dependencyEnabled
		if disableOverlay and disableOverlay.Parent then
			disableOverlay.Visible = not enabled
		end
	end

	local function evaluateDependencies()
		if control.__destroyed then
			return
		end
		local satisfied = control.__failedDependencyCount == 0
		if satisfied then
			for parent, predicate in pairs(control.__dependencySources) do
				local gotValue, value = pcall(parent.Get, parent)
				local gotResult, result
					if gotValue then
						gotResult, result = pcall(predicate, value, parent)
					else
						gotResult = false
					end
				if not gotResult or result ~= true then
					satisfied = false
					break
				end
			end
		end
		control.__dependencyEnabled = satisfied
		applyEnabledState()
	end

	local function removeDependency(parent)
		if control.__dependencySources[parent] then
			control.__dependencySources[parent] = nil
			if parent.__dependencyDependents then
				parent.__dependencyDependents[control] = nil
			end
		end
	end

	local function reaches(start, target, visited)
		if start == target then
			return true
		end
		visited = visited or {}
		if visited[start] then
			return false
		end
		visited[start] = true
		for child in pairs(start.__dependencyDependents or {}) do
			if not child.__destroyed and reaches(child, target, visited) then
				return true
			end
		end
		return false
	end

	control.__manualEnabled = true
	control.__dependencyEnabled = true
	control.__dependencySources = {}
	control.__dependencyDependents = {}
	control.__failedDependencyCount = 0
	control.__changeListeners = {}
	control.__destroyed = false
	ControlRegistry[control] = true

	-- Constructors assign public Set/Get before lifecycle augmentation. Dependency support is added here
	-- without replacing those control-specific accessors.
	control.__EmitChanged = function(_, value)
		if control.__destroyed then
			return
		end
		for listener in pairs(control.__changeListeners) do
			task.spawn(listener, value)
		end
		-- Value propagation is synchronous, so code immediately following parent:Set(...) sees every
		-- dependent gate in its new state. Snapshot to tolerate a listener destroying a control mid-pass.
		local dependents = {}
		for dependent in pairs(control.__dependencyDependents) do
			table.insert(dependents, dependent)
		end
		for _, dependent in ipairs(dependents) do
			if not dependent.__destroyed and dependent.__EvaluateDependencies then
				dependent:__EvaluateDependencies()
			end
		end
	end
	control.__EvaluateDependencies = function()
		evaluateDependencies()
	end

	control.OnChanged = function(_, listener)
		if type(listener) ~= "function" then
			warn("[iOSRobloxUILib] OnChanged: listener must be a function")
			return { Disconnect = function() end }
		end
		local connected = not control.__destroyed
		if connected then
			control.__changeListeners[listener] = true
		end
		return {
			Disconnect = function()
				if connected then
					connected = false
					control.__changeListeners[listener] = nil
				end
			end,
		}
	end

	control.DependOn = function(_, parent, predicate)
		if control.__destroyed then
			return control
		end
		if type(parent) ~= "table" or parent.__destroyed or type(parent.Get) ~= "function" or type(parent.OnChanged) ~= "function" then
			warn("[iOSRobloxUILib] DependOn: parent must be a live value control")
			return control
		end
		if parent == control or reaches(control, parent) then
			warn("[iOSRobloxUILib] DependOn: dependency cycle rejected")
			return control
		end
		if predicate ~= nil and type(predicate) ~= "function" then
			warn("[iOSRobloxUILib] DependOn: predicate must be a function")
			return control
		end
		removeDependency(parent)
		control.__dependencySources[parent] = predicate or function(value)
			return value == true
		end
		parent.__dependencyDependents[control] = true
		evaluateDependencies()
		return control
	end

	control.DependOnAll = function(_, parents, predicate)
		if type(parents) ~= "table" then
			warn("[iOSRobloxUILib] DependOnAll: parents must be an array of controls")
			return control
		end
		if predicate == nil then
			for _, parent in ipairs(parents) do
				control:DependOn(parent)
			end
			return control
		end
		if type(predicate) ~= "function" then
			warn("[iOSRobloxUILib] DependOnAll: predicate must be a function")
			return control
		end
		for _, parent in ipairs(parents) do
			control:DependOn(parent, function()
				local snapshot = {}
				for i, source in ipairs(parents) do
					local ok, current = pcall(source.Get, source)
					if not ok then
						return false
					end
					snapshot[i] = current
				end
				local ok, result = pcall(predicate, snapshot)
				return ok and result == true
			end)
		end
		return control
	end

	control.ClearDependencies = function()
		for parent in pairs(control.__dependencySources) do
			removeDependency(parent)
		end
		control.__failedDependencyCount = 0
		evaluateDependencies()
		return control
	end

	local visibleAnimationGen = 0
	local rowHeight = row.Size.Y.Offset
	control.SetVisible = function(_, visible)
		visibleAnimationGen += 1
		row.Visible = visible
		row.Size = UDim2.new(1, 0, 0, rowHeight)
	end
	-- Opt-in row transition for conditional controls: UIListLayout sees the height tween and shifts
	-- following rows with it, while the generation counter makes rapid state changes deterministic.
	control.SetVisibleAnimated = function(_, visible)
		visibleAnimationGen += 1
		local myGen = visibleAnimationGen
		if visible then
			row.Visible = true
			row.Size = UDim2.new(1, 0, 0, 0)
			tween(row, Motion.Tab, { Size = UDim2.new(1, 0, 0, rowHeight) })
		else
			if not row.Visible then
				return
			end
			local closeTween = tween(row, Motion.Tab, { Size = UDim2.new(1, 0, 0, 0) })
			closeTween.Completed:Connect(function(state)
				if state == Enum.PlaybackState.Completed and myGen == visibleAnimationGen then
					row.Visible = false
					row.Size = UDim2.new(1, 0, 0, rowHeight)
				end
			end)
		end
	end
	control.__IsEnabled = function()
		return not control.__destroyed and control.__manualEnabled and control.__dependencyEnabled
	end
	control.SetEnabled = function(_, enabled)
		control.__manualEnabled = enabled == true
		applyEnabledState()
	end
	control.SetName = function(_, name)
		if titleLabel then
			titleLabel.Text = name
		end
	end
	control.SetDescription = function(_, desc)
		if not descParent then
			return
		end
		if desc and desc ~= "" then
			if not descLabel or not descLabel.Parent then
				descLabel = new("TextLabel", {
					Font = Fonts.SubBody,
					TextSize = 10,
					TextColor3 = Colors.TextTertiary,
					TextXAlignment = Enum.TextXAlignment.Left,
					BackgroundTransparency = 1,
					Position = UDim2.fromOffset(0, 16),
					Size = UDim2.new(1, 0, 0, 12),
					Parent = descParent,
				})
				themed(descLabel, "TextColor3", "TextTertiary")
			end
			descLabel.Text = desc
		elseif descLabel then
			descLabel:Destroy()
			descLabel = nil
		end
	end
	control.Destroy = function()
		if control.__destroyed then
			return
		end
		control.__destroyed = true
		for parent in pairs(control.__dependencySources) do
			if parent.__dependencyDependents then
				parent.__dependencyDependents[control] = nil
			end
		end
		control.__dependencySources = {}
		-- Snapshot the dependents before mutating graph tables. This makes destruction deterministic even
		-- when a dependency update causes host code to destroy another control synchronously.
		local dependents = {}
		for dependent in pairs(control.__dependencyDependents) do
			table.insert(dependents, dependent)
		end
		for _, dependent in ipairs(dependents) do
			if not dependent.__destroyed then
				-- A missing parent is an unsatisfied requirement; keep the edge's failure state rather
				-- than silently re-enabling the child when its prerequisite is destroyed.
				dependent.__dependencySources[control] = function()
					return false
				end
				dependent.__failedDependencyCount += 1
				dependent:__EvaluateDependencies()
			end
		end
		control.__dependencyDependents = {}
		control.__changeListeners = {}
		ControlRegistry[control] = nil
		if flagName and Library.Flags[flagName] == control then
			Library.Flags[flagName] = nil
		end
		row:Destroy()
	end
	return control
end

clearControlDependencies = function()
	for control in pairs(ControlRegistry) do
		if not control.__destroyed then
			control:Destroy()
		end
	end
	ControlRegistry = setmetatable({}, { __mode = "k" })
end

-- Positions an Overlay-parented flyout (dropdown list, multi-dropdown list, color picker panel) relative
-- to its anchor button, in overlay-local pixel offsets (AnchorPoint (1,0), so `Position` is the flyout's
-- top-right corner). `sheet.ClipsDescendants = true`, so a flyout that opens straight below a button near
-- the bottom of a short window can extend past the sheet's own bottom edge and get silently clipped —
-- confirmed live via user screenshot (color picker's hue bar + hex box cut off, only the SV square
-- visible). Flips to open ABOVE the button instead when there isn't room below; if it doesn't fully fit
-- either way (a very tall flyout on a very short window), clamps into whatever room exists rather than
-- guaranteeing an overflow.
local function positionFlyout(sheet, anchorBtn, flyout, flyoutHeight, gap)
	gap = gap or 4
	local x = anchorBtn.AbsolutePosition.X + anchorBtn.AbsoluteSize.X - sheet.AbsolutePosition.X
	local belowY = anchorBtn.AbsolutePosition.Y + anchorBtn.AbsoluteSize.Y - sheet.AbsolutePosition.Y + gap
	local aboveY = anchorBtn.AbsolutePosition.Y - sheet.AbsolutePosition.Y - flyoutHeight - gap
	local sheetHeight = sheet.AbsoluteSize.Y
	local y
	if belowY + flyoutHeight <= sheetHeight then
		y = belowY
	elseif aboveY >= 0 then
		y = aboveY
	else
		y = math.clamp(belowY, 0, math.max(0, sheetHeight - flyoutHeight))
	end
	flyout.Position = UDim2.fromOffset(x, y)
end

-- ================= TAB ELEMENTS =================

function TabMeta:CreateLabel(config)
	config = config or {}
	local row, disableOverlay = baseRow(self, 24)
	local label = new("TextLabel", {
		Font = Fonts.Caption,
		Text = config.Text or "",
		TextSize = 11,
		TextColor3 = Colors.TextSecondary,
		TextXAlignment = Enum.TextXAlignment.Left,
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Parent = row,
	})
	themed(label, "TextColor3", "TextSecondary")
	-- A Label has no separate "name" concept — `SetName` retargets its own displayed text, same field
	-- `config.Text` set it from. No description slot (it IS the text), so `SetDescription` is a no-op.
	return attachLifecycle({ Type = "Label" }, row, disableOverlay, label, nil, nil, nil)
end

-- Multi-line structured card or section text block with optional title header and descriptive body.
-- Supports automatic vertical expansion, dynamic SetTitle / SetContent / Set / Get methods, and Flag tracking.
function TabMeta:CreateParagraph(config)
	config = config or {}
	local titleText = config.Title or config.Name or ""
	local contentText = config.Content or config.Text or config.Description or ""

	self.RowCount += 1
	local row = new("Frame", {
		Name = "Paragraph" .. self.RowCount,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Colors.BgCard,
		BackgroundTransparency = self.FlatRows and 1 or 0.5,
		LayoutOrder = self.RowCount,
		Parent = self.Page,
	})
	if not self.FlatRows then
		corner(row, Radius.Card - 2)
		stroke(row, 0.9, 1)
	end
	themed(row, "BackgroundColor3", "BgCard")
	pad(row, nil, 8, 10, 8, 10)

	local layout = new("UIListLayout", {
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 4),
		Parent = row,
	})

	local titleLabel = new("TextLabel", {
		Name = "Title",
		Font = Fonts.Body,
		Text = titleText,
		TextSize = 13,
		TextColor3 = Colors.TextPrimary,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextWrapped = true,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Visible = titleText ~= "",
		LayoutOrder = 1,
		Parent = row,
	})
	themed(titleLabel, "TextColor3", "TextPrimary")

	local contentLabel = new("TextLabel", {
		Name = "Content",
		Font = Fonts.SubBody,
		Text = contentText,
		TextSize = 12,
		TextColor3 = Colors.TextSecondary,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextWrapped = true,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Visible = contentText ~= "",
		LayoutOrder = 2,
		Parent = row,
	})
	themed(contentLabel, "TextColor3", "TextSecondary")

	local disableOverlay = new("Frame", {
		Name = "DisableOverlay",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Colors.BgBase,
		BackgroundTransparency = 0.5,
		Visible = false,
		ZIndex = 4,
		Parent = row,
	})
		themed(disableOverlay, "BackgroundColor3", "BgBase")
	if not self.FlatRows then
		corner(disableOverlay, Radius.Card - 2)
	end

	local control = {
		Type = "Paragraph",
		Title = titleText,
		Content = contentText,
	}

	function control:SetTitle(newTitle)
		self.Title = tostring(newTitle or "")
		titleLabel.Text = self.Title
		titleLabel.Visible = self.Title ~= ""
		return self
	end
	control.SetName = control.SetTitle

	function control:SetContent(newContent)
		self.Content = tostring(newContent or "")
		contentLabel.Text = self.Content
		contentLabel.Visible = self.Content ~= ""
		return self
	end
	control.SetText = control.SetContent
	control.SetDescription = control.SetContent

	function control:Set(titleOrTable, maybeContent)
		if typeof(titleOrTable) == "table" then
			if titleOrTable.Title or titleOrTable.Name then
				self:SetTitle(titleOrTable.Title or titleOrTable.Name)
			end
			if titleOrTable.Content or titleOrTable.Text or titleOrTable.Description then
				self:SetContent(titleOrTable.Content or titleOrTable.Text or titleOrTable.Description)
			end
		else
			if titleOrTable ~= nil then
				self:SetTitle(titleOrTable)
			end
			if maybeContent ~= nil then
				self:SetContent(maybeContent)
			end
		end
		return self
	end

	function control:Get()
		return {
			Title = self.Title,
			Content = self.Content,
		}
	end

	if config.Flag then
		Library.Flags[config.Flag] = control
	end

	-- Paragraph keeps its richer SetTitle/SetContent/Set surface above; attach only the shared
	-- lifecycle/dependency methods, then restore those paragraph-specific method aliases.
	local setTitle = control.SetTitle
	local setContent = control.SetContent
	local set = control.Set
	local get = control.Get
	attachLifecycle(control, row, disableOverlay, titleLabel, nil, nil, config.Flag)
	control.SetTitle = setTitle
	control.SetName = setTitle
	control.SetContent = setContent
	control.SetText = setContent
	control.SetDescription = setContent
	control.Set = set
	control.Get = get
	return control
end

-- Groups related widgets under one titled card (e.g. "Theme", "Config") instead of them sitting as loose
-- rows in the tab — the grouped-table-view convention this library's Apple HIG look already leans on
-- everywhere else. Returns a Section object carrying the exact same TabMeta metatable as a real Tab —
-- its `Page` just points at the section's own inner body instead of the tab's page, and it keeps its own
-- `RowCount` — so every existing `CreateXxx` widget constructor works inside a section completely
-- unchanged, including ones with their own Overlay-parented flyouts (`Window` is threaded through as-is).
function TabMeta:CreateSection(config)
	config = config or {}
	local title = config.Title or config.Name or "Section"

	self.RowCount += 1
	local container = new("Frame", {
		Name = "Section" .. self.RowCount,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Colors.BgFrame,
		BackgroundTransparency = 0.5,
		LayoutOrder = self.RowCount,
		Parent = self.Page,
	})
	themed(container, "BackgroundColor3", "BgFrame")
	corner(container, Radius.Card)
	stroke(container, 0.9, 1)
	pad(container, nil, 10, 12, 10, 12)
	new("UIListLayout", {
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 6),
		Parent = container,
	})

	local headerLabel = new("TextLabel", {
		Font = Fonts.Body,
		Text = title,
		TextSize = 12,
		TextColor3 = Colors.TextSecondary,
		TextXAlignment = Enum.TextXAlignment.Left,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 16),
		LayoutOrder = 0,
		Parent = container,
	})
	themed(headerLabel, "TextColor3", "TextSecondary")

	local body = new("Frame", {
		Name = "Body",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = 1,
		Parent = container,
	})
	new("UIListLayout", {
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, Spacing.RowGap),
		Parent = body,
	})

	return setmetatable({
		Type = "Section",
		Window = self.Window,
		Page = body,
		RowCount = 0,
		FlatRows = true,
	}, TabMeta)
end

-- Minimal 1px visual separator between widget groups in a tab — cheaper than a full CreateSection when
-- all you want is a break in the list, not a titled card. No labelBlock, no DisabledOverlay: a divider has
-- no "enabled/disabled" state, so SetEnabled would be meaningless and is deliberately not provided (only
-- SetVisible/Destroy, per spec).
function TabMeta:CreateDivider(config)
	config = config or {}
	self.RowCount += 1
	local line = new("Frame", {
		Name = "Divider" .. self.RowCount,
		Size = UDim2.new(1, 0, 0, 1),
		BackgroundColor3 = Colors.BorderSubtle,
		BackgroundTransparency = 0.5,
		BorderSizePixel = 0,
		LayoutOrder = self.RowCount,
		Parent = self.Page,
	})
	themed(line, "BackgroundColor3", "BorderSubtle")

	return {
		Type = "Divider",
		SetVisible = function(_, visible)
			line.Visible = visible
		end,
		Destroy = function()
			line:Destroy()
		end,
	}
end

-- Display-only progress bar (0 to 1 fraction). No Flag (not an interactive input).
-- Supports :SetProgress(fraction, animate), :SetText(overrideText), :GetProgress(), plus standard lifecycle.
function TabMeta:CreateProgressBar(config)
	config = config or {}
	local name = config.Name or "Progress"
	local current = math.clamp(config.CurrentValue or config.Progress or 0, 0, 1)

	local row, disableOverlay = baseRow(self, 46)
	local nameLabel = new("TextLabel", {
		Font = Fonts.Body,
		Text = name,
		TextSize = 13,
		TextColor3 = Colors.TextPrimary,
		TextXAlignment = Enum.TextXAlignment.Left,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -60, 0, 16),
		Parent = row,
	})
	themed(nameLabel, "TextColor3", "TextPrimary")

	local percentLabel = new("TextLabel", {
		Font = Fonts.SubBody,
		Text = config.Text or string.format("%d%%", math.floor(current * 100 + 0.5)),
		TextSize = 11,
		TextColor3 = Colors.TextSecondary,
		TextXAlignment = Enum.TextXAlignment.Right,
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 0),
		Size = UDim2.fromOffset(60, 16),
		Parent = row,
	})
	themed(percentLabel, "TextColor3", "TextSecondary")

	local track = new("Frame", {
		Position = UDim2.fromOffset(0, 26),
		Size = UDim2.new(1, 0, 0, 6),
		BackgroundColor3 = Colors.BorderSubtle,
		Parent = row,
	})
	themed(track, "BackgroundColor3", "BorderSubtle")
	corner(track, Radius.Pill)

	local fill = new("Frame", {
		Size = UDim2.fromScale(current, 1),
		BackgroundColor3 = Colors.AccentBlue,
		Parent = track,
	})
	themed(fill, "BackgroundColor3", "AccentBlue")
	corner(fill, Radius.Pill)

	local customText = config.Text ~= nil

	local control = {
		Type = "ProgressBar",
		SetProgress = function(_, fraction, animate)
			fraction = math.clamp(tonumber(fraction) or 0, 0, 1)
			current = fraction
			if animate ~= false then
				tween(fill, Motion.Press, { Size = UDim2.fromScale(fraction, 1) })
			else
				fill.Size = UDim2.fromScale(fraction, 1)
			end
			if not customText then
				percentLabel.Text = string.format("%d%%", math.floor(fraction * 100 + 0.5))
			end
		end,
		SetText = function(_, text)
			if text then
				customText = true
				percentLabel.Text = tostring(text)
			else
				customText = false
				percentLabel.Text = string.format("%d%%", math.floor(current * 100 + 0.5))
			end
		end,
		GetProgress = function()
			return current
		end,
	}

	if config.Flag then
		Library.Flags[config.Flag] = control
	end
	return attachLifecycle(control, row, disableOverlay, nameLabel, nil, nil, config.Flag)
end

function TabMeta:CreateToggle(config)
	config = config or {}
	local name = config.Name or "Toggle"
	local default = config.CurrentValue == true
	local callback = config.Callback or function() end

	local row, disableOverlay = baseRow(self, 40)
	local block, titleLabel, descLabel = labelBlock(row, name, config.Description)

	local track = new("TextButton", {
		Name = "Track",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, 0, 0.5, 0),
		Size = UDim2.fromOffset(44, 24),
		BackgroundColor3 = default and Colors.AccentGreen or Colors.BorderSubtle,
		AutoButtonColor = false,
		Text = "",
		Parent = row,
	})
	corner(track, Radius.Pill)

	local thumb = new("Frame", {
		Name = "Thumb",
		Size = UDim2.fromOffset(20, 20),
		Position = UDim2.fromOffset(default and 22 or 2, 2),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Parent = track,
	})
	corner(thumb, Radius.Pill)

	local state = default
	local control

	local function set(value, fireCallback)
		value = value == true
		local changed = state ~= value
		state = value
		tween(track, Motion.Toggle, { BackgroundColor3 = state and Colors.AccentGreen or Colors.BorderSubtle })
		tween(thumb, Motion.Toggle, { Position = UDim2.fromOffset(state and 22 or 2, 2) })
		if changed and control then
			control:__EmitChanged(state)
		end
		if fireCallback then
			task.spawn(callback, state)
		end
	end
	-- track's color is state-dependent, not a fixed Colors key, so it needs its own onTheme closure
	-- (a plain themed() call would only know one key) rather than the usual one-liner.
	onTheme(function()
		track.BackgroundColor3 = state and Colors.AccentGreen or Colors.BorderSubtle
	end)

	track.MouseButton1Click:Connect(function()
		set(not state, true)
	end)

	control = {
		Type = "Toggle",
		-- fires the callback (unlike a purely-cosmetic Set) so LoadConfig actually re-applies the effect
		-- (e.g. a restored "Fly Hack: true" really re-enables flying, not just flips the switch visually),
		-- matching Slider/Dropdown's Set below which already call their callback.
		Set = function(_, value)
			set(value, true)
		end,
		Get = function()
			return state
		end,
	}
	if config.Flag then
		Library.Flags[config.Flag] = control
	end
	return attachLifecycle(control, row, disableOverlay, titleLabel, descLabel, block, config.Flag)
end

function TabMeta:CreateButton(config)
	config = config or {}
	local name = config.Name or "Button"
	local callback = config.Callback or function() end

	local row, disableOverlay = baseRow(self, 36)
	local btn = new("TextButton", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
		Parent = row,
	})
	local btnLabel = new("TextLabel", {
		Font = Fonts.Body,
		Text = name,
		TextSize = 13,
		TextColor3 = Colors.AccentBlue,
		TextXAlignment = Enum.TextXAlignment.Center,
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Parent = btn,
	})
	themed(btnLabel, "TextColor3", "AccentBlue")

	local control = { Type = "Button" }
	btn.MouseButton1Down:Connect(function()
		if control.__IsEnabled and control:__IsEnabled() then
			tween(row, Motion.Press, { BackgroundTransparency = 0.2 })
		end
	end)
	btn.MouseButton1Up:Connect(function()
		if control.__IsEnabled and control:__IsEnabled() then
			tween(row, Motion.Hover, { BackgroundTransparency = 0.5 })
		end
	end)
	btn.MouseButton1Click:Connect(function()
		if control.__IsEnabled and control:__IsEnabled() then
			task.spawn(callback)
		end
	end)

	-- A Button's "name" is its own centered label; no description slot (there's no room in a 36px button
	-- row for one), so `SetDescription` is a documented no-op like Label's.
	return attachLifecycle(control, row, disableOverlay, btnLabel, nil, nil, nil)
end

function TabMeta:CreateSlider(config)
	config = config or {}
	local name = config.Name or "Slider"
	local min = config.Range and config.Range[1] or 0
	local max = config.Range and config.Range[2] or 100
	-- A reversed Range ({200, 16} instead of {16, 200}) used to crash outright: math.clamp requires
	-- min <= max and errors otherwise, and `value = math.clamp(config.CurrentValue or min, min, max)` just
	-- below is the very first thing this constructor does with them. Same defensive spirit as the
	-- max==min/increment<=0 guards right after this (a bad-but-plausible config shouldn't crash the whole
	-- widget) — swapping instead of erroring makes {200, 16} behave exactly like {16, 200}.
	if min > max then
		min, max = max, min
	end
	local increment = config.Increment or 1
	-- unclamped CurrentValue used to render (and report to Callback) a value outside [min,max] until the
	-- user's first drag silently pulled it back in line via setFromAlpha's own math.clamp — confirmed via
	-- code review (external bug report) that the visible starting state and the actual range could
	-- disagree. Clamping here makes the initial render always agree with the widget's own valid range.
	local value = math.clamp(config.CurrentValue or min, min, max)
	local callback = config.Callback or function() end

	-- `max == min` divides by zero below (both in the initial fill size and in every setFromAlpha call);
	-- `toAlpha` maps that degenerate range to a fixed 0 instead of propagating a NaN into UDim2.fromScale,
	-- which errors outright. A single-value Range is a plausible (if odd) config, not worth crashing over.
	local function toAlpha(v)
		if max == min then
			return 0
		end
		return (v - min) / (max - min)
	end

	local row, disableOverlay = baseRow(self, 46)
	local nameLabel = new("TextLabel", {
		Font = Fonts.Body,
		Text = name,
		TextSize = 13,
		TextColor3 = Colors.TextPrimary,
		TextXAlignment = Enum.TextXAlignment.Left,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -60, 0, 16),
		Parent = row,
	})
	themed(nameLabel, "TextColor3", "TextPrimary")
	local valueInput = new("TextBox", {
		Font = Fonts.SubBody,
		Text = tostring(value),
		TextSize = 11,
		TextColor3 = Colors.TextSecondary,
		TextXAlignment = Enum.TextXAlignment.Right,
		BackgroundTransparency = 1,
		ClearTextOnFocus = false,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 0),
		Size = UDim2.fromOffset(50, 16),
		Parent = row,
	})
	themed(valueInput, "TextColor3", "TextSecondary")

	local track = new("Frame", {
		Position = UDim2.fromOffset(0, 26),
		Size = UDim2.new(1, 0, 0, 6),
		BackgroundColor3 = Colors.BorderSubtle,
		Parent = row,
	})
	themed(track, "BackgroundColor3", "BorderSubtle")
	corner(track, Radius.Pill)

	local fill = new("Frame", {
		Size = UDim2.fromScale(toAlpha(value), 1),
		BackgroundColor3 = Colors.AccentBlue,
		Parent = track,
	})
	themed(fill, "BackgroundColor3", "AccentBlue")
	corner(fill, Radius.Pill)

	local control
	local function setFromAlpha(alpha)
		alpha = math.clamp(alpha, 0, 1)
		local raw = min + (max - min) * alpha
		-- `increment <= 0` divides by zero on every single drag frame (not just at creation, unlike
		-- min==max above) — falls back to an unquantized/continuous value instead of erroring, which is
		-- the closest sane behavior to "no snapping" for a bad or zero increment.
		local nextValue = increment > 0
			and math.clamp(math.floor(raw / increment + 0.5) * increment, min, max)
			or math.clamp(raw, min, max)
		local changed = value ~= nextValue
		value = nextValue
		local drawAlpha = toAlpha(value)
		tween(fill, Motion.Press, { Size = UDim2.fromScale(drawAlpha, 1) })
		valueInput.Text = tostring(value)
		if changed and control then
			control:__EmitChanged(value)
		end
		task.spawn(callback, value)
	end

	valueInput.FocusLost:Connect(function()
		if control and control.__IsEnabled and not control:__IsEnabled() then
			valueInput.Text = tostring(value)
			return
		end
		local num = tonumber(valueInput.Text)
		if num then
			num = math.clamp(num, min, max)
			if increment > 0 then
				num = math.floor(num / increment + 0.5) * increment
				num = math.clamp(num, min, max)
			end
			setFromAlpha(toAlpha(num))
		else
			valueInput.Text = tostring(value)
		end
	end)

	local dragging = false

	local trackButton = new("TextButton", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = "",
		Parent = track,
	})

	-- A plain click (down+up with zero movement) used to do nothing at all — dragging only flipped a flag,
	-- and the value only ever actually moved from InputChanged, which never fires without a mouse-move
	-- frame in between. Every other slider convention jumps to the click position immediately; doing the
	-- same here means `x`/`y` (GuiButton.MouseButton1Down's own params, screen pixels) feed straight into
	-- the same alpha math InputChanged uses below instead of duplicating it.
	trackButton.MouseButton1Down:Connect(function(x, y)
		if not (control and control.__IsEnabled and control:__IsEnabled()) then
			return
		end
		dragging = true
		local relX = (x - track.AbsolutePosition.X) / track.AbsoluteSize.X
		setFromAlpha(relX)
	end)
	trackConnection(UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end))
	trackConnection(UserInputService.InputChanged:Connect(function(input)
		if dragging and control and control.__IsEnabled and control:__IsEnabled()
			and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			local relX = (input.Position.X - track.AbsolutePosition.X) / track.AbsoluteSize.X
			setFromAlpha(relX)
		end
	end))
	control = {
		Type = "Slider",
		Set = function(_, v)
			setFromAlpha(toAlpha(v))
		end,
		Get = function()
			return value
		end,
	}
	if config.Flag then
		Library.Flags[config.Flag] = control
	end
	-- Slider's layout (name + right-aligned value on one line, track below) has no labelBlock/description
	-- slot to attach to — `SetName` retargets `nameLabel`, `SetDescription` is a documented no-op.
	return attachLifecycle(control, row, disableOverlay, nameLabel, nil, nil, config.Flag)
end

function TabMeta:CreateDropdown(config)
	config = config or {}
	local name = config.Name or "Dropdown"
	local options = config.Options or {}
	local current = config.CurrentOption or options[1] or ""
	local callback = config.Callback or function() end
	local searchable = config.Searchable == true
	local maxVisible = config.MaxVisibleOptions or 6
	local flyoutWidth = config.FlyoutWidth or (searchable and 120 or 96)
	local searchH = searchable and 26 or 0

	local row, disableOverlay = baseRow(self, 40)
	local block, titleLabel, descLabel = labelBlock(row, name, config.Description)

	local btn = new("TextButton", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, 0, 0.5, 0),
		Size = UDim2.fromOffset(flyoutWidth, 26),
		BackgroundColor3 = Colors.BgFrame,
		AutoButtonColor = false,
		Text = "",
		Parent = row,
	})
	themed(btn, "BackgroundColor3", "BgFrame")
	corner(btn, Radius.Slot)
	stroke(btn, 0.85, 1)
	local btnLabel = new("TextLabel", {
		Font = Fonts.SubBody,
		Text = current,
		TextSize = 11,
		TextColor3 = Colors.TextPrimary,
		TextTruncate = Enum.TextTruncate.AtEnd,
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Parent = btn,
	})
	themed(btnLabel, "TextColor3", "TextPrimary")

	local overlay = self.Window.Overlay
	local sheet = overlay.Parent

	local listHeight = searchH + (math.min(#options, maxVisible) * 24)
	local list = new("Frame", {
		Name = "OptionList",
		Active = true,
		ClipsDescendants = true,
		Visible = false,
		BackgroundTransparency = 1,
		ZIndex = 10,
		AnchorPoint = Vector2.new(1, 0),
		Size = UDim2.fromOffset(flyoutWidth, 0),
		BackgroundColor3 = Colors.BgFrame,
		Parent = overlay,
	})
	themed(list, "BackgroundColor3", "BgFrame")
	corner(list, Radius.Slot)
	stroke(list, 0.85, 1)

	local searchBox
	if searchable then
		local searchHeader = new("Frame", {
			Name = "SearchHeader",
			Size = UDim2.new(1, 0, 0, 26),
			BackgroundTransparency = 1,
			ZIndex = 10,
			Parent = list,
		})
		searchBox = new("TextBox", {
			Font = Fonts.SubBody,
			Text = "",
			TextSize = 11,
			TextColor3 = Colors.TextPrimary,
			PlaceholderText = "Search...",
			PlaceholderColor3 = Colors.TextTertiary,
			ClearTextOnFocus = false,
			BackgroundTransparency = 1,
			Size = UDim2.new(1, -14, 1, 0),
			Position = UDim2.fromOffset(7, 0),
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 11,
			Parent = searchHeader,
		})
		themed(searchBox, "TextColor3", "TextPrimary")
		local searchDivider = new("Frame", {
			Name = "Divider",
			Size = UDim2.new(1, 0, 0, 1),
			Position = UDim2.new(0, 0, 1, -1),
			BackgroundColor3 = Colors.BorderSubtle,
			BorderSizePixel = 0,
			ZIndex = 11,
			Parent = searchHeader,
		})
		themed(searchDivider, "BackgroundColor3", "BorderSubtle")
	end

	local scroll = new("ScrollingFrame", {
		Name = "Scroll",
		Position = UDim2.fromOffset(0, searchH),
		Size = UDim2.new(1, 0, 1, -searchH),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 3,
		ScrollBarImageColor3 = Colors.BorderSubtle,
		CanvasSize = UDim2.new(0, 0, 0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ZIndex = 10,
		Parent = list,
	})
	themed(scroll, "ScrollBarImageColor3", "BorderSubtle")
	new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Parent = scroll })

	local noResultsLabel
	if searchable then
		noResultsLabel = new("TextLabel", {
			Font = Fonts.SubBody,
			Text = "No matches",
			TextSize = 10,
			TextColor3 = Colors.TextTertiary,
			TextXAlignment = Enum.TextXAlignment.Center,
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 24),
			Visible = false,
			ZIndex = 10,
			Parent = scroll,
		})
		themed(noResultsLabel, "TextColor3", "TextTertiary")
	end

	local optLabels = {}
	local optButtons = {}
	local open = false
	local control
	local selectOption

	local function highlight()
		for option, optLabel in pairs(optLabels) do
			tween(optLabel, Motion.Tab, {
				TextColor3 = option == current and Colors.AccentBlue or Colors.TextSecondary,
			})
		end
	end

	selectOption = function(option, fireCallback)
		if not optLabels[option] then
			return false
		end
		local changed = current ~= option
		current = option
		btnLabel.Text = option
		highlight()
		if changed and control then
			control:__EmitChanged(current)
		end
		if fireCallback then
			task.spawn(callback, current)
		end
		return changed
	end
	onTheme(highlight)

	local setOpen

	local function filterOptions(query)
		query = string.lower(query or "")
		local matchCount = 0
		for option, optBtn in pairs(optButtons) do
			local visible = query == "" or string.find(string.lower(option), query, 1, true) ~= nil
			optBtn.Visible = visible
			if visible then
				matchCount += 1
			end
		end
		if noResultsLabel then
			noResultsLabel.Visible = (matchCount == 0 and query ~= "")
			if matchCount == 0 and query ~= "" then
				matchCount = 1
			end
		end
		return matchCount
	end

	local function rebuildOptions()
		for _, child in ipairs(scroll:GetChildren()) do
			if child:IsA("TextButton") then
				child:Destroy()
			end
		end
		optLabels = {}
		optButtons = {}
		for i, option in ipairs(options) do
			local opt = new("TextButton", {
				Size = UDim2.new(1, 0, 0, 24),
				BackgroundTransparency = 1,
				Text = "",
				LayoutOrder = i,
				ZIndex = 10,
				Parent = scroll,
			})
			local optLabel = new("TextLabel", {
				Font = Fonts.SubBody,
				Text = option,
				TextSize = 11,
				TextColor3 = option == current and Colors.AccentBlue or Colors.TextSecondary,
				TextTruncate = Enum.TextTruncate.AtEnd,
				BackgroundTransparency = 1,
				Position = UDim2.fromOffset(8, 0),
				Size = UDim2.new(1, -16, 1, 0),
				TextXAlignment = Enum.TextXAlignment.Left,
				ZIndex = 11,
				Parent = opt,
			})
			optLabels[option] = optLabel
			optButtons[option] = opt
			opt.MouseButton1Click:Connect(function()
				selectOption(option, true)
				setOpen(false)
			end)
		end
		local count = filterOptions(searchBox and searchBox.Text or "")
		listHeight = searchH + (math.min(count, maxVisible) * 24)
	end

	local function reposition()
		if open then
			positionFlyout(sheet, btn, list, listHeight)
		end
	end

	local function setOpenImpl(value)
		if open == value then
			return
		end
		if value then
			self.Window.CloseActiveFlyout()
		end
		open = value
		if open then
			self.Window.CloseActiveFlyout = function()
				if open then
					setOpen(false)
				end
			end
			if searchBox then
				searchBox.Text = ""
			end
			scroll.CanvasPosition = Vector2.new(0, 0)
			local count = filterOptions("")
			listHeight = searchH + (math.min(count, maxVisible) * 24)
			positionFlyout(sheet, btn, list, listHeight)
			highlight()
			list.Visible = true
			tween(list, Motion.Tab, { Size = UDim2.fromOffset(flyoutWidth, listHeight), BackgroundTransparency = 0 })
		else
			local closeTween = tween(list, Motion.Tab, { Size = UDim2.fromOffset(flyoutWidth, 0), BackgroundTransparency = 1 })
			closeTween.Completed:Connect(function(state)
				if state == Enum.PlaybackState.Completed and not open then
					list.Visible = false
				end
			end)
		end
	end
	setOpen = setOpenImpl

	if searchBox then
		searchBox:GetPropertyChangedSignal("Text"):Connect(function()
			if not open then return end
			local count = filterOptions(searchBox.Text)
			listHeight = searchH + (math.min(count, maxVisible) * 24)
			positionFlyout(sheet, btn, list, listHeight)
			tween(list, Motion.Tab, { Size = UDim2.fromOffset(flyoutWidth, listHeight) })
		end)
	end

	rebuildOptions()
	btn:GetPropertyChangedSignal("AbsolutePosition"):Connect(reposition)
	local sheetResizeConn = sheet:GetPropertyChangedSignal("AbsoluteSize"):Connect(reposition)

	btn.MouseButton1Click:Connect(function()
		if control and control.__IsEnabled and control:__IsEnabled() then
			setOpen(not open)
		end
	end)

	control = {
		Type = "Dropdown",
		Set = function(_, option)
			selectOption(option, true)
		end,
		Get = function()
			return current
		end,
		Refresh = function(_, newOptions)
			local previous = current
			options = newOptions or {}
			rebuildOptions()
			if not optLabels[current] then
				current = options[1] or ""
			end
			btnLabel.Text = current
			highlight()
			if current ~= previous then
				control:__EmitChanged(current)
			end
			if open then
				positionFlyout(sheet, btn, list, listHeight)
				tween(list, Motion.Tab, { Size = UDim2.fromOffset(flyoutWidth, listHeight) })
			end
		end,
	}
	if config.Flag then
		Library.Flags[config.Flag] = control
	end
	attachLifecycle(control, row, disableOverlay, titleLabel, descLabel, block, config.Flag)
	local baseDestroy = control.Destroy
	control.Destroy = function()
		sheetResizeConn:Disconnect()
		list:Destroy()
		baseDestroy()
	end
	return control
end

function TabMeta:CreateInput(config)
	config = config or {}
	local name = config.Name or "Input"
	local placeholder = config.PlaceholderText or ""
	local default = config.CurrentValue or ""
	local numbersOnly = config.NumbersOnly == true
	local clearOnFocus = config.ClearOnFocus == true
	local callback = config.Callback or function() end

	local row, disableOverlay = baseRow(self, 40)
	local block, titleLabel, descLabel = labelBlock(row, name, config.Description)

	local box = new("TextBox", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, 0, 0.5, 0),
		Size = UDim2.fromOffset(120, 26),
		BackgroundColor3 = Colors.BgFrame,
		Font = Fonts.SubBody,
		Text = default,
		PlaceholderText = placeholder,
		PlaceholderColor3 = Colors.TextTertiary,
		TextColor3 = Colors.TextPrimary,
		TextSize = 11,
		ClearTextOnFocus = clearOnFocus,
		Parent = row,
	})
	themed(box, "BackgroundColor3", "BgFrame")
	themed(box, "TextColor3", "TextPrimary")
	themed(box, "PlaceholderColor3", "TextTertiary")
	corner(box, Radius.Slot)
	stroke(box, 0.85, 1)
	pad(box, nil, 0, 8, 0, 8)

	-- last known-good value for NumbersOnly's revert-on-invalid path below. Starts at `default` since
	-- that's what's actually sitting in the box before the user touches it.
	local lastValidNumberText = default
	local currentValue = default
	local control

	local function commit(fireCallback)
		local previous = currentValue
		local v = box.Text
		if numbersOnly then
			-- Character-filtering alone (stripping anything that isn't a digit/dot/minus) still let
			-- structurally-broken text through — "1.2.3", "--5", "5-", ".", "-" all survive a gsub filter
			-- one character at a time, since every individual character in them IS allowed. Actually
			-- parsing with tonumber() after filtering is the only way to catch that; on failure, revert to
			-- the last text that DID parse, same "snap back to the last valid state" idiom the color
			-- picker's hex box already uses for its own invalid-input case.
			local filtered = v:gsub("[^%-%.%d]", "")
			if filtered ~= "" and tonumber(filtered) then
				v = filtered
				lastValidNumberText = v
			else
				v = lastValidNumberText
			end
			box.Text = v
		end
		currentValue = v
		if previous ~= v and control then
			control:__EmitChanged(v)
		end
		if fireCallback then
			task.spawn(callback, v)
		end
	end

	box.FocusLost:Connect(function()
		commit(true)
	end)

	control = {
		Type = "Input",
		Set = function(_, value)
			box.Text = tostring(value)
			commit(false)
		end,
		Get = function()
			return currentValue
		end,
	}
	if config.Flag then
		Library.Flags[config.Flag] = control
	end
	return attachLifecycle(control, row, disableOverlay, titleLabel, descLabel, block, config.Flag)
end

function TabMeta:CreateKeybind(config)
	config = config or {}
	local name = config.Name or "Keybind"
	local callback = config.Callback or function() end
	local changedCallback = config.ChangedCallback or function() end

	-- Indexing Enum.KeyCode with a name that isn't a real member THROWS (not a nil return) — a typo'd
	-- `CurrentKeybind`, or a saved config left over from a renamed/removed KeyCode, would otherwise crash
	-- CreateKeybind outright at creation time. (LoadConfig's own call into `Set` below is already pcall-
	-- wrapped and would have failed soft either way — this specifically protects direct construction and
	-- direct `:Set()` calls, which aren't wrapped by anything.)
	local function safeKeyCode(keyName)
		if not keyName then
			return nil
		end
		local ok, key = pcall(function()
			return Enum.KeyCode[keyName]
		end)
		if ok then
			return key
		end
		return nil
	end

	local currentKey = safeKeyCode(config.CurrentKeybind)
	local control

	local row, disableOverlay = baseRow(self, 40)
	local block, titleLabel, descLabel = labelBlock(row, name, config.Description)

	local btn = new("TextButton", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, 0, 0.5, 0),
		Size = UDim2.fromOffset(88, 26),
		BackgroundColor3 = Colors.BgFrame,
		AutoButtonColor = false,
		Text = "",
		Parent = row,
	})
	themed(btn, "BackgroundColor3", "BgFrame")
	corner(btn, Radius.Slot)
	stroke(btn, 0.85, 1)
	local btnLabel = new("TextLabel", {
		Font = Fonts.SubBody,
		Text = currentKey and currentKey.Name or "None",
		TextSize = 11,
		TextColor3 = Colors.TextPrimary,
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Parent = btn,
	})
	-- text color is state-dependent (idle=TextPrimary, listening=AccentBlue), same reasoning as Toggle's track
	local listening = false
	onTheme(function()
		btnLabel.TextColor3 = listening and Colors.AccentBlue or Colors.TextPrimary
	end)

	btn.MouseButton1Click:Connect(function()
		listening = true
		btnLabel.Text = "..."
		tween(btnLabel, Motion.Tab, { TextColor3 = Colors.AccentBlue })
	end)

	-- global listener: while `listening`, the next key press sets the bind (Escape cancels without
	-- setting); otherwise, a press matching `currentKey` fires the bound callback. `gameProcessed` is
	-- checked only for the fire path so binding capture still works even over a focused chat box etc.
	trackConnection(UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if listening then
			if input.UserInputType ~= Enum.UserInputType.Keyboard then
				return
			end
			listening = false
			if input.KeyCode == Enum.KeyCode.Escape then
				btnLabel.Text = currentKey and currentKey.Name or "None"
			else
				local changed = currentKey ~= input.KeyCode
				currentKey = input.KeyCode
				btnLabel.Text = currentKey.Name
				if changed and control then
					control:__EmitChanged(currentKey.Name)
				end
				task.spawn(changedCallback, currentKey.Name)
			end
			tween(btnLabel, Motion.Tab, { TextColor3 = Colors.TextPrimary })
			return
		end
		if not gameProcessed and currentKey and input.KeyCode == currentKey then
			task.spawn(callback)
		end
	end))

	control = {
		Type = "Keybind",
		Set = function(_, keyName)
			local nextKey = safeKeyCode(keyName)
			local changed = currentKey ~= nextKey
			currentKey = nextKey
			btnLabel.Text = currentKey and currentKey.Name or "None"
			-- Was silently missing: a manual rebind through the UI fired `changedCallback` (see the
			-- InputBegan listener above), but `Set()` — which is what `LoadConfig` calls — didn't, so a
			-- host script relying on ChangedCallback to know "the bind identity changed" (e.g. to update a
			-- hint label elsewhere) never heard about a config-restored bind. Deliberately still NOT firing
			-- the main `callback` here (that's the "hotkey was pressed" action-trigger — firing it from a
			-- config load would misfire the action itself), only the identity-change notification.
			if changed then
				control:__EmitChanged(currentKey and currentKey.Name or nil)
			end
			task.spawn(changedCallback, currentKey and currentKey.Name or nil)
		end,
		Get = function()
			return currentKey and currentKey.Name or nil
		end,
	}
	if config.Flag then
		Library.Flags[config.Flag] = control
	end
	return attachLifecycle(control, row, disableOverlay, titleLabel, descLabel, block, config.Flag)
end

-- Named config save/load UI on top of Library:SaveConfig/LoadConfig/ListConfigs/DeleteConfig. Doesn't
-- register a Flag itself (there's no single persisted "value" here — it's an action panel, not a
-- value-holding widget). `config.Callback`, if given, fires as (action, name, ok, err) after a save/load
-- so a host script can toast the result the same way it would for any other widget's Callback.
-- Split button+box layout: [Save Config][name box] then [Load Config][selection box], each pair a 50/50
-- row split rather than the usual label+control row shape — meant to sit inside a CreateSection card (see
-- "Config" in demo.lua) alongside a similarly-shaped Theme section. Picking a config from the selection
-- box just loads it into the box (doesn't apply it) — pressing "Load Config" is the separate, deliberate
-- commit step, so a stray tap while browsing saved configs can't silently reset your live widget state.
function TabMeta:CreateConfigManager(config)
	config = config or {}
	local callback = config.Callback or function() end -- (action, name, ok, err)

	-- ---- row 1: Save Config (left) + name box (right) ----
	local saveRow = baseRow(self, 40)
	local saveBtn = new("TextButton", {
		Size = UDim2.new(0.5, -4, 1, 0),
		BackgroundColor3 = Colors.AccentBlue,
		AutoButtonColor = false,
		Text = "",
		Parent = saveRow,
	})
	themed(saveBtn, "BackgroundColor3", "AccentBlue")
	corner(saveBtn, Radius.Slot)
	local saveLabel = new("TextLabel", {
		Font = Fonts.Body,
		Text = "Save Config",
		TextSize = 12,
		TextColor3 = Colors.TextPrimary,
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Parent = saveBtn,
	})
	themed(saveLabel, "TextColor3", "TextPrimary")
	saveBtn.MouseButton1Down:Connect(function()
		tween(saveBtn, Motion.Press, { BackgroundTransparency = 0.35 })
	end)
	saveBtn.MouseButton1Up:Connect(function()
		tween(saveBtn, Motion.Hover, { BackgroundTransparency = 0 })
	end)

	local nameBox = new("TextBox", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, 0, 0.5, 0),
		Size = UDim2.new(0.5, -4, 0, 26),
		BackgroundColor3 = Colors.BgFrame,
		Font = Fonts.SubBody,
		Text = config.DefaultName or "",
		PlaceholderText = "config name...",
		PlaceholderColor3 = Colors.TextTertiary,
		TextColor3 = Colors.TextPrimary,
		TextSize = 11,
		ClearTextOnFocus = false,
		Parent = saveRow,
	})
	themed(nameBox, "BackgroundColor3", "BgFrame")
	themed(nameBox, "TextColor3", "TextPrimary")
	themed(nameBox, "PlaceholderColor3", "TextTertiary")
	corner(nameBox, Radius.Slot)
	stroke(nameBox, 0.85, 1)
	pad(nameBox, nil, 0, 8, 0, 8)

	saveBtn.MouseButton1Click:Connect(function()
		local typedName = nameBox.Text
		local ok, result = Library:SaveConfig(typedName)
		task.spawn(callback, "save", ok and result or typedName, ok, result)
		nameBox.Text = "" -- clear right after saving, ready for the next name (placeholder shows again)
	end)

	-- ---- row 2: Load Config (left) + selection box (right, opens the flyout of saved configs) ----
	local loadRow = baseRow(self, 40)
	local loadBtn = new("TextButton", {
		Size = UDim2.new(0.5, -4, 1, 0),
		BackgroundColor3 = Colors.BgFrame,
		AutoButtonColor = false,
		Text = "",
		Parent = loadRow,
	})
	themed(loadBtn, "BackgroundColor3", "BgFrame")
	corner(loadBtn, Radius.Slot)
	stroke(loadBtn, 0.85, 1)
	local loadLabel = new("TextLabel", {
		Font = Fonts.Body,
		Text = "Load Config",
		TextSize = 12,
		TextColor3 = Colors.AccentBlue,
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Parent = loadBtn,
	})
	themed(loadLabel, "TextColor3", "AccentBlue")

	local selectBtn = new("TextButton", {
		Name = "ConfigSelectBox",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, 0, 0.5, 0),
		Size = UDim2.new(0.5, -4, 0, 26),
		BackgroundColor3 = Colors.BgFrame,
		AutoButtonColor = false,
		Text = "",
		Parent = loadRow,
	})
	themed(selectBtn, "BackgroundColor3", "BgFrame")
	corner(selectBtn, Radius.Slot)
	stroke(selectBtn, 0.85, 1)
	local selectLabel = new("TextLabel", {
		Font = Fonts.SubBody,
		Text = "None",
		TextSize = 11,
		TextColor3 = Colors.TextSecondary,
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Parent = selectBtn,
	})
	themed(selectLabel, "TextColor3", "TextSecondary")

	local selected = nil

	-- ---- the flyout: same Overlay-parented pattern as Dropdown/MultiDropdown/ColorPicker (MASTER.md §12's
	-- four rules), except its rows are rebuilt fresh on every open instead of fixed at widget-creation time
	-- — unlike those widgets' static option lists, the saved-config set can change between opens (a save,
	-- or a delete from this same panel).
	local overlay = self.Window.Overlay
	local sheet = overlay.Parent
	local flyoutWidth = 150
	local rowHeight = 26

	local list = new("Frame", {
		Name = "ConfigList",
		Active = true,
		ClipsDescendants = true,
		Visible = false,
		BackgroundTransparency = 1,
		ZIndex = 10,
		AnchorPoint = Vector2.new(1, 0),
		Size = UDim2.fromOffset(flyoutWidth, 0),
		BackgroundColor3 = Colors.BgFrame,
		Parent = overlay,
	})
	themed(list, "BackgroundColor3", "BgFrame")
	corner(list, Radius.Slot)
	stroke(list, 0.85, 1)
	new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Parent = list })

	local open = false
	local setOpen -- forward-declared; rebuildRows (below) needs to call it to close-on-pick
	local currentHeight = 0 -- last height rebuildRows computed; `reposition` below needs it outside setOpen's own scope

	local function rebuildRows()
		for _, child in ipairs(list:GetChildren()) do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
		local names = Library:ListConfigs()
		for i, cfgName in ipairs(names) do
			local optRow = new("Frame", {
				Size = UDim2.new(1, 0, 0, rowHeight),
				BackgroundTransparency = 1,
				LayoutOrder = i,
				ZIndex = 10,
				Parent = list,
			})
			local optBtn = new("TextButton", {
				Name = "LoadOption",
				Size = UDim2.new(1, -22, 1, 0),
				BackgroundTransparency = 1,
				Text = "",
				ZIndex = 10,
				Parent = optRow,
			})
			pad(optBtn, nil, 0, 0, 0, 8)
			local optLabel = new("TextLabel", {
				Font = Fonts.SubBody,
				Text = cfgName,
				TextSize = 11,
				TextColor3 = Colors.TextSecondary,
				TextXAlignment = Enum.TextXAlignment.Left,
				BackgroundTransparency = 1,
				Size = UDim2.fromScale(1, 1),
				ZIndex = 11,
				Parent = optBtn,
			})
			themed(optLabel, "TextColor3", "TextSecondary")
			local delBtn = new("TextButton", {
				Name = "DeleteOption",
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -4, 0.5, 0),
				Size = UDim2.fromOffset(16, 16),
				BackgroundTransparency = 1,
				Text = "×",
				Font = Fonts.SubBody,
				TextSize = 13,
				TextColor3 = Colors.AccentRed,
				ZIndex = 11,
				Parent = optRow,
			})
			themed(delBtn, "TextColor3", "AccentRed")

			-- Picking a row only loads it INTO the selection box — it does not call Library:LoadConfig.
			-- "Load Config" (the button on this row's other half) is the deliberate commit step.
			optBtn.MouseButton1Click:Connect(function()
				selected = cfgName
				selectLabel.Text = cfgName
				setOpen(false)
			end)
			delBtn.MouseButton1Click:Connect(function()
				Library:DeleteConfig(cfgName)
				if selected == cfgName then
					-- the box was pointing at a config that no longer exists — clear it rather than let
					-- "Load Config" silently try (and fail) to load a file that was just deleted out from
					-- under it.
					selected = nil
					selectLabel.Text = "None"
				end
				-- refresh in place (keep the flyout open so deleting several in a row works), and resize/
				-- reposition to match — a discarded rebuildRows() height here previously left the flyout's
				-- own Size stale against its new row count (caught live, see SESSION_NOTES.md).
				currentHeight = rebuildRows()
				positionFlyout(sheet, selectBtn, list, currentHeight)
				tween(list, Motion.Tab, { Size = UDim2.fromOffset(flyoutWidth, currentHeight) })
			end)
		end
		if #names == 0 then
			local emptyLabel = new("TextLabel", {
				Font = Fonts.SubBody,
				Text = "No saved configs",
				TextSize = 11,
				TextColor3 = Colors.TextTertiary,
				TextXAlignment = Enum.TextXAlignment.Left,
				BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 0, rowHeight),
				ZIndex = 10,
				Parent = list,
			})
			themed(emptyLabel, "TextColor3", "TextTertiary")
		end
		return math.max(#names, 1) * rowHeight
	end

	setOpen = function(value)
		if open == value then
			return
		end
		if value then
			-- see MASTER.md §12 rule 4 / bug #15: call this BEFORE flipping `open`, so a self-referential
			-- call (this exact widget still being the last-registered closer) sees the true pre-transition
			-- state and no-ops instead of recursing into its own close branch mid-open.
			self.Window.CloseActiveFlyout()
		end
		open = value
		if open then
			self.Window.CloseActiveFlyout = function()
				if open then
					setOpen(false)
				end
			end
			currentHeight = rebuildRows()
			positionFlyout(sheet, selectBtn, list, currentHeight)
			list.Visible = true
			tween(list, Motion.Tab, { Size = UDim2.fromOffset(flyoutWidth, currentHeight), BackgroundTransparency = 0 })
		else
			local closeTween = tween(list, Motion.Tab, { Size = UDim2.fromOffset(flyoutWidth, 0), BackgroundTransparency = 1 })
			closeTween.Completed:Connect(function(state)
				if state == Enum.PlaybackState.Completed and not open then
					list.Visible = false
				end
			end)
		end
	end

	-- same live-reposition fix as Dropdown/MultiDropdown/ColorPicker: without this, an open saved-config
	-- flyout stayed anchored to wherever it was at open-time and drifted from `selectBtn` the moment the
	-- dock collapsed/expanded or the window got resized underneath it.
	local function reposition()
		if open then
			positionFlyout(sheet, selectBtn, list, currentHeight)
		end
	end
	selectBtn:GetPropertyChangedSignal("AbsolutePosition"):Connect(reposition)
	-- captured (unlike selectBtn's own connection, which auto-disconnects with `loadRow`) so Destroy below
	-- can drop it explicitly — it's rooted on the window's `sheet`, which outlives this one widget.
	local sheetResizeConn = sheet:GetPropertyChangedSignal("AbsoluteSize"):Connect(reposition)

	selectBtn.MouseButton1Click:Connect(function()
		setOpen(not open)
	end)

	loadBtn.MouseButton1Down:Connect(function()
		tween(loadBtn, Motion.Press, { BackgroundTransparency = 0.2 })
	end)
	loadBtn.MouseButton1Up:Connect(function()
		tween(loadBtn, Motion.Hover, { BackgroundTransparency = 0 })
	end)
	loadBtn.MouseButton1Click:Connect(function()
		if not selected then
			task.spawn(callback, "load", nil, false, "no config selected")
			return
		end
		local ok, err = Library:LoadConfig(selected)
		task.spawn(callback, "load", selected, ok, err)
	end)

	-- No SetEnabled/SetName here — this is a two-row action panel with no single value or label to point
	-- either at (unlike every other widget, which is exactly one row with one name). SetVisible/Destroy
	-- still make sense (and are cheap), just applied to both rows instead of a labelBlock/disableOverlay
	-- this widget never built.
	return {
		Type = "ConfigManager",
		Refresh = rebuildRows,
		SetVisible = function(_, visible)
			saveRow.Visible = visible
			loadRow.Visible = visible
		end,
		Destroy = function()
			sheetResizeConn:Disconnect()
			saveRow:Destroy()
			loadRow:Destroy()
			list:Destroy()
		end,
	}
end

function TabMeta:CreateMultiDropdown(config)
	config = config or {}
	local name = config.Name or "Dropdown"
	local options = config.Options or {}
	local selected = {}
	for _, v in ipairs(config.CurrentOptions or {}) do
		selected[v] = true
	end
	local callback = config.Callback or function() end
	local searchable = config.Searchable == true
	local maxVisible = math.max(1, tonumber(config.MaxVisible) or 6)

	local row, disableOverlay = baseRow(self, 40)
	local block, titleLabel, descLabel = labelBlock(row, name, config.Description)

	local btn = new("TextButton", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, 0, 0.5, 0),
		Size = UDim2.fromOffset(96, 26),
		BackgroundColor3 = Colors.BgFrame,
		AutoButtonColor = false,
		Text = "",
		Parent = row,
	})
	themed(btn, "BackgroundColor3", "BgFrame")
	corner(btn, Radius.Slot)
	stroke(btn, 0.85, 1)
	local btnLabel = new("TextLabel", {
		Font = Fonts.SubBody,
		Text = "",
		TextSize = 11,
		TextColor3 = Colors.TextPrimary,
		TextTruncate = Enum.TextTruncate.AtEnd,
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Parent = btn,
	})
	themed(btnLabel, "TextColor3", "TextPrimary")

	local function getSelected()
		local result = {}
		for _, option in ipairs(options) do
			if selected[option] then
				table.insert(result, option)
			end
		end
		return result
	end

	local function sameSelection(left, right)
		if #left ~= #right then
			return false
		end
		for i, value in ipairs(left) do
			if right[i] ~= value then
				return false
			end
		end
		return true
	end

	local function refreshLabel()
		local names = getSelected()
		btnLabel.Text = #names == 0 and "None" or table.concat(names, ", ")
	end
	refreshLabel()

	local overlay = self.Window.Overlay
	local sheet = overlay.Parent

	local flyoutWidth = 140
	local searchH = searchable and 26 or 0
	local listHeight = searchH + (math.min(#options, maxVisible) * 24)

	local list = new("Frame", {
		Name = "OptionList",
		Active = true,
		ClipsDescendants = true,
		Visible = false,
		BackgroundTransparency = 1,
		ZIndex = 10,
		AnchorPoint = Vector2.new(1, 0),
		Size = UDim2.fromOffset(flyoutWidth, 0),
		BackgroundColor3 = Colors.BgFrame,
		Parent = overlay,
	})
	themed(list, "BackgroundColor3", "BgFrame")
	corner(list, Radius.Slot)
	stroke(list, 0.85, 1)
	new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Parent = list })

	local searchBox
	if searchable then
		local searchRow = new("Frame", {
			Name = "SearchRow",
			Size = UDim2.new(1, 0, 0, 26),
			BackgroundTransparency = 1,
			LayoutOrder = 0,
			ZIndex = 10,
			Parent = list,
		})
		searchBox = new("TextBox", {
			Name = "SearchBox",
			Font = Fonts.SubBody,
			PlaceholderText = "Search...",
			PlaceholderColor3 = Colors.TextTertiary,
			TextColor3 = Colors.TextPrimary,
			TextSize = 10,
			Text = "",
			ClearTextOnFocus = false,
			BackgroundTransparency = 1,
			Size = UDim2.new(1, -12, 1, 0),
			Position = UDim2.fromOffset(6, 0),
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 11,
			Parent = searchRow,
		})
		themed(searchBox, "TextColor3", "TextPrimary")
		themed(searchBox, "PlaceholderColor3", "TextTertiary")
		local div = new("Frame", {
			Name = "SearchDivider",
			Size = UDim2.new(1, 0, 0, 1),
			Position = UDim2.new(0, 0, 1, -1),
			BackgroundColor3 = Colors.BorderSubtle,
			BackgroundTransparency = 0.5,
			BorderSizePixel = 0,
			ZIndex = 11,
			Parent = searchRow,
		})
		themed(div, "BackgroundColor3", "BorderSubtle")
	end

	local scroll = new("ScrollingFrame", {
		Name = "OptionScroll",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 2,
		ScrollBarImageColor3 = Colors.BorderSubtle,
		ScrollBarImageTransparency = 0.3,
		CanvasPosition = Vector2.new(0, 0),
		Size = UDim2.new(1, 0, 1, -searchH),
		CanvasSize = UDim2.new(0, 0, 0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ZIndex = 10,
		Parent = list,
	})
	themed(scroll, "ScrollBarImageColor3", "BorderSubtle")
	new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Parent = scroll })

	local noResultsLabel
	if searchable then
		noResultsLabel = new("TextLabel", {
			Font = Fonts.SubBody,
			Text = "No matches",
			TextSize = 10,
			TextColor3 = Colors.TextTertiary,
			TextXAlignment = Enum.TextXAlignment.Center,
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 24),
			Visible = false,
			ZIndex = 10,
			Parent = scroll,
		})
		themed(noResultsLabel, "TextColor3", "TextTertiary")
	end

	local checks = {}
	local optButtons = {}
	local open = false
	local setOpen
	local control

	local function filterOptions(query)
		query = string.lower(query or "")
		local matchCount = 0
		for option, optBtn in pairs(optButtons) do
			local visible = query == "" or string.find(string.lower(option), query, 1, true) ~= nil
			optBtn.Visible = visible
			if visible then
				matchCount += 1
			end
		end
		if noResultsLabel then
			noResultsLabel.Visible = (matchCount == 0 and query ~= "")
			if matchCount == 0 and query ~= "" then
				matchCount = 1
			end
		end
		return matchCount
	end

	local function rebuildOptions()
		for _, child in ipairs(scroll:GetChildren()) do
			if child:IsA("TextButton") then
				child:Destroy()
			end
		end
		checks = {}
		optButtons = {}
		for i, option in ipairs(options) do
			local opt = new("TextButton", {
				Size = UDim2.new(1, 0, 0, 24),
				BackgroundTransparency = 1,
				Text = "",
				LayoutOrder = i,
				ZIndex = 10,
				Parent = scroll,
			})
			local check = new("Frame", {
				Name = "Check",
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.new(0, 8, 0.5, 0),
				Size = UDim2.fromOffset(14, 14),
				BackgroundColor3 = selected[option] and Colors.AccentBlue or Colors.BgFrame,
				ZIndex = 11,
				Parent = opt,
			})
			corner(check, 4)
			stroke(check, 0.7, 1)
			local optLabel = new("TextLabel", {
				Font = Fonts.SubBody,
				Text = option,
				TextSize = 11,
				TextColor3 = Colors.TextSecondary,
				TextXAlignment = Enum.TextXAlignment.Left,
				BackgroundTransparency = 1,
				Position = UDim2.fromOffset(28, 0),
				Size = UDim2.new(1, -32, 1, 0),
				ZIndex = 11,
				Parent = opt,
			})
			themed(optLabel, "TextColor3", "TextSecondary")
			checks[option] = check
			optButtons[option] = opt
			opt.MouseButton1Click:Connect(function()
				selected[option] = not selected[option]
				tween(check, Motion.Tab, { BackgroundColor3 = selected[option] and Colors.AccentBlue or Colors.BgFrame })
				refreshLabel()
				local result = getSelected()
				if control then
					control:__EmitChanged(result)
				end
				task.spawn(callback, result)
			end)
		end
		local count = filterOptions(searchBox and searchBox.Text or "")
		listHeight = searchH + (math.min(count, maxVisible) * 24)
	end

	local function reposition()
		if open then
			positionFlyout(sheet, btn, list, listHeight)
		end
	end

	local function setOpenImpl(value)
		if open == value then
			return
		end
		if value then
			self.Window.CloseActiveFlyout()
		end
		open = value
		if open then
			self.Window.CloseActiveFlyout = function()
				if open then
					setOpen(false)
				end
			end
			if searchBox then
				searchBox.Text = ""
			end
			scroll.CanvasPosition = Vector2.new(0, 0)
			local count = filterOptions("")
			listHeight = searchH + (math.min(count, maxVisible) * 24)
			positionFlyout(sheet, btn, list, listHeight)
			list.Visible = true
			tween(list, Motion.Tab, { Size = UDim2.fromOffset(flyoutWidth, listHeight), BackgroundTransparency = 0 })
		else
			local closeTween = tween(list, Motion.Tab, { Size = UDim2.fromOffset(flyoutWidth, 0), BackgroundTransparency = 1 })
			closeTween.Completed:Connect(function(state)
				if state == Enum.PlaybackState.Completed and not open then
					list.Visible = false
				end
			end)
		end
	end
	setOpen = setOpenImpl

	if searchBox then
		searchBox:GetPropertyChangedSignal("Text"):Connect(function()
			if not open then return end
			local count = filterOptions(searchBox.Text)
			listHeight = searchH + (math.min(count, maxVisible) * 24)
			positionFlyout(sheet, btn, list, listHeight)
			tween(list, Motion.Tab, { Size = UDim2.fromOffset(flyoutWidth, listHeight) })
		end)
	end

	rebuildOptions()
	btn:GetPropertyChangedSignal("AbsolutePosition"):Connect(reposition)
	local sheetResizeConn = sheet:GetPropertyChangedSignal("AbsoluteSize"):Connect(reposition)

	onTheme(function()
		for option, check in pairs(checks) do
			check.BackgroundColor3 = selected[option] and Colors.AccentBlue or Colors.BgFrame
		end
	end)

	btn.MouseButton1Click:Connect(function()
		setOpen(not open)
	end)

	control = {
		Type = "MultiDropdown",
		Set = function(_, optionsList)
			local previous = getSelected()
			optionsList = optionsList or {}
			for k in pairs(selected) do
				selected[k] = nil
			end
			for _, v in ipairs(optionsList) do
				selected[v] = true
			end
			for option, check in pairs(checks) do
				check.BackgroundColor3 = selected[option] and Colors.AccentBlue or Colors.BgFrame
			end
			refreshLabel()
			local result = getSelected()
			if not sameSelection(previous, result) then
				control:__EmitChanged(result)
			end
			task.spawn(callback, result)
		end,
		Get = getSelected,
		Refresh = function(_, newOptions)
			local previous = getSelected()
			options = newOptions or {}
			local stillValid = {}
			for _, o in ipairs(options) do
				stillValid[o] = true
			end
			for o in pairs(selected) do
				if not stillValid[o] then
					selected[o] = nil
				end
			end
			rebuildOptions()
			refreshLabel()
			local result = getSelected()
			if not sameSelection(previous, result) then
				control:__EmitChanged(result)
			end
			if open then
				positionFlyout(sheet, btn, list, listHeight)
				tween(list, Motion.Tab, { Size = UDim2.fromOffset(flyoutWidth, listHeight) })
			end
		end,
	}
	if config.Flag then
		Library.Flags[config.Flag] = control
	end
	attachLifecycle(control, row, disableOverlay, titleLabel, descLabel, block, config.Flag)
	local baseDestroy = control.Destroy
	control.Destroy = function()
		sheetResizeConn:Disconnect()
		list:Destroy()
		baseDestroy()
	end
	return control
end

function TabMeta:CreateColorPicker(config)
	config = config or {}
	local name = config.Name or "Color"
	local default = config.CurrentColor or Color3.fromRGB(255, 255, 255)
	local callback = config.Callback or function() end

	local row, disableOverlay = baseRow(self, 40)
	local block, titleLabel, descLabel = labelBlock(row, name, config.Description)

	local swatch = new("TextButton", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, 0, 0.5, 0),
		Size = UDim2.fromOffset(40, 26),
		BackgroundColor3 = default,
		AutoButtonColor = false,
		Text = "",
		Parent = row,
	})
	corner(swatch, Radius.Slot)
	stroke(swatch, 0.7, 1.2)

	local overlay = self.Window.Overlay
	local sheet = overlay.Parent

	local panelSize = Vector2.new(180, 190)
	local panel = new("Frame", {
		Name = "ColorPanel",
		Active = true,
		ClipsDescendants = true,
		Visible = false,
		BackgroundTransparency = 1,
		ZIndex = 10,
		AnchorPoint = Vector2.new(1, 0),
		Size = UDim2.fromOffset(panelSize.X, 0),
		BackgroundColor3 = Colors.BgFrame,
		Parent = overlay, -- same overlay-parenting fix as CreateDropdown/CreateMultiDropdown
	})
	themed(panel, "BackgroundColor3", "BgFrame")
	corner(panel, Radius.Slot)
	stroke(panel, 0.85, 1)
	pad(panel, 10)

	-- SV square: base color is the pure hue; two overlaid frames fake the saturation/value gradient
	-- using UIGradient *Transparency* sequences (not Color sequences) — the standard zero-asset technique.
	-- Layer 1 (white, transparency 0->1 left-to-right) fades from opaque white (low saturation) to fully
	-- transparent (reveals the pure hue beneath, full saturation). Layer 2 (black, transparency 1->0
	-- top-to-bottom via Rotation=90) fades from fully transparent (full value/brightness) at the top to
	-- opaque black (value=0) at the bottom.
	local svBox = new("Frame", {
		Size = UDim2.new(1, 0, 0, 110),
		BackgroundColor3 = Color3.fromHSV(0, 1, 1),
		ClipsDescendants = true,
		ZIndex = 11,
		Parent = panel,
	})
	corner(svBox, 6)
	local satOverlay = new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		ZIndex = 12,
		Parent = svBox,
	})
	new("UIGradient", { Transparency = NumberSequence.new(0, 1), Parent = satOverlay })
	local valOverlay = new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BorderSizePixel = 0,
		ZIndex = 13,
		Parent = svBox,
	})
	new("UIGradient", { Rotation = 90, Transparency = NumberSequence.new(1, 0), Parent = valOverlay })
	local svCursor = new("Frame", {
		Name = "Cursor",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(10, 10),
		BackgroundColor3 = Color3.new(1, 1, 1),
		ZIndex = 14,
		Parent = svBox,
	})
	corner(svCursor, Radius.Pill)
	stroke(svCursor, 0, 1.5)
	local svButton = new("TextButton", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = "",
		ZIndex = 15,
		Parent = svBox,
	})

	-- hue strip: a single rainbow ColorSequence, standard and cheap (no per-frame construction needed)
	local hueBar = new("Frame", {
		Position = UDim2.new(0, 0, 0, 118),
		Size = UDim2.new(1, 0, 0, 16),
		BackgroundColor3 = Color3.new(1, 1, 1),
		ClipsDescendants = true,
		ZIndex = 11,
		Parent = panel,
	})
	corner(hueBar, Radius.Pill)
	new("UIGradient", {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0 / 6, Color3.fromHSV(0 / 6, 1, 1)),
			ColorSequenceKeypoint.new(1 / 6, Color3.fromHSV(1 / 6, 1, 1)),
			ColorSequenceKeypoint.new(2 / 6, Color3.fromHSV(2 / 6, 1, 1)),
			ColorSequenceKeypoint.new(3 / 6, Color3.fromHSV(3 / 6, 1, 1)),
			ColorSequenceKeypoint.new(4 / 6, Color3.fromHSV(4 / 6, 1, 1)),
			ColorSequenceKeypoint.new(5 / 6, Color3.fromHSV(5 / 6, 1, 1)),
			ColorSequenceKeypoint.new(6 / 6, Color3.fromHSV(6 / 6, 1, 1)),
		}),
		Parent = hueBar,
	})
	local hueCursor = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(4, 20),
		Position = UDim2.new(0, 0, 0.5, 0),
		BackgroundColor3 = Color3.new(1, 1, 1),
		ZIndex = 12,
		Parent = hueBar,
	})
	corner(hueCursor, 2)
	stroke(hueCursor, 0, 1.5)
	local hueButton = new("TextButton", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = "",
		ZIndex = 13,
		Parent = hueBar,
	})

	local hexBox = new("TextBox", {
		Position = UDim2.new(0, 0, 0, 142),
		Size = UDim2.new(1, 0, 0, 26),
		BackgroundColor3 = Colors.BgCard,
		Font = Fonts.Code,
		Text = "",
		TextColor3 = Colors.TextPrimary,
		TextSize = 11,
		ClearTextOnFocus = false,
		ZIndex = 11,
		Parent = panel,
	})
	themed(hexBox, "BackgroundColor3", "BgCard")
	themed(hexBox, "TextColor3", "TextPrimary")
	corner(hexBox, Radius.Slot)
	stroke(hexBox, 0.85, 1)

	local hue, sat, val = default:ToHSV()

	local function currentColor()
		return Color3.fromHSV(hue, sat, val)
	end

	local function updateVisuals()
		svBox.BackgroundColor3 = Color3.fromHSV(hue, 1, 1)
		svCursor.Position = UDim2.new(sat, 0, 1 - val, 0)
		hueCursor.Position = UDim2.new(hue, 0, 0.5, 0)
		swatch.BackgroundColor3 = currentColor()
		local c = currentColor()
		hexBox.Text = string.format("#%02X%02X%02X", math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5))
	end
	updateVisuals()

	local svDragging, hueDragging = false, false

	local control
	local function emitColorChanged(previous)
		local color = currentColor()
		if control and previous ~= color then
			control:__EmitChanged(color)
		end
		return color
	end
	local function updateSV(pos)
		local previous = currentColor()
		local relX = math.clamp((pos.X - svBox.AbsolutePosition.X) / svBox.AbsoluteSize.X, 0, 1)
		local relY = math.clamp((pos.Y - svBox.AbsolutePosition.Y) / svBox.AbsoluteSize.Y, 0, 1)
		sat = relX
		val = 1 - relY
		updateVisuals()
		task.spawn(callback, emitColorChanged(previous))
	end
	local function updateHue(pos)
		local previous = currentColor()
		local relX = math.clamp((pos.X - hueBar.AbsolutePosition.X) / hueBar.AbsoluteSize.X, 0, 1)
		hue = relX
		updateVisuals()
		task.spawn(callback, emitColorChanged(previous))
	end

	svButton.MouseButton1Down:Connect(function(x, y)
		svDragging = true
		updateSV(Vector2.new(x, y))
	end)
	hueButton.MouseButton1Down:Connect(function(x, y)
		hueDragging = true
		updateHue(Vector2.new(x, y))
	end)
	trackConnection(UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			svDragging = false
			hueDragging = false
		end
	end))
	trackConnection(UserInputService.InputChanged:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
			if svDragging then
				updateSV(input.Position)
			elseif hueDragging then
				updateHue(input.Position)
			end
		end
	end))

	hexBox.FocusLost:Connect(function()
		local previous = currentColor()
		local hexStr = hexBox.Text:gsub("#", "")
		if #hexStr == 6 and hexStr:match("^%x+$") then
			local r = tonumber(hexStr:sub(1, 2), 16) / 255
			local g = tonumber(hexStr:sub(3, 4), 16) / 255
			local b = tonumber(hexStr:sub(5, 6), 16) / 255
			hue, sat, val = Color3.new(r, g, b):ToHSV()
			updateVisuals()
			task.spawn(callback, emitColorChanged(previous))
		else
			updateVisuals() -- invalid text, snap back to the last valid color
		end
	end)

	local open = false
	local function setOpen(value)
		if open == value then
			return
		end
		if value then
			-- see CreateDropdown's setOpen for why this closes-others call must happen before `open` is
			-- set true (reentrancy: reopening this same widget while it's still the registered closer)
			self.Window.CloseActiveFlyout()
		end
		open = value
		if open then
			self.Window.CloseActiveFlyout = function()
				if open then
					setOpen(false)
				end
			end
			-- this is the panel that was getting clipped by sheet's ClipsDescendants (only the SV square
			-- visible, hue bar + hex box cut off) — panelSize.Y (190) is tall enough to regularly overflow
			-- past the sheet's bottom edge when the color picker row sits low in a tab's list.
			positionFlyout(sheet, swatch, panel, panelSize.Y)
			panel.Visible = true
			tween(panel, Motion.Tab, { Size = UDim2.fromOffset(panelSize.X, panelSize.Y), BackgroundTransparency = 0 })
		else
			local closeTween = tween(panel, Motion.Tab, { Size = UDim2.fromOffset(panelSize.X, 0), BackgroundTransparency = 1 })
			closeTween.Completed:Connect(function(state)
				if state == Enum.PlaybackState.Completed and not open then
					panel.Visible = false
				end
			end)
		end
	end

	-- same live-reposition fix as Dropdown/MultiDropdown/ConfigManager: without this, an open color panel
	-- stayed anchored to wherever it was at open-time and drifted from `swatch` the moment the dock
	-- collapsed/expanded or the window resized underneath it.
	local function reposition()
		if open then
			positionFlyout(sheet, swatch, panel, panelSize.Y)
		end
	end
	swatch:GetPropertyChangedSignal("AbsolutePosition"):Connect(reposition)
	-- see CreateDropdown's identical comment: captured so this control's overridden Destroy can drop it —
	-- it's rooted on the window's `sheet`, not on anything that dies with `row`.
	local sheetResizeConn = sheet:GetPropertyChangedSignal("AbsoluteSize"):Connect(reposition)

	swatch.MouseButton1Click:Connect(function()
		setOpen(not open)
	end)

	control = {
		Type = "ColorPicker",
		Set = function(_, color)
			local previous = currentColor()
			hue, sat, val = color:ToHSV()
			updateVisuals()
			-- was silently missing: LoadConfig restoring a saved color updated the swatch/panel but never
			-- told the host script to actually re-apply it (e.g. an aura's real color never changed) — same
			-- class of bug as MultiDropdown's Set above, and the one already fixed for Toggle previously.
			task.spawn(callback, emitColorChanged(previous))
		end,
		Get = function()
			return currentColor()
		end,
	}
	if config.Flag then
		Library.Flags[config.Flag] = control
	end
	attachLifecycle(control, row, disableOverlay, titleLabel, descLabel, block, config.Flag)
	-- same override as CreateDropdown/CreateMultiDropdown, same reason: `panel` lives in `Overlay`, not
	-- under `row`.
	local baseDestroy = control.Destroy
	control.Destroy = function()
		sheetResizeConn:Disconnect()
		panel:Destroy()
		baseDestroy()
	end
	return control
end

return Library
