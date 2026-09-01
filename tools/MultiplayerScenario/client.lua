require "SurvivorMemory/Runtime"

local RunContext = require "PzModToolsMP/RunContext"
if not RunContext.current.active then return end

local role = RunContext.current.role
if role ~= "client-a" and role ~= "client-b" then return end

local Scenario = { phase = "WAIT_START", ticks = 0, finished = false }

local function log(message)
    print("[SurvivorMemory] MP role=" .. role .. " " .. message)
end

local function count(values)
    local total = 0
    for _ in pairs(values or {}) do total = total + 1 end
    return total
end

local function finish(status, diagnostics)
    if Scenario.finished then return end
    Scenario.finished = true
    Events.OnTick.Remove(Scenario.onTick)
    log("RESULT status=" .. status .. " diagnostics=" .. diagnostics)
    RunContext.result(status, diagnostics)
end

local function moveTo(player, square)
    player:setX(square:getX() + 0.5)
    player:setY(square:getY() + 0.5)
    player:setZ(square:getZ())
    player:setLastX(player:getX())
    player:setLastY(player:getY())
    player:setLastZ(player:getZ())
    player:setCurrent(square)
    player:setCurrentSquare(square)
end

-- Test-only fixture discovery. Production never enumerates a building remotely.
local function findFixture(player)
    local cell = getCell()
    local px, py = math.floor(player:getX()), math.floor(player:getY())
    local building, outside
    for radius = 0, 45 do
        for y = py - radius, py + radius do
            for x = px - radius, px + radius do
                local square = cell:getGridSquare(x, y, 0)
                if square then
                    if not building and square:getBuilding() then building = square:getBuilding() end
                    if not outside and not square:getBuilding() and square:getFloor() then outside = square end
                end
            end
        end
        if building and outside then break end
    end
    if not building or not outside then return nil end
    local roomSquare, container
    local rooms = building:getDef():getRooms()
    for index = 0, rooms:size() - 1 do
        local room = rooms:get(index):getIsoRoom()
        if room and not roomSquare then roomSquare = room:getFreeTile() or room:getRandomSquare() end
        if room then
            local squares = room:getSquares()
            for squareIndex = 0, squares:size() - 1 do
                local objects = squares:get(squareIndex):getObjects()
                for objectIndex = 0, objects:size() - 1 do
                    local object = objects:get(objectIndex)
                    if object:getContainerCount() > 0 then
                        container = object:getContainerByIndex(0)
                        break
                    end
                end
                if container then break end
            end
        end
        if roomSquare and container then break end
    end
    if not roomSquare then return nil end
    return {
        building = building,
        buildingKey = SurvivorMemory.BuildingIdentity.fromBuilding(building).key,
        outside = outside,
        room = roomSquare,
        container = container,
    }
end

function Scenario.onTick()
    if Scenario.finished then return end
    local ok, errorMessage = pcall(function()
        Scenario.ticks = Scenario.ticks + 1
        local player = getPlayer()
        if not player then return end

        if Scenario.phase == "SETUP" then
            Scenario.fixture = findFixture(player)
            if not Scenario.fixture then finish("FAIL", "fixture-not-found") return end
            local expected = role == "client-a" and "PzModToolsTestA" or "PzModToolsTestB"
            if tostring(player:getUsername()) ~= expected then
                finish("FAIL", "identity expected=" .. expected .. " actual=" .. tostring(player:getUsername()))
                return
            end
            moveTo(player, Scenario.fixture.outside)
            player:getModData().SurvivorMemory = nil
            SurvivorMemory.Runtime.resetPlayer(0)
            Scenario.phase, Scenario.ticks = "OUTSIDE_STABLE", 0
        elseif Scenario.phase == "OUTSIDE_STABLE" and Scenario.ticks >= 20 then
            local root = SurvivorMemory.MemoryStore.forModData(player:getModData())
            if count(root.buildings) ~= 0 then finish("FAIL", "baseline-not-empty") return end
            RunContext.signal("fixture-ready", "building-key-ready")
            Scenario.phase, Scenario.ticks = "WAIT_PEER", 0
        elseif Scenario.phase == "WAIT_PEER" then
            local peer = role == "client-a" and "from-client-b-fixture-ready" or "from-client-a-fixture-ready"
            if not RunContext.readSignal(peer) then return end
            if role == "client-a" then
                moveTo(player, Scenario.fixture.room)
                Scenario.phase, Scenario.ticks = "OBSERVE", 0
            else
                Scenario.phase, Scenario.ticks = "WAIT_A", 0
            end
        elseif Scenario.phase == "OBSERVE" and Scenario.ticks >= 35 then
            local memory, root = SurvivorMemory.Runtime.currentMemory(0)
            if not memory or memory.buildingKey ~= Scenario.fixture.buildingKey then
                finish("FAIL", "runtime-memory-not-created") return
            end
            if Scenario.fixture.container then
                SurvivorMemory.Runtime.inspectContainer({ player = 0 }, Scenario.fixture.container)
            end
            if not SurvivorMemory.Runtime.setCurrentPlaceDesignation(0,
                    SurvivorMemory.PlaceDesignation.OUTPOST) then
                finish("FAIL", "outpost-designation-failed") return
            end
            SurvivorMemory.EmotionalMemory.remember(memory, getGameTime():getWorldAgeHours())
            SurvivorMemory.ImportantMemory.observe(root,
                SurvivorMemory.ImportantMemory.Kind.GENERATOR, {
                    buildingKey = memory.buildingKey,
                    x = Scenario.fixture.room:getX(),
                    y = Scenario.fixture.room:getY(),
                    z = Scenario.fixture.room:getZ(),
                }, getGameTime():getWorldAgeHours())
            SurvivorMemory.VehicleMemory.observe(root, {
                sqlId = 7001,
                mechanicalId = 8101,
                scriptName = "Base.CarNormal",
                displayName = "Chevalier Dart",
                x = Scenario.fixture.outside:getX(),
                y = Scenario.fixture.outside:getY(),
                z = Scenario.fixture.outside:getZ(),
            }, getGameTime():getWorldAgeHours())
            player:transmitModData()
            local stats = SurvivorMemory.MemoryStore.stats(root, memory)
            if stats.roomsKnown < 1 then finish("FAIL", "room-not-observed") return end
            if Scenario.fixture.container and stats.containersInspected < 1 then
                finish("FAIL", "container-not-inspected") return
            end
            RunContext.signal("observation-complete", "runtime-memory-created")
            finish("PASS", "identity=" .. tostring(player:getUsername())
                .. " building=" .. memory.buildingKey
                .. " designation=" .. tostring(memory.placeDesignation)
                .. " emotional=" .. tostring(memory.emotionalMemory ~= nil)
                .. " important=" .. tostring(#SurvivorMemory.ImportantMemory.forBuilding(
                    root, memory.buildingKey))
                .. " vehicles=" .. tostring(#SurvivorMemory.VehicleMemory.all(root))
                .. " rooms=" .. tostring(stats.roomsKnown)
                .. " inspected=" .. tostring(stats.containersInspected))
        elseif Scenario.phase == "WAIT_A" and RunContext.readSignal("from-client-a-observation-complete") then
            Scenario.phase, Scenario.ticks = "ASSERT_ISOLATED", 0
        elseif Scenario.phase == "ASSERT_ISOLATED" and Scenario.ticks >= 20 then
            local root = SurvivorMemory.MemoryStore.forModData(player:getModData())
            local absent = root.buildings[Scenario.fixture.buildingKey] == nil
            local total = count(root.buildings)
            local importantTotal = count(root.importantMemories)
            local vehicleTotal = count(root.vehicleMemories)
            if not absent or total ~= 0 or importantTotal ~= 0 or vehicleTotal ~= 0 then
                finish("FAIL", "memory-leaked absent=" .. tostring(absent)
                    .. " buildings=" .. tostring(total) .. " important=" .. tostring(importantTotal)
                    .. " vehicles=" .. tostring(vehicleTotal))
                return
            end
            finish("PASS", "identity=" .. tostring(player:getUsername())
                .. " foreign-memory-absent=true buildings=0 important=0 vehicles=0")
        end

        if Scenario.ticks > 10800 then finish("FAIL", "scenario-timeout phase=" .. Scenario.phase) end
    end)
    if not ok then finish("FAIL", "lua-error=" .. tostring(errorMessage)) end
end

RunContext.wait("scenario-start", 240, function(ok, detail)
    if not ok then finish("FAIL", "scenario-start=" .. tostring(detail)) return end
    Scenario.phase, Scenario.ticks = "SETUP", 0
    Events.OnTick.Add(Scenario.onTick)
    log("START run=" .. RunContext.current.runId)
end)
