require "ISUI/Maps/ISWorldMap"
require "SurvivorMemory/UICompat"
require "SurvivorMemory/MemoryStore"
require "SurvivorMemory/TimeFormat"
require "SurvivorMemory/LocationName"
require "SurvivorMemory/StatusPresentation"

SurvivorMemory = SurvivorMemory or {}
SurvivorMemory.WorldMapOverlay = SurvivorMemory.WorldMapOverlay or {}

local Overlay = SurvivorMemory.WorldMapOverlay
local MemoryStore = SurvivorMemory.MemoryStore
local TimeFormat = SurvivorMemory.TimeFormat
local LocationName = SurvivorMemory.LocationName
local StatusPresentation = SurvivorMemory.StatusPresentation
local UICompat = SurvivorMemory.UICompat

local iconPath = "media/ui/SurvivorMemory/memory-status.png"

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
    map.smMemoryMarkerCache = { root = root, revision = revision, markers = markers }
    return markers
end

local function drawTooltip(map, memory, x, y)
    local lines = {
        LocationName.text(memory),
        StatusPresentation.text(memory.status),
        getText("IGUI_SM_MapLastVisited", TimeFormat.age(TimeFormat.worldAgeHours(), memory.lastVisited)),
    }
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
        local color = index == 2 and StatusPresentation.color(memory.status) or { r = 0.92, g = 0.92, b = 0.92 }
        map:drawText(line, x + 8, lineY, color.r, color.g, color.b, 1, font)
        lineY = lineY + fontHeight
    end
end

function Overlay.render(map)
    if map.smMemoryOverlayEnabled == false or not map.character or not map.mapAPI then return end
    local root = MemoryStore.forModData(map.character:getModData())
    local markers = markersFor(map, root)
    local texture = getTexture(iconPath)
    if not texture then return end
    local size = math.max(16, math.min(26, math.floor(14 + map.mapAPI:getZoomF() * 0.45)))
    local mouseX, mouseY = map:getMouseX(), map:getMouseY()
    local hovered, hoveredX, hoveredY
    for _, memory in ipairs(markers) do
        local x = map.mapAPI:worldToUIX(memory.centerX, memory.centerY)
        local y = map.mapAPI:worldToUIY(memory.centerX, memory.centerY)
        if x >= size and y >= size and x <= map.width - size and y <= map.height - size then
            local color = StatusPresentation.color(memory.status)
            local left, top = math.floor(x - size / 2), math.floor(y - size / 2)
            map:drawRect(left - 2, top - 2, size + 4, size + 4, 0.78, 0.04, 0.04, 0.04)
            map:drawRectBorder(left - 2, top - 2, size + 4, size + 4, 0.95, color.r, color.g, color.b)
            map:drawTextureScaled(texture, left, top, size, size, 1, color.r, color.g, color.b)
            if math.abs(mouseX - x) <= size / 2 + 3 and math.abs(mouseY - y) <= size / 2 + 3 then
                hovered, hoveredX, hoveredY = memory, x, y
            end
        end
    end
    if hovered then drawTooltip(map, hovered, hoveredX, hoveredY) end
end

function Overlay.toggle(map)
    map.smMemoryOverlayEnabled = not (map.smMemoryOverlayEnabled ~= false)
    if map.smMemoryToggle then map.smMemoryToggle:setActive(map.smMemoryOverlayEnabled) end
end

if not Overlay.installed then
    local originalCreateChildren = ISWorldMap.createChildren
    ISWorldMap.createChildren = function(self)
        originalCreateChildren(self)
        local spacing = tonumber(UI_BORDER_SPACING) or 10
        local size = math.floor(math.max(32, getTextManager():getFontHeight(UIFont.Small) * 2))
        self.smMemoryOverlayEnabled = true
        self.smMemoryToggle = UICompat.SquareButton:new(spacing, self:getHeight() - size - spacing,
            size, getTexture(iconPath), self, Overlay.toggle)
        self.smMemoryToggle:initialise()
        self.smMemoryToggle:setIconSizeRatio(0.62)
        self.smMemoryToggle:setActive(true)
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
    Overlay.installed = true
end

return Overlay
