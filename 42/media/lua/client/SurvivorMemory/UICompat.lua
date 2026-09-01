require "ISUI/ISButton"
require "ISUI/ISPanel"
require "ISUI/ISCollapsableWindow"
require "SurvivorMemory/ModOptions"

SurvivorMemory = SurvivorMemory or {}
SurvivorMemory.UICompat = SurvivorMemory.UICompat or {}

local UICompat = SurvivorMemory.UICompat

local function isActivated(modId)
    if not getActivatedMods then return false end
    local mods = getActivatedMods()
    return mods ~= nil and mods:contains(modId)
end

local neatAvailable = false
if SurvivorMemory.ModOptions.enabled("preferNeatUI") and isActivated("NeatUI_Framework") then
    local buttonLoaded = pcall(require, "neatui_framework/ui/ni_squarebutton")
    local patchLoaded = pcall(require, "neatui_framework/neattool/neattool_9patch")
    neatAvailable = buttonLoaded and patchLoaded and NI_SquareButton ~= nil and NinePatchTexture ~= nil
    if not neatAvailable then
        print("[SurvivorMemory] NeatUI is active but unavailable; using vanilla UI fallback")
    end
end

UICompat.neatAvailable = neatAvailable
print("[SurvivorMemory] UI backend=" .. (neatAvailable and "NeatUI" or "vanilla"))

local SquareButton
if neatAvailable then
    SquareButton = NI_SquareButton:derive("SurvivorMemoryOptionalSquareButton")
else
    SquareButton = ISButton:derive("SurvivorMemoryOptionalSquareButton")

    function SquareButton:new(x, y, size, iconTexture, target, onclick)
        local button = ISButton:new(x, y, size, size, "", target, onclick)
        setmetatable(button, self)
        self.__index = self
        button:setDisplayBackground(false)
        button.iconTexture = iconTexture
        button.iconSizeRatio = 0.68
        button.isActive = false
        button.activeColor = { r = 0.72, g = 0.52, b = 0.24 }
        return button
    end

    function SquareButton:setIconSizeRatio(ratio)
        self.iconSizeRatio = ratio
    end

    function SquareButton:setActive(active)
        self.isActive = active == true
    end

    function SquareButton:setActiveColor(r, g, b)
        self.activeColor = { r = r, g = g, b = b }
    end

    function SquareButton:render()
        local color = self.isActive and self.activeColor or { r = 0.20, g = 0.20, b = 0.20 }
        local multiplier = self:isMouseOver() and 1.18 or 1
        if self.pressed then multiplier = 0.78 end
        self:drawRect(0, 0, self.width, self.height, 0.94,
            math.min(color.r * multiplier, 1),
            math.min(color.g * multiplier, 1),
            math.min(color.b * multiplier, 1))
        self:drawRectBorder(0, 0, self.width, self.height, 0.95, 0.65, 0.65, 0.65)
        if self.iconTexture then
            local iconSize = math.floor(math.min(self.width, self.height) * self.iconSizeRatio)
            local x = math.floor((self.width - iconSize) / 2)
            local y = math.floor((self.height - iconSize) / 2)
            self:drawTextureScaled(self.iconTexture, x, y, iconSize, iconSize, 1, 0.95, 0.95, 0.95)
        end
    end
end

UICompat.SquareButton = SquareButton
UICompat.WindowBase = neatAvailable and ISPanel or ISCollapsableWindow

function UICompat.newWindow(class, x, y, width, height)
    if neatAvailable then return ISPanel.new(class, x, y, width, height) end
    return ISCollapsableWindow.new(class, x, y, width, height)
end

function UICompat.initialiseWindow(window)
    if neatAvailable then return ISPanel.initialise(window) end
    return ISCollapsableWindow.initialise(window)
end

function UICompat.createWindowChildren(window)
    if not neatAvailable then ISCollapsableWindow.createChildren(window) end
end

function UICompat.prerenderWindow(window)
    if neatAvailable then return ISPanel.prerender(window) end
    return ISCollapsableWindow.prerender(window)
end

function UICompat.renderWindow(window)
    if not neatAvailable then ISCollapsableWindow.render(window) end
end

function UICompat.closeIcon()
    if neatAvailable then return getTexture("media/ui/NeatUI/ICON/Icon_False.png") end
    return getTexture("media/ui/inventoryPanes/Button_Close.png")
end

function UICompat.ninePatch(path)
    if not neatAvailable then return nil end
    return NinePatchTexture.getSharedTexture(path)
end

local ScrollView
if neatAvailable and pcall(require, "neatui_framework/scrollview/niscrollview") and NIScrollView then
    ScrollView = NIScrollView
else
    ScrollView = ISPanel:derive("SurvivorMemoryVanillaScrollView")

    function ScrollView:new(x, y, width, height)
        local panel = ISPanel:new(x, y, width, height)
        setmetatable(panel, self)
        self.__index = self
        panel.background = false
        return panel
    end

    function ScrollView:initialise()
        ISPanel.initialise(self)
        self:setScrollChildren(true)
        self:addScrollBars(false)
    end

    function ScrollView:setScrollDirection(direction) end
    function ScrollView:setAutoHideScrollbar(autoHide) end

    function ScrollView:addScrollChild(child)
        child:setScrollWithParent(true)
        self:addChild(child)
    end

    function ScrollView:removeScrollChild(child)
        self:removeChild(child)
    end
end

UICompat.ScrollView = ScrollView

return UICompat
