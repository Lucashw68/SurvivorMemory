SurvivorMemory = SurvivorMemory or {}
SurvivorMemory.VehicleMemory = SurvivorMemory.VehicleMemory or {}

local VehicleMemory = SurvivorMemory.VehicleMemory

VehicleMemory.FuelState = {
    EMPTY = "EMPTY",
    LOW = "LOW",
    SOME = "SOME",
    FULL = "FULL",
}
VehicleMemory.VehicleCondition = {
    FAILED = "FAILED",
    POOR = "POOR",
    USABLE = "USABLE",
    PERFECT = "PERFECT",
}

local function integer(value)
    value = tonumber(value)
    if not value then return nil end
    return math.floor(value)
end

local function validText(value)
    return type(value) == "string" and value ~= "" and value or nil
end

local function validValue(values, value)
    return type(value) == "string" and values[value] == value and value or nil
end

function VehicleMemory.fuelState(amount, capacity)
    amount, capacity = tonumber(amount), tonumber(capacity)
    if not amount or not capacity or capacity <= 0 then return nil end
    local ratio = math.max(0, math.min(1, amount / capacity))
    if amount <= 0.01 then return VehicleMemory.FuelState.EMPTY end
    if ratio < 0.15 then return VehicleMemory.FuelState.LOW end
    if ratio >= 0.75 then return VehicleMemory.FuelState.FULL end
    return VehicleMemory.FuelState.SOME
end

function VehicleMemory.vehicleCondition(condition, operational)
    condition = tonumber(condition)
    if not condition then return nil end
    if operational == false then return VehicleMemory.VehicleCondition.FAILED end
    if condition >= 90 then return VehicleMemory.VehicleCondition.PERFECT end
    if condition < 40 then return VehicleMemory.VehicleCondition.POOR end
    return VehicleMemory.VehicleCondition.USABLE
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
    observation.fuelState = validValue(VehicleMemory.FuelState, observation.fuelState)
    observation.fuelObservedAt = observation.fuelState and tonumber(observation.fuelObservedAt) or nil
    observation.vehicleCondition = validValue(VehicleMemory.VehicleCondition,
        observation.vehicleCondition)
    observation.vehicleConditionObservedAt = observation.vehicleCondition
        and tonumber(observation.vehicleConditionObservedAt) or nil
    -- These short-lived pre-release fields described only the engine. They must
    -- not survive as if they represented the vehicle's overall condition.
    observation.engineActivity, observation.engineActivityObservedAt = nil, nil
    observation.engineCondition, observation.engineConditionObservedAt = nil, nil
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

    local previousKey, previousObservation
    if identity.kind == "SQL" then
        for key, observation in pairs(root.vehicleMemories) do
            if key ~= identity.key and sameMechanicalIdentity(observation, descriptor) then
                previousKey = key
                previousObservation = observation
                root.vehicleMemories[key] = nil
                break
            end
        end
    end

    local existing = root.vehicleMemories[identity.key] or previousObservation
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
    local fuelState = validValue(VehicleMemory.FuelState, descriptor.fuelState)
    if fuelState then
        observation.fuelState = fuelState
        observation.fuelObservedAt = observedAt
    end
    local vehicleCondition = validValue(VehicleMemory.VehicleCondition,
        descriptor.vehicleCondition)
    if vehicleCondition then
        observation.vehicleCondition = vehicleCondition
        observation.vehicleConditionObservedAt = observedAt
    end
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
