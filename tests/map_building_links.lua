return function(rootPath, equal, truthy)
    local P = require "SurvivorMemory/MapPresentation"
    local L = SurvivorMemory.BuildingLinks
    local M = SurvivorMemory.MemoryStore
    local B = SurvivorMemory.BuildingIdentity
    local function copy(t)
        if type(t) ~= "table" then return t end
        local out = {}
        for k, v in pairs(t) do out[k] = copy(v) end
        return out
    end
    equal(P.opacity(300, 0, 0, 0, 300, true, false, false), 1, "focus boundary remains opaque")
    equal(P.opacity(450, 0, 0, 0, 300, true, false, false), 0.625, "distance fade is gradual")
    equal(P.opacity(600, 0, 0, 0, 300, true, false, false), 0.25, "ordinary distant marker remains visible")
    equal(P.opacity(900, 0, 0, 0, 300, true, true, false), 0.85, "personal distant marker stays prominent")
    equal(P.opacity(900, 0, 0, 0, 300, true, false, true), 1, "hover restores opacity")
    equal(P.opacity(900, 0, 0, 0, 300, false, false, false), 1, "fade option can be disabled")
    truthy(P.vehicleSize(20, true) > P.vehicleSize(20, false), "personal vehicle has larger footprint")
    truthy(P.showPlayerDot(true, 19.99, false), "vanilla red dot below model zoom")
    equal(P.showPlayerDot(true, 20, false), false, "no duplicate dot over vanilla model")
    equal(P.showPlayerDot(false, 18, false), false, "player visibility option respected")
    equal(P.showPlayerDot(true, 18, true), false, "dead players not redrawn")

    local upper = B.fromFields({ x = 10, y = 20, x2 = 18, y2 = 28, minLevel = 0, maxLevel = 1 })
    local lower = B.fromFields({ x = 11, y = 21, x2 = 17, y2 = 27, minLevel = -1, maxLevel = -1 })
    local up = { key = upper.key, x = 12, y = 22, z = 0, stairs = true }
    local down = { key = lower.key, x = 12, y = 23, z = -1 }
    truthy(L.isBasementPassage(up, down), "observed adjacent basement stair passage")
    equal(L.isBasementPassage(nil, down), false, "loading basement is not proof of passage")
    local bad = copy(down); bad.z = 0
    equal(L.isBasementPassage(up, bad), false, "adjacent surface buildings not merged")
    bad = copy(down); bad.x = 60
    equal(L.isBasementPassage(up, bad), false, "remote teleport cannot group buildings")
    bad = copy(up); bad.stairs = false
    equal(L.isBasementPassage(bad, down), false, "floor crossing without stairs is insufficient")
    bad = copy(up); bad.vehicle = true
    equal(L.isBasementPassage(bad, down), false, "vehicle movement cannot group buildings")

    local root = M.migrate({ schemaVersion = 8 })
    equal(root.schemaVersion, 11, "v8 migrates to observed building links and location labels")
    local home = M.enterBuilding(root, upper, 10)
    local cellar = M.enterBuilding(root, lower, 5)
    M.enterBuilding(root, lower, 20)
    home.placeDesignation = "HOME"
    cellar.placeDesignation = "OUTPOST"
    local fields = { x = 11, y = 21, x2 = 15, y2 = 25, z = -1, name = "storage" }
    M.discoverRoom(cellar, B.roomFromFields(lower.key, fields), 5)
    M.observeContainer(home, "up-container", 10)
    M.inspectContainer(home, "up-container", 10)
    M.observeContainer(cellar, "down-container", 5)
    SurvivorMemory.ItemMemory.remember(cellar, { itemType = "Base.NailsBox", displayName = "Nails",
        containerKey = "down-container", quantityObserved = 1, observedAt = 6, textureName = "Item_NailsBox" })
    for _, kind in ipairs({ "GENERATOR", "WOOD_STOVE" }) do
        local placeKey = "building:" .. lower.key
        root.importantMemories[SurvivorMemory.ImportantMemory.key(kind, placeKey)] = {
            kind = kind, placeKey = placeKey, buildingKey = lower.key, x = 12, y = 23, z = -1, observedAt = 5,
        }
    end
    truthy(L.merge(root, lower.key, upper.key), "observed basement merges")
    equal(L.resolve(root, lower.key), upper.key, "basement alias resolves canonical building")
    equal(root.buildings[lower.key], nil, "no second active basement marker")
    equal(home.firstVisited, 5, "earliest historical first visit retained")
    equal(home.lastVisited, 20, "latest historical visit retained")
    equal(home.visitCount, 2, "old stair counters not summed")
    equal(home.roomsKnown[B.roomFromFields(upper.key, fields)], 5, "basement room key uses canonical building")
    equal(home.containersKnown["down-container"], 5, "basement container preserved")
    equal(home.status, "PARTIALLY_SEARCHED", "uninspected basement container affects combined status")
    equal(#SurvivorMemory.ItemMemory.all(home), 1, "basement item memory preserved")
    equal(home.placeDesignation, "HOME", "surface designation wins conflicting old designation")
    equal(root.linkedBuildingHistory[lower.key].placeDesignation, "OUTPOST", "conflicting source data archived")
    equal(root.linkedBuildingHistory[upper.key].firstVisited, 10, "original surface history also archived")
    equal(#SurvivorMemory.ImportantMemory.forBuilding(root, upper.key), 2, "important memories reassociated without skipping entries")
    equal(L.merge(root, lower.key, upper.key), false, "repeat passage merge is idempotent")
    equal(home.visitCount, 2, "repeat link never increments visits")
    local reloaded = M.migrate(copy(root))
    equal(L.resolve(reloaded, lower.key), upper.key, "alias survives reload")
    equal(#SurvivorMemory.ItemMemory.all(reloaded.buildings[upper.key]), 1, "linked item survives reload")
    M.discoverRoom(reloaded.buildings[upper.key], B.roomFromFields(upper.key, fields), 30)
    equal(M.stats(nil, reloaded.buildings[upper.key]).roomsKnown, 1, "room is not duplicated on revisiting basement")
    equal(L.resolve({ buildingAliases = { a = "b", b = "a" }, buildings = {} }, "a"), "a", "corrupt alias cycle terminates safely")
    equal(L.resolve({ buildingAliases = { a = "missing" }, buildings = { a = {} } }, "a"), "a", "dangling alias preserves live original")
    equal(L.resolve(M.migrate(nil), lower.key), lower.key, "new character inherits no building link")

    -- Runtime glue simulation, not a claim of physical in-game stair traversal.
    local sm = {}; for k, v in pairs(SurvivorMemory) do sm[k] = v end
    sm.Runtime = nil
    sm.ModOptions = { enabled = function() return true end, addListener = function() end }
    sm.TimeFormat = { worldAgeHours = function() return 42 end }
    local sent = 0
    local player = { getVehicle = function() return nil end,
        transmitModData = function() sent = sent + 1 end }
    local env = setmetatable({ SurvivorMemory = sm, require = function() end,
        isClient = function() return true end,
        Events = setmetatable({}, { __index = function() return { Add = function() end } end }),
    }, { __index = _G })
    local runtime = assert(loadfile(rootPath .. "/42/media/lua/client/SurvivorMemory/Runtime.lua", "t", env))()
    local function square(identity, z, y)
        local def = { getX = function() return identity.x end, getY = function() return identity.y end,
            getX2 = function() return identity.x2 end, getY2 = function() return identity.y2 end,
            getMinLevel = function() return identity.minLevel end, getMaxLevel = function() return identity.maxLevel end,
            getIDString = function() return "mock" end }
        return { getBuilding = function() return { getDef = function() return def end } end,
            getX = function() return 12 end, getY = function() return y end, getZ = function() return z end,
            HasStairs = function() return true end, HasStairsBelow = function() return false end }
    end
    local runtimeRoot = M.migrate(nil)
    M.enterBuilding(runtimeRoot, upper, 1)
    local state = { initialized = true, buildingKey = upper.key }
    equal(runtime.observeBuildingPassage(player, square(upper, 0, 22), state, runtimeRoot), false, "first position establishes no link")
    truthy(runtime.observeBuildingPassage(player, square(lower, -1, 23), state, runtimeRoot), "runtime links occupied stair squares")
    equal(state.buildingKey, upper.key, "active visit remains surface canonical key")
    equal(runtime.buildingIdentity(runtimeRoot, square(lower, -1, 23):getBuilding()).key, upper.key, "container and room lookup resolves basement")
    local transition = SurvivorMemory.VisitSession.update(state, upper.key, true)
    equal(transition.entered, nil, "stairs are not another entry")
    equal(transition.exited, nil, "stairs are not an exit")
    equal(sent, 1, "link transmits once through character modData")
    equal(runtime.observeBuildingPassage(player, square(upper, 0, 22), state, runtimeRoot), false, "return upstairs reuses link")
    equal(sent, 1, "repeated traversal does not retransmit aliases")

    local dots, zoom, enabled, dead, vehicle = {}, 18, true, false, nil
    local mapPlayer = { getX = function() return 100 end, getY = function() return 200 end,
        isDead = function() return dead end, getVehicle = function() return vehicle end }
    local map = { width = 500, height = 500, mapAPI = {
        getZoomF = function() return zoom end, -- Deliberately no Java renderer API.
        getBoolean = function(_, name) return name == "Players" and enabled end,
        worldToUIX = function(_, x) return x end, worldToUIY = function(_, _, y) return y end,
    }, drawRect = function(_, x, y, w, h) dots[#dots + 1] = { x = x, y = y, w = w, h = h } end }
    local mapEnv = setmetatable({ SurvivorMemory = sm, require = function() end,
        ISWorldMap = {}, getNumActivePlayers = function() return 1 end,
        getSpecificPlayer = function() return mapPlayer end,
    }, { __index = _G })
    local overlay = assert(loadfile(rootPath .. "/42/media/lua/client/SurvivorMemory/WorldMapOverlay.lua", "t", mapEnv))()
    overlay.drawPlayerDots(map)
    equal(#dots, 1, "red dot uses public Lua zoom API only")
    equal(dots[1].x, 97, "red dot centered at projected player x")
    equal(dots[1].h, 6, "red dot matches vanilla dimensions")
    vehicle = { getX = function() return 110 end, getY = function() return 210 end }
    overlay.drawPlayerDots(map)
    equal(dots[2].y, 207, "red dot follows occupied vehicle not stale player coordinates")
    zoom = 20; overlay.drawPlayerDots(map)
    equal(#dots, 2, "model zoom suppresses red dot")
    zoom = 18; enabled = false; overlay.drawPlayerDots(map)
    equal(#dots, 2, "map Players option hides dot")
    enabled = true; dead = true; overlay.drawPlayerDots(map)
    equal(#dots, 2, "runtime dead player omitted")

    dead, vehicle = false, nil
    sm.WorldMapOverlay = nil
    local mapRoot = { revision = 0 }
    sm.MemoryStore = { forModData = function() return mapRoot end }
    sm.ModOptions.value = function(name)
        if name == "markerFocusRadius" then return 50 end
        return sm.Settings.DEFAULTS[name]
    end
    sm.ModOptions.markerScale = function() return 1 end
    mapEnv.getTexture = function(path) return path end
    overlay = assert(loadfile(rootPath .. "/42/media/lua/client/SurvivorMemory/WorldMapOverlay.lua", "t", mapEnv))()
    map.character = mapPlayer
    mapPlayer.getModData = function() return {} end
    map.getMouseX = function() return -1000 end
    map.getMouseY = function() return -1000 end
    map.smMemoryMarkerCache = { root = mapRoot, revision = 0, important = {},
        markers = {
            { centerX = 300, centerY = 200, placeDesignation = "HOME" },
            { centerX = 310, centerY = 200, placeDesignation = "NONE" },
        }, vehicles = {
            { x = 300, y = 210, personal = true },
            { x = 310, y = 210, personal = false },
        },
    }
    local draws = {}
    map.drawTextureScaled = function(_, texture, x, y, w, h, alpha)
        draws[#draws + 1] = { texture = texture, alpha = alpha, size = w }
    end
    map.drawRect = function(_, x, y, w, h, alpha, red, green, blue)
        if w == 6 and red == 1 and green == 0 and blue == 0 then
            draws[#draws + 1] = { dot = true }
        end
    end
    overlay.render(map)
    equal(#draws, 5, "overlay draws four known memories and local player dot")
    equal(draws[1].alpha, 0.25, "ordinary building uses distance opacity in renderer")
    equal(draws[2].alpha, 0.25, "ordinary vehicle fades too")
    equal(draws[3].alpha, 0.85, "home stays prominent in renderer")
    equal(draws[4].alpha, 0.85, "personal vehicle stays prominent in renderer")
    truthy(draws[4].size > draws[2].size, "renderer distinguishes personal vehicle size")
    truthy(draws[5].dot, "player dot rendered after every memory marker")
    equal(overlay.memoryAt(map, 308, 200).placeDesignation, "HOME", "personal building wins overlapping ordinary hit")
    equal(overlay.vehicleAt(map, 308, 210).personal, true, "personal vehicle wins overlapping ordinary hit")

    local options = {}
    mapEnv.next = false -- Kahlua does not expose Lua's next global.
    sm.ModOptions.enabled = function(name) return options[name] ~= false end
    local building = { buildingKey = "badge", centerX = 300, centerY = 200, placeDesignation = "NONE" }
    mapRoot.buildings = { badge = building }
    mapRoot.importantMemories = {}
    map.smMemoryMarkerCache = nil
    local badges = {}
    map.drawRect = function(_, x, y, w, h, alpha, red, green, blue)
        if red == 0.18 and green == 0.48 and blue == 0.70 then
            badges[#badges + 1] = { x = x, y = y, width = w, alpha = alpha }
        end
    end
    local function renderBadgeCount()
        badges = {}
        overlay.render(map)
        return #badges
    end
    equal(renderBadgeCount(), 0, "no badge without remembered objects")
    building.itemMemories = { selected = { displayName = "Stapler" } }
    equal(renderBadgeCount(), 1, "selected item adds one building badge")
    equal(badges[1].alpha, 0.25, "object badge follows marker distance opacity")
    for _, designation in ipairs({ "HOME", "OUTPOST" }) do
        building.placeDesignation = designation
        equal(renderBadgeCount(), 1, "object badge retained on " .. designation)
    end
    options.itemMemory = false
    equal(renderBadgeCount(), 0, "disabled item memories hide their badge")
    options.itemMemory = true
    building.itemMemories.selected = nil
    equal(renderBadgeCount(), 0, "forgetting final item removes badge immediately")
    SurvivorMemory.ImportantMemory.observe(mapRoot, "WOOD_STOVE",
        { buildingKey = "badge", x = 300, y = 200, z = 0 }, 24)
    mapRoot.revision = 1
    equal(renderBadgeCount(), 1, "important object adds badge after memory revision")
    local cache = map.smMemoryMarkerCache
    renderBadgeCount()
    equal(map.smMemoryMarkerCache, cache, "unchanged memories reuse resource presence index")
    options.importantMemory = false
    equal(renderBadgeCount(), 0, "disabled important memories hide their badge")
    building.itemMemories.selected = {}
    equal(renderBadgeCount(), 1, "active selected items still show with important memories disabled")
    options.buildingMarkers, options.personalPlaceMarkers = false, false
    equal(renderBadgeCount(), 0, "hidden building has no detached object badge")
    options.buildingMarkers, options.personalPlaceMarkers = true, true
    options.importantMemory = true
    building.itemMemories = {}
    mapRoot.importantMemories = {}
    mapRoot.revision = 2
    equal(renderBadgeCount(), 0, "resource removal invalidates presence index")
    for _, size in ipairs({ 10, 20, 48 }) do
        badges = {}
        overlay.drawObjectBadge(map, 100, 100, size, 0.5)
        truthy(badges[1].width >= 5 and badges[1].width <= 9, "badge stays compact across marker sizes")
        truthy(badges[1].x >= 100 and badges[1].y >= 100, "badge anchored inside lower-right marker corner")
    end
end
