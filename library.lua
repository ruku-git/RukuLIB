--[[
	iOS Roblox UI Lib
	Rayfield-Gen2-shaped developer API, Apple HIG dark-mode + glassmorphism skin.
	Built entirely from Instance.new — no models, no asset dependencies.
	Tokens (color / radius / spacing / motion) mirror MASTER.md 1:1.

	local UI = loadstring(game:HttpGet("..."))()
	local Window = UI:CreateWindow({Name = "iOS Exploit", Subtitle = "Premium Suite"}) -- drag by the header to move it
	local Tab = Window:CreateTab({Name = "Main", Icon = 12345})
	Tab:CreateToggle({Name = "Fly Hack", Flag = "FlyHack", Callback = function(v) print(v) end})
	Tab:CreateSlider({Name = "Speed", Range = {16, 200}, CurrentValue = 16, Flag = "Speed", Callback = function(v) end})
	Tab:CreateDropdown({Name = "Mode", Options = {"Walk", "Noclip"}, Flag = "Mode", Callback = function(v) end})
	Tab:CreateMultiDropdown({Name = "ESP", Options = {"Boxes", "Names"}, Flag = "ESP", Callback = function(list) end})
	Tab:CreateInput({Name = "Player", PlaceholderText = "username", Flag = "Player", Callback = function(v) end})
	Tab:CreateKeybind({Name = "Fly Bind", CurrentKeybind = "F", Flag = "FlyBind", Callback = function() end})
	Tab:CreateColorPicker({Name = "Aura Color", CurrentColor = Color3.new(1, 0, 0), Flag = "AuraColor", Callback = function(c) end})
	Tab:CreateButton({Name = "Test Button", Callback = function() end})
	Tab:CreateConfigManager({DefaultName = "default"}) -- name box + Save, Load opens a flyout of saved configs
	Tab:CreateKeybind({Name = "Toggle Menu", CurrentKeybind = "RightControl", Flag = "MenuToggleBind",
		Callback = function() Window:ToggleVisible() end}) -- Flag'd, so the bind itself persists via SaveConfig

	Library:Notify({Title = "Loaded", Text = "Script ready"})
	Library:SetTheme("Light") -- or "Dark", or a raw {BgFrame = Color3...} table for a fully custom palette
	Library:SaveConfig("default") -- writes every Flag'd control's current value to IOSRobloxUILib_Configs/default.json
	Library:LoadConfig("default") -- reads it back and re-applies (fires each control's Callback too)
	Window:ToggleVisible() -- show/hide the whole window; also driven by the draggable floating button and any Keybind wired to it
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
	local ok, err = pcall(function()
		delfile(path)
	end)
	if not ok then
		return false, "delfile failed: " .. tostring(err)
	end
	return true
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
	notifyGui = new("ScreenGui", {
		Name = "IOSRobloxUILibNotify",
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Global,
		DisplayOrder = 1000, -- above the main window (999) so a toast is never hidden behind it
		Parent = getGuiParent(),
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

function Library:CreateWindow(config)
	config = config or {}
	local windowName = config.Name or "Window"
	local subtitle = config.Subtitle or ""

	local guiParent = getGuiParent()
	for _, child in ipairs(guiParent:GetChildren()) do
		if child.Name == "IOSRobloxUILib" then
			child:Destroy() -- re-running CreateWindow (e.g. re-executing the script) replaces, never stacks
		end
	end

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
		UserInputService.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				dragging = false
			end
		end)
		UserInputService.InputChanged:Connect(function(input)
			if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
				local delta = input.Position - dragStart
				sheet.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
			end
		end)
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
		UserInputService.InputChanged:Connect(function(input)
			if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
				local delta = input.Position - dragStart
				if not moved and delta.Magnitude > DRAG_THRESHOLD then
					moved = true
				end
				floatBtn.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
			end
		end)
		UserInputService.InputEnded:Connect(function(input)
			if dragging and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
				dragging = false
				if not moved then
					requestToggle()
				end
			end
		end)
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

	return Window
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

	slot.MouseButton1Click:Connect(activate)
	slot.MouseEnter:Connect(function()
		if self.ActiveTab ~= Tab then
			tween(slot, Motion.Hover, { BackgroundTransparency = 0.1 })
		end
	end)
	slot.MouseLeave:Connect(function()
		if self.ActiveTab ~= Tab then
			tween(slot, Motion.Hover, { BackgroundTransparency = 0.3 })
		end
	end)

	table.insert(self.Tabs, Tab)
	if #self.Tabs == 1 then
		activate()
	end

	return Tab
end

-- ---- shared row scaffold ----

local function baseRow(tab, height)
	tab.RowCount += 1
	local row = new("Frame", {
		Name = "Row" .. tab.RowCount,
		Size = UDim2.new(1, 0, 0, height or 40),
		BackgroundColor3 = Colors.BgCard,
		BackgroundTransparency = 0.5,
		LayoutOrder = tab.RowCount,
		Parent = tab.Page,
	})
	themed(row, "BackgroundColor3", "BgCard") -- covers every widget's row background in one place
	corner(row, Radius.Card - 2)
	pad(row, nil, 8, 10, 8, 10)
	return row
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
	if desc and desc ~= "" then
		local descLabel = new("TextLabel", {
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
	return block
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
	local row = baseRow(self, 24)
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
	return row
end

function TabMeta:CreateToggle(config)
	config = config or {}
	local name = config.Name or "Toggle"
	local default = config.CurrentValue == true
	local callback = config.Callback or function() end

	local row = baseRow(self, 40)
	labelBlock(row, name, config.Description)

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

	local function set(value, fireCallback)
		state = value
		tween(track, Motion.Toggle, { BackgroundColor3 = state and Colors.AccentGreen or Colors.BorderSubtle })
		tween(thumb, Motion.Toggle, { Position = UDim2.fromOffset(state and 22 or 2, 2) })
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

	local control = {
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
	return control
end

function TabMeta:CreateButton(config)
	config = config or {}
	local name = config.Name or "Button"
	local callback = config.Callback or function() end

	local row = baseRow(self, 36)
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

	btn.MouseButton1Down:Connect(function()
		tween(row, Motion.Press, { BackgroundTransparency = 0.2 })
	end)
	btn.MouseButton1Up:Connect(function()
		tween(row, Motion.Hover, { BackgroundTransparency = 0.5 })
	end)
	btn.MouseButton1Click:Connect(function()
		task.spawn(callback)
	end)

	return row
end

function TabMeta:CreateSlider(config)
	config = config or {}
	local name = config.Name or "Slider"
	local min = config.Range and config.Range[1] or 0
	local max = config.Range and config.Range[2] or 100
	local increment = config.Increment or 1
	local value = config.CurrentValue or min
	local callback = config.Callback or function() end

	local row = baseRow(self, 46)
	local nameLabel = new("TextLabel", {
		Font = Fonts.Body,
		Text = name,
		TextSize = 13,
		TextColor3 = Colors.TextPrimary,
		TextXAlignment = Enum.TextXAlignment.Left,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -40, 0, 16),
		Parent = row,
	})
	themed(nameLabel, "TextColor3", "TextPrimary")
	local valueLabel = new("TextLabel", {
		Font = Fonts.SubBody,
		Text = tostring(value),
		TextSize = 11,
		TextColor3 = Colors.TextSecondary,
		TextXAlignment = Enum.TextXAlignment.Right,
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 0),
		Size = UDim2.fromOffset(40, 16),
		Parent = row,
	})
	themed(valueLabel, "TextColor3", "TextSecondary")

	local track = new("Frame", {
		Position = UDim2.fromOffset(0, 26),
		Size = UDim2.new(1, 0, 0, 6),
		BackgroundColor3 = Colors.BorderSubtle,
		Parent = row,
	})
	themed(track, "BackgroundColor3", "BorderSubtle")
	corner(track, Radius.Pill)

	local fill = new("Frame", {
		Size = UDim2.fromScale((value - min) / (max - min), 1),
		BackgroundColor3 = Colors.AccentBlue,
		Parent = track,
	})
	themed(fill, "BackgroundColor3", "AccentBlue")
	corner(fill, Radius.Pill)

	local function setFromAlpha(alpha)
		alpha = math.clamp(alpha, 0, 1)
		local raw = min + (max - min) * alpha
		value = math.clamp(math.floor(raw / increment + 0.5) * increment, min, max)
		local drawAlpha = (value - min) / (max - min)
		tween(fill, Motion.Press, { Size = UDim2.fromScale(drawAlpha, 1) })
		valueLabel.Text = tostring(value)
		task.spawn(callback, value)
	end

	local dragging = false

	local trackButton = new("TextButton", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = "",
		Parent = track,
	})

	trackButton.MouseButton1Down:Connect(function()
		dragging = true
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			local relX = (input.Position.X - track.AbsolutePosition.X) / track.AbsoluteSize.X
			setFromAlpha(relX)
		end
	end)
	local control = {
		Set = function(_, v)
			setFromAlpha((v - min) / (max - min))
		end,
		Get = function()
			return value
		end,
	}
	if config.Flag then
		Library.Flags[config.Flag] = control
	end
	return control
end

function TabMeta:CreateDropdown(config)
	config = config or {}
	local name = config.Name or "Dropdown"
	local options = config.Options or {}
	local current = config.CurrentOption or options[1] or ""
	local callback = config.Callback or function() end

	local row = baseRow(self, 40)
	labelBlock(row, name)

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
		Text = current,
		TextSize = 11,
		TextColor3 = Colors.TextPrimary,
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Parent = btn,
	})
	themed(btnLabel, "TextColor3", "TextPrimary")

	local overlay = self.Window.Overlay
	local sheet = overlay.Parent

	local listHeight = #options * 24
	local list = new("Frame", {
		Name = "OptionList",
		Active = true, -- belt-and-suspenders: still block clicks to whatever's directly behind the flyout
		-- itself, even though the real fix is being parented to `overlay` below instead of nested inside
		-- this dropdown's own row.
		ClipsDescendants = true, -- lets the height tween below double as the open/close reveal
		Visible = false,
		BackgroundTransparency = 1,
		ZIndex = 10,
		AnchorPoint = Vector2.new(1, 0),
		Size = UDim2.fromOffset(96, 0),
		BackgroundColor3 = Colors.BgFrame,
		Parent = overlay, -- NOT `btn` — being nested inside its own row put the flyout in the same branch
		-- as every other row (including Test Button's), and a single click could register on an option
		-- button here AND a button in a completely different row at the same time (confirmed live: giving
		-- the flyout Active=true alone did not stop it). Parenting to the shared top-level `overlay`
		-- instead makes the flyout a fully separate branch from every row, so there's no other row's
		-- button anywhere "behind" it for a click to also land on.
	})
	themed(list, "BackgroundColor3", "BgFrame")
	corner(list, Radius.Slot)
	stroke(list, 0.85, 1)
	new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Parent = list })

	local optLabels = {}
	local open = false

	local function highlight()
		for option, optLabel in pairs(optLabels) do
			tween(optLabel, Motion.Tab, {
				TextColor3 = option == current and Colors.AccentBlue or Colors.TextSecondary,
			})
		end
	end
	onTheme(highlight) -- re-reads current Colors.AccentBlue/TextSecondary so idle (never-reopened) option colors refresh too

	local function setOpen(value)
		if open == value then
			return
		end
		if value then
			-- Close whatever's currently registered as the active flyout BEFORE flipping our own `open`
			-- flag to true. Reopening this exact widget when it's still the last-registered closer (e.g.
			-- after being auto-closed by a tab switch, since closing never resets the registration back to
			-- a no-op) used to call CloseActiveFlyout() with `open` already true — invoking this widget's
			-- OWN stale closure against its own new state, which immediately called setOpen(false) back
			-- into itself and left `open` permanently desynced (stuck reporting closed while the list
			-- stayed visually open forever, ignoring every subsequent click). Calling it while `open` is
			-- still false makes that self-call a safe no-op regardless of ordering.
			self.Window.CloseActiveFlyout()
		end
		open = value
		if open then
			self.Window.CloseActiveFlyout = function()
				if open then
					setOpen(false)
				end
			end
			-- computed fresh on every open, in overlay-local pixel offsets, since `btn` can move (dock
			-- collapse/expand, tab switches) and the flyout no longer inherits `btn`'s position for free.
			-- Also flips above the button (or clamps) instead of always opening below, since `sheet`'s
			-- ClipsDescendants would otherwise silently cut off a flyout that overflows past its bottom
			-- edge (confirmed live: this exact clipping on the color picker panel, same root cause here).
			positionFlyout(sheet, btn, list, listHeight)
			highlight()
			list.Visible = true
			tween(list, Motion.Tab, { Size = UDim2.fromOffset(96, listHeight), BackgroundTransparency = 0 })
		else
			local closeTween = tween(list, Motion.Tab, { Size = UDim2.fromOffset(96, 0), BackgroundTransparency = 1 })
			closeTween.Completed:Connect(function(state)
				if state == Enum.PlaybackState.Completed and not open then
					list.Visible = false
				end
			end)
		end
	end

	for i, option in ipairs(options) do
		local opt = new("TextButton", {
			Size = UDim2.new(1, 0, 0, 24),
			BackgroundTransparency = 1,
			Text = "",
			LayoutOrder = i,
			-- ZIndex is NOT inherited from parent in Roblox — `list` being ZIndex=10 does nothing for
			-- this button's own input priority. Without this, `opt` defaulted to ZIndex=1, tying with
			-- Test Button's own default-ZIndex TextButton. Global ZIndexBehavior breaks same-ZIndex ties
			-- by creation order, which is why clicking "Noclip" was flaky: sometimes the option won,
			-- sometimes Test Button won underneath it, sometimes both fired. Matching `list`'s ZIndex
			-- here makes the option button unambiguously win over any row's default-ZIndex content.
			ZIndex = 10,
			Parent = list,
		})
		local optLabel = new("TextLabel", {
			Font = Fonts.SubBody,
			Text = option,
			TextSize = 11,
			TextColor3 = option == current and Colors.AccentBlue or Colors.TextSecondary,
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			ZIndex = 11,
			Parent = opt,
		})
		optLabels[option] = optLabel
		opt.MouseButton1Click:Connect(function()
			current = option
			btnLabel.Text = option
			setOpen(false)
			highlight()
			task.spawn(callback, current)
		end)
	end

	btn.MouseButton1Click:Connect(function()
		setOpen(not open)
	end)

	local control = {
		Set = function(_, option)
			current = option
			btnLabel.Text = option
			highlight()
			task.spawn(callback, current)
		end,
		Get = function()
			return current
		end,
	}
	if config.Flag then
		Library.Flags[config.Flag] = control
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

	local row = baseRow(self, 40)
	labelBlock(row, name)

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

	local function commit(fireCallback)
		local v = box.Text
		if numbersOnly then
			v = v:gsub("[^%-%.%d]", "")
			box.Text = v
		end
		if fireCallback then
			task.spawn(callback, v)
		end
	end

	box.FocusLost:Connect(function()
		commit(true)
	end)

	local control = {
		Set = function(_, value)
			box.Text = tostring(value)
			commit(false)
		end,
		Get = function()
			return box.Text
		end,
	}
	if config.Flag then
		Library.Flags[config.Flag] = control
	end
	return control
end

function TabMeta:CreateKeybind(config)
	config = config or {}
	local name = config.Name or "Keybind"
	local callback = config.Callback or function() end
	local changedCallback = config.ChangedCallback or function() end
	local currentKey = config.CurrentKeybind and Enum.KeyCode[config.CurrentKeybind] or nil

	local row = baseRow(self, 40)
	labelBlock(row, name)

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
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if listening then
			if input.UserInputType ~= Enum.UserInputType.Keyboard then
				return
			end
			listening = false
			if input.KeyCode == Enum.KeyCode.Escape then
				btnLabel.Text = currentKey and currentKey.Name or "None"
			else
				currentKey = input.KeyCode
				btnLabel.Text = currentKey.Name
				task.spawn(changedCallback, currentKey.Name)
			end
			tween(btnLabel, Motion.Tab, { TextColor3 = Colors.TextPrimary })
			return
		end
		if not gameProcessed and currentKey and input.KeyCode == currentKey then
			task.spawn(callback)
		end
	end)

	local control = {
		Set = function(_, keyName)
			currentKey = keyName and Enum.KeyCode[keyName] or nil
			btnLabel.Text = currentKey and currentKey.Name or "None"
		end,
		Get = function()
			return currentKey and currentKey.Name or nil
		end,
	}
	if config.Flag then
		Library.Flags[config.Flag] = control
	end
	return control
end

-- Named config save/load UI on top of Library:SaveConfig/LoadConfig/ListConfigs/DeleteConfig. Doesn't
-- register a Flag itself (there's no single persisted "value" here — it's an action panel, not a
-- value-holding widget). `config.Callback`, if given, fires as (action, name, ok, err) after a save/load
-- so a host script can toast the result the same way it would for any other widget's Callback.
function TabMeta:CreateConfigManager(config)
	config = config or {}
	local defaultName = config.DefaultName or "default"
	local callback = config.Callback or function() end

	-- ---- row 1: name box + Save ----
	local nameRow = baseRow(self, 40)
	labelBlock(nameRow, "Config Name")

	local nameBox = new("TextBox", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -56, 0.5, 0),
		Size = UDim2.fromOffset(110, 26),
		BackgroundColor3 = Colors.BgFrame,
		Font = Fonts.SubBody,
		Text = defaultName,
		PlaceholderText = "name...",
		PlaceholderColor3 = Colors.TextTertiary,
		TextColor3 = Colors.TextPrimary,
		TextSize = 11,
		ClearTextOnFocus = false,
		Parent = nameRow,
	})
	themed(nameBox, "BackgroundColor3", "BgFrame")
	themed(nameBox, "TextColor3", "TextPrimary")
	themed(nameBox, "PlaceholderColor3", "TextTertiary")
	corner(nameBox, Radius.Slot)
	stroke(nameBox, 0.85, 1)
	pad(nameBox, nil, 0, 8, 0, 8)

	local saveBtn = new("TextButton", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, 0, 0.5, 0),
		Size = UDim2.fromOffset(48, 26),
		BackgroundColor3 = Colors.AccentBlue,
		AutoButtonColor = false,
		Text = "",
		Parent = nameRow,
	})
	themed(saveBtn, "BackgroundColor3", "AccentBlue")
	corner(saveBtn, Radius.Slot)
	local saveLabel = new("TextLabel", {
		Font = Fonts.Body,
		Text = "Save",
		TextSize = 11,
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
	saveBtn.MouseButton1Click:Connect(function()
		local ok, result = Library:SaveConfig(nameBox.Text)
		if ok then
			nameBox.Text = result -- reflect the sanitized final name back (e.g. trimmed, or the "config" fallback)
		end
		task.spawn(callback, "save", nameBox.Text, ok, result)
	end)

	-- ---- row 2: Load (opens the flyout list of saved configs) ----
	local loadRow = baseRow(self, 36)
	local loadBtn = new("TextButton", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
		Parent = loadRow,
	})
	local loadLabel = new("TextLabel", {
		Font = Fonts.Body,
		Text = "Load Config ▾",
		TextSize = 13,
		TextColor3 = Colors.AccentBlue,
		TextXAlignment = Enum.TextXAlignment.Center,
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Parent = loadBtn,
	})
	themed(loadLabel, "TextColor3", "AccentBlue")
	loadBtn.MouseButton1Down:Connect(function()
		tween(loadRow, Motion.Press, { BackgroundTransparency = 0.2 })
	end)
	loadBtn.MouseButton1Up:Connect(function()
		tween(loadRow, Motion.Hover, { BackgroundTransparency = 0.5 })
	end)

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
	local setOpen -- forward-declared; rebuildRows (below) needs to call it to close-on-load

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

			optBtn.MouseButton1Click:Connect(function()
				local ok, err = Library:LoadConfig(cfgName)
				if ok then
					nameBox.Text = cfgName
				end
				task.spawn(callback, "load", cfgName, ok, err)
				setOpen(false)
			end)
			delBtn.MouseButton1Click:Connect(function()
				Library:DeleteConfig(cfgName)
				-- refresh in place (keep the flyout open so deleting several in a row works), and resize/
				-- reposition to match — rebuildRows()'s returned height was previously discarded here, so
				-- e.g. deleting down to a very different row count left the flyout's own Size stale.
				local newHeight = rebuildRows()
				positionFlyout(sheet, loadBtn, list, newHeight)
				tween(list, Motion.Tab, { Size = UDim2.fromOffset(flyoutWidth, newHeight) })
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
			local listHeight = rebuildRows()
			positionFlyout(sheet, loadBtn, list, listHeight)
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

	loadBtn.MouseButton1Click:Connect(function()
		setOpen(not open)
	end)

	return { Refresh = rebuildRows }
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

	local row = baseRow(self, 40)
	labelBlock(row, name)

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

	local function refreshLabel()
		local names = {}
		for _, option in ipairs(options) do
			if selected[option] then
				table.insert(names, option)
			end
		end
		btnLabel.Text = #names == 0 and "None" or table.concat(names, ", ")
	end
	refreshLabel()

	local overlay = self.Window.Overlay
	local sheet = overlay.Parent

	local listHeight = #options * 24
	local list = new("Frame", {
		Name = "OptionList",
		Active = true, -- see CreateDropdown for why: belt-and-suspenders alongside Overlay-parenting below
		ClipsDescendants = true,
		Visible = false,
		BackgroundTransparency = 1,
		ZIndex = 10,
		AnchorPoint = Vector2.new(1, 0),
		Size = UDim2.fromOffset(140, 0),
		BackgroundColor3 = Colors.BgFrame,
		Parent = overlay, -- same overlay-parenting fix as CreateDropdown (bug #6/#7/#8) — never nest a
		-- flyout inside its own row.
	})
	themed(list, "BackgroundColor3", "BgFrame")
	corner(list, Radius.Slot)
	stroke(list, 0.85, 1)
	new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Parent = list })

	local checks = {}
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
			positionFlyout(sheet, btn, list, listHeight) -- see CreateDropdown for why this flips/clamps
			list.Visible = true
			tween(list, Motion.Tab, { Size = UDim2.fromOffset(140, listHeight), BackgroundTransparency = 0 })
		else
			local closeTween = tween(list, Motion.Tab, { Size = UDim2.fromOffset(140, 0), BackgroundTransparency = 1 })
			closeTween.Completed:Connect(function(state)
				if state == Enum.PlaybackState.Completed and not open then
					list.Visible = false
				end
			end)
		end
	end

	for i, option in ipairs(options) do
		local opt = new("TextButton", {
			Size = UDim2.new(1, 0, 0, 24),
			BackgroundTransparency = 1,
			Text = "",
			LayoutOrder = i,
			-- see CreateDropdown's `opt` for why this must be explicit and match `list` (bug #9): ZIndex
			-- is never inherited from parent in Roblox, so this would otherwise default to 1 and tie with
			-- whatever row-content sits behind the flyout.
			ZIndex = 10,
			Parent = list,
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
		opt.MouseButton1Click:Connect(function()
			selected[option] = not selected[option]
			tween(check, Motion.Tab, { BackgroundColor3 = selected[option] and Colors.AccentBlue or Colors.BgFrame })
			refreshLabel()
			local result = {}
			for _, o in ipairs(options) do
				if selected[o] then
					table.insert(result, o)
				end
			end
			task.spawn(callback, result)
		end)
	end
	onTheme(function()
		for option, check in pairs(checks) do
			check.BackgroundColor3 = selected[option] and Colors.AccentBlue or Colors.BgFrame
		end
	end)

	btn.MouseButton1Click:Connect(function()
		setOpen(not open)
	end)

	local control = {
		Set = function(_, optionsList)
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
		end,
		Get = function()
			local result = {}
			for _, o in ipairs(options) do
				if selected[o] then
					table.insert(result, o)
				end
			end
			return result
		end,
	}
	if config.Flag then
		Library.Flags[config.Flag] = control
	end
	return control
end

function TabMeta:CreateColorPicker(config)
	config = config or {}
	local name = config.Name or "Color"
	local default = config.CurrentColor or Color3.fromRGB(255, 255, 255)
	local callback = config.Callback or function() end

	local row = baseRow(self, 40)
	labelBlock(row, name)

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

	local function updateSV(pos)
		local relX = math.clamp((pos.X - svBox.AbsolutePosition.X) / svBox.AbsoluteSize.X, 0, 1)
		local relY = math.clamp((pos.Y - svBox.AbsolutePosition.Y) / svBox.AbsoluteSize.Y, 0, 1)
		sat = relX
		val = 1 - relY
		updateVisuals()
		task.spawn(callback, currentColor())
	end
	local function updateHue(pos)
		local relX = math.clamp((pos.X - hueBar.AbsolutePosition.X) / hueBar.AbsoluteSize.X, 0, 1)
		hue = relX
		updateVisuals()
		task.spawn(callback, currentColor())
	end

	svButton.MouseButton1Down:Connect(function(x, y)
		svDragging = true
		updateSV(Vector2.new(x, y))
	end)
	hueButton.MouseButton1Down:Connect(function(x, y)
		hueDragging = true
		updateHue(Vector2.new(x, y))
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			svDragging = false
			hueDragging = false
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
			if svDragging then
				updateSV(input.Position)
			elseif hueDragging then
				updateHue(input.Position)
			end
		end
	end)

	hexBox.FocusLost:Connect(function()
		local hexStr = hexBox.Text:gsub("#", "")
		if #hexStr == 6 and hexStr:match("^%x+$") then
			local r = tonumber(hexStr:sub(1, 2), 16) / 255
			local g = tonumber(hexStr:sub(3, 4), 16) / 255
			local b = tonumber(hexStr:sub(5, 6), 16) / 255
			hue, sat, val = Color3.new(r, g, b):ToHSV()
			updateVisuals()
			task.spawn(callback, currentColor())
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
	swatch.MouseButton1Click:Connect(function()
		setOpen(not open)
	end)

	local control = {
		Set = function(_, color)
			hue, sat, val = color:ToHSV()
			updateVisuals()
		end,
		Get = function()
			return currentColor()
		end,
	}
	if config.Flag then
		Library.Flags[config.Flag] = control
	end
	return control
end

return Library
