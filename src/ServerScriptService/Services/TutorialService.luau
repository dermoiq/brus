--!strict
-- Server-side tutorial state. The client renders whatever step the saved data says; only server events
-- (mining, purchases) advance steps, except the harmless "opened the shop" step. Skipping is always allowed.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Tutorial = require(Shared.Config.Tutorial)
local Types = require(Shared.Types)

local DataService = require(script.Parent.DataService)
local MiningService = require(script.Parent.MiningService)
local ProgressionService = require(script.Parent.ProgressionService)
local RateLimiter = require(script.Parent.RateLimiter)

local Remotes = ReplicatedStorage.Remotes

local TutorialService = {}

local actionLimiter = RateLimiter.new(2, 5)

local function currentStep(data: Types.PlayerData): Tutorial.StepDef?
	if data.TutorialDone then
		return nil
	end
	return Tutorial.Steps[data.TutorialStep]
end

local function advance(player: Player)
	local completed = false
	DataService.Update(player, function(d)
		d.TutorialStep += 1
		d.TutorialProgress = 0
		if d.TutorialStep > #Tutorial.Steps then
			d.TutorialDone = true
			d.Gems += Tutorial.Reward
			completed = true
		end
	end)
	if completed then
		Remotes.Notify:FireClient(player, "TutorialComplete", Tutorial.Reward)
	end
end

function TutorialService.Start()
	MiningService.Mined:Connect(function(player: Player, gems: number)
		local data = DataService.Get(player)
		local step = data and currentStep(data)
		if not step then
			return
		end
		if step.Id == "Mine" then
			advance(player)
		elseif step.Id == "Collect" then
			local goal = step.Goal or 0
			local reached = false
			DataService.Update(player, function(d)
				d.TutorialProgress += gems
				reached = d.TutorialProgress >= goal
			end)
			if reached then
				advance(player)
			end
		end
	end)

	-- Buying any upgrade proves the loop is understood, even if the player raced ahead of the steps.
	ProgressionService.Purchased:Connect(function(player: Player, kind: string)
		local data = DataService.Get(player)
		if kind ~= "Upgrade" or not data or data.TutorialDone then
			return
		end
		DataService.Update(player, function(d)
			d.TutorialStep = #Tutorial.Steps
		end)
		advance(player)
	end)

	Remotes.TutorialAction.OnServerEvent:Connect(function(player, action)
		if not actionLimiter:Check(player) then
			return
		end
		local data = DataService.Get(player)
		if not data or data.TutorialDone then
			return
		end
		if action == "Skip" then
			DataService.Update(player, function(d)
				d.TutorialDone = true
			end)
		elseif action == "OpenedShop" then
			local step = currentStep(data)
			if step and step.Id == "OpenShop" then
				advance(player)
			end
		end
	end)
end

return TutorialService
