require "SurvivorMemory/Runtime"
require "SurvivorMemory/MemoryPanel"

debugScenarios = debugScenarios or {}
if SM_SMOKE_MODE ~= true then return end

local Runner = { tick = 0, phase = 0, failures = {} }

local function log(message) print("[SurvivorMemory] SMOKE " .. message) end
local function check(condition, name, detail)
    if condition then
        log("CHECK PASS name=" .. name .. (detail and " " .. detail or ""))
    else
        table.insert(Runner.failures, name)
        log("CHECK FAIL name=" .. name .. (detail and " " .. detail or ""))
    end
end

local function moveTo(player, square)
    player:setX(square:getX() + 0.5); player:setY(square:getY() + 0.5); player:setZ(square:getZ())
    player:setLastX(player:getX()); player:setLastY(player:getY()); player:setLastZ(player:getZ())
    player:setCurrent(square); player:setCurrentSquare(square)
end

-- This scan exists only in the isolated test fixture. Production code never enumerates a building.
local function findFixture(player)
    local cell, px, py = getCell(), math.floor(player:getX()), math.floor(player:getY())
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
    if not building then return nil end
    local rooms, containers = {}, {}
    local roomDefs = building:getDef():getRooms()
    for i = 0, roomDefs:size() - 1 do
        local room = roomDefs:get(i):getIsoRoom()
        if room then
        local square = room:getFreeTile() or room:getRandomSquare()
        if square then table.insert(rooms, square) end
        local values = room:getContainer()
        for j = 0, values:size() - 1 do table.insert(containers, values:get(j)) end
        local squares = room:getSquares()
        for j = 0, squares:size() - 1 do
            local objects = squares:get(j):getObjects()
            for k = 0, objects:size() - 1 do
                local object = objects:get(k)
                for n = 0, object:getContainerCount() - 1 do
                    table.insert(containers, object:getContainerByIndex(n))
                end
            end
        end
        end
    end
    return { building = building, outside = outside, rooms = rooms, containers = containers }
end

local function finish()
    local snapshot = SurvivorMemory.Runtime.debugSnapshot(0)
    if snapshot then
        log(string.format("METRICS bytes=%d buildings=%d playerUpdates=%d squareTransitions=%d entries=%s exits=%s rooms=%s containers=%s writes=%s",
            snapshot.estimatedBytes, SurvivorMemory.MemoryStore.stats(snapshot.root, snapshot.memory).buildings,
            snapshot.runtimeCounters.playerUpdates, snapshot.runtimeCounters.squareTransitions,
            tostring(snapshot.root.debug.buildingEntries or 0), tostring(snapshot.root.debug.buildingExits or 0),
            tostring(snapshot.root.debug.roomsDiscovered or 0), tostring(snapshot.root.debug.containersInspected or 0),
            tostring(snapshot.root.debug.modDataWrites or 0)))
    end
    log("RESULT status=" .. (#Runner.failures == 0 and "PASS" or "FAIL")
        .. " failures=" .. table.concat(Runner.failures, ","))
    getCore():quitToDesktop()
end

local function onTick()
    Runner.tick = Runner.tick + 1
    local player = getPlayer()
    if not player then return end
    if Runner.phase == 0 and Runner.tick > 150 then
        check(SurvivorMemory.UICompat ~= nil, "ui_compat_loaded")
        check(SurvivorMemory.UICompat and SurvivorMemory.UICompat.neatAvailable == SM_EXPECT_NEATUI,
            "ui_backend_expected", "neat=" .. tostring(SurvivorMemory.UICompat and SurvivorMemory.UICompat.neatAvailable))
        Runner.fixture = findFixture(player)
        check(Runner.fixture ~= nil, "vanilla_building_fixture")
        if not Runner.fixture then finish() return end
        check(#Runner.fixture.rooms >= 2, "fixture_two_rooms", "count=" .. #Runner.fixture.rooms)
        check(#Runner.fixture.containers >= 2, "fixture_two_containers", "count=" .. #Runner.fixture.containers)
        moveTo(player, Runner.fixture.outside)
        player:getModData().SurvivorMemory = nil
        SurvivorMemory.Runtime.resetPlayer(0)
        Runner.phase, Runner.tick = 1, 0
    elseif Runner.phase == 1 and Runner.tick > 20 then
        moveTo(player, Runner.fixture.rooms[1]); Runner.phase, Runner.tick = 2, 0
    elseif Runner.phase == 2 and Runner.tick > 25 then
        local memory = SurvivorMemory.Runtime.currentMemory(0)
        check(memory ~= nil, "memory_created_on_entry")
        if not memory then finish() return end
        Runner.firstVisited = memory.firstVisited
        check(memory.visitCount == 1, "first_visit_count", "value=" .. tostring(memory.visitCount))
        check(memory.locationKind ~= "BUILDING", "observed_location_kind", "value=" .. tostring(memory.locationKind))
        local indicator = SurvivorMemory.MemoryStatusIndicator and SurvivorMemory.MemoryStatusIndicator.currentButton(0)
        check(indicator and indicator:isVisible(), "memory_status_indicator_visible")
        if Runner.fixture.rooms[2] then moveTo(player, Runner.fixture.rooms[2]) end
        Runner.phase, Runner.tick = 3, 0
    elseif Runner.phase == 3 and Runner.tick > 25 then
        local page = { player = 0 }
        if Runner.fixture.containers[1] then SurvivorMemory.Runtime.inspectContainer(page, Runner.fixture.containers[1]) end
        if Runner.fixture.containers[2] then SurvivorMemory.Runtime.inspectContainer(page, Runner.fixture.containers[2]) end
        local memory = SurvivorMemory.Runtime.currentMemory(0)
        local stats = SurvivorMemory.MemoryStore.stats(nil, memory)
        check(stats.roomsKnown >= math.min(2, #Runner.fixture.rooms), "rooms_unique", "count=" .. stats.roomsKnown)
        check(stats.containersInspected >= math.min(2, #Runner.fixture.containers), "containers_inspected", "count=" .. stats.containersInspected)
        SurvivorMemory.MemoryPanel.open(0); Runner.phase, Runner.tick = 4, 0
    elseif Runner.phase == 4 and Runner.tick > 45 then
        local ok, err = pcall(function() getCore():TakeFullScreenshot("survivor-memory-panel.png") end)
        check(ok, "memory_panel_screenshot", "error=" .. tostring(err))
        SurvivorMemory.MemoryPanel.open(0)
        getCore():setOptionMapViewPause(false)
        ISWorldMap.ShowWorldMap(0, Runner.fixture.rooms[1]:getX(), Runner.fixture.rooms[1]:getY(), 18)
        Runner.phase, Runner.tick = 45, 0
    elseif Runner.phase == 45 and Runner.tick > 60 then
        check(ISWorldMap.instance ~= nil, "world_map_opened")
        check(ISWorldMap.instance and ISWorldMap.instance.smMemoryToggle ~= nil, "world_map_overlay_toggle")
        local ok, err = pcall(function() getCore():TakeFullScreenshot("survivor-memory-world-map.png") end)
        check(ok, "world_map_overlay_screenshot", "error=" .. tostring(err))
        if ISWorldMap.instance then ISWorldMap.instance:close() end
        moveTo(player, Runner.fixture.outside)
        Runner.ageBeforeWait = getGameTime():getWorldAgeHours()
        getGameTime():setMinutesPerDay(1); setGameSpeed(3)
        Runner.phase, Runner.tick = 5, 0
    elseif Runner.phase == 5 and getGameTime():getWorldAgeHours() >= Runner.ageBeforeWait + 6 then
        setGameSpeed(1)
        moveTo(player, Runner.fixture.rooms[1]); Runner.phase, Runner.tick = 6, 0
    elseif Runner.phase == 6 and Runner.tick > 25 then
        local memory = SurvivorMemory.Runtime.currentMemory(0)
        local stats = SurvivorMemory.MemoryStore.stats(nil, memory)
        check(memory.firstVisited == Runner.firstVisited, "first_visited_unchanged")
        check(memory.lastVisited >= Runner.firstVisited + 5, "last_visited_updated")
        check(memory.visitCount == 2, "revisit_count_once", "value=" .. tostring(memory.visitCount))
        check(stats.roomsKnown == math.min(2, #Runner.fixture.rooms), "rooms_not_duplicated", "count=" .. stats.roomsKnown)
        check(stats.containersInspected == math.min(2, #Runner.fixture.containers), "containers_not_duplicated", "count=" .. stats.containersInspected)
        check(memory.status == SurvivorMemory.MemoryStore.Status.PARTIALLY_SEARCHED, "status_partial_with_uninspected_known_containers", "value=" .. tostring(memory.status))
        save(true)
        log("SAVE requested=true first=" .. tostring(memory.firstVisited) .. " last=" .. tostring(memory.lastVisited))
        Runner.phase, Runner.tick = 7, 0
    elseif Runner.phase == 7 and Runner.tick > 90 then
        Events.OnTick.Remove(onTick); finish()
    end
end

debugScenarios.SurvivorMemorySmokeScenario = {
    name = "Survivor Memory vanilla building smoke test",
    forceLaunch = true,
    startLoc = { x = 7090, y = 8371, z = 0 },
    setSandbox = function()
        SandboxVars.Zombies = 6
        SandboxVars.LootItemRemovalList = ""
        SandboxVars.ZombieConfig = SandboxVars.ZombieConfig or {}
        SandboxVars.ZombieConfig.PopulationMultiplier = 0
        SandboxVars.ZombieConfig.PopulationStartMultiplier = 0
        SandboxVars.ZombieConfig.PopulationPeakMultiplier = 0
    end,
    onStart = function()
        getPlayer():setGhostMode(true); setGameSpeed(1); Events.OnTick.Add(onTick)
        log("START map=" .. tostring(getWorld():getMap()) .. " save=" .. tostring(getCore():getSaveFolder()))
    end,
}
