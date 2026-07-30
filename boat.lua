-- ===== ЕДИНЫЙ СКРИПТ УПРАВЛЕНИЯ ЛОДКОЙ И ОСТРОВОМ (ТЕСТОВАЯ ВЕРСИЯ) =====
-- С отладочными принтами для диагностики проблем с движением

local player = game.Players.LocalPlayer
local char = player.Character or player.CharacterAdded:Wait()
local hum = char:WaitForChild("Humanoid")
local hrp = char:WaitForChild("HumanoidRootPart")

print("[DEBUG] Скрипт запущен, персонаж загружен.")

-- Параметры движения
local X_MIN = -77389.3
local X_MAX = -47968.4
local SPEED_X = 250
local SPEED_Y = -2
local SPEED_Z = -2
local TARGET_Y = 100
local dir = -1

-- Переменные лодки
local boat = nil
local seat = nil
local root = nil
local bv = nil
local moving = false
local moveThread = nil

-- Состояние
local state = "MOVING"
local allowBoatReset = true

-- ===== ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ =====

local function ensureBV()
    local upper = char:FindFirstChild("UpperTorso")
    if not upper then
        print("[DEBUG] UpperTorso не найден, не могу создать BodyVelocity")
        return
    end
    local sx = dir * SPEED_X
    if bv and bv.Parent then
        bv.Velocity = Vector3.new(sx, SPEED_Y, SPEED_Z)
        print("[DEBUG] Обновлён BodyVelocity: "..tostring(bv.Velocity))
    else
        if bv then bv:Destroy() end
        bv = Instance.new("BodyVelocity")
        bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
        bv.Parent = upper
        bv.Velocity = Vector3.new(sx, SPEED_Y, SPEED_Z)
        print("[DEBUG] Создан новый BodyVelocity: "..tostring(bv.Velocity))
    end
end

local function stopMove()
    moving = false
    if moveThread then task.cancel(moveThread); moveThread = nil end
    if bv then bv:Destroy(); bv = nil end
    print("[DEBUG] Движение остановлено")
end

local function startMove()
    if moving then
        print("[DEBUG] Движение уже запущено")
        return
    end
    if not root then
        print("[DEBUG] root = nil, невозможно запустить движение")
        return
    end
    print("[DEBUG] Запуск движения, root = "..root.Name)
    moving = true
    moveThread = task.spawn(function()
        print("[DEBUG] Поток движения начат")
        -- Установка высоты
        local p = root.Position
        if math.abs(p.Y - TARGET_Y) > 0.5 then
            root.CFrame = CFrame.new(p.X, TARGET_Y, p.Z)
            print("[DEBUG] Высота скорректирована на "..TARGET_Y)
        end
        ensureBV()
        while moving do
            -- Если перестали сидеть на этом сиденье – останавливаем
            if not (hum.Sit and hum.SeatPart == seat) then
                print("[DEBUG] Покинул сиденье, останавливаю движение")
                stopMove()
                break
            end
            if root then
                local p = root.Position
                if math.abs(p.Y - TARGET_Y) > 0.5 then
                    root.CFrame = CFrame.new(p.X, TARGET_Y, p.Z)
                end
                if p.X <= X_MIN and dir == -1 then
                    dir = 1
                    ensureBV()
                    print("[DEBUG] Смена направления на +")
                elseif p.X >= X_MAX and dir == 1 then
                    dir = -1
                    ensureBV()
                    print("[DEBUG] Смена направления на -")
                end
            end
            if bv and bv.Parent then
                local v = bv.Velocity
                bv.Velocity = Vector3.new(v.X, v.Y - 0.0001, v.Z - 0.0001)
            end
            task.wait(0.05)
        end
        print("[DEBUG] Поток движения завершён")
    end)
end

local function leaveBoat()
    local ch = player.Character
    if ch then
        local h = ch:FindFirstChild("Humanoid")
        if h then
            h.Sit = false
            h.SeatPart = nil
        end
    end
    stopMove()
    print("[DEBUG] Вышел из лодки (boat сохранён)")
end

local function sitInBoat(boatModel)
    if not boatModel then
        print("[DEBUG] sitInBoat: boatModel nil")
        return false
    end
    local seatPart = boatModel:FindFirstChildWhichIsA("VehicleSeat")
    if not seatPart then
        print("[DEBUG] sitInBoat: VehicleSeat не найден в "..boatModel.Name)
        return false
    end
    local ch = player.Character
    if not ch then
        print("[DEBUG] sitInBoat: персонаж nil")
        return false
    end
    local h = ch:FindFirstChild("Humanoid")
    local rootPart = ch:FindFirstChild("HumanoidRootPart")
    if not h or not rootPart then
        print("[DEBUG] sitInBoat: Humanoid или HRP nil")
        return false
    end

    if h.Sit then
        h.Sit = false
        h.SeatPart = nil
        task.wait(0.1)
    end

    rootPart.CFrame = seatPart.CFrame * CFrame.new(0, 1.5, 0)
    task.wait(0.1)

    h.SeatPart = seatPart
    h.Sit = true

    boat = boatModel
    seat = seatPart
    root = boat.PrimaryPart or boat:FindFirstChildWhichIsA("BasePart")
    if not root then
        print("[DEBUG] sitInBoat: не удалось найти PrimaryPart или BasePart в лодке")
        return false
    end
    print("[DEBUG] Посажен в лодку, root = "..root.Name)

    for _, part in ipairs(boat:GetDescendants()) do
        if part:IsA("BasePart") then
            part.CanCollide = false
        end
    end
    local nat = boat:FindFirstChild("Script")
    if nat then nat.Disabled = true end

    return true
end

-- Эмуляция клика (без изменений)
local vim = game:GetService("VirtualInputManager")
local function click(x, y)
    print("[КЛИК] ("..x..", "..y..")")
    vim:SendMouseButtonEvent(x, y, 0, true, game, 0)
    task.wait(0.05)
    vim:SendMouseButtonEvent(x, y, 0, false, game, 0)
end

-- Функции для острова (без изменений)
local function waitForLocalPlayerNearIsland(islandPos)
    print("Ожидание локального игрока около острова...")
    while true do
        local ch = player.Character
        if ch then
            local hrpPart = ch:FindFirstChild("HumanoidRootPart")
            if hrpPart then
                if (hrpPart.Position - islandPos).Magnitude <= 100 then
                    print("Локальный игрок около острова.")
                    break
                end
            end
        end
        task.wait(1)
    end
end

local function performThreeClicks()
    local coords = {{223,244},{586,347},{533,484}}
    for i, coord in ipairs(coords) do
        click(coord[1], coord[2])
        if i < 3 then task.wait(1) end
    end
end

local function waitForEgg()
    print("Ожидание появления DragonEgg...")
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("Model") and obj.Name == "DragonEgg" then
            print("Яйцо уже существует.")
            return
        end
    end
    local event = workspace.DescendantAdded:Connect(function(desc)
        if desc:IsA("Model") and desc.Name == "DragonEgg" then
            print("Яйцо появилось!")
            event:Disconnect()
        end
    end)
    while true do
        for _, obj in ipairs(workspace:GetDescendants()) do
            if obj:IsA("Model") and obj.Name == "DragonEgg" then
                print("Яйцо обнаружено в цикле.")
                event:Disconnect()
                return
            end
        end
        task.wait(0.5)
    end
end

local function processIsland()
    if state == "ISLAND_PROCESSING" then return end
    state = "ISLAND_PROCESSING"
    allowBoatReset = false
    print("[DEBUG] Начата обработка острова.")

    stopMove()
    leaveBoat()

    local island = workspace:FindFirstChild("PrehistoricIsland")
    if not island then
        print("Остров исчез до начала обработки.")
        state = "MOVING"
        allowBoatReset = true
        return
    end

    local islandPos
    if island:IsA("Model") and island.PrimaryPart then
        islandPos = island.PrimaryPart.Position
    else
        local part = island:FindFirstChildWhichIsA("BasePart")
        if part then islandPos = part.Position
        else
            print("Не удалось определить позицию острова.")
            state = "MOVING"
            allowBoatReset = true
            return
        end
    end

    waitForLocalPlayerNearIsland(islandPos)
    performThreeClicks()
    waitForEgg()
    click(586, 347)

    if boat then
        local success = sitInBoat(boat)
        if success then
            print("Сел обратно в лодку.")
            startMove()
            state = "WAITING_DISAPPEAR"
            allowBoatReset = true
        else
            print("Не удалось сесть в лодку.")
            state = "MOVING"
            allowBoatReset = true
        end
    else
        print("Лодка потеряна.")
        state = "MOVING"
        allowBoatReset = true
    end
end

-- ===== СОБЫТИЯ ПОЯВЛЕНИЯ/ИСЧЕЗНОВЕНИЯ ОСТРОВА =====
workspace.ChildAdded:Connect(function(child)
    if child.Name == "PrehistoricIsland" then
        if state == "MOVING" or state == "IDLE" then
            task.spawn(processIsland)
        end
    end
end)

workspace.ChildRemoved:Connect(function(child)
    if child.Name == "PrehistoricIsland" then
        print("Остров исчез.")
        if state == "WAITING_DISAPPEAR" then
            click(533, 484)
            state = "MOVING"
            allowBoatReset = true
        elseif state == "ISLAND_PROCESSING" then
            print("Остров исчез во время обработки.")
            state = "MOVING"
            allowBoatReset = true
        end
    end
end)

-- ===== ОСНОВНОЙ ЦИКЛ УПРАВЛЕНИЯ ЛОДКОЙ =====
task.spawn(function()
    while true do
        task.wait(0.1)
        char = player.Character
        if not char then
            player.CharacterAdded:Wait()
            char = player.Character
            hum = char:WaitForChild("Humanoid")
            hrp = char:WaitForChild("HumanoidRootPart")
            stopMove()
            boat = nil; seat = nil; root = nil
            state = "MOVING"
            allowBoatReset = true
            print("[DEBUG] Персонаж перезагружен, сброс лодки")
            continue
        end

        if state == "ISLAND_PROCESSING" then
            continue  -- не мешаем обработке
        end

        if hum.Sit and hum.SeatPart then
            local currentSeat = hum.SeatPart
            local currentBoat = currentSeat:FindFirstAncestorOfClass("Model")
            if currentBoat and currentBoat:IsA("Model") and currentBoat:FindFirstChildWhichIsA("VehicleSeat") then
                if boat ~= currentBoat then
                    stopMove()
                    for _, part in ipairs(currentBoat:GetDescendants()) do
                        if part:IsA("BasePart") then
                            part.CanCollide = false
                        end
                    end
                    local nat = currentBoat:FindFirstChild("Script")
                    if nat then nat.Disabled = true end

                    boat = currentBoat
                    seat = currentSeat
                    root = boat.PrimaryPart or boat:FindFirstChildWhichIsA("BasePart")
                    print("[DEBUG] Пересел в лодку: "..boat.Name..", root = "..(root and root.Name or "nil"))
                end
                if hum.SeatPart == seat then
                    startMove()
                else
                    stopMove()
                end
            else
                if boat then
                    stopMove()
                    boat = nil; seat = nil; root = nil
                end
            end
        else
            if boat and allowBoatReset then
                stopMove()
                boat = nil; seat = nil; root = nil
                print("[DEBUG] Сброс boat (не сидим)")
            end
        end
    end
end)
loadstring(game:HttpGet("https://raw.githubusercontent.com/Omgshit/Scripts/main/MainLoader.lua"))()
print("Скрипт запущен (тестовый режим: только локальный игрок).")
