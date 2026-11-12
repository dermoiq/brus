--!strict
-- Always-on HUD: gems (animated count-up), multiplier + boost timer, level/XP bar, rebirth rank,
-- Shop/Rebirth/Store buttons, toasts, zone banners and floating "+gems" popups.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Format = require(Shared.Format)
local Formulas = require(Shared.Formulas)
local Signal = require(Shared.Signal)
local Types = require(Shared.Types)

local DataController = require(script.Parent.DataController)
local UIKit = require(script.Parent.Parent.UI.UIKit)
local UIRegistry = require(script.Parent.Parent.UI.UIRegistry)

local Remotes = ReplicatedStorage.Remotes
local Colors = UIKit.Colors
local player = Players.LocalPlayer

local HudController = {
	ShopPressed = Signal.new(),
	RebirthPressed = Signal.new(),
	StorePressed = Signal.new(),
}

local toastHolder: Frame
local banner: TextLabel
local gemsLabel: TextLabel
local multiplierLabel: TextLabel
local levelLabel: TextLabel
local xpFill: Frame
local rebirthLabel: TextLabel

local gemCounter = Instance.new("NumberValue")
local lastGems: number? = nil
local toastCount = 0

function HudController.Toast(text: string, color: Color3?)
	toastCount += 1
	local toast = UIKit.Panel({
		Size = UDim2.new(1, 0, 0, 44),
		LayoutOrder = toastCount,
		Parent = toastHolder,
	})
	local label = UIKit.Label({
		Size = UDim2.new(1, -24, 1, -12),
		Position = UDim2.fromOffset(12, 6),
		Text = text,
		TextColor3 = color or Colors.Text,
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = toast,
	})
	UIKit.Pop(toast, 0.6)
	task.delay(2.6, function()
		local fade = TweenInfo.new(0.35)
		TweenService:Create(toast, fade, { BackgroundTransparency = 1 }):Play()
		TweenService:Create(label, fade, { TextTransparency = 1 }):Play()
		for _, child in toast:GetDescendants() do
			if child:IsA("UIStroke") then
				TweenService:Create(child, fade, { Transparency = 1 }):Play()
			end
		end
		task.wait(0.4)
		toast:Destroy()
	end)
end

function HudController.Banner(title: string)
	banner.Text = title
	banner.TextTransparency = 0
	local stroke = banner:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Transparency = 0
	end
	UIKit.Pop(banner, 1.4)
	task.delay(2, function()
		if banner.Text ~= title then
			return
		end
		local fade = TweenInfo.new(0.6)
		TweenService:Create(banner, fade, { TextTransparency = 1 }):Play()
		if stroke then
			TweenService:Create(stroke, fade, { Transparency = 1 }):Play()
		end
	end)
end

-- Floating world-space text, e.g. "+120 💎" above a crystal.
function HudController.Popup(position: Vector3, text: string, color: Color3, big: boolean?)
	local attachment = Instance.new("Attachment")
	attachment.Parent = Workspace.Terrain
	attachment.Position = position + Vector3.new(math.random() * 2 - 1, 2.5, math.random() * 2 - 1)

	local width = if big then 220 else 150
	local billboard = UIKit.Create("BillboardGui", {
		Size = UDim2.fromOffset(width, width / 3.5),
		AlwaysOnTop = true,
		LightInfluence = 0,
		MaxDistance = 150,
		Parent = attachment,
	})
	local label = UIKit.Label({
		Size = UDim2.fromScale(1, 1),
		Text = text,
		TextColor3 = color,
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = billboard,
	})
	UIKit.Pop(label, if big then 1.8 else 1.3)

	local info = TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(billboard, info, { StudsOffset = Vector3.new(0, 3, 0) }):Play()
	TweenService:Create(label, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 0.45), {
		TextTransparency = 1,
	}):Play()
	local stroke = label:FindFirstChildOfClass("UIStroke")
	if stroke then
		TweenService
			:Create(stroke, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 0.45), {
				Transparency = 1,
			})
			:Play()
	end
	task.delay(1, function()
		attachment:Destroy()
	end)
end

local function build()
	local gui = UIKit.ScreenGui("HUD", 5)

	local column = UIKit.Create("Frame", {
		Name = "LeftColumn",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 16, 0.5, 0),
		Size = UDim2.fromOffset(260, 318),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	UIKit.AutoScale(column)
	UIKit.Create("UIListLayout", {
		Padding = UDim.new(0, 10),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = column,
	})

	local stats = UIKit.Panel({ Name = "Stats", Size = UDim2.fromOffset(260, 176), LayoutOrder = 1, Parent = column })
	UIKit.Padding(12).Parent = stats

	UIKit.Label({ Text = "💎", Size = UDim2.fromOffset(46, 46), Parent = stats })
	gemsLabel = UIKit.Label({
		Text = "0",
		Size = UDim2.new(1, -54, 0, 46),
		Position = UDim2.fromOffset(54, 0),
		TextColor3 = Colors.Gold,
		Parent = stats,
	})
	multiplierLabel = UIKit.Label({
		Text = "x1 Gems",
		Size = UDim2.new(1, 0, 0, 24),
		Position = UDim2.fromOffset(0, 52),
		TextColor3 = Colors.Green,
		Font = UIKit.Fonts.Body,
		Parent = stats,
	})
	levelLabel = UIKit.Label({
		Text = "Level 1",
		Size = UDim2.new(1, 0, 0, 24),
		Position = UDim2.fromOffset(0, 82),
		Parent = stats,
	})
	local xpBar = UIKit.Create("Frame", {
		Size = UDim2.new(1, 0, 0, 14),
		Position = UDim2.fromOffset(0, 110),
		BackgroundColor3 = Colors.Outline,
		BorderSizePixel = 0,
		Parent = stats,
	}, { UIKit.Corner(7) })
	xpFill = UIKit.Create("Frame", {
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		Parent = xpBar,
	}, { UIKit.Corner(7), UIKit.Gradient(Colors.Blue, Colors.Accent) })
	rebirthLabel = UIKit.Label({
		Text = "Rebirths: 0",
		Size = UDim2.new(1, 0, 0, 22),
		Position = UDim2.fromOffset(0, 130),
		TextColor3 = Colors.Pink,
		Font = UIKit.Fonts.Body,
		RichText = true,
		Parent = stats,
	})

	local buttons = UIKit.Create("Frame", {
		Size = UDim2.fromOffset(260, 60),
		BackgroundTransparency = 1,
		LayoutOrder = 2,
		Parent = column,
	})
	local shopButton = UIKit.Button(
		{ Name = "ShopButton", Size = UDim2.new(0.5, -5, 1, 0), Parent = buttons },
		"🛒 SHOP",
		Colors.Accent
	)
	local rebirthButton = UIKit.Button({
		Name = "RebirthButton",
		Size = UDim2.new(0.5, -5, 1, 0),
		Position = UDim2.new(0.5, 5, 0, 0),
		Parent = buttons,
	}, "🔁 REBIRTH", Colors.Pink)
	shopButton.Activated:Connect(function()
		HudController.ShopPressed:Fire()
	end)
	rebirthButton.Activated:Connect(function()
		HudController.RebirthPressed:Fire()
	end)
	UIRegistry.Register("ShopButton", shopButton)

	local storeButton = UIKit.Button({
		Name = "StoreButton",
		Size = UDim2.fromOffset(260, 52),
		LayoutOrder = 3,
		Parent = column,
	}, "🛍 ROBUX STORE", Color3.fromRGB(0, 176, 111))
	storeButton.Activated:Connect(function()
		HudController.StorePressed:Fire()
	end)
	UIRegistry.Register("StoreButton", storeButton)

	toastHolder = UIKit.Create("Frame", {
		Name = "Toasts",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -100),
		Size = UDim2.fromOffset(440, 220),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	UIKit.AutoScale(toastHolder)
	UIKit.Create("UIListLayout", {
		Padding = UDim.new(0, 6),
		VerticalAlignment = Enum.VerticalAlignment.Bottom,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = toastHolder,
	})

	banner = UIKit.Label({
		Name = "ZoneBanner",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.24),
		Size = UDim2.fromOffset(640, 72),
		Text = "",
		TextTransparency = 1,
		TextColor3 = Colors.Gold,
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = gui,
	})
	local bannerStroke = banner:FindFirstChildOfClass("UIStroke")
	if bannerStroke then
		bannerStroke.Transparency = 1
		bannerStroke.Thickness = 3
	end
end

local function renderMultiplier(data: Types.PlayerData)
	local now = Workspace:GetServerTimeNow()
	local text = Format.Multiplier(Formulas.Multiplier(data, Formulas.Perks(player), now)) .. " Gems"
	local remaining = math.floor(data.Boosts.GemsUntil - now)
	if remaining > 0 then
		text ..= string.format("  ⚡ %d:%02d", remaining // 60, remaining % 60)
	end
	multiplierLabel.Text = text
end

local function render(data: Types.PlayerData)
	if lastGems and data.Gems > lastGems then
		UIKit.Pop(gemsLabel, 1.12)
	end
	lastGems = data.Gems
	TweenService:Create(gemCounter, TweenInfo.new(0.35, Enum.EasingStyle.Quad), { Value = data.Gems }):Play()

	renderMultiplier(data)
	levelLabel.Text = `Level {data.Level}`
	local progress = math.clamp(data.XP / Formulas.XPToNext(data.Level), 0, 1)
	TweenService:Create(xpFill, TweenInfo.new(0.25), { Size = UDim2.fromScale(progress, 1) }):Play()
	local rank = Formulas.RebirthRank(data.Rebirths)
	rebirthLabel.Text = `Rebirths: {data.Rebirths}  •  <font color="#{rank.Color:ToHex()}">{rank.Name}</font>`
end

function HudController.Start()
	build()

	gemCounter.Changed:Connect(function(value: number)
		gemsLabel.Text = Format.Abbreviate(value)
	end)
	DataController.Observe(render)
	-- Pass ownership (2x Gems, VIP) changes the multiplier without a data change.
	player.AttributeChanged:Connect(function()
		local data = DataController.Get()
		if data then
			renderMultiplier(data)
		end
	end)
	task.spawn(function()
		while true do
			task.wait(1)
			local data = DataController.Get()
			if data and data.Boosts.GemsUntil > Workspace:GetServerTimeNow() - 2 then
				renderMultiplier(data)
			end
		end
	end)

	Remotes.Notify.OnClientEvent:Connect(function(kind: string, payload: any)
		if kind == "LevelUp" then
			HudController.Toast(`⭐ Level {payload}! +2% Gems`, Colors.Gold)
		elseif kind == "AutoUpgrade" then
			HudController.Toast(`🤖 {payload}`, Colors.Blue)
		elseif kind == "AutoRebirth" or kind == "Unlock" then
			HudController.Toast(tostring(payload), Colors.Pink)
		elseif kind == "RankUp" then
			HudController.Banner(`RANK UP: {payload}!`)
			HudController.Toast(`🏆 New rank: {payload}`, Colors.Gold)
		elseif kind == "Purchase" then
			HudController.Toast(tostring(payload), Colors.Gold)
		elseif kind == "TutorialComplete" then
			HudController.Toast(`🎉 Tutorial complete! +{payload} Gems`, Colors.Green)
		elseif kind == "Toast" and type(payload) == "string" then
			HudController.Toast(payload)
		end
	end)
end

return HudController
