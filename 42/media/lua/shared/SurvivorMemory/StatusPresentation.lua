SurvivorMemory = SurvivorMemory or {}
SurvivorMemory.StatusPresentation = SurvivorMemory.StatusPresentation or {}

local StatusPresentation = SurvivorMemory.StatusPresentation
local COLORS = {
    VISITED = { r = 0.82, g = 0.18, b = 0.16 },
    PARTIALLY_SEARCHED = { r = 0.92, g = 0.58, b = 0.12 },
    SEARCHED = { r = 0.20, g = 0.72, b = 0.28 },
}

function StatusPresentation.color(status)
    return COLORS[status] or COLORS.VISITED
end

function StatusPresentation.text(status)
    return getText("IGUI_SM_Status_" .. tostring(status or "VISITED"))
end

function StatusPresentation.needsRefresh(presentedStatus, currentStatus)
    return presentedStatus ~= currentStatus
end

return StatusPresentation
