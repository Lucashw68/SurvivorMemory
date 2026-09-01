SurvivorMemory = SurvivorMemory or {}
SurvivorMemory.PlaceDesignation = SurvivorMemory.PlaceDesignation or {}

local PlaceDesignation = SurvivorMemory.PlaceDesignation

PlaceDesignation.NONE = "NONE"
PlaceDesignation.HOME = "HOME"
PlaceDesignation.OUTPOST = "OUTPOST"

local VALID = {
    NONE = true,
    HOME = true,
    OUTPOST = true,
}

function PlaceDesignation.isValid(value)
    return type(value) == "string" and VALID[value] == true
end

function PlaceDesignation.normalize(value)
    if PlaceDesignation.isValid(value) then return value end
    return PlaceDesignation.NONE
end

function PlaceDesignation.isPersonalPlace(value)
    value = PlaceDesignation.normalize(value)
    return value == PlaceDesignation.HOME or value == PlaceDesignation.OUTPOST
end

function PlaceDesignation.shouldShowIndicator(status, designation)
    if status ~= "SEARCHED" then return true end
    return not PlaceDesignation.isPersonalPlace(designation)
end

return PlaceDesignation
