-- ===== ИСПРАВЛЕННЫЙ СКРИПТ (принудительные действия при isSitting = false) =====
local player = game.Players.LocalPlayer
local playerName = player.Name
local tweenService = game:GetService("TweenService")

-- НАСТРОЙКИ
local MOVE_POINT = Vector3.new(-16917, 9.1, 447)
local BOAT_THRESHOLD_X = -77389
local BOAT_POINT_FAR = Vector3.new(-77389.3, 22.8, 32606.2)
local BOAT_POINT_NEAR = Vector3.new(-47968.4, 22.8, 6048.2)
local WALK_SPEED = 150
local BOAT_SPEED = 420
local SEAT_OFFSET = Vector3.new(0, 2.5, 0)
local COLLISION_INTERVAL = 0.3

local isSitting = false
local needToSit = false
local myBoat = nil
local seat = nil
local rootPart = nil
local currentTween = nil
local stopScript = false

-- ... (функции maintainCollisions, disableAllCollisions, selectMarines, moveCharacterTo, findMyBoat, sitOnSeat, stopBoat, startBoatMovement остаются без изменений, как в предыдущем сообщении) ...

-- НЕПРЕРЫВНЫЙ МОНИТОР ПОСАДКИ (отдельный поток)
task.spawn(function()
    while not stopScript do
        local char = player.Character
        local humanoid = char and char:FindFirstChild("Humanoid")
        local sitting = humanoid and humanoid.Sit and humanoid.SeatPart == seat
        print("[CHECK] Сидит в лодке:", sitting)
        if sitting ~= isSitting then
            isSitting = sitting
            if not isSitting then
                needToSit = true
                stopBoat()
                print("[CHECK] needToSit = true")
            else
                needToSit = false
                print("[CHECK] needToSit = false")
            end
        end
        -- Если isSitting = false, но needToSit по какой-то причине false, принудительно выставляем
        if not isSitting and not needToSit then
            needToSit = true
            print("[CHECK] Принудительно установлен needToSit = true")
        end
        -- Обновление ссылок на лодку
        if myBoat and (not myBoat.Parent or not seat or not rootPart) then
            myBoat = nil
            seat = nil
            rootPart = nil
            needToSit = true
            print("[CHECK] Лодка потеряна, сброс ссылок")
        end
        task.wait(0.2)
    end
end)

-- ГЛАВНЫЙ ЦИКЛ (действия)
task.spawn(function()
    selectMarines()
    task.wait(2)

    while not stopScript do
        if needToSit then
            print("[MAIN] needToSit активен, начинаем процесс посадки")
            -- Если нет лодки или она пропала, покупаем
            if not myBoat or not myBoat.Parent then
                print("[MAIN] Лодки нет, перемещаемся к точке покупки")
                moveCharacterTo(MOVE_POINT, WALK_SPEED)
                print("[MAIN] Призываем лодку")
                local remote = game:GetService("ReplicatedStorage").Remotes.CommF_
                if remote then
                    remote:InvokeServer("BuyBoat", "Guardian")
                else
                    print("[MAIN] Ошибка: CommF_ не найден")
                end
                task.wait(3)
                -- Ищем лодку
                for i = 1, 10 do
                    myBoat = findMyBoat()
                    if myBoat then break end
                    task.wait(1)
                end
                if not myBoat then
                    print("[MAIN] Не удалось найти лодку, повтор через 5 сек")
                    task.wait(5)
                    continue
                end
                print("[MAIN] Лодка найдена:", myBoat.Name)
                seat = myBoat:FindFirstChildWhichIsA("VehicleSeat")
                rootPart = myBoat.PrimaryPart or myBoat:FindFirstChildWhichIsA("BasePart")
                if not seat or not rootPart then
                    print("[MAIN] Ошибка: нет сиденья или основной части")
                    myBoat = nil
                    continue
                end
                -- Отключаем коллизии у лодки
                for _, part in ipairs(myBoat:GetDescendants()) do
                    if part:IsA("BasePart") then part.CanCollide = false end
                end
                myBoat.DescendantAdded:Connect(function(desc)
                    if desc:IsA("BasePart") then desc.CanCollide = false end
                end)
                local native = myBoat:FindFirstChild("Script")
                if native then native.Disabled = true end
            end

            -- Пытаемся сесть
            local char = player.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            local humanoid = char and char:FindFirstChild("Humanoid")
            if hrp and humanoid then
                print("[MAIN] Запуск посадки на сиденье")
                sitOnSeat(seat, hrp, humanoid)
                task.wait(0.5)
                -- Проверяем, сели ли
                if isSitting then
                    needToSit = false
                    print("[MAIN] Посадка подтверждена, needToSit = false")
                else
                    print("[MAIN] Посадка не удалась, повтор через 1 сек")
                    task.wait(1)
                end
            else
                print("[MAIN] Нет персонажа или HRP, ждём...")
                task.wait(1)
            end
        else
            -- Если сидим, управляем лодкой
            if isSitting and myBoat and rootPart then
                startBoatMovement()
            end
            task.wait(0.3)
        end
    end
end)

print("Скрипт запущен. Принудительная посадка при isSitting = false.")
