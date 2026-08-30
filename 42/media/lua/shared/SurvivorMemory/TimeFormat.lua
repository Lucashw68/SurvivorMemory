SurvivorMemory = SurvivorMemory or {}
SurvivorMemory.TimeFormat = SurvivorMemory.TimeFormat or {}

local TimeFormat = SurvivorMemory.TimeFormat

function TimeFormat.worldAgeHours()
    return getGameTime():getWorldAgeHours()
end

function TimeFormat.dayNumber(hours)
    return math.floor((tonumber(hours) or 0) / 24) + 1
end

function TimeFormat.age(nowHours, observedHours)
    if tonumber(observedHours) == nil then return getText("IGUI_SM_TimeUnknown") end
    local hours = math.max(0, (tonumber(nowHours) or 0) - (tonumber(observedHours) or 0))
    local days = math.floor(hours / 24)
    if days == 0 then return getText("IGUI_SM_Today") end
    if days == 1 then return getText("IGUI_SM_Yesterday") end
    if days < 60 then return getText("IGUI_SM_DaysAgo", days) end
    return getText("IGUI_SM_MonthsAgo", math.floor(days / 30))
end

return TimeFormat
