--[[
	Kisha UI Library  v1.0.0
	A generic, self-contained Roblox Luau UI framework.
	No telemetry, no remote auth, no third-party links.

	Sections: Services / Theme / Helpers / Config / Notify / Elements / Window / Library API
]]

------------------------------------------------------------------------
-- Services
------------------------------------------------------------------------
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")

local LocalPlayer = Players.LocalPlayer

local okCore, CoreGui = pcall(game.GetService, game, "CoreGui")
if not okCore then
	CoreGui = nil
end

-- Shared environment (used to tear down a previous load of Kisha on re-execute)
local function getEnv()
	local ok, env = pcall(function()
		return getgenv()
	end)
	if ok and type(env) == "table" then
		return env
	end
	return _G
end
local Env = getEnv()

if Env.__KishaLibrary and type(Env.__KishaLibrary.Destroy) == "function" then
	pcall(function()
		Env.__KishaLibrary:Destroy()
	end)
end

------------------------------------------------------------------------
-- Library table
------------------------------------------------------------------------
local Library = {
	Version = "1.0.0",
	Flags = {},
	Windows = {},
	ConfigFolder = "Kisha/configs",
	-- Optional custom storage: Save = function(name, json) end, Load = function(name) return json end
	ConfigHooks = {},
	_registry = {},
	_gui = nil,
}

------------------------------------------------------------------------
-- Theme
------------------------------------------------------------------------
local Theme = {
	Background = Color3.fromRGB(13, 15, 24),
	Sidebar = Color3.fromRGB(10, 12, 19),
	Card = Color3.fromRGB(18, 21, 33),
	Element = Color3.fromRGB(25, 29, 44),
	ElementHover = Color3.fromRGB(31, 36, 54),
	Stroke = Color3.fromRGB(40, 46, 68),
	Off = Color3.fromRGB(45, 51, 74),
	Text = Color3.fromRGB(238, 241, 250),
	SubText = Color3.fromRGB(139, 148, 173),
	Accent = Color3.fromRGB(62, 112, 255), -- cobalt
	White = Color3.fromRGB(255, 255, 255),
	Font = Enum.Font.Gotham,
	FontBold = Enum.Font.GothamBold,
	WindowRadius = 14,
	ElementRadius = 8,
}

Library.Accent = Theme.Accent

local RowH = UserInputService.TouchEnabled and 40 or 36

------------------------------------------------------------------------
-- Helpers
------------------------------------------------------------------------
local function New(class, props, children)
	local inst = Instance.new(class)
	local parent
	for k, v in pairs(props or {}) do
		if k == "Parent" then
			parent = v
		else
			inst[k] = v
		end
	end
	for _, child in ipairs(children or {}) do
		child.Parent = inst
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end

local function Corner(parent, radius)
	return New("UICorner", { CornerRadius = UDim.new(0, radius or Theme.ElementRadius), Parent = parent })
end

local function Stroke(parent, color, transparency)
	return New("UIStroke", {
		Color = color or Theme.Stroke,
		Thickness = 1,
		Transparency = transparency or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = parent,
	})
end

local function Pad(parent, t, r, b, l)
	return New("UIPadding", {
		PaddingTop = UDim.new(0, t or 0),
		PaddingRight = UDim.new(0, r or t or 0),
		PaddingBottom = UDim.new(0, b or t or 0),
		PaddingLeft = UDim.new(0, l or r or t or 0),
		Parent = parent,
	})
end

local function Label(props)
	local p = {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Font = Theme.Font,
		TextSize = 13,
		TextColor3 = Theme.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
		Text = "",
	}
	for k, v in pairs(props) do
		p[k] = v
	end
	return New("TextLabel", p)
end

local function tween(obj, props, time, style, dir)
	local t = TweenService:Create(
		obj,
		TweenInfo.new(time or 0.15, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out),
		props
	)
	t:Play()
	return t
end

-- Lets every method work with both `obj:Method(x)` and `obj.Method(x)`.
local function method(obj, name, fn)
	obj[name] = function(a, ...)
		if a == obj then
			return fn(obj, ...)
		end
		return fn(obj, a, ...)
	end
end

local function fire(cb, ...)
	if type(cb) == "function" then
		local ok, err = pcall(cb, ...)
		if not ok then
			warn("[Kisha] callback error: " .. tostring(err))
		end
	end
end

local function roundTo(n, inc)
	if not inc or inc <= 0 then
		return n
	end
	local r = math.floor(n / inc + 0.5) * inc
	local decimals = (tostring(inc):match("%.(%d+)")) 
	decimals = decimals and #decimals or 0
	return tonumber(string.format("%." .. decimals .. "f", r)) or r
end

local function register(ctx, flag, kind, setter, initial)
	if not flag then
		return
	end
	Library.Flags[flag] = initial
	Library._registry[flag] = { Kind = kind, Set = setter }
	ctx.flags[#ctx.flags + 1] = flag
end

local function commit(flag, value)
	if flag then
		Library.Flags[flag] = value
	end
end

------------------------------------------------------------------------
-- ScreenGui
------------------------------------------------------------------------
local function getGui()
	if Library._gui and Library._gui.Parent then
		return Library._gui
	end

	local gui = New("ScreenGui", {
		Name = "KishaUI",
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 999,
		IgnoreGuiInset = true,
	})

	local parented = false
	if CoreGui then
		parented = pcall(function()
			gui.Parent = CoreGui
		end) and gui.Parent ~= nil
	end
	if not parented then
		gui.Parent = LocalPlayer:WaitForChild("PlayerGui")
	end

	Library._gui = gui
	return gui
end

------------------------------------------------------------------------
-- Config
------------------------------------------------------------------------
local function fsAvailable()
	return type(writefile) == "function" and type(readfile) == "function" and type(isfile) == "function"
end

local function configPath(name)
	name = tostring(name or "default"):gsub("[^%w_%-%. ]", "_")
	return Library.ConfigFolder .. "/" .. name .. ".json"
end

local function ensureFolders()
	pcall(function()
		if type(makefolder) == "function" and type(isfolder) == "function" then
			local root = Library.ConfigFolder:match("^[^/]+")
			if root and not isfolder(root) then
				makefolder(root)
			end
			if not isfolder(Library.ConfigFolder) then
				makefolder(Library.ConfigFolder)
			end
		end
	end)
end

method(Library, "SaveConfig", function(self, name)
	name = name or "default"
	local data = {}
	for flag, entry in pairs(self._registry) do
		local v = self.Flags[flag]
		if typeof(v) == "EnumItem" then
			v = v.Name
		end
		if v ~= nil then
			data[flag] = v
		end
	end

	local okEnc, json = pcall(function()
		return HttpService:JSONEncode(data)
	end)
	if not okEnc then
		return false
	end

	if type(self.ConfigHooks.Save) == "function" then
		return (pcall(self.ConfigHooks.Save, name, json))
	end
	if not fsAvailable() then
		return false
	end
	ensureFolders()
	return (pcall(writefile, configPath(name), json))
end)

method(Library, "LoadConfig", function(self, name)
	name = name or "default"
	local json
	if type(self.ConfigHooks.Load) == "function" then
		local ok, res = pcall(self.ConfigHooks.Load, name)
		json = ok and res or nil
	elseif fsAvailable() then
		local path = configPath(name)
		local okExists, exists = pcall(isfile, path)
		if okExists and exists then
			local ok, res = pcall(readfile, path)
			json = ok and res or nil
		end
	end
	if type(json) ~= "string" then
		return false
	end

	local ok, data = pcall(function()
		return HttpService:JSONDecode(json)
	end)
	if not ok or type(data) ~= "table" then
		return false
	end

	for flag, value in pairs(data) do
		local entry = self._registry[flag]
		if entry then
			pcall(entry.Set, value)
		end
	end
	return true
end)

------------------------------------------------------------------------
-- Notify
------------------------------------------------------------------------
method(Library, "Notify", function(self, opts)
	opts = opts or {}
	local gui = getGui()
	local accent = self.Accent or Theme.Accent
	local duration = tonumber(opts.Duration) or 4

	local holder = gui:FindFirstChild("KishaToasts")
	if not holder then
		holder = New("Frame", {
			Name = "KishaToasts",
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -16, 0, 16),
			Size = UDim2.new(0, 280, 1, -32),
			BackgroundTransparency = 1,
			Parent = gui,
		})
		New("UIListLayout", {
			Padding = UDim.new(0, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
			VerticalAlignment = Enum.VerticalAlignment.Bottom,
			HorizontalAlignment = Enum.HorizontalAlignment.Right,
			Parent = holder,
		})
	end

	local wrapper = New("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = os.clock() * 1000 // 1,
		Parent = holder,
	})

	local toast = New("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		Position = UDim2.new(1, 60, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Theme.Card,
		BorderSizePixel = 0,
		Parent = wrapper,
	})
	Corner(toast, 12)
	Stroke(toast, Theme.Stroke)
	Pad(toast, 12)
	New("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder, Parent = toast })

	Label({
		Text = tostring(opts.Title or "Kisha"),
		Font = Theme.FontBold,
		TextSize = 14,
		Size = UDim2.new(1, 0, 0, 18),
		LayoutOrder = 1,
		Parent = toast,
	})
	if opts.Content then
		Label({
			Text = tostring(opts.Content),
			TextSize = 12,
			TextColor3 = Theme.SubText,
			TextWrapped = true,
			TextYAlignment = Enum.TextYAlignment.Top,
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			LayoutOrder = 2,
			Parent = toast,
		})
	end

	local track = New("Frame", {
		Size = UDim2.new(1, 0, 0, 3),
		BackgroundColor3 = Theme.Off,
		LayoutOrder = 3,
		Parent = toast,
	})
	Corner(track, 2)
	local fill = New("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = accent, Parent = track })
	Corner(fill, 2)

	tween(toast, { Position = UDim2.new(0, 0, 0, 0) }, 0.3, Enum.EasingStyle.Quint)
	tween(fill, { Size = UDim2.new(0, 0, 1, 0) }, duration, Enum.EasingStyle.Linear)

	task.delay(duration, function()
		if not toast.Parent then
			return
		end
		tween(toast, { Position = UDim2.new(1, 60, 0, 0) }, 0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
		task.wait(0.3)
		wrapper:Destroy()
	end)
end)

------------------------------------------------------------------------
-- Elements (built per Section)
------------------------------------------------------------------------
local function buildSection(ctx, page, container, sectionObj)
	local order = 0
	local function nextOrder()
		order += 1
		return order
	end

	local function Row(height)
		local row = New("Frame", {
			Size = UDim2.new(1, 0, 0, height or RowH),
			BackgroundColor3 = Theme.Element,
			BorderSizePixel = 0,
			LayoutOrder = nextOrder(),
			Parent = container,
		})
		Corner(row)
		Stroke(row, Theme.Stroke, 0.4)
		row.MouseEnter:Connect(function()
			tween(row, { BackgroundColor3 = Theme.ElementHover }, 0.12)
		end)
		row.MouseLeave:Connect(function()
			tween(row, { BackgroundColor3 = Theme.Element }, 0.12)
		end)
		return row
	end

	local function Hit(row)
		return New("TextButton", {
			Name = "Hit",
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Text = "",
			AutoButtonColor = false,
			ZIndex = 2,
			Parent = row,
		})
	end

	local function finish(el, row, flag)
		el.Instance = row
		method(el, "Destroy", function()
			if flag then
				Library.Flags[flag] = nil
				Library._registry[flag] = nil
			end
			row:Destroy()
		end)
		return el
	end

	-- Toggle ----------------------------------------------------------
	method(sectionObj, "AddToggle", function(_, o)
		o = o or {}
		local row = Row()
		Label({
			Text = o.Name or "Toggle",
			Position = UDim2.fromOffset(12, 0),
			Size = UDim2.new(1, -70, 1, 0),
			TextTruncate = Enum.TextTruncate.AtEnd,
			Parent = row,
		})
		local sw = New("Frame", {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -12, 0.5, 0),
			Size = UDim2.fromOffset(40, 20),
			BackgroundColor3 = Theme.Off,
			Parent = row,
		})
		Corner(sw, 10)
		local knob = New("Frame", {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 3, 0.5, 0),
			Size = UDim2.fromOffset(14, 14),
			BackgroundColor3 = Theme.White,
			Parent = sw,
		})
		Corner(knob, 7)
		local hit = Hit(row)

		local el = { Value = o.Default and true or false, Flag = o.Flag, Type = "Toggle" }

		local function render(time)
			tween(sw, { BackgroundColor3 = el.Value and ctx.accent or Theme.Off }, time)
			tween(knob, {
				Position = el.Value and UDim2.new(1, -17, 0.5, 0) or UDim2.new(0, 3, 0.5, 0),
			}, time)
		end

		method(el, "Set", function(_, v, silent)
			el.Value = v and true or false
			commit(o.Flag, el.Value)
			render(0.15)
			if not silent then
				fire(o.Callback, el.Value)
			end
		end)
		method(el, "Get", function()
			return el.Value
		end)

		hit.MouseButton1Click:Connect(function()
			el:Set(not el.Value)
		end)
		ctx.bind(function()
			render(0)
		end)
		register(ctx, o.Flag, "toggle", function(v)
			el:Set(v)
		end, el.Value)
		return finish(el, row, o.Flag)
	end)

	-- Slider ----------------------------------------------------------
	method(sectionObj, "AddSlider", function(_, o)
		o = o or {}
		local min, max = o.Min or 0, o.Max or 100
		local inc = o.Increment or 1
		local row = Row(54)

		Label({
			Text = o.Name or "Slider",
			Position = UDim2.fromOffset(12, 6),
			Size = UDim2.new(1, -90, 0, 18),
			TextTruncate = Enum.TextTruncate.AtEnd,
			Parent = row,
		})
		local valueLabel = Label({
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -12, 0, 6),
			Size = UDim2.fromOffset(70, 18),
			TextXAlignment = Enum.TextXAlignment.Right,
			TextColor3 = Theme.SubText,
			Parent = row,
		})
		local track = New("Frame", {
			Position = UDim2.new(0, 12, 0, 36),
			Size = UDim2.new(1, -24, 0, 6),
			BackgroundColor3 = Theme.Off,
			Parent = row,
		})
		Corner(track, 3)
		local fill = New("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = ctx.accent, Parent = track })
		Corner(fill, 3)
		local knob = New("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(1, 0.5),
			Size = UDim2.fromOffset(12, 12),
			BackgroundColor3 = Theme.White,
			Parent = fill,
		})
		Corner(knob, 6)

		-- Large invisible hit area (touch friendly)
		local hit = New("TextButton", {
			Position = UDim2.new(0, 0, 0, 26),
			Size = UDim2.new(1, 0, 0, 28),
			BackgroundTransparency = 1,
			Text = "",
			AutoButtonColor = false,
			ZIndex = 2,
			Parent = row,
		})

		local el = { Value = min, Flag = o.Flag, Type = "Slider" }

		local function render(time)
			local alpha = (max > min) and ((el.Value - min) / (max - min)) or 0
			tween(fill, { Size = UDim2.fromScale(math.clamp(alpha, 0, 1), 1) }, time)
			valueLabel.Text = tostring(el.Value) .. (o.Suffix or "")
		end

		method(el, "Set", function(_, v, silent)
			v = tonumber(v)
			if not v then
				return
			end
			v = math.clamp(roundTo(v, inc), min, max)
			el.Value = v
			commit(o.Flag, v)
			render(0.06)
			if not silent then
				fire(o.Callback, v)
			end
		end)
		method(el, "Get", function()
			return el.Value
		end)

		local dragging = false
		local function fromX(x)
			local w = track.AbsoluteSize.X
			if w <= 0 then
				return
			end
			local alpha = math.clamp((x - track.AbsolutePosition.X) / w, 0, 1)
			local newVal = math.clamp(roundTo(min + (max - min) * alpha, inc), min, max)
			if newVal ~= el.Value then
				el:Set(newVal)
			end
		end

		hit.InputBegan:Connect(function(input)
			if
				input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.Touch
			then
				dragging = true
				page.ScrollingEnabled = false
				fromX(input.Position.X)
			end
		end)
		ctx.track(UserInputService.InputChanged:Connect(function(input)
			if
				dragging
				and (
					input.UserInputType == Enum.UserInputType.MouseMovement
					or input.UserInputType == Enum.UserInputType.Touch
				)
			then
				fromX(input.Position.X)
			end
		end))
		ctx.track(UserInputService.InputEnded:Connect(function(input)
			if
				dragging
				and (
					input.UserInputType == Enum.UserInputType.MouseButton1
					or input.UserInputType == Enum.UserInputType.Touch
				)
			then
				dragging = false
				page.ScrollingEnabled = true
			end
		end))

		ctx.bind(function(c)
			fill.BackgroundColor3 = c
		end)
		el:Set(o.Default ~= nil and o.Default or min, true)
		register(ctx, o.Flag, "slider", function(v)
			el:Set(v)
		end, el.Value)
		return finish(el, row, o.Flag)
	end)

	-- Dropdown --------------------------------------------------------
	method(sectionObj, "AddDropdown", function(_, o)
		o = o or {}
		local options = {}
		for _, v in ipairs(o.Options or {}) do
			options[#options + 1] = tostring(v)
		end

		local row = Row()
		row.ClipsDescendants = true
		local open = false

		local header = New("TextButton", {
			Size = UDim2.new(1, 0, 0, RowH),
			BackgroundTransparency = 1,
			Text = "",
			AutoButtonColor = false,
			Parent = row,
		})
		Label({
			Text = o.Name or "Dropdown",
			Position = UDim2.fromOffset(12, 0),
			Size = UDim2.new(0.5, -12, 1, 0),
			TextTruncate = Enum.TextTruncate.AtEnd,
			Parent = header,
		})
		local valueLabel = Label({
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -30, 0, 0),
			Size = UDim2.new(0.5, -36, 1, 0),
			TextXAlignment = Enum.TextXAlignment.Right,
			TextColor3 = Theme.SubText,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Parent = header,
		})
		local arrow = Label({
			Text = "›",
			TextSize = 20,
			Font = Theme.FontBold,
			TextColor3 = Theme.SubText,
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -8, 0, 0),
			Size = UDim2.fromOffset(18, RowH),
			TextXAlignment = Enum.TextXAlignment.Center,
			Rotation = 90,
			Parent = header,
		})

		local list = New("ScrollingFrame", {
			Position = UDim2.fromOffset(6, RowH + 2),
			Size = UDim2.new(1, -12, 0, 0),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ScrollBarThickness = 2,
			CanvasSize = UDim2.new(),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			Parent = row,
		})
		New("UIListLayout", { Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder, Parent = list })

		local el = { Value = nil, Options = options, Flag = o.Flag, Type = "Dropdown" }
		local optionButtons = {}

		local function recolor()
			for opt, b in pairs(optionButtons) do
				b.TextColor3 = (opt == el.Value) and ctx.accent or Theme.SubText
			end
		end

		local function resize()
			local listH = math.min(#options * 30, 150)
			list.Size = UDim2.new(1, -12, 0, listH)
			tween(row, { Size = UDim2.new(1, 0, 0, open and (RowH + listH + 8) or RowH) }, 0.2)
			tween(arrow, { Rotation = open and -90 or 90 }, 0.2)
		end

		method(el, "Set", function(_, v, silent)
			v = tostring(v)
			if not table.find(options, v) then
				return
			end
			el.Value = v
			valueLabel.Text = v
			commit(o.Flag, v)
			recolor()
			if not silent then
				fire(o.Callback, v)
			end
		end)
		method(el, "Get", function()
			return el.Value
		end)

		local function build()
			for _, b in pairs(optionButtons) do
				b:Destroy()
			end
			table.clear(optionButtons)
			for i, opt in ipairs(options) do
				local b = New("TextButton", {
					Size = UDim2.new(1, 0, 0, 28),
					BackgroundColor3 = Theme.ElementHover,
					BackgroundTransparency = 1,
					Text = opt,
					Font = Theme.Font,
					TextSize = 13,
					TextColor3 = Theme.SubText,
					AutoButtonColor = false,
					LayoutOrder = i,
					Parent = list,
				})
				Corner(b, 6)
				b.MouseEnter:Connect(function()
					tween(b, { BackgroundTransparency = 0.3 }, 0.1)
				end)
				b.MouseLeave:Connect(function()
					tween(b, { BackgroundTransparency = 1 }, 0.1)
				end)
				b.MouseButton1Click:Connect(function()
					el:Set(opt)
					open = false
					resize()
				end)
				optionButtons[opt] = b
			end
			recolor()
		end

		method(el, "Refresh", function(_, newOptions, keepValue)
			table.clear(options)
			for _, v in ipairs(newOptions or {}) do
				options[#options + 1] = tostring(v)
			end
			build()
			if not (keepValue and el.Value and table.find(options, el.Value)) then
				el.Value = nil
				valueLabel.Text = "None"
				if options[1] then
					el:Set(options[1], true)
				end
			end
			if open then
				resize()
			end
		end)

		header.MouseButton1Click:Connect(function()
			open = not open
			resize()
		end)

		build()
		valueLabel.Text = "None"
		local default = o.Default ~= nil and tostring(o.Default) or options[1]
		if default then
			el:Set(default, true)
		end
		ctx.bind(recolor)
		register(ctx, o.Flag, "dropdown", function(v)
			el:Set(v)
		end, el.Value)
		return finish(el, row, o.Flag)
	end)

	-- Button ----------------------------------------------------------
	method(sectionObj, "AddButton", function(_, o)
		o = o or {}
		local row = Row()
		local hit = Hit(row)
		local lbl = Label({
			Text = o.Name or "Button",
			Size = UDim2.fromScale(1, 1),
			TextXAlignment = Enum.TextXAlignment.Center,
			Font = Theme.FontBold,
			Parent = row,
		})
		hit.MouseButton1Click:Connect(function()
			row.BackgroundColor3 = ctx.accent
			tween(row, { BackgroundColor3 = Theme.ElementHover }, 0.3)
			fire(o.Callback)
		end)
		local el = { Type = "Button" }
		method(el, "SetText", function(_, text)
			lbl.Text = tostring(text)
		end)
		return finish(el, row, nil)
	end)

	-- Keybind ---------------------------------------------------------
	method(sectionObj, "AddKeybind", function(_, o)
		o = o or {}
		local row = Row()
		Label({
			Text = o.Name or "Keybind",
			Position = UDim2.fromOffset(12, 0),
			Size = UDim2.new(1, -120, 1, 0),
			TextTruncate = Enum.TextTruncate.AtEnd,
			Parent = row,
		})
		local btn = New("TextButton", {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -8, 0.5, 0),
			Size = UDim2.fromOffset(96, RowH - 12),
			BackgroundColor3 = Theme.Off,
			Text = "",
			Font = Theme.FontBold,
			TextSize = 12,
			TextColor3 = Theme.SubText,
			AutoButtonColor = false,
			Parent = row,
		})
		Corner(btn, 6)

		local unknown = Enum.KeyCode.Unknown
		local el = { Value = o.Default or unknown, Flag = o.Flag, Type = "Keybind" }
		local listening = false

		local function show()
			if listening then
				btn.Text = "..."
			else
				btn.Text = (el.Value == unknown) and "None" or el.Value.Name
			end
			btn.TextColor3 = listening and ctx.accent or Theme.SubText
		end

		method(el, "Set", function(_, key, silent)
			if type(key) == "string" then
				local ok, res = pcall(function()
					return Enum.KeyCode[key]
				end)
				key = ok and res or nil
			end
			if typeof(key) ~= "EnumItem" then
				return
			end
			el.Value = key
			commit(o.Flag, key)
			if o.BindToggle then
				ctx.window:SetToggleKey(key)
			end
			show()
			if not silent then
				fire(o.Callback, key)
			end
		end)
		method(el, "Get", function()
			return el.Value
		end)

		btn.MouseButton1Click:Connect(function()
			listening = true
			ctx.listening = true
			show()
		end)

		ctx.track(UserInputService.InputBegan:Connect(function(input, processed)
			if listening then
				if input.UserInputType == Enum.UserInputType.Keyboard then
					listening = false
					task.defer(function()
						ctx.listening = false
					end)
					if input.KeyCode == Enum.KeyCode.Escape then
						show()
					elseif input.KeyCode == Enum.KeyCode.Backspace then
						el:Set(unknown)
					else
						el:Set(input.KeyCode)
					end
				end
				return
			end
			if not processed and el.Value ~= unknown and input.KeyCode == el.Value then
				fire(o.Pressed)
			end
		end))

		ctx.bind(show)
		el:Set(el.Value, true)
		register(ctx, o.Flag, "keybind", function(v)
			el:Set(v)
		end, el.Value)
		return finish(el, row, o.Flag)
	end)

	-- Textbox ---------------------------------------------------------
	method(sectionObj, "AddTextbox", function(_, o)
		o = o or {}
		local row = Row()
		Label({
			Text = o.Name or "Textbox",
			Position = UDim2.fromOffset(12, 0),
			Size = UDim2.new(0.5, -16, 1, 0),
			TextTruncate = Enum.TextTruncate.AtEnd,
			Parent = row,
		})
		local box = New("TextBox", {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -8, 0.5, 0),
			Size = UDim2.new(0.5, -8, 0, RowH - 12),
			BackgroundColor3 = Theme.Off,
			Text = o.Default or "",
			PlaceholderText = o.Placeholder or "",
			PlaceholderColor3 = Theme.SubText,
			TextColor3 = Theme.Text,
			Font = Theme.Font,
			TextSize = 13,
			ClearTextOnFocus = o.ClearOnFocus == true,
			ClipsDescendants = true,
			Parent = row,
		})
		Corner(box, 6)
		Pad(box, 0, 8, 0, 8)
		local stroke = Stroke(box, Theme.Stroke, 1)

		local el = { Value = o.Default or "", Flag = o.Flag, Type = "Textbox" }

		method(el, "Set", function(_, text, silent)
			text = tostring(text or "")
			el.Value = text
			box.Text = text
			commit(o.Flag, text)
			if not silent then
				fire(o.Callback, text)
			end
		end)
		method(el, "Get", function()
			return el.Value
		end)

		box.Focused:Connect(function()
			stroke.Color = ctx.accent
			tween(stroke, { Transparency = 0 }, 0.15)
		end)
		box.FocusLost:Connect(function()
			tween(stroke, { Transparency = 1 }, 0.15)
			el:Set(box.Text)
		end)

		register(ctx, o.Flag, "textbox", function(v)
			el:Set(v)
		end, el.Value)
		return finish(el, row, o.Flag)
	end)

	-- Paragraph -------------------------------------------------------
	method(sectionObj, "AddParagraph", function(_, o)
		o = o or {}
		local row = Row(0)
		row.AutomaticSize = Enum.AutomaticSize.Y
		row.Size = UDim2.new(1, 0, 0, 0)
		Pad(row, 10, 12, 10, 12)
		New("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder, Parent = row })

		local title = Label({
			Text = o.Title or "",
			Font = Theme.FontBold,
			TextWrapped = true,
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			LayoutOrder = 1,
			Parent = row,
		})
		local body = Label({
			Text = o.Body or o.Content or "",
			TextSize = 12,
			TextColor3 = Theme.SubText,
			TextWrapped = true,
			TextYAlignment = Enum.TextYAlignment.Top,
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			LayoutOrder = 2,
			Parent = row,
		})
		title.Visible = (o.Title or "") ~= ""

		local el = { Type = "Paragraph" }
		method(el, "Set", function(_, t, b)
			if type(t) == "table" then
				t, b = t.Title, t.Body
			end
			if t ~= nil then
				title.Text = tostring(t)
				title.Visible = tostring(t) ~= ""
			end
			if b ~= nil then
				body.Text = tostring(b)
			end
		end)
		return finish(el, row, nil)
	end)
end

------------------------------------------------------------------------
-- Window
------------------------------------------------------------------------
local function createWindow(_, opts)
	opts = opts or {}
	local gui = getGui()

	local window = {
		Tabs = {},
		Visible = false,
		Destroyed = false,
		ToggleKey = opts.ToggleKey or Enum.KeyCode.RightControl,
	}
	local ctx = { listening = false, flags = {}, accent = opts.Accent or Theme.Accent, window = window }
	local conns, accentFns = {}, {}

	function ctx.track(c)
		conns[#conns + 1] = c
		return c
	end
	function ctx.bind(fn)
		accentFns[#accentFns + 1] = fn
		fn(ctx.accent)
	end

	Library.Accent = ctx.accent
	local size = opts.Size or UDim2.fromOffset(560, 420)

	-- Root + Main ------------------------------------------------------
	local Root = New("Frame", {
		Name = "Window",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = size,
		BackgroundTransparency = 1,
		Parent = gui,
	})
	local fitScale = New("UIScale", { Parent = Root })

	local Main = New("CanvasGroup", {
		Name = "Main",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Theme.Background,
		BorderSizePixel = 0,
		GroupTransparency = 1,
		Parent = Root,
	})
	local pop = New("UIScale", { Scale = 0.94, Parent = Main })
	Corner(Main, Theme.WindowRadius)
	Stroke(Main, Theme.Stroke)

	-- Fit to small screens (mobile) ------------------------------------
	local function fit()
		local cam = workspace.CurrentCamera
		local w, h = size.X.Offset, size.Y.Offset
		if not cam or w <= 0 or h <= 0 then
			fitScale.Scale = 1
			return
		end
		local vp = cam.ViewportSize
		fitScale.Scale = math.clamp(math.min((vp.X - 24) / w, (vp.Y - 24) / h), 0.5, 1)
	end
	fit()
	if workspace.CurrentCamera then
		ctx.track(workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fit))
	end

	-- Header -----------------------------------------------------------
	local header = New("Frame", {
		Name = "Header",
		Size = UDim2.new(1, 0, 0, 50),
		BackgroundTransparency = 1,
		Parent = Main,
	})
	local dot = New("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 16, 0.5, 0),
		Size = UDim2.fromOffset(10, 10),
		BackgroundColor3 = ctx.accent,
		Parent = header,
	})
	Corner(dot, 5)
	ctx.bind(function(c)
		dot.BackgroundColor3 = c
	end)

	local hasSub = opts.Subtitle and opts.Subtitle ~= ""
	Label({
		Text = opts.Title or "Kisha",
		Font = Theme.FontBold,
		TextSize = 16,
		Position = UDim2.fromOffset(36, hasSub and 8 or 0),
		Size = UDim2.new(1, -90, 0, hasSub and 20 or 50),
		Parent = header,
	})
	if hasSub then
		Label({
			Text = opts.Subtitle,
			TextSize = 11,
			TextColor3 = Theme.SubText,
			Position = UDim2.fromOffset(36, 27),
			Size = UDim2.new(1, -90, 0, 14),
			Parent = header,
		})
	end

	local closeBtn = New("TextButton", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -10, 0.5, 0),
		Size = UDim2.fromOffset(32, 32),
		BackgroundColor3 = Theme.Element,
		BackgroundTransparency = 1,
		Text = "×",
		Font = Theme.FontBold,
		TextSize = 20,
		TextColor3 = Theme.SubText,
		AutoButtonColor = false,
		Parent = header,
	})
	Corner(closeBtn, 8)
	closeBtn.MouseEnter:Connect(function()
		tween(closeBtn, { BackgroundTransparency = 0, TextColor3 = Theme.Text }, 0.12)
	end)
	closeBtn.MouseLeave:Connect(function()
		tween(closeBtn, { BackgroundTransparency = 1, TextColor3 = Theme.SubText }, 0.12)
	end)

	New("Frame", {
		Position = UDim2.fromOffset(0, 50),
		Size = UDim2.new(1, 0, 0, 1),
		BackgroundColor3 = Theme.Stroke,
		BackgroundTransparency = 0.3,
		Parent = Main,
	})

	-- Dragging (mouse + touch) ----------------------------------------
	local dragging, dragStart, startPos = false, nil, nil
	header.InputBegan:Connect(function(input)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			dragging = true
			dragStart = input.Position
			startPos = Root.Position
		end
	end)
	ctx.track(UserInputService.InputChanged:Connect(function(input)
		if
			dragging
			and (
				input.UserInputType == Enum.UserInputType.MouseMovement
				or input.UserInputType == Enum.UserInputType.Touch
			)
		then
			local d = input.Position - dragStart
			Root.Position = UDim2.new(
				startPos.X.Scale,
				startPos.X.Offset + d.X,
				startPos.Y.Scale,
				startPos.Y.Offset + d.Y
			)
		end
	end))
	ctx.track(UserInputService.InputEnded:Connect(function(input)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			dragging = false
		end
	end))

	-- Body: sidebar + content -----------------------------------------
	local body = New("Frame", {
		Position = UDim2.fromOffset(0, 51),
		Size = UDim2.new(1, 0, 1, -51),
		BackgroundTransparency = 1,
		Parent = Main,
	})
	local sidebar = New("Frame", {
		Size = UDim2.new(0, 132, 1, 0),
		BackgroundColor3 = Theme.Sidebar,
		BorderSizePixel = 0,
		Parent = body,
	})
	local tabList = New("ScrollingFrame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 0,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		Parent = sidebar,
	})
	Pad(tabList, 10, 8, 10, 8)
	New("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder, Parent = tabList })

	local content = New("Frame", {
		Position = UDim2.fromOffset(132, 0),
		Size = UDim2.new(1, -132, 1, 0),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		Parent = body,
	})

	-- Tabs -------------------------------------------------------------
	local function selectTab(tab)
		window.Selected = tab
		for _, t in ipairs(window.Tabs) do
			t._setActive(t == tab)
		end
	end

	method(window, "CreateTab", function(_, tabOpts)
		tabOpts = tabOpts or {}
		local name = tabOpts.Name or "Tab"
		local tab = { Name = name, Window = window, Sections = {} }

		local btn = New("TextButton", {
			Name = name,
			Size = UDim2.new(1, 0, 0, 38),
			BackgroundColor3 = ctx.accent,
			BackgroundTransparency = 1,
			Text = "",
			AutoButtonColor = false,
			LayoutOrder = #window.Tabs + 1,
			Parent = tabList,
		})
		Corner(btn, 8)
		local bar = New("Frame", {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 0, 0.5, 0),
			Size = UDim2.fromOffset(3, 16),
			BackgroundColor3 = ctx.accent,
			BackgroundTransparency = 1,
			Parent = btn,
		})
		Corner(bar, 2)

		local textX = 12
		local icon = tabOpts.Icon
		if type(icon) == "string" and icon ~= "" then
			if icon:match("^rbxasset") then
				New("ImageLabel", {
					AnchorPoint = Vector2.new(0, 0.5),
					Position = UDim2.new(0, 12, 0.5, 0),
					Size = UDim2.fromOffset(16, 16),
					BackgroundTransparency = 1,
					Image = icon,
					ImageColor3 = Theme.SubText,
					Parent = btn,
				})
				textX = 36
			else
				Label({
					Text = icon,
					Position = UDim2.fromOffset(12, 0),
					Size = UDim2.fromOffset(18, 38),
					TextXAlignment = Enum.TextXAlignment.Center,
					Parent = btn,
				})
				textX = 36
			end
		end
		local lbl = Label({
			Text = name,
			Font = Theme.FontBold,
			TextColor3 = Theme.SubText,
			Position = UDim2.fromOffset(textX, 0),
			Size = UDim2.new(1, -textX - 6, 1, 0),
			TextTruncate = Enum.TextTruncate.AtEnd,
			Parent = btn,
		})

		local page = New("ScrollingFrame", {
			Name = name,
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ScrollBarThickness = 3,
			ScrollBarImageColor3 = ctx.accent,
			ScrollingDirection = Enum.ScrollingDirection.Y,
			CanvasSize = UDim2.new(),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			Visible = false,
			Parent = content,
		})
		Pad(page, 12, 14, 12, 12)
		New("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder, Parent = page })

		local active = false
		function tab._setActive(v)
			active = v
			page.Visible = v
			tween(btn, { BackgroundTransparency = v and 0.88 or 1 }, 0.15)
			tween(bar, { BackgroundTransparency = v and 0 or 1 }, 0.15)
			tween(lbl, { TextColor3 = v and Theme.Text or Theme.SubText }, 0.15)
		end

		btn.MouseEnter:Connect(function()
			if not active then
				tween(btn, { BackgroundTransparency = 0.94 }, 0.1)
			end
		end)
		btn.MouseLeave:Connect(function()
			if not active then
				tween(btn, { BackgroundTransparency = 1 }, 0.1)
			end
		end)
		btn.MouseButton1Click:Connect(function()
			selectTab(tab)
		end)
		ctx.bind(function(c)
			btn.BackgroundColor3 = c
			bar.BackgroundColor3 = c
			page.ScrollBarImageColor3 = c
		end)

		-- Sections
		method(tab, "CreateSection", function(_, secOpts)
			secOpts = secOpts or {}
			local section = { Name = secOpts.Name or "Section", Tab = tab }

			local frame = New("Frame", {
				Name = section.Name,
				Size = UDim2.new(1, 0, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundColor3 = Theme.Card,
				BorderSizePixel = 0,
				LayoutOrder = #tab.Sections + 1,
				Parent = page,
			})
			Corner(frame, 10)
			Stroke(frame, Theme.Stroke, 0.3)
			Pad(frame, 10)
			New("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = frame })

			local title = Label({
				Text = string.upper(section.Name),
				Font = Theme.FontBold,
				TextSize = 11,
				TextColor3 = ctx.accent,
				Size = UDim2.new(1, 0, 0, 18),
				LayoutOrder = 0,
				Parent = frame,
			})
			ctx.bind(function(c)
				title.TextColor3 = c
			end)

			buildSection(ctx, page, frame, section)
			section.Instance = frame
			tab.Sections[#tab.Sections + 1] = section
			return section
		end)

		window.Tabs[#window.Tabs + 1] = tab
		tab._setActive(false)
		if #window.Tabs == 1 then
			selectTab(tab)
		end
		return tab
	end)

	-- Visibility -------------------------------------------------------
	local token = 0
	method(window, "SetVisible", function(_, v)
		if window.Destroyed then
			return
		end
		v = v and true or false
		window.Visible = v
		token += 1
		local mine = token
		if v then
			Root.Visible = true
			tween(Main, { GroupTransparency = 0 }, 0.2)
			tween(pop, { Scale = 1 }, 0.28, Enum.EasingStyle.Back)
		else
			tween(Main, { GroupTransparency = 1 }, 0.15)
			tween(pop, { Scale = 0.94 }, 0.15)
			task.delay(0.17, function()
				if token == mine and not window.Destroyed then
					Root.Visible = false
				end
			end)
		end
	end)
	method(window, "Toggle", function()
		window:SetVisible(not window.Visible)
	end)

	method(window, "SetToggleKey", function(_, key)
		if typeof(key) == "EnumItem" then
			window.ToggleKey = key
		end
	end)

	method(window, "SetAccent", function(_, color)
		if typeof(color) ~= "Color3" then
			return
		end
		ctx.accent = color
		Library.Accent = color
		for _, fn in ipairs(accentFns) do
			pcall(fn, color)
		end
	end)

	closeBtn.MouseButton1Click:Connect(function()
		window:SetVisible(false)
	end)

	-- Toggle keybind ---------------------------------------------------
	ctx.track(UserInputService.InputBegan:Connect(function(input, processed)
		if processed or ctx.listening then
			return
		end
		if window.ToggleKey ~= Enum.KeyCode.Unknown and input.KeyCode == window.ToggleKey then
			window:SetVisible(not window.Visible)
		end
	end))

	-- Mobile launcher (no keyboard = no toggle key) --------------------
	local launcher
	local wantLauncher = opts.MobileButton == true
		or (opts.MobileButton ~= false and UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled)
	if wantLauncher then
		launcher = New("TextButton", {
			Name = "KishaLauncher",
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 10, 0.5, 0),
			Size = UDim2.fromOffset(46, 46),
			BackgroundColor3 = ctx.accent,
			Text = string.upper(string.sub(opts.Title or "K", 1, 1)),
			Font = Theme.FontBold,
			TextSize = 18,
			TextColor3 = Theme.White,
			AutoButtonColor = false,
			Parent = gui,
		})
		Corner(launcher, 14)
		launcher.MouseButton1Click:Connect(function()
			window:SetVisible(not window.Visible)
		end)
		ctx.bind(function(c)
			launcher.BackgroundColor3 = c
		end)
	end

	-- Destroy ----------------------------------------------------------
	method(window, "Destroy", function()
		if window.Destroyed then
			return
		end
		window.Destroyed = true
		for _, c in ipairs(conns) do
			pcall(function()
				c:Disconnect()
			end)
		end
		table.clear(conns)
		table.clear(accentFns)
		for _, flag in ipairs(ctx.flags) do
			Library.Flags[flag] = nil
			Library._registry[flag] = nil
		end
		Root:Destroy()
		if launcher then
			launcher:Destroy()
		end
		local i = table.find(Library.Windows, window)
		if i then
			table.remove(Library.Windows, i)
		end
	end)

	Library.Windows[#Library.Windows + 1] = window
	window:SetVisible(true)
	return window
end

------------------------------------------------------------------------
-- Library API
------------------------------------------------------------------------
method(Library, "CreateWindow", createWindow)

method(Library, "Destroy", function(self)
	for i = #self.Windows, 1, -1 do
		pcall(function()
			self.Windows[i]:Destroy()
		end)
	end
	if self._gui then
		self._gui:Destroy()
		self._gui = nil
	end
	table.clear(self.Flags)
	table.clear(self._registry)
	if Env.__KishaLibrary == self then
		Env.__KishaLibrary = nil
	end
end)

Env.__KishaLibrary = Library
return Library
