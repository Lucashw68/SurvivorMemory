SurvivorMemory = SurvivorMemory or {}
SurvivorMemory.ItemMemory = SurvivorMemory.ItemMemory or {}
local ItemMemory = SurvivorMemory.ItemMemory

local function finite(value)
    return type(value) == "number" and value == value
        and value > -math.huge and value < math.huge
end

local function text(value)
    return type(value) == "string" and value ~= ""
end

function ItemMemory.key(containerKey, itemType)
    if not text(containerKey) or not text(itemType) then return nil end
    return #containerKey .. ":" .. containerKey .. ":" .. itemType
end

function ItemMemory.sanitize(key, value)
    if type(value) ~= "table" or key ~= ItemMemory.key(value.containerKey, value.itemType)
            or not text(value.displayName) or not finite(value.observedAt)
            or not finite(value.quantityObserved) or value.quantityObserved < 1 then return nil end
    return {
        itemType = value.itemType, displayName = value.displayName,
        containerKey = value.containerKey,
        quantityObserved = math.floor(value.quantityObserved), observedAt = value.observedAt,
        textureName = text(value.textureName) and value.textureName or nil,
    }
end

function ItemMemory.initialize(memory)
    local observations = memory.itemMemories
    if type(observations) ~= "table" then observations = {} end
    for key, value in pairs(observations) do
        observations[key] = ItemMemory.sanitize(key, value)
    end
    memory.itemMemories = observations
end

-- Explicit selections only. Recalling a type in a different container keeps
-- both observations; nothing here consults live containers or global items.
function ItemMemory.remember(memory, observation)
    if not memory or type(observation) ~= "table" then return false end
    local key = ItemMemory.key(observation.containerKey, observation.itemType)
    local value = key and ItemMemory.sanitize(key, observation) or nil
    if not value then return false end
    memory.itemMemories = memory.itemMemories or {}
    memory.itemMemories[key] = value
    return true
end

function ItemMemory.forget(memory, key)
    if not memory or not memory.itemMemories or not memory.itemMemories[key] then return false end
    memory.itemMemories[key] = nil
    return true
end

function ItemMemory.all(memory)
    local result = {}
    for key, observation in pairs(memory and memory.itemMemories or {}) do
        result[#result + 1] = { key = key, observation = observation }
    end
    table.sort(result, function(a, b)
        if a.observation.observedAt ~= b.observation.observedAt then
            return a.observation.observedAt > b.observation.observedAt
        end
        return a.key < b.key
    end)
    return result
end

return ItemMemory
