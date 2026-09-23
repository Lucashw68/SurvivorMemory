require "ISUI/Maps/ISWorldMap"
require "ISUI/ISContextMenu"
require "SurvivorMemory/UICompat"
require "SurvivorMemory/Runtime"
require "SurvivorMemory/MemoryStore"
require "SurvivorMemory/TimeFormat"
require "SurvivorMemory/LocationName"
require "SurvivorMemory/StatusPresentation"
require "SurvivorMemory/PlaceDesignation"
require "SurvivorMemory/ImportantMemory"
require "SurvivorMemory/VehicleMemory"
require "SurvivorMemory/BuildingMarkerSelection"
require "SurvivorMemory/ModOptions"
require "SurvivorMemory/MapPresentation"
require "SurvivorMemory/MapTooltip"

SurvivorMemory = SurvivorMemory or {}
SurvivorMemory.WorldMapOverlay = SurvivorMemory.WorldMapOverlay or {}

local Overlay = SurvivorMemory.WorldMapOverlay
local MemoryStore = SurvivorMemory.MemoryStore
local TimeFormat = SurvivorMemory.TimeFormat
local LocationName = SurvivorMemory.LocationName
local StatusPresentation = SurvivorMemory.StatusPresentation
local UICompat = SurvivorMemory.UICompat
local PlaceDesignation = SurvivorMemory.PlaceDesignation
local Runtime = SurvivorMemory.Runtime
local ImportantMemory = SurvivorMemory.ImportantMemory
local VehicleMemory = SurvivorMemory.VehicleMemory
local BuildingMarkerSelection = SurvivorMemory.BuildingMarkerSelection
local ModOptions = SurvivorMemory.ModOptions
local ItemMemory = SurvivorMemory.ItemMemory
local Presentation = SurvivorMemory.MapPresentation
local MapTooltip = SurvivorMemory.MapTooltip

local ICON_PATHS = {
    NONE = "media/ui/SurvivorMemory/map-memory-marker.png",
    HOME = "media/ui/SurvivorMemory/map-home-marker.png",
    OUTPOST = "media/ui/SurvivorMemory/map-outpost-marker.png",
}
local VEHICLE_ICON_PATH = "media/ui/SurvivorMemory/map-vehicle-marker.png"

function Overlay.iconPathFor(memory)
    return ICON_PATHS[PlaceDesignation.normalize(memory and memory.placeDesignation)] or ICON_PATHS.NONE
end

function Overlay.markerSizeFor(memory, baseSize)
    local designation = PlaceDesignation.normalize(memory and memory.placeDesignation)
    if designation == PlaceDesignation.OUTPOST then
        return math.floor(baseSize * 1.65 + 0.5)
    end
    if designation == PlaceDesignation.HOME then
        return math.floor(baseSize * 1.30 + 0.5)
    end
    return baseSize
end

local function baseMarkerSize(map)
    local base = math.max(16, math.min(26, math.floor(14 + map.mapAPI:getZoomF() * 0.45)))
    return math.max(10, math.floor(base * ModOptions.markerScale() + 0.5))
end

local function displayIconPathFor(memory)
    if ModOptions.enabled("places")
            and ModOptions.enabled("personalPlaceMarkers")
            and PlaceDesignation.isPersonalPlace(memory and memory.placeDesignation) then
        return Overlay.iconPathFor(memory)
    end
    return ICON_PATHS.NONE
end

local function shouldShowBuilding(memory)
    local personal = ModOptions.enabled("places")
        and PlaceDesignation.isPersonalPlace(memory and memory.placeDesignation)
    if personal and ModOptions.enabled("personalPlaceMarkers") then return true end
    return ModOptions.enabled("buildingMarkers")
end

local function displayMarkerSizeFor(memory, baseSize)
    if ModOptions.enabled("places") and ModOptions.enabled("personalPlaceMarkers")
            and PlaceDesignation.isPersonalPlace(memory and memory.placeDesignation) then
        return Overlay.markerSizeFor(memory, baseSize)
    end
    return baseSize
end

local function personalBuilding(memory)
    return ModOptions.enabled("places") and ModOptions.enabled("personalPlaceMarkers")
        and PlaceDesignation.isPersonalPlace(memory.placeDesignation)
end

local function markerOpacity(map, x, y, personal, hovered)
    return Presentation.opacity(x, y, map.character:getX(), map.character:getY(),
        ModOptions.value("markerFocusRadius"), ModOptions.enabled("fadeDistantMarkers"), personal, hovered)
end

local function markersFor(map, root)
    local revision = tonumber(root.revision) or 0
    local cache = map.smMemoryMarkerCache
    if cache and cache.root == root and cache.revision == revision then return cache.markers end
    local markers = BuildingMarkerSelection.select(root.buildings)
    local importantBuildings = {}
    for _, observation in pairs(root.importantMemories or {}) do
        if observation.buildingKey then importantBuildings[observation.buildingKey] = true end
    end
    map.smMemoryMarkerCache = {
        root = root,
        revision = revision,
        markers = markers,
        important = ImportantMemory.outdoor(root),
        importantBuildings = importantBuildings,
        vehicles = VehicleMemory.all(root),
    }
    return markers
end

local function vehicleMarkersFor(map, root)
    markersFor(map, root)
    return map.smMemoryMarkerCache.vehicles or {}
end

local function importantMarkersFor(map, root)
    markersFor(map, root)
    return map.smMemoryMarkerCache.important or {}
end

-- Presence of remembered observations, never a claim about current loot.
-- The resource index shares the revision cache; item presence is an O(1) lookup.
function Overlay.hasObjectBadge(map, memory)
    if ModOptions.enabled("itemMemory") and type(memory.itemMemories) == "table" then
        -- B42/Kahlua exposes pairs, but not the standard Lua next global.
        for _ in pairs(memory.itemMemories) do return true end
    end
    local cache = map.smMemoryMarkerCache
    return ModOptions.enabled("importantMemory") and cache ~= nil
        and cache.importantBuildings ~= nil and cache.importantBuildings[memory.buildingKey] == true
end

function Overlay.drawObjectBadge(map, left, top, markerSize, alpha)
    local size = math.max(7, math.min(11, math.floor(markerSize * 0.40 + 0.5)))
    local x, y = left + markerSize - size + 1, top + markerSize - size + 1
    map:drawRect(x, y, size, size, alpha, 0.06, 0.08, 0.12)
    map:drawRect(x + 1, y + 1, size - 2, size - 2, alpha, 0.18, 0.48, 0.70)
    local center = math.floor(size / 2)
    map:drawRect(x + 2, y + center, size - 4, 1, alpha, 1, 1, 1)
    map:drawRect(x + center, y + 2, 1, size - 4, alpha, 1, 1, 1)
end

function Overlay.memoryAt(map, mouseX, mouseY)
    if not ModOptions.enabled("worldMap") or map.smMemoryOverlayEnabled == false
            or not map.character or not map.mapAPI then return nil end
    local root = MemoryStore.forModData(map.character:getModData())
    local baseSize = baseMarkerSize(map)
    local closest, closestDistance
    for _, memory in ipairs(markersFor(map, root)) do
        if shouldShowBuilding(memory) and getTexture(displayIconPathFor(memory)) then
            local x = map.mapAPI:worldToUIX(memory.centerX, memory.centerY)
            local y = map.mapAPI:worldToUIY(memory.centerX, memory.centerY)
            local radius = displayMarkerSizeFor(memory, baseSize) / 2 + 3
            local dx, dy = mouseX - x, mouseY - y
            local distance = dx * dx + dy * dy
            local personal = personalBuilding(memory)
            if distance <= radius * radius and (not closest
                    or (personal and not personalBuilding(closest))
                    or (personal == personalBuilding(closest) and distance < closestDistance)) then
                closest, closestDistance = memory, distance
            end
        end
    end
    return closest
end

function Overlay.vehicleAt(map, mouseX, mouseY)
    if not ModOptions.enabled("vehicleMarkers") or map.smMemoryOverlayEnabled == false
            or not map.character or not map.mapAPI then return nil end
    local root = MemoryStore.forModData(map.character:getModData())
    local closest, closestDistance
    for _, observation in ipairs(vehicleMarkersFor(map, root)) do
        local size = Presentation.vehicleSize(baseMarkerSize(map), observation.personal)
        local x = map.mapAPI:worldToUIX(observation.x, observation.y)
        local y = map.mapAPI:worldToUIY(observation.x, observation.y)
        local dx, dy = mouseX - x, mouseY - y
        local distance = dx * dx + dy * dy
        local radius = size / 2 + 3
        local personal = observation.personal == true
        if distance <= radius * radius and (not closest
                or (personal and closest.personal ~= true)
                or (personal == (closest.personal == true) and distance < closestDistance)) then
            closest, closestDistance = observation, distance
        end
    end
    return closest
end

function Overlay.showPlaceContextMenu(map, memory, x, y)
    if not map or not memory or not map.character then return false end
    local playerNum = map.character:getPlayerNum()
    local context = ISContextMenu.get(playerNum, x + map:getAbsoluteX(), y + map:getAbsoluteY())
    local current = PlaceDesignation.normalize(memory.placeDesignation)
    local choices = {
        { PlaceDesignation.HOME, "IGUI_SM_MapMarkHome" },
        { PlaceDesignation.OUTPOST, "IGUI_SM_MapMarkOutpost" },
        { PlaceDesignation.NONE, "IGUI_SM_MapClearPlace" },
    }
    for _, choice in ipairs(ModOptions.enabled("placeDesignations") and choices or {}) do
        local option = context:addOption(getText(choice[2]), playerNum,
            Runtime.setPlaceDesignation, memory.buildingKey, choice[1])
        context:setOptionChecked(option, current == choice[1])
    end
    if ModOptions.enabled("itemMemory") and #ItemMemory.all(memory) > 0 then
        local option = context:addOption(getText("IGUI_SM_ForgetItemMenu"), nil, nil)
        local subMenu = ISContextMenu:getNew(context)
        context:addSubMenu(option, subMenu)
        for _, entry in ipairs(ItemMemory.all(memory)) do
            local observation = entry.observation
            subMenu:addOption(getText("IGUI_SM_ItemLastSeen", observation.displayName,
                observation.quantityObserved, TimeFormat.age(TimeFormat.worldAgeHours(), observation.observedAt)),
                playerNum, Runtime.forgetItem, memory.buildingKey, entry.key)
        end
    end
    return true
end

function Overlay.showVehicleContextMenu(map, observation, x, y)
    if not map or not observation or not map.character then return false end
    local playerNum = map.character:getPlayerNum()
    local context = ISContextMenu.get(playerNum, x + map:getAbsoluteX(), y + map:getAbsoluteY())
    local personal = observation.personal == true
    context:addOption(getText(personal and "IGUI_SM_VehicleClearPersonal"
        or "IGUI_SM_VehicleMarkPersonal"), playerNum,
        Runtime.setVehiclePersonal, observation.vehicleKey, not personal)
    return true
end

function Overlay.drawBuildingTooltip(map, memory, x, y)
    local rows = { { text = LocationName.text(memory), title = true } }
    if ModOptions.enabled("places") and PlaceDesignation.isPersonalPlace(memory.placeDesignation) then
        rows[#rows + 1] = { text = getText("IGUI_SM_Place_" .. PlaceDesignation.normalize(memory.placeDesignation)),
            color = MapTooltip.ACCENT }
    end
    rows[#rows + 1] = { text = StatusPresentation.text(memory.status),
        color = StatusPresentation.color(memory.status), divider = true }
    rows[#rows + 1] = { text = getText("IGUI_SM_MapLastVisited",
        TimeFormat.age(TimeFormat.worldAgeHours(), memory.lastVisited)), color = MapTooltip.MUTED }
    if Runtime.mayHaveLootRespawned(memory) then
        rows[#rows + 1] = { text = getText("IGUI_SM_LootRespawnPossible"), color = MapTooltip.ACCENT }
    end
    if ModOptions.enabled("emotionalMemory") and memory.emotionalMemory then
        rows[#rows + 1] = { text = getText("IGUI_SM_EmotionalMemory"), color = MapTooltip.MUTED }
    end
    local root = MemoryStore.forModData(map.character:getModData())
    local firstObservation = true
    if ModOptions.enabled("importantMemory") then
        for _, observation in ipairs(ImportantMemory.forBuilding(root, memory.buildingKey)) do
            rows[#rows + 1] = { text = getText("IGUI_SM_Important_" .. observation.kind),
                icon = MapTooltip.importantIcon(observation.kind), divider = firstObservation,
                detail = getText("IGUI_SM_ImportantMapLastSeen",
                    TimeFormat.age(TimeFormat.worldAgeHours(), observation.observedAt)) }
            firstObservation = false
        end
    end
    if ModOptions.enabled("itemMemory") then
        local items = ItemMemory.all(memory)
        for index = 1, math.min(#items, 6) do
            local observation = items[index].observation
            rows[#rows + 1] = { text = getText("IGUI_SM_ItemQuantity",
                    observation.displayName, observation.quantityObserved),
                icon = observation.textureName and getTexture(observation.textureName) or nil,
                divider = firstObservation,
                detail = getText("IGUI_SM_VehicleMapLastSeen",
                    TimeFormat.age(TimeFormat.worldAgeHours(), observation.observedAt)) }
            firstObservation = false
        end
        if #items > 6 then
            rows[#rows + 1] = { text = getText("IGUI_SM_MoreItemMemories", #items - 6),
                count = #items - 6, color = MapTooltip.MUTED }
        end
    end
    return MapTooltip.draw(map, rows, x, y)
end

function Overlay.drawImportantTooltip(map, observation, x, y)
    return MapTooltip.draw(map, {
        { text = getText("IGUI_SM_Important_" .. observation.kind), title = true,
            icon = MapTooltip.importantIcon(observation.kind) },
        { text = getText("IGUI_SM_ImportantMapLastSeen",
            TimeFormat.age(TimeFormat.worldAgeHours(), observation.observedAt)),
            color = MapTooltip.MUTED, divider = true },
    }, x, y)
end

local function drawVehicleMarker(map, x, y, size, alpha, personal)
    local left, top = math.floor(x - size / 2), math.floor(y - size / 2)
    local texture = getTexture(VEHICLE_ICON_PATH)
    if texture then map:drawTextureScaled(texture, left, top, size, size, alpha, 1, 1, 1) end
    if personal then
        map:drawRect(left + size - 7, top + size - 7, 7, 7, alpha, 0.08, 0.08, 0.08)
        map:drawRect(left + size - 6, top + size - 6, 5, 5, alpha, 0.95, 0.79, 0.35)
    end
end

-- B42 UIWorldMap.renderLocalPlayers is private and runs before the Lua
-- overlay. Reproduce only its local 6px red dot, with the same visibility rule.
function Overlay.drawPlayerDots(map)
    -- UIWorldMapV1.getZoomF delegates to getDisplayZoomF. The renderer itself
    -- is not exposed to Lua even though its Java method is public.
    local zoom = map.mapAPI:getZoomF()
    for playerNum = 0, getNumActivePlayers() - 1 do
        local player = getSpecificPlayer(playerNum)
        if player and Presentation.showPlayerDot(map.mapAPI:getBoolean("Players"), zoom, player:isDead()) then
            local location = player:getVehicle() or player
            local x = math.floor(map.mapAPI:worldToUIX(location:getX(), location:getY()))
            local y = math.floor(map.mapAPI:worldToUIY(location:getX(), location:getY()))
            if x >= 3 and y >= 3 and x <= map.width - 3 and y <= map.height - 3 then
                map:drawRect(x - 3, y - 3, 6, 6, 1, 1, 0, 0)
            end
        end
    end
end

function Overlay.drawVehicleTooltip(map, observation, x, y)
    local rows = { { text = observation.displayName or getText("IGUI_SM_GenericVehicle"), title = true } }
    if observation.personal then
        rows[#rows + 1] = { text = getText("IGUI_SM_VehiclePersonal"), color = MapTooltip.ACCENT }
    end
    if observation.fuelState then
        rows[#rows + 1] = { text = getText("IGUI_SM_VehicleFuel_" .. observation.fuelState), divider = true }
    end
    if observation.vehicleCondition then
        rows[#rows + 1] = { text = getText("IGUI_SM_VehicleCondition_" .. observation.vehicleCondition),
            divider = not observation.fuelState }
    end
    rows[#rows + 1] = { text = getText("IGUI_SM_VehicleMapLastSeen",
        TimeFormat.age(TimeFormat.worldAgeHours(), observation.observedAt)),
        color = MapTooltip.MUTED, divider = true }
    return MapTooltip.draw(map, rows, x, y)
end

function Overlay.render(map)
    if map.smMemoryToggle then map.smMemoryToggle:setVisible(ModOptions.enabled("worldMap")) end
    if not ModOptions.enabled("worldMap") or map.smMemoryOverlayEnabled == false
            or not map.character or not map.mapAPI then return end
    local root = MemoryStore.forModData(map.character:getModData())
    local markers = markersFor(map, root)
    local size = baseMarkerSize(map)
    local mouseX, mouseY = map:getMouseX(), map:getMouseY()
    local hovered, hoveredX, hoveredY
    local importantHovered, importantX, importantY
    local vehicleHovered, vehicleX, vehicleY
    local hoverKind
    for pass = 1, 2 do
        for _, memory in ipairs(markers) do
            local texture = getTexture(displayIconPathFor(memory))
            local markerSize = displayMarkerSizeFor(memory, size)
            local x = map.mapAPI:worldToUIX(memory.centerX, memory.centerY)
            local y = map.mapAPI:worldToUIY(memory.centerX, memory.centerY)
            local personal = personalBuilding(memory)
            if personal == (pass == 2) and shouldShowBuilding(memory) and texture and x >= markerSize and y >= markerSize
                    and x <= map.width - markerSize and y <= map.height - markerSize then
                local left, top = math.floor(x - markerSize / 2), math.floor(y - markerSize / 2)
                local hit = math.abs(mouseX - x) <= markerSize / 2 + 3
                    and math.abs(mouseY - y) <= markerSize / 2 + 3
                local alpha = markerOpacity(map, memory.centerX, memory.centerY, personal, hit)
                map:drawTextureScaled(texture, left, top, markerSize, markerSize, alpha, 1, 1, 1)
                if Overlay.hasObjectBadge(map, memory) then
                    Overlay.drawObjectBadge(map, left, top, markerSize, alpha)
                end
                if hit then
                    hovered, hoveredX, hoveredY = memory, x, y
                    hoverKind = "building"
                end
            end
        end
        local importantTexture = getTexture(ICON_PATHS.NONE)
        local importantSize = math.max(14, math.floor(size * 0.90))
        for _, observation in ipairs(pass == 1 and ModOptions.enabled("importantMarkers")
                and importantMarkersFor(map, root) or {}) do
            local x = map.mapAPI:worldToUIX(observation.x, observation.y)
            local y = map.mapAPI:worldToUIY(observation.x, observation.y)
            if importantTexture and x >= importantSize and y >= importantSize
                    and x <= map.width - importantSize and y <= map.height - importantSize then
                local hit = math.abs(mouseX - x) <= importantSize / 2 + 3
                    and math.abs(mouseY - y) <= importantSize / 2 + 3
                map:drawTextureScaled(importantTexture, math.floor(x - importantSize / 2),
                    math.floor(y - importantSize / 2), importantSize, importantSize,
                    markerOpacity(map, observation.x, observation.y, false, hit), 0.92, 0.82, 0.62)
                if hit then
                    importantHovered, importantX, importantY = observation, x, y
                    hoverKind = "important"
                end
            end
        end
        for _, observation in ipairs(ModOptions.enabled("vehicleMarkers")
                and vehicleMarkersFor(map, root) or {}) do
            local vehicleSize = Presentation.vehicleSize(size, observation.personal)
            local x = map.mapAPI:worldToUIX(observation.x, observation.y)
            local y = map.mapAPI:worldToUIY(observation.x, observation.y)
            if (observation.personal == true) == (pass == 2) and x >= vehicleSize and y >= vehicleSize
                    and x <= map.width - vehicleSize and y <= map.height - vehicleSize then
                local hit = math.abs(mouseX - x) <= vehicleSize / 2 + 3
                    and math.abs(mouseY - y) <= vehicleSize / 2 + 3
                drawVehicleMarker(map, x, y, vehicleSize,
                    markerOpacity(map, observation.x, observation.y, observation.personal, hit), observation.personal)
                if hit then
                    vehicleHovered, vehicleX, vehicleY = observation, x, y
                    hoverKind = "vehicle"
                end
            end
        end
    end
    Overlay.drawPlayerDots(map)
    if hoverKind == "vehicle" then
        Overlay.drawVehicleTooltip(map, vehicleHovered, vehicleX, vehicleY)
    elseif hoverKind == "building" then
        Overlay.drawBuildingTooltip(map, hovered, hoveredX, hoveredY)
    elseif hoverKind == "important" then
        Overlay.drawImportantTooltip(map, importantHovered, importantX, importantY)
    end
end

function Overlay.toggle(map)
    if not ModOptions.enabled("worldMap") then return end
    map.smMemoryOverlayEnabled = not (map.smMemoryOverlayEnabled ~= false)
    if map.smMemoryToggle then map.smMemoryToggle:setActive(map.smMemoryOverlayEnabled) end
end

if not Overlay.installed then
    local originalCreateChildren = ISWorldMap.createChildren
    ISWorldMap.createChildren = function(self)
        originalCreateChildren(self)
        local spacing = tonumber(UI_BORDER_SPACING) or 10
        local size = math.floor(math.max(32, getTextManager():getFontHeight(UIFont.Small) * 2))
        self.smMemoryOverlayEnabled = ModOptions.value("overlayVisibleByDefault") == true
        self.smMemoryToggle = UICompat.SquareButton:new(spacing, self:getHeight() - size - spacing,
            size, getTexture(ICON_PATHS.NONE), self, Overlay.toggle)
        self.smMemoryToggle:initialise()
        self.smMemoryToggle:setIconSizeRatio(0.62)
        self.smMemoryToggle:setActive(self.smMemoryOverlayEnabled)
        self.smMemoryToggle:setVisible(ModOptions.enabled("worldMap"))
        self.smMemoryToggle:setTooltip(getText("IGUI_SM_MapToggleTooltip"))
        self.smMemoryToggle:setAnchorTop(false)
        self.smMemoryToggle:setAnchorBottom(true)
        self:addChild(self.smMemoryToggle)
    end

    local originalRender = ISWorldMap.render
    ISWorldMap.render = function(self)
        originalRender(self)
        if self.smMemoryToggle then
            self.smMemoryToggle:setY(self:getHeight() - self.smMemoryToggle:getHeight() - (tonumber(UI_BORDER_SPACING) or 10))
        end
        Overlay.render(self)
    end

    local originalRightMouseUp = ISWorldMap.onRightMouseUp
    ISWorldMap.onRightMouseUp = function(self, x, y)
        local vehicle = Overlay.vehicleAt(self, x, y)
        local memory = Overlay.memoryAt(self, x, y)
        if memory and personalBuilding(memory) and vehicle and not vehicle.personal then vehicle = nil end
        if vehicle or (memory and (ModOptions.enabled("placeDesignations")
                or (ModOptions.enabled("itemMemory") and #ItemMemory.all(memory) > 0))) then
            if self.symbolsUI:onRightMouseUpMap(x, y) then return true end
            if vehicle then return Overlay.showVehicleContextMenu(self, vehicle, x, y) end
            return Overlay.showPlaceContextMenu(self, memory, x, y)
        end
        return originalRightMouseUp(self, x, y)
    end
    Overlay.installed = true
end

return Overlay
