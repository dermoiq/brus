--!strict
-- Gems/XP/levels, every purchase (upgrades, pickaxes, zones, rebirth), Auto-Upgrade and leaderstats.
-- All prices are computed here from shared config; the client only ever says *what* it wants to buy.

local Players = game:GetService("Players")
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

local DataService = require(script.Parent.DataService)
local EquipService = require(script.Parent.EquipService)
local RateLimiter = require(script.Parent.RateLimiter)

local Remotes = ReplicatedStorage.Remotes

type PlayerData = Types.PlayerData

local ProgressionService = {
	Purchased = Signal.new(), -- (player, kind, id)
}

local purchaseLimiter = RateLimiter.new(6, 10)
local settingLimiter = RateLimiter.new(2, 4)

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
		Remotes.Notify:FireClient(player, "LevelUp", newLevel)
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
	EquipService.Equip(player, id)
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

local function rebirth(player: Player, data: PlayerData): (boolean, string)
	local cost = Formulas.RebirthCost(data.Rebirths)
	if data.Gems < cost then
		return false, `Need {Format.Abbreviate(cost)} Gems to rebirth`
	end
	DataService.Update(player, function(d)
		d.Gems = 0
		d.Upgrades = {}
		d.Rebirths += 1
	end)
	return true, `Rebirth #{data.Rebirths}! Gems are now boosted forever.`
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

	local ok, message
	if kind == "Rebirth" then
		ok, message = rebirth(player, data)
	elseif typeof(id) ~= "string" then
		return false, "Invalid request"
	elseif kind == "Upgrade" then
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

local function cheapestUpgrade(data: PlayerData): (string?, number)
	local bestId, bestCost = nil, math.huge
	for _, def in Upgrades.List do
		local level = Formulas.UpgradeLevel(data, def.Id)
		if level < def.MaxLevel then
			local cost = Formulas.UpgradeCost(def.Id, level)
			if cost < bestCost then
				bestId, bestCost = def.Id, cost
			end
		end
	end
	return bestId, bestCost
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

	folder.Parent = player
end

local function updateLeaderstats(player: Player, data: PlayerData)
	local folder = player:FindFirstChild("leaderstats")
	local gems = folder and folder:FindFirstChild("Gems")
	local rebirths = folder and folder:FindFirstChild("Rebirths")
	if gems and gems:IsA("StringValue") then
		gems.Value = Format.Abbreviate(data.Gems)
	end
	if rebirths and rebirths:IsA("IntValue") then
		rebirths.Value = data.Rebirths
	end
end

function ProgressionService.Start()
	Remotes.Purchase.OnServerInvoke = handlePurchase

	Remotes.SetSetting.OnServerEvent:Connect(function(player, key, value)
		if not settingLimiter:Check(player) then
			return
		end
		if key == "AutoUpgrade" and typeof(value) == "boolean" then
			DataService.Update(player, function(d)
				d.Settings.AutoUpgrade = value
			end)
		end
	end)

	DataService.ProfileLoaded:Connect(setupLeaderstats)
	DataService.Changed:Connect(updateLeaderstats)

	-- Auto-Upgrade: buys the cheapest affordable stat upgrade. Gate it behind a game pass if desired.
	task.spawn(function()
		while true do
			task.wait(Progression.AutoUpgradeInterval)
			for _, player in Players:GetPlayers() do
				local data = DataService.Get(player)
				if data and data.Settings.AutoUpgrade then
					local id, cost = cheapestUpgrade(data)
					if id and data.Gems >= cost then
						local ok, message = buyUpgrade(player, data, id)
						if ok then
							Remotes.Notify:FireClient(player, "AutoUpgrade", message)
							ProgressionService.Purchased:Fire(player, "Upgrade", id)
						end
					end
				end
			end
		end
	end)
end

return ProgressionService
