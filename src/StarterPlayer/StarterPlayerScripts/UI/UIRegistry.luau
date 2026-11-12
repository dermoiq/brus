--!strict
-- Named lookup for UI elements the tutorial can point at (e.g. "ShopButton", "Upgrade:GemMultiplier").

local registry: { [string]: GuiObject } = {}

local UIRegistry = {}

function UIRegistry.Register(key: string, gui: GuiObject)
	registry[key] = gui
end

function UIRegistry.Get(key: string): GuiObject?
	local gui = registry[key]
	if gui and gui.Parent then
		return gui
	end
	return nil
end

-- True only if the element and every ancestor is visible and its ScreenGui is enabled.
function UIRegistry.IsShown(gui: GuiObject): boolean
	local current: Instance? = gui
	while current do
		if current:IsA("GuiObject") and not current.Visible then
			return false
		elseif current:IsA("LayerCollector") then
			return current.Enabled
		end
		current = current.Parent
	end
	return false
end

return UIRegistry
