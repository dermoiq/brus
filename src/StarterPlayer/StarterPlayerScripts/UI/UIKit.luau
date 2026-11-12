--!strict
-- Tiny UI toolkit so every panel/button shares one polished style (gradients, rounded corners,
-- outlined text, press animations, resolution-aware scaling).

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local UIKit = {}

UIKit.Colors = {
	PanelTop = Color3.fromRGB(58, 44, 98),
	PanelBottom = Color3.fromRGB(26, 20, 46),
	Card = Color3.fromRGB(44, 34, 76),
	Accent = Color3.fromRGB(150, 96, 255),
	Gold = Color3.fromRGB(255, 204, 72),
	Green = Color3.fromRGB(64, 214, 118),
	Red = Color3.fromRGB(240, 80, 96),
	Blue = Color3.fromRGB(70, 160, 255),
	Pink = Color3.fromRGB(255, 96, 180),
	Grey = Color3.fromRGB(110, 106, 130),
	Text = Color3.fromRGB(255, 255, 255),
	Muted = Color3.fromRGB(200, 190, 230),
	Outline = Color3.fromRGB(16, 10, 30),
}

UIKit.Fonts = {
	Display = Enum.Font.FredokaOne,
	Body = Enum.Font.BuilderSansBold,
}

function UIKit.Create(className: string, props: { [string]: any }?, children: { any }?): any
	local instance = Instance.new(className)
	local parent = nil
	if props then
		for key, value in props do
			if key == "Parent" then
				parent = value
			else
				(instance :: any)[key] = value
			end
		end
	end
	if children then
		for _, child in children do
			child.Parent = instance
		end
	end
	if parent then
		instance.Parent = parent
	end
	return instance
end

function UIKit.Corner(radius: number?): Instance
	return UIKit.Create("UICorner", { CornerRadius = UDim.new(0, radius or 12) })
end

function UIKit.Stroke(color: Color3, thickness: number, transparency: number?): Instance
	return UIKit.Create("UIStroke", {
		Color = color,
		Thickness = thickness,
		Transparency = transparency or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

function UIKit.Gradient(top: Color3, bottom: Color3): Instance
	return UIKit.Create("UIGradient", { Color = ColorSequence.new(top, bottom), Rotation = 90 })
end

function UIKit.Padding(pixels: number): Instance
	local p = UDim.new(0, pixels)
	return UIKit.Create("UIPadding", { PaddingTop = p, PaddingBottom = p, PaddingLeft = p, PaddingRight = p })
end

function UIKit.ScreenGui(name: string, displayOrder: number): ScreenGui
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local existing = playerGui:FindFirstChild(name)
	if existing then
		existing:Destroy()
	end
	return UIKit.Create("ScreenGui", {
		Name = name,
		DisplayOrder = displayOrder,
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = playerGui,
	})
end

-- Scales a panel around its AnchorPoint so it reads the same on phones and 4K monitors.
function UIKit.AutoScale(gui: GuiObject, designHeight: number?)
	local scale = UIKit.Create("UIScale", { Parent = gui })
	local function update()
		local camera = Workspace.CurrentCamera
		if camera then
			scale.Scale = math.clamp(camera.ViewportSize.Y / (designHeight or 820), 0.55, 1.25)
		end
	end
	update()
	local camera = Workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(update)
	end
end

function UIKit.Panel(props: { [string]: any }): Frame
	local frame = UIKit.Create("Frame", props)
	frame.BackgroundColor3 = Color3.new(1, 1, 1)
	frame.BorderSizePixel = 0
	UIKit.Corner(16).Parent = frame
	UIKit.Gradient(UIKit.Colors.PanelTop, UIKit.Colors.PanelBottom).Parent = frame
	UIKit.Stroke(Color3.new(1, 1, 1), 2, 0.8).Parent = frame
	return frame
end

function UIKit.Label(props: { [string]: any }): TextLabel
	local label = UIKit.Create("TextLabel", {
		BackgroundTransparency = 1,
		Font = UIKit.Fonts.Display,
		TextColor3 = UIKit.Colors.Text,
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	for key, value in props do
		if key ~= "Parent" then
			(label :: any)[key] = value
		end
	end
	UIKit.Create("UIStroke", { Color = UIKit.Colors.Outline, Thickness = 2, Parent = label })
	label.Parent = props.Parent
	return label
end

local function pressFeedback(button: GuiButton)
	local scale = UIKit.Create("UIScale", { Name = "PressScale", Parent = button })
	local quick = TweenInfo.new(0.08, Enum.EasingStyle.Quad)
	local bounce = TweenInfo.new(0.25, Enum.EasingStyle.Back)
	button.MouseEnter:Connect(function()
		TweenService:Create(scale, quick, { Scale = 1.05 }):Play()
	end)
	button.MouseLeave:Connect(function()
		TweenService:Create(scale, quick, { Scale = 1 }):Play()
	end)
	button.MouseButton1Down:Connect(function()
		TweenService:Create(scale, quick, { Scale = 0.92 }):Play()
	end)
	button.MouseButton1Up:Connect(function()
		TweenService:Create(scale, bounce, { Scale = 1 }):Play()
	end)
end

-- Text lives in a child "Label" so it can have its own outline while the button keeps a border stroke.
function UIKit.Button(props: { [string]: any }, text: string, color: Color3): TextButton
	local button = UIKit.Create("TextButton", {
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
	})
	for key, value in props do
		if key ~= "Parent" then
			(button :: any)[key] = value
		end
	end
	UIKit.Corner(12).Parent = button
	UIKit.Create("UIGradient", { Name = "Fill", Rotation = 90, Parent = button })
	UIKit.Stroke(UIKit.Colors.Outline, 2, 0.2).Parent = button
	UIKit.Label({
		Name = "Label",
		Size = UDim2.new(1, -12, 1, -8),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = button,
	})
	pressFeedback(button)
	UIKit.SetButton(button, text, color)
	button.Parent = props.Parent
	return button
end

function UIKit.SetButton(button: GuiButton, text: string, color: Color3)
	local label = button:FindFirstChild("Label")
	if label and label:IsA("TextLabel") then
		label.Text = text
	end
	local fill = button:FindFirstChild("Fill")
	if fill and fill:IsA("UIGradient") then
		fill.Color = ColorSequence.new(color:Lerp(Color3.new(1, 1, 1), 0.25), color:Lerp(Color3.new(0, 0, 0), 0.2))
	end
end

-- Quick "juice" bounce on any GuiObject that has (or gets) a UIScale named "PopScale".
function UIKit.Pop(gui: GuiObject, from: number?)
	local scale = gui:FindFirstChild("PopScale") :: UIScale?
	if not scale then
		scale = UIKit.Create("UIScale", { Name = "PopScale", Parent = gui })
	end
	assert(scale, "PopScale")
	scale.Scale = from or 1.15
	TweenService:Create(scale, TweenInfo.new(0.3, Enum.EasingStyle.Back), { Scale = 1 }):Play()
end

return UIKit
