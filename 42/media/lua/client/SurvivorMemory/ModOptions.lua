if not (PZAPI and PZAPI.ModOptions) then require "PZAPI/ModOptions" end
require "SurvivorMemory/Settings"

SurvivorMemory = SurvivorMemory or {}
SurvivorMemory.ModOptions = SurvivorMemory.ModOptions or {}

local ModOptions = SurvivorMemory.ModOptions
local Settings = SurvivorMemory.Settings
local MOD_ID = "SurvivorMemory"

ModOptions.listeners = ModOptions.listeners or {}
ModOptions.registered = ModOptions.registered or false
ModOptions.options = ModOptions.options or nil
ModOptions.values = ModOptions.values or Settings.DEFAULTS

local function rawValues()
    local values = {}
    local options = ModOptions.options
    for key, default in pairs(Settings.DEFAULTS) do
        local option = options and options:getOption(key) or nil
        if option then
            values[key] = Settings.withDefault(option:getValue(), default)
        else
            values[key] = default
        end
    end
    return values
end

function ModOptions.value(key)
    local option = ModOptions.options and ModOptions.options:getOption(key) or nil
    if option then return Settings.withDefault(option:getValue(), Settings.DEFAULTS[key]) end
    return Settings.DEFAULTS[key]
end

function ModOptions.enabled(feature)
    return Settings.enabled(ModOptions.values, feature)
end

function ModOptions.reactionMultiplier()
    return Settings.reactionMultiplier(ModOptions.values)
end

function ModOptions.markerScale()
    return Settings.markerScale(ModOptions.values)
end

function ModOptions.addListener(listener)
    ModOptions.listeners[listener] = true
end

function ModOptions.removeListener(listener)
    ModOptions.listeners[listener] = nil
end

local function notify()
    for listener in pairs(ModOptions.listeners) do
        local ok, message = pcall(listener)
        if not ok then print("[SurvivorMemory] option listener error=" .. tostring(message)) end
    end
end

local function rebuildValues()
    ModOptions.values = rawValues()
end

local function setEnabled(id, enabled)
    local option = ModOptions.options and ModOptions.options:getOption(id) or nil
    if option and option.setEnabled then option:setEnabled(enabled == true) end
end

local function selected(id, feature)
    local option = ModOptions.options and ModOptions.options:getOption(id) or nil
    if option then
        if option.smPreviewValue ~= nil then return option.smPreviewValue == true end
        local element = option.element
        local optionsVisible = MainOptions and MainOptions.instance
            and MainOptions.instance.isVisible and MainOptions.instance:isVisible()
        if optionsVisible and option.type == "tickbox" and element and element.isSelected then
            return element:isSelected(1)
        end
    end
    return ModOptions.enabled(feature)
end

local function refreshDependencies()
    local master = selected("enabled", "master")
    local building = master and selected("buildingMemoryEnabled", "buildingMemory")
    local places = building and selected("placesEnabled", "places")
    local emotional = building and selected("emotionalMemoryEnabled", "emotionalMemory")
    local important = master and selected("importantMemoryEnabled", "importantMemory")
    local vehicle = master and selected("vehicleMemoryEnabled", "vehicleMemory")
    local map = master and selected("worldMapOverlayEnabled", "worldMap")

    setEnabled("preferNeatUI", master)
    setEnabled("buildingMemoryEnabled", master)
    for _, id in ipairs({ "rememberRooms", "rememberContainers", "showStatusIndicator" }) do
        setEnabled(id, building)
    end
    setEnabled("placesEnabled", building)
    for _, id in ipairs({ "allowPlaceDesignations", "hideIndicatorInSearchedPlaces" }) do
        setEnabled(id, places)
    end
    setEnabled("emotionalMemoryEnabled", building)
    for _, id in ipairs({ "emotionalReactionsEnabled", "emotionalReactionStrength" }) do
        setEnabled(id, emotional)
    end
    setEnabled("importantMemoryEnabled", master)
    for _, id in ipairs({ "rememberGenerators", "rememberGasPumps", "rememberWoodStoves" }) do
        setEnabled(id, important)
    end
    setEnabled("vehicleMemoryEnabled", master)
    setEnabled("rememberVehicleInteractions", vehicle)
    setEnabled("worldMapOverlayEnabled", master)
    for _, id in ipairs({ "overlayVisibleByDefault", "showBuildingMarkers",
            "showPersonalPlaceMarkers", "showImportantMemoryMarkers",
            "showVehicleMarkers", "markerSizePercent" }) do
        setEnabled(id, map)
    end
    setEnabled("showPersonalPlaceMarkers", map and places)
    setEnabled("showImportantMemoryMarkers", map and important)
    setEnabled("showVehicleMarkers", map and vehicle)
end

local function liveApply(option, field)
    option.onChange = function(self, value)
        self.smPreviewValue = value
        refreshDependencies()
        self.smPreviewValue = nil
    end
    option.onChangeApply = function(self, value)
        self[field] = value
        rebuildValues()
        refreshDependencies()
        notify()
    end
end

local function addTick(options, id, translation, tooltip)
    local option = options:addTickBox(id, translation, Settings.DEFAULTS[id], tooltip)
    liveApply(option, "value")
    return option
end

-- B42.20.4 stores a mod keybind button's internal identifier from option.name,
-- but later looks it up against the rendered ISLabel text. Those values differ
-- as soon as option.name is a translation key, leaving keyBinded nil in
-- MainOptions.keyPressHandler. Normalize only Survivor Memory's own button at
-- click time and leave vanilla/other-mod bindings untouched.
function ModOptions.normalizeRecallKeybindButton(button)
    local option = ModOptions.options and ModOptions.options:getOption("recallPanelKey") or nil
    local element = option and option.element or nil
    if not button or not element or element.btn ~= button or not element.txt
            or not element.txt.getName then return false end
    button.internal = element.txt:getName()
    return true
end

local function installKeybindCompatibility()
    if not MainOptions or not MainOptions.onKeyBindingBtnPress
            or MainOptions.smSurvivorMemoryKeybindCompatibility then return false end
    local original = MainOptions.onKeyBindingBtnPress
    MainOptions.onKeyBindingBtnPress = function(self, button, x, y)
        ModOptions.normalizeRecallKeybindButton(button)
        return original(self, button, x, y)
    end
    MainOptions.smSurvivorMemoryKeybindCompatibility = true
    return true
end

function ModOptions.register()
    if ModOptions.registered or not (PZAPI and PZAPI.ModOptions) then return false end
    local options = PZAPI.ModOptions:create(MOD_ID, "IGUI_SM_OptionsTitle")
    ModOptions.options = options

    options:addTitle("IGUI_SM_OptionsSectionGeneral")
    addTick(options, "enabled", "IGUI_SM_OptionEnabled", "IGUI_SM_OptionEnabledTooltip")
    addTick(options, "preferNeatUI", "IGUI_SM_OptionPreferNeatUI",
        "IGUI_SM_OptionPreferNeatUITooltip")
    options:addKeyBind("recallPanelKey", "IGUI_SM_OptionRecallPanelKey",
        Keyboard and Keyboard.KEY_NONE or 0, "IGUI_SM_OptionRecallPanelKeyTooltip")

    options:addTitle("IGUI_SM_OptionsSectionBuilding")
    addTick(options, "buildingMemoryEnabled", "IGUI_SM_OptionBuildingMemory",
        "IGUI_SM_OptionBuildingMemoryTooltip")
    addTick(options, "rememberRooms", "IGUI_SM_OptionRememberRooms",
        "IGUI_SM_OptionRememberRoomsTooltip")
    addTick(options, "rememberContainers", "IGUI_SM_OptionRememberContainers",
        "IGUI_SM_OptionRememberContainersTooltip")
    addTick(options, "showStatusIndicator", "IGUI_SM_OptionShowStatusIndicator",
        "IGUI_SM_OptionShowStatusIndicatorTooltip")

    options:addTitle("IGUI_SM_OptionsSectionPlaces")
    addTick(options, "placesEnabled", "IGUI_SM_OptionPlaces", "IGUI_SM_OptionPlacesTooltip")
    addTick(options, "allowPlaceDesignations", "IGUI_SM_OptionAllowDesignations",
        "IGUI_SM_OptionAllowDesignationsTooltip")
    addTick(options, "hideIndicatorInSearchedPlaces", "IGUI_SM_OptionHideIndicatorSearchedPlaces",
        "IGUI_SM_OptionHideIndicatorSearchedPlacesTooltip")

    options:addTitle("IGUI_SM_OptionsSectionEmotional")
    addTick(options, "emotionalMemoryEnabled", "IGUI_SM_OptionEmotionalMemory",
        "IGUI_SM_OptionEmotionalMemoryTooltip")
    addTick(options, "emotionalReactionsEnabled", "IGUI_SM_OptionEmotionalReactions",
        "IGUI_SM_OptionEmotionalReactionsTooltip")
    local reaction = options:addComboBox("emotionalReactionStrength", "IGUI_SM_OptionReactionStrength",
        "IGUI_SM_OptionReactionStrengthTooltip")
    reaction:addItem("IGUI_SM_OptionReactionReduced", false)
    reaction:addItem("IGUI_SM_OptionReactionStandard", true)
    liveApply(reaction, "selected")

    options:addTitle("IGUI_SM_OptionsSectionImportant")
    addTick(options, "importantMemoryEnabled", "IGUI_SM_OptionImportantMemory",
        "IGUI_SM_OptionImportantMemoryTooltip")
    addTick(options, "rememberGenerators", "IGUI_SM_OptionRememberGenerators",
        "IGUI_SM_OptionRememberGeneratorsTooltip")
    addTick(options, "rememberGasPumps", "IGUI_SM_OptionRememberGasPumps",
        "IGUI_SM_OptionRememberGasPumpsTooltip")
    addTick(options, "rememberWoodStoves", "IGUI_SM_OptionRememberWoodStoves",
        "IGUI_SM_OptionRememberWoodStovesTooltip")

    options:addTitle("IGUI_SM_OptionsSectionVehicle")
    addTick(options, "vehicleMemoryEnabled", "IGUI_SM_OptionVehicleMemory",
        "IGUI_SM_OptionVehicleMemoryTooltip")
    addTick(options, "rememberVehicleInteractions", "IGUI_SM_OptionVehicleInteractions",
        "IGUI_SM_OptionVehicleInteractionsTooltip")

    options:addTitle("IGUI_SM_OptionsSectionWorldMap")
    addTick(options, "worldMapOverlayEnabled", "IGUI_SM_OptionWorldMapOverlay",
        "IGUI_SM_OptionWorldMapOverlayTooltip")
    addTick(options, "overlayVisibleByDefault", "IGUI_SM_OptionOverlayVisibleByDefault",
        "IGUI_SM_OptionOverlayVisibleByDefaultTooltip")
    addTick(options, "showBuildingMarkers", "IGUI_SM_OptionShowBuildingMarkers",
        "IGUI_SM_OptionShowBuildingMarkersTooltip")
    addTick(options, "showPersonalPlaceMarkers", "IGUI_SM_OptionShowPersonalPlaceMarkers",
        "IGUI_SM_OptionShowPersonalPlaceMarkersTooltip")
    addTick(options, "showImportantMemoryMarkers", "IGUI_SM_OptionShowImportantMarkers",
        "IGUI_SM_OptionShowImportantMarkersTooltip")
    addTick(options, "showVehicleMarkers", "IGUI_SM_OptionShowVehicleMarkers",
        "IGUI_SM_OptionShowVehicleMarkersTooltip")
    local markerSize = options:addSlider("markerSizePercent", "IGUI_SM_OptionMarkerSize",
        75, 150, 5, Settings.DEFAULTS.markerSizePercent, "IGUI_SM_OptionMarkerSizeTooltip")
    liveApply(markerSize, "value")

    ModOptions.registered = true
    PZAPI.ModOptions:load()
    rebuildValues()
    refreshDependencies()
    installKeybindCompatibility()
    return true
end

ModOptions.register()
if Events and Events.OnGameBoot then
    Events.OnGameBoot.Add(ModOptions.register)
    Events.OnGameBoot.Add(installKeybindCompatibility)
end

return ModOptions
