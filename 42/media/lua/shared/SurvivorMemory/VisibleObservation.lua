SurvivorMemory = SurvivorMemory or {}
SurvivorMemory.VisibleObservation = SurvivorMemory.VisibleObservation or {}

local VisibleObservation = SurvivorMemory.VisibleObservation

function VisibleObservation.isScreenPointVisible(x, y, left, top, width, height)
    x, y = tonumber(x), tonumber(y)
    left, top = tonumber(left), tonumber(top)
    width, height = tonumber(width), tonumber(height)
    if not x or not y or not left or not top or not width or not height
            or width <= 0 or height <= 0 then return false end
    return x >= left and x < left + width and y >= top and y < top + height
end

-- Returns the currently visible set and only the candidates that transitioned
-- from not visible to visible. Candidate identities remain transient runtime
-- values; nothing from this helper is persisted.
function VisibleObservation.reconcile(previous, candidates, isVisible)
    previous = type(previous) == "table" and previous or {}
    candidates = type(candidates) == "table" and candidates or {}
    local current, newlyVisible = {}, {}
    local checked = 0
    for candidate in pairs(candidates) do
        checked = checked + 1
        if isVisible(candidate) then
            current[candidate] = true
            if previous[candidate] ~= true then
                table.insert(newlyVisible, candidate)
            end
        end
    end
    return current, newlyVisible, checked
end

return VisibleObservation
