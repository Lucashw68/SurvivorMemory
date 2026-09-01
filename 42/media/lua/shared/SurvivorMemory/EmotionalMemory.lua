SurvivorMemory = SurvivorMemory or {}
SurvivorMemory.EmotionalMemory = SurvivorMemory.EmotionalMemory or {}

local EmotionalMemory = SurvivorMemory.EmotionalMemory

EmotionalMemory.SUSTAINED_SECONDS = 15
EmotionalMemory.QUIET_RESET_SECONDS = 3
EmotionalMemory.REACTION_COOLDOWN_HOURS = 24
EmotionalMemory.SAFE_VISITS_TO_FORGET = 3

function EmotionalMemory.isSevere(signal)
    signal = signal or {}
    local panic = tonumber(signal.panic) or 0
    local health = tonumber(signal.health) or 100
    local pain = tonumber(signal.pain) or 0
    local bleeding = tonumber(signal.bleeding) or 0
    local veryClose = tonumber(signal.veryCloseZombies) or 0
    local chasing = tonumber(signal.chasingZombies) or 0
    local danger = signal.targeted == true or veryClose >= 2 or chasing >= 4
    local vulnerable = health <= 55 or pain >= 50 or bleeding >= 1
    return panic >= 80 and danger and vulnerable
end

function EmotionalMemory.updateTracker(tracker, signal, elapsedSeconds)
    tracker = tracker or { dangerSeconds = 0, quietSeconds = 0 }
    local elapsed = math.max(0, math.min(tonumber(elapsedSeconds) or 0, 2))
    if EmotionalMemory.isSevere(signal) then
        tracker.dangerSeconds = (tonumber(tracker.dangerSeconds) or 0) + elapsed
        tracker.quietSeconds = 0
    else
        tracker.quietSeconds = (tonumber(tracker.quietSeconds) or 0) + elapsed
        if tracker.quietSeconds >= EmotionalMemory.QUIET_RESET_SECONDS then
            tracker.dangerSeconds = 0
        end
    end
    if tracker.dangerSeconds >= EmotionalMemory.SUSTAINED_SECONDS then
        tracker.dangerSeconds = 0
        tracker.quietSeconds = 0
        return tracker, true
    end
    return tracker, false
end

function EmotionalMemory.sanitize(record)
    if type(record) ~= "table" or tonumber(record.observedAt) == nil then return nil end
    record.observedAt = tonumber(record.observedAt)
    record.lastReactionAt = tonumber(record.lastReactionAt)
    record.safeReturns = math.max(0, math.floor(tonumber(record.safeReturns) or 0))
    if record.safeReturns >= EmotionalMemory.SAFE_VISITS_TO_FORGET then return nil end
    return record
end

function EmotionalMemory.remember(memory, observedAt)
    if not memory or tonumber(observedAt) == nil then return false end
    local record = EmotionalMemory.sanitize(memory.emotionalMemory)
    memory.emotionalMemory = record or {}
    memory.emotionalMemory.observedAt = tonumber(observedAt)
    memory.emotionalMemory.lastReactionAt = record and record.lastReactionAt or nil
    memory.emotionalMemory.safeReturns = 0
    return true
end

function EmotionalMemory.reaction(record, now)
    record = EmotionalMemory.sanitize(record)
    now = tonumber(now)
    if not record or not now then return nil end
    if record.lastReactionAt and now - record.lastReactionAt < EmotionalMemory.REACTION_COOLDOWN_HOURS then
        return nil
    end
    local ageDays = math.max(0, now - record.observedAt) / 24
    local panic, stress
    if ageDays <= 7 then panic, stress = 12, 0.05
    elseif ageDays <= 30 then panic, stress = 8, 0.03
    elseif ageDays <= 90 then panic, stress = 4, 0.015
    else return nil end
    local multiplier = math.max(0, 1 - record.safeReturns / EmotionalMemory.SAFE_VISITS_TO_FORGET)
    if multiplier <= 0 then return nil end
    return { panic = panic * multiplier, stress = stress * multiplier }
end

function EmotionalMemory.recordReaction(record, now)
    if not EmotionalMemory.sanitize(record) or tonumber(now) == nil then return false end
    record.lastReactionAt = tonumber(now)
    return true
end

function EmotionalMemory.recordSafeReturn(memory)
    if not memory then return false end
    local record = EmotionalMemory.sanitize(memory.emotionalMemory)
    if not record then memory.emotionalMemory = nil return false end
    record.safeReturns = record.safeReturns + 1
    if record.safeReturns >= EmotionalMemory.SAFE_VISITS_TO_FORGET then
        memory.emotionalMemory = nil
    end
    return true
end

return EmotionalMemory
