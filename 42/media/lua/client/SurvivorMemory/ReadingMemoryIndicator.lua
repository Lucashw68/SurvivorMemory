require "ISUI/ISInventoryItem"
require "SurvivorMemory/Runtime"

SurvivorMemory = SurvivorMemory or {}
SurvivorMemory.ReadingMemoryIndicator = SurvivorMemory.ReadingMemoryIndicator or {}

local Indicator = SurvivorMemory.ReadingMemoryIndicator
local Runtime = SurvivorMemory.Runtime

function Indicator.install()
    if Indicator.installed or not ISInventoryItem or not ISInventoryItem.renderItemIcon then return end
    local original = ISInventoryItem.renderItemIcon
    ISInventoryItem.renderItemIcon = function(pane, item, x, y, alpha, w, h)
        local result = original(pane, item, x, y, alpha, w, h)
        if not pane or pane.Type ~= "ISInventoryPane" or type(pane.player) ~= "number"
                or not item then return result end
        local player = getSpecificPlayer(pane.player)
        if not Runtime.hasCollectedReadingItem(player, item) then return result end

        -- Blue bookmark in the icon's upper-left corner. Vanilla's read tick
        -- occupies the opposite corner and remains untouched.
        local size = math.max(9, math.min(14, math.floor((w or 32) * 0.32)))
        local left, top = x + 2, y + 2
        pane:drawRect(left, top, size, size, 0.95, 0.10, 0.35, 0.78)
        pane:drawRectBorder(left, top, size, size, 1, 0.87, 0.94, 1)
        pane:drawRect(left + math.floor(size / 2) - 1, top + 2, 2, size - 5,
            1, 0.92, 0.97, 1)
        return result
    end
    Indicator.installed = true
end

Events.OnGameStart.Add(Indicator.install)

return Indicator
