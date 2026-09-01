SurvivorMemory = SurvivorMemory or {}
SurvivorMemory.MemoryStore = SurvivorMemory.MemoryStore or {}

require "SurvivorMemory/LocationName"
require "SurvivorMemory/PlaceDesignation"
require "SurvivorMemory/EmotionalMemory"
require "SurvivorMemory/ImportantMemory"
require "SurvivorMemory/VehicleMemory"

local MemoryStore = SurvivorMemory.MemoryStore
local PlaceDesignation = SurvivorMemory.PlaceDesignation
local EmotionalMemory = SurvivorMemory.EmotionalMemory
local ImportantMemory = SurvivorMemory.ImportantMemory
local VehicleMemory = SurvivorMemory.VehicleMemory
MemoryStore.SCHEMA_VERSION = 5
MemoryStore.MOD_DATA_KEY = "SurvivorMemory"
MemoryStore.Status = {
    VISITED = "VISITED",
    PARTIALLY_SEARCHED = "PARTIALLY_SEARCHED",
    SEARCHED = "SEARCHED",
}

local function countKeys(values)
    local count = 0
    for _ in pairs(values or {}) do count = count + 1 end
    return count
end

local function sanitizeObservations(values)
    if type(values) ~= "table" then return {} end
    for key, timestamp in pairs(values) do
        if type(key) ~= "string" or type(timestamp) ~= "number" then
            values[key] = nil
        end
    end
    return values
end

local function sanitizeBuilding(key, memory)
    if type(key) ~= "string" or type(memory) ~= "table" then return nil end
    local firstVisited = tonumber(memory.firstVisited)
    local lastVisited = tonumber(memory.lastVisited)
    if not firstVisited and not lastVisited then return nil end
    firstVisited = firstVisited or lastVisited
    lastVisited = lastVisited or firstVisited
    if lastVisited < firstVisited then lastVisited = firstVisited end

    memory.buildingKey = key
    memory.firstVisited = firstVisited
    memory.lastVisited = lastVisited
    memory.visitCount = math.max(1, math.floor(tonumber(memory.visitCount) or 1))
    memory.roomsKnown = sanitizeObservations(memory.roomsKnown)
    memory.containersKnown = sanitizeObservations(memory.containersKnown)
    memory.containersInspected = sanitizeObservations(memory.containersInspected)
    memory.identityVersion = math.max(1, math.floor(tonumber(memory.identityVersion) or 1))
    memory.placeDesignation = PlaceDesignation.normalize(memory.placeDesignation)
    memory.emotionalMemory = EmotionalMemory.sanitize(memory.emotionalMemory)
    if not SurvivorMemory.LocationName.isValidKind(memory.locationKind) then
        memory.locationKind = "BUILDING"
    end
    return memory
end

function MemoryStore.migrate(raw)
    if type(raw) ~= "table" then raw = {} end
    raw = raw or {}
    local version = tonumber(raw.schemaVersion) or 0
    if version == 0 then
        raw.buildings = raw.buildings or {}
        raw.debug = raw.debug or {}
        raw.schemaVersion = 1
        version = 1
    end
    if version == 1 then
        raw.schemaVersion = 2
        version = 2
    end
    if version == 2 then
        raw.schemaVersion = 3
        version = 3
    end
    if version == 3 then
        raw.importantMemories = raw.importantMemories or {}
        raw.schemaVersion = 4
        version = 4
    end
    if version == 4 then
        raw.vehicleMemories = raw.vehicleMemories or {}
        raw.schemaVersion = 5
        version = 5
    end
    if version ~= MemoryStore.SCHEMA_VERSION then
        error("Unsupported Survivor Memory schema: " .. tostring(version))
    end
    raw.buildings = raw.buildings or {}
    raw.debug = raw.debug or {}
    raw.importantMemories = raw.importantMemories or {}
    raw.vehicleMemories = raw.vehicleMemories or {}
    raw.revision = math.max(0, math.floor(tonumber(raw.revision) or 0))
    if type(raw.buildings) ~= "table" then raw.buildings = {} end
    if type(raw.debug) ~= "table" then raw.debug = {} end
    if type(raw.importantMemories) ~= "table" then raw.importantMemories = {} end
    if type(raw.vehicleMemories) ~= "table" then raw.vehicleMemories = {} end
    for key, memory in pairs(raw.buildings) do
        local sanitized = sanitizeBuilding(key, memory)
        if sanitized then
            raw.buildings[key] = sanitized
            MemoryStore.recomputeStatus(sanitized)
        else
            raw.buildings[key] = nil
        end
    end
    for key, observation in pairs(raw.importantMemories) do
        local sanitized = ImportantMemory.sanitize(key, observation)
        raw.importantMemories[key] = sanitized
    end
    for key, observation in pairs(raw.vehicleMemories) do
        raw.vehicleMemories[key] = VehicleMemory.sanitize(key, observation)
    end
    return raw
end

function MemoryStore.forModData(modData)
    local ok, root = pcall(MemoryStore.migrate, modData[MemoryStore.MOD_DATA_KEY])
    if not ok then
        modData.SurvivorMemoryRecovery = {
            reason = tostring(root),
            schemaVersion = tonumber(type(modData[MemoryStore.MOD_DATA_KEY]) == "table"
                and modData[MemoryStore.MOD_DATA_KEY].schemaVersion) or -1,
        }
        root = MemoryStore.migrate(nil)
    end
    modData[MemoryStore.MOD_DATA_KEY] = root
    return root
end

function MemoryStore.newBuilding(identity, observedAt)
    return {
        buildingKey = identity.key,
        firstVisited = observedAt,
        lastVisited = observedAt,
        visitCount = 1,
        roomsKnown = {},
        containersKnown = {},
        containersInspected = {},
        status = MemoryStore.Status.VISITED,
        centerX = identity.centerX,
        centerY = identity.centerY,
        identityVersion = 1,
        nativeIdObserved = identity.nativeId,
        locationKind = "BUILDING",
        placeDesignation = PlaceDesignation.NONE,
    }
end

function MemoryStore.setPlaceDesignation(memory, designation)
    if not memory or not PlaceDesignation.isValid(designation) then return false end
    if PlaceDesignation.normalize(memory.placeDesignation) == designation then return false end
    memory.placeDesignation = designation
    return true
end

function MemoryStore.enterBuilding(root, identity, observedAt)
    local memory = root.buildings[identity.key]
    if not memory then
        memory = MemoryStore.newBuilding(identity, observedAt)
        root.buildings[identity.key] = memory
    else
        memory.lastVisited = observedAt
        memory.visitCount = (tonumber(memory.visitCount) or 0) + 1
    end
    return memory
end

function MemoryStore.discoverRoom(memory, roomKey, observedAt)
    if not roomKey or memory.roomsKnown[roomKey] ~= nil then return false end
    memory.roomsKnown[roomKey] = observedAt
    return true
end

function MemoryStore.recomputeStatus(memory)
    local known = countKeys(memory.containersKnown)
    local inspected = countKeys(memory.containersInspected)
    if inspected == 0 then
        memory.status = MemoryStore.Status.VISITED
    elseif known > 0 and inspected >= known then
        memory.status = MemoryStore.Status.SEARCHED
    else
        memory.status = MemoryStore.Status.PARTIALLY_SEARCHED
    end
    return memory.status
end

function MemoryStore.observeContainer(memory, containerKey, observedAt)
    if not containerKey or memory.containersKnown[containerKey] ~= nil then return false end
    memory.containersKnown[containerKey] = observedAt
    MemoryStore.recomputeStatus(memory)
    return true
end

function MemoryStore.inspectContainer(memory, containerKey, observedAt)
    if not containerKey then return false end
    MemoryStore.observeContainer(memory, containerKey, observedAt)
    local firstInspection = memory.containersInspected[containerKey] == nil
    memory.containersInspected[containerKey] = observedAt
    MemoryStore.recomputeStatus(memory)
    return firstInspection
end

function MemoryStore.stats(root, memory)
    return {
        buildings = countKeys(root and root.buildings),
        roomsKnown = countKeys(memory and memory.roomsKnown),
        containersKnown = countKeys(memory and memory.containersKnown),
        containersInspected = countKeys(memory and memory.containersInspected),
    }
end

function MemoryStore.estimateSerializedBytes(value)
    local seen = {}
    local function estimate(item)
        local itemType = type(item)
        if itemType == "nil" then return 1 end
        if itemType == "boolean" then return 1 end
        if itemType == "number" then return 8 end
        if itemType == "string" then return #item + 4 end
        if itemType ~= "table" then return 0 end
        if seen[item] then return 0 end
        seen[item] = true
        local size = 8
        for key, child in pairs(item) do
            size = size + estimate(key) + estimate(child) + 2
        end
        return size
    end
    return estimate(value)
end

return MemoryStore
