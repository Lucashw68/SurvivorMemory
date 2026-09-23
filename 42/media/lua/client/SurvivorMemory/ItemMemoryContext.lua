require "ISUI/ISInventoryPane"
require "SurvivorMemory/Runtime"

SurvivorMemory.ItemMemoryContext = SurvivorMemory.ItemMemoryContext or {}
local Context = SurvivorMemory.ItemMemoryContext
local Runtime = SurvivorMemory.Runtime

function Context.fill(playerNum, context, selections)
    local items = ISInventoryPane.getActualItems(selections)
    local eligible = {}
    for _, item in ipairs(items) do
        if Runtime.itemMemoryContext(playerNum, item) then eligible[#eligible + 1] = item end
    end
    if #eligible == 0 then return end
    context:addOption(getText("IGUI_SM_RememberItems"), playerNum, Runtime.rememberItems, eligible)
end

if not Context.installed then
    Events.OnFillInventoryObjectContextMenu.Add(Context.fill)
    Context.installed = true
end
return Context
