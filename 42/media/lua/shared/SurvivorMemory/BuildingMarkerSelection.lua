SurvivorMemory = SurvivorMemory or {}
SurvivorMemory.BuildingMarkerSelection = SurvivorMemory.BuildingMarkerSelection or {}

require "SurvivorMemory/PlaceDesignation"

local BuildingMarkerSelection = SurvivorMemory.BuildingMarkerSelection
local PlaceDesignation = SurvivorMemory.PlaceDesignation

local function coordinateKey(memory)
    local x = tonumber(memory and memory.centerX)
    local y = tonumber(memory and memory.centerY)
    if not x or not y then return nil end
    return tostring(math.floor(x)) .. ":" .. tostring(math.floor(y))
end

local function preferred(candidate, current)
    local candidatePersonal = PlaceDesignation.isPersonalPlace(candidate.placeDesignation)
    local currentPersonal = PlaceDesignation.isPersonalPlace(current.placeDesignation)
    if candidatePersonal ~= currentPersonal then return candidatePersonal end

    local candidateVisited = tonumber(candidate.lastVisited) or 0
    local currentVisited = tonumber(current.lastVisited) or 0
    if candidateVisited ~= currentVisited then return candidateVisited > currentVisited end

    return tostring(candidate.buildingKey or "") < tostring(current.buildingKey or "")
end

function BuildingMarkerSelection.select(buildings)
    local byCoordinate = {}
    for _, memory in pairs(buildings or {}) do
        local key = coordinateKey(memory)
        local current = key and byCoordinate[key] or nil
        if key and (not current or preferred(memory, current)) then
            byCoordinate[key] = memory
        end
    end

    local selected = {}
    for _, memory in pairs(byCoordinate) do table.insert(selected, memory) end
    table.sort(selected, function(a, b)
        return tostring(a.buildingKey or "") < tostring(b.buildingKey or "")
    end)
    return selected
end

return BuildingMarkerSelection
