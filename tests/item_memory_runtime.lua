-- Simulated runtime glue: the deterministic model is exercised separately.
return function(rootPath, equal, truthy)
    local sm = {}
    for key, value in pairs(SurvivorMemory) do sm[key] = value end
    local values, sent = {}, 0
    sm.Runtime = nil
    sm.ModOptions = { enabled = function(feature) return sm.Settings.enabled(values, feature) end,
        addListener = function() end }
    sm.TimeFormat = { worldAgeHours = function() return 42 end }
    local data = {}
    local playerSquare = { getX = function() return 10 end, getY = function() return 20 end,
        getZ = function() return 0 end }
    local player = { getPlayerNum = function() return 0 end,
        isLocalPlayer = function() return true end,
        getModData = function() return data end, getCurrentSquare = function() return playerSquare end,
        transmitModData = function() sent = sent + 1 end }
    local def = { getX = function() return 10 end, getY = function() return 20 end,
        getX2 = function() return 15 end, getY2 = function() return 25 end,
        getMinLevel = function() return 0 end, getMaxLevel = function() return 1 end,
        getIDString = function() return "mock" end }
    local building = { getDef = function() return def end }
    local square = { getX = function() return 11 end, getY = function() return 20 end,
        getZ = function() return 0 end, getBuilding = function() return building end }
    local container
    local parent = { getObjectIndex = function() return 1 end,
        getContainerCount = function() return 1 end,
        getContainerByIndex = function() return container end,
        getSpriteName = function() return "mock_shelf" end }
    container = { getSourceGrid = function() return square end, getParent = function() return parent end,
        isVehiclePart = function() return false end, getContainingItem = function() return nil end,
        getType = function() return "shelves" end }
    local visible, currentContainer = true, container
    local loot = { isReallyVisible = function() return visible end,
        inventoryPane = { inventory = container } }
    local item = { getContainer = function() return currentContainer end,
        getFullType = function() return "Base.NailsBox" end,
        getName = function() return "Box of Nails" end, getCount = function() return 1 end,
        getTex = function() return { getName = function() return "Item_NailsBox" end } end }
    local env = setmetatable({ SurvivorMemory = sm, getSpecificPlayer = function() return player end,
        getPlayerLoot = function() return loot end, instanceof = function(obj, class)
            return obj == item and class == "InventoryItem" end,
        isClient = function() return true end,
        Events = setmetatable({}, { __index = function() return { Add = function() end } end }),
        require = function() end,
    }, { __index = _G })
    local runtime = assert(loadfile(rootPath .. "/42/media/lua/client/SurvivorMemory/Runtime.lua", "t", env))()
    equal(runtime.rememberItems(0, { item }), false, "runtime refuses item in unvisited building")
    local store = sm.MemoryStore.forModData(data)
    local identity = sm.BuildingIdentity.fromBuilding(building)
    local memory = sm.MemoryStore.enterBuilding(store, identity, 1)
    truthy(runtime.rememberItems(0, { item }), "runtime accepts selected visible local loot item")
    equal(sent, 1, "item selection transmits only owner modData once")
    equal(#sm.ItemMemory.all(memory), 1, "runtime stores one selected item")
    equal(memory.status, "VISITED", "manual item action preserves exploration status")
    visible = false
    equal(runtime.rememberItems(0, { item }), false, "closed loot UI cannot create item memory")
    visible = true
    loot.isCollapsed = true
    equal(runtime.rememberItems(0, { item }), false, "collapsed loot UI cannot create item memory")
    loot.isCollapsed = false
    currentContainer = {}
    equal(runtime.rememberItems(0, { item }), false, "item moved after menu opened cannot be remembered here")
    currentContainer = container
    playerSquare.getX = function() return 100 end
    equal(runtime.rememberItems(0, { item }), false, "remote container cannot be remembered")
    playerSquare.getX = function() return 10 end
    playerSquare.getZ = function() return 1 end
    equal(runtime.rememberItems(0, { item }), false, "other floor cannot be remembered")
    playerSquare.getZ = function() return 0 end
    values.itemMemoryEnabled = false
    equal(runtime.rememberItems(0, { item }), false, "disabled module refuses selection")
    equal(#sm.ItemMemory.all(memory), 1, "disabling module preserves remembered item")
    equal(sent, 1, "rejected observations produce no MP traffic")
    values.itemMemoryEnabled = true
    local key = sm.ItemMemory.key(sm.ContainerIdentity.fromContainer(container), "Base.NailsBox")
    truthy(runtime.forgetItem(0, identity.key, key), "manual forget works through runtime")
    equal(#sm.ItemMemory.all(memory), 0, "manual forget removes item memory")
    equal(sent, 2, "manual forgetting syncs character memory")
end
