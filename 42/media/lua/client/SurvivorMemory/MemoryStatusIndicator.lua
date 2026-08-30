require "SurvivorMemory/UICompat"
require "SurvivorMemory/Runtime"
require "SurvivorMemory/MemoryPanel"
require "SurvivorMemory/LocationName"
require "SurvivorMemory/StatusPresentation"
require "SurvivorMemory/TimeFormat"

SurvivorMemory = SurvivorMemory or {}
SurvivorMemory.MemoryStatusIndicator = SurvivorMemory.MemoryStatusIndicator or {}

local Indicator = SurvivorMemory.MemoryStatusIndicator
local StatusPresentation = SurvivorMemory.StatusPresentation
local LocationName = SurvivorMemory.LocationName
local TimeFormat = SurvivorMemory.TimeFormat
local UICompat = SurvivorMemory.UICompat
local buttons = {}
local TEXTURE_SIZES = { 32, 48, 64, 80, 96, 128 }
local POSITION_REFRESH_MS = 250
local TOOLTIP_REFRESH_MS = 1000

-- B42 has no public custom-moodle slot API. Counting only the already-visible
-- vanilla moodles lets this NeatUI button occupy the next visual slot without
-- touching MoodleUI's private state.
local VANILLA_MOODLES = {
    MoodleType.ENDURANCE, MoodleType.TIRED, MoodleType.HUNGRY,
    MoodleType.PANIC, MoodleType.SICK, MoodleType.BORED,
    MoodleType.UNHAPPY, MoodleType.BLEEDING, MoodleType.WET,
    MoodleType.HAS_A_COLD, MoodleType.ANGRY, MoodleType.STRESS,
    MoodleType.THIRST, MoodleType.INJURED, MoodleType.PAIN,
    MoodleType.HEAVY_LOAD, MoodleType.DRUNK, MoodleType.DEAD,
    MoodleType.ZOMBIE, MoodleType.HYPERTHERMIA, MoodleType.HYPOTHERMIA,
    MoodleType.WINDCHILL, MoodleType.CANT_SPRINT,
    MoodleType.UNCOMFORTABLE, MoodleType.NOXIOUS_SMELL,
    MoodleType.FOOD_EATEN,
}

local MemoryStatusButton = UICompat.SquareButton:derive("SurvivorMemoryStatusButton")

local function textureSize()
    local option = getCore():getOptionMoodleSize()
    local index = option
    if option == 7 then index = getCore():getOptionFontSizeReal() end
    return TEXTURE_SIZES[index] or TEXTURE_SIZES[1]
end

local function visibleMoodleCount(player)
    if not player or not player:getMoodles() then return 0 end
    local moodles = player:getMoodles()
    local count = 0
    for _, moodleType in ipairs(VANILLA_MOODLES) do
        local level = moodles:getMoodleLevel(moodleType)
        if level > 0 and (moodleType ~= MoodleType.FOOD_EATEN or level >= 3) then
            count = count + 1
        end
    end
    return count
end

local function position(button)
    local playerNum = button.playerNum
    local size = textureSize()
    if button.width ~= size then
        button:setWidth(size)
        button:setHeight(size)
        button.moodleBackground = nil
        button.moodleBorder = nil
        button.moodleTextureSize = nil
    end
    local screenLeft = getPlayerScreenLeft(playerNum)
    local screenTop = getPlayerScreenTop(playerNum)
    local screenWidth = getPlayerScreenWidth(playerNum)
    local screenHeight = getPlayerScreenHeight(playerNum)
    local x = screenLeft + screenWidth - 10 - size
    local top = getPlayerScreenTop(playerNum) + 44
    local moodle = UIManager.getMoodleUI(playerNum)
    if moodle and moodle:isVisible() then
        top = math.max(top, moodle:getY())
        local player = getSpecificPlayer(playerNum)
        top = top + visibleMoodleCount(player) * (size + 10)
    end
    local bottom = screenTop + screenHeight - size - 8
    button:setX(math.floor(x))
    button:setY(math.floor(math.min(top, bottom)))
end

local function updateTooltip(button)
    local memory = button.memory
    if not memory then return end
    button:setTooltip(getText("IGUI_SM_IndicatorTooltip",
        LocationName.text(memory),
        StatusPresentation.text(memory.status),
        tostring(memory.visitCount or 0),
        TimeFormat.age(TimeFormat.worldAgeHours(), memory.lastVisited)))
end

function MemoryStatusButton:ensureMoodleTextures()
    local size = self.width
    if self.moodleTextureSize == size then return end
    local path = "media/ui/Moodles/" .. tostring(size) .. "/"
    self.moodleBackground = getTexture(path .. "_Moodles_BGsolid.png")
    self.moodleBorder = getTexture(path .. "_Moodles_BGoutline.png")
    self.moodleTextureSize = size
end

function MemoryStatusButton:render()
    self:ensureMoodleTextures()
    local color = self.activeColor
    local multiplier = 1
    if self.pressed then
        multiplier = 0.78
    elseif self:isMouseOver() then
        multiplier = 1.16
    end
    local r = math.min(color.r * multiplier, 1)
    local g = math.min(color.g * multiplier, 1)
    local b = math.min(color.b * multiplier, 1)
    if self.moodleBackground then
        self:drawTextureScaled(self.moodleBackground, 0, 0, self.width, self.height, 0.95, r, g, b)
    end
    if self.moodleBorder then
        self:drawTextureScaled(self.moodleBorder, 0, 0, self.width, self.height, 1, 1, 1, 1)
    end
    if self.iconTexture then
        local iconSize = math.floor(self.width * self.iconSizeRatio)
        local offset = math.floor((self.width - iconSize) / 2)
        self:drawTextureScaled(self.iconTexture, offset, offset, iconSize, iconSize, 1, 1, 1, 1)
    end
end

function MemoryStatusButton:update()
    ISButton.update(self)
    local now = getTimestampMs()
    if not self.nextPositionRefresh or now >= self.nextPositionRefresh then
        position(self)
        self.nextPositionRefresh = now + POSITION_REFRESH_MS
    end
    if not self.nextTooltipRefresh or now >= self.nextTooltipRefresh then
        updateTooltip(self)
        self.nextTooltipRefresh = now + TOOLTIP_REFRESH_MS
    end
end

function Indicator.onClick(target, button)
    SurvivorMemory.MemoryPanel.open(button and button.playerNum or 0)
end

local function ensureButton(playerNum)
    local button = buttons[playerNum]
    if button then return button end
    local size = textureSize()
    button = MemoryStatusButton:new(0, 0, size,
        getTexture("media/ui/SurvivorMemory/memory-status.png"), Indicator, Indicator.onClick)
    button.playerNum = playerNum
    button:initialise()
    button:setIconSizeRatio(0.62)
    button:setActive(true)
    button:setVisible(false)
    button:addToUIManager()
    position(button)
    buttons[playerNum] = button
    return button
end

function Indicator.onMemoryEvent(eventName, player, memory)
    if not player then return end
    local button = ensureButton(player:getPlayerNum())
    if eventName == "exited" or not memory then
        button:setVisible(false)
        return
    end
    local color = StatusPresentation.color(memory.status)
    button.memory = memory
    button:setActiveColor(color.r, color.g, color.b)
    updateTooltip(button)
    button.nextPositionRefresh = nil
    button:setVisible(true)
end

function Indicator.reset(playerNum)
    local button = buttons[playerNum]
    if button then
        button.memory = nil
        button:setVisible(false)
        button:removeFromUIManager()
        buttons[playerNum] = nil
    end
end

function Indicator.currentButton(playerNum)
    return buttons[playerNum or 0]
end

SurvivorMemory.Runtime.addListener(Indicator.onMemoryEvent)
Events.OnCreatePlayer.Add(Indicator.reset)

return Indicator
