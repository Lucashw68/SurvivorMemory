SurvivorMemory = SurvivorMemory or {}
SurvivorMemory.LootRespawnMemory = SurvivorMemory.LootRespawnMemory or {}

local LootRespawnMemory = SurvivorMemory.LootRespawnMemory

local ELIGIBLE_ZONE_TYPES = {
    TownZone = true,
    TownZones = true,
    TrailerPark = true,
}

local function latestTimestamp(values)
    local latest = nil
    for _, timestamp in pairs(values or {}) do
        if type(timestamp) == "number" and (not latest or timestamp > latest) then
            latest = timestamp
        end
    end
    return latest
end

function LootRespawnMemory.isEligibleZoneType(zoneType)
    return ELIGIBLE_ZONE_TYPES[zoneType] == true
end

function LootRespawnMemory.sanitizeArmedContainers(values)
    if type(values) ~= "table" then return {} end
    for key, timestamp in pairs(values) do
        if type(key) ~= "string" or type(timestamp) ~= "number" then
            values[key] = nil
        end
    end
    return values
end

function LootRespawnMemory.initializeBuilding(memory)
    memory.lootRespawnArmed = LootRespawnMemory.sanitizeArmedContainers(
        memory.lootRespawnArmed)
    for key in pairs(memory.lootRespawnArmed) do
        if type(memory.containersKnown) ~= "table"
                or memory.containersKnown[key] == nil then
            memory.lootRespawnArmed[key] = nil
        end
    end
    if type(memory.searchCompletedAt) ~= "number" then
        memory.searchCompletedAt = memory.status == "SEARCHED"
            and latestTimestamp(memory.containersInspected) or nil
    end
    return memory
end

function LootRespawnMemory.markLooted(memory, containerKey, observedAt, eligible)
    if not memory or not containerKey or eligible ~= true or type(observedAt) ~= "number" then
        return false
    end
    if type(memory.containersKnown) ~= "table"
            or memory.containersKnown[containerKey] == nil then return false end
    memory.lootRespawnArmed = memory.lootRespawnArmed or {}
    if memory.lootRespawnArmed[containerKey] ~= nil then return false end
    memory.lootRespawnArmed[containerKey] = observedAt
    return true
end

function LootRespawnMemory.isArmed(memory, containerKey)
    return memory and type(memory.lootRespawnArmed) == "table"
        and type(memory.lootRespawnArmed[containerKey]) == "number"
end

function LootRespawnMemory.hasArmedContainer(memory)
    if not memory or type(memory.lootRespawnArmed) ~= "table" then return false end
    for _ in pairs(memory.lootRespawnArmed) do return true end
    return false
end

function LootRespawnMemory.recordStatus(memory, oldStatus, observedAt)
    if not memory then return end
    if memory.status == "SEARCHED" and oldStatus ~= "SEARCHED" then
        memory.searchCompletedAt = observedAt
    elseif memory.status ~= "SEARCHED" then
        memory.searchCompletedAt = nil
    end
end

function LootRespawnMemory.mayHaveReappeared(memory, now, respawnHours, unseenHours)
    if not memory or memory.status ~= "SEARCHED"
            or not LootRespawnMemory.hasArmedContainer(memory) then return false end
    local completedAt = tonumber(memory.searchCompletedAt)
    local current = tonumber(now)
    local interval = tonumber(respawnHours) or 0
    if not completedAt or not current or interval <= 0 then return false end
    local minimumAbsence = math.max(0, tonumber(unseenHours) or 0)
    local lastVisited = tonumber(memory.lastVisited) or completedAt
    if minimumAbsence > 0 and current - lastVisited < minimumAbsence then return false end
    for _, lootedAt in pairs(memory.lootRespawnArmed) do
        local baseline = math.max(completedAt, tonumber(lootedAt) or completedAt)
        if current - baseline >= interval then return true end
    end
    return false
end

-- A confirmed respawn invalidates the previous building-wide search pass. The
-- container that supplied the evidence is already visible in the loot UI, so
-- it remains inspected; every other known container must be revisited.
function LootRespawnMemory.confirm(memory, containerKey, observedAt)
    if not LootRespawnMemory.isArmed(memory, containerKey)
            or type(observedAt) ~= "number" then return false end
    memory.containersInspected = { [containerKey] = observedAt }
    memory.lootRespawnArmed[containerKey] = nil
    memory.searchCompletedAt = nil
    return true
end

return LootRespawnMemory
