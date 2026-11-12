--!strict
-- Data-driven shop window: every upgrade, pickaxe and zone in the shared config gets an entry
-- automatically. Opened from the HUD button or the Upgrade Station's ProximityPrompt.

local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Format = require(Shared.Format)
local Formulas = require(Shared.Formulas)
local Items = require(Shared.Config.Items)
local Progression = require(Shared.Config.Progression)
local Signal = require(Shared.Signal)
local Types = require(Shared.Types)
local Upgrades = require(Shared.Config.Upgrades)
local Zones = require(Shared.Config.Zones)

local DataController = require(script.Parent.DataController)
local HudController = require(script.Parent.HudController)
local UIKit = require(script.Parent.Parent.UI.UIKit)
local UIRegistry = require(script.Parent.Parent.UI.UIRegistry)

local Remotes = ReplicatedStorage.Remotes
local Colors = UIKit.Colors

type PlayerData = Types.PlayerData

local TABS = { "Upgrades", "Pickaxes", "Zones", "Rebirth" }

local ShopController = {
	Opened = Signal.new(),
	Closed = Signal.new(),
}

local window: Frame
local body: Frame
local pages: { [string]: ScrollingFrame } = {}
local tabButtons: { [string]: TextButton } = {}
local refreshers: { (PlayerData) -> () } = {}
local isOpen = false
local busy = false

local function purchase(kind: string, id: string?)
	if busy then
		return
	end
	busy = true
	task.spawn(function()
		local ok, success, message = pcall(function()
			return Remotes.Purchase:InvokeServer(kind, id)
		end)
		busy = false
		if not ok then
			HudController.Toast("Purchase failed, try again", Colors.Red)
		elseif type(message) == "string" then
			HudController.Toast(message, if success then Colors.Green else Colors.Red)
		end
	end)
end

local function priceButton(button: TextButton, price: number, affordable: boolean)
	UIKit.SetButton(button, "💎 " .. Format.Abbreviate(price), if affordable then Colors.Green else Colors.Grey)
end

-- One row: [icon] title / subtitle ............ [button]
local function makeEntry(
	page: ScrollingFrame,
	order: number,
	icon: string,
	iconColor: Color3
): (TextLabel, TextLabel, TextButton)
	local row = UIKit.Create("Frame", {
		Size = UDim2.new(1, -10, 0, 78),
		BackgroundColor3 = Colors.Card,
		BorderSizePixel = 0,
		LayoutOrder = order,
		Parent = page,
	}, { UIKit.Corner(12), UIKit.Stroke(Color3.new(1, 1, 1), 1, 0.85) })

	local iconFrame = UIKit.Create("Frame", {
		Size = UDim2.fromOffset(58, 58),
		Position = UDim2.fromOffset(10, 10),
		BackgroundColor3 = iconColor,
		BorderSizePixel = 0,
		Parent = row,
	}, { UIKit.Corner(12), UIKit.Gradient(Color3.new(1, 1, 1), Color3.fromRGB(150, 150, 150)) })
	UIKit.Label({
		Text = icon,
		Size = UDim2.fromScale(0.8, 0.8),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = iconFrame,
	})

	local title = UIKit.Label({
		Size = UDim2.new(1, -250, 0, 30),
		Position = UDim2.fromOffset(80, 10),
		Text = "",
		Parent = row,
	})
	local subtitle = UIKit.Label({
		Size = UDim2.new(1, -250, 0, 24),
		Position = UDim2.fromOffset(80, 42),
		Text = "",
		Font = UIKit.Fonts.Body,
		TextColor3 = Colors.Muted,
		Parent = row,
	})
	local button = UIKit.Button({
		Size = UDim2.fromOffset(150, 50),
		Position = UDim2.new(1, -12, 0.5, 0),
		AnchorPoint = Vector2.new(1, 0.5),
		Parent = row,
	}, "", Colors.Grey)
	return title, subtitle, button
end

local function makePage(name: string): ScrollingFrame
	local page = UIKit.Create("ScrollingFrame", {
		Name = name,
		Size = UDim2.new(1, -24, 1, -128),
		Position = UDim2.fromOffset(12, 116),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = Colors.Muted,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		Visible = false,
		Parent = body,
	})
	UIKit.Create("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = page })
	UIKit.Create("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingLeft = UDim.new(0, 4), Parent = page })
	pages[name] = page
	return page
end

local function buildUpgrades()
	local page = makePage("Upgrades")

	local autoButton =
		UIKit.Button({ Size = UDim2.new(1, -10, 0, 44), LayoutOrder = 0, Parent = page }, "", Colors.Grey)
	autoButton.Activated:Connect(function()
		local data = DataController.Get()
		if data then
			Remotes.SetSetting:FireServer("AutoUpgrade", not data.Settings.AutoUpgrade)
		end
	end)
	table.insert(refreshers, function(data)
		local on = data.Settings.AutoUpgrade
		UIKit.SetButton(
			autoButton,
			if on then "🤖 AUTO-UPGRADE: ON" else "🤖 AUTO-UPGRADE: OFF",
			if on then Colors.Blue else Colors.Grey
		)
	end)

	for _, def in Upgrades.List do
		local title, subtitle, button = makeEntry(page, def.Order, def.Icon, Colors.Accent)
		UIRegistry.Register("Upgrade:" .. def.Id, button)
		button.Activated:Connect(function()
			purchase("Upgrade", def.Id)
		end)
		table.insert(refreshers, function(data)
			local level = Formulas.UpgradeLevel(data, def.Id)
			title.Text = `{def.Name}  <font color="#C8BEE6">Lv. {level}/{def.MaxLevel}</font>`
			title.RichText = true
			local current = if def.Id == "GemMultiplier"
				then Format.Multiplier(Formulas.Multiplier(data))
				elseif def.Id == "SwingSpeed" then string.format("%.2fs", Formulas.Cooldown(data))
				else Format.Percent(Formulas.CritChance(data))
			subtitle.Text = `{def.Description}  (now {current})`
			if level >= def.MaxLevel then
				UIKit.SetButton(button, "MAXED", Colors.Gold)
			else
				local cost = Formulas.UpgradeCost(def.Id, level)
				priceButton(button, cost, data.Gems >= cost)
			end
		end)
	end
end

local function buildPickaxes()
	local page = makePage("Pickaxes")
	for _, def in Items.List do
		local title, subtitle, button = makeEntry(page, def.Order, "⛏", def.Color)
		title.Text = def.Name
		button.Activated:Connect(function()
			local data = DataController.Get()
			if not data then
				return
			end
			if data.OwnedItems[def.Id] then
				Remotes.Equip:FireServer(def.Id)
			else
				purchase("Item", def.Id)
			end
		end)
		table.insert(refreshers, function(data)
			local rarityColor = Items.Rarities[def.Rarity] or Colors.Muted
			subtitle.RichText = true
			subtitle.Text =
				`<font color="#{rarityColor:ToHex()}">{def.Rarity}</font>  •  Power {def.Power}  •  +{def.WalkSpeedBonus} Speed`
			if data.EquippedItem == def.Id then
				UIKit.SetButton(button, "EQUIPPED", Colors.Grey)
			elseif data.OwnedItems[def.Id] then
				UIKit.SetButton(button, "EQUIP", Colors.Blue)
			else
				priceButton(button, def.Price, data.Gems >= def.Price)
			end
		end)
	end
end

local function buildZones()
	local page = makePage("Zones")
	for _, def in Zones.List do
		local title, subtitle, button = makeEntry(page, def.Order, "🗺", def.CrystalColor)
		title.Text = def.Name
		subtitle.Text = `Crystals worth {def.NodeValue}x  •  {def.XPPerHit} XP per hit`
		button.Activated:Connect(function()
			purchase("Zone", def.Id)
		end)
		table.insert(refreshers, function(data)
			local previous = Zones.List[def.Order - 1]
			if data.UnlockedZones[def.Id] then
				UIKit.SetButton(button, "UNLOCKED", Colors.Grey)
			elseif previous and not data.UnlockedZones[previous.Id] then
				UIKit.SetButton(button, "🔒 LOCKED", Colors.Grey)
			else
				priceButton(button, def.Price, data.Gems >= def.Price)
			end
		end)
	end
end

local function buildRebirth()
	local page = makePage("Rebirth")
	local panel = UIKit.Create("Frame", {
		Size = UDim2.new(1, -10, 0, 270),
		BackgroundColor3 = Colors.Card,
		BorderSizePixel = 0,
		Parent = page,
	}, { UIKit.Corner(14), UIKit.Padding(16) })

	local heading = UIKit.Label({ Size = UDim2.new(1, 0, 0, 40), TextColor3 = Colors.Pink, Text = "", Parent = panel })
	UIKit.Label({
		Size = UDim2.new(1, 0, 0, 48),
		Position = UDim2.fromOffset(0, 46),
		Font = UIKit.Fonts.Body,
		TextColor3 = Colors.Muted,
		TextWrapped = true,
		Text = "Resets your Gems and upgrades. Keeps pickaxes, zones and level.",
		Parent = panel,
	})
	local bonus =
		UIKit.Label({ Size = UDim2.new(1, 0, 0, 32), Position = UDim2.fromOffset(0, 100), Text = "", Parent = panel })
	local bar = UIKit.Create("Frame", {
		Size = UDim2.new(1, 0, 0, 18),
		Position = UDim2.fromOffset(0, 144),
		BackgroundColor3 = Colors.Outline,
		BorderSizePixel = 0,
		Parent = panel,
	}, { UIKit.Corner(9) })
	local fill = UIKit.Create("Frame", {
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		Parent = bar,
	}, { UIKit.Corner(9), UIKit.Gradient(Colors.Pink, Colors.Accent) })
	local button = UIKit.Button({
		Size = UDim2.new(1, 0, 0, 60),
		Position = UDim2.fromOffset(0, 176),
		Parent = panel,
	}, "", Colors.Pink)
	button.Activated:Connect(function()
		purchase("Rebirth", nil)
	end)

	table.insert(refreshers, function(data)
		local cost = Formulas.RebirthCost(data.Rebirths)
		heading.Text = `Rebirth #{data.Rebirths + 1}`
		local now = 1 + data.Rebirths * Progression.RebirthBonus
		local nextBonus = now + Progression.RebirthBonus
		bonus.Text = `Rebirth Gem bonus: {Format.Multiplier(now)} → {Format.Multiplier(nextBonus)}`
		fill.Size = UDim2.fromScale(math.clamp(data.Gems / cost, 0, 1), 1)
		UIKit.SetButton(
			button,
			`🔁 REBIRTH  (💎 {Format.Abbreviate(cost)})`,
			if data.Gems >= cost then Colors.Pink else Colors.Grey
		)
	end)
end

local function selectTab(name: string)
	for tab, page in pages do
		page.Visible = tab == name
	end
	for tab, button in tabButtons do
		UIKit.SetButton(button, tab, if tab == name then Colors.Accent else Colors.Card)
	end
end

local function build()
	local gui = UIKit.ScreenGui("Shop", 10)

	window = UIKit.Create("Frame", {
		Name = "Window",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.52),
		Size = UDim2.fromOffset(680, 480),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = gui,
	})
	UIKit.AutoScale(window)

	body = UIKit.Panel({ Name = "Body", Size = UDim2.fromScale(1, 1), Parent = window })

	UIKit.Label({
		Text = "SHOP",
		Size = UDim2.fromOffset(300, 48),
		Position = UDim2.fromOffset(20, 10),
		TextColor3 = Colors.Gold,
		Parent = body,
	})
	local close = UIKit.Button({
		Size = UDim2.fromOffset(48, 48),
		Position = UDim2.new(1, -12, 0, 10),
		AnchorPoint = Vector2.new(1, 0),
		Parent = body,
	}, "✕", Colors.Red)
	close.Activated:Connect(function()
		ShopController.Close()
	end)

	local tabRow = UIKit.Create("Frame", {
		Size = UDim2.new(1, -24, 0, 44),
		Position = UDim2.fromOffset(12, 64),
		BackgroundTransparency = 1,
		Parent = body,
	})
	UIKit.Create("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = tabRow,
	})
	for index, name in TABS do
		local button = UIKit.Button({
			Size = UDim2.new(0.25, -6, 1, 0),
			LayoutOrder = index,
			Parent = tabRow,
		}, name, Colors.Card)
		button.Activated:Connect(function()
			selectTab(name)
		end)
		tabButtons[name] = button
	end

	buildUpgrades()
	buildPickaxes()
	buildZones()
	buildRebirth()
	selectTab("Upgrades")
end

function ShopController.IsOpen(): boolean
	return isOpen
end

function ShopController.Open(tab: string?)
	if tab then
		selectTab(tab)
	end
	if isOpen then
		return
	end
	isOpen = true
	window.Visible = true
	UIKit.Pop(body, 0.85)
	ShopController.Opened:Fire()
end

function ShopController.Close()
	if not isOpen then
		return
	end
	isOpen = false
	window.Visible = false
	ShopController.Closed:Fire()
end

function ShopController.Start()
	build()
	DataController.Observe(function(data)
		for _, refresh in refreshers do
			refresh(data)
		end
	end)

	HudController.ShopPressed:Connect(function()
		if isOpen then
			ShopController.Close()
		else
			ShopController.Open("Upgrades")
		end
	end)
	HudController.RebirthPressed:Connect(function()
		ShopController.Open("Rebirth")
	end)
	ProximityPromptService.PromptTriggered:Connect(function(prompt)
		if prompt:GetAttribute("OpensShop") then
			ShopController.Open("Upgrades")
		end
	end)
end

return ShopController
