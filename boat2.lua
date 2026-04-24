-- Монитор появления Prehistoricisland
local function log(msg) print("[ISLAND]", msg) end

local lastState = false
while true do
    local island = workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("Prehistoricisland")
    local exists = island ~= nil
    if exists ~= lastState then
        if exists then
            log("Остров Prehistoricisland ПОЯВИЛСЯ")
        else
            log("Остров Prehistoricisland ИСЧЕЗ")
        end
        lastState = exists
    end
    task.wait(0.5)
end
