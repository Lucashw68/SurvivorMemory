require "ISUI/ISPanel"
require "ISUI/ISContextMenu"
require "SurvivorMemory/UICompat"
require "SurvivorMemory/Runtime"
require "SurvivorMemory/LocationName"
require "SurvivorMemory/PlaceDesignation"
require "SurvivorMemory/ImportantMemory"
require "SurvivorMemory/ModOptions"

SurvivorMemory = SurvivorMemory or {}
SurvivorMemory.MemoryPanel = SurvivorMemory.UICompat.WindowBase:derive("SurvivorMemoryPanel")

local MemoryPanel = SurvivorMemory.MemoryPanel
local MemoryStore = SurvivorMemory.MemoryStore
local TimeFormat = SurvivorMemory.TimeFormat
local LocationName = SurvivorMemory.LocationName
local UICompat = SurvivorMemory.UICompat
local PlaceDesignation = SurvivorMemory.PlaceDesignation
local ImportantMemory = SurvivorMemory.ImportantMemory
local ModOptions = SurvivorMemory.ModOptions
local panels = {}

local function texture(path)
    return UICompat.ninePatch(path)
end

function MemoryPanel:initialise()
    UICompat.initialiseWindow(self)
end

function MemoryPanel:createChildren()
    if not UICompat.neatAvailable then
        UICompat.createWindowChildren(self)
        return
    end
    self.closeButton = UICompat.SquareButton:new(
        self.width - self.titleHeight, 0, self.titleHeight,
        UICompat.closeIcon(), self, MemoryPanel.close)
    self.closeButton:initialise()
    self.closeButton:setIconSizeRatio(0.45)
    self.closeButton:setTooltip(getText("IGUI_SM_CloseTooltip"))
    self:addChild(self.closeButton)
end

function MemoryPanel:close()
    self:setVisible(false)
    self:removeFromUIManager()
    panels[self.playerNum] = nil
end

function MemoryPanel:drawSection(title, y)
    local absoluteX, absoluteY = self:getAbsoluteX(), self:getAbsoluteY()
    if self.sectionBackground then
        self.sectionBackground:render(
            absoluteX + self.padding, absoluteY + y,
            self.width - self.padding * 2, self.sectionHeight,
            0.20, 0.20, 0.20, 0.92)
    end
    self:drawText(title, self.padding * 2, y + self.sectionTextOffset,
        0.78, 0.72, 0.58, 1, UIFont.Small)
    return y + self.sectionHeight + self.lineGap
end

function MemoryPanel:drawLine(text, y, r, g, b)
    self:drawText(text, self.padding * 2, y, r or 0.90, g or 0.90, b or 0.90, 1, UIFont.Small)
    return y + self.lineHeight
end

function MemoryPanel:prerender()
    UICompat.prerenderWindow(self)
    if not UICompat.neatAvailable then return end
    local absoluteX, absoluteY = self:getAbsoluteX(), self:getAbsoluteY()
    if self.mainBackground then
        self.mainBackground:render(absoluteX, absoluteY, self.width, self.height, 0.10, 0.10, 0.10, 0.98)
    end
    if not self.mainBackground then
        self:drawRect(0, 0, self.width, self.height, 0.98, 0.08, 0.08, 0.08)
        self:drawRectBorder(0, 0, self.width, self.height, 1, 0.35, 0.31, 0.22)
    end
    if self.contentBackground then
        self.contentBackground:render(
            absoluteX, absoluteY + self.titleHeight,
            self.width, self.height - self.titleHeight,
            0.08, 0.08, 0.08, 0.96)
    end
    if self.titleBackground then
        self.titleBackground:render(absoluteX, absoluteY, self.width, self.titleHeight, 0.22, 0.19, 0.13, 1)
    else
        self:drawRect(0, 0, self.width, self.titleHeight, 1, 0.22, 0.19, 0.13)
    end
end

function MemoryPanel:render()
    UICompat.renderWindow(self)
    local memory = SurvivorMemory.Runtime.currentMemory(self.playerNum)
    local y = self.titleHeight + self.padding
    if UICompat.neatAvailable then
        self:drawText(getText("IGUI_SM_Title"), self.padding, self.titleTextY,
            0.96, 0.84, 0.55, 1, UIFont.Medium)
    end

    if not memory then
        y = self:drawSection(getText("IGUI_SM_SectionLocation"), y)
        self:drawLine(getText("IGUI_SM_NoCurrentBuilding"), y, 0.70, 0.70, 0.70)
        return
    end

    local stats = MemoryStore.stats(nil, memory)
    local now = TimeFormat.worldAgeHours()

    y = self:drawSection(getText("IGUI_SM_SectionLocation"), y)
    y = self:drawLine(LocationName.text(memory), y)
    if ModOptions.enabled("places") then
        y = self:drawLine(getText("IGUI_SM_PlaceDesignation",
            getText("IGUI_SM_Place_" .. PlaceDesignation.normalize(memory.placeDesignation))), y)
    end
    if ModOptions.enabled("emotionalMemory") and memory.emotionalMemory then
        y = self:drawLine(getText("IGUI_SM_EmotionalMemory"), y, 0.88, 0.70, 0.58)
    end

    y = self:drawSection(getText("IGUI_SM_SectionVisits"), y)
    y = self:drawLine(getText("IGUI_SM_VisitedTimes", memory.visitCount), y)
    y = self:drawLine(getText("IGUI_SM_FirstVisitedRelative", TimeFormat.age(now, memory.firstVisited)), y)
    y = self:drawLine(getText("IGUI_SM_LastVisitedRelative", TimeFormat.age(now, memory.lastVisited)), y)

    if ModOptions.enabled("rooms") or ModOptions.enabled("containers") then
        y = self:drawSection(getText("IGUI_SM_SectionExploration"), y)
        if ModOptions.enabled("rooms") then
            y = self:drawLine(getText("IGUI_SM_RoomsRemembered", stats.roomsKnown), y)
        end
        if ModOptions.enabled("containers") then
            y = self:drawLine(getText("IGUI_SM_ContainersRemembered", stats.containersInspected), y)
        end
    end

    local _, root = SurvivorMemory.Runtime.currentMemory(self.playerNum)
    local important = ImportantMemory.forBuilding(root, memory.buildingKey)
    if ModOptions.enabled("importantMemory") and #important > 0 then
        y = self:drawSection(getText("IGUI_SM_SectionImportantMemories"), y)
        for _, observation in ipairs(important) do
            y = self:drawLine(getText("IGUI_SM_ImportantLastSeen",
                getText("IGUI_SM_Important_" .. observation.kind),
                TimeFormat.age(now, observation.observedAt)), y, 0.88, 0.78, 0.55)
        end
    end

    y = self:drawSection(getText("IGUI_SM_SectionStatus"), y)
    local statusText = getText("IGUI_SM_Status_" .. memory.status)
    self:drawLine(statusText, y, 0.72, 0.88, 0.62)
end

function MemoryPanel:new(playerNum)
    local small = getTextManager():getFontHeight(UIFont.Small)
    local medium = getTextManager():getFontHeight(UIFont.Medium)
    local scale = math.max(1, small / 14)
    local width = math.floor(380 * scale)
    local height = math.floor(400 * scale)
    width = math.min(width, math.floor(getPlayerScreenWidth(playerNum) * 0.90))
    height = math.min(height, math.floor(getPlayerScreenHeight(playerNum) * 0.90))
    local x = getPlayerScreenLeft(playerNum) + math.floor((getPlayerScreenWidth(playerNum) - width) / 2)
    local y = getPlayerScreenTop(playerNum) + math.floor((getPlayerScreenHeight(playerNum) - height) / 2)
    local panel = UICompat.newWindow(self, x, y, width, height)
    panel.playerNum = playerNum
    panel.background = not UICompat.neatAvailable
    panel.moveWithMouse = UICompat.neatAvailable
    panel.padding = math.max(6, math.floor(small * 0.55))
    panel.lineHeight = math.floor(small * 1.35)
    panel.lineGap = math.max(2, math.floor(small * 0.20))
    panel.titleHeight = UICompat.neatAvailable and math.floor(medium * 1.75) or panel:titleBarHeight()
    panel.sectionHeight = math.floor(small * 1.30)
    panel.sectionTextOffset = math.floor((panel.sectionHeight - small) / 2)
    panel.titleTextY = math.floor((panel.titleHeight - medium) / 2)
    panel.mainBackground = texture("media/ui/NeatUI/DefaultPanel/MainPanelBG_RoundTop.png")
    panel.titleBackground = texture("media/ui/NeatUI/DefaultPanel/MainTitle_BG.png")
    panel.contentBackground = texture("media/ui/NeatUI/DefaultPanel/ContentPanel_BG.png")
    panel.sectionBackground = texture("media/ui/NeatUI/DefaultPanel/InnerTitle_BG.png")
    if not UICompat.neatAvailable then
        panel:setTitle(getText("IGUI_SM_Title"))
        panel:setResizable(false)
    end
    return panel
end

function MemoryPanel.open(playerNum)
    playerNum = playerNum or 0
    if not ModOptions.enabled("buildingMemory") then return end
    if panels[playerNum] then
        panels[playerNum]:close()
        return
    end
    local panel = MemoryPanel:new(playerNum)
    panel:initialise()
    panel:addToUIManager()
    panel:setVisible(true)
    panels[playerNum] = panel
    return panel
end

function MemoryPanel.onWorldContextMenu(playerNum, context, worldObjects, test)
    if test and ISWorldObjectContextMenu.Test then return true end
    local player = getSpecificPlayer(playerNum)
    local square = player and player:getCurrentSquare() or nil
    if not square or not square:getBuilding() then return end
    local memory = SurvivorMemory.Runtime.currentMemory(playerNum)
    if not memory then return end
    if test then return ISWorldObjectContextMenu.setTest() end
    context:addOption(getText("IGUI_SM_RememberAction"), playerNum, MemoryPanel.open)
    if ModOptions.enabled("placeDesignations") then
        local designationOption = context:addOption(getText("IGUI_SM_PlaceAction"))
        local designationMenu = ISContextMenu:getNew(context)
        context:addSubMenu(designationOption, designationMenu)
        local current = PlaceDesignation.normalize(memory.placeDesignation)
        for _, designation in ipairs({ PlaceDesignation.HOME, PlaceDesignation.OUTPOST, PlaceDesignation.NONE }) do
            local option = designationMenu:addOption(getText("IGUI_SM_Place_" .. designation),
                playerNum, SurvivorMemory.Runtime.setCurrentPlaceDesignation, designation)
            designationMenu:setOptionChecked(option, current == designation)
        end
    end
    if isDebugEnabled() and SurvivorMemory.MemoryDebugPanel then
        context:addOption(getText("IGUI_SM_DebugAction"), playerNum, SurvivorMemory.MemoryDebugPanel.open)
    end
end

local function firstLocalPlayerNum()
    for playerNum = 0, 3 do
        local player = getSpecificPlayer(playerNum)
        if player and player:isLocalPlayer() then return playerNum end
    end
    return 0
end

function MemoryPanel.onKeyStartPressed(key)
    if MainOptions and MainOptions.setKeybindDialog then return end
    local configured = tonumber(ModOptions.value("recallPanelKey")) or 0
    if configured > 0 and key == configured then MemoryPanel.open(firstLocalPlayerNum()) end
end

function MemoryPanel.applyOptions()
    if ModOptions.enabled("buildingMemory") then return end
    local openPanels = {}
    for _, panel in pairs(panels) do table.insert(openPanels, panel) end
    for _, panel in ipairs(openPanels) do panel:close() end
end

Events.OnFillWorldObjectContextMenu.Add(MemoryPanel.onWorldContextMenu)
Events.OnKeyStartPressed.Add(MemoryPanel.onKeyStartPressed)
ModOptions.addListener(MemoryPanel.applyOptions)

return MemoryPanel
