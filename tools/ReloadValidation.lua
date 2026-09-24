if SM_RELOAD_MODE ~= true then return end

require "SurvivorMemory/Runtime"

local target = tostring(SM_RELOAD_SAVE or "")
local launched, ticks = false, 0
local function log(message) print("[SurvivorMemory] RELOAD " .. message) end

local function launchLatest()
    if launched then return end
    ticks = ticks + 1
    if ticks < 30 or not MainScreen or not MainScreen.instance then return end
    local screen = MainScreen.instance.loadScreen
    if not screen or not screen.listbox then return end
    screen:setSaveGamesList()
    local selected
    for index, entry in ipairs(screen.listbox.items) do
        if target == "" or string.find(tostring(entry.text), target, 1, true) then selected = index break end
    end
    if not selected then
        log("RESULT status=FAIL failures=save_not_found target=" .. target)
        getCore():quitToDesktop(); launched = true; return
    end
    launched = true
    screen.listbox.selected = selected
    local selectedItem = screen.listbox.items[selected].item
    setSavefilePlayer1(selectedItem.gameMode, selectedItem.saveName, 1)
    log("LOAD save=" .. tostring(screen.listbox.items[selected].text)
        .. " playerAlive=" .. tostring(selectedItem.playerAlive))
    screen:clickPlay()
end

local function validateReload()
    Events.OnRenderTick.Remove(launchLatest)
    local player = getPlayer()
    local root = player and SurvivorMemory.MemoryStore.forModData(player:getModData()) or nil
    local buildingCount, memory = 0, nil
    for _, value in pairs(root and root.buildings or {}) do buildingCount = buildingCount + 1; memory = value end
    local failures = {}
    local function check(condition, name)
        if not condition then table.insert(failures, name) end
        log("CHECK " .. (condition and "PASS" or "FAIL") .. " name=" .. name)
    end
    check(root and root.schemaVersion == 11, "schema_v11")
    local carriedBooks = player and player:getInventory():getItemsFromFullType("Base.BookCarpentry1") or nil
    local carriedBook = carriedBooks and carriedBooks:size() > 0 and carriedBooks:get(0) or nil
    check(carriedBook and SurvivorMemory.ReadingMemory.has(root, carriedBook),
        "collected_unread_book_memory_preserved")
    local labelsMatch = memory and type(memory.locationKinds) == "table"
        and root.debug.expectedLocationKinds ~= nil
    for kind in pairs(root and root.debug.expectedLocationKinds or {}) do
        if not memory or not memory.locationKinds[kind] then labelsMatch = false end
    end
    for kind in pairs(memory and memory.locationKinds or {}) do
        if not root.debug.expectedLocationKinds[kind] then labelsMatch = false end
    end
    check(labelsMatch, "observed_location_labels_preserved")
    local basement = root and root.debug.basementFixture
    local basementSource, basementTarget
    for source, targetKey in pairs(basement and basement.buildingAliases or {}) do
        basementSource, basementTarget = source, targetKey; break
    end
    check(basementSource and basementTarget and basement.buildings[basementTarget]
            and basement.buildings[basementSource] == nil
            and basement.buildings[basementTarget].visitCount == 1
            and basement.linkedBuildingHistory[basementSource] ~= nil,
        "real_basement_alias_and_history_preserved")
    check(buildingCount == 1, "one_building")
    check(memory and memory.visitCount == 2, "visit_count_preserved")
    check(memory and SurvivorMemory.MemoryStore.stats(nil, memory).roomsKnown == 2, "rooms_preserved")
    check(memory and SurvivorMemory.MemoryStore.stats(nil, memory).containersInspected == 2, "containers_preserved")
    check(memory and memory.firstVisited < memory.lastVisited, "timestamps_preserved")
    check(memory and memory.status == SurvivorMemory.MemoryStore.Status.PARTIALLY_SEARCHED, "status_preserved")
    check(memory and memory.placeDesignation == SurvivorMemory.PlaceDesignation.HOME, "home_designation_preserved")
    local items = SurvivorMemory.ItemMemory.all(memory)
    check(#items == 1 and items[1].observation.itemType == "Base.NailsBox"
            and items[1].observation.quantityObserved == 1
            and items[1].observation.textureName ~= nil, "selected_item_memory_preserved")
    check(memory and memory.emotionalMemory and memory.emotionalMemory.observedAt ~= nil,
        "emotional_memory_preserved")
    check(memory and memory.emotionalMemory and memory.emotionalMemory.lastReactionAt ~= nil,
        "emotional_reaction_timestamp_preserved")
    local important = root and SurvivorMemory.ImportantMemory
        and SurvivorMemory.ImportantMemory.forBuilding(root, memory and memory.buildingKey) or {}
    check(#important == 1 and important[1].kind == "GENERATOR",
        "important_generator_preserved")
    local outdoorImportant = root and SurvivorMemory.ImportantMemory
        and SurvivorMemory.ImportantMemory.outdoor(root) or {}
    local outdoorKinds = {}
    for _, observation in ipairs(outdoorImportant) do outdoorKinds[observation.kind] = true end
    check(#outdoorImportant == 2 and outdoorKinds.GENERATOR and outdoorKinds.GAS_PUMP,
        "important_outdoor_objects_preserved")
    local vehicles = root and SurvivorMemory.VehicleMemory
        and SurvivorMemory.VehicleMemory.all(root) or {}
    check(#vehicles == 1 and vehicles[1].vehicleKey ~= nil,
        "vehicle_last_seen_memory_preserved")
    check(#vehicles == 1 and vehicles[1].fuelState == "LOW",
        "vehicle_fuel_summary_preserved")
    check(#vehicles == 1 and vehicles[1].vehicleCondition == "POOR",
        "vehicle_overall_condition_preserved")
    check(#vehicles == 1 and vehicles[1].personal == true,
        "personal_vehicle_designation_preserved")
    log("RESULT status=" .. (#failures == 0 and "PASS" or "FAIL") .. " failures=" .. table.concat(failures, ","))
    getCore():quitToDesktop()
end

Events.OnRenderTick.Add(launchLatest)
Events.OnMainMenuEnter.Add(function() ticks = 30; launchLatest() end)
Events.OnGameStart.Add(validateReload)
