--!strict
-- Onboarding steps. Target is resolved by the client TutorialController:
--   "NearestNode"      -> world arrow + beam to the closest crystal
--   "<RegistryKey>"    -> UI highlight on a button registered in UIRegistry (e.g. "ShopButton", "Upgrade:GemMultiplier")
-- Step completion is decided by the server (TutorialService), never by the client.

export type StepDef = {
	Id: string,
	Title: string,
	Body: string,
	Target: string,
	Goal: number?,
}

local Steps: { StepDef } = {
	{
		Id = "Mine",
		Title = "Mine your first crystal",
		Body = "Walk up to a glowing crystal and click or tap to swing.",
		Target = "NearestNode",
	},
	{
		Id = "Collect",
		Title = "Collect 40 Gems",
		Body = "Hold to keep swinging. Lucky crits pay 5x!",
		Target = "NearestNode",
		Goal = 40,
	},
	{
		Id = "OpenShop",
		Title = "Open the Shop",
		Body = "Time to spend those Gems.",
		Target = "ShopButton",
	},
	{
		Id = "BuyUpgrade",
		Title = "Buy a Gem Multiplier",
		Body = "Upgrades boost every swing, forever.",
		Target = "Upgrade:GemMultiplier",
	},
}

return {
	Steps = Steps,
	Reward = 100,
}
