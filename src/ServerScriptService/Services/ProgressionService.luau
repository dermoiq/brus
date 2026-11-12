--!strict
-- Gems/XP/levels, every Gem purchase (upgrades, pickaxes, zones), infinite rebirths, Auto-Upgrade,
-- Auto-Rebirth and leaderstats. Prices are computed here from shared config; the client only ever says
-- *what* it wants to buy.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Auras = require(Shared.Config.Auras)
local Format = require(Shared.Format)
local Formulas = require(Shared.Formulas)
local Items = require(Shared.Config.Items)
local Progression = require(Shared.Config.Progression)
local Rebirths = require(Shared.Config.Rebirths)
local Signal = require(Shared.Signal)
local Types = require(Shared.Types)
local Upgrades = require(Shared.Config.Upgrades)
local Zones = require(Shared.Config.Zones)

local DataService = require(script.Parent.DataService)
local EquipService = require(script.Parent.EquipService)
local RateLimiter = require(script.Parent.RateLimiter)

local Remotes = ReplicatedStorage.Remotes

type PlayerData = Types.PlayerData

local SETTINGS: { [string]: boolean } = { AutoUpgrade = true, AutoRebirth = true, AutoMine = true }

local ProgressionService = {
	Purchased = Signal.new(), -- (player, kind, id)
}

local purchaseLimiter = RateLimiter.new(6, 10)
local settingLimiter = RateLimiter.new(3, 6)

local function notify(player: Player, kind: string, payload: any)
	Remotes.Notify:FireClient(player, kind, payload)
end

function ProgressionService.AwardGems(player: Player, amount: number, xp: number)
	local newLevel: number? = nil
	DataService.Update(player, function(data)
		data.Gems += amount
		data.TotalGems += amount
		data.XP += xp
		local needed = Formulas.XPToNext(data.Level)
		while data.XP >= needed do
			data.XP -= needed
			data.Level += 1
			newLevel = data.Level
			needed = Formulas.XPToNext(data.Level)
		end
	end)
	if newLevel then
		notify(player, "LevelUp", newLevel)
	end
end

local function buyUpgrade(player: Player, data: PlayerData, id: string): (boolean, string)
	local def = Upgrades.ById[id]
	if not def then
		return false, "Unknown upgrade"
	end
	local level = Formulas.UpgradeLevel(data, id)
	if level >= def.MaxLevel then
		return false, "Already maxed!"
	end
	local cost = Formulas.UpgradeCost(id, level)
	if data.Gems < cost then
		return false, "Not enough Gems"
	end
	DataService.Update(player, function(d)
		d.Gems -= cost
		d.Upgrades[id] = level + 1
	end)
	return true, `{def.Name} is now Lv. {level + 1}!`
end

local function buyItem(player: Player, data: PlayerData, id: string): (boolean, string)
	local def = Items.ById[id]
	if not def then
		return false, "Unknown item"
	end
	if def.RebirthRequired or def.Gamepass then
		return false, "This pickaxe can't be bought with Gems"
	end
	if data.OwnedItems[id] then
		return false, "Already owned"
	end
	if data.Gems < def.Price then
		return false, "Not enough Gems"
	end
	DataService.Update(player, function(d)
		d.Gems -= def.Price
		d.OwnedItems[id] = true
	end)
	EquipService.Equip(player, "Item", id)
	return true, `Unlocked the {def.Name}!`
end

local function unlockZone(player: Player, data: PlayerData, id: string): (boolean, string)
	local def = Zones.ById[id]
	if not def then
		return false, "Unknown zone"
	end
	if data.UnlockedZones[id] then
		return false, "Already unlocked"
	end
	local previous = Zones.List[def.Order - 1]
	if previous and not data.UnlockedZones[previous.Id] then
		return false, `Unlock {previous.Name} first`
	end
	if data.Gems < def.Price then
		return false, `Need {Format.Abbreviate(def.Price)} Gems`
	end
	DataService.Update(player, function(d)
		d.Gems -= def.Price
		d.UnlockedZones[id] = true
	end)
	return true, `{def.Name} unlocked!`
end

local function announceUnlocks(player: Player, before: number, after: number)
	local oldRank, oldIndex = Formulas.RebirthRank(before)
	local newRank, newIndex = Formulas.RebirthRank(after)
	if newIndex > oldIndex and newRank ~= oldRank then
		notify(player, "RankUp", newRank.Name)
	end
	for _, def in Items.List do
		local need = def.RebirthRequired
		if need and need > before and need <= after then
			notify(player, "Unlock", `New pickaxe: {def.Name}!`)
		end
	end
	for _, def in Auras.List do
		local need = def.RebirthRequired
		if need and need > before and need <= after then
			notify(player, "Unlock", `New aura: {def.Name}!`)
		end
	end
end

-- Resets Gems, upgrades and shop pickaxes; keeps zones, level, exclusive pickaxes and auras.
-- `free` skips the cost (Instant Rebirth product).
function ProgressionService.Rebirth(player: Player, free: boolean): (boolean, string)
	local data = DataService.Get(player)
	if not data then
		return false, "Your data is still loading"
	end
	local cost = Formulas.RebirthCost(data.Rebirths)
	if not free and data.Gems < cost then
		return false, `Need {Format.Abbreviate(cost)} Gems to rebirth`
	end

	local perks = Formulas.Perks(player)
	local before = data.Rebirths
	DataService.Update(player, function(d)
		d.Gems = 0
		d.Upgrades = {}
		d.OwnedItems = { [Items.Default] = true }
		d.Rebirths += 1
		d.EquippedItem = Formulas.BestOwnedItem(d, perks)
	end)
	EquipService.Refresh(player)
	announceUnlocks(player, before, before + 1)
	ProgressionService.Purchased:Fire(player, "Rebirth", nil)

	local multiplier = Format.Multiplier(Formulas.RebirthMultiplier(before + 1))
	return true, `🔁 Rebirth #{before + 1}! All Gems are now {multiplier} forever.`
end

local function handlePurchase(player: Player, kind: unknown, id: unknown): (boolean, string)
	if not purchaseLimiter:Check(player) then
		return false, "Slow down!"
	end
	if typeof(kind) ~= "string" or (id ~= nil and typeof(id) ~= "string") then
		return false, "Invalid request"
	end
	local data = DataService.Get(player)
	if not data then
		return false, "Your data is still loading"
	end

	if kind == "Rebirth" then
		return ProgressionService.Rebirth(player, false)
	elseif typeof(id) ~= "string" then
		return false, "Invalid request"
	end

	local ok, message
	if kind == "Upgrade" then
		ok, message = buyUpgrade(player, data, id)
	elseif kind == "Item" then
		ok, message = buyItem(player, data, id)
	elseif kind == "Zone" then
		ok, message = unlockZone(player, data, id)
	else
		return false, "Invalid request"
	end

	if ok then
		ProgressionService.Purchased:Fire(player, kind, id)
	end
	return ok, message
end

-- Cheapest useful purchase: the next stat upgrade level, or the next stronger shop pickaxe.
local function cheapestAutoPurchase(data: PlayerData, perks: Types.Perks): (string?, string?, number)
	local bestKind, bestId, bestCost = nil, nil, math.huge
	for _, def in Upgrades.List do
		local level = Formulas.UpgradeLevel(data, def.Id)
		if level < def.MaxLevel then
			local cost = Formulas.UpgradeCost(def.Id, level)
			if cost < bestCost then
				bestKind, bestId, bestCost = "Upgrade", def.Id, cost
			end
		end
	end
	local power = Formulas.Power(data, perks)
	for _, def in Items.List do
		local forSale = not def.RebirthRequired and not def.Gamepass
		if forSale and not data.OwnedItems[def.Id] and def.Power > power then
			if def.Price < bestCost then
				bestKind, bestId, bestCost = "Item", def.Id, def.Price
			end
			break
		end
	end
	return bestKind, bestId, bestCost
end

local function runAutomation(player: Player)
	local data = DataService.Get(player)
	if not data then
		return
	end

	if
		data.Settings.AutoRebirth
		and data.Rebirths >= Rebirths.AutoRebirthUnlock
		and data.Gems >= Formulas.RebirthCost(data.Rebirths)
	then
		local ok, message = ProgressionService.Rebirth(player, false)
		if ok then
			notify(player, "AutoRebirth", message)
		end
		return
	end

	if data.Settings.AutoUpgrade then
		local kind, id, cost = cheapestAutoPurchase(data, Formulas.Perks(player))
		if kind and id and data.Gems >= cost then
			local ok, message
			if kind == "Upgrade" then
				ok, message = buyUpgrade(player, data, id)
			else
				ok, message = buyItem(player, data, id)
			end
			if ok then
				notify(player, "AutoUpgrade", message)
				ProgressionService.Purchased:Fire(player, kind, id)
			end
		end
	end
end

local function setupLeaderstats(player: Player, data: PlayerData)
	local folder = Instance.new("Folder")
	folder.Name = "leaderstats"

	local gems = Instance.new("StringValue")
	gems.Name = "Gems"
	gems.Value = Format.Abbreviate(data.Gems)
	gems.Parent = folder

	local rebirths = Instance.new("IntValue")
	rebirths.Name = "Rebirths"
	rebirths.Value = data.Rebirths
	rebirths.Parent = folder

	local rank = Instance.new("StringValue")
	rank.Name = "Rank"
	rank.Value = (Formulas.RebirthRank(data.Rebirths)).Name
	rank.Parent = folder

	folder.Parent = player
end

local function updateLeaderstats(player: Player, data: PlayerData)
	local folder = player:FindFirstChild("leaderstats")
	if not folder then
		return
	end
	local gems = folder:FindFirstChild("Gems")
	local rebirths = folder:FindFirstChild("Rebirths")
	local rank = folder:FindFirstChild("Rank")
	if gems and gems:IsA("StringValue") then
		gems.Value = Format.Abbreviate(data.Gems)
	end
	if rebirths and rebirths:IsA("IntValue") then
		rebirths.Value = data.Rebirths
	end
	if rank and rank:IsA("StringValue") then
		rank.Value = (Formulas.RebirthRank(data.Rebirths)).Name
	end
end

function ProgressionService.Start()
	Remotes.Purchase.OnServerInvoke = handlePurchase

	Remotes.SetSetting.OnServerEvent:Connect(function(player, key, value)
		if not settingLimiter:Check(player) or typeof(key) ~= "string" or typeof(value) ~= "boolean" then
			return
		end
		local data = DataService.Get(player)
		if not data or not SETTINGS[key] then
			return
		end
		if key == "AutoRebirth" and value and data.Rebirths < Rebirths.AutoRebirthUnlock then
			return
		end
		DataService.Update(player, function(d)
			(d.Settings :: any)[key] = value
		end)
	end)

	DataService.ProfileLoaded:Connect(setupLeaderstats)
	DataService.Changed:Connect(updateLeaderstats)

	task.spawn(function()
		while true do
			task.wait(Progression.AutoUpgradeInterval)
			for _, player in Players:GetPlayers() do
				runAutomation(player)
			end
		end
	end)
end

return ProgressionService
