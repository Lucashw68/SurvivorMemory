require "SurvivorMemory/BuildingIdentity"
require "SurvivorMemory/ContainerIdentity"
require "SurvivorMemory/MemoryStore"
require "SurvivorMemory/TimeFormat"
require "SurvivorMemory/VisitSession"
require "SurvivorMemory/LocationName"
require "SurvivorMemory/PlaceDesignation"
require "SurvivorMemory/EmotionalMemory"
require "SurvivorMemory/ImportantMemory"
require "SurvivorMemory/VehicleMemory"
require "SurvivorMemory/VisibleObservation"
require "SurvivorMemory/ModOptions"

SurvivorMemory = SurvivorMemory or {}
SurvivorMemory.Runtime = SurvivorMemory.Runtime or {}

local Runtime = SurvivorMemory.Runtime
local BuildingIdentity = SurvivorMemory.BuildingIdentity
local ContainerIdentity = SurvivorMemory.ContainerIdentity
local MemoryStore = SurvivorMemory.MemoryStore
local TimeFormat = SurvivorMemory.TimeFormat
local VisitSession = SurvivorMemory.VisitSession
local LocationName = SurvivorMemory.LocationName
local PlaceDesignation = SurvivorMemory.PlaceDesignation
local EmotionalMemory = SurvivorMemory.EmotionalMemory
local ImportantMemory = SurvivorMemory.ImportantMemory
local VehicleMemory = SurvivorMemory.VehicleMemory
local VisibleObservation = SurvivorMemory.VisibleObservation
local ModOptions = SurvivorMemory.ModOptions
local rootFor, increment, syncPlayer
local IMPORTANT_FEATURE_FOR_KIND = {
    [ImportantMemory.Kind.GENERATOR] = "generatorMemory",
    [ImportantMemory.Kind.GAS_PUMP] = "gasPumpMemory",
    [ImportantMemory.Kind.WOOD_STOVE] = "woodStoveMemory",
}

Runtime.players = Runtime.players or {}
Runtime.hooksInstalled = Runtime.hooksInstalled or false
Runtime.vehicleHooksInstalled = Runtime.vehicleHooksInstalled or false
Runtime.counters = Runtime.counters or { playerUpdates = 0, squareTransitions = 0 }
Runtime.listeners = Runtime.listeners or {}
Runtime.importantCandidates = Runtime.importantCandidates or {}
Runtime.importantCandidatesRevision = Runtime.importantCandidatesRevision or 0
Runtime.IMPORTANT_OBSERVATION_DELAY_MS = 250

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
        state.emotionalTracker = nil
        state.emotionalTriggeredThisVisit = false
        state.emotionalDangerThisVisit = false
        state.emotionalEnteredAt = nil
        state.nextEmotionalSampleMs = nil
        state.lastEmotionalSampleMs = nil
        state.activeVehicle = nil
        state.activeVehicleKey = nil
        state.visibleImportantObjects = {}
        state.importantCandidateRevision = -1
        state.importantObservationPending = false
        state.importantObservationAtMs = nil
        state.viewDirection = nil
        Runtime.players[playerNum] = state
    end
    return state
end

local function vehicleDisplayName(vehicle, script)
    if not script then return getText("IGUI_SM_GenericVehicle") end
    local name = script:getCarModelName() or script:getName()
    local translated = name and getTextOrNull("IGUI_VehicleName" .. tostring(name)) or nil
    return translated or tostring(name or script:getFullName() or getText("IGUI_SM_GenericVehicle"))
end

function Runtime.vehicleDescriptor(vehicle)
    if not vehicle or not instanceof(vehicle, "BaseVehicle") then return nil end
    local square = vehicle:getSquare()
    local script = vehicle:getScript()
    if not square or not script then return nil end
    local descriptor = {
        sqlId = vehicle:getSqlId(),
        mechanicalId = vehicle:getMechanicalID(),
        scriptName = vehicle:getScriptName() or script:getFullName() or script:getName(),
        displayName = vehicleDisplayName(vehicle, script),
        x = square:getX(), y = square:getY(), z = square:getZ(),
    }
    local identity = VehicleMemory.identityFromFields(descriptor)
    return identity and descriptor or nil
end

function Runtime.observeVehicle(player, vehicle, reason)
    if not ModOptions.enabled("vehicleTracking") then return false end
    if not player or not player:isLocalPlayer() then return false end
    local descriptor = Runtime.vehicleDescriptor(vehicle)
    if not descriptor then return false end
    local root = rootFor(player)
    local _, observation = VehicleMemory.observe(root, descriptor, TimeFormat.worldAgeHours())
    if not observation then return false end
    increment(root, "vehicleObservations")
    increment(root, "vehicleObservations_" .. tostring(reason or "interaction"))
    syncPlayer(player, root)
    notify("vehicle", player, nil)
    return true
end

function Runtime.onEnterVehicle(character)
    if not ModOptions.enabled("vehicleTracking") then return end
    if not character or not character:isLocalPlayer() then return end
    local vehicle = character:getVehicle()
    if not vehicle then return end
    local state = stateFor(character)
    state.activeVehicle = vehicle
    local descriptor = Runtime.vehicleDescriptor(vehicle)
    local identity = descriptor and VehicleMemory.identityFromFields(descriptor) or nil
    state.activeVehicleKey = identity and identity.key or nil
    Runtime.observeVehicle(character, vehicle, "enter")
end

function Runtime.onExitVehicle(character)
    if not ModOptions.enabled("vehicleTracking") then return end
    if not character or not character:isLocalPlayer() then return end
    local state = stateFor(character)
    local vehicle = state.activeVehicle
    if vehicle then Runtime.observeVehicle(character, vehicle, "exit") end
    state.activeVehicle = nil
    state.activeVehicleKey = nil
end

rootFor = function(player)
    return MemoryStore.forModData(player:getModData())
end

increment = function(root, name)
    root.debug[name] = (tonumber(root.debug[name]) or 0) + 1
end

syncPlayer = function(player, root)
    if root then
        increment(root, "modDataWrites")
        root.revision = (tonumber(root.revision) or 0) + 1
    end
    if isClient() then
        player:transmitModData()
    end
end

function Runtime.importantKindForObject(object)
    if not object then return nil end
    local objectType = instanceof(object, "IsoGenerator") and "IsoGenerator" or nil
    local container = object.getContainer and object:getContainer() or nil
    local containerType = container and container:getType() or nil
    local sprite = object.getSprite and object:getSprite() or nil
    local properties = sprite and sprite:getProperties() or nil
    return ImportantMemory.kindFromFields({
        objectType = objectType,
        containerType = containerType,
        hasFuelAmount = properties and properties:has("fuelAmount") or false,
    })
end

function Runtime.observeImportantObject(playerNum, object)
    local player = getSpecificPlayer(playerNum or 0)
    local kind = Runtime.importantKindForObject(object)
    local square = object and object:getSquare() or nil
    if not player or not kind or not ModOptions.enabled(IMPORTANT_FEATURE_FOR_KIND[kind])
            or not square or not square:isCouldSee(player:getPlayerNum()) then return false end
    local buildingIdentity = BuildingIdentity.fromBuilding(square:getBuilding())
    local root = rootFor(player)
    local _, observation = ImportantMemory.observe(root, kind, {
        x = square:getX(), y = square:getY(), z = square:getZ(),
        buildingKey = buildingIdentity and buildingIdentity.key or nil,
    }, TimeFormat.worldAgeHours())
    if not observation then return false end
    if square:isCanSee(player:getPlayerNum()) then
        stateFor(player).visibleImportantObjects[object] = true
    end
    increment(root, "importantObservations")
    syncPlayer(player, root)
    if observation.buildingKey == stateFor(player).buildingKey then
        notify("important", player, root.buildings[observation.buildingKey])
    end
    return true
end

function Runtime.trackImportantObject(object)
    if not Runtime.importantKindForObject(object) or not object:getSquare() then return false end
    if Runtime.importantCandidates[object] then return false end
    Runtime.importantCandidates[object] = true
    Runtime.importantCandidatesRevision = Runtime.importantCandidatesRevision + 1
    return true
end

function Runtime.onLoadGridSquare(square)
    if not square then return end
    local objects = square:getObjects()
    for index = 0, objects:size() - 1 do
        Runtime.trackImportantObject(objects:get(index))
    end
end

function Runtime.onObjectAdded(object)
    if not Runtime.trackImportantObject(object) then return end
    -- A moved/re-added object must be eligible for a fresh visible transition.
    for _, state in pairs(Runtime.players) do
        state.visibleImportantObjects[object] = nil
    end
end

function Runtime.onObjectAboutToBeRemoved(object)
    if not Runtime.importantCandidates[object] then return end
    Runtime.importantCandidates[object] = nil
    Runtime.importantCandidatesRevision = Runtime.importantCandidatesRevision + 1
    for _, state in pairs(Runtime.players) do
        state.visibleImportantObjects[object] = nil
    end
end

function Runtime.onSeeNewRoom()
    -- The candidate set is unchanged, but opening a new line of sight can make
    -- an already loaded remarkable object visible while the player stands still.
    Runtime.importantCandidatesRevision = Runtime.importantCandidatesRevision + 1
end

function Runtime.isImportantObjectVisible(playerNum, object)
    local player = getSpecificPlayer(playerNum)
    local square = object and object:getSquare() or nil
    if not player or not square or square:getZ() ~= player:getZ()
            or not square:isCanSee(playerNum) then return false end
    local screenX = isoToScreenX(playerNum,
        square:getX() + 0.5, square:getY() + 0.5, square:getZ())
    local screenY = isoToScreenY(playerNum,
        square:getX() + 0.5, square:getY() + 0.5, square:getZ())
    return VisibleObservation.isScreenPointVisible(screenX, screenY,
        getPlayerScreenLeft(playerNum), getPlayerScreenTop(playerNum),
        getPlayerScreenWidth(playerNum), getPlayerScreenHeight(playerNum))
end

function Runtime.observeVisibleImportantObjects(player)
    if not ModOptions.enabled("importantMemory")
            or not player or not player:isLocalPlayer() then return false end
    local playerNum = player:getPlayerNum()
    local state = stateFor(player)
    local activeCandidates = {}
    local staleCandidates = {}
    for object in pairs(Runtime.importantCandidates) do
        local square = object and object:getSquare() or nil
        local loadedSquare = square and getCell():getGridSquare(
            square:getX(), square:getY(), square:getZ()) or nil
        if square and loadedSquare == square then
            activeCandidates[object] = true
        else
            table.insert(staleCandidates, object)
        end
    end
    for _, object in ipairs(staleCandidates) do
        Runtime.importantCandidates[object] = nil
    end

    local current, newlyVisible, checked = VisibleObservation.reconcile(
        state.visibleImportantObjects, activeCandidates,
        function(object)
            return Runtime.isImportantObjectVisible(playerNum, object)
        end)
    state.visibleImportantObjects = current
    Runtime.counters.importantVisibilityPasses =
        (Runtime.counters.importantVisibilityPasses or 0) + 1
    Runtime.counters.importantCandidatesChecked =
        (Runtime.counters.importantCandidatesChecked or 0) + checked

    local observedKeys = {}
    local observedAny = false
    for _, object in ipairs(newlyVisible) do
        local square = object:getSquare()
        local kind = Runtime.importantKindForObject(object)
        local buildingIdentity = BuildingIdentity.fromBuilding(square:getBuilding())
        local placeKey = ImportantMemory.placeKey(buildingIdentity and buildingIdentity.key,
            square:getX(), square:getY(), square:getZ())
        local key = ImportantMemory.key(kind, placeKey)
        if key and not observedKeys[key] then
            observedKeys[key] = true
            if Runtime.observeImportantObject(playerNum, object) then
                observedAny = true
                Runtime.counters.importantBecameVisible =
                    (Runtime.counters.importantBecameVisible or 0) + 1
            end
        end
    end
    return observedAny
end

local function enterBuilding(player, state, building, now)
    local identity = BuildingIdentity.fromBuilding(building)
    if not identity then return nil end
    local root = rootFor(player)
    local memory = MemoryStore.enterBuilding(root, identity, now)
    LocationName.observe(memory, building, player:getCurrentSquare() and player:getCurrentSquare():getRoom())
    state.buildingKey = identity.key
    state.emotionalTracker = nil
    state.emotionalTriggeredThisVisit = false
    state.emotionalDangerThisVisit = false
    state.emotionalEnteredAt = now
    state.lastEmotionalSampleMs = nil
    state.nextEmotionalSampleMs = nil
    local reaction = ModOptions.enabled("emotionalReactions")
        and EmotionalMemory.reaction(memory.emotionalMemory, now) or nil
    if reaction then
        local reactionMultiplier = ModOptions.reactionMultiplier()
        local stats = player:getStats()
        stats:add(CharacterStat.PANIC, reaction.panic * reactionMultiplier)
        stats:add(CharacterStat.STRESS, reaction.stress * reactionMultiplier)
        EmotionalMemory.recordReaction(memory.emotionalMemory, now)
        increment(root, "emotionalReactions")
    end
    increment(root, "buildingEntries")
    syncPlayer(player, root)
    notify("entered", player, memory)
    return memory
end

local function emotionalSignal(player)
    local stats = player:getStats()
    local body = player:getBodyDamage()
    return {
        panic = stats:get(CharacterStat.PANIC),
        health = body:getHealth(),
        pain = stats:get(CharacterStat.PAIN),
        bleeding = body:getNumPartsBleeding(),
        veryCloseZombies = stats:getNumVeryCloseZombies(),
        chasingZombies = stats:getNumChasingZombies(),
        targeted = player:isTargetedByZombie(),
    }
end

local function sampleEmotionalMemory(player, state)
    if not ModOptions.enabled("emotionalMemory")
            or not state.buildingKey or state.emotionalTriggeredThisVisit then return end
    local nowMs = getTimestampMs()
    if state.nextEmotionalSampleMs and nowMs < state.nextEmotionalSampleMs then return end
    local elapsed = state.lastEmotionalSampleMs and (nowMs - state.lastEmotionalSampleMs) / 1000 or 0
    state.lastEmotionalSampleMs = nowMs
    state.nextEmotionalSampleMs = nowMs + 1000
    if elapsed <= 0 then return end
    local signal = emotionalSignal(player)
    if EmotionalMemory.isSevere(signal) then state.emotionalDangerThisVisit = true end
    local triggered
    state.emotionalTracker, triggered = EmotionalMemory.updateTracker(
        state.emotionalTracker, signal, elapsed)
    if not triggered then return end
    local root = rootFor(player)
    local memory = root.buildings[state.buildingKey]
    if not memory then return end
    EmotionalMemory.remember(memory, TimeFormat.worldAgeHours())
    state.emotionalTriggeredThisVisit = true
    increment(root, "emotionalMemoriesCreated")
    syncPlayer(player, root)
    notify("emotional", player, memory)
end

local function finishEmotionalVisit(state, root, buildingKey, now)
    local memory = root.buildings[buildingKey]
    if ModOptions.enabled("emotionalMemory")
            and memory and memory.emotionalMemory and not state.emotionalDangerThisVisit
            and tonumber(state.emotionalEnteredAt)
            and now - state.emotionalEnteredAt >= 0.10 then
        if EmotionalMemory.recordSafeReturn(memory) then
            increment(root, "emotionalSafeReturns")
        end
    end
    state.emotionalTracker = nil
    state.emotionalTriggeredThisVisit = false
    state.emotionalDangerThisVisit = false
    state.emotionalEnteredAt = nil
    state.lastEmotionalSampleMs = nil
    state.nextEmotionalSampleMs = nil
end

local function discoverCurrentRoom(player, state, room, memory, now)
    if not ModOptions.enabled("rooms") then return end
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
    if not ModOptions.enabled("master") then return end
    local square = player:getCurrentSquare()
    if not square then return end
    local state = stateFor(player)
    local currentVehicle = ModOptions.enabled("vehicleTracking") and player:getVehicle() or nil
    if currentVehicle and state.activeVehicle == nil then
        -- On reload the timed-action enter event has already happened. One observed
        -- resume restores the local session without sampling the driven route.
        state.activeVehicle = currentVehicle
        local descriptor = Runtime.vehicleDescriptor(currentVehicle)
        local identity = descriptor and VehicleMemory.identityFromFields(descriptor) or nil
        state.activeVehicleKey = identity and identity.key or nil
        Runtime.observeVehicle(player, currentVehicle, "resume")
    end
    sampleEmotionalMemory(player, state)
    local x, y, z = square:getX(), square:getY(), square:getZ()
    local positionChanged = state.x ~= x or state.y ~= y or state.z ~= z
    local direction = tostring(player:getCardinalDirection())
    local observationInputChanged = ModOptions.enabled("importantMemory") and (positionChanged
        or state.viewDirection ~= direction
        or state.importantCandidateRevision ~= Runtime.importantCandidatesRevision)
    if observationInputChanged then
        state.viewDirection = direction
        state.importantCandidateRevision = Runtime.importantCandidatesRevision
        state.importantObservationPending = true
        state.importantObservationAtMs = state.importantObservationAtMs
            or getTimestampMs() + Runtime.IMPORTANT_OBSERVATION_DELAY_MS
    end
    if state.importantObservationPending
            and ModOptions.enabled("importantMemory")
            and getTimestampMs() >= state.importantObservationAtMs then
        Runtime.observeVisibleImportantObjects(player)
        state.importantObservationPending = false
        state.importantObservationAtMs = nil
    end
    if not positionChanged then return end
    Runtime.counters.squareTransitions = Runtime.counters.squareTransitions + 1
    state.x, state.y, state.z = x, y, z

    if not ModOptions.enabled("buildingMemory") then return end

    local building = square:getBuilding()
    local identity = BuildingIdentity.fromBuilding(building)
    local nextKey = identity and identity.key or nil
    local now = TimeFormat.worldAgeHours()

    local currentRoot = rootFor(player)
    local transition = VisitSession.update(state, nextKey,
        nextKey ~= nil and currentRoot.buildings[nextKey] ~= nil)
    if transition.exited then
        finishEmotionalVisit(state, currentRoot, transition.exited, now)
        increment(currentRoot, "buildingExits")
        syncPlayer(player, currentRoot)
        notify("exited", player, nil)
    end
    if transition.entered then
        enterBuilding(player, state, building, now)
    elseif transition.resumed then
        local resumedMemory = currentRoot.buildings[nextKey]
        if resumedMemory then
            state.emotionalTracker = nil
            state.emotionalTriggeredThisVisit = false
            state.emotionalDangerThisVisit = false
            state.emotionalEnteredAt = now
            state.lastEmotionalSampleMs = nil
            state.nextEmotionalSampleMs = nil
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
        if room and ModOptions.enabled("rooms") then
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
    if not ModOptions.enabled("master") then return end
    local parent = container and container.getParent and container:getParent() or nil
    if parent and Runtime.importantKindForObject(parent) == ImportantMemory.Kind.WOOD_STOVE then
        Runtime.observeImportantObject(page.player, parent)
    end
    if not ModOptions.enabled("containers") then return end
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
    if not ModOptions.enabled("containers") then return end
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

function Runtime.installVehicleHooks()
    if Runtime.vehicleHooksInstalled then return end
    require "Vehicles/ISUI/ISVehicleMenu"
    if not ISVehicleMenu or not ISVehicleMenu.onMechanic then return end
    local originalOnMechanic = ISVehicleMenu.onMechanic
    ISVehicleMenu.onMechanic = function(player, vehicle)
        Runtime.observeVehicle(player, vehicle, "mechanics")
        return originalOnMechanic(player, vehicle)
    end
    Runtime.vehicleHooksInstalled = true
    print("[SurvivorMemory] B42 vehicle observation hooks installed")
end

function Runtime.currentMemory(playerNum)
    local player = getSpecificPlayer(playerNum or 0)
    if not player then return nil, nil end
    local root = rootFor(player)
    if not ModOptions.enabled("buildingMemory") then return nil, root end
    local state = stateFor(player)
    return root.buildings[state.buildingKey], root
end

function Runtime.setPlaceDesignation(playerNum, buildingKey, designation)
    playerNum = playerNum or 0
    if not ModOptions.enabled("placeDesignations")
            or not PlaceDesignation.isValid(designation) then return false end
    local player = getSpecificPlayer(playerNum)
    if not player then return false end
    local root = rootFor(player)
    local memory = root.buildings[buildingKey]
    if not memory or not MemoryStore.setPlaceDesignation(memory, designation) then return false end
    increment(root, "placeDesignationChanges")
    syncPlayer(player, root)
    if stateFor(player).buildingKey == buildingKey then
        notify("designation", player, memory)
    end
    return true
end

function Runtime.setCurrentPlaceDesignation(playerNum, designation)
    playerNum = playerNum or 0
    local memory = Runtime.currentMemory(playerNum)
    if not memory then return false end
    return Runtime.setPlaceDesignation(playerNum, memory.buildingKey, designation)
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

local function applyOptions()
    for playerNum = 0, 3 do
        local player = getSpecificPlayer(playerNum)
        if player then notify("exited", player, nil) end
        Runtime.resetPlayer(playerNum)
    end
end

ModOptions.addListener(applyOptions)

Events.OnPlayerUpdate.Add(Runtime.onPlayerUpdate)
Events.OnGameStart.Add(Runtime.installInventoryHooks)
Events.OnGameStart.Add(Runtime.installVehicleHooks)
Events.OnEnterVehicle.Add(Runtime.onEnterVehicle)
Events.OnExitVehicle.Add(Runtime.onExitVehicle)
Events.OnCreatePlayer.Add(function(playerNum) Runtime.resetPlayer(playerNum) end)
Events.LoadGridsquare.Add(Runtime.onLoadGridSquare)
Events.OnObjectAdded.Add(Runtime.onObjectAdded)
Events.OnObjectAboutToBeRemoved.Add(Runtime.onObjectAboutToBeRemoved)
Events.OnSeeNewRoom.Add(Runtime.onSeeNewRoom)

return Runtime
