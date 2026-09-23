SurvivorMemory = SurvivorMemory or {}
SurvivorMemory.BuildingLinks = SurvivorMemory.BuildingLinks or {}
local Links = SurvivorMemory.BuildingLinks

function Links.resolve(root, key)
    if not key then return nil end
    local original, seen = key, {}
    local aliases = root and root.buildingAliases or {}
    while type(aliases[key]) == "string" do
        if seen[key] then return original end
        seen[key] = true
        key = aliases[key]
    end
    if key ~= original and not (root.buildings and root.buildings[key]) then return original end
    return key
end

-- Evidence is taken from two consecutive, locally occupied squares, never
-- from bounds overlap or the world's list of buildings.
function Links.isBasementPassage(previous, current)
    if not previous or not current or not previous.key or not current.key then return false end
    return previous.key ~= current.key and math.min(previous.z, current.z) < 0
        and math.abs(previous.z - current.z) == 1
        and math.abs(previous.x - current.x) + math.abs(previous.y - current.y) <= 2
        and (previous.stairs == true or current.stairs == true)
        and (previous.vehicle ~= true and current.vehicle ~= true)
end

local function copy(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for key, child in pairs(value) do result[key] = copy(child) end
    return result
end

local function union(target, source, useEarliest)
    for key, value in pairs(source or {}) do
        if target[key] == nil then target[key] = value
        elseif useEarliest then target[key] = math.min(target[key], value)
        else target[key] = math.max(target[key], value) end
    end
end

local function roomKeyFor(key, sourceKey, targetKey)
    local prefix = "r1:" .. #sourceKey .. ":" .. sourceKey
    if key:sub(1, #prefix + 1) == prefix .. ":" then
        return "r1:" .. #targetKey .. ":" .. targetKey .. key:sub(#prefix + 1)
    end
    return key
end

function Links.merge(root, sourceKey, targetKey)
    sourceKey, targetKey = Links.resolve(root, sourceKey), Links.resolve(root, targetKey)
    if not sourceKey or not targetKey or sourceKey == targetKey then return false end
    local source, target = root.buildings[sourceKey], root.buildings[targetKey]
    if not source or not target then return false end
    root.buildingAliases = root.buildingAliases or {}
    root.linkedBuildingHistory = root.linkedBuildingHistory or {}
    -- Preserve the original component for diagnostics/migration conflicts.
    root.linkedBuildingHistory[sourceKey] = copy(source)
    root.linkedBuildingHistory[targetKey] = root.linkedBuildingHistory[targetKey] or copy(target)
    target.firstVisited = math.min(target.firstVisited, source.firstVisited)
    target.lastVisited = math.max(target.lastVisited, source.lastVisited)
    -- Old independent counters cannot be added: they counted stair transitions.
    target.visitCount = math.max(target.visitCount, source.visitCount)
    for key, value in pairs(source.roomsKnown) do
        local nextKey = roomKeyFor(key, sourceKey, targetKey)
        target.roomsKnown[nextKey] = math.min(target.roomsKnown[nextKey] or value, value)
    end
    union(target.containersKnown, source.containersKnown, true)
    union(target.containersInspected, source.containersInspected, false)
    target.lootRespawnArmed = target.lootRespawnArmed or {}
    union(target.lootRespawnArmed, source.lootRespawnArmed, true)
    target.itemMemories = target.itemMemories or {}
    for key, value in pairs(source.itemMemories or {}) do
        if not target.itemMemories[key] or value.observedAt > target.itemMemories[key].observedAt then
            target.itemMemories[key] = copy(value)
        end
    end
    if target.placeDesignation == "NONE" then target.placeDesignation = source.placeDesignation end
    if source.emotionalMemory and (not target.emotionalMemory
            or source.emotionalMemory.observedAt > target.emotionalMemory.observedAt) then
        target.emotionalMemory = copy(source.emotionalMemory)
    end
    SurvivorMemory.LocationName.merge(target, source)
    for key, value in pairs(copy(root.importantMemories or {})) do
        if value.buildingKey == sourceKey then
            local observation = copy(value)
            observation.buildingKey = targetKey
            observation.placeKey = "building:" .. targetKey
            local nextKey = SurvivorMemory.ImportantMemory.key(observation.kind, observation.placeKey)
            local existing = root.importantMemories[nextKey]
            if not existing or existing.observedAt < observation.observedAt then
                root.importantMemories[nextKey] = observation
            end
            root.importantMemories[key] = nil
        end
    end
    root.buildingAliases[sourceKey] = targetKey
    root.buildings[sourceKey] = nil
    SurvivorMemory.MemoryStore.recomputeStatus(target)
    target.searchCompletedAt = target.status == "SEARCHED"
        and math.max(target.searchCompletedAt or 0, source.searchCompletedAt or 0) or nil
    root.revision = (tonumber(root.revision) or 0) + 1
    return true
end

return Links
