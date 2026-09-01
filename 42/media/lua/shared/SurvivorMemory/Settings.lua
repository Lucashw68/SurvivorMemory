SurvivorMemory = SurvivorMemory or {}
SurvivorMemory.Settings = SurvivorMemory.Settings or {}

local Settings = SurvivorMemory.Settings

Settings.DEFAULTS = {
    enabled = true,
    preferNeatUI = true,
    recallPanelKey = 0,
    buildingMemoryEnabled = true,
    rememberRooms = true,
    rememberContainers = true,
    showStatusIndicator = true,
    placesEnabled = true,
    allowPlaceDesignations = true,
    hideIndicatorInSearchedPlaces = true,
    emotionalMemoryEnabled = true,
    emotionalReactionsEnabled = true,
    emotionalReactionStrength = 2,
    importantMemoryEnabled = true,
    rememberGenerators = true,
    rememberGasPumps = true,
    rememberWoodStoves = true,
    vehicleMemoryEnabled = true,
    rememberVehicleInteractions = true,
    worldMapOverlayEnabled = true,
    overlayVisibleByDefault = true,
    showBuildingMarkers = true,
    showPersonalPlaceMarkers = true,
    showImportantMemoryMarkers = true,
    showVehicleMarkers = true,
    markerSizePercent = 100,
}

local function bool(values, key)
    local value = values and values[key]
    if value == nil then value = Settings.DEFAULTS[key] end
    return value == true or value == 1 or value == "1" or value == "true"
end

function Settings.withDefault(value, default)
    if value == nil then return default end
    return value
end

function Settings.value(values, key)
    local value = values and values[key]
    if value == nil then return Settings.DEFAULTS[key] end
    return value
end

function Settings.enabled(values, feature)
    if feature == "preferNeatUI" then return bool(values, feature) end
    if not bool(values, "enabled") then return false end
    if feature == "master" then return true end

    local building = bool(values, "buildingMemoryEnabled")
    local places = building and bool(values, "placesEnabled")
    local emotional = building and bool(values, "emotionalMemoryEnabled")
    local important = bool(values, "importantMemoryEnabled")
    local vehicle = bool(values, "vehicleMemoryEnabled")
    local map = bool(values, "worldMapOverlayEnabled")

    if feature == "buildingMemory" then return building end
    if feature == "rooms" then return building and bool(values, "rememberRooms") end
    if feature == "containers" then return building and bool(values, "rememberContainers") end
    if feature == "statusIndicator" then return building and bool(values, "showStatusIndicator") end
    if feature == "places" then return places end
    if feature == "placeDesignations" then return places and bool(values, "allowPlaceDesignations") end
    if feature == "hideIndicatorInSearchedPlaces" then
        return places and bool(values, "hideIndicatorInSearchedPlaces")
    end
    if feature == "emotionalMemory" then return emotional end
    if feature == "emotionalReactions" then
        return emotional and bool(values, "emotionalReactionsEnabled")
    end
    if feature == "importantMemory" then return important end
    if feature == "generatorMemory" then return important and bool(values, "rememberGenerators") end
    if feature == "gasPumpMemory" then return important and bool(values, "rememberGasPumps") end
    if feature == "woodStoveMemory" then return important and bool(values, "rememberWoodStoves") end
    if feature == "vehicleMemory" then return vehicle end
    if feature == "vehicleTracking" then
        return vehicle and bool(values, "rememberVehicleInteractions")
    end
    if feature == "worldMap" then return map end
    if feature == "buildingMarkers" then
        return map and building and bool(values, "showBuildingMarkers")
    end
    if feature == "personalPlaceMarkers" then
        return map and places and bool(values, "showPersonalPlaceMarkers")
    end
    if feature == "importantMarkers" then
        return map and important and bool(values, "showImportantMemoryMarkers")
    end
    if feature == "vehicleMarkers" then
        return map and vehicle and bool(values, "showVehicleMarkers")
    end
    return bool(values, feature)
end

function Settings.reactionMultiplier(values)
    return tonumber(Settings.value(values, "emotionalReactionStrength")) == 1 and 0.5 or 1
end

function Settings.markerScale(values)
    local percent = tonumber(Settings.value(values, "markerSizePercent")) or 100
    return math.max(75, math.min(150, percent)) / 100
end

return Settings
