SurvivorMemory = SurvivorMemory or {}
SurvivorMemory.ReadingMemory = SurvivorMemory.ReadingMemory or {}

local ReadingMemory = SurvivorMemory.ReadingMemory

local function nonempty(value)
    return type(value) == "string" and value ~= "" and value or nil
end

local function makeKey(kind, fullType, detail)
    return "reading1:" .. kind .. ":" .. #fullType .. ":" .. fullType
        .. ":" .. #detail .. ":" .. detail
end

-- Each key describes a title, not the current Java item instance. Generic
-- untitled fiction and media are intentionally skipped: their full type alone
-- would falsely identify unrelated titles as duplicates.
function ReadingMemory.identity(item)
    if not item then return nil end
    local fullType = nonempty(item:getFullType())
    if not fullType then return nil end

    local media = item:getMediaData()
    if media then
        local mediaId = nonempty(media:getId())
        return mediaId and makeKey("media", fullType, mediaId) or nil
    end

    if item:IsMap() then
        local mapId = nonempty(item:getMapID())
        return mapId and makeKey("map", fullType, mapId) or nil
    end

    if not item:IsLiterature() then return nil end
    local category = item:getDisplayCategory()
    local data = item:hasModData() and item:getModData() or nil
    local title = data and nonempty(data.literatureTitle) or nil
    local printMedia = data and data.printMedia or nil
    if not title and type(printMedia) == "table" then
        title = nonempty(printMedia.title)
    end
    if title then return makeKey("print", fullType, title) end
    if category == "SkillBook" or category == "RecipeResource" then
        return makeKey("print", fullType, "")
    end
    return nil
end

function ReadingMemory.initialize(root)
    if type(root.collectedReading) ~= "table" then root.collectedReading = {} end
    for key, time in pairs(root.collectedReading) do
        if type(key) ~= "string" or key:sub(1, 9) ~= "reading1:"
                or type(time) ~= "number" or time ~= time
                or time == math.huge or time == -math.huge or time < 0 then
            root.collectedReading[key] = nil
        end
    end
end

function ReadingMemory.remember(root, item, observedAt)
    local key = ReadingMemory.identity(item)
    if not key or type(observedAt) ~= "number" or observedAt ~= observedAt
            or observedAt == math.huge or observedAt == -math.huge
            or observedAt < 0 then return false end
    if type(root.collectedReading) ~= "table" then root.collectedReading = {} end
    if root.collectedReading[key] ~= nil then return false end
    root.collectedReading[key] = observedAt
    return true
end

function ReadingMemory.has(root, item)
    local key = ReadingMemory.identity(item)
    return key ~= nil and type(root) == "table"
        and type(root.collectedReading) == "table"
        and root.collectedReading[key] ~= nil
end

return ReadingMemory
