-- ============================================================
-- AutoFarm Prehistoric Island + Boat Movement (FULL VERSION)
-- Использует оригинальный скрипт движения лодки (BodyVelocity).
-- Хаб загружается автоматически, затем скрипт управляет кнопками 5,6 и 5,10.
-- Цикл: активация 5,6 -> посадка -> деактивация 5,6 -> ожидание 10с -> движение лодки.
-- При появлении острова -> активация 5,10 -> ожидание всех игроков -> возврат в лодку.
-- ============================================================

-- 1. Загружаем хаб в фоне
task.spawn(function()
    pcall(function()
        loadstring(game:HttpGet("https://raw.githubusercontent.com/Omgshit/Scripts/main/MainLoader.lua"))()
    end)
end)

-- Сервисы
local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local Workspace = game:GetService("Workspace")
local player = Players.LocalPlayer

-- Настройки
local BOAT_TAB = 5
local BOAT_OPT = 6
local ISLAND_OPT = 10
local COLOR_ON  = "0.345098, 0.396078, 0.94902"
local COLOR_OFF = "0.239216, 0.262745, 0.529412"
local X_MIN = -77389.3
local X_MAX = -47968.4
local SPEED_X = 250
local SPEED_Y = -2
local SPEED_Z = -2
local TARGET_Y = 100

-- Функция логирования
local function log(msg)
    pcall(function() warn("[AutoFarm]", msg) end)
end

-- Ожидание появления redz-library-v5 (интерфейс хаба)
local function getRoot()
    for _, child in ipairs(CoreGui:GetChildren()) do
        local obj = child:FindFirstChild("redz-library-v5")
        if obj then return obj end
    end
    return nil
end

local function safeFind(obj, ...)
    for _, name in ipairs({...}) do
        if not obj then return nil end
        obj = obj:FindFirstChild(name)
    end
    return obj
end

-- Проверка полной загрузки интерфейса (TabsScroll должен существовать)
local function waitForInterface()
    if not getRoot() then return false end
    return safeFind(getRoot(), "Window", "Components", "TabsScroll") ~= nil
end

log("Ожидание интерфейса хаба...")
repeat task.wait(0.5) until waitForInterface()
log("Интерфейс загружен.")

-- ======================== GUI ФУНКЦИИ =========================
local function fireSequence(btn)
    if not (btn:IsA("TextButton") or btn:IsA("ImageButton")) then return end
    local signals = {"MouseEnter","MouseButton1Down","MouseButton1Click","MouseButton1Up","Activated","MouseLeave"}
    for _, sig in ipairs(signals) do
        local event = btn[sig]
        if event then
            for _, conn in ipairs(getconnections(event) or {}) do
                if conn.Enabled then pcall(conn.Function) end
            end
        end
    end
end

local function findIndicatorFrame(parent)
    for _, child in ipairs(parent:GetChildren()) do
        if child:IsA("Frame") then
            local col = tostring(child.BackgroundColor3)
            if col == COLOR_ON or col == COLOR_OFF then return child end
        end
        local found = findIndicatorFrame(child)
        if found then return found end
    end
    return nil
end

local function getOptionState(tabIndex, optIndex)
    local root = getRoot()
    if not root then return nil end
    local tabsScroll = safeFind(root, "Window", "Components", "TabsScroll")
    if not tabsScroll then return nil end
    -- Ищем вкладку
    local tabButton, tabCount = nil, 0
    local function findTab(parent)
        if tabButton then return end
        for _, child in ipairs(parent:GetChildren()) do
            if child:IsA("TextButton") or child:IsA("ImageButton") then
                tabCount = tabCount + 1
                if tabCount == tabIndex then tabButton = child return end
            end
            findTab(child)
        end
    end
    findTab(tabsScroll)
    if not tabButton then return nil end
    fireSequence(tabButton)
    task.wait(0.3)  -- задержка для прогрузки контейнера
    -- Контейнер с опциями
    local container = safeFind(root, "Window", "Components", "Containers", "Container")
    if not container then return nil end
    local optionBtn, optCount = nil, 0
    for _, child in ipairs(container:GetChildren()) do
        if child.Name == "Option" and child.Visible and (child:IsA("TextButton") or child:IsA("ImageButton")) then
            optCount = optCount + 1
            if optCount == optIndex then optionBtn = child break end
        end
    end
    if not optionBtn then return nil end
    local indicator = findIndicatorFrame(optionBtn)
    if not indicator then return nil end
    local col = tostring(indicator.BackgroundColor3)
    return (col == COLOR_ON and "on") or (col == COLOR_OFF and "off") or nil
end

local function setOptionState(tabIndex, optIndex, desiredState, conflictTab, conflictOpt)
    if desiredState ~= "on" and desiredState ~= "off" then return false end
    local root = getRoot()
    if not root then return false end
    -- Если нужно включить опцию, сначала выключаем конфликтную (если задана)
    if desiredState == "on" and conflictTab and conflictOpt then
        if getOptionState(conflictTab, conflictOpt) == "on" then
            -- Переключаемся на вкладку конфликтной опции и выключаем её
            local cfRoot = getRoot()
            if cfRoot then
                local cfTabsScroll = safeFind(cfRoot, "Window", "Components", "TabsScroll")
                if cfTabsScroll then
                    local cfTabBtn, cfTabCount = nil, 0
                    local function findCfTab(p)
                        if cfTabBtn then return end
                        for _, c in ipairs(p:GetChildren()) do
                            if c:IsA("TextButton") or c:IsA("ImageButton") then
                                cfTabCount = cfTabCount + 1
                                if cfTabCount == conflictTab then cfTabBtn = c return end
                            end
                            findCfTab(c)
                        end
                    end
                    findCfTab(cfTabsScroll)
                    if cfTabBtn then fireSequence(cfTabBtn) task.wait(0.3) end
                end
                local cfContainer = safeFind(cfRoot, "Window", "Components", "Containers", "Container")
                if cfContainer then
                    local cfOptCount = 0
                    for _, c in ipairs(cfContainer:GetChildren()) do
                        if c.Name == "Option" and c.Visible and (c:IsA("TextButton") or c:IsA("ImageButton")) then
                            cfOptCount = cfOptCount + 1
                            if cfOptCount == conflictOpt then
                                local ind = findIndicatorFrame(c)
                                if ind and tostring(ind.BackgroundColor3) == COLOR_ON then
                                    fireSequence(c)  -- выключаем
                                end
                                break
                            end
                        end
                    end
                end
                task.wait(0.1)
            end
        end
    end
    -- Теперь переключаем целевую опцию
    local tabsScroll = safeFind(root, "Window", "Components", "TabsScroll")
    if not tabsScroll then return false end
    local tabButton, tabCount = nil, 0
    local function findTab(parent)
        if tabButton then return end
        for _, child in ipairs(parent:GetChildren()) do
            if child:IsA("TextButton") or child:IsA("ImageButton") then
                tabCount = tabCount + 1
                if tabCount == tabIndex then tabButton = child return end
            end
            findTab(child)
        end
    end
    findTab(tabsScroll)
    if not tabButton then return false end
    fireSequence(tabButton)
    task.wait(0.3)
    local container = safeFind(root, "Window", "Components", "Containers", "Container")
    if not container then return false end
    local optionBtn, optCount = nil, 0
    for _, child in ipairs(container:GetChildren()) do
        if child.Name == "Option" and child.Visible and (child:IsA("TextButton") or child:IsA("ImageButton")) then
            optCount = optCount + 1
            if optCount == optIndex then optionBtn = child break end
        end
    end
    if not optionBtn then return false end
    local indicator = findIndicatorFrame(optionBtn)
    if not indicator then return false end
    local currentCol = tostring(indicator.BackgroundColor3)
    local currentState = (currentCol == COLOR_ON and "on") or (currentCol == COLOR_OFF and "off") or nil
    if currentState == desiredState then return true end  -- уже нужное
    fireSequence(optionBtn)
    task.wait(0.1)
    return true
end

-- ====================== ДВИЖЕНИЕ ЛОДКИ ========================
-- (Оригинальный скрипт с BodyVelocity, интегрированный в наш цикл)
local boat = nil
local seat = nil
local root = nil
local dir = -1
local bv = nil
local moving = false
local moveThread = nil

local function ensureBV()
    local char = player.Character
    if not char then return end
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

local function stopMove()
    moving = false
    if moveThread then task.cancel(moveThread); moveThread = nil end
    if bv then bv:Destroy(); bv = nil end
end

local function startMove()
    if moving then return end
    if not root then return end
    moving = true
    moveThread = task.spawn(function()
        -- начальная корректировка высоты
        local p = root.Position
        if math.abs(p.Y - TARGET_Y) > 0.5 then
            root.CFrame = CFrame.new(p.X, TARGET_Y, p.Z)
        end
        ensureBV()
        while moving do
            local char = player.Character
            local hum = char and char:FindFirstChild("Humanoid")
            if not (hum and hum.Sit and hum.SeatPart == seat) then
                stopMove()
                break
            end
            if root then
                local p = root.Position
                -- поддержание высоты
                if math.abs(p.Y - TARGET_Y) > 0.5 then
                    root.CFrame = CFrame.new(p.X, TARGET_Y, p.Z)
                end
                -- смена направления у границ
                if p.X <= X_MIN and dir == -1 then
                    dir = 1
                    ensureBV()
                elseif p.X >= X_MAX and dir == 1 then
                    dir = -1
                    ensureBV()
                end
            end
            -- легкое обновление скорости, чтобы физика не "засыпала"
            if bv and bv.Parent then
                local v = bv.Velocity
                bv.Velocity = Vector3.new(v.X, v.Y - 0.0001, v.Z - 0.0001)
            end
            task.wait(0.05)
        end
    end)
end

-- Проверка: сидим ли мы в лодке (VehicleSeat)
local function isInBoat()
    local char = player.Character
    if not char then return false end
    local hum = char:FindFirstChild("Humanoid")
    if not hum or not hum.Sit or not hum.SeatPart then return false end
    local seatPart = hum.SeatPart
    local model = seatPart:FindFirstAncestorOfClass("Model")
    if model and model:FindFirstChildWhichIsA("VehicleSeat") then
        return true, model, seatPart
    end
    return false
end

-- ======================= ОСТРОВ ==========================
local function findIsland()
    local map = Workspace:FindFirstChild("Map")
    if map then
        local island = map:FindFirstChild("PrehistoricIsland")
        if island then
            local core = island:FindFirstChild("Core")
            if core then
                local promptContainer = core:FindFirstChild("ActivationPrompt")
                if promptContainer then
                    local prompt = promptContainer:FindFirstChild("ProximityPrompt")
                    if prompt and prompt:IsA("ProximityPrompt") and prompt.Enabled then
                        return island
                    end
                end
            end
        end
    end
    return nil
end

local function getIslandPosition(island)
    if island:IsA("Model") and island.PrimaryPart then
        return island.PrimaryPart.Position
    else
        local part = island:FindFirstChildWhichIsA("BasePart")
        return part and part.Position
    end
end

local function allPlayersNearIsland(islandPos)
    if not islandPos then return false end
    for _, plr in ipairs(Players:GetPlayers()) do
        local char = plr.Character
        if char then
            local hrp = char:FindFirstChild("HumanoidRootPart")
            if hrp then
                if (hrp.Position - islandPos).Magnitude > 100 then
                    return false
                end
            else
                return false
            end
        else
            return false
        end
    end
    return true
end

-- ====================== ОСНОВНОЙ ЦИКЛ =========================
local state = "INIT"

-- Вспомогательная функция ожидания персонажа
local function waitForCharacter()
    while not player.Character or not player.Character:FindFirstChild("HumanoidRootPart") do
        player.CharacterAdded:Wait()
        task.wait(0.2)
    end
end

log("Скрипт AutoFarm запущен.")

while true do
    local char = player.Character
    local hum = char and char:FindFirstChild("Humanoid")
    local hrp = char and char:FindFirstChild("HumanoidRootPart")

    -- Если персонаж не готов, сбрасываем всё и ждём
    if not hum or hum.Health <= 0 or not hrp then
        stopMove()
        boat, seat, root = nil, nil, nil
        state = "INIT"
        waitForCharacter()
        continue
    end

    if state == "INIT" then
        if not waitForInterface() then
            task.wait(0.5)
            continue
        end
        log("Интерфейс готов, начинаем.")
        state = "WAITING_FOR_BOAT_OPTION"

    elseif state == "WAITING_FOR_BOAT_OPTION" then
        -- Убедимся, что 5,6 включена
        local curState = getOptionState(BOAT_TAB, BOAT_OPT)
        if curState == "off" then
            log("Включаем кнопку лодки 5,6")
            setOptionState(BOAT_TAB, BOAT_OPT, "on", BOAT_TAB, ISLAND_OPT)
        elseif curState == nil then
            log("Кнопка лодки не найдена, ждём...")
            task.wait(1)
            continue
        end
        state = "WAITING_FOR_BOARD_BOAT"
        task.wait(0.2)

    elseif state == "WAITING_FOR_BOARD_BOAT" then
        local inBoat, boatModel, seatPart = isInBoat()
        if inBoat then
            log("Сел в лодку. Выключаем 5,6 и ждём 10 сек...")
            setOptionState(BOAT_TAB, BOAT_OPT, "off")
            task.wait(10)
            -- Подготовка лодки
            boat = boatModel
            seat = seatPart
            root = boat.PrimaryPart or boat:FindFirstChildWhichIsA("BasePart")
            for _, part in ipairs(boat:GetDescendants()) do
                if part:IsA("BasePart") then part.CanCollide = false end
            end
            local natScript = boat:FindFirstChild("Script")
            if natScript then natScript.Disabled = true end
            -- Запуск движения
            startMove()
            state = "MOVING_ON_BOAT"
        else
            -- Иногда повторно включаем кнопку, если не сели
            task.wait(0.5)
            if math.random(1,10) == 1 then
                setOptionState(BOAT_TAB, BOAT_OPT, "on", BOAT_TAB, ISLAND_OPT)
            end
        end

    elseif state == "MOVING_ON_BOAT" then
        -- Проверяем, всё ещё в лодке
        local inBoat, boatModel = isInBoat()
        if not inBoat or boatModel ~= boat then
            log("Вышли из лодки, перезапуск.")
            stopMove()
            boat, seat, root = nil, nil, nil
            state = "WAITING_FOR_BOAT_OPTION"
            continue
        end
        -- Проверка на появление острова
        if findIsland() then
            log("Остров обнаружен! Останавливаем лодку.")
            stopMove()
            state = "GOING_TO_ISLAND"
        end
        task.wait(0.5)

    elseif state == "GOING_TO_ISLAND" then
        log("Меняем кнопки: выключаем 5,6, включаем 5,10")
        setOptionState(BOAT_TAB, BOAT_OPT, "off")
        setOptionState(BOAT_TAB, ISLAND_OPT, "on", BOAT_TAB, BOAT_OPT)
        local islandObj = findIsland()
        if not islandObj then
            log("Остров пропал, возвращаемся к лодке.")
            state = "WAITING_FOR_BOAT_OPTION"
            continue
        end
        local islandPos = getIslandPosition(islandObj)
        if not islandPos then
            state = "WAITING_FOR_BOAT_OPTION"
            continue
        end
        -- Ждём, пока персонаж окажется рядом с островом (функция хаба его перенесёт)
        if hrp and (hrp.Position - islandPos).Magnitude <= 100 then
            log("Персонаж на месте, ждём остальных игроков.")
            state = "WAITING_ALL_NEAR"
        else
            task.wait(0.3)
        end

    elseif state == "WAITING_ALL_NEAR" then
        local island = findIsland()
        if not island then
            log("Остров исчез, перезапуск.")
            state = "WAITING_FOR_BOAT_OPTION"
            continue
        end
        local islandPos = getIslandPosition(island)
        if not islandPos then
            state = "WAITING_FOR_BOAT_OPTION"
            continue
        end
        if allPlayersNearIsland(islandPos) then
            log("Все игроки на острове! Возвращаемся в лодку.")
            state = "RETURN_TO_BOAT"
        else
            task.wait(1)
        end

    elseif state == "RETURN_TO_BOAT" then
        log("Возврат: выключаем 5,10, включаем 5,6")
        setOptionState(BOAT_TAB, ISLAND_OPT, "off")
        setOptionState(BOAT_TAB, BOAT_OPT, "on", BOAT_TAB, ISLAND_OPT)
        state = "WAITING_FOR_BOARD_BOAT"  -- дальше цикл сам обработает посадку
        task.wait(0.2)
    end

    task.wait(0.1)
end
