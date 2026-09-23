return function(rootPath, equal, truthy)
    local manager = { getFontHeight = function(_, font) return font == "medium" and 20 or 16 end,
        MeasureStringX = function(_, _, text) return (utf8.len(text) or #text) * 8 end }
    local env = setmetatable({ SurvivorMemory = {}, UIFont = { Small = "small", Medium = "medium" },
        getTextManager = function() return manager end,
        getTexture = function(path) return { splitIcon = function() return path .. ":trimmed" end } end,
        getText = function(key, value) return key == "IGUI_SM_MoreTooltipEntries" and "+ " .. value or key end,
    }, { __index = _G })
    local tooltip = assert(loadfile(rootPath .. "/42/media/lua/client/SurvivorMemory/MapTooltip.lua", "t", env))()
    equal(table.concat(tooltip.wrap("Boîte de clous", "small", 300), " "), "Boîte de clous", "tooltip keeps short translated name")
    local chinese = "记得这里有一个古董炉子"
    local wrapped = tooltip.wrap(chinese, "small", 40)
    truthy(#wrapped > 1, "Chinese tooltip wraps without spaces")
    equal(table.concat(wrapped), chinese, "Chinese characters preserved while wrapping")
    local cyrillic = "Автомобиль"
    equal(table.concat(tooltip.wrap(cyrillic, "small", 24)), cyrillic, "Cyrillic characters preserved")
    equal(tooltip.importantIcon("GENERATOR"), "Item_Generator:trimmed", "generator uses vanilla inventory icon")
    equal(tooltip.importantIcon("WOOD_STOVE"), "appliances_cooking_01_16:trimmed", "stove uses trimmed vanilla tile")
    equal(tooltip.importantIcon("GAS_PUMP"), "location_shop_fossoil_01_12:trimmed", "pump uses trimmed vanilla tile")
    equal(tooltip.importantIcon("UNKNOWN"), nil, "unknown category has no invented icon")
    local rows = {
        { text = "Race Car", title = true },
        { text = "Personal vehicle", color = tooltip.ACCENT },
        { text = "Fuel: tank looked full", divider = true },
        { text = "Condition: roadworthy" },
        { text = "Last seen: today", divider = true, color = tooltip.MUTED },
    }
    local layout = tooltip.layout(rows, 960, 720)
    equal(#layout.blocks, 5, "vehicle tooltip retains all observed fields")
    equal(layout.blocks[1].font, "medium", "title has stronger visual hierarchy")
    equal(layout.blocks[3].row.divider, true, "details separated from identity")
    equal(layout.blocks[5].row.color, tooltip.MUTED, "observation age is secondary text")
    local long = { text = string.rep("Long translated item name ", 8), icon = "item", detail = "Last seen yesterday" }
    layout = tooltip.layout({ long }, 300, 720)
    truthy(layout.width <= 288, "long names stay inside narrow map")
    truthy(#layout.blocks[1].lines > 1, "long name wraps rather than clipping")
    for _, line in ipairs(layout.blocks[1].lines) do
        truthy(manager:MeasureStringX("small", line) <= layout.width - 62, "wrapped line reserves icon gutter")
    end
    local crowded = {}; for i = 1, 30 do crowded[i] = { text = "Memory " .. i, detail = "Last seen today" } end
    layout = tooltip.layout(crowded, 300, 240)
    truthy(layout.height <= 228, "many memories stay within map height")
    truthy(#layout.blocks < #crowded, "overflow limits complete rows")
    truthy(layout.blocks[#layout.blocks].row.text:find("+ ", 1, true), "overflow has explicit count")
    local visibleBlocks = #layout.blocks - 1
    crowded[#crowded] = { text = "100 other memories", count = 100 }
    layout = tooltip.layout(crowded, 300, 240)
    equal(layout.blocks[#layout.blocks].row.text, "+ " .. (#crowded - visibleBlocks + 99),
        "overflow preserves counts of already summarized memories")
    local bounds
    local map = { width = 300, height = 240, drawRect = function(_, x, y, w, h)
        bounds = bounds or { x = x, y = y, w = w, h = h }
    end, drawRectBorder = function() end, drawText = function() end, drawTextureScaledAspect = function() end }
    tooltip.draw(map, rows, 299, 239)
    truthy(bounds.x >= 0 and bounds.y >= 0 and bounds.x + bounds.w <= map.width
        and bounds.y + bounds.h <= map.height, "tooltip clamped at bottom-right edge")
    env.getTexture = function() return nil end
    equal(tooltip.importantIcon("WOOD_STOVE"), nil, "missing texture degrades to text")

    -- Test the production row composition without querying any world objects.
    local sm = {}; for k, v in pairs(SurvivorMemory) do sm[k] = v end
    local captured
    sm.WorldMapOverlay = nil
    sm.MapTooltip = { ACCENT = tooltip.ACCENT, MUTED = tooltip.MUTED,
        importantIcon = function(kind) return "icon:" .. kind end,
        draw = function(_, values) captured = values end }
    sm.ModOptions = { enabled = function() return true end }
    sm.TimeFormat = { worldAgeHours = function() return 100 end, age = function() return "yesterday" end }
    local root = { importantMemories = {} }
    sm.MemoryStore = { forModData = function() return root end }
    sm.Runtime = { mayHaveLootRespawned = function() return false end }
    local overlayEnv = setmetatable({ SurvivorMemory = sm, ISWorldMap = {}, require = function() end,
        getText = function(key, a, b) return key .. (a and ":" .. a or "") .. (b and ":" .. b or "") end,
    }, { __index = env })
    local overlay = assert(loadfile(rootPath .. "/42/media/lua/client/SurvivorMemory/WorldMapOverlay.lua", "t", overlayEnv))()
    overlay.drawVehicleTooltip({}, { displayName = "Car", personal = true, observedAt = 24 }, 0, 0)
    equal(#captured, 3, "unknown fuel and condition not invented")
    equal(captured[1].title, true, "vehicle name is the title")
    equal(captured[3].divider, true, "last seen separated even without vehicle details")
    overlay.drawImportantTooltip({}, { kind = "WOOD_STOVE", observedAt = 24 }, 0, 0)
    equal(captured[1].icon, "icon:WOOD_STOVE", "outdoor important tooltip includes icon")
    sm.ImportantMemory.observe(root, "WOOD_STOVE", { buildingKey = "home", x = 1, y = 2, z = 0 }, 24)
    overlay.drawBuildingTooltip({ character = { getModData = function() return {} end } },
        { buildingKey = "home", status = "VISITED", lastVisited = 24, placeDesignation = "NONE" }, 0, 0)
    equal(captured[#captured].icon, "icon:WOOD_STOVE", "building tooltip includes important object icon")
    truthy(captured[#captured].detail:find("yesterday", 1, true), "important observation date is separate detail")
    overlay.drawBuildingTooltip({ character = { getModData = function() return {} end } },
        { buildingKey = "mixed", status = "VISITED", lastVisited = 24,
            locationKinds = { MEDICAL = true, WAREHOUSE = true }, placeDesignation = "NONE" }, 0, 0)
    equal(captured[1].text, "IGUI_SM_Location_MEDICAL / IGUI_SM_Location_WAREHOUSE",
        "map tooltip title retains every observed location label")
    layout = tooltip.layout({ { text = "Medical building / Warehouse / Office building", title = true } }, 270, 400)
    truthy(#layout.blocks[1].lines > 1, "multi-label title wraps on a narrow map")
end
