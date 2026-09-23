SurvivorMemory = SurvivorMemory or {}
SurvivorMemory.MapPresentation = SurvivorMemory.MapPresentation or {}
local Presentation = SurvivorMemory.MapPresentation

function Presentation.opacity(x, y, playerX, playerY, radius, fade, personal, hovered)
    if hovered or not fade then return 1 end
    radius = math.max(50, math.min(2000, tonumber(radius) or 300))
    local dx, dy = x - playerX, y - playerY
    local distance = math.sqrt(dx * dx + dy * dy)
    local amount = math.max(0, math.min(1, (distance - radius) / radius))
    return 1 - amount * (personal and 0.15 or 0.75)
end

function Presentation.vehicleSize(baseSize, personal)
    return math.max(18, math.floor(baseSize * (personal and 1.25 or 1.05)))
end

function Presentation.showPlayerDot(playersEnabled, zoom, dead)
    return playersEnabled == true and zoom < 20 and not dead
end

return Presentation
