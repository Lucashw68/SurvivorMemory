SurvivorMemory = SurvivorMemory or {}
SurvivorMemory.LocationName = SurvivorMemory.LocationName or {}

local LocationName = SurvivorMemory.LocationName

local ROOM_KINDS = {
    -- Shared service rooms (kitchen, bathroom, diningroom, closet) do not
    -- establish a residential use: shops and workplaces have them too.
    bedroom = "HOUSE", livingroom = "HOUSE",
    garage = "GARAGE", garagestorage = "GARAGE",
    office = "OFFICE", meetingroom = "OFFICE",
    warehouse = "WAREHOUSE", storageunit = "WAREHOUSE", factory = "FACTORY",
    grocery = "GROCERY", grocerystorage = "GROCERY", supermarket = "GROCERY",
    restaurant = "RESTAURANT", diner = "RESTAURANT", pizzawhirled = "RESTAURANT",
    bar = "BAR", pub = "BAR",
    medical = "MEDICAL", clinic = "MEDICAL", pharmacy = "MEDICAL",
    police = "POLICE", policestorage = "POLICE",
    firestation = "FIRE_STATION", firestorage = "FIRE_STATION",
    classroom = "SCHOOL", school = "SCHOOL", church = "CHURCH",
    bank = "BANK", hotelroom = "HOTEL", motelroom = "HOTEL",
}

local VALID_KINDS = {
    BUILDING = true, HOUSE = true, GARAGE = true, STORE = true, OFFICE = true,
    WAREHOUSE = true, FACTORY = true, GROCERY = true, RESTAURANT = true, BAR = true,
    MEDICAL = true, POLICE = true, FIRE_STATION = true, SCHOOL = true, CHURCH = true,
    BANK = true, HOTEL = true,
}

local function normalized(value)
    return tostring(value or ""):lower():gsub("[^%w]", "")
end

function LocationName.kindFromRoomName(roomName)
    return ROOM_KINDS[normalized(roomName)]
end

function LocationName.isValidKind(kind)
    return type(kind) == "string" and VALID_KINDS[kind] == true
end

-- Decode only our persisted r1 identity, never fetch a room from the world.
local function rememberedRoomName(key, buildingKey)
    if type(key) ~= "string" then return nil end
    local length, start = key:match("^r1:(%d+):()")
    length = tonumber(length)
    if not length or length > #key then return nil end
    if key:sub(start, start + length - 1) ~= buildingKey then return nil end
    local nameLength, name = key:sub(start + length):match(
        "^:%-?%d+:%-?%d+:%-?%d+:%-?%d+:%-?%d+:(%d+):(.*)$")
    if name and #name == tonumber(nameLength) then return name end
end

function LocationName.initialize(memory, rebuild)
    if rebuild or type(memory.locationKinds) ~= "table" then
        memory.locationKinds = {}
        for key in pairs(memory.roomsKnown or {}) do
            local kind = LocationName.kindFromRoomName(rememberedRoomName(key, memory.buildingKey))
            if kind then memory.locationKinds[kind] = true end
        end
    end
    for kind, known in pairs(memory.locationKinds) do
        if known ~= true or kind == "BUILDING" or not LocationName.isValidKind(kind) then
            memory.locationKinds[kind] = nil
        end
    end
end

function LocationName.observe(memory, room)
    if not memory or not room then return false end
    local def = room:getRoomDef()
    local kind = def and LocationName.kindFromRoomName(def:getName()) or nil
    if not kind then return false end
    if type(memory.locationKinds) ~= "table" then LocationName.initialize(memory) end
    if memory.locationKinds[kind] then return false end
    memory.locationKinds[kind] = true
    return true
end

function LocationName.merge(target, source)
    LocationName.initialize(target)
    LocationName.initialize(source)
    for kind in pairs(source.locationKinds) do target.locationKinds[kind] = true end
end

function LocationName.text(memory)
    local kinds, labels = {}, {}
    for kind, known in pairs(memory and memory.locationKinds or {}) do
        if known == true and kind ~= "BUILDING" and LocationName.isValidKind(kind) then
            kinds[#kinds + 1] = kind
        end
    end
    table.sort(kinds) -- Stable across visit order and save/reload.
    for _, kind in ipairs(kinds) do labels[#labels + 1] = getText("IGUI_SM_Location_" .. kind) end
    if #labels == 0 then return getText("IGUI_SM_Location_BUILDING") end
    return table.concat(labels, " / ")
end

return LocationName
