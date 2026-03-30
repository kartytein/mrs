(getgenv())["Configs"] = {
    ["Quest"] = {
        ["Evo Race V1"] = true,
        ["Evo Race V2"] = true;
        ["RGB Haki"] = true,
        ["Pull Lerver"] = true
    };
    ["Sword"] = {
        "Dual-Headed Blade",
        "Smoke Admiral",
        "Wardens Sword",
        "Cutlass",
        "Katana";
        "Dual Katana";
        "Triple Katana",
        "Iron Mace",
        "Saber";
        "Pole (1st Form)",
        "Gravity Blade",
        "Longsword";
        "Rengoku";
        "Midnight Blade",
        "Soul Cane",
        "Bisento",
        "Yama";
        "Tushita";
        "Cursed Dual Katana"
    };
    ["Gun"] = {
        "Soul Guitar";
        "Kabucha",
        "Venom Bow",
        "Musket";
        "Flintlock",
        "Refined Slingshot",
        "Magma Blaster";
        "Dual Flintlock",
        "Cannon",
        "Bizarre Revolver";
        "Bazooka"
    };
    ["FPS Booster"] = true
}

spawn(function()
    loadstring(game:HttpGet("https://raw.githubusercontent.com/Graihub/Loader-bamiahub/refs/heads/main/Bamia-kaitun"))()

task.wait(5)

local TeleportService = game:GetService("TeleportService")

local function kickPlayer(player)
    if player then player:Kick() end
end

local function serverHop(player)
    if player then TeleportService:Teleport(game.PlaceId, player) end
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
        
        if currentValue > 50 then
            kickPlayer(player)
            break
        end
        
        if currentValue ~= lastValue then
            lastValue = currentValue
            lastChangeTime = os.time()
        elseif os.time() - lastChangeTime >= 180 then
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
