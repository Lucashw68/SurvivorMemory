SurvivorMemory = SurvivorMemory or {}
SurvivorMemory.ImportantMemory = SurvivorMemory.ImportantMemory or {}

local ImportantMemory = SurvivorMemory.ImportantMemory

ImportantMemory.Kind = {
    GENERATOR = "GENERATOR",
    GAS_PUMP = "GAS_PUMP",
    WOOD_STOVE = "WOOD_STOVE",
}

function ImportantMemory.isValidKind(kind)
    for _, value in pairs(ImportantMemory.Kind) do
        if kind == value then return true end
    end
    return false
end

function ImportantMemory.kindFromFields(fields)
    fields = fields or {}
    if fields.objectType == "IsoGenerator" then return ImportantMemory.Kind.GENERATOR end
    if fields.containerType == "woodstove" then return ImportantMemory.Kind.WOOD_STOVE end
    if fields.hasFuelAmount == true then return ImportantMemory.Kind.GAS_PUMP end
    return nil
end

function ImportantMemory.placeKey(buildingKey, x, y, z)
    if type(buildingKey) == "string" and buildingKey ~= "" then
        return "building:" .. buildingKey
    end
    x, y, z = tonumber(x), tonumber(y), tonumber(z)
    if not x or not y or not z then return nil end
    return string.format("area:%d:%d:%d", math.floor(x / 10), math.floor(y / 10), math.floor(z))
end

function ImportantMemory.key(kind, placeKey)
    if not ImportantMemory.isValidKind(kind) or type(placeKey) ~= "string" then return nil end
    return "important:v1:" .. kind .. ":" .. placeKey
end

function ImportantMemory.sanitize(key, observation)
    if type(key) ~= "string" or type(observation) ~= "table" then return nil end
    if not ImportantMemory.isValidKind(observation.kind) then return nil end
    if type(observation.placeKey) ~= "string" or tonumber(observation.observedAt) == nil then return nil end
    if ImportantMemory.key(observation.kind, observation.placeKey) ~= key then return nil end
    observation.observedAt = tonumber(observation.observedAt)
    observation.x = tonumber(observation.x)
    observation.y = tonumber(observation.y)
    observation.z = tonumber(observation.z)
    if not observation.x or not observation.y or not observation.z then return nil end
    if type(observation.buildingKey) ~= "string" then observation.buildingKey = nil end
    return observation
end

function ImportantMemory.observe(root, kind, location, observedAt)
    if type(root) ~= "table" or not ImportantMemory.isValidKind(kind) then return false, nil end
    location = location or {}
    local placeKey = ImportantMemory.placeKey(location.buildingKey, location.x, location.y, location.z)
    local key = ImportantMemory.key(kind, placeKey)
    observedAt = tonumber(observedAt)
    if not key or not observedAt then return false, nil end
    root.importantMemories = type(root.importantMemories) == "table" and root.importantMemories or {}
    local current = root.importantMemories[key]
    local created = current == nil
    current = current or { kind = kind, placeKey = placeKey }
    current.observedAt = observedAt
    current.x, current.y, current.z = tonumber(location.x), tonumber(location.y), tonumber(location.z)
    current.buildingKey = type(location.buildingKey) == "string" and location.buildingKey or nil
    root.importantMemories[key] = current
    return created, current
end

function ImportantMemory.forBuilding(root, buildingKey)
    local result = {}
    for _, observation in pairs(root and root.importantMemories or {}) do
        if observation.buildingKey == buildingKey then table.insert(result, observation) end
    end
    table.sort(result, function(a, b)
        if a.kind == b.kind then return a.observedAt > b.observedAt end
        return a.kind < b.kind
    end)
    return result
end

function ImportantMemory.outdoor(root)
    local result = {}
    for _, observation in pairs(root and root.importantMemories or {}) do
        if not observation.buildingKey then table.insert(result, observation) end
    end
    table.sort(result, function(a, b)
        if a.kind == b.kind then return a.placeKey < b.placeKey end
        return a.kind < b.kind
    end)
    return result
end

return ImportantMemory
