-- ============================================================
-- AutoFarm Prehistoric Island + Boat Movement (Final Fix)
-- Исправлена ошибка с nil Window при обращении к кнопкам.
-- ============================================================

local origWarn = warn
local function log(msg)
    pcall(function() origWarn("[AutoFarm]", msg) end)
end

-- 1. Загружаем хаб асинхронно
task.spawn(function()
    local ok, err = pcall(function()
        loadstring(game:HttpGet("https://raw.githubusercontent.com/Omgshit/Scripts/main/MainLoader.lua"))()
    end)
    if not ok then log("Ошибка загрузки хаба: " .. tostring(err))
    else log("Хаб загружен") end
end)

-- 2. Ожидание интерфейса redz-library-v5
local CoreGui = game:GetService("CoreGui")
local function getRoot()
    for _, child in ipairs(CoreGui:GetChildren()) do
        local obj = child:FindFirstChild("redz-library-v5")
        if obj then return obj end
    end
    return nil
end

-- Ждём не только root, но и его внутренний Window
local function waitForInterface()
    if not getRoot() then return false end
    local root = getRoot()
    -- Проверяем, что внутри root есть Window/Components/TabsScroll
    local window = root:FindFirstChild("Window")
    if not window then return false end
    local components = window:FindFirstChild("Components")
    if not components then return false end
    local tabsScroll = components:FindFirstChild("TabsScroll")
    return tabsScroll ~= nil
end

log("Ожидание интерфейса хаба...")
local timeout = 30
local waited = 0
while not waitForInterface() and waited < timeout do
    task.wait(0.5)
    waited = waited + 0.5
end
if not waitForInterface() then
    log("Интерфейс хаба не появился. Остановка.")
    return
end
log("Интерфейс полностью загружен, запуск AutoFarm.")

-- Настройки
local BOAT_TAB = 5
local BOAT_OPT = 6
local ISLAND_OPT = 10
local COLOR_ON  = "0.345098, 0.396078, 0.94902"
local COLOR_OFF = "0.239216, 0.262745, 0.529412"
local X_MIN = -77389.3
local X_MAX = -47968.4
local SPEED_X = 250
local TARGET_Y = 100
local BOAT_SPEED_Y = -2
local BOAT_SPEED_Z = -2

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local player = Players.LocalPlayer

-- Безопасная функция для последовательного поиска
local function safeFind(obj, ...)
    local current = obj
    for _, name in ipairs({...}) do
        if not current then return nil end
        current = current:FindFirstChild(name)
    end
    return current
end

-- Вспомогательные функции
local function fireSequence(btn)
    local signals = {"MouseEnter","MouseButton1Down","MouseButton1Click","MouseButton1Up","Activated","MouseLeave"}
    for _, sigName in ipairs(signals) do
        local sig = btn[sigName]
        if sig then
            local ok, conns = pcall(function() return getconnections(sig) end)
            if ok and conns then
                for _, conn in ipairs(conns) do
                    if conn and conn.Enabled and type(conn.Function) == "function" then
                        conn.Function()
                    end
                end
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
    task.wait(0.3)
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
    -- выключаем конфликтующую
    if desiredState == "on" and conflictTab and conflictOpt then
        if getOptionState(conflictTab, conflictOpt) == "on" then
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
                                if ind and tostring(ind.BackgroundColor3) == COLOR_ON then fireSequence(c) end
                                break
                            end
                        end
                    end
                end
                task.wait(0.1)
            end
        end
    end
    -- переключаем целевую
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
    if currentState == desiredState then return true end
    fireSequence(optionBtn)
    task.wait(0.1)
    return true
end

-- Движение лодки (без изменений)
local boat, seat, boatRoot = nil, nil, nil
local moving, moveThread = false, nil

local function stopBoatMovement()
    moving = false
    if moveThread then task.cancel(moveThread); moveThread = nil end
end

local function startBoatMovement()
    if moving or not boatRoot then return end
    moving = true
    moveThread = task.spawn(function()
        local dir = -1
        local pos = boatRoot.Position
        if math.abs(pos.Y - TARGET_Y) > 0.5 then
            boat:PivotTo(CFrame.new(pos.X, TARGET_Y, pos.Z))
        end
        while moving do
            if not boat or not boat.Parent or not seat or not seat.Parent then
                stopBoatMovement()
                break
            end
            local currentPos = boatRoot.Position
            local newX = currentPos.X + dir * SPEED_X * 0.05
            local newY = TARGET_Y
            local newZ = currentPos.Z + BOAT_SPEED_Z * 0.05
            if newX <= X_MIN and dir == -1 then
                dir = 1; newX = X_MIN
            elseif newX >= X_MAX and dir == 1 then
                dir = -1; newX = X_MAX
            end
            boat:PivotTo(CFrame.new(newX, newY, newZ))
            task.wait(0.05)
        end
    end)
end

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
                if (hrp.Position - islandPos).Magnitude > 100 then return false end
            else return false end
        else return false end
    end
    return true
end

local state = "INIT"
local function waitForCharacter()
    while not player.Character or not player.Character:FindFirstChild("HumanoidRootPart") do
        player.CharacterAdded:Wait()
        task.wait(0.2)
    end
end

log("Главный цикл запущен.")

-- Главный цикл
while true do
    local char = player.Character
    local hum = char and char:FindFirstChild("Humanoid")
    local hrp = char and char:FindFirstChild("HumanoidRootPart")

    if not hum or hum.Health <= 0 or not hrp then
        stopBoatMovement()
        boat, seat, boatRoot = nil, nil, nil
        state = "INIT"
        waitForCharacter()
        continue
    end

    if state == "INIT" then
        if not waitForInterface() then task.wait(0.5); continue end
        state = "WAITING_FOR_BOAT_OPTION"

    elseif state == "WAITING_FOR_BOAT_OPTION" then
        local curState = getOptionState(BOAT_TAB, BOAT_OPT)
        if curState == "off" then
            setOptionState(BOAT_TAB, BOAT_OPT, "on", BOAT_TAB, ISLAND_OPT)
        elseif curState == nil then
            task.wait(1); continue
        end
        state = "WAITING_FOR_BOARD_BOAT"
        task.wait(0.2)

    elseif state == "WAITING_FOR_BOARD_BOAT" then
        local inBoat, boatModel, seatPart = isInBoat()
        if inBoat then
            log("Сел в лодку. Деактивируем 5,6 и ждём 1 сек...")
            setOptionState(BOAT_TAB, BOAT_OPT, "off")
            task.wait(10)
            boat = boatModel
            seat = seatPart
            boatRoot = boat.PrimaryPart or boat:FindFirstChildWhichIsA("BasePart")
            for _, part in ipairs(boat:GetDescendants()) do
                if part:IsA("BasePart") then part.CanCollide = false end
            end
            local natScript = boat:FindFirstChild("Script")
            if natScript then natScript.Disabled = true end
            startBoatMovement()
            state = "MOVING_ON_BOAT"
        else
            task.wait(0.5)
            if math.random(1,10) == 1 then
                setOptionState(BOAT_TAB, BOAT_OPT, "on", BOAT_TAB, ISLAND_OPT)
            end
        end

    elseif state == "MOVING_ON_BOAT" then
        local inBoat, boatModel = isInBoat()
        if not inBoat or boatModel ~= boat then
            stopBoatMovement()
            boat, seat, boatRoot = nil, nil, nil
            state = "WAITING_FOR_BOAT_OPTION"
            continue
        end
        if findIsland() then
            stopBoatMovement()
            state = "GOING_TO_ISLAND"
        end
        task.wait(0.5)

    elseif state == "GOING_TO_ISLAND" then
        setOptionState(BOAT_TAB, BOAT_OPT, "off")
        setOptionState(BOAT_TAB, ISLAND_OPT, "on", BOAT_TAB, BOAT_OPT)
        local islandObj = findIsland()
        if not islandObj then state = "WAITING_FOR_BOAT_OPTION"; continue end
        local islandPos = getIslandPosition(islandObj)
        if not islandPos then state = "WAITING_FOR_BOAT_OPTION"; continue end
        if hrp and (hrp.Position - islandPos).Magnitude <= 100 then
            state = "WAITING_ALL_NEAR"
        else task.wait(0.3) end

    elseif state == "WAITING_ALL_NEAR" then
        local island = findIsland()
        if not island then state = "WAITING_FOR_BOAT_OPTION"; continue end
        local islandPos = getIslandPosition(island)
        if not islandPos then state = "WAITING_FOR_BOAT_OPTION"; continue end
        if allPlayersNearIsland(islandPos) then
            state = "RETURN_TO_BOAT"
        else task.wait(1) end

    elseif state == "RETURN_TO_BOAT" then
        setOptionState(BOAT_TAB, ISLAND_OPT, "off")
        setOptionState(BOAT_TAB, BOAT_OPT, "on", BOAT_TAB, ISLAND_OPT)
        state = "WAITING_FOR_BOARD_BOAT"
        task.wait(0.2)
    end

    task.wait(0.1)
end
