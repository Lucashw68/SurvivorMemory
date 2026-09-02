local script = arg[0]
local root = script:match("^(.*)/tests/test_runner%.lua$") or "."
package.path = table.concat({
    root .. "/42/media/lua/shared/?.lua",
    root .. "/42/media/lua/shared/?/?.lua",
    package.path,
}, ";")

local BuildingIdentity = require "SurvivorMemory/BuildingIdentity"
local ContainerIdentity = require "SurvivorMemory/ContainerIdentity"
local MemoryStore = require "SurvivorMemory/MemoryStore"
local VisitSession = require "SurvivorMemory/VisitSession"
local LocationName = require "SurvivorMemory/LocationName"
local StatusPresentation = require "SurvivorMemory/StatusPresentation"
local PlaceDesignation = require "SurvivorMemory/PlaceDesignation"
local EmotionalMemory = require "SurvivorMemory/EmotionalMemory"
local ImportantMemory = require "SurvivorMemory/ImportantMemory"
local VehicleMemory = require "SurvivorMemory/VehicleMemory"
local VisibleObservation = require "SurvivorMemory/VisibleObservation"
local Settings = require "SurvivorMemory/Settings"
function getText(key, value)
    if value == nil then return key end
    return key .. ":" .. tostring(value)
end
local TimeFormat = require "SurvivorMemory/TimeFormat"

local passed = 0

local function equal(actual, expected, label)
    if actual ~= expected then
        error(string.format("%s: expected %s, got %s", label, tostring(expected), tostring(actual)), 2)
    end
    passed = passed + 1
end

local function truthy(value, label)
    if not value then error(label .. ": expected truthy", 2) end
    passed = passed + 1
end

local function deepCopy(value)
    if type(value) ~= "table" then return value end
    local copy = {}
    for key, child in pairs(value) do copy[deepCopy(key)] = deepCopy(child) end
    return copy
end

local house = { x = 100, y = 200, x2 = 110, y2 = 212, minLevel = 0, maxLevel = 1, nativeId = "77" }
local sameHouse = { x = 100, y = 200, x2 = 110, y2 = 212, minLevel = 0, maxLevel = 1, nativeId = "999" }
local nextHouse = { x = 111, y = 200, x2 = 120, y2 = 212, minLevel = 0, maxLevel = 1 }
local identity = BuildingIdentity.fromFields(house)

equal(identity.key, BuildingIdentity.fromFields(sameHouse).key, "same building key ignores native runtime id")
truthy(identity.key ~= BuildingIdentity.fromFields(nextHouse).key, "different building key")
equal(BuildingIdentity.fromFields(deepCopy(house)).key, identity.key, "building identity serialization")

local rootData = MemoryStore.migrate(nil)
equal(rootData.schemaVersion, 5, "new schema version")
local memory = MemoryStore.enterBuilding(rootData, identity, 24)
equal(memory.firstVisited, 24, "first visit")
equal(memory.lastVisited, 24, "first lastVisited")
equal(memory.visitCount, 1, "first visit count")
equal(memory.placeDesignation, PlaceDesignation.NONE, "new building has no personal designation")

MemoryStore.enterBuilding(rootData, identity, 99.5)
equal(memory.firstVisited, 24, "first visit remains stable")
equal(memory.lastVisited, 99.5, "revisit lastVisited")
equal(memory.visitCount, 2, "revisit count")

local roomA = BuildingIdentity.roomFromFields(identity.key, {
    x = 100, y = 200, x2 = 104, y2 = 204, z = 0, name = "kitchen",
})
truthy(MemoryStore.discoverRoom(memory, roomA, 100), "first room discovery")
equal(MemoryStore.discoverRoom(memory, roomA, 101), false, "duplicate room discovery")
equal(MemoryStore.stats(rootData, memory).roomsKnown, 1, "unique room count")

local containerA = ContainerIdentity.fromFields({
    x = 101, y = 201, z = 0, objectIndex = 3, containerIndex = 0,
    spriteName = "fixtures_counters_01_16", containerType = "counter",
})
local containerB = ContainerIdentity.fromFields({
    x = 102, y = 201, z = 0, objectIndex = 2, containerIndex = 0,
    spriteName = "fixtures_shelves_01_4", containerType = "shelves",
})
equal(containerA, ContainerIdentity.fromFields({
    x = 101, y = 201, z = 0, objectIndex = 3, containerIndex = 0,
    spriteName = "fixtures_counters_01_16", containerType = "counter",
}), "same container key")
truthy(containerA ~= containerB, "different container key")
truthy(MemoryStore.observeContainer(memory, containerA, 100), "observe first container")
equal(memory.status, "VISITED", "known but uninspected remains visited")
truthy(MemoryStore.observeContainer(memory, containerB, 100), "observe second container")
truthy(MemoryStore.inspectContainer(memory, containerA, 101), "inspect first container")
equal(memory.status, "PARTIALLY_SEARCHED", "partial status")
equal(MemoryStore.inspectContainer(memory, containerA, 102), false, "repeat inspection")
equal(memory.containersInspected[containerA], 102, "repeat refreshes timestamp")
truthy(MemoryStore.inspectContainer(memory, containerB, 103), "inspect second container")
equal(memory.status, "SEARCHED", "searched status")

local containerC = ContainerIdentity.fromFields({
    x = 103, y = 201, z = 0, objectIndex = 1, containerIndex = 0,
    spriteName = "fixtures_counters_01_17", containerType = "counter",
})
MemoryStore.observeContainer(memory, containerC, 104)
equal(memory.status, "PARTIALLY_SEARCHED", "new observation downgrades completion")

local serialized = deepCopy(rootData)
local reloaded = MemoryStore.migrate(serialized)
equal(reloaded.schemaVersion, MemoryStore.SCHEMA_VERSION, "reload schema")
equal(reloaded.buildings[identity.key].visitCount, 2, "reload visit count")
equal(reloaded.buildings[identity.key].containersInspected[containerB], 103, "reload container observation")

local otherMemory = MemoryStore.enterBuilding(rootData, BuildingIdentity.fromFields(nextHouse), 110)
equal(MemoryStore.stats(rootData, otherMemory).containersInspected, 0, "container association stays in building")
equal(MemoryStore.stats(rootData, memory).containersInspected, 2, "source building retains inspections")

local modData = {}
local attached = MemoryStore.forModData(modData)
truthy(attached == modData.SurvivorMemory, "player modData attachment")
equal(attached.schemaVersion, 5, "player modData migration")

equal(TimeFormat.age(100, 99), "IGUI_SM_Today", "human time today")
equal(TimeFormat.age(100, 75), "IGUI_SM_Yesterday", "human time yesterday")
equal(TimeFormat.age(200, 50), "IGUI_SM_DaysAgo:6", "human time days")
equal(TimeFormat.age(24 * 100, 0), "IGUI_SM_MonthsAgo:3", "human time months")
equal(TimeFormat.age(100, nil), "IGUI_SM_TimeUnknown", "human time missing")

local accepted = pcall(function() MemoryStore.migrate({ schemaVersion = 999 }) end)
equal(accepted, false, "unknown persistence version rejected")

local recoveredModData = { SurvivorMemory = { schemaVersion = 999, buildings = {} } }
local recovered = MemoryStore.forModData(recoveredModData)
equal(recovered.schemaVersion, 5, "future schema degrades to fresh store")
equal(recoveredModData.SurvivorMemoryRecovery.schemaVersion, 999, "future schema recovery marker")

local partial = MemoryStore.migrate({
    schemaVersion = 1,
    buildings = {
        valid = { lastVisited = 12, roomsKnown = "bad", containersKnown = {}, containersInspected = {} },
        invalid = { roomsKnown = {} },
    },
    debug = "bad",
})
equal(partial.buildings.valid.firstVisited, 12, "partial first timestamp repaired")
equal(type(partial.buildings.valid.roomsKnown), "table", "partial room set repaired")
equal(partial.buildings.invalid, nil, "unrecoverable building removed")
equal(type(partial.debug), "table", "corrupted debug counters repaired")
equal(partial.schemaVersion, 5, "v1 store migrates to current schema")
equal(partial.buildings.valid.placeDesignation, PlaceDesignation.NONE, "v1 building migrates to no designation")

local corruptDesignation = MemoryStore.migrate({
    schemaVersion = 3,
    buildings = {
        invalidPlace = { firstVisited = 1, lastVisited = 1, placeDesignation = "SAFEHOUSE" },
    },
})
equal(corruptDesignation.buildings.invalidPlace.placeDesignation, PlaceDesignation.NONE,
    "invalid personal designation degrades safely")

local severeSignal = {
    panic = 90, health = 45, pain = 60, bleeding = 1,
    veryCloseZombies = 2, chasingZombies = 4, targeted = true,
}
equal(EmotionalMemory.isSevere(severeSignal), true, "combined severe danger qualifies")
equal(EmotionalMemory.isSevere({ panic = 100, health = 20 }), false,
    "panic and injury without real danger do not qualify")
equal(EmotionalMemory.isSevere({ panic = 100, health = 100, veryCloseZombies = 5 }), false,
    "panic and zombies without vulnerability do not qualify")
local tracker = nil
local triggered = false
for _ = 1, 14 do tracker, triggered = EmotionalMemory.updateTracker(tracker, severeSignal, 1) end
equal(triggered, false, "severe instant does not create memory")
tracker, triggered = EmotionalMemory.updateTracker(tracker, severeSignal, 1)
equal(triggered, true, "sustained severe event creates memory")
tracker = EmotionalMemory.updateTracker(tracker, severeSignal, 2)
tracker = EmotionalMemory.updateTracker(tracker, {}, 3)
tracker = EmotionalMemory.updateTracker(tracker, {}, 1)
equal(tracker.dangerSeconds, 0, "quiet interval resets danger duration")

truthy(EmotionalMemory.remember(memory, 240), "emotional observation stored")
equal(memory.emotionalMemory.observedAt, 240, "emotional timestamp stored")
local freshReaction = EmotionalMemory.reaction(memory.emotionalMemory, 264)
equal(freshReaction.panic, 12, "fresh emotional reaction uses modest vanilla panic")
equal(freshReaction.stress, 0.05, "fresh emotional reaction uses modest vanilla stress")
truthy(EmotionalMemory.recordReaction(memory.emotionalMemory, 264), "reaction timestamp stored")
equal(EmotionalMemory.reaction(memory.emotionalMemory, 265), nil, "reaction cooldown prevents continuous effect")
local agedReaction = EmotionalMemory.reaction({ observedAt = 0, safeReturns = 0 }, 24 * 45)
equal(agedReaction.panic, 4, "old emotional memory naturally weakens")
equal(EmotionalMemory.reaction({ observedAt = 0, safeReturns = 0 }, 24 * 100), nil,
    "very old emotional memory has no reaction")
memory.emotionalMemory.lastReactionAt = nil
truthy(EmotionalMemory.recordSafeReturn(memory), "first safe return habituates")
truthy(EmotionalMemory.recordSafeReturn(memory), "second safe return habituates")
truthy(EmotionalMemory.recordSafeReturn(memory), "third safe return forgets")
equal(memory.emotionalMemory, nil, "habituation removes obsolete emotional memory")

local migratedEmotion = MemoryStore.migrate({
    schemaVersion = 2,
    buildings = { emotional = { firstVisited = 1, lastVisited = 2,
        emotionalMemory = { observedAt = 1, safeReturns = 1 } } },
})
equal(migratedEmotion.schemaVersion, 5, "v2 store migrates through to v5")
equal(migratedEmotion.buildings.emotional.emotionalMemory.safeReturns, 1,
    "valid emotional memory survives migration")
local corruptEmotion = MemoryStore.migrate({
    schemaVersion = 3,
    buildings = { emotional = { firstVisited = 1, lastVisited = 2,
        emotionalMemory = { observedAt = "bad" } } },
})
equal(corruptEmotion.buildings.emotional.emotionalMemory, nil,
    "corrupt emotional memory degrades safely")

equal(ImportantMemory.kindFromFields({ objectType = "IsoGenerator" }), "GENERATOR",
    "generator classification is explicit")
equal(ImportantMemory.kindFromFields({ hasFuelAmount = true }), "GAS_PUMP",
    "fuelAmount sprite property classifies gas pump")
equal(ImportantMemory.kindFromFields({ containerType = "woodstove" }), "WOOD_STOVE",
    "woodstove container classification is explicit")
equal(ImportantMemory.kindFromFields({ containerType = "counter" }), nil,
    "ordinary loot is not worth remembering")
local buildingPlace = ImportantMemory.placeKey(identity.key, 101, 201, 0)
equal(buildingPlace, "building:" .. identity.key, "building aggregates important observations")
equal(ImportantMemory.placeKey(nil, 109, 201, 0), "area:10:20:0",
    "outdoor observations use deterministic ten-tile place")
local createdGenerator, generatorMemory = ImportantMemory.observe(rootData, "GENERATOR", {
    buildingKey = identity.key, x = 101, y = 201, z = 0,
}, 300)
equal(createdGenerator, true, "first important observation creates memory")
equal(generatorMemory.observedAt, 300, "important observation stores in-game time")
local repeatedGenerator, refreshedGenerator = ImportantMemory.observe(rootData, "GENERATOR", {
    buildingKey = identity.key, x = 103, y = 202, z = 0,
}, 324)
equal(repeatedGenerator, false, "same kind in same building stays aggregated")
equal(refreshedGenerator.observedAt, 324, "re-observation refreshes last seen time")
equal(#ImportantMemory.forBuilding(rootData, identity.key), 1,
    "building exposes one aggregated important memory")
local createdPump = ImportantMemory.observe(rootData, "GAS_PUMP", { x = 209, y = 301, z = 0 }, 350)
equal(createdPump, true, "outdoor gas pump creates personal memory")
equal(#ImportantMemory.outdoor(rootData), 1, "outdoor important memory is available to map overlay")
local importantReload = MemoryStore.migrate(deepCopy(rootData))
equal(#ImportantMemory.forBuilding(importantReload, identity.key), 1,
    "important memory survives serialization")
local migratedImportant = MemoryStore.migrate({ schemaVersion = 3, buildings = {}, debug = {} })
equal(migratedImportant.schemaVersion, 5, "v3 store migrates through to v5")
equal(type(migratedImportant.importantMemories), "table", "v4 migration creates important memory collection")
local corruptImportant = MemoryStore.migrate({
    schemaVersion = 4, buildings = {}, debug = {},
    importantMemories = { bad = { kind = "NAILS", observedAt = 1, x = 1, y = 1, z = 0 } },
})
equal(corruptImportant.importantMemories.bad, nil,
    "unsupported or corrupt important memory degrades safely")

local visibleCandidates = { generator = true, pump = true }
local visibleNow = { generator = true }
local visibleSet, newlyVisible, checked = VisibleObservation.reconcile(nil, visibleCandidates,
    function(candidate) return visibleNow[candidate] == true end)
equal(checked, 2, "visible observer checks only registered candidates")
equal(#newlyVisible, 1, "first visible transition is reported")
equal(newlyVisible[1], "generator", "visible transition identifies candidate")
visibleSet, newlyVisible = VisibleObservation.reconcile(visibleSet, visibleCandidates,
    function(candidate) return visibleNow[candidate] == true end)
equal(#newlyVisible, 0, "continuously visible candidate is not repeated")
visibleNow.generator = nil
visibleSet = select(1, VisibleObservation.reconcile(visibleSet, visibleCandidates,
    function(candidate) return visibleNow[candidate] == true end))
visibleNow.generator = true
visibleSet, newlyVisible = VisibleObservation.reconcile(visibleSet, visibleCandidates,
    function(candidate) return visibleNow[candidate] == true end)
equal(#newlyVisible, 1, "candidate is remembered again after leaving and re-entering view")
equal(visibleSet.pump, nil, "never-visible candidate stays unknown")
equal(VisibleObservation.isScreenPointVisible(100, 80, 0, 0, 200, 160), true,
    "visible observation accepts a point inside the player viewport")
equal(VisibleObservation.isScreenPointVisible(201, 80, 0, 0, 200, 160), false,
    "line-of-sight object outside the viewport is not observed")
equal(VisibleObservation.isScreenPointVisible(100, -1, 0, 0, 200, 160), false,
    "object above the viewport is not observed")
equal(VisibleObservation.isScreenPointVisible(100, 80, 0, 0, 0, 160), false,
    "invalid viewport degrades without observing")

equal(Settings.enabled(nil, "master"), true, "mod options default to enabled")
equal(Settings.withDefault(false, true), false, "native false option is never replaced by default true")
equal(Settings.withDefault(nil, true), true, "missing native option uses its default")
equal(Settings.enabled(nil, "buildingMemory"), true, "building memory defaults to enabled")
local disabledMod = { enabled = false }
equal(Settings.enabled(disabledMod, "buildingMemory"), false, "master switch disables building memory")
equal(Settings.enabled(disabledMod, "importantMemory"), false, "master switch disables important memory")
equal(Settings.enabled(disabledMod, "vehicleMemory"), false, "master switch disables vehicle memory")
equal(Settings.enabled(disabledMod, "worldMap"), false, "master switch disables map overlay")
local noBuildings = { buildingMemoryEnabled = false }
equal(Settings.enabled(noBuildings, "rooms"), false, "rooms depend on building memory")
equal(Settings.enabled(noBuildings, "containers"), false, "containers depend on building memory")
equal(Settings.enabled(noBuildings, "places"), false, "places depend on building memory")
equal(Settings.enabled(noBuildings, "emotionalMemory"), false, "emotional memory depends on buildings")
equal(Settings.enabled(noBuildings, "importantMemory"), true, "important memory remains independent")
local selectedThings = { rememberGenerators = false, rememberGasPumps = true,
    rememberWoodStoves = false }
equal(Settings.enabled(selectedThings, "generatorMemory"), false, "generator memory can be disabled")
equal(Settings.enabled(selectedThings, "gasPumpMemory"), true, "gas-pump memory can remain enabled")
equal(Settings.enabled(selectedThings, "woodStoveMemory"), false, "wood-stove memory can be disabled")
equal(Settings.reactionMultiplier({ emotionalReactionStrength = 1 }), 0.5,
    "reduced emotional reaction uses half strength")
equal(Settings.reactionMultiplier({ emotionalReactionStrength = 2 }), 1,
    "standard emotional reaction preserves strength")
equal(Settings.markerScale({ markerSizePercent = 50 }), 0.75, "map marker scale has safe minimum")
equal(Settings.markerScale({ markerSizePercent = 125 }), 1.25, "map marker scale uses percentage")
equal(Settings.markerScale({ markerSizePercent = 200 }), 1.5, "map marker scale has safe maximum")

equal(VehicleMemory.fuelState(0, 40), VehicleMemory.FuelState.EMPTY,
    "empty vehicle tank is remembered qualitatively")
equal(VehicleMemory.fuelState(4, 40), VehicleMemory.FuelState.LOW,
    "fuel below vanilla low-gauge threshold is remembered as low")
equal(VehicleMemory.fuelState(20, 40), VehicleMemory.FuelState.SOME,
    "middle fuel level is remembered without an exact percentage")
equal(VehicleMemory.fuelState(30, 40), VehicleMemory.FuelState.FULL,
    "three-quarter tank uses the broad full memory state")
equal(VehicleMemory.fuelState(1, 0), nil, "invalid fuel capacity reveals nothing")
equal(VehicleMemory.engineCondition(0), VehicleMemory.EngineCondition.FAILED,
    "failed engine condition is remembered")
equal(VehicleMemory.engineCondition(20), VehicleMemory.EngineCondition.POOR,
    "badly damaged engine is remembered broadly")
equal(VehicleMemory.engineCondition(70), VehicleMemory.EngineCondition.USABLE,
    "usable engine avoids an exact condition value")

local sqlVehicle = VehicleMemory.identityFromFields({
    sqlId = 81, mechanicalId = 12004, scriptName = "Base.CarNormal",
})
equal(sqlVehicle.key, "vehicle:sql:81", "vehicle SQL identity is stable primary key")
local mechanicalVehicle = VehicleMemory.identityFromFields({
    sqlId = -1, mechanicalId = 12004, scriptName = "Base.CarNormal",
})
equal(mechanicalVehicle.key, "vehicle:mechanical:14:Base.CarNormal:12004",
    "vehicle mechanical fallback is deterministic")
equal(VehicleMemory.identityFromFields({ sqlId = -1, mechanicalId = 12004 }), nil,
    "vehicle identity refuses ambiguous fallback")
local vehicleCreated, vehicleObservation = VehicleMemory.observe(rootData, {
    sqlId = -1, mechanicalId = 12004, scriptName = "Base.CarNormal",
    displayName = "Chevalier Dart", x = 300, y = 401, z = 0,
    fuelState = VehicleMemory.FuelState.LOW,
    engineActivity = VehicleMemory.EngineActivity.OFF,
    engineCondition = VehicleMemory.EngineCondition.POOR,
}, 500)
equal(vehicleCreated, true, "first significant vehicle observation creates memory")
equal(vehicleObservation.observedAt, 500, "vehicle stores deterministic in-game time")
equal(vehicleObservation.fuelState, VehicleMemory.FuelState.LOW,
    "vehicle stores broad observed fuel state")
equal(vehicleObservation.engineCondition, VehicleMemory.EngineCondition.POOR,
    "mechanics stores broad observed engine condition")
local vehicleRefreshed, movedVehicle = VehicleMemory.observe(rootData, {
    sqlId = -1, mechanicalId = 12004, scriptName = "Base.CarNormal",
    displayName = "Chevalier Dart", x = 350, y = 451, z = 0,
    engineActivity = VehicleMemory.EngineActivity.RUNNING,
}, 524)
equal(vehicleRefreshed, false, "repeat vehicle observation updates one memory")
equal(movedVehicle.x, 350, "vehicle remembers latest observed position only")
equal(movedVehicle.observedAt, 524, "vehicle last-seen time refreshes on observation")
equal(movedVehicle.fuelState, VehicleMemory.FuelState.LOW,
    "less detailed revisit preserves last legitimate fuel memory")
equal(VehicleMemory.engineSummary(movedVehicle), "RUNNING",
    "running engine takes precedence in the remembered summary")
equal(#VehicleMemory.all(rootData), 1, "vehicle memory has no route history")
local promotedVehicle, promotedObservation, replacedKey = VehicleMemory.observe(rootData, {
    sqlId = 81, mechanicalId = 12004, scriptName = "Base.CarNormal",
    displayName = "Chevalier Dart", x = 350, y = 451, z = 0,
}, 525)
equal(promotedVehicle, false, "SQL assignment promotes existing fallback without duplicate")
equal(replacedKey, mechanicalVehicle.key, "fallback vehicle key is replaced after SQL assignment")
equal(promotedObservation.vehicleKey, sqlVehicle.key, "promoted vehicle uses persistent SQL key")
equal(promotedObservation.engineCondition, VehicleMemory.EngineCondition.POOR,
    "identity promotion preserves mechanical observations")
equal(#VehicleMemory.all(rootData), 1, "identity promotion keeps one vehicle memory")
local vehicleReload = MemoryStore.migrate(deepCopy(rootData))
equal(vehicleReload.vehicleMemories[sqlVehicle.key].observedAt, 525,
    "vehicle memory survives serialization")
equal(vehicleReload.vehicleMemories[sqlVehicle.key].fuelState, VehicleMemory.FuelState.LOW,
    "qualitative vehicle details survive serialization")
local sanitizedVehicleDetail = VehicleMemory.sanitize("vehicle:sql:82", {
    sqlId = 82, scriptName = "Base.CarNormal", x = 1, y = 2, z = 0, observedAt = 3,
    fuelState = "EXACT_PERCENTAGE", engineCondition = "PERFECT",
})
equal(sanitizedVehicleDetail.fuelState, nil, "unknown fuel state is discarded safely")
equal(sanitizedVehicleDetail.engineCondition, nil, "unknown engine state is discarded safely")
local migratedVehicles = MemoryStore.migrate({ schemaVersion = 4, buildings = {}, debug = {} })
equal(migratedVehicles.schemaVersion, 5, "v4 store migrates to v5")
equal(type(migratedVehicles.vehicleMemories), "table", "v5 migration creates vehicle collection")
local corruptVehicles = MemoryStore.migrate({
    schemaVersion = 5, buildings = {}, debug = {}, importantMemories = {},
    vehicleMemories = { bad = { sqlId = "x", observedAt = 1, x = 1, y = 1, z = 0 } },
})
equal(corruptVehicles.vehicleMemories.bad, nil, "corrupt vehicle memory degrades safely")

local statusBeforeDesignation = memory.status
truthy(MemoryStore.setPlaceDesignation(memory, PlaceDesignation.HOME), "building marked home")
equal(memory.placeDesignation, PlaceDesignation.HOME, "home designation stored")
equal(memory.status, statusBeforeDesignation, "designation does not change exploration status")
equal(MemoryStore.setPlaceDesignation(memory, PlaceDesignation.HOME), false, "duplicate home designation ignored")
equal(MemoryStore.setPlaceDesignation(memory, "SAFEHOUSE"), false, "invalid designation rejected")
truthy(MemoryStore.setPlaceDesignation(memory, PlaceDesignation.OUTPOST), "home changed to outpost")
truthy(MemoryStore.setPlaceDesignation(memory, PlaceDesignation.NONE), "personal designation cleared")
equal(PlaceDesignation.shouldShowIndicator("VISITED", PlaceDesignation.HOME), true, "home visited indicator visible")
equal(PlaceDesignation.shouldShowIndicator("PARTIALLY_SEARCHED", PlaceDesignation.OUTPOST), true, "outpost partial indicator visible")
equal(PlaceDesignation.shouldShowIndicator("SEARCHED", PlaceDesignation.NONE), true, "normal searched indicator visible")
equal(PlaceDesignation.shouldShowIndicator("SEARCHED", PlaceDesignation.HOME), false, "searched home indicator hidden")
equal(PlaceDesignation.shouldShowIndicator("SEARCHED", PlaceDesignation.OUTPOST), false, "searched outpost indicator hidden")

MemoryStore.setPlaceDesignation(memory, PlaceDesignation.HOME)
local designationReload = MemoryStore.migrate(deepCopy(rootData))
equal(designationReload.buildings[identity.key].placeDesignation, PlaceDesignation.HOME, "designation survives serialization")
memory = rootData.buildings[identity.key]

local characterA, characterB = {}, {}
local storeA = MemoryStore.forModData(characterA)
local characterAMemory = MemoryStore.enterBuilding(storeA, identity, 200)
MemoryStore.setPlaceDesignation(characterAMemory, PlaceDesignation.OUTPOST)
local storeB = MemoryStore.forModData(characterB)
equal(storeB.buildings[identity.key], nil, "new character has no inherited memory")
truthy(storeA.buildings[identity.key] ~= nil, "original character retains memory")
equal(storeB.buildings[identity.key], nil, "personal designation is not inherited")
equal(next(storeB.importantMemories), nil, "important memories are not inherited")
equal(next(storeB.vehicleMemories), nil, "vehicle memories are not inherited")

local session = VisitSession.new()
local firstEntry = VisitSession.update(session, identity.key, false)
equal(firstEntry.entered, identity.key, "session first entry")
local sameSquare = VisitSession.update(session, identity.key, true)
equal(sameSquare.entered, nil, "session no duplicate entry")
local exit = VisitSession.update(session, nil, false)
equal(exit.exited, identity.key, "session exit")
local rapidReentry = VisitSession.update(session, identity.key, true)
equal(rapidReentry.entered, identity.key, "session rapid reentry")

local reloadSession = VisitSession.new()
local resumed = VisitSession.update(reloadSession, identity.key, true)
equal(resumed.resumed, true, "save reload resumes active visit")
equal(resumed.entered, nil, "save reload does not increment visit")

local teleported = VisitSession.update(reloadSession, BuildingIdentity.fromFields(nextHouse).key, false)
equal(teleported.exited, identity.key, "teleport exits old building")
equal(teleported.entered, BuildingIdentity.fromFields(nextHouse).key, "teleport enters new building")

truthy(MemoryStore.estimateSerializedBytes(rootData) > 0, "serialized size estimate")

equal(LocationName.kindFromRoomName("bedroom"), "HOUSE", "bedroom identifies house")
equal(LocationName.kindFromRoomName("policestorage"), "POLICE", "police room identifies station")
equal(LocationName.kindFromRoomName("unknown-room"), nil, "unknown room stays generic")
equal(LocationName.choose("HOUSE", "POLICE"), "POLICE", "specific observed location upgrades generic")
equal(LocationName.choose("POLICE", "HOUSE"), "POLICE", "generic room cannot downgrade specific location")
equal(LocationName.choose("HOUSE", "GARAGE"), "HOUSE", "house is not renamed after garage visit")
equal(StatusPresentation.color("VISITED").r, 0.82, "visited indicator is red")
equal(StatusPresentation.color("SEARCHED").g, 0.72, "searched indicator is green")
equal(StatusPresentation.needsRefresh("VISITED", "VISITED"), false, "matching indicator status stays current")
equal(StatusPresentation.needsRefresh("PARTIALLY_SEARCHED", "SEARCHED"), true, "changed indicator status refreshes")

memory.locationKind = "GROCERY"
rootData.revision = 42
local locationReload = MemoryStore.migrate(deepCopy(rootData))
equal(locationReload.buildings[identity.key].locationKind, "GROCERY", "location kind persists")
equal(locationReload.revision, 42, "overlay revision persists")

local corruptLocation = MemoryStore.migrate({
    schemaVersion = 1, revision = "bad", debug = {},
    buildings = { badLocation = { firstVisited = 1, lastVisited = 1, locationKind = "SECRET_LAB" } },
})
equal(corruptLocation.buildings.badLocation.locationKind, "BUILDING", "invalid location kind degrades safely")
equal(corruptLocation.revision, 0, "invalid overlay revision repaired")

print(string.format("PASS: %d deterministic Survivor Memory assertions", passed))
