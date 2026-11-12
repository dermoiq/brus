--!strict
-- CollectionService tags and the zone lookup shared by server and client.

local Workspace = game:GetService("Workspace")

local ZoneUtil = {
	NodeTag = "CrystalNode",
	GateTag = "ZoneGate",
	-- Portal models carry attribute Zone = <zoneId> or "Lobby" and a ProximityPrompt descendant.
	PortalTag = "Portal",
	LobbyId = "Lobby",
}

-- A node/gate belongs to the zone named by its "Zone" attribute, or else to the Workspace.Zones.<ZoneId>
-- folder it lives under.
function ZoneUtil.GetZoneId(instance: Instance): string?
	local attribute = instance:GetAttribute("Zone")
	if typeof(attribute) == "string" then
		return attribute
	end
	local zonesFolder = Workspace:FindFirstChild("Zones")
	if not zonesFolder then
		return nil
	end
	local current: Instance? = instance
	while current and current.Parent ~= zonesFolder do
		current = current.Parent
	end
	return if current then current.Name else nil
end

-- Nodes and gates may be a single BasePart or a Model.
function ZoneUtil.GetAnchorPart(instance: Instance): BasePart?
	if instance:IsA("BasePart") then
		return instance
	elseif instance:IsA("Model") then
		return instance.PrimaryPart or instance:FindFirstChildWhichIsA("BasePart", true)
	end
	return nil
end

function ZoneUtil.GetPosition(instance: Instance): Vector3?
	if instance:IsA("PVInstance") then
		return instance:GetPivot().Position
	end
	return nil
end

return ZoneUtil
