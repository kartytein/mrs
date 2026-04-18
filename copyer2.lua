-- ===== РАСШИРЕННЫЙ ЛОГГЕР (с периодическим выводом позиции лодки) =====
local function log(msg)
    print(string.format("[%s] %s", os.date("%H:%M:%S"), msg))
end

local player = game.Players.LocalPlayer
local char = player.Character or player.CharacterAdded:Wait()
local hrp = char:WaitForChild("HumanoidRootPart")
local humanoid = char:WaitForChild("Humanoid")

-- Отслеживаем появление лодки
local boat = nil
workspace.DescendantAdded:Connect(function(desc)
    if desc.Name == "Guardian" and desc:IsA("Model") then
        boat = desc
        log("!!! ЛОДКА ПОЯВИЛАСЬ: " .. boat:GetFullName())
    end
end)

-- Периодический вывод позиции лодки и статуса сидения
task.spawn(function()
    while true do
        task.wait(0.2)
        if boat and boat.Parent then
            local root = boat.PrimaryPart or boat:FindFirstChildWhichIsA("BasePart")
            if root then
                log("BOAT POS: " .. tostring(root.Position))
            end
        end
        log("SIT = " .. tostring(humanoid.Sit) .. ", SeatPart = " .. tostring(humanoid.SeatPart))
        log("CHAR VEL: " .. tostring(hrp.Velocity))
    end
end)

-- Отслеживаем изменения BodyVelocity у персонажа
char.DescendantAdded:Connect(function(desc)
    if desc:IsA("BodyVelocity") then
        log("CHAR BodyVelocity created")
        desc:GetPropertyChangedSignal("Velocity"):Connect(function()
            log("CHAR BodyVelocity Velocity = " .. tostring(desc.Velocity))
        end)
    end
end)

log("Логгер запущен. Теперь активируйте эталонный скрипт.")
