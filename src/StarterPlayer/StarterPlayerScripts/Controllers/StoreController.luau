--!strict
-- Robux Store: game passes (owned state from server-set attributes) and Developer Products, with live
-- prices from MarketplaceService. Items whose Id is still 0 in Config/Monetization show as unavailable.
-- Also adds the [VIP] chat tag.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Format = require(Shared.Format)
local Formulas = require(Shared.Formulas)
local Monetization = require(Shared.Config.Monetization)
local Signal = require(Shared.Signal)
local Types = require(Shared.Types)

local DataController = require(script.Parent.DataController)
local HudController = require(script.Parent.HudController)
local UIKit = require(script.Parent.Parent.UI.UIKit)

local Colors = UIKit.Colors
local player = Players.LocalPlayer

local ROBUX_GREEN = Color3.fromRGB(0, 176, 111)

local StoreController = {
	Opened = Signal.new(),
}

local window: Frame
local body: Frame
local isOpen = false
local pricesLoaded = false
local refreshers: { (Types.PlayerData?) -> () } = {}
local priceLabels: { [number]: { Label: TextLabel, InfoType: Enum.InfoType } } = {}

local function ownsPass(key: string): boolean
	return player:GetAttribute(Monetization.AttributePrefix .. key) == true
end

local function loadPrices()
	if pricesLoaded then
		return
	end
	pricesLoaded = true
	for id, entry in priceLabels do
		task.spawn(function()
			local ok, info = pcall(function()
				return MarketplaceService:GetProductInfoAsync(id, entry.InfoType)
			end)
			if ok and type(info) == "table" and type(info.PriceInRobux) == "number" then
				entry.Label.Text = `R$ {info.PriceInRobux}`
			else
				entry.Label.Text = "R$ ?"
			end
		end)
	end
end

local function sectionTitle(text: string, position: UDim2)
	UIKit.Label({
		Text = text,
		Size = UDim2.fromOffset(300, 28),
		Position = position,
		TextColor3 = Colors.Gold,
		Parent = body,
	})
end

local function buildPassCard(parent: Instance, pass: Monetization.PassDef)
	local card = UIKit.Create("Frame", {
		BackgroundColor3 = Colors.Card,
		BorderSizePixel = 0,
		LayoutOrder = pass.Order,
		Parent = parent,
	}, { UIKit.Corner(14), UIKit.Stroke(Colors.Gold, 2, 0.55), UIKit.Padding(10) })

	UIKit.Label({
		Text = pass.Icon,
		Size = UDim2.fromOffset(46, 46),
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = card,
	})
	UIKit.Label({
		Text = pass.Name,
		Size = UDim2.new(1, -54, 0, 26),
		Position = UDim2.fromOffset(54, 0),
		Parent = card,
	})
	local price = UIKit.Label({
		Text = if pass.Id == 0 then "" else "R$ …",
		Size = UDim2.new(1, -54, 0, 18),
		Position = UDim2.fromOffset(54, 26),
		TextColor3 = ROBUX_GREEN,
		Font = UIKit.Fonts.Body,
		Parent = card,
	})
	UIKit.Label({
		Text = pass.Description,
		Size = UDim2.new(1, 0, 0, 40),
		Position = UDim2.fromOffset(0, 52),
		TextWrapped = true,
		TextColor3 = Colors.Muted,
		Font = UIKit.Fonts.Body,
		Parent = card,
	})
	local button = UIKit.Button({
		Size = UDim2.new(1, 0, 0, 38),
		Position = UDim2.new(0, 0, 1, -38),
		Parent = card,
	}, "", Colors.Grey)

	if pass.Id ~= 0 then
		priceLabels[pass.Id] = { Label = price, InfoType = Enum.InfoType.GamePass }
	end
	button.Activated:Connect(function()
		if pass.Id == 0 then
			HudController.Toast("Set this pass ID in Config/Monetization", Colors.Red)
		elseif not ownsPass(pass.Key) then
			MarketplaceService:PromptGamePassPurchase(player, pass.Id)
		end
	end)
	table.insert(refreshers, function()
		if pass.Id == 0 then
			UIKit.SetButton(button, "COMING SOON", Colors.Grey)
		elseif ownsPass(pass.Key) then
			UIKit.SetButton(button, "OWNED ✓", Colors.Grey)
		else
			UIKit.SetButton(button, "BUY", ROBUX_GREEN)
		end
	end)
end

local function buildProductRow(parent: Instance, product: Monetization.ProductDef)
	local row = UIKit.Create("Frame", {
		Size = UDim2.new(1, -8, 0, 74),
		BackgroundColor3 = Colors.Card,
		BorderSizePixel = 0,
		LayoutOrder = product.Order,
		Parent = parent,
	}, { UIKit.Corner(12), UIKit.Stroke(Color3.new(1, 1, 1), 1, 0.85) })

	UIKit.Label({
		Text = product.Icon,
		Size = UDim2.fromOffset(44, 44),
		Position = UDim2.fromOffset(10, 15),
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = row,
	})
	UIKit.Label({
		Text = product.Name,
		Size = UDim2.new(1, -190, 0, 26),
		Position = UDim2.fromOffset(62, 8),
		Parent = row,
	})
	local detail = UIKit.Label({
		Text = product.Description,
		Size = UDim2.new(1, -190, 0, 32),
		Position = UDim2.fromOffset(62, 36),
		TextWrapped = true,
		TextColor3 = Colors.Muted,
		Font = UIKit.Fonts.Body,
		Parent = row,
	})
	local price = UIKit.Label({
		Text = if product.Id == 0 then "" else "R$ …",
		Size = UDim2.fromOffset(110, 20),
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 6),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = ROBUX_GREEN,
		Font = UIKit.Fonts.Body,
		Parent = row,
	})
	local button = UIKit.Button({
		Size = UDim2.fromOffset(110, 38),
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -12, 1, -8),
		Parent = row,
	}, "", Colors.Grey)

	if product.Id ~= 0 then
		priceLabels[product.Id] = { Label = price, InfoType = Enum.InfoType.Product }
	end
	button.Activated:Connect(function()
		if product.Id == 0 then
			HudController.Toast("Set this product ID in Config/Monetization", Colors.Red)
		else
			MarketplaceService:PromptProductPurchase(player, product.Id)
		end
	end)
	table.insert(refreshers, function(data)
		UIKit.SetButton(
			button,
			if product.Id == 0 then "SOON" else "BUY",
			if product.Id == 0 then Colors.Grey else ROBUX_GREEN
		)
		if not data then
			return
		end
		if product.Kind == "Gems" then
			local amount =
				Formulas.GemPackAmount(data, product.Minutes or 10, product.MinGems or 0, Formulas.Perks(player))
			detail.Text = `≈ 💎 {Format.Abbreviate(amount)}  ({product.Description})`
		elseif product.Kind == "Boost" then
			local remaining = data.Boosts.GemsUntil - Workspace:GetServerTimeNow()
			detail.Text = if remaining > 0
				then `Active: {math.floor(remaining / 60)}m left. Buying adds more time.`
				else product.Description
		end
	end)
end

local function build()
	local gui = UIKit.ScreenGui("Store", 11)

	window = UIKit.Create("Frame", {
		Name = "Window",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.52),
		Size = UDim2.fromOffset(760, 500),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = gui,
	})
	UIKit.AutoScale(window)
	body = UIKit.Panel({ Name = "Body", Size = UDim2.fromScale(1, 1), Parent = window })
	UIKit.Stroke(Colors.Gold, 3, 0.3).Parent = body

	UIKit.Label({
		Text = "🛍 ROBUX STORE",
		Size = UDim2.fromOffset(400, 46),
		Position = UDim2.fromOffset(20, 10),
		TextColor3 = Colors.Gold,
		Parent = body,
	})
	local close = UIKit.Button({
		Size = UDim2.fromOffset(46, 46),
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 10),
		Parent = body,
	}, "✕", Colors.Red)
	close.Activated:Connect(function()
		StoreController.Close()
	end)

	sectionTitle("GAME PASSES", UDim2.fromOffset(20, 62))
	local passes = UIKit.Create("Frame", {
		Size = UDim2.new(0.55, -26, 1, -110),
		Position = UDim2.fromOffset(16, 94),
		BackgroundTransparency = 1,
		Parent = body,
	})
	UIKit.Create("UIGridLayout", {
		CellSize = UDim2.new(0.5, -5, 0.5, -5),
		CellPadding = UDim2.fromOffset(10, 10),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = passes,
	})
	for _, pass in Monetization.Gamepasses do
		buildPassCard(passes, pass)
	end

	sectionTitle("BOOSTS & GEMS", UDim2.new(0.55, 0, 0, 62))
	local products = UIKit.Create("ScrollingFrame", {
		Size = UDim2.new(0.45, -16, 1, -110),
		Position = UDim2.new(0.55, 0, 0, 94),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		Parent = body,
	})
	UIKit.Create(
		"UIListLayout",
		{ Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = products }
	)
	for _, product in Monetization.Products do
		buildProductRow(products, product)
	end
end

local function refresh()
	local data = DataController.Get()
	for _, refreshEntry in refreshers do
		refreshEntry(data)
	end
end

function StoreController.IsOpen(): boolean
	return isOpen
end

function StoreController.Open()
	if isOpen then
		return
	end
	isOpen = true
	window.Visible = true
	UIKit.Pop(body, 0.85)
	loadPrices()
	refresh()
	StoreController.Opened:Fire()
end

function StoreController.Close()
	isOpen = false
	window.Visible = false
end

local function setupVipChatTag()
	local prefix = Monetization.AttributePrefix .. "VIP"
	TextChatService.OnIncomingMessage = function(message: TextChatMessage)
		local properties = Instance.new("TextChatMessageProperties")
		local source = message.TextSource
		local sender = source and Players:GetPlayerByUserId(source.UserId)
		if sender and sender:GetAttribute(prefix) == true then
			properties.PrefixText = `<font color="#FFD75A">[VIP]</font> {message.PrefixText}`
		end
		return properties
	end
end

function StoreController.Start()
	build()
	refresh()
	DataController.Changed:Connect(refresh)
	player.AttributeChanged:Connect(refresh)

	HudController.StorePressed:Connect(function()
		if isOpen then
			StoreController.Close()
		else
			StoreController.Open()
		end
	end)
	ProximityPromptService.PromptTriggered:Connect(function(prompt)
		if prompt:GetAttribute("OpensStore") then
			StoreController.Open()
		end
	end)

	task.spawn(function()
		while true do
			task.wait(1)
			if isOpen then
				refresh()
			end
		end
	end)

	setupVipChatTag()
end

return StoreController
