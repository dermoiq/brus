--!strict
-- Non-intrusive onboarding: a compact card at the top of the screen, a pulsing highlight + arrow on the
-- UI element to press, and a glowing beam/marker to the nearest crystal. "Skip Tutorial" is visible the
-- whole time. Which step is shown comes from saved data, so it resumes correctly after a rejoin.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Tutorial = require(Shared.Config.Tutorial)
local Types = require(Shared.Types)
local ZoneUtil = require(Shared.ZoneUtil)

local DataController = require(script.Parent.DataController)
local ShopController = require(script.Parent.ShopController)
local UIKit = require(script.Parent.Parent.UI.UIKit)
local UIRegistry = require(script.Parent.Parent.UI.UIRegistry)

local Remotes = ReplicatedStorage.Remotes
local Colors = UIKit.Colors
local player = Players.LocalPlayer

local NODE_SEARCH_INTERVAL = 0.5

local TutorialController = {}

local gui: ScreenGui
local card: Frame
local stepLabel: TextLabel
local titleLabel: TextLabel
local bodyLabel: TextLabel
local progressBar: Frame
local progressFill: Frame
local progressText: TextLabel
local focus: Frame
local arrow: TextLabel
local skipButton: TextButton

local skipped = false
local shownStep = 0
local worldGuide: { Beam: Beam, From: Attachment, To: Attachment, Marker: BillboardGui }? = nil
local guideTarget: Instance? = nil
local lastNodeSearch = 0

local function currentStep(): (Tutorial.StepDef?, Types.PlayerData?)
	local data = DataController.Get()
	if skipped or not data or data.TutorialDone then
		return nil, data
	end
	return Tutorial.Steps[data.TutorialStep], data
end

local function build()
	gui = UIKit.ScreenGui("Tutorial", 20)

	card = UIKit.Panel({
		Name = "Card",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 10),
		Size = UDim2.fromOffset(500, 112),
		Visible = false,
		Parent = gui,
	})
	UIKit.AutoScale(card)

	stepLabel = UIKit.Label({
		Size = UDim2.fromOffset(200, 20),
		Position = UDim2.fromOffset(16, 10),
		TextColor3 = Colors.Gold,
		Font = UIKit.Fonts.Body,
		Text = "",
		Parent = card,
	})
	titleLabel = UIKit.Label({
		Size = UDim2.new(1, -170, 0, 32),
		Position = UDim2.fromOffset(16, 30),
		Text = "",
		Parent = card,
	})
	bodyLabel = UIKit.Label({
		Size = UDim2.new(1, -170, 0, 22),
		Position = UDim2.fromOffset(16, 64),
		Font = UIKit.Fonts.Body,
		TextColor3 = Colors.Muted,
		Text = "",
		Parent = card,
	})

	progressBar = UIKit.Create("Frame", {
		Size = UDim2.new(1, -32, 0, 12),
		Position = UDim2.new(0, 16, 1, -18),
		BackgroundColor3 = Colors.Outline,
		BorderSizePixel = 0,
		Visible = false,
		Parent = card,
	}, { UIKit.Corner(6) })
	progressFill = UIKit.Create("Frame", {
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		Parent = progressBar,
	}, { UIKit.Corner(6), UIKit.Gradient(Colors.Gold, Colors.Green) })
	progressText = UIKit.Label({
		Size = UDim2.fromOffset(120, 20),
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, 0, 0, -2),
		TextXAlignment = Enum.TextXAlignment.Right,
		Font = UIKit.Fonts.Body,
		Text = "",
		Parent = progressBar,
	})

	skipButton = UIKit.Button({
		Name = "SkipTutorial",
		Size = UDim2.fromOffset(140, 40),
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 12),
		Parent = card,
	}, "Skip Tutorial ✕", Colors.Red)

	-- Highlight ring around the target button. Active=false so clicks pass straight through to it.
	focus = UIKit.Create("Frame", {
		Name = "Focus",
		BackgroundTransparency = 1,
		Active = false,
		Visible = false,
		Parent = gui,
	}, { UIKit.Corner(16) })
	local ring = UIKit.Stroke(Colors.Gold, 4, 0)
	ring.Parent = focus
	TweenService:Create(
		ring,
		TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ Transparency = 0.6, Thickness = 7 }
	):Play()

	arrow = UIKit.Label({
		Name = "Arrow",
		Size = UDim2.fromOffset(56, 56),
		AnchorPoint = Vector2.new(0.5, 0.5),
		TextColor3 = Colors.Gold,
		TextXAlignment = Enum.TextXAlignment.Center,
		Text = "◀",
		Visible = false,
		Parent = gui,
	})
end

local function clearWorldGuide()
	if worldGuide then
		worldGuide.Beam:Destroy()
		worldGuide.From:Destroy()
		worldGuide.To:Destroy()
		worldGuide = nil
	end
	guideTarget = nil
end

local function nearestNode(data: Types.PlayerData, origin: Vector3): Instance?
	local best, bestDistance = nil, math.huge
	for _, node in CollectionService:GetTagged(ZoneUtil.NodeTag) do
		local zoneId = ZoneUtil.GetZoneId(node)
		local position = ZoneUtil.GetPosition(node)
		if position and zoneId and data.UnlockedZones[zoneId] and node:IsDescendantOf(Workspace) then
			local distance = (position - origin).Magnitude
			if distance < bestDistance then
				best, bestDistance = node, distance
			end
		end
	end
	return best
end

local function pointWorldGuideAt(node: Instance, root: BasePart)
	if guideTarget == node and worldGuide and worldGuide.To.Parent then
		return
	end
	clearWorldGuide()
	local anchor = ZoneUtil.GetAnchorPart(node)
	if not anchor then
		return
	end
	local from = Instance.new("Attachment")
	from.Name = "TutorialFrom"
	from.Parent = root
	local to = Instance.new("Attachment")
	to.Name = "TutorialTo"
	to.Position = Vector3.new(0, 3, 0)
	to.Parent = anchor

	local beam = UIKit.Create("Beam", {
		Attachment0 = from,
		Attachment1 = to,
		Color = ColorSequence.new(Colors.Gold),
		Transparency = NumberSequence.new(0.1, 0.5),
		Width0 = 0.5,
		Width1 = 0.5,
		FaceCamera = true,
		LightEmission = 1,
		LightInfluence = 0,
		Segments = 16,
		Parent = from,
	})
	local marker = UIKit.Create("BillboardGui", {
		Size = UDim2.fromOffset(140, 90),
		StudsOffset = Vector3.new(0, 3, 0),
		AlwaysOnTop = true,
		LightInfluence = 0,
		Parent = to,
	})
	UIKit.Label({
		Size = UDim2.fromScale(1, 0.4),
		Text = "MINE ME!",
		TextColor3 = Colors.Gold,
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = marker,
	})
	UIKit.Label({
		Size = UDim2.fromScale(1, 0.6),
		Position = UDim2.fromScale(0, 0.4),
		Text = "▼",
		TextColor3 = Colors.Gold,
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = marker,
	})
	worldGuide = { Beam = beam, From = from, To = to, Marker = marker }
	guideTarget = node
end

local function resolveUiTarget(key: string): GuiObject?
	local element = UIRegistry.Get(key)
	if element and UIRegistry.IsShown(element) then
		return element
	end
	-- e.g. "Upgrade:GemMultiplier" lives inside the shop; point at the Shop button until it's open.
	local shopButton = UIRegistry.Get("ShopButton")
	if key ~= "ShopButton" and shopButton and UIRegistry.IsShown(shopButton) and not ShopController.IsOpen() then
		return shopButton
	end
	return nil
end

local function placeFocus(target: GuiObject?, now: number)
	if not target then
		focus.Visible = false
		arrow.Visible = false
		return
	end
	local position, size = target.AbsolutePosition, target.AbsoluteSize
	focus.Position = UDim2.fromOffset(position.X - 6, position.Y - 6)
	focus.Size = UDim2.fromOffset(size.X + 12, size.Y + 12)
	focus.Visible = true

	local camera = Workspace.CurrentCamera
	local viewportWidth = if camera then camera.ViewportSize.X else 1000
	local onLeft = position.X + size.X / 2 < viewportWidth / 2
	local bob = math.sin(now * 6) * 8
	local centerY = position.Y + size.Y / 2
	if onLeft then
		arrow.Text = "◀"
		arrow.Position = UDim2.fromOffset(position.X + size.X + 40 + bob, centerY)
	else
		arrow.Text = "▶"
		arrow.Position = UDim2.fromOffset(position.X - 40 - bob, centerY)
	end
	arrow.Visible = true
end

local function render(data: Types.PlayerData?)
	local step = if skipped or not data or data.TutorialDone then nil else Tutorial.Steps[data.TutorialStep]
	if not step or not data then
		card.Visible = false
		focus.Visible = false
		arrow.Visible = false
		clearWorldGuide()
		return
	end

	card.Visible = true
	if shownStep ~= data.TutorialStep then
		shownStep = data.TutorialStep
		UIKit.Pop(card, 1.08)
	end
	stepLabel.Text = `STEP {data.TutorialStep} / {#Tutorial.Steps}`
	titleLabel.Text = step.Title
	bodyLabel.Text = step.Body

	local goal = step.Goal
	progressBar.Visible = goal ~= nil
	if goal then
		local progress = math.clamp(data.TutorialProgress / goal, 0, 1)
		TweenService:Create(progressFill, TweenInfo.new(0.2), { Size = UDim2.fromScale(progress, 1) }):Play()
		progressText.Text = `{math.min(math.floor(data.TutorialProgress), goal)} / {goal}`
	end
end

local function onFrame()
	local step, data = currentStep()
	if not step or not data then
		return
	end
	local now = os.clock()

	if step.Target == "NearestNode" then
		placeFocus(nil, now)
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") and now - lastNodeSearch > NODE_SEARCH_INTERVAL then
			lastNodeSearch = now
			local node = nearestNode(data, root.Position)
			if node then
				pointWorldGuideAt(node, root)
			else
				clearWorldGuide()
			end
		end
		if worldGuide then
			worldGuide.Marker.StudsOffset = Vector3.new(0, 3 + math.sin(now * 5) * 0.5, 0)
		end
	else
		clearWorldGuide()
		placeFocus(resolveUiTarget(step.Target), now)
	end
end

function TutorialController.Start()
	build()
	DataController.Observe(render)
	render(DataController.Get())

	skipButton.Activated:Connect(function()
		skipped = true
		Remotes.TutorialAction:FireServer("Skip")
		-- Hide immediately instead of waiting for the server round-trip.
		render(DataController.Get())
	end)

	ShopController.Opened:Connect(function()
		local step = currentStep()
		if step and step.Id == "OpenShop" then
			Remotes.TutorialAction:FireServer("OpenedShop")
		end
	end)

	player.CharacterAdded:Connect(clearWorldGuide)

	RunService.RenderStepped:Connect(function()
		if card.Visible then
			onFrame()
		end
	end)
end

return TutorialController
