-- Kisha demo: one of each element.
local URL = "https://raw.githubusercontent.com/mialmos/Kisha-ui/refs/heads/main/Kisha.lua"
local Kisha = loadstring(game:HttpGet(URL))()

local Window = Kisha:CreateWindow({
	Title = "Kisha",
	Subtitle = "demo",
	Accent = Color3.fromRGB(62, 112, 255),
	ToggleKey = Enum.KeyCode.RightControl,
	Size = UDim2.fromOffset(560, 420),
})

local Main = Window:CreateTab({ Name = "Main", Icon = "★" })
local Settings = Window:CreateTab({ Name = "Settings", Icon = "⚙" })

local Movement = Main:CreateSection({ Name = "Movement" })

Movement:AddToggle({
	Name = "Example",
	Default = false,
	Flag = "example_toggle",
	Callback = function(value)
		print("toggle:", value)
	end,
})

Movement:AddSlider({
	Name = "Speed",
	Min = 0, Max = 100, Default = 10, Increment = 1,
	Flag = "speed",
	Callback = function(value)
		print("speed:", value)
	end,
})

Movement:AddDropdown({
	Name = "Mode",
	Options = { "A", "B", "C" },
	Default = "A",
	Flag = "mode",
	Callback = function(value)
		print("mode:", value)
	end,
})

Movement:AddButton({
	Name = "Run",
	Callback = function()
		Kisha:Notify({ Title = "Kisha", Content = "Button pressed", Duration = 3 })
	end,
})

Movement:AddParagraph({ Title = "Info", Body = "Drag the header to move. Press the toggle key to hide." })

local Misc = Settings:CreateSection({ Name = "Interface" })

Misc:AddKeybind({
	Name = "Menu Key",
	Default = Enum.KeyCode.RightControl,
	BindToggle = true, -- rebinding also changes the window toggle key
	Callback = function(key)
		print("menu key:", key)
	end,
})

Misc:AddTextbox({
	Name = "Input",
	Placeholder = "type here...",
	Default = "",
	Flag = "input",
	Callback = function(text)
		print("text:", text)
	end,
})

Misc:AddButton({
	Name = "Save config",
	Callback = function()
		Kisha:Notify({ Title = "Config", Content = Kisha:SaveConfig("demo") and "Saved" or "Not available", Duration = 3 })
	end,
})

Misc:AddButton({
	Name = "Load config",
	Callback = function()
		Kisha:Notify({ Title = "Config", Content = Kisha:LoadConfig("demo") and "Loaded" or "Not found", Duration = 3 })
	end,
})

Kisha:Notify({ Title = "Kisha", Content = "Loaded", Duration = 3 })
