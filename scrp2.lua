(getgenv() or _G)["Configs"] = {
    ["Quest"] = {
        ["Evo Race V1"] = true,
        ["Evo Race V2"] = true,
        ["RGB Haki"] = true,
        ["Pull Lerver"] = true
    },
    ["Sword"] = {
    },
    ["Gun"] = {
    },
    ["FPS Booster"] = true
}

local success, err = pcall(function()
    loadstring(game:HttpGet("https://raw.githubusercontent.com/Graihub/Loader-bamiahub/refs/heads/main/Bamia-kaitun"))()
end)
if not success then
    warn("Не удалось загрузить внешний скрипт: " .. tostring(err))
end

local TeleportService = game:GetService("TeleportService")

local function serverHop(player)
    if player then
        TeleportService:Teleport(game.PlaceId, player)
    end
end

local function monitorPlayer(player)
    local data = player:FindFirstChild("Data")
    if not data then return end
    local level = data:FindFirstChild("Level")
    if not level then return end
    
    local lastValue = level.Value
    local lastChangeTime = os.time()
    
    while player.Parent do
        task.wait(1)
        local currentValue = level.Value
        
        if currentValue ~= lastValue then
            lastValue = currentValue
            lastChangeTime = os.time()
        elseif os.time() - lastChangeTime >= 90 then
            serverHop(player)
            break
        end
    end
end

for _, player in ipairs(game:GetService("Players"):GetPlayers()) do
    task.wait(3)
    monitorPlayer(player)
end

game:GetService("Players").PlayerAdded:Connect(function(player)
    task.wait(3)
    monitorPlayer(player)
end)
