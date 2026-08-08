-- ============================================================
-- SHORT VERSION: только активация лодки и движение
-- Загрузите хаб вручную перед запуском этого скрипта.
-- ============================================================

local origWarn = warn
local function log(msg) pcall(function() origWarn("[Boat]", msg) end) end

-- Настройки
local BOAT_TAB, BOAT_OPT = 5, 6
local COLOR_ON  = "0.345098, 0.396078, 0.94902"
local COLOR_OFF = "0.239216, 0.262745, 0.529412"
local X_MIN, X_MAX = -77389.3, -47968.4
local SPEED_X = 250
local TARGET_Y = 100

-- Сервисы
local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local player = Players.LocalPlayer

-- Поиск интерфейса
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

-- Ожидание полной загрузки интерфейса
local function waitForInterface()
    if not getRoot() then return false end
    return safeFind(getRoot(), "Window", "Components", "TabsScroll") ~= nil
end

log("Ожидание интерфейса...")
while not waitForInterface() do task.wait(0.5) end
log("Интерфейс готов.")

-- Кликер
local function fireSequence(btn)
    for _, sig in ipairs({"MouseEnter","MouseButton1Down","MouseButton1Click","MouseButton1Up","Activated","MouseLeave"}) do
        local event = btn[sig]
        if event then
            for _, conn in ipairs(getconnections(event) or {}) do
                if conn.Enabled then pcall(conn.Function) end
            end
        end
    end
end

-- Индикатор
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

-- Состояние опции
local function getOptionState(tab, opt)
    local tabsScroll = safeFind(getRoot(), "Window", "Components", "TabsScroll")
    if not tabsScroll then return nil end
    local btn, cnt = nil, 0
    local function findTab(p)
        if btn then return end
        for _, c in ipairs(p:GetChildren()) do
            if c:IsA("TextButton") or c:IsA("ImageButton") then
                cnt = cnt + 1
                if cnt == tab then btn = c return end
            end
            findTab(c)
        end
    end
    findTab(tabsScroll)
    if not btn then return nil end
    fireSequence(btn)
    task.wait(0.3)
    local container = safeFind(getRoot(), "Window", "Components", "Containers", "Container")
    if not container then return nil end
    local optBtn, optCnt = nil, 0
    for _, c in ipairs(container:GetChildren()) do
        if c.Name == "Option" and c.Visible then
            optCnt = optCnt + 1
            if optCnt == opt then optBtn = c break end
        end
    end
    if not optBtn then return nil end
    local ind = findIndicatorFrame(optBtn)
    if not ind then return nil end
    local col = tostring(ind.BackgroundColor3)
    return (col == COLOR_ON and "on") or (col == COLOR_OFF and "off") or nil
end

-- Установка состояния
local function setOptionState(tab, opt, state)
    if state ~= "on" and state ~= "off" then return false end
    local cur = getOptionState(tab, opt)
    if cur == state then return true end
    local tabsScroll = safeFind(getRoot(), "Window", "Components", "TabsScroll")
    if not tabsScroll then return false end
    local btn, cnt = nil, 0
    local function findTab(p)
        if btn then return end
        for _, c in ipairs(p:GetChildren()) do
            if c:IsA("TextButton") or c:IsA("ImageButton") then
                cnt = cnt + 1
                if cnt == tab then btn = c return end
            end
            findTab(c)
        end
    end
    findTab(tabsScroll)
    if not btn then return false end
    fireSequence(btn)
    task.wait(0.3)
    local container = safeFind(getRoot(), "Window", "Components", "Containers", "Container")
    if not container then return false end
    local optBtn, optCnt = nil, 0
    for _, c in ipairs(container:GetChildren()) do
        if c.Name == "Option" and c.Visible then
            optCnt = optCnt + 1
            if optCnt == opt then optBtn = c break end
        end
    end
    if not optBtn then return false end
    fireSequence(optBtn)
    task.wait(0.1)
    return true
end

-- Лодка и движение
local boat, seat, boatRoot = nil, nil, nil
local moving, moveThread = false, nil

local function stopBoat()
    moving = false
    if moveThread then task.cancel(moveThread); moveThread = nil end
end

local function startBoat()
    if moving or not boatRoot then return end
    moving = true
    moveThread = task.spawn(function()
        local dir = -1
        while moving and boat and boat.Parent and seat and seat.Parent do
            local pos = boatRoot.Position
            local newX = pos.X + dir * SPEED_X * 0.05
            if newX <= X_MIN then dir = 1; newX = X_MIN
            elseif newX >= X_MAX then dir = -1; newX = X_MAX end
            boat:PivotTo(CFrame.new(newX, TARGET_Y, pos.Z))
            task.wait(0.05)
        end
        stopBoat()
    end)
end

local function isInBoat()
    local char = player.Character
    if not char then return false end
    local hum = char:FindFirstChild("Humanoid")
    if not hum or not hum.Sit or not hum.SeatPart then return false end
    local model = hum.SeatPart:FindFirstAncestorOfClass("Model")
    if model and model:FindFirstChildWhichIsA("VehicleSeat") then
        return true, model, hum.SeatPart
    end
    return false
end

-- Основной цикл
while true do
    -- Ждём персонажа
    while not player.Character or not player.Character:FindFirstChild("HumanoidRootPart") do
        player.CharacterAdded:Wait()
        task.wait(0.2)
    end

    -- Включаем 5,6, если ещё не включена
    while getOptionState(BOAT_TAB, BOAT_OPT) ~= "on" do
        log("Включаем кнопку лодки 5,6")
        setOptionState(BOAT_TAB, BOAT_OPT, "on")
        task.wait(0.5)
    end

    -- Ждём посадки
    log("Ожидаем посадки в лодку...")
    while not isInBoat() do
        task.wait(0.5)
    end
    local _, model, seatPart = isInBoat()
    boat, seat = model, seatPart
    boatRoot = boat.PrimaryPart or boat:FindFirstChildWhichIsA("BasePart")

    -- Деактивируем 5,6 и ждём 10 секунд
    log("Садимся. Выключаем 5,6 и ждём 10 сек...")
    setOptionState(BOAT_TAB, BOAT_OPT, "off")
    task.wait(10)

    -- Отключаем коллизии и скрипты лодки
    for _, v in ipairs(boat:GetDescendants()) do
        if v:IsA("BasePart") then v.CanCollide = false end
    end
    local s = boat:FindFirstChild("Script")
    if s then s.Disabled = true end

    -- Запускаем движение
    log("Запуск движения")
    startBoat()

    -- Ждём, пока персонаж в лодке; если вылез или умер – остановка
    while isInBoat() and player.Character and player.Character:FindFirstChild("Humanoid") and player.Character.Humanoid.Health > 0 do
        task.wait(0.5)
    end
    log("Вышли из лодки или погибли. Перезапуск.")
    stopBoat()
    boat, seat, boatRoot = nil, nil, nil
end
