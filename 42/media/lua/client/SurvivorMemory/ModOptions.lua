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

local function refreshDependencies()
    local master = ModOptions.enabled("master")
    local building = ModOptions.enabled("buildingMemory")
    local places = ModOptions.enabled("places")
    local emotional = ModOptions.enabled("emotionalMemory")
    local important = ModOptions.enabled("importantMemory")
    local vehicle = ModOptions.enabled("vehicleMemory")
    local map = ModOptions.enabled("worldMap")

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
    option.onChangeApply = function(self, value)
        self[field] = value
        rebuildValues()
        refreshDependencies()
        notify()
    end
end

local function addTick(options, id, translation)
    local option = options:addTickBox(id, translation, Settings.DEFAULTS[id])
    liveApply(option, "value")
    return option
end

function ModOptions.register()
    if ModOptions.registered or not (PZAPI and PZAPI.ModOptions) then return false end
    local options = PZAPI.ModOptions:create(MOD_ID, "IGUI_SM_OptionsTitle")
    ModOptions.options = options

    options:addTitle("IGUI_SM_OptionsSectionGeneral")
    addTick(options, "enabled", "IGUI_SM_OptionEnabled")
    addTick(options, "preferNeatUI", "IGUI_SM_OptionPreferNeatUI")
    options:addKeyBind("recallPanelKey", "IGUI_SM_OptionRecallPanelKey",
        Keyboard and Keyboard.KEY_NONE or 0)

    options:addTitle("IGUI_SM_OptionsSectionBuilding")
    addTick(options, "buildingMemoryEnabled", "IGUI_SM_OptionBuildingMemory")
    addTick(options, "rememberRooms", "IGUI_SM_OptionRememberRooms")
    addTick(options, "rememberContainers", "IGUI_SM_OptionRememberContainers")
    addTick(options, "showStatusIndicator", "IGUI_SM_OptionShowStatusIndicator")

    options:addTitle("IGUI_SM_OptionsSectionPlaces")
    addTick(options, "placesEnabled", "IGUI_SM_OptionPlaces")
    addTick(options, "allowPlaceDesignations", "IGUI_SM_OptionAllowDesignations")
    addTick(options, "hideIndicatorInSearchedPlaces", "IGUI_SM_OptionHideIndicatorSearchedPlaces")

    options:addTitle("IGUI_SM_OptionsSectionEmotional")
    addTick(options, "emotionalMemoryEnabled", "IGUI_SM_OptionEmotionalMemory")
    addTick(options, "emotionalReactionsEnabled", "IGUI_SM_OptionEmotionalReactions")
    local reaction = options:addComboBox("emotionalReactionStrength", "IGUI_SM_OptionReactionStrength")
    reaction:addItem("IGUI_SM_OptionReactionReduced", false)
    reaction:addItem("IGUI_SM_OptionReactionStandard", true)
    liveApply(reaction, "selected")

    options:addTitle("IGUI_SM_OptionsSectionImportant")
    addTick(options, "importantMemoryEnabled", "IGUI_SM_OptionImportantMemory")
    addTick(options, "rememberGenerators", "IGUI_SM_OptionRememberGenerators")
    addTick(options, "rememberGasPumps", "IGUI_SM_OptionRememberGasPumps")
    addTick(options, "rememberWoodStoves", "IGUI_SM_OptionRememberWoodStoves")

    options:addTitle("IGUI_SM_OptionsSectionVehicle")
    addTick(options, "vehicleMemoryEnabled", "IGUI_SM_OptionVehicleMemory")
    addTick(options, "rememberVehicleInteractions", "IGUI_SM_OptionVehicleInteractions")

    options:addTitle("IGUI_SM_OptionsSectionWorldMap")
    addTick(options, "worldMapOverlayEnabled", "IGUI_SM_OptionWorldMapOverlay")
    addTick(options, "overlayVisibleByDefault", "IGUI_SM_OptionOverlayVisibleByDefault")
    addTick(options, "showBuildingMarkers", "IGUI_SM_OptionShowBuildingMarkers")
    addTick(options, "showPersonalPlaceMarkers", "IGUI_SM_OptionShowPersonalPlaceMarkers")
    addTick(options, "showImportantMemoryMarkers", "IGUI_SM_OptionShowImportantMarkers")
    addTick(options, "showVehicleMarkers", "IGUI_SM_OptionShowVehicleMarkers")
    local markerSize = options:addSlider("markerSizePercent", "IGUI_SM_OptionMarkerSize",
        75, 150, 5, Settings.DEFAULTS.markerSizePercent)
    liveApply(markerSize, "value")

    ModOptions.registered = true
    PZAPI.ModOptions:load()
    rebuildValues()
    refreshDependencies()
    return true
end

ModOptions.register()
if Events and Events.OnGameBoot then Events.OnGameBoot.Add(ModOptions.register) end

return ModOptions
