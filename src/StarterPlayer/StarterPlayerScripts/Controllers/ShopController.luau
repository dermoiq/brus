--!strict
-- Data-driven shop window: every upgrade, pickaxe, zone and aura in the shared config gets an entry
-- automatically. Opened from the HUD, the Upgrade Station and the Rebirth Altar.

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Auras = require(Shared.Config.Auras)
local Format = require(Shared.Format)
local Formulas = require(Shared.Formulas)
local Items = require(Shared.Config.Items)
local Rebirths = require(Shared.Config.Rebirths)
local Signal = require(Shared.Signal)
local Types = require(Shared.Types)
local Upgrades = require(Shared.Config.Upgrades)
local Zones = require(Shared.Config.Zones)

local DataController = require(script.Parent.DataController)
local HudController = require(script.Parent.HudController)
local StoreController = require(script.Parent.StoreController)
local UIKit = require(script.Parent.Parent.UI.UIKit)
local UIRegistry = require(script.Parent.Parent.UI.UIRegistry)

local Remotes = ReplicatedStorage.Remotes
local Colors = UIKit.Colors
local player = Players.LocalPlayer

type PlayerData = Types.PlayerData
type Perks = Types.Perks

local TABS = { "Upgrades", "Pickaxes", "Zones", "Rebirth", "Auras" }

local ShopController = {
	Opened = Signal.new(),
	Closed = Signal.new(),
}

local window: Frame
local body: Frame
local pages: { [string]: ScrollingFrame } = {}
local tabButtons: { [string]: TextButton } = {}
local refreshers: { (PlayerData, Perks) -> () } = {}
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

local function toggleButton(button: TextButton, label: string, on: boolean, onColor: Color3)
	UIKit.SetButton(button, `{label}: {if on then "ON" else "OFF"}`, if on then onColor else Colors.Grey)
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
		RichText = true,
		Parent = row,
	})
	local subtitle = UIKit.Label({
		Size = UDim2.new(1, -250, 0, 24),
		Position = UDim2.fromOffset(80, 42),
		Text = "",
		RichText = true,
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

local function hex(color: Color3): string
	return "#" .. color:ToHex()
end

local function requirementText(rebirthRequired: number?, gamepass: string?): string
	if gamepass then
		return "👑 " .. gamepass
	end
	return `🔒 REBIRTH {rebirthRequired or 0}`
end

local function buildUpgrades()
	local page = makePage("Upgrades")

	local toggles = UIKit.Create("Frame", {
		Size = UDim2.new(1, -10, 0, 44),
		BackgroundTransparency = 1,
		LayoutOrder = 0,
		Parent = page,
	})
	local autoUpgrade = UIKit.Button({ Size = UDim2.new(0.5, -5, 1, 0), Parent = toggles }, "", Colors.Grey)
	local autoMine = UIKit.Button({
		Size = UDim2.new(0.5, -5, 1, 0),
		Position = UDim2.new(0.5, 5, 0, 0),
		Parent = toggles,
	}, "", Colors.Grey)
	autoUpgrade.Activated:Connect(function()
		local data = DataController.Get()
		if data then
			Remotes.SetSetting:FireServer("AutoUpgrade", not data.Settings.AutoUpgrade)
		end
	end)
	autoMine.Activated:Connect(function()
		local data = DataController.Get()
		if not data then
			return
		end
		if Formulas.Perks(player).AutoMine then
			Remotes.SetSetting:FireServer("AutoMine", not data.Settings.AutoMine)
		else
			ShopController.Close()
			StoreController.Open()
		end
	end)
	table.insert(refreshers, function(data, perks)
		toggleButton(autoUpgrade, "🤖 AUTO-UPGRADE", data.Settings.AutoUpgrade, Colors.Blue)
		if perks.AutoMine then
			toggleButton(autoMine, "⛏ AUTO-MINE", data.Settings.AutoMine, Colors.Blue)
		else
			UIKit.SetButton(autoMine, "🔒 AUTO-MINE (Store)", Colors.Grey)
		end
	end)

	for _, def in Upgrades.List do
		local title, subtitle, button = makeEntry(page, def.Order, def.Icon, Colors.Accent)
		UIRegistry.Register("Upgrade:" .. def.Id, button)
		button.Activated:Connect(function()
			purchase("Upgrade", def.Id)
		end)
		table.insert(refreshers, function(data, perks)
			local level = Formulas.UpgradeLevel(data, def.Id)
			title.Text = `{def.Name}  <font color="#C8BEE6">Lv. {level}/{def.MaxLevel}</font>`
			local current = if def.Id == "GemMultiplier"
				then Format.Multiplier(Formulas.Multiplier(data, perks))
				elseif def.Id == "SwingSpeed" then string.format("%.2fs", Formulas.Cooldown(data))
				else Format.Percent(Formulas.CritChance(data, perks))
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
		local rarityColor = Items.Rarities[def.Rarity] or Colors.Muted
		title.Text = def.Name
		subtitle.Text = `<font color="{hex(rarityColor)}">{def.Rarity}</font>  •  Power {Format.Abbreviate(def.Power)}  •  +{def.WalkSpeedBonus} Speed`
		local exclusive = def.RebirthRequired ~= nil or def.Gamepass ~= nil
		button.Activated:Connect(function()
			local data = DataController.Get()
			if not data then
				return
			end
			if Formulas.OwnsItem(data, def, Formulas.Perks(player)) then
				Remotes.Equip:FireServer("Item", def.Id)
			elseif def.Gamepass then
				ShopController.Close()
				StoreController.Open()
			elseif not exclusive then
				purchase("Item", def.Id)
			end
		end)
		table.insert(refreshers, function(data, perks)
			if Formulas.EquippedItem(data, perks).Id == def.Id then
				UIKit.SetButton(button, "EQUIPPED", Colors.Grey)
			elseif Formulas.OwnsItem(data, def, perks) then
				UIKit.SetButton(button, "EQUIP", Colors.Blue)
			elseif exclusive then
				UIKit.SetButton(
					button,
					requirementText(def.RebirthRequired, def.Gamepass),
					if def.Gamepass then Colors.Gold else Colors.Grey
				)
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
		subtitle.Text = `Crystals worth {Format.Abbreviate(def.NodeValue)}x  •  {def.XPPerHit} XP per hit`
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

-- The next rebirth-exclusive pickaxe or aura, for the "next unlock" teaser.
local function nextRebirthReward(rebirths: number): (string?, number?)
	local bestName, bestNeed = nil, math.huge
	for _, def in Items.List do
		local need = def.RebirthRequired
		if need and need > rebirths and need < bestNeed then
			bestName, bestNeed = def.Name, need
		end
	end
	for _, def in Auras.List do
		local need = def.RebirthRequired
		if need and need > rebirths and need < bestNeed then
			bestName, bestNeed = def.Name, need
		end
	end
	return bestName, if bestName then bestNeed else nil
end

local function buildRebirth()
	local page = makePage("Rebirth")
	local panel = UIKit.Create("Frame", {
		Size = UDim2.new(1, -10, 0, 330),
		BackgroundColor3 = Colors.Card,
		BorderSizePixel = 0,
		Parent = page,
	}, { UIKit.Corner(14), UIKit.Padding(16) })

	local heading = UIKit.Label({ Size = UDim2.new(1, 0, 0, 38), Text = "", RichText = true, Parent = panel })
	local rankLine = UIKit.Label({
		Size = UDim2.new(1, 0, 0, 24),
		Position = UDim2.fromOffset(0, 40),
		Font = UIKit.Fonts.Body,
		Text = "",
		RichText = true,
		TextColor3 = Colors.Muted,
		Parent = panel,
	})
	UIKit.Label({
		Size = UDim2.new(1, 0, 0, 22),
		Position = UDim2.fromOffset(0, 66),
		Font = UIKit.Fonts.Body,
		TextColor3 = Colors.Muted,
		Text = "Resets Gems, upgrades and shop pickaxes. Keeps zones, level, exclusive pickaxes and auras.",
		Parent = panel,
	})
	local bonus = UIKit.Label({ Size = UDim2.new(1, 0, 0, 30), Position = UDim2.fromOffset(0, 94), Text = "", Parent = panel })
	local teaser = UIKit.Label({
		Size = UDim2.new(1, 0, 0, 22),
		Position = UDim2.fromOffset(0, 126),
		Font = UIKit.Fonts.Body,
		TextColor3 = Colors.Gold,
		Text = "",
		Parent = panel,
	})
	local bar = UIKit.Create("Frame", {
		Size = UDim2.new(1, 0, 0, 18),
		Position = UDim2.fromOffset(0, 156),
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
		Size = UDim2.new(1, 0, 0, 58),
		Position = UDim2.fromOffset(0, 186),
		Parent = panel,
	}, "", Colors.Pink)
	button.Activated:Connect(function()
		purchase("Rebirth", nil)
	end)
	local autoRebirth = UIKit.Button({
		Size = UDim2.new(1, 0, 0, 42),
		Position = UDim2.fromOffset(0, 252),
		Parent = panel,
	}, "", Colors.Grey)
	autoRebirth.Activated:Connect(function()
		local data = DataController.Get()
		if data and data.Rebirths >= Rebirths.AutoRebirthUnlock then
			Remotes.SetSetting:FireServer("AutoRebirth", not data.Settings.AutoRebirth)
		end
	end)

	table.insert(refreshers, function(data)
		local cost = Formulas.RebirthCost(data.Rebirths)
		local rank, _, nextRank = Formulas.RebirthRank(data.Rebirths)
		heading.Text = `Rebirth #{data.Rebirths + 1}   <font color="{hex(rank.Color)}">{rank.Name}</font>`
		rankLine.Text = if nextRank
			then `Next rank: <font color="{hex(nextRank.Color)}">{nextRank.Name}</font> at {nextRank.Threshold} rebirths`
			else "You've reached the highest rank. Rebirths keep multiplying forever!"
		local now = Formulas.RebirthMultiplier(data.Rebirths)
		local after = Formulas.RebirthMultiplier(data.Rebirths + 1)
		bonus.Text = `Rebirth Gem bonus: {Format.Multiplier(now)} → {Format.Multiplier(after)}`
		local rewardName, rewardAt = nextRebirthReward(data.Rebirths)
		teaser.Text = if rewardName then `🎁 Next unlock: {rewardName} at {rewardAt} rebirths` else ""
		fill.Size = UDim2.fromScale(math.clamp(data.Gems / cost, 0, 1), 1)
		UIKit.SetButton(
			button,
			`🔁 REBIRTH  (💎 {Format.Abbreviate(cost)})`,
			if data.Gems >= cost then Colors.Pink else Colors.Grey
		)
		if data.Rebirths >= Rebirths.AutoRebirthUnlock then
			toggleButton(autoRebirth, "♻ AUTO-REBIRTH", data.Settings.AutoRebirth, Colors.Pink)
		else
			UIKit.SetButton(autoRebirth, `🔒 AUTO-REBIRTH (unlocks at {Rebirths.AutoRebirthUnlock} rebirths)`, Colors.Grey)
		end
	end)
end

local function buildAuras()
	local page = makePage("Auras")
	for _, def in Auras.List do
		local title, subtitle, button = makeEntry(page, def.Order, "✨", def.Color)
		title.Text = def.Name
		subtitle.Text = def.Description
		button.Activated:Connect(function()
			local data = DataController.Get()
			if not data then
				return
			end
			if Formulas.OwnsAura(data, def, Formulas.Perks(player)) then
				Remotes.Equip:FireServer("Aura", def.Id)
			elseif def.Gamepass then
				ShopController.Close()
				StoreController.Open()
			end
		end)
		table.insert(refreshers, function(data, perks)
			if Formulas.EquippedAura(data, perks).Id == def.Id then
				UIKit.SetButton(button, "EQUIPPED", Colors.Grey)
			elseif Formulas.OwnsAura(data, def, perks) then
				UIKit.SetButton(button, "EQUIP", Colors.Blue)
			else
				UIKit.SetButton(
					button,
					requirementText(def.RebirthRequired, def.Gamepass),
					if def.Gamepass then Colors.Gold else Colors.Grey
				)
			end
		end)
	end
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
		Size = UDim2.fromOffset(720, 500),
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
			Size = UDim2.new(1 / #TABS, -7, 1, 0),
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
	buildAuras()
	selectTab("Upgrades")
end

local function refresh()
	local data = DataController.Get()
	if not data then
		return
	end
	local perks = Formulas.Perks(player)
	for _, refreshEntry in refreshers do
		refreshEntry(data, perks)
	end
end

function ShopController.IsOpen(): boolean
	return isOpen
end

function ShopController.Open(tab: string?)
	if tab then
		selectTab(tab)
	end
	if StoreController.IsOpen() then
		StoreController.Close()
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
	DataController.Observe(function()
		refresh()
	end)
	player.AttributeChanged:Connect(refresh)

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
	StoreController.Opened:Connect(ShopController.Close)
	ProximityPromptService.PromptTriggered:Connect(function(prompt)
		if prompt:GetAttribute("OpensShop") then
			ShopController.Open("Upgrades")
		elseif prompt:GetAttribute("OpensRebirth") then
			ShopController.Open("Rebirth")
		end
	end)
end

return ShopController
