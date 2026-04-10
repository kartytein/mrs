-- Универсальный скрипт управления лодкой (ищет по всему workspace)
local player = game.Players.LocalPlayer
local char = player.Character or player.CharacterAdded:Wait()
local hrp = char:WaitForChild("HumanoidRootPart")
local humanoid = char:WaitForChild("Humanoid")

local function controlBoat(boat)
    print("Найдена лодка:", boat.Name)
    
    -- Отключаем столкновения у всех частей
    for _, part in ipairs(boat:GetDescendants()) do
        if part:IsA("BasePart") then part.CanCollide = false end
    end
    
    -- Отключаем родной скрипт (если есть)
    local native = boat:FindFirstChild("Script")
    if native then native.Disabled = true end
    
    local seat = boat:FindFirstChildWhichIsA("VehicleSeat")
    if not then return end
    
    -- Tween к сиденью
    local target = seat.CFrame + Vector3.new(0, 2, 0)
    local tween = game:GetService("TweenService"):Create(hrp, TweenInfo.new(2), {CFrame = target})
    tween:Play()
    tween.Completed:Wait()
    
    humanoid.Sit = true
    task.wait(0.5)
    
    -- Движение
    local root = boat.PrimaryPart or boat:FindFirstChildWhichIsA("BasePart")
    if not root then return end
    local speed = -420
    game:GetService("RunService").RenderStepped:Connect(function(dt)
        if humanoid.Sit and humanoid.SeatPart == seat then
            root.CFrame = root.CFrame * CFrame.new(0, 0, speed * dt)
        end
    end)
    print("Лодка поехала")
end

-- Поиск лодки раз в секунду
task.spawn(function()
    while true do
        for _, obj in ipairs(workspace:GetDescendants()) do
            if obj:IsA("Model") and obj:FindFirstChildWhichIsA("VehicleSeat") then
                -- Игнорируем уже управляемую лодку (можно добавить флаг)
                if not obj:GetAttribute("UnderControl") then
                    obj:SetAttribute("UnderControl", true)
                    controlBoat(obj)
                    return -- останавливаем поиск
                end
            end
        end
        task.wait(1)
    end
end)

print("Ожидание появления лодки...")
