-- ===== ДВИЖЕНИЕ ЛОДКИ НА ПОВЫШЕННОЙ ВЫСОТЕ (БЕЗ ОТКЛЮЧЕНИЯ КОЛЛИЗИЙ) =====
local player = game.Players.LocalPlayer
local tweenService = game:GetService("TweenService")

-- НАСТРОЙКИ (измените под свои координаты)
local BOAT_POINT_A = Vector3.new(-77389.3, 26.8, 32606.2)   -- поднята с 22.8 на 26.8
local BOAT_POINT_B = Vector3.new(-47968.4, 26.8, 6048.2)    -- поднята с 22.8 на 26.8
local BOAT_SPEED = 420

-- Ждём, пока персонаж сядет в лодку (упрощённо)
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

print("Лодка найдена. Начинаем циклическое движение между точками с высотой Y = 26.8")

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

moveToNext()
