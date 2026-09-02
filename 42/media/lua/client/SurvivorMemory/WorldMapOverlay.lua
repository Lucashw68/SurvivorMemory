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
require "SurvivorMemory/ModOptions"

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
local ModOptions = SurvivorMemory.ModOptions

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

local function markersFor(map, root)
    local revision = tonumber(root.revision) or 0
    local cache = map.smMemoryMarkerCache
    if cache and cache.root == root and cache.revision == revision then return cache.markers end
    local markers = {}
    for _, memory in pairs(root.buildings or {}) do
        if tonumber(memory.centerX) and tonumber(memory.centerY) then
            table.insert(markers, memory)
        end
    end
    table.sort(markers, function(a, b) return tostring(a.buildingKey) < tostring(b.buildingKey) end)
    map.smMemoryMarkerCache = {
        root = root,
        revision = revision,
        markers = markers,
        important = ImportantMemory.outdoor(root),
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
            if distance <= radius * radius and (not closestDistance or distance < closestDistance) then
                closest, closestDistance = memory, distance
            end
        end
    end
    return closest
end

function Overlay.showPlaceContextMenu(map, memory, x, y)
    if not ModOptions.enabled("placeDesignations")
            or not map or not memory or not map.character then return false end
    local playerNum = map.character:getPlayerNum()
    local context = ISContextMenu.get(playerNum, x + map:getAbsoluteX(), y + map:getAbsoluteY())
    local current = PlaceDesignation.normalize(memory.placeDesignation)
    local choices = {
        { PlaceDesignation.HOME, "IGUI_SM_MapMarkHome" },
        { PlaceDesignation.OUTPOST, "IGUI_SM_MapMarkOutpost" },
        { PlaceDesignation.NONE, "IGUI_SM_MapClearPlace" },
    }
    for _, choice in ipairs(choices) do
        local option = context:addOption(getText(choice[2]), playerNum,
            Runtime.setPlaceDesignation, memory.buildingKey, choice[1])
        context:setOptionChecked(option, current == choice[1])
    end
    return true
end

local function drawTooltip(map, memory, x, y)
    local statusIndex = 2
    local lines = {
        LocationName.text(memory),
        StatusPresentation.text(memory.status),
        getText("IGUI_SM_MapLastVisited", TimeFormat.age(TimeFormat.worldAgeHours(), memory.lastVisited)),
    }
    if ModOptions.enabled("places") and PlaceDesignation.isPersonalPlace(memory.placeDesignation) then
        table.insert(lines, 2, getText("IGUI_SM_PlaceDesignation",
            getText("IGUI_SM_Place_" .. PlaceDesignation.normalize(memory.placeDesignation))))
        statusIndex = 3
    end
    if ModOptions.enabled("emotionalMemory") and memory.emotionalMemory then
        table.insert(lines, getText("IGUI_SM_EmotionalMemory"))
    end
    local root = MemoryStore.forModData(map.character:getModData())
    if ModOptions.enabled("importantMemory") then
        for _, observation in ipairs(ImportantMemory.forBuilding(root, memory.buildingKey)) do
            table.insert(lines, getText("IGUI_SM_ImportantLastSeen",
                getText("IGUI_SM_Important_" .. observation.kind),
                TimeFormat.age(TimeFormat.worldAgeHours(), observation.observedAt)))
        end
    end
    local font = UIFont.Small
    local fontHeight = getTextManager():getFontHeight(font)
    local width = 0
    for _, line in ipairs(lines) do
        width = math.max(width, getTextManager():MeasureStringX(font, line))
    end
    width = width + 16
    local height = fontHeight * #lines + 14
    x = math.min(x + 14, map.width - width - 6)
    y = math.min(y + 14, map.height - height - 6)
    map:drawRect(x, y, width, height, 0.92, 0.05, 0.05, 0.05)
    map:drawRectBorder(x, y, width, height, 0.9, 0.55, 0.48, 0.32)
    local lineY = y + 7
    for index, line in ipairs(lines) do
        local color = index == statusIndex and StatusPresentation.color(memory.status)
            or { r = 0.92, g = 0.92, b = 0.92 }
        map:drawText(line, x + 8, lineY, color.r, color.g, color.b, 1, font)
        lineY = lineY + fontHeight
    end
end

local function drawImportantTooltip(map, observation, x, y)
    local lines = {
        getText("IGUI_SM_Important_" .. observation.kind),
        getText("IGUI_SM_ImportantMapLastSeen",
            TimeFormat.age(TimeFormat.worldAgeHours(), observation.observedAt)),
    }
    local font = UIFont.Small
    local fontHeight = getTextManager():getFontHeight(font)
    local width = 0
    for _, line in ipairs(lines) do width = math.max(width, getTextManager():MeasureStringX(font, line)) end
    width = width + 16
    local height = fontHeight * #lines + 14
    x = math.min(x + 14, map.width - width - 6)
    y = math.min(y + 14, map.height - height - 6)
    map:drawRect(x, y, width, height, 0.92, 0.05, 0.05, 0.05)
    map:drawRectBorder(x, y, width, height, 0.9, 0.55, 0.48, 0.32)
    for index, line in ipairs(lines) do
        map:drawText(line, x + 8, y + 7 + (index - 1) * fontHeight,
            0.92, 0.82, 0.62, 1, font)
    end
end

local function drawVehicleMarker(map, x, y, size)
    local left, top = math.floor(x - size / 2), math.floor(y - size / 2)
    local texture = getTexture(VEHICLE_ICON_PATH)
    if texture then map:drawTextureScaled(texture, left, top, size, size, 1, 1, 1, 1) end
end

local function drawVehicleTooltip(map, observation, x, y)
    local lines = {
        observation.displayName or getText("IGUI_SM_GenericVehicle"),
    }
    if observation.fuelState then
        table.insert(lines, getText("IGUI_SM_VehicleFuel_" .. observation.fuelState))
    end
    local engineSummary = VehicleMemory.engineSummary(observation)
    if engineSummary then
        table.insert(lines, getText("IGUI_SM_VehicleEngine_" .. engineSummary))
    end
    table.insert(lines, getText("IGUI_SM_VehicleMapLastSeen",
        TimeFormat.age(TimeFormat.worldAgeHours(), observation.observedAt)))
    local font = UIFont.Small
    local fontHeight = getTextManager():getFontHeight(font)
    local width = 0
    for _, line in ipairs(lines) do width = math.max(width, getTextManager():MeasureStringX(font, line)) end
    width = width + 16
    local height = fontHeight * #lines + 14
    x = math.min(x + 14, map.width - width - 6)
    y = math.min(y + 14, map.height - height - 6)
    map:drawRect(x, y, width, height, 0.92, 0.05, 0.05, 0.05)
    map:drawRectBorder(x, y, width, height, 0.9, 0.55, 0.48, 0.32)
    for index, line in ipairs(lines) do
        map:drawText(line, x + 8, y + 7 + (index - 1) * fontHeight,
            0.92, 0.82, 0.62, 1, font)
    end
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
    for _, memory in ipairs(markers) do
        local texture = getTexture(displayIconPathFor(memory))
        local markerSize = displayMarkerSizeFor(memory, size)
        local x = map.mapAPI:worldToUIX(memory.centerX, memory.centerY)
        local y = map.mapAPI:worldToUIY(memory.centerX, memory.centerY)
        if shouldShowBuilding(memory) and texture and x >= markerSize and y >= markerSize
                and x <= map.width - markerSize and y <= map.height - markerSize then
            local left, top = math.floor(x - markerSize / 2), math.floor(y - markerSize / 2)
            map:drawTextureScaled(texture, left, top, markerSize, markerSize, 1, 1, 1, 1)
            if math.abs(mouseX - x) <= markerSize / 2 + 3
                    and math.abs(mouseY - y) <= markerSize / 2 + 3 then
                hovered, hoveredX, hoveredY = memory, x, y
            end
        end
    end
    local importantHovered, importantX, importantY
    local importantTexture = getTexture(ICON_PATHS.NONE)
    local importantSize = math.max(14, math.floor(size * 0.90))
    for _, observation in ipairs(ModOptions.enabled("importantMarkers")
            and importantMarkersFor(map, root) or {}) do
        local x = map.mapAPI:worldToUIX(observation.x, observation.y)
        local y = map.mapAPI:worldToUIY(observation.x, observation.y)
        if importantTexture and x >= importantSize and y >= importantSize
                and x <= map.width - importantSize and y <= map.height - importantSize then
            map:drawTextureScaled(importantTexture, math.floor(x - importantSize / 2),
                math.floor(y - importantSize / 2), importantSize, importantSize, 1, 0.92, 0.82, 0.62)
            if math.abs(mouseX - x) <= importantSize / 2 + 3
                    and math.abs(mouseY - y) <= importantSize / 2 + 3 then
                importantHovered, importantX, importantY = observation, x, y
            end
        end
    end
    local vehicleHovered, vehicleX, vehicleY
    local vehicleSize = math.max(18, math.floor(size * 1.05))
    for _, observation in ipairs(ModOptions.enabled("vehicleMarkers")
            and vehicleMarkersFor(map, root) or {}) do
        local x = map.mapAPI:worldToUIX(observation.x, observation.y)
        local y = map.mapAPI:worldToUIY(observation.x, observation.y)
        if x >= vehicleSize and y >= vehicleSize
                and x <= map.width - vehicleSize and y <= map.height - vehicleSize then
            drawVehicleMarker(map, x, y, vehicleSize)
            if math.abs(mouseX - x) <= vehicleSize / 2 + 3
                    and math.abs(mouseY - y) <= vehicleSize / 2 + 3 then
                vehicleHovered, vehicleX, vehicleY = observation, x, y
            end
        end
    end
    if vehicleHovered then
        drawVehicleTooltip(map, vehicleHovered, vehicleX, vehicleY)
    elseif hovered then
        drawTooltip(map, hovered, hoveredX, hoveredY)
    elseif importantHovered then
        drawImportantTooltip(map, importantHovered, importantX, importantY)
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
        local memory = Overlay.memoryAt(self, x, y)
        if memory and ModOptions.enabled("placeDesignations") then
            if self.symbolsUI:onRightMouseUpMap(x, y) then return true end
            return Overlay.showPlaceContextMenu(self, memory, x, y)
        end
        return originalRightMouseUp(self, x, y)
    end
    Overlay.installed = true
end

return Overlay
