return function(rootPath, equal, truthy)
    local Reading = require "SurvivorMemory/ReadingMemory"
    local Store = require "SurvivorMemory/MemoryStore"
    local Settings = require "SurvivorMemory/Settings"

    local function item(fullType, category, data, mediaId, mapId)
        local media = mediaId and { getId = function() return mediaId end } or nil
        return {
            getFullType = function() return fullType end,
            getDisplayCategory = function() return category end,
            getMediaData = function() return media end,
            IsMap = function() return mapId ~= nil end,
            getMapID = function() return mapId end,
            IsLiterature = function() return category ~= nil end,
            hasModData = function() return data ~= nil end,
            getModData = function() return data end,
        }
    end

    local carpentry = item("Base.BookCarpentry1", "SkillBook")
    local carpentryCopy = item("Base.BookCarpentry1", "SkillBook")
    local skillTwo = item("Base.BookCarpentry2", "SkillBook")
    local novelA = item("Base.Book", "Literature", { literatureTitle = "Nightfall" })
    local novelB = item("Base.Book", "Literature", { literatureTitle = "Daybreak" })
    local magazine = item("Base.Magazine", "Literature", { literatureTitle = "Garden Issue 4" })
    local brochure = item("Base.Brochure", "Junk", { printMedia = { title = "Shelter" } })
    local mapA = item("Base.Map", nil, nil, nil, "MuldraughMap")
    local mapB = item("Base.Map", nil, nil, nil, "WestpointMap")
    local cdA = item("Base.Disc_Retail", nil, nil, "RM_001")
    local cdB = item("Base.Disc_Retail", nil, nil, "RM_002")
    local vhs = item("Base.VHS_Retail", nil, nil, "RM_VHS_1")
    local recipe = item("Base.HerbalistMag", "RecipeResource")

    equal(Reading.identity(carpentry), Reading.identity(carpentryCopy), "same skill book title")
    truthy(Reading.identity(carpentry) ~= Reading.identity(skillTwo), "skill book volumes differ")
    truthy(Reading.identity(novelA) ~= Reading.identity(novelB), "generated novel titles differ")
    truthy(Reading.identity(mapA) ~= Reading.identity(mapB), "map identities differ")
    truthy(Reading.identity(cdA) ~= Reading.identity(cdB), "CD contents differ")
    truthy(Reading.identity(vhs) ~= Reading.identity(cdA), "VHS and CD differ")
    truthy(Reading.identity(magazine), "titled magazine recognized")
    truthy(Reading.identity(brochure), "print media title recognized")
    truthy(Reading.identity(recipe), "recipe magazine recognized by unique type")
    equal(Reading.identity(item("Base.Book", "Literature")), nil,
        "untitled generic book cannot imply duplicate")
    equal(Reading.identity(item("Base.Disc_Retail")), nil,
        "unknown disc content cannot imply duplicate")
    equal(Reading.identity(item("Base.Map", nil, nil, nil, "")), nil,
        "unidentified map cannot imply duplicate")
    equal(Reading.identity(item("Base.NailsBox")), nil, "ordinary loot is excluded")

    local root = Store.migrate({ schemaVersion = 10, buildings = {}, debug = {} })
    equal(root.schemaVersion, 11, "v10 save migrates to v11")
    truthy(Reading.remember(root, novelA, 24), "first collection is saved")
    equal(Reading.remember(root, novelA, 30), false, "duplicate collection is idempotent")
    equal(root.collectedReading[Reading.identity(novelA)], 24,
        "first collection time stays unchanged")
    equal(Reading.has(root, novelB), false, "another title is not falsely marked")
    truthy(Reading.has(root, novelA), "collected title marked independently of reading")
    local reload = Store.migrate({ schemaVersion = 11,
        collectedReading = { [Reading.identity(novelA)] = 24 }, buildings = {}, debug = {} })
    truthy(Reading.has(reload, novelA), "collection survives reload")
    equal(Reading.has(Store.migrate(nil), novelA), false, "new character has no inherited collection")
    reload.collectedReading.invalid = 1
    reload.collectedReading[Reading.identity(cdA)] = 0 / 0
    reload.collectedReading[Reading.identity(mapA)] = math.huge
    Reading.initialize(reload)
    equal(reload.collectedReading.invalid, nil, "corrupt key removed")
    equal(reload.collectedReading[Reading.identity(cdA)], nil, "corrupt timestamp removed")
    equal(reload.collectedReading[Reading.identity(mapA)], nil, "infinite timestamp removed")
    truthy(Reading.has(reload, novelA), "valid sibling survives sanitation")
    equal(Reading.remember(reload, cdA, math.huge), false,
        "invalid world age cannot create a collection")
    equal(Settings.enabled({ readingMemoryEnabled = false }, "readingMemory"), false,
        "native option disables collection memory")
    equal(Settings.enabled({ buildingMemoryEnabled = false }, "readingMemory"), true,
        "collection memory does not depend on a building")

    local sm = {}
    for key, value in pairs(SurvivorMemory) do sm[key] = value end
    sm.Runtime = nil
    local values, sent = {}, 0
    sm.ModOptions = { enabled = function(feature) return Settings.enabled(values, feature) end,
        addListener = function() end }
    sm.TimeFormat = { worldAgeHours = function() return 42 end }
    local data = {}
    local carried = {}
    local inventory = { getItems = function() return {
        size = function() return #carried end,
        get = function(_, index) return carried[index + 1] end,
    } end }
    local player = { getPlayerNum = function() return 0 end,
        isLocalPlayer = function() return true end,
        getInventory = function() return inventory end,
        getModData = function() return data end,
        transmitModData = function() sent = sent + 1 end }
    local external = { getOutermostContainer = function(self) return self end }
    local transferred = false
    inventory.contains = function(_, object) return transferred and object == cdA end
    local env = setmetatable({ SurvivorMemory = sm,
        getSpecificPlayer = function() return player end,
        instanceof = function(object, class)
            return class == "InventoryContainer" and object.isBag == true
        end,
        isClient = function() return true end,
        Events = setmetatable({}, { __index = function() return { Add = function() end } end }),
        require = function() end,
    }, { __index = _G })
    local runtime = assert(loadfile(rootPath .. "/42/media/lua/client/SurvivorMemory/Runtime.lua", "t", env))()
    equal(runtime.observeReadingTransfer(player, external, inventory, cdA), false,
        "unfinished transfer does not create memory")
    transferred = true
    truthy(runtime.observeReadingTransfer(player, external, inventory, cdA),
        "completed transfer creates personal memory")
    equal(sent, 1, "completed transfer syncs once")
    equal(runtime.observeReadingTransfer(player, external, inventory, cdA), false,
        "repeat transfer does not resync")
    inventory.contains = function(_, object) return object == cdA or object == mapB end
    truthy(runtime.observeReadingTransfer(player, inventory, inventory, mapB),
        "title first encountered during carried move is still observed")
    truthy(runtime.hasCollectedReadingItem(player, cdA), "runtime exposes collected media")
    equal(runtime.hasCollectedReadingItem(player, cdB), false,
        "runtime does not mark another CD title")

    local bagContents = { novelA, mapA }
    local bag = { isBag = true, getFullType = function() return "Base.Bag" end,
        getMediaData = function() return nil end,
        IsMap = function() return false end, IsLiterature = function() return false end,
        getInventory = function() return { getItems = function() return {
        size = function() return #bagContents end,
        get = function(_, index) return bagContents[index + 1] end,
    } end } end }
    carried[1] = bag
    truthy(runtime.observeCarriedReading(player), "carried bag contents observed on load")
    equal(sent, 3, "one load scan batches persistence sync")
    truthy(runtime.hasCollectedReadingItem(player, novelA), "unread book from bag is marked")
    truthy(runtime.hasCollectedReadingItem(player, mapA), "map from bag is marked")
    values.readingMemoryEnabled = false
    equal(runtime.hasCollectedReadingItem(player, novelA), false,
        "disabled option hides mark without deleting memory")
    values.readingMemoryEnabled = true
    truthy(runtime.hasCollectedReadingItem(player, novelA), "re-enabled option restores mark")

    local drawn = 0
    local iconEnv = setmetatable({ SurvivorMemory = sm,
        ISInventoryItem = { renderItemIcon = function() end },
        getSpecificPlayer = function() return player end,
        Events = { OnGameStart = { Add = function() end } },
        require = function() end,
    }, { __index = _G })
    local indicator = assert(loadfile(rootPath
        .. "/42/media/lua/client/SurvivorMemory/ReadingMemoryIndicator.lua", "t", iconEnv))()
    indicator.install()
    local pane = { Type = "ISInventoryPane", player = 0,
        drawRect = function() drawn = drawn + 1 end,
        drawRectBorder = function() drawn = drawn + 1 end }
    iconEnv.ISInventoryItem.renderItemIcon(pane, novelA, 0, 0, 1, 32, 32)
    truthy(drawn > 0, "collected unread book receives inventory mark")
    drawn = 0
    iconEnv.ISInventoryItem.renderItemIcon(pane, novelB, 0, 0, 1, 32, 32)
    equal(drawn, 0, "new title receives no mark")
end
