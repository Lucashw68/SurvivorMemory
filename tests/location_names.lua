return function(rootPath, equal, truthy)
    local L, M, B = SurvivorMemory.LocationName, SurvivorMemory.MemoryStore, SurvivorMemory.BuildingIdentity
    local function copy(value)
        if type(value) ~= "table" then return value end
        local out = {}; for k, v in pairs(value) do out[k] = copy(v) end; return out
    end
    local function room(name)
        return { getRoomDef = function() return { getName = function() return name end } end,
            getBuilding = function() error("must not inspect the whole building") end }
    end
    local id = B.fromFields({ x = 10, y = 20, x2 = 30, y2 = 40 })
    local memory = M.newBuilding(id, 12)
    equal(L.text(memory), "IGUI_SM_Location_BUILDING", "unknown building stays generic")
    for _, name in ipairs({ "kitchen", "bathroom", "closet", "diningroom", "unknown" }) do
        equal(L.observe(memory, room(name)), false, name .. " is not evidence of building use")
    end
    equal(L.observe(memory, nil), false, "missing room does not classify building")
    equal(L.observe(memory, { getRoomDef = function() end }), false, "missing room definition is safe")
    truthy(L.observe(memory, room("medical")), "medical room adds label")
    truthy(L.observe(memory, room("warehouse")), "warehouse adds second label of equal former priority")
    equal(L.text(memory), "IGUI_SM_Location_MEDICAL / IGUI_SM_Location_WAREHOUSE", "both observed uses displayed")
    equal(L.observe(memory, room("medical")), false, "revisits do not duplicate or resync labels")
    equal(L.observe(memory, room("pharmacy")), false, "related room deduplicates category")
    local reverse = M.newBuilding(id, 12)
    L.observe(reverse, room("warehouse")); L.observe(reverse, room("medical"))
    equal(L.text(reverse), L.text(memory), "label order independent of exploration order")
    equal(memory.visitCount, 1, "classification does not add visits")
    equal(memory.firstVisited, 12, "classification does not change timestamps")
    equal(memory.status, "VISITED", "classification does not affect searched status")
    equal(M.stats(nil, memory).roomsKnown, 0, "classification does not discover remote rooms")

    local function key(name, buildingKey)
        return B.roomFromFields(buildingKey or id.key,
            { x = 10, y = 20, x2 = 12, y2 = 22, z = -1, name = name })
    end
    local old = { schemaVersion = 9, buildings = { [id.key] = {
        firstVisited = 2, lastVisited = 3, visitCount = 7, locationKind = "HOUSE",
        roomsKnown = { [key("medical")] = 2, [key("warehouse")] = 3,
            [key("bathroom")] = 3, [key("bedroom", "another-building")] = 3,
            ["r1:999999:broken"] = 3, [key("病房:未知")] = 3 },
        containersKnown = { container = 2 }, containersInspected = { container = 3 },
        placeDesignation = "HOME",
    } } }
    local migrated = M.migrate(copy(old))
    local restored = migrated.buildings[id.key]
    equal(migrated.schemaVersion, 10, "v9 migrates to observed multi-label schema")
    equal(L.text(restored), L.text(memory), "migration reconstructs labels only from remembered r1 rooms")
    equal(restored.locationKind, "HOUSE", "legacy classification retained but no longer displayed")
    equal(restored.visitCount, 7, "migration preserves visits")
    equal(restored.firstVisited, 2, "migration preserves dates")
    equal(restored.containersInspected.container, 3, "migration preserves inspected containers")
    equal(restored.placeDesignation, "HOME", "migration preserves personal designation")
    local reloaded = M.migrate(copy(migrated))
    equal(L.text(reloaded.buildings[id.key]), L.text(memory), "multi-label memory survives serialized reload")
    local missing = copy(old)
    missing.buildings[id.key].roomsKnown = { [key("bathroom")] = 2 }
    equal(L.text(M.migrate(missing).buildings[id.key]), "IGUI_SM_Location_BUILDING", "unsupported old House becomes generic")
    local corrupt = copy(migrated)
    corrupt.buildings[id.key].locationKinds = { MEDICAL = true, WAREHOUSE = "yes", SECRET = true, BUILDING = true }
    equal(L.text(M.migrate(corrupt).buildings[id.key]), "IGUI_SM_Location_MEDICAL", "corrupt labels sanitized")
    corrupt = copy(migrated); corrupt.buildings[id.key].locationKinds = false
    equal(L.text(M.migrate(corrupt).buildings[id.key]), L.text(memory), "missing v10 labels recover from recorded rooms")
    local badLength = M.newBuilding(id, 0)
    badLength.locationKinds = nil
    badLength.roomsKnown[key("medical") .. "extra"] = 1
    L.initialize(badLength)
    equal(L.text(badLength), "IGUI_SM_Location_BUILDING", "malformed encoded room name is not inferred")
    equal(L.text(M.newBuilding(id, 0)), "IGUI_SM_Location_BUILDING", "new character inherits no labels")

    local lowerId = B.fromFields({ x = 11, y = 21, x2 = 29, y2 = 39, minLevel = -1, maxLevel = -1 })
    local root = M.migrate(nil)
    local upper = M.enterBuilding(root, id, 10)
    local lower = M.enterBuilding(root, lowerId, 10)
    L.observe(upper, room("medical")); L.observe(lower, room("warehouse"))
    truthy(SurvivorMemory.BuildingLinks.merge(root, lowerId.key, id.key), "observed basement link merges memories")
    equal(L.text(upper), L.text(memory), "basement merge unions discovered labels")
    equal(L.text(M.migrate(copy(root)).buildings[id.key]), L.text(memory), "merged labels survive reload")

    -- Runtime glue simulation: no game/world enumeration, including when a
    -- second category is added to an already visited building.
    local sm = {}; for k, v in pairs(SurvivorMemory) do sm[k] = v end
    sm.Runtime = nil
    local options = { master = true, buildingMemory = true, rooms = true }
    sm.ModOptions = { enabled = function(name) return options[name] == true end, addListener = function() end }
    sm.TimeFormat = { worldAgeHours = function() return 24 end }
    local sent, updates = 0, 0
    local modData = {}
    local def = { getX = function() return 10 end, getY = function() return 20 end,
        getX2 = function() return 30 end, getY2 = function() return 40 end,
        getMinLevel = function() return 0 end, getMaxLevel = function() return 0 end,
        getIDString = function() return "fixture" end,
        isResidential = function() error("unobserved building classification forbidden") end,
        isShop = function() error("unobserved shop classification forbidden") end }
    local building = { getDef = function() return def end }
    local currentRoom, x = "medical", 11
    local function current()
        local rd = { getName = function() return currentRoom end, getX = function() return x end,
            getY = function() return 21 end, getX2 = function() return x + 1 end,
            getY2 = function() return 22 end, getZ = function() return 0 end }
        return { getX = function() return x end, getY = function() return 21 end,
            getZ = function() return 0 end, getBuilding = function() return building end,
            getRoom = function() return { getRoomDef = function() return rd end } end,
            HasStairs = function() return false end, HasStairsBelow = function() return false end }
    end
    local player = { isLocalPlayer = function() return true end, getPlayerNum = function() return 0 end,
        getCurrentSquare = current, getVehicle = function() end, getCardinalDirection = function() return "N" end,
        getModData = function() return modData end, transmitModData = function() sent = sent + 1 end }
    local env = setmetatable({ SurvivorMemory = sm, require = function() end, isClient = function() return true end,
        Events = setmetatable({}, { __index = function() return { Add = function() end } end }),
    }, { __index = _G })
    local runtime = assert(loadfile(rootPath .. "/42/media/lua/client/SurvivorMemory/Runtime.lua", "t", env))()
    runtime.addListener(function(event) if event == "updated" then updates = updates + 1 end end)
    runtime.onPlayerUpdate(player)
    local observed = modData.SurvivorMemory.buildings[id.key]
    truthy(observed.locationKinds.MEDICAL, "runtime entry records only occupied medical room")
    currentRoom, x = "warehouse", 15
    local before = sent
    runtime.onPlayerUpdate(player)
    truthy(observed.locationKinds.WAREHOUSE, "runtime adds second observed type")
    truthy(sent > before, "new category synchronizes character modData")
    truthy(updates >= 2, "room discoveries refresh indicator and panel listeners")
    equal(observed.visitCount, 1, "crossing premises does not duplicate building visit")
    before = sent; runtime.onPlayerUpdate(player)
    equal(sent, before, "stationary update does not resynchronize labels")
    options.rooms = false
    currentRoom, x = "office", 19
    before = sent
    runtime.onPlayerUpdate(player)
    truthy(observed.locationKinds.OFFICE, "classification records entered room when room-count option is off")
    equal(M.stats(nil, observed).roomsKnown, 2, "classification does not enable room counting")
    truthy(sent > before, "new label synchronizes even when room counts are disabled")
    runtime.players = {}
    before = sent; runtime.onPlayerUpdate(player)
    equal(observed.visitCount, 1, "resume preserves visits and observed labels")
    equal(L.text(observed), "IGUI_SM_Location_MEDICAL / IGUI_SM_Location_OFFICE / IGUI_SM_Location_WAREHOUSE",
        "runtime displays every discovered category")
end
