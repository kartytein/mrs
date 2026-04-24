-- ===== ДВИЖЕНИЕ ЛОДКИ С ПОДНЯТИЕМ ВЫШЕ (Y=50) =====
local player = game.Players.LocalPlayer
local tweenService = game:GetService("TweenService")

-- НАСТРОЙКИ
local BOAT_POINT_A = Vector3.new(-77389.3, 50, 32606.2)   -- поднята на 50
local BOAT_POINT_B = Vector3.new(-47968.4, 50, 6048.2)    -- поднята на 50
local BOAT_SPEED = 420

-- Ждём, пока персонаж сядет в лодку
local function waitForSeat()
    local char = player.Character
    if not char then return nil end
    local humanoid = char:FindFirstChild("Humanoid")
    if not humanoid then return nil end
    repeat
        task.wait(0.5)
    until humanoid.Sit and humanoid.SeatPart
    return humanoid.SeatPart
end

local seat = waitForSeat()
if not seat then
    warn("Не удалось обнаружить сиденье")
    return
end

local boat = seat:FindFirstAncestorWhichIsA("Model")
if not boat then
    warn("Лодка не найдена")
    return
end

local rootPart = boat.PrimaryPart or boat:FindFirstChildWhichIsA("BasePart")
if not rootPart then
    warn("Основная часть лодки не найдена")
    return
end

-- Поднимаем лодку на нужную высоту сразу
rootPart.CFrame = CFrame.new(rootPart.Position.X, 50, rootPart.Position.Z)

print("Лодка находится на высоте Y=50, начинаем циклическое движение")

local points = {BOAT_POINT_A, BOAT_POINT_B}
local index = 1
local currentTween = nil

-- Функция для поддержания высоты (запускается в фоне)
task.spawn(function()
    while true do
        task.wait(0.1)
        if rootPart and rootPart.Parent then
            local pos = rootPart.Position
            if math.abs(pos.Y - 50) > 0.5 then
                rootPart.CFrame = CFrame.new(pos.X, 50, pos.Z)
            end
        end
    end
end)

local function moveToNext()
    local target = points[index]
    local dist = (rootPart.Position - target).Magnitude
    local duration = dist / BOAT_SPEED
    if duration > 0 then
        currentTween = tweenService:Create(rootPart, TweenInfo.new(duration, Enum.EasingStyle.Linear), {CFrame = CFrame.new(target)})
        currentTween:Play()
        currentTween.Completed:Connect(function()
            currentTween = nil
            index = index % #points + 1
            moveToNext()
        end)
    end
end

moveToNext()
