SurvivorMemory = SurvivorMemory or {}
SurvivorMemory.VehicleMemory = SurvivorMemory.VehicleMemory or {}

local VehicleMemory = SurvivorMemory.VehicleMemory

local function integer(value)
    value = tonumber(value)
    if not value then return nil end
    return math.floor(value)
end

local function validText(value)
    return type(value) == "string" and value ~= "" and value or nil
end

function VehicleMemory.identityFromFields(fields)
    if type(fields) ~= "table" then return nil end
    local sqlId = integer(fields.sqlId)
    local mechanicalId = integer(fields.mechanicalId)
    local scriptName = validText(fields.scriptName)
    if sqlId and sqlId >= 0 then
        return {
            key = "vehicle:sql:" .. tostring(sqlId),
            kind = "SQL",
            sqlId = sqlId,
            mechanicalId = mechanicalId,
            scriptName = scriptName,
        }
    end
    if mechanicalId and mechanicalId >= 0 and scriptName then
        return {
            key = "vehicle:mechanical:" .. tostring(#scriptName) .. ":"
                .. scriptName .. ":" .. tostring(mechanicalId),
            kind = "MECHANICAL",
            mechanicalId = mechanicalId,
            scriptName = scriptName,
        }
    end
    return nil
end

function VehicleMemory.sanitize(key, observation)
    if type(key) ~= "string" or type(observation) ~= "table" then return nil end
    local identity = VehicleMemory.identityFromFields(observation)
    if not identity or identity.key ~= key then return nil end
    local x, y, z = integer(observation.x), integer(observation.y), integer(observation.z)
    local observedAt = tonumber(observation.observedAt)
    if not x or not y or not z or not observedAt then return nil end
    observation.vehicleKey = key
    observation.identityKind = identity.kind
    observation.sqlId = identity.sqlId
    observation.mechanicalId = identity.mechanicalId
    observation.scriptName = identity.scriptName
    observation.displayName = validText(observation.displayName) or identity.scriptName
    observation.x, observation.y, observation.z = x, y, z
    observation.observedAt = observedAt
    return observation
end

local function sameMechanicalIdentity(observation, descriptor)
    return tonumber(observation.mechanicalId) == tonumber(descriptor.mechanicalId)
        and observation.scriptName == descriptor.scriptName
        and descriptor.mechanicalId ~= nil
        and descriptor.scriptName ~= nil
end

function VehicleMemory.observe(root, descriptor, observedAt)
    if type(root) ~= "table" or type(descriptor) ~= "table" then return false, nil end
    local identity = VehicleMemory.identityFromFields(descriptor)
    local x, y, z = integer(descriptor.x), integer(descriptor.y), integer(descriptor.z)
    if not identity or not x or not y or not z or type(observedAt) ~= "number" then return false, nil end
    root.vehicleMemories = type(root.vehicleMemories) == "table" and root.vehicleMemories or {}

    local previousKey
    if identity.kind == "SQL" then
        for key, observation in pairs(root.vehicleMemories) do
            if key ~= identity.key and sameMechanicalIdentity(observation, descriptor) then
                previousKey = key
                root.vehicleMemories[key] = nil
                break
            end
        end
    end

    local existing = root.vehicleMemories[identity.key]
    local created = existing == nil and previousKey == nil
    local observation = existing or {}
    observation.vehicleKey = identity.key
    observation.identityKind = identity.kind
    observation.sqlId = identity.sqlId
    observation.mechanicalId = identity.mechanicalId
    observation.scriptName = identity.scriptName
    observation.displayName = validText(descriptor.displayName) or identity.scriptName
    observation.x, observation.y, observation.z = x, y, z
    observation.observedAt = observedAt
    root.vehicleMemories[identity.key] = observation
    return created, observation, previousKey
end

function VehicleMemory.remove(root, vehicleKey)
    if type(root) ~= "table" or type(root.vehicleMemories) ~= "table"
            or root.vehicleMemories[vehicleKey] == nil then return false end
    root.vehicleMemories[vehicleKey] = nil
    return true
end

function VehicleMemory.all(root)
    local memories = {}
    for _, observation in pairs(root and root.vehicleMemories or {}) do
        table.insert(memories, observation)
    end
    table.sort(memories, function(a, b) return tostring(a.vehicleKey) < tostring(b.vehicleKey) end)
    return memories
end

return VehicleMemory
