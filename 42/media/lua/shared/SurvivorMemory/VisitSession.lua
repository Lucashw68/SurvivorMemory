SurvivorMemory = SurvivorMemory or {}
SurvivorMemory.VisitSession = SurvivorMemory.VisitSession or {}

local VisitSession = SurvivorMemory.VisitSession

function VisitSession.new()
    return { initialized = false, buildingKey = nil, roomKey = nil }
end

function VisitSession.update(state, nextBuildingKey, alreadyRemembered)
    local transition = { entered = nil, exited = nil, resumed = false }
    if not state.initialized then
        state.initialized = true
        state.buildingKey = nextBuildingKey
        if nextBuildingKey then
            if alreadyRemembered then
                transition.resumed = true
            else
                transition.entered = nextBuildingKey
            end
        end
        return transition
    end

    if state.buildingKey == nextBuildingKey then return transition end
    transition.exited = state.buildingKey
    transition.entered = nextBuildingKey
    state.buildingKey = nextBuildingKey
    state.roomKey = nil
    return transition
end

return VisitSession

