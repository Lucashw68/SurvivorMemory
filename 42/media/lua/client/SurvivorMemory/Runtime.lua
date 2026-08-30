require "SurvivorMemory/BuildingIdentity"
require "SurvivorMemory/ContainerIdentity"
require "SurvivorMemory/MemoryStore"
require "SurvivorMemory/TimeFormat"
require "SurvivorMemory/VisitSession"
require "SurvivorMemory/LocationName"

SurvivorMemory = SurvivorMemory or {}
SurvivorMemory.Runtime = SurvivorMemory.Runtime or {}

local Runtime = SurvivorMemory.Runtime
local BuildingIdentity = SurvivorMemory.BuildingIdentity
local ContainerIdentity = SurvivorMemory.ContainerIdentity
local MemoryStore = SurvivorMemory.MemoryStore
local TimeFormat = SurvivorMemory.TimeFormat
local VisitSession = SurvivorMemory.VisitSession
local LocationName = SurvivorMemory.LocationName

Runtime.players = Runtime.players or {}
Runtime.hooksInstalled = Runtime.hooksInstalled or false
Runtime.counters = Runtime.counters or { playerUpdates = 0, squareTransitions = 0 }
Runtime.listeners = Runtime.listeners or {}

function Runtime.addListener(listener)
    Runtime.listeners[listener] = true
end

function Runtime.removeListener(listener)
    Runtime.listeners[listener] = nil
end

local function notify(eventName, player, memory)
    for listener in pairs(Runtime.listeners) do
        local ok, message = pcall(listener, eventName, player, memory)
        if not ok then print("[SurvivorMemory] listener error=" .. tostring(message)) end
    end
end

local function stateFor(player)
    local playerNum = player:getPlayerNum()
    local state = Runtime.players[playerNum]
    if not state then
        state = VisitSession.new()
        state.x, state.y, state.z = nil, nil, nil
        Runtime.players[playerNum] = state
    end
    return state
end

local function rootFor(player)
    return MemoryStore.forModData(player:getModData())
end

local function increment(root, name)
    root.debug[name] = (tonumber(root.debug[name]) or 0) + 1
end

local function syncPlayer(player, root)
    if root then
        increment(root, "modDataWrites")
        root.revision = (tonumber(root.revision) or 0) + 1
    end
    if isClient() then
        player:transmitModData()
    end
end

local function enterBuilding(player, state, building, now)
    local identity = BuildingIdentity.fromBuilding(building)
    if not identity then return nil end
    local root = rootFor(player)
    local memory = MemoryStore.enterBuilding(root, identity, now)
    LocationName.observe(memory, building, player:getCurrentSquare() and player:getCurrentSquare():getRoom())
    state.buildingKey = identity.key
    increment(root, "buildingEntries")
    syncPlayer(player, root)
    notify("entered", player, memory)
    return memory
end

local function discoverCurrentRoom(player, state, room, memory, now)
    local roomKey = BuildingIdentity.roomKey(state.buildingKey, room)
    state.roomKey = roomKey
    if roomKey and MemoryStore.discoverRoom(memory, roomKey, now) then
        local root = rootFor(player)
        increment(root, "roomsDiscovered")
        syncPlayer(player, root)
    end
end

function Runtime.onPlayerUpdate(player)
    if not player or not player:isLocalPlayer() then return end
    Runtime.counters.playerUpdates = Runtime.counters.playerUpdates + 1
    local square = player:getCurrentSquare()
    if not square then return end
    local state = stateFor(player)
    local x, y, z = square:getX(), square:getY(), square:getZ()
    if state.x == x and state.y == y and state.z == z then return end
    Runtime.counters.squareTransitions = Runtime.counters.squareTransitions + 1
    state.x, state.y, state.z = x, y, z

    local building = square:getBuilding()
    local identity = BuildingIdentity.fromBuilding(building)
    local nextKey = identity and identity.key or nil
    local now = TimeFormat.worldAgeHours()

    local currentRoot = rootFor(player)
    local transition = VisitSession.update(state, nextKey,
        nextKey ~= nil and currentRoot.buildings[nextKey] ~= nil)
    if transition.exited then
        increment(currentRoot, "buildingExits")
        syncPlayer(player, currentRoot)
        notify("exited", player, nil)
    end
    if transition.entered then
        enterBuilding(player, state, building, now)
    elseif transition.resumed then
        local resumedMemory = currentRoot.buildings[nextKey]
        if resumedMemory then
            LocationName.observe(resumedMemory, building, square:getRoom())
            notify("entered", player, resumedMemory)
        end
    end

    if not state.buildingKey then return end
    local root = rootFor(player)
    local memory = root.buildings[state.buildingKey]
    local room = square:getRoom()
    local nextRoomKey = BuildingIdentity.roomKey(state.buildingKey, room)
    if nextRoomKey ~= state.roomKey then
        state.roomKey = nil
        if room then
            local oldKind = memory.locationKind
            discoverCurrentRoom(player, state, room, memory, now)
            if LocationName.observe(memory, building, room) and memory.locationKind ~= oldKind then
                syncPlayer(player, root)
            end
            notify("updated", player, memory)
        end
    end
end

local function memoryForContainer(page, container)
    if not page or not container then return nil, nil, nil end
    local player = getSpecificPlayer(page.player)
    if not player then return nil, nil, nil end
    local square = container:getSourceGrid()
    local building = square and square:getBuilding() or nil
    if not ContainerIdentity.isNaturalBuildingContainer(container, building) then
        return nil, nil, nil
    end
    local identity = BuildingIdentity.fromBuilding(building)
    local root = rootFor(player)
    local memory = identity and root.buildings[identity.key] or nil
    if not memory then return nil, nil, nil end
    return player, root, memory
end

function Runtime.observeContainer(page, container)
    local player, root, memory = memoryForContainer(page, container)
    if not memory then return end
    local key = ContainerIdentity.fromContainer(container)
    if not key then return end
    local oldStatus = memory.status
    if MemoryStore.observeContainer(memory, key, TimeFormat.worldAgeHours()) then
        increment(root, "containersObserved")
        syncPlayer(player, root)
        notify(oldStatus ~= memory.status and "status" or "updated", player, memory)
    end
end

function Runtime.inspectContainer(page, container)
    local player, root, memory = memoryForContainer(page, container)
    if not memory then return end
    local key = ContainerIdentity.fromContainer(container)
    if not key then return end
    local now = TimeFormat.worldAgeHours()
    local oldStatus = memory.status
    local firstInspection = memory.containersInspected[key] == nil
    MemoryStore.inspectContainer(memory, key, now)
    if firstInspection then
        increment(root, "containersInspected")
    end
    syncPlayer(player, root)
    notify(oldStatus ~= memory.status and "status" or "updated", player, memory)
end

function Runtime.installInventoryHooks()
    if Runtime.hooksInstalled then return end
    require "ISUI/ISInventoryPage"
    if not ISInventoryPage then return end

    local originalAddContainerButton = ISInventoryPage.addContainerButton
    ISInventoryPage.addContainerButton = function(self, container, texture, name, tooltip)
        local button = originalAddContainerButton(self, container, texture, name, tooltip)
        Runtime.observeContainer(self, container)
        return button
    end

    local originalSelectContainer = ISInventoryPage.selectContainer
    ISInventoryPage.selectContainer = function(self, button)
        local result = originalSelectContainer(self, button)
        if button then Runtime.inspectContainer(self, button.inventory) end
        return result
    end

    local originalSetNewContainer = ISInventoryPage.setNewContainer
    ISInventoryPage.setNewContainer = function(self, inventory)
        local result = originalSetNewContainer(self, inventory)
        Runtime.inspectContainer(self, inventory)
        return result
    end

    Runtime.hooksInstalled = true
    print("[SurvivorMemory] B42 inventory observation hooks installed")
end

function Runtime.currentMemory(playerNum)
    local player = getSpecificPlayer(playerNum or 0)
    if not player then return nil, nil end
    local state = stateFor(player)
    local root = rootFor(player)
    return root.buildings[state.buildingKey], root
end

function Runtime.debugSnapshot(playerNum)
    local player = getSpecificPlayer(playerNum or 0)
    if not player then return nil end
    local state = stateFor(player)
    local memory, root = Runtime.currentMemory(playerNum)
    return {
        state = state,
        memory = memory,
        root = root,
        runtimeCounters = Runtime.counters,
        estimatedBytes = MemoryStore.estimateSerializedBytes(root),
    }
end

function Runtime.resetPlayer(playerNum)
    Runtime.players[playerNum] = nil
end

Events.OnPlayerUpdate.Add(Runtime.onPlayerUpdate)
Events.OnGameStart.Add(Runtime.installInventoryHooks)
Events.OnCreatePlayer.Add(function(playerNum) Runtime.resetPlayer(playerNum) end)

return Runtime
