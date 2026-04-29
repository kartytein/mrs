-- ===== ТОЧНОЕ ПОВТОРЕНИЕ ЭТАЛОННОГО СКРИПТА (BODYVELOCITY НА UPPERTORSO) =====
local player = game.Players.LocalPlayer

-- Ждём посадки
local function waitForSeat()
    while true do
        local char = player.Character
        if char then
            local humanoid = char:FindFirstChild("Humanoid")
            if humanoid and humanoid.Sit and humanoid.SeatPart then
                return humanoid.SeatPart, humanoid
            end
        end
        task.wait(0.5)
    end
end

print("Ожидание посадки в лодку...")
local seat, humanoid = waitForSeat()
local boat = seat:FindFirstAncestorWhichIsA("Model")
if not boat then error("Лодка не найдена") end
local rootPart = boat.PrimaryPart or boat:FindFirstChildWhichIsA("BasePart")
if not rootPart then error("Нет основной части лодки") end

local char = player.Character
local upperTorso = char:FindFirstChild("UpperTorso")
if not upperTorso then error("UpperTorso не найден") end

-- Создаём BodyVelocity с нулевой скоростью (как в эталоне)
local bv = Instance.new("BodyVelocity")
bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
bv.Parent = upperTorso
bv.Velocity = Vector3.new(0, 2, 0)  -- как в логе: "скорость = 0, 2, 0"
print("BodyVelocity создан с начальной скоростью 0,2,0")

-- Небольшая задержка перед установкой боевой скорости
task.wait(0.1)
bv.Velocity = Vector3.new(-250, -2, -2)
print("Скорость установлена: -250, -2, -2")

-- Настройки границ
local X_MIN = -77389.3
local X_MAX = -47968.4
local currentDirection = -1
local baseSpeedX = 250
local speedY = -2
local speedZ = -2

-- Поток для постоянного микро-обновления скорости (каждые 0.05 сек, как в эталоне)
task.spawn(function()
    while true do
        if not (humanoid and humanoid.Sit and humanoid.SeatPart == seat) then
            print("Персонаж вышел, останавливаем движение")
            bv:Destroy()
            break
        end
        -- Обновляем скорость, добавляя микро-вариации (имитируем лог)
        local microX = baseSpeedX * currentDirection + (math.random() - 0.5) * 0.001
        bv.Velocity = Vector3.new(microX, speedY + (math.random() - 0.5) * 0.001, speedZ + (math.random() - 0.5) * 0.001)
        task.wait(0.05)
    end
end)

-- Отслеживаем позицию лодки и меняем направление
task.spawn(function()
    while true do
        if not (humanoid and humanoid.Sit and humanoid.SeatPart == seat) then
            break
        end
        local x = rootPart.Position.X
        if x <= X_MIN and currentDirection == -1 then
            currentDirection = 1
            print("Смена направления → вправо (X = " .. x .. ")")
        elseif x >= X_MAX and currentDirection == 1 then
            currentDirection = -1
            print("Смена направления → влево (X = " .. x .. ")")
        end
        task.wait(0.2)
    end
end)

print("Скрипт точно повторяет эталон. Лодка должна двигаться без сбросов.")
