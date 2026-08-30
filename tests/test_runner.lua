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
equal(rootData.schemaVersion, 1, "new schema version")
local memory = MemoryStore.enterBuilding(rootData, identity, 24)
equal(memory.firstVisited, 24, "first visit")
equal(memory.lastVisited, 24, "first lastVisited")
equal(memory.visitCount, 1, "first visit count")

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
equal(attached.schemaVersion, 1, "player modData migration")

equal(TimeFormat.age(100, 99), "IGUI_SM_Today", "human time today")
equal(TimeFormat.age(100, 75), "IGUI_SM_Yesterday", "human time yesterday")
equal(TimeFormat.age(200, 50), "IGUI_SM_DaysAgo:6", "human time days")
equal(TimeFormat.age(24 * 100, 0), "IGUI_SM_MonthsAgo:3", "human time months")
equal(TimeFormat.age(100, nil), "IGUI_SM_TimeUnknown", "human time missing")

local accepted = pcall(function() MemoryStore.migrate({ schemaVersion = 999 }) end)
equal(accepted, false, "unknown persistence version rejected")

local recoveredModData = { SurvivorMemory = { schemaVersion = 999, buildings = {} } }
local recovered = MemoryStore.forModData(recoveredModData)
equal(recovered.schemaVersion, 1, "future schema degrades to fresh store")
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

local characterA, characterB = {}, {}
local storeA = MemoryStore.forModData(characterA)
MemoryStore.enterBuilding(storeA, identity, 200)
local storeB = MemoryStore.forModData(characterB)
equal(storeB.buildings[identity.key], nil, "new character has no inherited memory")
truthy(storeA.buildings[identity.key] ~= nil, "original character retains memory")

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
