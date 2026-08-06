-- ===== МИНИМАЛЬНЫЙ СКРИПТ ДВИЖЕНИЯ ЛОДКИ =====
local player = game.Players.LocalPlayer
local char = player.Character or player.CharacterAdded:Wait()
local hum = char:WaitForChild("Humanoid")
local hrp = char:WaitForChild("HumanoidRootPart")

-- Параметры движения
local X_MIN = -77389.3
local X_MAX = -47968.4
local SPEED_X = 250
local SPEED_Y = -2
local SPEED_Z = -2
local TARGET_Y = 100
local dir = -1

local boat = nil      -- модель лодки, в которой сидим
local seat = nil      -- сиденье этой лодки
local root = nil      -- PrimaryPart лодки
local bv = nil        -- BodyVelocity
local moving = false
local moveThread = nil

-- Функция обновления скорости
local function ensureBV()
    local upper = char:FindFirstChild("UpperTorso")
    if not upper then return end
    local sx = dir * SPEED_X
    if bv and bv.Parent then
        bv.Velocity = Vector3.new(sx, SPEED_Y, SPEED_Z)
    else
        if bv then bv:Destroy() end
        bv = Instance.new("BodyVelocity")
        bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
        bv.Parent = upper
        bv.Velocity = Vector3.new(sx, SPEED_Y, SPEED_Z)
    end
end

-- Остановка
local function stopMove()
    moving = false
    if moveThread then task.cancel(moveThread); moveThread = nil end
    if bv then bv:Destroy(); bv = nil end
end

-- Запуск
local function startMove()
    if moving then return end
    moving = true
    moveThread = task.spawn(function()
        if not root then return end
        -- Первоначальная установка Y
        local p = root.Position
        if math.abs(p.Y - TARGET_Y) > 0.5 then
            root.CFrame = CFrame.new(p.X, TARGET_Y, p.Z)
        end
        ensureBV()
        while moving do
            -- Если перестали сидеть на этом сиденье – останавливаем
            if not (hum.Sit and hum.SeatPart == seat) then
                stopMove()
                break
            end
            if root then
                local p = root.Position
                -- Корректировка высоты
                if math.abs(p.Y - TARGET_Y) > 0.5 then
                    root.CFrame = CFrame.new(p.X, TARGET_Y, p.Z)
                end
                -- Смена направления у границ
                if p.X <= X_MIN and dir == -1 then
                    dir = 1
                    ensureBV()
                elseif p.X >= X_MAX and dir == 1 then
                    dir = -1
                    ensureBV()
                end
            end
            -- Небольшое обновление скорости, чтобы физика не засыпала
            if bv and bv.Parent then
                local v = bv.Velocity
                bv.Velocity = Vector3.new(v.X, v.Y - 0.0001, v.Z - 0.0001)
            end
            task.wait(0.05)
        end
    end)
end

-- ===== ОСНОВНОЙ ЦИКЛ =====
task.spawn(function()
    while true do
        task.wait(0.1)
        char = player.Character
        if not char then
            -- Если персонаж умер/перезагрузился – ждём
            player.CharacterAdded:Wait()
            char = player.Character
            hum = char:WaitForChild("Humanoid")
            hrp = char:WaitForChild("HumanoidRootPart")
            continue
        end

        -- Если мы сидим на каком-то сиденье
        if hum.Sit and hum.SeatPart then
            local currentSeat = hum.SeatPart
            local currentBoat = currentSeat:FindFirstAncestorOfClass("Model")
            -- Проверяем, что это лодка (ищем по наличию VehicleSeat или по имени)
            if currentBoat and currentBoat:IsA("Model") and currentBoat:FindFirstChildWhichIsA("VehicleSeat") then
                -- Если это другая лодка – обновляем переменные
                if boat ~= currentBoat then
                    -- Останавливаем старое движение
                    stopMove()
                    -- Отключаем коллизии у всех частей лодки
                    for _, part in ipairs(currentBoat:GetDescendants()) do
                        if part:IsA("BasePart") then
                            part.CanCollide = false
                        end
                    end
                    -- Отключаем скрипты лодки (чтобы не мешали)
                    local nat = currentBoat:FindFirstChild("Script")
                    if nat then nat.Disabled = true end

                    boat = currentBoat
                    seat = currentSeat
                    root = currentBoat.PrimaryPart or currentBoat:FindFirstChildWhichIsA("BasePart")
                    print("Сел в лодку:", boat.Name)
                end
                -- Запускаем движение, если сидим именно на этом сиденье
                if hum.SeatPart == seat then
                    startMove()
                else
                    stopMove()
                end
            else
                -- Сидим не на лодке – останавливаем движение и сбрасываем
                if boat then
                    stopMove()
                    boat = nil; seat = nil; root = nil
                end
            end
        else
            -- Не сидим – сбрасываем
            if boat then
                stopMove()
                boat = nil; seat = nil; root = nil
            end
        end
    end
end)

print("Скрипт движения запущен. Садись в лодку – она поедет.")

