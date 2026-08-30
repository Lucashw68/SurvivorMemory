SurvivorMemory = SurvivorMemory or {}
SurvivorMemory.BuildingIdentity = SurvivorMemory.BuildingIdentity or {}

local BuildingIdentity = SurvivorMemory.BuildingIdentity

local function integer(value, fallback)
    value = tonumber(value)
    if value == nil then return fallback or 0 end
    return math.floor(value)
end

function BuildingIdentity.fromFields(fields)
    local identity = {
        x = integer(fields.x),
        y = integer(fields.y),
        x2 = integer(fields.x2),
        y2 = integer(fields.y2),
        minLevel = integer(fields.minLevel),
        maxLevel = integer(fields.maxLevel),
        nativeId = fields.nativeId and tostring(fields.nativeId) or nil,
    }
    identity.key = table.concat({
        "b1", identity.x, identity.y, identity.x2, identity.y2,
        identity.minLevel, identity.maxLevel,
    }, ":")
    identity.centerX = math.floor((identity.x + identity.x2) / 2)
    identity.centerY = math.floor((identity.y + identity.y2) / 2)
    return identity
end

function BuildingIdentity.fromBuilding(building)
    if not building then return nil end
    local def = building:getDef()
    if not def then return nil end
    return BuildingIdentity.fromFields({
        x = def:getX(), y = def:getY(), x2 = def:getX2(), y2 = def:getY2(),
        minLevel = def:getMinLevel(), maxLevel = def:getMaxLevel(),
        nativeId = def:getIDString(),
    })
end

local function encode(value)
    value = tostring(value or "")
    return tostring(#value) .. ":" .. value
end

function BuildingIdentity.roomFromFields(buildingKey, fields)
    local name = tostring(fields.name or "")
    return table.concat({
        "r1", encode(buildingKey), integer(fields.x), integer(fields.y),
        integer(fields.x2), integer(fields.y2), integer(fields.z), encode(name),
    }, ":")
end

function BuildingIdentity.roomKey(buildingKey, room)
    if not room then return nil end
    local def = room:getRoomDef()
    if not def then return nil end
    return BuildingIdentity.roomFromFields(buildingKey, {
        x = def:getX(), y = def:getY(), x2 = def:getX2(), y2 = def:getY2(),
        z = def:getZ(), name = def:getName(),
    })
end

return BuildingIdentity

