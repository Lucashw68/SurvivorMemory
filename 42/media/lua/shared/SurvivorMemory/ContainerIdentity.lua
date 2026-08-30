SurvivorMemory = SurvivorMemory or {}
SurvivorMemory.ContainerIdentity = SurvivorMemory.ContainerIdentity or {}

local ContainerIdentity = SurvivorMemory.ContainerIdentity

local function encode(value)
    value = tostring(value or "")
    return tostring(#value) .. ":" .. value
end

function ContainerIdentity.fromFields(fields)
    return table.concat({
        "c1", math.floor(tonumber(fields.x) or 0), math.floor(tonumber(fields.y) or 0),
        math.floor(tonumber(fields.z) or 0), math.floor(tonumber(fields.objectIndex) or -1),
        math.floor(tonumber(fields.containerIndex) or 0), encode(fields.spriteName),
        encode(fields.containerType),
    }, ":")
end

function ContainerIdentity.isNaturalBuildingContainer(container, building)
    if not container or not building then return false end
    if container:isVehiclePart() or container:getContainingItem() then return false end
    local parent = container:getParent()
    local square = container:getSourceGrid()
    return parent ~= nil and square ~= nil and square:getBuilding() == building
end

function ContainerIdentity.fromContainer(container)
    if not container then return nil end
    local square = container:getSourceGrid()
    local parent = container:getParent()
    if not square or not parent then return nil end

    local containerIndex = 0
    for index = 0, parent:getContainerCount() - 1 do
        if parent:getContainerByIndex(index) == container then
            containerIndex = index
            break
        end
    end

    return ContainerIdentity.fromFields({
        x = square:getX(), y = square:getY(), z = square:getZ(),
        objectIndex = parent:getObjectIndex(), containerIndex = containerIndex,
        spriteName = parent:getSpriteName(), containerType = container:getType(),
    })
end

return ContainerIdentity

