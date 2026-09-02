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

local function applyNativeOption(id, value)
    local options = PZAPI and PZAPI.ModOptions
        and PZAPI.ModOptions:getOptions("SurvivorMemory") or nil
    local option = options and options:getOption(id) or nil
    if not option or not option.onChangeApply then return false end
    option:onChangeApply(value)
    return true
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
        local nativeOptions = PZAPI and PZAPI.ModOptions
            and PZAPI.ModOptions:getOptions("SurvivorMemory") or nil
        check(nativeOptions ~= nil, "native_mod_options_registered")
        check(nativeOptions and nativeOptions:getOption("buildingMemoryEnabled")
                and nativeOptions:getOption("buildingMemoryEnabled"):getValue() == true,
            "native_building_memory_default_enabled")
        check(nativeOptions and nativeOptions:getOption("markerSizePercent")
                and nativeOptions:getOption("markerSizePercent"):getValue() == 100,
            "native_marker_size_default")
        local keyOption = nativeOptions and nativeOptions:getOption("recallPanelKey") or nil
        check(keyOption and keyOption.name == getText("IGUI_SM_OptionRecallPanelKey"),
            "native_keybind_uses_rendered_label")
        local allOptionsHaveTooltips = nativeOptions ~= nil
        if nativeOptions then
            for _, option in ipairs(nativeOptions.data) do
                if option.getValue and not option.tooltip then allOptionsHaveTooltips = false end
            end
        end
        check(allOptionsHaveTooltips, "native_mod_options_have_tooltips")
        local buildingOption = nativeOptions and nativeOptions:getOption("buildingMemoryEnabled") or nil
        local roomsOption = nativeOptions and nativeOptions:getOption("rememberRooms") or nil
        if buildingOption and buildingOption.onChange then buildingOption:onChange(false) end
        check(roomsOption and roomsOption.isEnabled == false,
            "native_category_disables_child_immediately")
        check(roomsOption and roomsOption:getValue() == true,
            "native_category_preserves_child_preference")
        if buildingOption and buildingOption.onChange then buildingOption:onChange(true) end
        check(roomsOption and roomsOption.isEnabled == true,
            "native_category_restores_child_immediately")
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
        local outdoorItem = instanceItem("Base.Generator")
        Runner.outdoorGenerator = outdoorItem
            and IsoGenerator.new(outdoorItem, getCell(), Runner.fixture.outside) or nil
        check(Runner.outdoorGenerator ~= nil, "important_outdoor_generator_fixture_created")
        if Runner.outdoorGenerator then
            triggerEvent("OnObjectAdded", Runner.outdoorGenerator)
        end
        Runner.gasPump = IsoObject.new(getCell(), Runner.fixture.outside,
            getSprite("location_shop_fossoil_01_12"))
        check(Runner.gasPump ~= nil
                and SurvivorMemory.Runtime.importantKindForObject(Runner.gasPump)
                    == SurvivorMemory.ImportantMemory.Kind.GAS_PUMP,
            "important_gas_pump_fixture_classified")
        if Runner.gasPump then triggerEvent("OnObjectAdded", Runner.gasPump) end
        Runner.phase, Runner.tick = 11, 0
    elseif Runner.phase == 11 and Runner.tick > 30 then
        local outdoorObserved = SurvivorMemory.ImportantMemory.outdoor(
            select(2, SurvivorMemory.Runtime.currentMemory(0)))
        local outdoorKinds = {}
        for _, observation in ipairs(outdoorObserved) do outdoorKinds[observation.kind] = true end
        check(Runner.outdoorGenerator and outdoorKinds.GENERATOR == true,
            "important_outdoor_generator_observed_automatically")
        check(Runner.gasPump and outdoorKinds.GAS_PUMP == true,
            "important_gas_pump_observed_only_when_visible")
        local contextOk, contextError = pcall(function()
            SurvivorMemory.MemoryPanel.onWorldContextMenu(0, nil, {}, false)
        end)
        check(contextOk, "world_context_menu_has_no_observation_side_effect",
            "error=" .. tostring(contextError))
        local outdoorRoot = select(2, SurvivorMemory.Runtime.currentMemory(0))
        check(#SurvivorMemory.ImportantMemory.outdoor(outdoorRoot) == 2,
            "important_outdoor_memory_available_to_map")
        Runner.vehicle = addVehicle("Base.CarNormal", Runner.fixture.outside:getX() + 3,
            Runner.fixture.outside:getY(), Runner.fixture.outside:getZ())
        check(Runner.vehicle ~= nil, "vehicle_fixture_created")
        local descriptor = Runner.vehicle and SurvivorMemory.Runtime.vehicleDescriptor(Runner.vehicle) or nil
        check(descriptor ~= nil, "vehicle_identity_available",
            "sql=" .. tostring(descriptor and descriptor.sqlId)
                .. " mechanical=" .. tostring(descriptor and descriptor.mechanicalId))
        if Runner.vehicle then
            Runner.vehicle:enter(0, player)
            triggerEvent("OnEnterVehicle", player)
            check(#SurvivorMemory.VehicleMemory.all(outdoorRoot) == 1,
                "vehicle_remembered_on_enter")
            Runner.vehicle:exit(player)
            triggerEvent("OnExitVehicle", player)
            check(#SurvivorMemory.VehicleMemory.all(outdoorRoot) == 1,
                "vehicle_exit_updates_single_memory")
            check((outdoorRoot.debug.vehicleObservations_enter or 0) == 1,
                "vehicle_enter_event_counted_once")
            check((outdoorRoot.debug.vehicleObservations_exit or 0) == 1,
                "vehicle_exit_event_counted_once")
        end
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
        check(applyNativeOption("showStatusIndicator", false),
            "native_status_indicator_option_applied_off")
        check(indicator and not indicator:isVisible(),
            "native_status_indicator_option_hides_indicator")
        check(applyNativeOption("showStatusIndicator", true),
            "native_status_indicator_option_applied_on")
        Runner.phase, Runner.tick = 21, 0
    elseif Runner.phase == 21 and Runner.tick > 25 then
        local memory = SurvivorMemory.Runtime.currentMemory(0)
        local indicator = SurvivorMemory.MemoryStatusIndicator and SurvivorMemory.MemoryStatusIndicator.currentButton(0)
        check(indicator and indicator:isVisible(),
            "native_status_indicator_option_restores_indicator")
        check(memory and memory.visitCount == 1,
            "option_change_does_not_duplicate_visit", "value=" .. tostring(memory and memory.visitCount))
        if Runner.fixture.rooms[2] then moveTo(player, Runner.fixture.rooms[2]) end
        Runner.phase, Runner.tick = 3, 0
    elseif Runner.phase == 3 and Runner.tick > 25 then
        local page = { player = 0 }
        if Runner.fixture.containers[1] then SurvivorMemory.Runtime.inspectContainer(page, Runner.fixture.containers[1]) end
        if Runner.fixture.containers[2] then SurvivorMemory.Runtime.inspectContainer(page, Runner.fixture.containers[2]) end
        local probeIndex = 3
        while probeIndex <= #Runner.fixture.containers do
            SurvivorMemory.Runtime.observeContainer(page, Runner.fixture.containers[probeIndex])
            local probeMemory = SurvivorMemory.Runtime.currentMemory(0)
            if probeMemory and probeMemory.status == SurvivorMemory.MemoryStore.Status.PARTIALLY_SEARCHED then break end
            probeIndex = probeIndex + 1
        end
        local memory = SurvivorMemory.Runtime.currentMemory(0)
        local stats = SurvivorMemory.MemoryStore.stats(nil, memory)
        check(stats.roomsKnown >= math.min(2, #Runner.fixture.rooms), "rooms_unique", "count=" .. stats.roomsKnown)
        check(stats.containersInspected >= math.min(2, #Runner.fixture.containers), "containers_inspected", "count=" .. stats.containersInspected)
        local indicator = SurvivorMemory.MemoryStatusIndicator and SurvivorMemory.MemoryStatusIndicator.currentButton(0)
        local staleColor = SurvivorMemory.StatusPresentation.color(SurvivorMemory.MemoryStore.Status.VISITED)
        if indicator then
            indicator.presentedStatus = SurvivorMemory.MemoryStore.Status.VISITED
            indicator:setActiveColor(staleColor.r, staleColor.g, staleColor.b)
        end
        Runner.phase, Runner.tick = 31, 0
    elseif Runner.phase == 31 and Runner.tick > 10 then
        local memory = SurvivorMemory.Runtime.currentMemory(0)
        local indicator = SurvivorMemory.MemoryStatusIndicator and SurvivorMemory.MemoryStatusIndicator.currentButton(0)
        local expectedColor = SurvivorMemory.StatusPresentation.color(memory and memory.status)
        check(indicator and memory and indicator.presentedStatus == memory.status,
            "indicator_status_refreshes_without_map", "value=" .. tostring(indicator and indicator.presentedStatus))
        check(indicator and math.abs(indicator.activeColor.r - expectedColor.r) < 0.001
                and math.abs(indicator.activeColor.g - expectedColor.g) < 0.001
                and math.abs(indicator.activeColor.b - expectedColor.b) < 0.001,
            "indicator_color_refreshes_without_map")
        local changed = SurvivorMemory.Runtime.setCurrentPlaceDesignation(0,
            SurvivorMemory.PlaceDesignation.HOME)
        check(changed, "place_designated_home")
        check(memory and memory.placeDesignation == SurvivorMemory.PlaceDesignation.HOME,
            "home_designation_stored")
        check(indicator and indicator:isVisible(), "home_partial_indicator_visible")
        check(SurvivorMemory.WorldMapOverlay
                and SurvivorMemory.WorldMapOverlay.iconPathFor(memory)
                    == "media/ui/SurvivorMemory/map-home-marker.png",
            "home_map_marker_selected")
        check(getTexture("media/ui/SurvivorMemory/map-home-marker.png") ~= nil,
            "home_marker_texture_loaded")
        check(getTexture("media/ui/SurvivorMemory/map-outpost-marker.png") ~= nil,
            "outpost_marker_texture_loaded")
        local temporaryInspections = {}
        for key in pairs(memory.containersKnown) do
            if memory.containersInspected[key] == nil then
                memory.containersInspected[key] = getGameTime():getWorldAgeHours()
                table.insert(temporaryInspections, key)
            end
        end
        SurvivorMemory.MemoryStore.recomputeStatus(memory)
        SurvivorMemory.Runtime.setCurrentPlaceDesignation(0, SurvivorMemory.PlaceDesignation.OUTPOST)
        check(indicator and not indicator:isVisible(), "searched_outpost_indicator_hidden")
        check(SurvivorMemory.WorldMapOverlay.iconPathFor(memory)
                == "media/ui/SurvivorMemory/map-outpost-marker.png",
            "outpost_map_marker_selected")
        check(SurvivorMemory.WorldMapOverlay.markerSizeFor(memory, 20) == 33,
            "outpost_marker_scaled_up")
        for _, key in ipairs(temporaryInspections) do memory.containersInspected[key] = nil end
        SurvivorMemory.MemoryStore.recomputeStatus(memory)
        SurvivorMemory.Runtime.setCurrentPlaceDesignation(0, SurvivorMemory.PlaceDesignation.HOME)
        check(indicator and indicator:isVisible(), "partial_home_indicator_restored")
        check(SurvivorMemory.WorldMapOverlay.markerSizeFor(memory, 20) == 26,
            "home_marker_scaled_up")
        check(SurvivorMemory.WorldMapOverlay.markerSizeFor({ placeDesignation = "NONE" }, 20) == 20,
            "standard_marker_size_unchanged")
        local generatorItem = instanceItem("Base.Generator")
        Runner.generator = generatorItem and IsoGenerator.new(generatorItem, getCell(), player:getCurrentSquare()) or nil
        check(Runner.generator ~= nil, "important_generator_fixture_created")
        check(Runner.generator and SurvivorMemory.Runtime.importantKindForObject(Runner.generator)
                == SurvivorMemory.ImportantMemory.Kind.GENERATOR,
            "important_generator_classified")
        if Runner.generator then
            triggerEvent("OnObjectAdded", Runner.generator)
        end
        Runner.phase, Runner.tick = 32, 0
    elseif Runner.phase == 32 and Runner.tick > 30 then
        local memory = SurvivorMemory.Runtime.currentMemory(0)
        local importantRoot = select(2, SurvivorMemory.Runtime.currentMemory(0))
        local important = SurvivorMemory.ImportantMemory.forBuilding(importantRoot, memory.buildingKey)
        check(#important == 1 and important[1].kind == SurvivorMemory.ImportantMemory.Kind.GENERATOR,
            "important_generator_observed_automatically_in_building")
        SurvivorMemory.EmotionalMemory.remember(memory, getGameTime():getWorldAgeHours() - 24)
        local emotionalSnapshot = SurvivorMemory.Runtime.debugSnapshot(0)
        emotionalSnapshot.state.emotionalDangerThisVisit = true
        check(memory.emotionalMemory ~= nil, "emotional_memory_seeded_for_runtime_smoke")
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
        check(ISWorldMap.instance and ISWorldMap.instance.smMemoryMarkerCache
                and #ISWorldMap.instance.smMemoryMarkerCache.important == 2,
            "important_outdoor_marker_cached")
        check(ISWorldMap.instance and ISWorldMap.instance.smMemoryMarkerCache
                and #ISWorldMap.instance.smMemoryMarkerCache.vehicles == 1,
            "vehicle_last_seen_marker_cached")
        check(getTexture("media/ui/SurvivorMemory/map-vehicle-marker.png") ~= nil,
            "vehicle_marker_texture_loaded")
        local memory = SurvivorMemory.Runtime.currentMemory(0)
        local markerX = ISWorldMap.instance and memory
            and ISWorldMap.instance.mapAPI:worldToUIX(memory.centerX, memory.centerY)
        local markerY = ISWorldMap.instance and memory
            and ISWorldMap.instance.mapAPI:worldToUIY(memory.centerX, memory.centerY)
        local hit = markerX and SurvivorMemory.WorldMapOverlay.memoryAt(
            ISWorldMap.instance, markerX, markerY) or nil
        check(hit == memory, "world_map_marker_hit_test")
        local opened = hit and ISWorldMap.instance:onRightMouseUp(markerX, markerY)
        check(opened == true, "world_map_marker_context_opened")
        local context = getPlayerContextMenu and getPlayerContextMenu(0) or nil
        check(context and context:getOptionFromName(getText("IGUI_SM_MapMarkHome")) ~= nil,
            "world_map_home_action_available")
        local outpostOption = context and context:getOptionFromName(getText("IGUI_SM_MapMarkOutpost")) or nil
        check(outpostOption ~= nil, "world_map_outpost_action_available")
        check(context and context:getOptionFromName(getText("IGUI_SM_MapClearPlace")) ~= nil,
            "world_map_clear_action_available")
        if outpostOption then
            outpostOption.onSelect(outpostOption.target, outpostOption.param1, outpostOption.param2)
        end
        check(memory.placeDesignation == SurvivorMemory.PlaceDesignation.OUTPOST,
            "world_map_outpost_action_applied")
        if context then context:closeAll() end
        local reopened = ISWorldMap.instance:onRightMouseUp(markerX, markerY)
        check(reopened == true, "world_map_outpost_context_reopened")
        Runner.mapContext = getPlayerContextMenu and getPlayerContextMenu(0) or nil
        local reopenedOutpost = Runner.mapContext
            and Runner.mapContext:getOptionFromName(getText("IGUI_SM_MapMarkOutpost")) or nil
        check(reopenedOutpost and reopenedOutpost.checkMark == true,
            "world_map_outpost_action_checked")
        Runner.phase, Runner.tick = 46, 0
    elseif Runner.phase == 46 and Runner.tick > 10 then
        check(Runner.mapContext and Runner.mapContext:getIsVisible(), "world_map_context_visible")
        local ok, err = pcall(function() getCore():TakeFullScreenshot("survivor-memory-world-map.png") end)
        check(ok, "world_map_overlay_screenshot", "error=" .. tostring(err))
        local memory = SurvivorMemory.Runtime.currentMemory(0)
        SurvivorMemory.Runtime.setPlaceDesignation(0, memory.buildingKey, SurvivorMemory.PlaceDesignation.HOME)
        if Runner.mapContext then Runner.mapContext:closeAll() end
        if ISWorldMap.instance then ISWorldMap.instance:close() end
        moveTo(player, Runner.fixture.outside)
        Runner.ageBeforeWait = getGameTime():getWorldAgeHours()
        getGameTime():setMinutesPerDay(1); setGameSpeed(3)
        Runner.phase, Runner.tick = 5, 0
    elseif Runner.phase == 5 and getGameTime():getWorldAgeHours() >= Runner.ageBeforeWait + 6 then
        setGameSpeed(1)
        Runner.panicBeforeReaction = player:getStats():get(CharacterStat.PANIC)
        Runner.stressBeforeReaction = player:getStats():get(CharacterStat.STRESS)
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
        check(memory.emotionalMemory and memory.emotionalMemory.lastReactionAt ~= nil,
            "emotional_reaction_recorded_on_reentry")
        check(player:getStats():get(CharacterStat.PANIC) > Runner.panicBeforeReaction,
            "emotional_reaction_added_vanilla_panic")
        check(player:getStats():get(CharacterStat.STRESS) > Runner.stressBeforeReaction,
            "emotional_reaction_added_vanilla_stress")
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
