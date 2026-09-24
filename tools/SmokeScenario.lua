require "SurvivorMemory/Runtime"
require "SurvivorMemory/MemoryPanel"
require "SurvivorMemory/ItemMemoryContext"

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

-- Test-only bounded lookup in the vanilla basement zone at 7121,8329.
-- No equivalent world enumeration exists in production observation code.
local function findBasementStairPair()
    for x = 7119, 7134 do
        for y = 8327, 8345 do
            local lower = getCell():getGridSquare(x, y, -1)
            if lower and lower:HasStairs() and lower:getBuilding() then
                for dx = -1, 1 do
                    for dy = -1, 1 do
                        local upper = getCell():getGridSquare(x + dx, y + dy, 0)
                        if upper and upper:getBuilding() and upper:getFloor() then
                            return upper, lower
                        end
                    end
                end
            end
        end
    end
end

local function restoreBasementFixture(player)
    local testRoot = player:getModData().SurvivorMemory
    Runner.basementOriginalRoot.debug.basementFixture = testRoot
    player:getModData().SurvivorMemory = Runner.basementOriginalRoot
    SurvivorMemory.Runtime.players[0] = Runner.basementOriginalState
    moveTo(player, Runner.basementOriginalSquare)
    save(true)
    Runner.phase, Runner.tick = 83, 0
end

local function onTick()
    Runner.tick = Runner.tick + 1
    local player = getPlayer()
    if not player then return end
    if Runner.phase == 0 and Runner.tick > 150 then
        local nativeOptions = PZAPI and PZAPI.ModOptions
            and PZAPI.ModOptions:getOptions("SurvivorMemory") or nil
        check(nativeOptions ~= nil, "native_mod_options_registered")
        check(nativeOptions and nativeOptions:getOption("fadeDistantMarkers") ~= nil
                and nativeOptions:getOption("markerFocusRadius") ~= nil,
            "native_map_distance_options_registered")
        check(nativeOptions and nativeOptions:getOption("buildingMemoryEnabled")
                and nativeOptions:getOption("buildingMemoryEnabled"):getValue() == true,
            "native_building_memory_default_enabled")
        check(nativeOptions and nativeOptions:getOption("markerSizePercent")
                and nativeOptions:getOption("markerSizePercent"):getValue() == 100,
            "native_marker_size_default")
        check(nativeOptions and nativeOptions:getOption("lootRespawnAwareness")
                and nativeOptions:getOption("lootRespawnAwareness"):getValue() == true,
            "native_loot_respawn_awareness_default_enabled")
        local keyOption = nativeOptions and nativeOptions:getOption("recallPanelKey") or nil
        check(keyOption and keyOption.name == "IGUI_SM_OptionRecallPanelKey",
            "native_keybind_uses_translation_key")
        local fakeLabel = { getName = function() return getText("IGUI_SM_OptionRecallPanelKey") end }
        local fakeButton = { internal = "IGUI_SM_OptionRecallPanelKey" }
        local previousKeyElement = keyOption and keyOption.element or nil
        if keyOption then keyOption.element = { btn = fakeButton, txt = fakeLabel } end
        check(SurvivorMemory.ModOptions.normalizeRecallKeybindButton(fakeButton)
                and fakeButton.internal == getText("IGUI_SM_OptionRecallPanelKey"),
            "native_keybind_normalizes_button_to_rendered_label")
        if keyOption then keyOption.element = previousKeyElement end
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
        check(SurvivorMemory.Runtime.transferHooksInstalled == true,
            "loot_respawn_transfer_hook_installed")
        check(nativeOptions and nativeOptions:getOption("readingMemoryEnabled") ~= nil,
            "reading_memory_native_option_registered")
        check(SurvivorMemory.ReadingMemoryIndicator
                and SurvivorMemory.ReadingMemoryIndicator.installed == true,
            "reading_inventory_marker_hook_installed")
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
            for index = 0, Runner.vehicle:getPartCount() - 1 do
                local part = Runner.vehicle:getPartByIndex(index)
                if part then part:setCondition(20) end
            end
            local gasTank = Runner.vehicle:getPartById("GasTank")
            local engine = Runner.vehicle:getPartById("Engine")
            if gasTank and gasTank:getContainerCapacity() > 0 then
                gasTank:setContainerContentAmount(gasTank:getContainerCapacity() * 0.10)
            end
            -- Keep the badly damaged fixture driveable so this validates POOR,
            -- while deterministic tests cover the FAILED override separately.
            if engine then engine:setCondition(20) end
            local mechanicsBefore = outdoorRoot.debug.vehicleObservations_mechanics or 0
            local mechanicsAction = ISOpenMechanicsUIAction:new(player, Runner.vehicle)
            mechanicsAction:perform()
            check((outdoorRoot.debug.vehicleObservations_mechanics or 0) == mechanicsBefore + 1,
                "vehicle_remembered_when_mechanics_ui_opens")
            local mechanicsMemory = SurvivorMemory.VehicleMemory.all(outdoorRoot)[1]
            check(mechanicsMemory
                    and mechanicsMemory.fuelState == SurvivorMemory.VehicleMemory.FuelState.LOW,
                "vehicle_mechanics_remembers_broad_fuel_state",
                "value=" .. tostring(mechanicsMemory and mechanicsMemory.fuelState))
            check(mechanicsMemory
                    and mechanicsMemory.vehicleCondition
                        == SurvivorMemory.VehicleMemory.VehicleCondition.POOR,
                "vehicle_mechanics_remembers_broad_overall_condition",
                "value=" .. tostring(mechanicsMemory and mechanicsMemory.vehicleCondition)
                    .. " driveable=" .. tostring(Runner.vehicle:isDriveable()))
            local mechanicsUI = getPlayerMechanicsUI(player:getPlayerNum())
            if mechanicsUI and mechanicsUI:isReallyVisible() then mechanicsUI:close() end
            local localVehicleContext = ISContextMenu.get(0, 100, 100)
            check(SurvivorMemory.MemoryPanel.addVehicleContextOption(
                0, localVehicleContext, Runner.vehicle),
                "nearby_vehicle_personal_action_added")
            local markPersonalNearby = localVehicleContext:getOptionFromName(
                getText("IGUI_SM_VehicleMarkPersonal"))
            check(markPersonalNearby ~= nil, "nearby_vehicle_mark_personal_action_available")
            if markPersonalNearby then
                markPersonalNearby.onSelect(markPersonalNearby.target,
                    markPersonalNearby.param1, markPersonalNearby.param2)
            end
            check(mechanicsMemory.personal == true,
                "nearby_vehicle_personal_action_applied")
            localVehicleContext:closeAll()
            check(SurvivorMemory.Runtime.setVehiclePersonal(
                0, mechanicsMemory.vehicleKey, false),
                "personal_vehicle_can_be_cleared_before_map_test")
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
        local roomKind = SurvivorMemory.LocationName.kindFromRoomName(
            player:getCurrentSquare():getRoom():getRoomDef():getName())
        check(type(memory.locationKinds) == "table" and (not roomKind or memory.locationKinds[roomKind]),
            "observed_location_labels", "value=" .. SurvivorMemory.LocationName.text(memory))
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
        local expectedKinds = {}
        for index = 1, math.min(2, #Runner.fixture.rooms) do
            local kind = SurvivorMemory.LocationName.kindFromRoomName(
                Runner.fixture.rooms[index]:getRoom():getRoomDef():getName())
            if kind then expectedKinds[kind] = true end
        end
        local labelsMatch = true
        for kind in pairs(expectedKinds) do
            if not memory.locationKinds[kind] then labelsMatch = false end
        end
        for kind in pairs(memory.locationKinds) do
            if not expectedKinds[kind] then labelsMatch = false end
        end
        check(labelsMatch, "classification_uses_only_entered_rooms")
        select(2, SurvivorMemory.Runtime.currentMemory(0)).debug.expectedLocationKinds = expectedKinds
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
        local respawnContainer = Runner.fixture.containers[1]
        local respawnKey = respawnContainer
            and SurvivorMemory.ContainerIdentity.fromContainer(respawnContainer) or nil
        local root = select(2, SurvivorMemory.Runtime.currentMemory(0))
        local confirmedBefore = root.debug.lootRespawnsConfirmed or 0
        if respawnContainer and respawnKey then
            SurvivorMemory.MemoryStore.markContainerLooted(memory, respawnKey,
                getGameTime():getWorldAgeHours(), true)
            respawnContainer:setHasBeenLooted(false)
            SurvivorMemory.Runtime.inspectContainer({ player = 0 }, respawnContainer)
        end
        check((root.debug.lootRespawnsConfirmed or 0) == confirmedBefore + 1,
            "vanilla_loot_respawn_flag_transition_confirmed")
        check(SurvivorMemory.Runtime.lootRespawnNotice(0, memory) == "CONFIRMED",
            "confirmed_loot_respawn_exposed_to_ui")
        check(memory.status == SurvivorMemory.MemoryStore.Status.PARTIALLY_SEARCHED,
            "confirmed_loot_respawn_refreshes_other_container_progress")
        for _, key in ipairs(temporaryInspections) do memory.containersInspected[key] = nil end
        if Runner.fixture.containers[2] then
            SurvivorMemory.Runtime.inspectContainer({ player = 0 }, Runner.fixture.containers[2])
        end
        check(SurvivorMemory.MemoryStore.stats(nil, memory).containersInspected == 2,
            "known_container_can_be_reinspected_after_respawn")
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
        local container = Runner.fixture.containers[1]
        moveTo(player, container:getSourceGrid())
        Runner.rememberedItem = container:AddItem("Base.NailsBox")
        local loot = getPlayerLoot(0)
        loot:setVisible(true)
        loot:setPinned()
        loot:setNewContainer(container)
        Runner.phase, Runner.tick = 33, 0
    elseif Runner.phase == 33 and Runner.tick > 10 then
        local loot = getPlayerLoot(0)
        loot:setNewContainer(Runner.fixture.containers[1])
        local memory = SurvivorMemory.Runtime.currentMemory(0)
        local context = ISContextMenu.get(0, 100, 100)
        SurvivorMemory.ItemMemoryContext.fill(0, context, { Runner.rememberedItem })
        local option = context:getOptionFromName(getText("IGUI_SM_RememberItems"))
        check(option ~= nil, "selected_item_context_action_available")
        if option then option.onSelect(option.target, option.param1) end
        local entries = SurvivorMemory.ItemMemory.all(memory)
        check(#entries == 1 and entries[1].observation.itemType == "Base.NailsBox",
            "selected_box_of_nails_remembered")
        check(#entries == 1 and entries[1].observation.textureName
                and getTexture(entries[1].observation.textureName) ~= nil,
            "selected_item_texture_resolves")
        if option then option.onSelect(option.target, option.param1) end
        check(#SurvivorMemory.ItemMemory.all(memory) == 1, "selected_item_repeat_not_duplicated")
        loot:setVisible(false)
        check(SurvivorMemory.Runtime.rememberItems(0, { Runner.rememberedItem }) == false,
            "closed_loot_ui_rejects_item_selection")
        loot:setVisible(true)
        context:closeAll()
        local container = Runner.fixture.containers[1]
        Runner.collectedBook = container:AddItem("Base.BookCarpentry1")
        Runner.duplicateBook = container:AddItem("Base.BookCarpentry1")
        check(Runner.collectedBook and Runner.duplicateBook,
            "reading_book_pair_created_in_real_loot_container")
        if Runner.collectedBook then
            ISTimedActionQueue.add(ISInventoryTransferAction:new(player, Runner.collectedBook,
                container, player:getInventory(), 1))
        end
        Runner.phase, Runner.tick = 34, 0
    elseif Runner.phase == 34 and (Runner.collectedBook
            and player:getInventory():contains(Runner.collectedBook)
            or Runner.tick > 180) then
        local root = SurvivorMemory.MemoryStore.forModData(player:getModData())
        check(Runner.collectedBook and player:getInventory():contains(Runner.collectedBook),
            "reading_book_really_transferred_into_inventory")
        check(SurvivorMemory.ReadingMemory.has(root, Runner.duplicateBook),
            "unread_duplicate_in_loot_marked_as_collected")
        local ok, err = pcall(function()
            getCore():TakeFullScreenshot("survivor-memory-reading-loot.png")
        end)
        check(ok, "reading_loot_screenshot", "error=" .. tostring(err))
        SurvivorMemory.MemoryPanel.open(0); Runner.phase, Runner.tick = 4, 0
    elseif Runner.phase == 4 and Runner.tick > 45 then
        local ok, err = pcall(function() getCore():TakeFullScreenshot("survivor-memory-panel.png") end)
        check(ok, "memory_panel_screenshot", "error=" .. tostring(err))
        SurvivorMemory.MemoryPanel.open(0)
        local memory, root = SurvivorMemory.Runtime.currentMemory(0)
        Runner.duplicateBuildingKey = memory and (memory.buildingKey .. ":historical-smoke") or nil
        if root and memory and Runner.duplicateBuildingKey then
            root.buildings[Runner.duplicateBuildingKey] = SurvivorMemory.MemoryStore.newBuilding({
                key = Runner.duplicateBuildingKey,
                centerX = memory.centerX,
                centerY = memory.centerY,
            }, memory.firstVisited)
            root.revision = (tonumber(root.revision) or 0) + 1
        end
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
        check(ISWorldMap.instance and ISWorldMap.instance.smMemoryMarkerCache
                and #ISWorldMap.instance.smMemoryMarkerCache.markers == 1,
            "personal_place_replaces_duplicate_building_marker")
        check(getTexture("media/ui/SurvivorMemory/map-vehicle-marker.png") ~= nil,
            "vehicle_marker_texture_loaded")
        local vehicleObservation = ISWorldMap.instance.smMemoryMarkerCache.vehicles[1]
        local vehicleMarkerX = vehicleObservation
            and ISWorldMap.instance.mapAPI:worldToUIX(vehicleObservation.x, vehicleObservation.y)
        local vehicleMarkerY = vehicleObservation
            and ISWorldMap.instance.mapAPI:worldToUIY(vehicleObservation.x, vehicleObservation.y)
        local vehicleHit = vehicleMarkerX and SurvivorMemory.WorldMapOverlay.vehicleAt(
            ISWorldMap.instance, vehicleMarkerX, vehicleMarkerY) or nil
        check(vehicleHit == vehicleObservation, "world_map_vehicle_marker_hit_test")
        local vehicleContextOpened = vehicleHit
            and ISWorldMap.instance:onRightMouseUp(vehicleMarkerX, vehicleMarkerY)
        check(vehicleContextOpened == true, "world_map_vehicle_context_opened")
        local vehicleContext = getPlayerContextMenu and getPlayerContextMenu(0) or nil
        local markPersonal = vehicleContext
            and vehicleContext:getOptionFromName(getText("IGUI_SM_VehicleMarkPersonal")) or nil
        check(markPersonal ~= nil, "world_map_mark_personal_vehicle_action_available")
        if markPersonal then
            markPersonal.onSelect(markPersonal.target, markPersonal.param1, markPersonal.param2)
        end
        check(vehicleObservation.personal == true, "world_map_personal_vehicle_action_applied")
        if vehicleContext then vehicleContext:closeAll() end
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
        check(Runner.mapContext and Runner.mapContext:getOptionFromName(getText("IGUI_SM_ForgetItemMenu")),
            "map_item_forget_menu_available")
        Runner.phase, Runner.tick = 46, 0
    elseif Runner.phase == 46 and Runner.tick > 10 then
        check(Runner.mapContext and Runner.mapContext:getIsVisible(), "world_map_context_visible")
        local ok, err = pcall(function() getCore():TakeFullScreenshot("survivor-memory-world-map.png") end)
        check(ok, "world_map_overlay_screenshot", "error=" .. tostring(err))
        local memory = SurvivorMemory.Runtime.currentMemory(0)
        SurvivorMemory.Runtime.setPlaceDesignation(0, memory.buildingKey, SurvivorMemory.PlaceDesignation.HOME)
        local root = select(2, SurvivorMemory.Runtime.currentMemory(0))
        if root and Runner.duplicateBuildingKey then
            root.buildings[Runner.duplicateBuildingKey] = nil
            root.revision = (tonumber(root.revision) or 0) + 1
        end
        if Runner.mapContext then Runner.mapContext:closeAll() end
        local map = ISWorldMap.instance
        SurvivorMemory.WorldMapOverlay.render(map)
        check(SurvivorMemory.WorldMapOverlay.hasObjectBadge(map, memory),
            "remembered_objects_badge_on_home_marker")
        local originalRect = map.drawRect
        local redDots = 0
        map.drawRect = function(self, x, y, w, h, a, r, g, b)
            if w == 6 and h == 6 and a == 1 and r == 1 and g == 0 and b == 0 then
                redDots = redDots + 1
            end
            return originalRect(self, x, y, w, h, a, r, g, b)
        end
        SurvivorMemory.WorldMapOverlay.drawPlayerDots(map)
        map.drawRect = originalRect
        check(redDots == 1, "vanilla_red_player_dot_redrawn_above_markers")
        for _, kind in ipairs({ "GENERATOR", "GAS_PUMP", "WOOD_STOVE" }) do
            check(SurvivorMemory.MapTooltip.importantIcon(kind) ~= nil, "important_tooltip_icon_" .. kind)
        end
        Runner.originalMapRender = map.render
        map.render = function(self)
            Runner.originalMapRender(self)
            SurvivorMemory.WorldMapOverlay.drawBuildingTooltip(self, memory, 140, 130)
        end
        Runner.phase, Runner.tick = 47, 0
    elseif Runner.phase == 47 and Runner.tick > 20 then
        local ok, err = pcall(function() getCore():TakeFullScreenshot("survivor-memory-item-tooltip.png") end)
        check(ok, "item_tooltip_screenshot", "error=" .. tostring(err))
        local vehicle = SurvivorMemory.VehicleMemory.all(select(2, SurvivorMemory.Runtime.currentMemory(0)))[1]
        ISWorldMap.instance.render = function(self)
            Runner.originalMapRender(self)
            SurvivorMemory.WorldMapOverlay.drawVehicleTooltip(self, vehicle, 130, 130)
            -- Presentation fixture only: does not create an unobserved stove memory.
            SurvivorMemory.WorldMapOverlay.drawImportantTooltip(self,
                { kind = "WOOD_STOVE", observedAt = getGameTime():getWorldAgeHours() }, 550, 130)
        end
        Runner.phase, Runner.tick = 48, 0
    elseif Runner.phase == 48 and Runner.tick > 20 then
        local ok, err = pcall(function() getCore():TakeFullScreenshot("survivor-memory-tooltip-cards.png") end)
        check(ok, "vehicle_and_stove_tooltip_screenshot", "error=" .. tostring(err))
        ISWorldMap.instance.render = Runner.originalMapRender
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
        Runner.basementOriginalRoot = player:getModData().SurvivorMemory
        Runner.basementOriginalState = SurvivorMemory.Runtime.players[0]
        Runner.basementOriginalSquare = player:getCurrentSquare()
        player:getModData().SurvivorMemory = nil
        SurvivorMemory.Runtime.resetPlayer(0)
        player:setX(7124.5); player:setY(8331.5); player:setZ(0)
        player:setLastX(player:getX()); player:setLastY(player:getY()); player:setLastZ(0)
        Runner.phase, Runner.tick = 80, 0
    elseif Runner.phase == 80 and Runner.tick > 90 then
        Runner.basementUpper, Runner.basementLower = findBasementStairPair()
        check(Runner.basementUpper ~= nil, "real_vanilla_basement_stair_fixture")
        if not Runner.basementUpper then restoreBasementFixture(player) return end
        -- Discard arrival observations in this separate test character store.
        player:getModData().SurvivorMemory = nil
        SurvivorMemory.Runtime.resetPlayer(0)
        moveTo(player, Runner.basementUpper)
        SurvivorMemory.Runtime.onPlayerUpdate(player)
        Runner.basementParentKey = SurvivorMemory.BuildingIdentity.fromBuilding(Runner.basementUpper:getBuilding()).key
        Runner.basementChildKey = SurvivorMemory.BuildingIdentity.fromBuilding(Runner.basementLower:getBuilding()).key
        log("BASEMENT upper=" .. Runner.basementParentKey .. " lower=" .. Runner.basementChildKey)
        Runner.phase, Runner.tick = 81, 0
    elseif Runner.phase == 81 and Runner.tick > 5 then
        moveTo(player, Runner.basementLower)
        SurvivorMemory.Runtime.onPlayerUpdate(player)
        local memory, root = SurvivorMemory.Runtime.currentMemory(0)
        check(memory and memory.buildingKey == Runner.basementParentKey,
            "real_basement_uses_surface_memory")
        check(memory and memory.visitCount == 1, "real_basement_no_extra_visit")
        check(root and SurvivorMemory.BuildingLinks.resolve(root, Runner.basementChildKey) == Runner.basementParentKey,
            "real_basement_identity_resolves")
        moveTo(player, Runner.basementUpper)
        SurvivorMemory.Runtime.onPlayerUpdate(player)
        memory = SurvivorMemory.Runtime.currentMemory(0)
        check(memory and memory.visitCount == 1, "real_return_upstairs_no_extra_visit")
        restoreBasementFixture(player)
    elseif Runner.phase == 83 and Runner.tick > 60 then
        Events.OnTick.Remove(onTick); finish()
    end
end

debugScenarios.SurvivorMemorySmokeScenario = {
    name = "Survivor Memory vanilla building smoke test",
    forceLaunch = true,
    startLoc = { x = 7090, y = 8371, z = 0 },
    setSandbox = function()
        SandboxVars.Basement = { SpawnFrequency = 7 }
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
