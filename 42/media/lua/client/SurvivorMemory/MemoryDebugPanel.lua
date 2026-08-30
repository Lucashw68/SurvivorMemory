require "ISUI/ISPanel"
require "ISUI/ISLabel"
require "SurvivorMemory/UICompat"
require "SurvivorMemory/Runtime"

SurvivorMemory = SurvivorMemory or {}
SurvivorMemory.MemoryDebugPanel = SurvivorMemory.UICompat.WindowBase:derive("SurvivorMemoryDebugPanel")

local DebugPanel = SurvivorMemory.MemoryDebugPanel
local UICompat = SurvivorMemory.UICompat
local panels = {}

local function sortedKeys(values)
    local result = {}
    for key in pairs(values or {}) do table.insert(result, tostring(key)) end
    table.sort(result)
    return result
end

function DebugPanel:initialise()
    UICompat.initialiseWindow(self)
end

function DebugPanel:createChildren()
    UICompat.createWindowChildren(self)
    self.scroll = UICompat.ScrollView:new(self.padding, self.titleHeight,
        self.width - self.padding * 2, self.height - self.titleHeight - self.padding)
    self.scroll:initialise()
    self.scroll:setScrollDirection("vertical")
    self.scroll:setAutoHideScrollbar(true)
    self:addChild(self.scroll)

    if UICompat.neatAvailable then
        self.closeButton = UICompat.SquareButton:new(self.width - self.titleHeight, 0, self.titleHeight,
            UICompat.closeIcon(), self, DebugPanel.close)
        self.closeButton:initialise()
        self.closeButton:setIconSizeRatio(0.45)
        self.closeButton:setTooltip(getText("IGUI_SM_CloseTooltip"))
        self:addChild(self.closeButton)
    end
    self:rebuild()
end

function DebugPanel:close()
    self:setVisible(false)
    self:removeFromUIManager()
    panels[self.playerNum] = nil
end

function DebugPanel:addDebugLine(text, color)
    local label = ISLabel:new(self.padding, self.contentY, self.fontHeight, text,
        color and color.r or 0.82, color and color.g or 0.82, color and color.b or 0.82,
        1, UIFont.Small, true)
    label:initialise()
    self.scroll:addScrollChild(label)
    table.insert(self.debugLabels, label)
    self.contentY = self.contentY + self.fontHeight + self.lineGap
end

function DebugPanel:rebuild()
    if self.debugLabels then
        for _, label in ipairs(self.debugLabels) do self.scroll:removeScrollChild(label) end
    end
    self.debugLabels = {}
    self.contentY = self.padding
    local snapshot = SurvivorMemory.Runtime.debugSnapshot(self.playerNum)
    if not snapshot then return end
    local state, memory, root = snapshot.state, snapshot.memory, snapshot.root
    local function add(key, value, color)
        self:addDebugLine(getText(key, tostring(value)), color)
    end

    add("IGUI_SM_DebugStoreVersion", root.schemaVersion)
    add("IGUI_SM_DebugSerializedBytes", snapshot.estimatedBytes)
    add("IGUI_SM_DebugSession", state.buildingKey or getText("IGUI_SM_DebugNone"))
    add("IGUI_SM_DebugRoom", state.roomKey or getText("IGUI_SM_DebugNone"))
    add("IGUI_SM_DebugPlayerUpdates", snapshot.runtimeCounters.playerUpdates)
    add("IGUI_SM_DebugSquareTransitions", snapshot.runtimeCounters.squareTransitions)
    for name, value in pairs(root.debug or {}) do add("IGUI_SM_DebugCounter", name .. "=" .. tostring(value)) end
    if memory then
        add("IGUI_SM_DebugBuildingKey", memory.buildingKey)
        add("IGUI_SM_DebugFirstRaw", memory.firstVisited)
        add("IGUI_SM_DebugLastRaw", memory.lastVisited)
        for _, key in ipairs(sortedKeys(memory.roomsKnown)) do add("IGUI_SM_DebugRoomKey", key) end
        for _, key in ipairs(sortedKeys(memory.containersKnown)) do add("IGUI_SM_DebugContainerKnownKey", key) end
        for _, key in ipairs(sortedKeys(memory.containersInspected)) do add("IGUI_SM_DebugContainerInspectedKey", key) end
    end
    self.scroll:setScrollHeight(math.max(self.scroll:getHeight(), self.contentY + self.padding))
end

function DebugPanel:prerender()
    UICompat.prerenderWindow(self)
    if not UICompat.neatAvailable then return end
    local x, y = self:getAbsoluteX(), self:getAbsoluteY()
    if self.backgroundTexture then self.backgroundTexture:render(x, y, self.width, self.height, 0.08, 0.08, 0.08, 0.98) end
    if self.titleTexture then self.titleTexture:render(x, y, self.width, self.titleHeight, 0.20, 0.16, 0.12, 1) end
    if not self.backgroundTexture then
        self:drawRect(0, 0, self.width, self.height, 0.98, 0.08, 0.08, 0.08)
        self:drawRectBorder(0, 0, self.width, self.height, 1, 0.35, 0.31, 0.22)
        self:drawRect(0, 0, self.width, self.titleHeight, 1, 0.20, 0.16, 0.12)
    end
end

function DebugPanel:render()
    UICompat.renderWindow(self)
    if UICompat.neatAvailable then
        self:drawText(getText("IGUI_SM_DebugTitle"), self.padding,
            math.floor((self.titleHeight - self.mediumHeight) / 2), 0.95, 0.72, 0.40, 1, UIFont.Medium)
    end
end

function DebugPanel:new(playerNum)
    local small = getTextManager():getFontHeight(UIFont.Small)
    local medium = getTextManager():getFontHeight(UIFont.Medium)
    local width = math.min(math.floor(720 * math.max(1, small / 14)), getPlayerScreenWidth(playerNum) - 40)
    local height = math.min(math.floor(520 * math.max(1, small / 14)), getPlayerScreenHeight(playerNum) - 40)
    local x = getPlayerScreenLeft(playerNum) + math.floor((getPlayerScreenWidth(playerNum) - width) / 2)
    local y = getPlayerScreenTop(playerNum) + math.floor((getPlayerScreenHeight(playerNum) - height) / 2)
    local panel = UICompat.newWindow(self, x, y, width, height)
    panel.playerNum = playerNum
    panel.background = not UICompat.neatAvailable
    panel.moveWithMouse = UICompat.neatAvailable
    panel.padding = math.max(6, math.floor(small * 0.5))
    panel.lineGap = math.max(2, math.floor(small * 0.2))
    panel.fontHeight = small
    panel.mediumHeight = medium
    panel.titleHeight = UICompat.neatAvailable and math.floor(medium * 1.75) or panel:titleBarHeight()
    panel.backgroundTexture = UICompat.ninePatch("media/ui/NeatUI/DefaultPanel/MainPanelBG_RoundTop.png")
    panel.titleTexture = UICompat.ninePatch("media/ui/NeatUI/DefaultPanel/MainTitle_BG.png")
    if not UICompat.neatAvailable then
        panel:setTitle(getText("IGUI_SM_DebugTitle"))
        panel:setResizable(false)
    end
    return panel
end

function DebugPanel.open(playerNum)
    if not isDebugEnabled() then return end
    if panels[playerNum] then panels[playerNum]:close() return end
    local panel = DebugPanel:new(playerNum)
    panel:initialise()
    panel:addToUIManager()
    panel:setVisible(true)
    panels[playerNum] = panel
end

return DebugPanel
