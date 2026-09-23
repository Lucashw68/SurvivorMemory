require "SurvivorMemory/BuildingIdentity"
require "SurvivorMemory/ContainerIdentity"
require "SurvivorMemory/MemoryStore"
require "SurvivorMemory/LootRespawnMemory"

local MODULE = "SurvivorMemory"

local function integer(value)
    local number = tonumber(value)
    return number and math.floor(number) or nil
end

local function nearby(player, square)
    local playerSquare = player and player:getCurrentSquare() or nil
    return playerSquare and square and playerSquare:getZ() == square:getZ()
        and math.abs(playerSquare:getX() - square:getX()) <= 4
        and math.abs(playerSquare:getY() - square:getY()) <= 4
end

local function resolveContainer(args)
    local x, y, z = integer(args.x), integer(args.y), integer(args.z)
    local objectIndex = integer(args.objectIndex)
    local containerIndex = integer(args.containerIndex)
    if not x or not y or not z or not objectIndex or not containerIndex
            or objectIndex < 0 or containerIndex < 0 then return nil end
    local square = getCell():getGridSquare(x, y, z)
    local objects = square and square:getObjects() or nil
    local object = objects and objectIndex < objects:size() and objects:get(objectIndex) or nil
    local container = object and containerIndex < object:getContainerCount()
        and object:getContainerByIndex(containerIndex) or nil
    return square, container
end

local function onClientCommand(module, command, player, args)
    if module ~= MODULE or command ~= "checkLootRespawn" or type(args) ~= "table" then return end
    local square, container = resolveContainer(args)
    local building = square and square:getBuilding() or nil
    local buildingIdentity = building and SurvivorMemory.BuildingIdentity.fromBuilding(building) or nil
    local containerKey = container and SurvivorMemory.ContainerIdentity.fromContainer(container) or nil
    local root = SurvivorMemory.MemoryStore.forModData(player:getModData())
    local observedKey = buildingIdentity and SurvivorMemory.BuildingLinks.resolve(root, buildingIdentity.key)
    local requestedKey = SurvivorMemory.BuildingLinks.resolve(root, args.buildingKey)
    local valid = nearby(player, square)
        and SurvivorMemory.ContainerIdentity.isNaturalBuildingContainer(container, building)
        and observedKey and observedKey == requestedKey
        and containerKey and containerKey == args.containerKey
    local armed = false
    if valid then
        local memory = root.buildings[observedKey]
        armed = SurvivorMemory.LootRespawnMemory.isArmed(memory, containerKey)
    end
    sendServerCommand(player, MODULE, "lootRespawnCheck", {
        playerNum = integer(args.playerNum) or 0,
        buildingKey = args.buildingKey,
        containerKey = args.containerKey,
        respawned = valid and armed and not container:isHasBeenLooted() or false,
    })
end

Events.OnClientCommand.Add(onClientCommand)
