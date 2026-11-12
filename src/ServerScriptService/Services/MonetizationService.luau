--!strict
-- Game passes and Developer Products (IDs live in Shared/Config/Monetization).
-- Pass ownership is mirrored into player attributes ("Pass_<Key>") so the server and client read the
-- same perks; clients can't change server-set attributes. Products are granted in ProcessReceipt with a
-- saved PurchaseId history, so a receipt is never granted twice even if Roblox retries it.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Format = require(Shared.Format)
local Formulas = require(Shared.Formulas)
local Monetization = require(Shared.Config.Monetization)

local DataService = require(script.Parent.DataService)
local ProgressionService = require(script.Parent.ProgressionService)

local Remotes = ReplicatedStorage.Remotes

local RECEIPT_HISTORY = 100
local DATA_WAIT = 15

local MonetizationService = {}

local passById: { [number]: Monetization.PassDef } = {}
local productById: { [number]: Monetization.ProductDef } = {}
for _, pass in Monetization.Gamepasses do
	if pass.Id ~= 0 then
		passById[pass.Id] = pass
	end
end
for _, product in Monetization.Products do
	if product.Id ~= 0 then
		productById[product.Id] = product
	end
end

local function setPass(player: Player, key: string, owned: boolean)
	player:SetAttribute(Monetization.AttributePrefix .. key, owned)
end

local function refreshPasses(player: Player)
	local grantAll = RunService:IsStudio() and Monetization.StudioOwnsAllPasses
	for _, pass in Monetization.Gamepasses do
		if grantAll then
			setPass(player, pass.Key, true)
		elseif pass.Id ~= 0 then
			local ok, owns = pcall(function()
				return MarketplaceService:UserOwnsGamePassAsync(player.UserId, pass.Id)
			end)
			if ok then
				setPass(player, pass.Key, owns == true)
			else
				warn(`[Monetization] Pass check failed for {pass.Key}: {owns}`)
			end
		end
	end
end

local function grant(player: Player, product: Monetization.ProductDef): (boolean, string)
	local data = DataService.Get(player)
	if not data then
		return false, ""
	end
	if product.Kind == "Gems" then
		local amount =
			Formulas.GemPackAmount(data, product.Minutes or 10, product.MinGems or 0, Formulas.Perks(player))
		DataService.Update(player, function(d)
			d.Gems += amount
			d.TotalGems += amount
		end)
		return true, `💎 +{Format.Abbreviate(amount)} Gems! Thank you!`
	elseif product.Kind == "Boost" then
		local seconds = (product.Minutes or 15) * 60
		DataService.Update(player, function(d)
			d.Boosts.GemsUntil = math.max(d.Boosts.GemsUntil, os.time()) + seconds
		end)
		return true, `⚡ {product.Name} active! Thank you!`
	elseif product.Kind == "Rebirth" then
		return ProgressionService.Rebirth(player, true)
	end
	return false, "Unknown product"
end

local function processReceipt(receipt: { [string]: any }): Enum.ProductPurchaseDecision
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local data = DataService.WaitForData(player, DATA_WAIT)
	if not data then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local purchaseId = tostring(receipt.PurchaseId)
	if table.find(data.ProcessedReceipts, purchaseId) then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	local product = productById[receipt.ProductId]
	if not product then
		warn(`[Monetization] Receipt for unknown product {receipt.ProductId}; add its Id to Config/Monetization`)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	-- Grant and record the receipt in the same frame (no yields), then persist before acknowledging.
	local ok, message = grant(player, product)
	if not ok then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	DataService.Update(player, function(d)
		table.insert(d.ProcessedReceipts, purchaseId)
		while #d.ProcessedReceipts > RECEIPT_HISTORY do
			table.remove(d.ProcessedReceipts, 1)
		end
	end)
	Remotes.Notify:FireClient(player, "Purchase", message)

	if not DataService.SaveNow(player) then
		-- Roblox retries later; the history check above prevents a double grant.
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

function MonetizationService.Start()
	MarketplaceService.ProcessReceipt = processReceipt

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		local pass = passById[passId]
		if purchased and pass then
			setPass(player, pass.Key, true)
			Remotes.Notify:FireClient(player, "Purchase", `{pass.Icon} {pass.Name} unlocked! Thank you!`)
		end
	end)

	Players.PlayerAdded:Connect(refreshPasses)
	for _, player in Players:GetPlayers() do
		task.spawn(refreshPasses, player)
	end
end

return MonetizationService
