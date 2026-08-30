SurvivorMemory = SurvivorMemory or {}
SurvivorMemory.LocationName = SurvivorMemory.LocationName or {}

local LocationName = SurvivorMemory.LocationName

local ROOM_KINDS = {
    bedroom = "HOUSE", bathroom = "HOUSE", livingroom = "HOUSE",
    kitchen = "HOUSE", diningroom = "HOUSE", closet = "HOUSE",
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

local PRIORITY = {
    BUILDING = 0, HOUSE = 1, GARAGE = 1, STORE = 2, OFFICE = 2,
    WAREHOUSE = 3, FACTORY = 3, GROCERY = 3, RESTAURANT = 3, BAR = 3,
    MEDICAL = 3, POLICE = 3, FIRE_STATION = 3, SCHOOL = 3, CHURCH = 3,
    BANK = 3, HOTEL = 3,
}

local function normalized(value)
    return tostring(value or ""):lower():gsub("[^%w]", "")
end

function LocationName.kindFromRoomName(roomName)
    return ROOM_KINDS[normalized(roomName)]
end

function LocationName.isValidKind(kind)
    return type(kind) == "string" and PRIORITY[kind] ~= nil
end

function LocationName.choose(currentKind, observedKind)
    currentKind = currentKind or "BUILDING"
    if not observedKind then return currentKind end
    if (PRIORITY[observedKind] or 0) > (PRIORITY[currentKind] or 0) then
        return observedKind
    end
    return currentKind
end

function LocationName.observe(memory, building, room)
    if not memory then return false end
    local roomKind
    if room and room:getRoomDef() then
        roomKind = LocationName.kindFromRoomName(room:getRoomDef():getName())
    end
    local kind = roomKind
    if building and building:getDef() then
        local def = building:getDef()
        if def:isResidential() and (not roomKind or roomKind == "HOUSE" or roomKind == "GARAGE") then
            kind = "HOUSE"
        elseif def:isShop() and (not roomKind or roomKind == "HOUSE") then
            kind = "STORE"
        end
    end
    local chosen = LocationName.choose(memory.locationKind, kind)
    if chosen == (memory.locationKind or "BUILDING") then return false end
    memory.locationKind = chosen
    return true
end

function LocationName.text(memory)
    local kind = memory and memory.locationKind or "BUILDING"
    return getText("IGUI_SM_Location_" .. kind)
end

return LocationName
