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
    check(root and root.schemaVersion == 1, "schema_v1")
    check(buildingCount == 1, "one_building")
    check(memory and memory.visitCount == 2, "visit_count_preserved")
    check(memory and SurvivorMemory.MemoryStore.stats(nil, memory).roomsKnown == 2, "rooms_preserved")
    check(memory and SurvivorMemory.MemoryStore.stats(nil, memory).containersInspected == 2, "containers_preserved")
    check(memory and memory.firstVisited < memory.lastVisited, "timestamps_preserved")
    check(memory and memory.status == SurvivorMemory.MemoryStore.Status.PARTIALLY_SEARCHED, "status_preserved")
    log("RESULT status=" .. (#failures == 0 and "PASS" or "FAIL") .. " failures=" .. table.concat(failures, ","))
    getCore():quitToDesktop()
end

Events.OnRenderTick.Add(launchLatest)
Events.OnMainMenuEnter.Add(function() ticks = 30; launchLatest() end)
Events.OnGameStart.Add(validateReload)
