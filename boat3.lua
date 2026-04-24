-- ===== ДВИЖЕНИЕ ЛОДКИ НА ФИКСИРОВАННОЙ ВЫСОТЕ (Y = 50) =====
local player = game.Players.LocalPlayer
local tweenService = game:GetService("TweenService")

-- НАСТРОЙКИ
local BOAT_POINT_A = Vector3.new(-77389.3, 50, 32606.2)   -- Y = 50
local BOAT_POINT_B = Vector3.new(-47968.4, 50, 6048.2)    -- Y = 50
local BOAT_SPEED = 420

-- Ждём посадки
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

print("Ожидание посадки в лодку...")
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

-- ПОДНЯТИЕ ЛОДКИ (ОДИН РАЗ) И БЛОКИРОВКА ВЫСОТЫ
local function liftAndLockHeight()
    local pos = rootPart.Position
    rootPart.CFrame = CFrame.new(pos.X, 50, pos.Z)
    print("Лодка поднята на высоту 50")
    -- Фоновый поток для поддержания высоты (если игра сбивает)
    task.spawn(function()
        while boat and boat.Parent do
            local p = rootPart.Position
            if math.abs(p.Y - 50) > 0.5 then
                rootPart.CFrame = CFrame.new(p.X, 50, p.Z)
            end
            task.wait(0.2)
        end
    end)
end

liftAndLockHeight()

-- ЦИКЛИЧЕСКОЕ ДВИЖЕНИЕ МЕЖДУ ТОЧКАМИ
local points = {BOAT_POINT_A, BOAT_POINT_B}
local index = 1
local currentTween = nil

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

print("Начинаем движение на высоте 50")
moveToNext()
