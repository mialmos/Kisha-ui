--[[
	Kisha UI Library  v3.1.0  (Liquid Glass / Pastel Pink)
	Self-contained Roblox Luau UI framework. API-compatible with v1/v2.
	No telemetry, no remote auth, no third-party links.

	New in v3:
	  * Keybinds: toggles and buttons can get a "+" pill. Script users click it to bind
	    one or many keys to that function and trigger it without opening the menu.
	      Section:AddToggle({ ..., Keybinds = true })
	      Section:AddButton({ ..., Keybinds = { Default = { Enum.KeyCode.E }, Max = 4 } })
	      Window:  CreateWindow({ ..., Keybinds = true })  -- enables it on every toggle/button
	  * Spinning light-pink outline around the whole window
	  * Depth: layered drop shadow, hover lift, press feedback, sliding tab highlight,
	    page transitions, ripples, cursor-reactive sheen, blinking logo

	Sections: Services / Theme / Helpers / Config / Notify / Elements / Keybind panel / Logo / Window / Library API
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

-- Shared environment (used to tear down a previous load on re-execute)
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
	Version = "3.1.0",
	Flags = {},
	Windows = {},
	ConfigFolder = "Kisha/configs",
	-- Optional custom storage: Save = function(name, json) end, Load = function(name) return json end
	ConfigHooks = {},
	_registry = {},
	_gui = nil,
}

------------------------------------------------------------------------
-- Theme (pastel pink liquid glass)
------------------------------------------------------------------------
local Theme = {
	Background = Color3.fromRGB(255, 233, 241), -- blush
	Glass = Color3.fromRGB(255, 251, 253), -- warm milk white
	Track = Color3.fromRGB(250, 215, 229),
	Text = Color3.fromRGB(122, 58, 82), -- warm rosewood
	SubText = Color3.fromRGB(178, 121, 142),
	Accent = Color3.fromRGB(255, 145, 186), -- baby pink
	White = Color3.fromRGB(255, 255, 255),
	ShadowColor = Color3.fromRGB(235, 135, 165),
	Font = Enum.Font.GothamMedium,
	FontBold = Enum.Font.GothamBold,
	WindowRadius = 20,
	CardRadius = 15,
	ElementRadius = 12,
	WindowAlpha = 0.1,
	CardAlpha = 0.74,
	ElementAlpha = 0.5,
	ElementHoverAlpha = 0.28,
}

Library.Accent = Theme.Accent

local function Deep(c)
	return c:Lerp(Color3.fromRGB(150, 45, 90), 0.4)
end

local RowH = UserInputService.TouchEnabled and 42 or 38

local Quint = Enum.EasingStyle.Quint
local Back = Enum.EasingStyle.Back
local Sine = Enum.EasingStyle.Sine

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

local function Stroke(parent, color, transparency, thickness)
	return New("UIStroke", {
		Color = color or Theme.White,
		Thickness = thickness or 1,
		Transparency = transparency or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = parent,
	})
end

-- Glass rim light: bright on the top-left edge, fading toward the bottom-right
local function Rim(parent, strength, thickness)
	local s = New("UIStroke", {
		Color = Theme.White,
		Thickness = thickness or 1.2,
		Transparency = strength or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = parent,
	})
	New("UIGradient", {
		Rotation = 45,
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(0.45, 0.6),
			NumberSequenceKeypoint.new(1, 0.2),
		}),
		Parent = s,
	})
	return s
end

-- Vertical sheen so surfaces read as curved glass
local function Gloss(inst, top, bottom)
	return New("UIGradient", {
		Rotation = 90,
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, top or 0),
			NumberSequenceKeypoint.new(1, bottom or 0.3),
		}),
		Parent = inst,
	})
end

-- Soft shading for solid pieces (toggle pill, slider fill)
local function Shade(inst)
	return New("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(255, 229, 239)),
		Parent = inst,
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
	local decimals = tostring(inc):match("%.(%d+)")
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

-- Key helpers ----------------------------------------------------------
local KEY_NAMES = {
	LeftShift = "LShift", RightShift = "RShift", LeftControl = "LCtrl", RightControl = "RCtrl",
	LeftAlt = "LAlt", RightAlt = "RAlt", Return = "Enter", Backspace = "Bksp",
	Zero = "0", One = "1", Two = "2", Three = "3", Four = "4",
	Five = "5", Six = "6", Seven = "7", Eight = "8", Nine = "9",
	Equals = "=", Minus = "-", Backquote = "`", LeftBracket = "[", RightBracket = "]",
	Semicolon = ";", Quote = "'", Comma = ",", Period = ".", Slash = "/", BackSlash = "\\",
}

local function keyDisplay(key)
	return KEY_NAMES[key.Name] or key.Name
end

local function normalizeKey(key)
	if type(key) == "string" then
		local ok, res = pcall(function()
			return Enum.KeyCode[key]
		end)
		key = ok and res or nil
	end
	if typeof(key) == "EnumItem" and key.EnumType == Enum.KeyCode then
		return key
	end
	return nil
end

-- Per-row visual state (hover lift / press)
local rowFx = setmetatable({}, { __mode = "k" })

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
	for flag in pairs(self._registry) do
		local v = self.Flags[flag]
		if typeof(v) == "EnumItem" then
			v = v.Name
		elseif type(v) == "table" then
			local names = {}
			for _, k in ipairs(v) do
				names[#names + 1] = typeof(k) == "EnumItem" and k.Name or tostring(k)
			end
			v = names
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
			Size = UDim2.new(0, 290, 1, -32),
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
		BackgroundColor3 = Theme.Background,
		BackgroundTransparency = 0.12,
		BorderSizePixel = 0,
		Parent = wrapper,
	})
	Corner(toast, 16)
	Rim(toast, 0)
	Gloss(toast, 0, 0.25)
	Pad(toast, 12, 14, 12, 14)
	New("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder, Parent = toast })

	Label({
		Text = tostring(opts.Title or "Kisha UI"),
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
		Size = UDim2.new(1, 0, 0, 4),
		BackgroundColor3 = Theme.Track,
		LayoutOrder = 3,
		Parent = toast,
	})
	Corner(track, 2)
	local fill = New("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = accent, Parent = track })
	Corner(fill, 2)
	Shade(fill)

	tween(toast, { Position = UDim2.new(0, 0, 0, 0) }, 0.5, Back)
	tween(fill, { Size = UDim2.new(0, 0, 1, 0) }, duration, Enum.EasingStyle.Linear)

	task.delay(duration, function()
		if not toast.Parent then
			return
		end
		tween(toast, { Position = UDim2.new(1, 60, 0, 0) }, 0.3, Quint, Enum.EasingDirection.In)
		task.wait(0.35)
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

	local function wantsKeybinds(o)
		if o.Keybinds == false then
			return false
		end
		if o.Keybinds == true or type(o.Keybinds) == "table" then
			return true
		end
		return ctx.defaultKeybinds == true
	end

	-- Row: glass surface with hover lift + rim brighten ----------------
	local function Row(height)
		local row = New("Frame", {
			Size = UDim2.new(1, 0, 0, height or RowH),
			BackgroundColor3 = Theme.Glass,
			BackgroundTransparency = Theme.ElementAlpha,
			BorderSizePixel = 0,
			LayoutOrder = nextOrder(),
			Parent = container,
		})
		Corner(row)
		local rim = Rim(row, 0.15)
		Gloss(row, 0, 0.3)
		local rs = New("UIScale", { Parent = row })
		rowFx[row] = { scale = rs, hovered = false }

		row.MouseEnter:Connect(function()
			rowFx[row].hovered = true
			tween(row, { BackgroundTransparency = Theme.ElementHoverAlpha }, 0.16)
			tween(rs, { Scale = 1.012 }, 0.25, Quint)
			tween(rim, { Transparency = 0, Thickness = 1.8 }, 0.2)
		end)
		row.MouseLeave:Connect(function()
			rowFx[row].hovered = false
			tween(row, { BackgroundTransparency = Theme.ElementAlpha }, 0.2)
			tween(rs, { Scale = 1 }, 0.25, Quint)
			tween(rim, { Transparency = 0.15, Thickness = 1.2 }, 0.25)
		end)
		return row
	end

	local function Hit(row)
		local btn = New("TextButton", {
			Name = "Hit",
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Text = "",
			AutoButtonColor = false,
			ZIndex = 2,
			Parent = row,
		})
		local fx = rowFx[row]
		btn.MouseButton1Down:Connect(function()
			tween(fx.scale, { Scale = 0.982 }, 0.08)
		end)
		btn.MouseButton1Up:Connect(function()
			tween(fx.scale, { Scale = fx.hovered and 1.012 or 1 }, 0.3, Back)
		end)
		return btn
	end

	-- Visual feedback when a key triggers an element
	local function Pulse(row)
		local fx = rowFx[row]
		row.BackgroundColor3 = ctx.accent
		row.BackgroundTransparency = 0.12
		tween(row, { BackgroundColor3 = Theme.Glass, BackgroundTransparency = Theme.ElementAlpha }, 0.6)
		if fx then
			fx.scale.Scale = 1.045
			tween(fx.scale, { Scale = fx.hovered and 1.012 or 1 }, 0.5, Back)
		end
	end

	local function finish(el, row, flag)
		el.Instance = row
		method(el, "Destroy", function()
			if flag then
				Library.Flags[flag] = nil
				Library._registry[flag] = nil
				Library.Flags[flag .. "_keys"] = nil
				Library._registry[flag .. "_keys"] = nil
			end
			ctx.keyElements[el] = nil
			row:Destroy()
		end)
		return el
	end

	-- Keybind customizer: the "+" pill + multi-key list ---------------
	local function attachKeybinds(el, row, o, displayName, rightOffset, trigger)
		local cfg = type(o.Keybinds) == "table" and o.Keybinds or {}
		local max = cfg.Max or o.MaxKeybinds or 5
		local keys = {}
		local unknown = Enum.KeyCode.Unknown
		local keyFlag = o.Flag and (o.Flag .. "_keys") or nil

		el.Keys = keys
		el._keys = keys
		el._trigger = trigger
		ctx.keyElements[el] = true

		local pill = New("TextButton", {
			Name = "KeybindPill",
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, rightOffset, 0.5, 0),
			Size = UDim2.fromOffset(28, 24),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundColor3 = Theme.Glass,
			BackgroundTransparency = 0.3,
			Text = "+",
			Font = Theme.FontBold,
			TextSize = 14,
			TextColor3 = Theme.SubText,
			AutoButtonColor = false,
			ZIndex = 3,
			Parent = row,
		})
		Corner(pill, 12)
		Rim(pill, 0.2)
		Pad(pill, 0, 8, 0, 8)
		local pillScale = New("UIScale", { Parent = pill })

		local function refresh()
			if #keys == 0 then
				pill.Text = "+"
				pill.TextColor3 = Theme.SubText
			else
				local txt = keyDisplay(keys[1])
				if #keys > 1 then
					txt = txt .. " +" .. (#keys - 1)
				end
				pill.Text = txt
				pill.TextColor3 = Deep(ctx.accent)
			end
		end

		local function changed(silent)
			if keyFlag then
				Library.Flags[keyFlag] = table.clone(keys)
			end
			refresh()
			if el._panelRefresh then
				el._panelRefresh()
			end
			if not silent then
				fire(cfg.Callback or o.KeybindChanged, table.clone(keys))
			end
		end

		method(el, "AddKey", function(_, key, silent)
			key = normalizeKey(key)
			if not key or key == unknown then
				return false
			end
			if key == ctx.window.ToggleKey or table.find(keys, key) or #keys >= max then
				return false
			end
			keys[#keys + 1] = key
			changed(silent)
			return true
		end)
		method(el, "RemoveKey", function(_, key, silent)
			key = normalizeKey(key)
			local i = key and table.find(keys, key)
			if not i then
				return false
			end
			table.remove(keys, i)
			changed(silent)
			return true
		end)
		method(el, "SetKeys", function(_, list, silent)
			table.clear(keys)
			for _, k in ipairs(type(list) == "table" and list or {}) do
				local nk = normalizeKey(k)
				if nk and nk ~= unknown and not table.find(keys, nk) and #keys < max then
					keys[#keys + 1] = nk
				end
			end
			changed(silent)
		end)
		method(el, "GetKeys", function()
			return table.clone(keys)
		end)

		pill.MouseEnter:Connect(function()
			tween(pill, { BackgroundTransparency = 0.05 }, 0.12)
			tween(pillScale, { Scale = 1.1 }, 0.2, Back)
		end)
		pill.MouseLeave:Connect(function()
			tween(pill, { BackgroundTransparency = 0.3 }, 0.15)
			tween(pillScale, { Scale = 1 }, 0.2, Quint)
		end)
		pill.MouseButton1Down:Connect(function()
			tween(pillScale, { Scale = 0.9 }, 0.07)
		end)
		pill.MouseButton1Click:Connect(function()
			tween(pillScale, { Scale = 1.1 }, 0.2, Back)
			ctx.openKeybindPanel(el, displayName, max)
		end)

		for _, k in ipairs(cfg.Default or o.DefaultKeys or {}) do
			el:AddKey(k, true)
		end
		ctx.bind(refresh)
		register(ctx, keyFlag, "keybinds", function(v)
			el:SetKeys(v)
		end, table.clone(keys))
	end

	-- Toggle ----------------------------------------------------------
	method(sectionObj, "AddToggle", function(_, o)
		o = o or {}
		local hasKeys = wantsKeybinds(o)
		local row = Row()
		Label({
			Text = o.Name or "Toggle",
			Position = UDim2.fromOffset(14, 0),
			Size = UDim2.new(1, hasKeys and -126 or -74, 1, 0),
			TextTruncate = Enum.TextTruncate.AtEnd,
			Parent = row,
		})
		local sw = New("Frame", {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -12, 0.5, 0),
			Size = UDim2.fromOffset(42, 22),
			BackgroundColor3 = Theme.Track,
			Parent = row,
		})
		Corner(sw, 11)
		Shade(sw)
		local swGlow = Stroke(sw, ctx.accent, 1, 3)
		local knob = New("Frame", {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 3, 0.5, 0),
			Size = UDim2.fromOffset(16, 16),
			BackgroundColor3 = Theme.White,
			Parent = sw,
		})
		Corner(knob, 8)
		Stroke(knob, Color3.fromRGB(255, 200, 220), 0.3, 1)
		local hit = Hit(row)

		local el = { Value = o.Default and true or false, Flag = o.Flag, Type = "Toggle" }
		local pressed = false

		local function render(time)
			local w = pressed and 21 or 16
			tween(sw, { BackgroundColor3 = el.Value and ctx.accent or Theme.Track }, time)
			tween(swGlow, { Transparency = el.Value and 0.55 or 1 }, time)
			tween(knob, {
				Size = UDim2.fromOffset(w, 16),
				Position = el.Value and UDim2.new(1, -(w + 3), 0.5, 0) or UDim2.new(0, 3, 0.5, 0),
			}, time, Back)
		end

		method(el, "Set", function(_, v, silent)
			el.Value = v and true or false
			commit(o.Flag, el.Value)
			render(0.3)
			if not silent then
				fire(o.Callback, el.Value)
			end
		end)
		method(el, "Get", function()
			return el.Value
		end)

		hit.MouseButton1Down:Connect(function()
			pressed = true
			render(0.12)
		end)
		hit.MouseButton1Up:Connect(function()
			pressed = false
			render(0.25)
		end)
		hit.MouseLeave:Connect(function()
			if pressed then
				pressed = false
				render(0.25)
			end
		end)
		hit.MouseButton1Click:Connect(function()
			el:Set(not el.Value)
		end)
		ctx.bind(function(c)
			swGlow.Color = c
			render(0)
		end)
		register(ctx, o.Flag, "toggle", function(v)
			el:Set(v)
		end, el.Value)

		if hasKeys then
			attachKeybinds(el, row, o, o.Name or "Toggle", -62, function()
				el:Set(not el.Value)
				Pulse(row)
				if o.KeybindNotify then
					Library:Notify({
						Title = o.Name or "Toggle",
						Content = el.Value and "Enabled" or "Disabled",
						Duration = 1.6,
					})
				end
			end)
		end
		return finish(el, row, o.Flag)
	end)

	-- Slider ----------------------------------------------------------
	method(sectionObj, "AddSlider", function(_, o)
		o = o or {}
		local min, max = o.Min or 0, o.Max or 100
		local inc = o.Increment or 1
		local row = Row(56)

		Label({
			Text = o.Name or "Slider",
			Position = UDim2.fromOffset(14, 7),
			Size = UDim2.new(1, -92, 0, 18),
			TextTruncate = Enum.TextTruncate.AtEnd,
			Parent = row,
		})
		local valueLabel = Label({
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -14, 0, 7),
			Size = UDim2.fromOffset(70, 18),
			TextXAlignment = Enum.TextXAlignment.Right,
			TextColor3 = Theme.SubText,
			Parent = row,
		})
		local track = New("Frame", {
			Position = UDim2.new(0, 14, 0, 38),
			Size = UDim2.new(1, -28, 0, 8),
			BackgroundColor3 = Theme.Track,
			Parent = row,
		})
		Corner(track, 4)
		local fill = New("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = ctx.accent, Parent = track })
		Corner(fill, 4)
		Shade(fill)
		local knob = New("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(1, 0.5),
			Size = UDim2.fromOffset(16, 16),
			BackgroundColor3 = Theme.White,
			Parent = fill,
		})
		Corner(knob, 8)
		local knobStroke = Stroke(knob, ctx.accent, 0, 2)

		-- Large invisible hit area (touch friendly)
		local hit = New("TextButton", {
			Position = UDim2.new(0, 0, 0, 26),
			Size = UDim2.new(1, 0, 0, 30),
			BackgroundTransparency = 1,
			Text = "",
			AutoButtonColor = false,
			ZIndex = 2,
			Parent = row,
		})

		local el = { Value = min, Flag = o.Flag, Type = "Slider" }
		local dragging = false

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
			render(dragging and 0.05 or 0.2)
			if not silent then
				fire(o.Callback, v)
			end
		end)
		method(el, "Get", function()
			return el.Value
		end)

		local function setDragging(on)
			dragging = on
			page.ScrollingEnabled = not on
			tween(knob, { Size = on and UDim2.fromOffset(22, 22) or UDim2.fromOffset(16, 16) }, 0.25, Back)
			tween(track, { Size = UDim2.new(1, -28, 0, on and 10 or 8) }, 0.2)
			tween(valueLabel, {
				TextSize = on and 15 or 13,
				TextColor3 = on and Deep(ctx.accent) or Theme.SubText,
			}, 0.2)
		end

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

		hit.MouseEnter:Connect(function()
			if not dragging then
				tween(knob, { Size = UDim2.fromOffset(19, 19) }, 0.2, Back)
			end
		end)
		hit.MouseLeave:Connect(function()
			if not dragging then
				tween(knob, { Size = UDim2.fromOffset(16, 16) }, 0.2)
			end
		end)
		hit.InputBegan:Connect(function(input)
			if
				input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.Touch
			then
				setDragging(true)
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
				setDragging(false)
			end
		end))

		ctx.bind(function(c)
			fill.BackgroundColor3 = c
			knobStroke.Color = c
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
			Position = UDim2.fromOffset(14, 0),
			Size = UDim2.new(0.5, -14, 1, 0),
			TextTruncate = Enum.TextTruncate.AtEnd,
			Parent = header,
		})
		local valueLabel = Label({
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -32, 0, 0),
			Size = UDim2.new(0.5, -38, 1, 0),
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
			Position = UDim2.new(1, -10, 0, 0),
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
			ScrollBarImageColor3 = ctx.accent,
			CanvasSize = UDim2.new(),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			Parent = row,
		})
		New("UIListLayout", { Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder, Parent = list })

		local el = { Value = nil, Options = options, Flag = o.Flag, Type = "Dropdown" }
		local optionButtons = {}

		local function recolor()
			for opt, b in pairs(optionButtons) do
				b.TextColor3 = (opt == el.Value) and Deep(ctx.accent) or Theme.SubText
				b.Font = (opt == el.Value) and Theme.FontBold or Theme.Font
			end
			list.ScrollBarImageColor3 = ctx.accent
		end

		local function resize()
			local listH = math.min(#options * 30, 150)
			list.Size = UDim2.new(1, -12, 0, listH)
			tween(row, { Size = UDim2.new(1, 0, 0, open and (RowH + listH + 8) or RowH) }, 0.35, Quint)
			tween(arrow, { Rotation = open and -90 or 90 }, 0.3, Back)
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
					BackgroundColor3 = Theme.White,
					BackgroundTransparency = 1,
					Text = opt,
					Font = Theme.Font,
					TextSize = 13,
					TextColor3 = Theme.SubText,
					AutoButtonColor = false,
					LayoutOrder = i,
					Parent = list,
				})
				Corner(b, 8)
				b.MouseEnter:Connect(function()
					tween(b, { BackgroundTransparency = 0.4 }, 0.1)
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
		local hasKeys = wantsKeybinds(o)
		local row = Row()
		row.ClipsDescendants = true
		local hit = Hit(row)
		local lbl = Label({
			Text = o.Name or "Button",
			Size = UDim2.fromScale(1, 1),
			TextXAlignment = Enum.TextXAlignment.Center,
			Font = Theme.FontBold,
			Parent = row,
		})

		-- Ripple from the click point
		hit.InputBegan:Connect(function(input)
			if
				input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.Touch
			then
				local f = row.AbsoluteSize.Y / RowH
				if f <= 0 then
					return
				end
				local relX = (input.Position.X - row.AbsolutePosition.X) / f
				local w = row.AbsoluteSize.X / f
				local ripple = New("Frame", {
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromOffset(relX, RowH / 2),
					Size = UDim2.fromOffset(0, 0),
					BackgroundColor3 = ctx.accent,
					BackgroundTransparency = 0.5,
					BorderSizePixel = 0,
					Parent = row,
				})
				New("UICorner", { CornerRadius = UDim.new(0.5, 0), Parent = ripple })
				tween(ripple, {
					Size = UDim2.fromOffset(w * 2.2, w * 2.2),
					BackgroundTransparency = 1,
				}, 0.6, Quint)
				task.delay(0.65, function()
					ripple:Destroy()
				end)
			end
		end)

		hit.MouseButton1Click:Connect(function()
			fire(o.Callback)
		end)

		local el = { Type = "Button" }
		method(el, "SetText", function(_, text)
			lbl.Text = tostring(text)
		end)
		method(el, "Fire", function()
			fire(o.Callback)
		end)

		if hasKeys then
			attachKeybinds(el, row, o, o.Name or "Button", -10, function()
				fire(o.Callback)
				Pulse(row)
				if o.KeybindNotify then
					Library:Notify({ Title = o.Name or "Button", Content = "Triggered", Duration = 1.4 })
				end
			end)
		end
		return finish(el, row, nil)
	end)

	-- Keybind (single key picker, unchanged API) ----------------------
	method(sectionObj, "AddKeybind", function(_, o)
		o = o or {}
		local row = Row()
		Label({
			Text = o.Name or "Keybind",
			Position = UDim2.fromOffset(14, 0),
			Size = UDim2.new(1, -124, 1, 0),
			TextTruncate = Enum.TextTruncate.AtEnd,
			Parent = row,
		})
		local btn = New("TextButton", {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -8, 0.5, 0),
			Size = UDim2.fromOffset(96, RowH - 12),
			BackgroundColor3 = Theme.Glass,
			BackgroundTransparency = 0.25,
			Text = "",
			Font = Theme.FontBold,
			TextSize = 12,
			TextColor3 = Theme.SubText,
			AutoButtonColor = false,
			Parent = row,
		})
		Corner(btn, 8)
		Rim(btn, 0.2)

		local unknown = Enum.KeyCode.Unknown
		local el = { Value = o.Default or unknown, Flag = o.Flag, Type = "Keybind" }
		local listening = false

		local function show()
			if listening then
				btn.Text = "..."
			else
				btn.Text = (el.Value == unknown) and "None" or keyDisplay(el.Value)
			end
			btn.TextColor3 = listening and Deep(ctx.accent) or Theme.SubText
		end

		method(el, "Set", function(_, key, silent)
			key = normalizeKey(key)
			if not key then
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
			Position = UDim2.fromOffset(14, 0),
			Size = UDim2.new(0.5, -18, 1, 0),
			TextTruncate = Enum.TextTruncate.AtEnd,
			Parent = row,
		})
		local box = New("TextBox", {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -8, 0.5, 0),
			Size = UDim2.new(0.5, -8, 0, RowH - 12),
			BackgroundColor3 = Theme.Glass,
			BackgroundTransparency = 0.25,
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
		Corner(box, 8)
		Pad(box, 0, 8, 0, 8)
		local focusRing = Stroke(box, ctx.accent, 1, 1.5)

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
			focusRing.Color = ctx.accent
			tween(focusRing, { Transparency = 0 }, 0.2)
			tween(box, { BackgroundTransparency = 0.05 }, 0.2)
		end)
		box.FocusLost:Connect(function()
			tween(focusRing, { Transparency = 1 }, 0.2)
			tween(box, { BackgroundTransparency = 0.25 }, 0.2)
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
		Pad(row, 10, 14, 10, 14)
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
-- Keybind panel: glass sheet to add/remove multiple keys for one element
------------------------------------------------------------------------
local function buildKeyPanel(ctx, Main)
	local overlay = New("TextButton", {
		Name = "KeyOverlay",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(150, 70, 95),
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
		Visible = false,
		ZIndex = 50,
		Parent = Main,
	})

	local panel = New("CanvasGroup", {
		Name = "KeyPanel",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 16),
		Size = UDim2.new(0, 296, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Theme.Background,
		BackgroundTransparency = 0.05,
		GroupTransparency = 1,
		Active = true,
		Visible = false,
		ZIndex = 51,
		Parent = Main,
	})
	Corner(panel, 18)
	Rim(panel, 0, 1.5)
	Gloss(panel, 0, 0.2)
	Pad(panel, 16)
	local ps = New("UIScale", { Scale = 0.9, Parent = panel })
	New("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = panel })

	Label({
		Text = "Keybinds",
		Font = Theme.FontBold,
		TextSize = 16,
		Size = UDim2.new(1, 0, 0, 20),
		LayoutOrder = 1,
		Parent = panel,
	})
	local sub = Label({
		Text = "",
		TextSize = 12,
		TextColor3 = Theme.SubText,
		Size = UDim2.new(1, 0, 0, 16),
		TextTruncate = Enum.TextTruncate.AtEnd,
		LayoutOrder = 2,
		Parent = panel,
	})
	local listFrame = New("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = 3,
		Parent = panel,
	})
	New("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = listFrame })

	local addBtn = New("TextButton", {
		Size = UDim2.new(1, 0, 0, 36),
		BackgroundColor3 = Theme.Glass,
		BackgroundTransparency = 0.35,
		Text = "+  Add key",
		Font = Theme.FontBold,
		TextSize = 13,
		TextColor3 = Theme.Text,
		AutoButtonColor = false,
		LayoutOrder = 4,
		Parent = panel,
	})
	Corner(addBtn, 11)
	Rim(addBtn, 0.15)
	local addScale = New("UIScale", { Parent = addBtn })

	local doneBtn = New("TextButton", {
		Size = UDim2.new(1, 0, 0, 36),
		BackgroundColor3 = ctx.accent,
		BackgroundTransparency = 0.1,
		Text = "Done",
		Font = Theme.FontBold,
		TextSize = 13,
		TextColor3 = Theme.White,
		TextStrokeColor3 = Color3.fromRGB(190, 80, 120),
		TextStrokeTransparency = 0.75,
		AutoButtonColor = false,
		LayoutOrder = 5,
		Parent = panel,
	})
	Corner(doneBtn, 11)
	Rim(doneBtn, 0)
	Gloss(doneBtn, 0, 0.25)
	local doneScale = New("UIScale", { Parent = doneBtn })
	ctx.bind(function(c)
		doneBtn.BackgroundColor3 = c
	end)

	local cur, curMax, listening, token = nil, 5, false, 0

	local function refresh()
		for _, c in ipairs(listFrame:GetChildren()) do
			if c:IsA("GuiObject") then
				c:Destroy()
			end
		end
		local keys = cur and cur._keys or {}
		if #keys == 0 then
			Label({
				Text = "No keys bound yet",
				TextSize = 12,
				TextColor3 = Theme.SubText,
				TextXAlignment = Enum.TextXAlignment.Center,
				Size = UDim2.new(1, 0, 0, 30),
				Parent = listFrame,
			})
		end
		for i, key in ipairs(keys) do
			local chip = New("Frame", {
				Size = UDim2.new(1, 0, 0, 34),
				BackgroundColor3 = Theme.Glass,
				BackgroundTransparency = 1,
				LayoutOrder = i,
				Parent = listFrame,
			})
			Corner(chip, 10)
			Rim(chip, 0.2)
			tween(chip, { BackgroundTransparency = 0.4 }, 0.3)
			Label({
				Text = keyDisplay(key),
				Font = Theme.FontBold,
				Position = UDim2.fromOffset(12, 0),
				Size = UDim2.new(1, -50, 1, 0),
				Parent = chip,
			})
			local x = New("TextButton", {
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -5, 0.5, 0),
				Size = UDim2.fromOffset(26, 26),
				BackgroundColor3 = Theme.Glass,
				BackgroundTransparency = 0.5,
				Text = "×",
				Font = Theme.FontBold,
				TextSize = 17,
				TextColor3 = Theme.SubText,
				AutoButtonColor = false,
				Parent = chip,
			})
			Corner(x, 13)
			x.MouseEnter:Connect(function()
				tween(x, { BackgroundTransparency = 0.1, TextColor3 = Deep(ctx.accent) }, 0.12)
			end)
			x.MouseLeave:Connect(function()
				tween(x, { BackgroundTransparency = 0.5, TextColor3 = Theme.SubText }, 0.15)
			end)
			x.MouseButton1Click:Connect(function()
				if cur then
					cur:RemoveKey(key)
				end
			end)
		end
		addBtn.Text = (#keys >= curMax) and "Limit reached" or "+  Add key"
		addBtn.TextColor3 = Theme.Text
		tween(addBtn, { BackgroundColor3 = Theme.Glass, BackgroundTransparency = 0.35 }, 0.2)
	end

	local function shake()
		task.spawn(function()
			for _, dx in ipairs({ 8, -8, 5, 0 }) do
				tween(panel, { Position = UDim2.new(0.5, dx, 0.5, 0) }, 0.05)
				task.wait(0.05)
			end
		end)
	end

	function ctx.closeKeybindPanel()
		if not overlay.Visible then
			return
		end
		listening = false
		ctx.listening = false
		token += 1
		local mine = token
		if cur then
			cur._panelRefresh = nil
		end
		cur = nil
		tween(overlay, { BackgroundTransparency = 1 }, 0.2)
		tween(panel, { GroupTransparency = 1, Position = UDim2.new(0.5, 0, 0.5, 10) }, 0.2)
		tween(ps, { Scale = 0.94 }, 0.2)
		task.delay(0.22, function()
			if token == mine then
				overlay.Visible = false
				panel.Visible = false
			end
		end)
	end

	function ctx.openKeybindPanel(el, name, max)
		if cur and cur ~= el then
			cur._panelRefresh = nil
		end
		cur, curMax = el, max or 5
		el._panelRefresh = refresh
		sub.Text = tostring(name)
		listening = false
		refresh()
		token += 1
		overlay.Visible = true
		panel.Visible = true
		panel.Position = UDim2.new(0.5, 0, 0.5, 16)
		ps.Scale = 0.9
		tween(overlay, { BackgroundTransparency = 0.55 }, 0.25)
		tween(panel, { GroupTransparency = 0, Position = UDim2.fromScale(0.5, 0.5) }, 0.4, Quint)
		tween(ps, { Scale = 1 }, 0.45, Back)
	end

	-- Button interactions
	addBtn.MouseEnter:Connect(function()
		tween(addScale, { Scale = 1.02 }, 0.15, Quint)
	end)
	addBtn.MouseLeave:Connect(function()
		tween(addScale, { Scale = 1 }, 0.15, Quint)
	end)
	addBtn.MouseButton1Click:Connect(function()
		if not cur or #cur._keys >= curMax then
			shake()
			return
		end
		listening = true
		ctx.listening = true
		addBtn.Text = "Press a key...  (Esc cancels)"
		addBtn.TextColor3 = Theme.White
		tween(addBtn, { BackgroundColor3 = ctx.accent, BackgroundTransparency = 0.15 }, 0.2)
	end)
	doneBtn.MouseEnter:Connect(function()
		tween(doneScale, { Scale = 1.02 }, 0.15, Quint)
	end)
	doneBtn.MouseLeave:Connect(function()
		tween(doneScale, { Scale = 1 }, 0.15, Quint)
	end)
	doneBtn.MouseButton1Click:Connect(function()
		ctx.closeKeybindPanel()
	end)
	overlay.MouseButton1Click:Connect(function()
		ctx.closeKeybindPanel()
	end)

	ctx.track(UserInputService.InputBegan:Connect(function(input)
		if not cur then
			return
		end
		if listening then
			if input.UserInputType == Enum.UserInputType.Keyboard then
				listening = false
				task.defer(function()
					ctx.listening = false
				end)
				if input.KeyCode ~= Enum.KeyCode.Escape then
					if not cur:AddKey(input.KeyCode) then
						shake()
					end
				end
				refresh()
			end
			return
		end
		if input.KeyCode == Enum.KeyCode.Escape and overlay.Visible then
			ctx.closeKeybindPanel()
		end
	end))
end

------------------------------------------------------------------------
-- Logo: an original cat-face mark built from Gui objects
-- (pass opts.Logo = "rbxassetid://..." to use your own image instead)
------------------------------------------------------------------------
local function buildLogo(parent, ctx, image)
	local holder = New("Frame", {
		Name = "Logo",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 16, 0.5, -1.5),
		Size = UDim2.fromOffset(34, 34),
		BackgroundTransparency = 1,
		Parent = parent,
	})
	local eyes = {}

	if type(image) == "string" and image ~= "" then
		New("ImageLabel", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Image = image,
			ScaleType = Enum.ScaleType.Fit,
			Parent = holder,
		})
		return holder, eyes
	end

	local pieces = {}

	local function ear(x)
		local e = New("Frame", {
			Position = UDim2.fromOffset(x, 3),
			Size = UDim2.fromOffset(11, 11),
			Rotation = 45,
			BackgroundColor3 = ctx.accent,
			Parent = holder,
		})
		Corner(e, 3)
		pieces[#pieces + 1] = e
		local inner = New("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(5, 5),
			BackgroundColor3 = Theme.White,
			BackgroundTransparency = 0.35,
			Parent = e,
		})
		Corner(inner, 2)
	end
	ear(4)
	ear(19)

	local head = New("Frame", {
		Position = UDim2.fromOffset(2, 9),
		Size = UDim2.fromOffset(30, 23),
		BackgroundColor3 = ctx.accent,
		Parent = holder,
	})
	Corner(head, 12)
	Shade(head)
	Rim(head, 0.1, 1.2)
	pieces[#pieces + 1] = head

	local function eye(x)
		local e = New("Frame", {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.fromOffset(x, 11),
			Size = UDim2.fromOffset(4, 6),
			BackgroundColor3 = Theme.Text,
			Parent = head,
		})
		Corner(e, 3)
		eyes[#eyes + 1] = e
	end
	eye(8)
	eye(18)

	local nose = New("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 15),
		Size = UDim2.fromOffset(6, 4),
		BackgroundColor3 = Theme.White,
		Parent = head,
	})
	Corner(nose, 2)

	ctx.bind(function(c)
		for _, p in ipairs(pieces) do
			p.BackgroundColor3 = c
		end
	end)
	return holder, eyes
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
	local ctx = {
		listening = false,
		flags = {},
		accent = opts.Accent or Theme.Accent,
		window = window,
		keyElements = {},
		defaultKeybinds = opts.Keybinds == true,
	}
	local conns, accentFns, loopTweens = {}, {}, {}

	function ctx.track(c)
		conns[#conns + 1] = c
		return c
	end
	function ctx.bind(fn)
		accentFns[#accentFns + 1] = fn
		fn(ctx.accent)
	end
	function ctx.closeKeybindPanel() end

	Library.Accent = ctx.accent
	local size = opts.Size or UDim2.fromOffset(580, 430)
	local titleText = (opts.Title == nil or opts.Title == "Kisha") and "Kisha UI" or opts.Title

	-- Root -------------------------------------------------------------
	local Root = New("Frame", {
		Name = "Window",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = size,
		BackgroundTransparency = 1,
		Parent = gui,
	})
	local fitScale = New("UIScale", { Parent = Root })

	-- Depth: layered soft drop shadow ---------------------------------
	local shadow = New("CanvasGroup", {
		Name = "Shadow",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 12),
		Size = UDim2.new(1, 120, 1, 120),
		BackgroundTransparency = 1,
		GroupTransparency = 1,
		Parent = Root,
	})
	local shadowScale = New("UIScale", { Scale = 0.94, Parent = shadow })
	for i = 1, 6 do
		local layer = New("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.new(1, -120 + i * 10, 1, -120 + i * 10),
			BackgroundColor3 = Theme.ShadowColor,
			BackgroundTransparency = 0.955,
			BorderSizePixel = 0,
			Parent = shadow,
		})
		Corner(layer, Theme.WindowRadius + i * 5)
	end

	-- Spinning light outline around the whole window ------------------
	local halo = New("CanvasGroup", {
		Name = "Halo",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, 40, 1, 40),
		BackgroundTransparency = 1,
		GroupTransparency = 1,
		Parent = Root,
	})
	local haloScale = New("UIScale", { Scale = 0.94, Parent = halo })

	local function haloColors(c)
		local light = c:Lerp(Theme.White, 0.35)
		return ColorSequence.new({
			ColorSequenceKeypoint.new(0, light),
			ColorSequenceKeypoint.new(0.9, Theme.White),
			ColorSequenceKeypoint.new(1, light),
		})
	end

	local function haloRing(inset, thickness, baseAlpha, radiusAdd, seq)
		local f = New("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.new(1, -(40 - inset * 2), 1, -(40 - inset * 2)),
			BackgroundTransparency = 1,
			Parent = halo,
		})
		Corner(f, Theme.WindowRadius + radiusAdd)
		local stroke = New("UIStroke", {
			Thickness = thickness,
			Transparency = baseAlpha,
			Color = Theme.White,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Parent = f,
		})
		local grad = New("UIGradient", { Transparency = seq, Color = haloColors(ctx.accent), Parent = stroke })
		local spin = TweenService:Create(
			grad,
			TweenInfo.new(3.4, Enum.EasingStyle.Linear, Enum.EasingDirection.Out, -1),
			{ Rotation = 360 }
		)
		loopTweens[#loopTweens + 1] = spin
		return grad
	end

	-- soft wide glow + crisp line (faint base ring with a bright comet)
	local glowGrad = haloRing(4, 7, 0.7, 4, NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.5, 1),
		NumberSequenceKeypoint.new(0.85, 0.55),
		NumberSequenceKeypoint.new(0.96, 0.05),
		NumberSequenceKeypoint.new(1, 1),
	}))
	local lineGrad = haloRing(3, 2.5, 0, 3, NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.82),
		NumberSequenceKeypoint.new(0.5, 0.82),
		NumberSequenceKeypoint.new(0.8, 0.35),
		NumberSequenceKeypoint.new(0.94, 0),
		NumberSequenceKeypoint.new(1, 0.82),
	}))
	ctx.bind(function(c)
		glowGrad.Color = haloColors(c)
		lineGrad.Color = haloColors(c)
	end)

	-- Main -------------------------------------------------------------
	local Main = New("CanvasGroup", {
		Name = "Main",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 14),
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Theme.Background,
		BackgroundTransparency = Theme.WindowAlpha,
		BorderSizePixel = 0,
		GroupTransparency = 1,
		Parent = Root,
	})
	local pop = New("UIScale", { Scale = 0.92, Parent = Main })
	Corner(Main, Theme.WindowRadius)
	Rim(Main, 0, 1.5)

	-- Liquid sheen (follows the cursor) + color bloom (counter-moves)
	local sheen = New("Frame", {
		Name = "Sheen",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Theme.White,
		BorderSizePixel = 0,
		Parent = Main,
	})
	local sheenGrad = New("UIGradient", {
		Rotation = 35,
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.5),
			NumberSequenceKeypoint.new(0.4, 0.82),
			NumberSequenceKeypoint.new(1, 0.95),
		}),
		Parent = sheen,
	})
	local bloom = New("Frame", {
		Name = "Bloom",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = ctx.accent:Lerp(Theme.White, 0.2),
		BorderSizePixel = 0,
		Parent = Main,
	})
	local bloomGrad = New("UIGradient", {
		Rotation = 35,
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.6, 0.93),
			NumberSequenceKeypoint.new(1, 0.72),
		}),
		Parent = bloom,
	})
	ctx.bind(function(c)
		bloom.BackgroundColor3 = c:Lerp(Theme.White, 0.2)
	end)

	local lastSheen = 0
	ctx.track(UserInputService.InputChanged:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.MouseMovement or not window.Visible then
			return
		end
		local now = os.clock()
		if now - lastSheen < 0.04 then
			return
		end
		lastSheen = now
		local ap, as = Main.AbsolutePosition, Main.AbsoluteSize
		if as.X <= 0 or as.Y <= 0 then
			return
		end
		local m = UserInputService:GetMouseLocation()
		local dx = math.clamp((m.X - ap.X) / as.X - 0.5, -0.8, 0.8)
		local dy = math.clamp((m.Y - ap.Y) / as.Y - 0.5, -0.8, 0.8)
		tween(sheenGrad, { Offset = Vector2.new(dx * 0.6, dy * 0.6) }, 0.35)
		tween(bloomGrad, { Offset = Vector2.new(-dx * 0.4, -dy * 0.4) }, 0.5)
	end))

	buildKeyPanel(ctx, Main)

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
		Size = UDim2.new(1, 0, 0, 56),
		BackgroundTransparency = 1,
		Parent = Main,
	})
	local logo, logoEyes = buildLogo(header, ctx, opts.Logo)
	loopTweens[#loopTweens + 1] = TweenService:Create(
		logo,
		TweenInfo.new(2.4, Sine, Enum.EasingDirection.InOut, -1, true),
		{ Position = UDim2.new(0, 16, 0.5, 1.5) }
	)

	local hasSub = opts.Subtitle and opts.Subtitle ~= ""
	Label({
		Text = titleText,
		Font = Theme.FontBold,
		TextSize = 17,
		Position = UDim2.fromOffset(60, hasSub and 9 or 0),
		Size = UDim2.new(1, -112, 0, hasSub and 21 or 56),
		Parent = header,
	})
	if hasSub then
		Label({
			Text = opts.Subtitle,
			TextSize = 11,
			TextColor3 = Theme.SubText,
			Position = UDim2.fromOffset(60, 30),
			Size = UDim2.new(1, -112, 0, 14),
			Parent = header,
		})
	end

	local closeBtn = New("TextButton", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -14, 0.5, 0),
		Size = UDim2.fromOffset(32, 32),
		BackgroundColor3 = Theme.Glass,
		BackgroundTransparency = 0.5,
		Text = "×",
		Font = Theme.FontBold,
		TextSize = 20,
		TextColor3 = Theme.SubText,
		AutoButtonColor = false,
		Parent = header,
	})
	Corner(closeBtn, 16)
	Rim(closeBtn, 0.2)
	closeBtn.MouseEnter:Connect(function()
		tween(closeBtn, { BackgroundTransparency = 0.15, TextColor3 = Theme.Text, Rotation = 90 }, 0.3, Back)
	end)
	closeBtn.MouseLeave:Connect(function()
		tween(closeBtn, { BackgroundTransparency = 0.5, TextColor3 = Theme.SubText, Rotation = 0 }, 0.3, Quint)
	end)

	-- Specular top edge + header divider
	local edge = New("Frame", {
		Position = UDim2.fromOffset(24, 1),
		Size = UDim2.new(1, -48, 0, 1),
		BackgroundColor3 = Theme.White,
		BorderSizePixel = 0,
		Parent = Main,
	})
	New("UIGradient", {
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.5, 0),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Parent = edge,
	})
	New("Frame", {
		Position = UDim2.fromOffset(0, 56),
		Size = UDim2.new(1, 0, 0, 1),
		BackgroundColor3 = Theme.White,
		BackgroundTransparency = 0.45,
		BorderSizePixel = 0,
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
		Position = UDim2.fromOffset(0, 57),
		Size = UDim2.new(1, 0, 1, -57),
		BackgroundTransparency = 1,
		Parent = Main,
	})
	local sidebar = New("Frame", {
		Size = UDim2.new(0, 138, 1, 0),
		BackgroundColor3 = Theme.Glass,
		BackgroundTransparency = 0.7,
		BorderSizePixel = 0,
		Parent = body,
	})
	New("Frame", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.new(0, 1, 1, 0),
		BackgroundColor3 = Theme.White,
		BackgroundTransparency = 0.5,
		BorderSizePixel = 0,
		Parent = sidebar,
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
	Pad(tabList, 12, 10, 12, 10)

	local tabHolder = New("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Parent = tabList,
	})
	-- Sliding highlight pill that glides between tabs
	local highlight = New("Frame", {
		Name = "Highlight",
		Size = UDim2.new(1, 0, 0, 38),
		BackgroundColor3 = ctx.accent,
		BackgroundTransparency = 0.45,
		Visible = false,
		Parent = tabHolder,
	})
	Corner(highlight, 12)
	Rim(highlight, 0.1)
	Gloss(highlight, 0, 0.3)
	local hbar = New("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 5, 0.5, 0),
		Size = UDim2.fromOffset(3, 16),
		BackgroundColor3 = Theme.White,
		BackgroundTransparency = 0.15,
		Parent = highlight,
	})
	Corner(hbar, 2)
	ctx.bind(function(c)
		highlight.BackgroundColor3 = c
	end)

	local tabButtons = New("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Parent = tabHolder,
	})
	New("UIListLayout", { Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder, Parent = tabButtons })

	local content = New("Frame", {
		Position = UDim2.fromOffset(138, 0),
		Size = UDim2.new(1, -138, 1, 0),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		Parent = body,
	})

	-- Tabs -------------------------------------------------------------
	local function selectTab(tab)
		if window.Selected == tab then
			return
		end
		local first = window.Selected == nil
		window.Selected = tab
		local idx = table.find(window.Tabs, tab) or 1
		highlight.Visible = true
		tween(highlight, { Position = UDim2.fromOffset(0, (idx - 1) * 43) }, first and 0 or 0.4, Quint)
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
			BackgroundColor3 = Theme.White,
			BackgroundTransparency = 1,
			Text = "",
			AutoButtonColor = false,
			LayoutOrder = #window.Tabs + 1,
			Parent = tabButtons,
		})
		Corner(btn, 12)

		local textX = 16
		local icon = tabOpts.Icon
		if type(icon) == "string" and icon ~= "" then
			if icon:match("^rbxasset") then
				New("ImageLabel", {
					AnchorPoint = Vector2.new(0, 0.5),
					Position = UDim2.new(0, 16, 0.5, 0),
					Size = UDim2.fromOffset(16, 16),
					BackgroundTransparency = 1,
					Image = icon,
					ImageColor3 = Theme.SubText,
					Parent = btn,
				})
			else
				Label({
					Text = icon,
					Position = UDim2.fromOffset(14, 0),
					Size = UDim2.fromOffset(18, 38),
					TextXAlignment = Enum.TextXAlignment.Center,
					Parent = btn,
				})
			end
			textX = 38
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
		Pad(page, 14, 16, 14, 14)
		New("UIListLayout", { Padding = UDim.new(0, 12), SortOrder = Enum.SortOrder.LayoutOrder, Parent = page })

		local active = false
		function tab._setActive(v)
			active = v
			tween(lbl, { TextColor3 = v and Theme.Text or Theme.SubText }, 0.25)
			if v then
				page.Visible = true
				page.Position = UDim2.fromOffset(0, 18)
				tween(page, { Position = UDim2.fromOffset(0, 0) }, 0.5, Quint)
				for i, s in ipairs(tab.Sections) do
					local inst = s.Instance
					if inst then
						inst.BackgroundTransparency = 1
						task.delay((i - 1) * 0.07, function()
							tween(inst, { BackgroundTransparency = Theme.CardAlpha }, 0.4)
						end)
					end
				end
			else
				page.Visible = false
			end
		end

		btn.MouseEnter:Connect(function()
			if not active then
				tween(btn, { BackgroundTransparency = 0.82 }, 0.12)
				tween(lbl, { TextColor3 = Theme.Text }, 0.12)
			end
		end)
		btn.MouseLeave:Connect(function()
			if not active then
				tween(btn, { BackgroundTransparency = 1 }, 0.15)
				tween(lbl, { TextColor3 = Theme.SubText }, 0.15)
			end
		end)
		btn.MouseButton1Click:Connect(function()
			selectTab(tab)
		end)
		ctx.bind(function(c)
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
				BackgroundColor3 = Theme.Glass,
				BackgroundTransparency = Theme.CardAlpha,
				BorderSizePixel = 0,
				LayoutOrder = #tab.Sections + 1,
				Parent = page,
			})
			Corner(frame, Theme.CardRadius)
			Rim(frame, 0.25)
			Gloss(frame, 0, 0.25)
			Pad(frame, 10, 10, 10, 10)
			New("UIListLayout", { Padding = UDim.new(0, 7), SortOrder = Enum.SortOrder.LayoutOrder, Parent = frame })

			local title = Label({
				Text = string.upper(section.Name),
				Font = Theme.FontBold,
				TextSize = 11,
				TextColor3 = Deep(ctx.accent),
				Size = UDim2.new(1, 0, 0, 18),
				LayoutOrder = 0,
				Parent = frame,
			})
			Pad(title, 0, 0, 0, 4)
			ctx.bind(function(c)
				title.TextColor3 = Deep(c)
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

	-- Optional screen blur (frosted-glass effect behind the window) ----
	local blur
	local blurSize = tonumber(opts.BlurSize) or 14
	if opts.Blur ~= false then
		pcall(function()
			blur = New("BlurEffect", {
				Name = "KishaBlur",
				Size = 0,
				Parent = game:GetService("Lighting"),
			})
		end)
	end

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
		if blur then
			tween(blur, { Size = v and blurSize or 0 }, 0.35)
		end
		if v then
			Root.Visible = true
			for _, t in ipairs(loopTweens) do
				t:Play()
			end
			tween(Main, { GroupTransparency = 0, Position = UDim2.fromScale(0.5, 0.5) }, 0.45, Quint)
			tween(pop, { Scale = 1 }, 0.55, Back)
			tween(shadow, { GroupTransparency = 0 }, 0.6)
			tween(halo, { GroupTransparency = 0 }, 0.6)
			tween(shadowScale, { Scale = 1 }, 0.55, Back)
			tween(haloScale, { Scale = 1 }, 0.55, Back)
		else
			ctx.closeKeybindPanel()
			tween(Main, { GroupTransparency = 1, Position = UDim2.new(0.5, 0, 0.5, 10) }, 0.22, Quint)
			tween(pop, { Scale = 0.94 }, 0.22, Quint)
			tween(shadow, { GroupTransparency = 1 }, 0.22)
			tween(halo, { GroupTransparency = 1 }, 0.22)
			tween(shadowScale, { Scale = 0.94 }, 0.22, Quint)
			tween(haloScale, { Scale = 0.94 }, 0.22, Quint)
			task.delay(0.25, function()
				if token == mine and not window.Destroyed then
					Root.Visible = false
					for _, t in ipairs(loopTweens) do
						t:Pause()
					end
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

	-- Window toggle key + element keybinds ----------------------------
	ctx.track(UserInputService.InputBegan:Connect(function(input, processed)
		if processed or ctx.listening then
			return
		end
		local key = input.KeyCode
		if key == Enum.KeyCode.Unknown then
			return
		end
		if key == window.ToggleKey then
			window:SetVisible(not window.Visible)
			return
		end
		for el in pairs(ctx.keyElements) do
			if el._keys and table.find(el._keys, key) then
				pcall(el._trigger)
			end
		end
	end))

	-- Logo blink ---------------------------------------------------------
	task.spawn(function()
		while not window.Destroyed do
			task.wait(math.random(30, 70) / 10)
			if window.Destroyed then
				break
			end
			if window.Visible then
				for _, e in ipairs(logoEyes) do
					tween(e, { Size = UDim2.fromOffset(4, 1) }, 0.07)
				end
				task.wait(0.12)
				for _, e in ipairs(logoEyes) do
					tween(e, { Size = UDim2.fromOffset(4, 6) }, 0.1)
				end
			end
		end
	end)

	-- Mobile launcher (no keyboard = no toggle key) --------------------
	local launcher
	local wantLauncher = opts.MobileButton == true
		or (opts.MobileButton ~= false and UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled)
	if wantLauncher then
		launcher = New("TextButton", {
			Name = "KishaLauncher",
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 10, 0.5, 0),
			Size = UDim2.fromOffset(48, 48),
			BackgroundColor3 = ctx.accent,
			BackgroundTransparency = 0.1,
			Text = "K",
			Font = Theme.FontBold,
			TextSize = 19,
			TextColor3 = Theme.White,
			TextStrokeColor3 = Color3.fromRGB(190, 80, 120),
			TextStrokeTransparency = 0.75,
			AutoButtonColor = false,
			Parent = gui,
		})
		Corner(launcher, 24)
		Rim(launcher, 0)
		Gloss(launcher, 0, 0.3)
		local ls = New("UIScale", { Parent = launcher })
		launcher.MouseButton1Down:Connect(function()
			tween(ls, { Scale = 0.88 }, 0.08)
		end)
		launcher.MouseButton1Click:Connect(function()
			tween(ls, { Scale = 1 }, 0.3, Back)
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
		table.clear(ctx.keyElements)
		for _, t in ipairs(loopTweens) do
			pcall(function()
				t:Cancel()
			end)
		end
		table.clear(loopTweens)
		for _, flag in ipairs(ctx.flags) do
			Library.Flags[flag] = nil
			Library._registry[flag] = nil
		end
		Root:Destroy()
		if launcher then
			launcher:Destroy()
		end
		if blur then
			blur:Destroy()
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
