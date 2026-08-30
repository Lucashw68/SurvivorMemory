local RunContext = require "PzModToolsMP/RunContext"
if not RunContext.current.active or RunContext.current.role ~= "server" then return end

RunContext.wait("scenario-start", 240, function(ok, detail)
    if ok then
        print("[SurvivorMemory] MP role=server RESULT status=PASS diagnostics=dedicated-server-context")
        RunContext.result("PASS", "dedicated-server-context")
    else
        print("[SurvivorMemory] MP role=server RESULT status=FAIL diagnostics=scenario-start-timeout")
        RunContext.result("FAIL", "scenario-start=" .. tostring(detail))
    end
end)
