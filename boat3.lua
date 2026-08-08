-- Оригинальный скрипт движения + активация кнопки 5,6 перед стартом.
-- Запускать при уже загруженном хабе (redz-library-v5 присутствует).

-- ====== НАСТРОЙКИ ======
local BOAT_TAB, BOAT_OPT = 5, 6
local COLOR_ON  = "0.345098, 0.396078, 0.94902"
local COLOR_OFF = "0.239216, 0.262745, 0.529412"

local X_MIN = -77389.3
local X_MAX = -47968.4
local SPEED_X = 250
local SPEED_Y = -2
local SPEED_Z = -2
local TARGET_Y = 100

-- ====== СЛУЖЕБНЫЕ ОБЪЕКТЫ ======
local player = game.Players.LocalPlayer
local CoreGui = game:GetService("CoreGui")
local char = player.Character or player.CharacterAdded:Wait()
local hum = char:WaitForChild("Humanoid")
local hrp = char:WaitForChild("HumanoidRootPart")

-- ====== GUI-ФУНКЦИИ (без изменений) ======
local function getRoot()
    for _, child in ipairs(CoreGui:GetChildren()) do
        local obj = child:FindFirstChild("redz-library-v5")
        if obj then return obj end
    end
end

local function safeFind(obj, ...)
    for _, name in ipairs({...}) do
        if not obj then return nil end
        obj = obj:FindFirstChild(name)
    end
    return obj
end

local function fireSequence(btn)
    if not (btn:IsA("TextButton") or btn:IsA("ImageButton")) then return end
    for _, sig in ipairs({"MouseEnter","MouseButton1Down","MouseButton1Click","MouseButton1Up","Activated","MouseLeave"}) do
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
end

local function getOptionState(tab, opt)
    local root = getRoot()
    if not root then return end
    local tabsScroll = safeFind(root, "Window", "Components", "TabsScroll")
    if not tabsScroll then return end
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
    if not btn then return end
    fireSequence(btn)
    task.wait(0.3)
    local container = safeFind(root, "Window", "Components", "Containers", "Container")
    if not container then return end
    local optBtn, optCnt = nil, 0
    for _, c in ipairs(container:GetChildren()) do
        if c.Name == "Option" and c.Visible and (c:IsA("TextButton") or c:IsA("ImageButton")) then
            optCnt = optCnt + 1
            if optCnt == opt then optBtn = c break end
        end
    end
    if not optBtn then return end
    local ind = findIndicatorFrame(optBtn)
    if not ind then return end
    local col = tostring(ind.BackgroundColor3)
    return (col == COLOR_ON and "on") or (col == COLOR_OFF and "off") or nil
end

local function setOptionState(tab, opt, state)
    if state ~= "on" and state ~= "off" then return false end
    if getOptionState(tab, opt) == state then return true end
    local root = getRoot()
    if not root then return false end
    local tabsScroll = safeFind(root, "Window", "Components", "TabsScroll")
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
    local container = safeFind(root, "Window", "Components", "Containers", "Container")
    if not container then return false end
    local optBtn, optCnt = nil, 0
    for _, c in ipairs(container:GetChildren()) do
        if c.Name == "Option" and c.Visible and (c:IsA("TextButton") or c:IsA("ImageButton")) then
            optCnt = optCnt + 1
            if optCnt == opt then optBtn = c break end
        end
    end
    if not optBtn then return false end
    fireSequence(optBtn)
    task.wait(0.1)
    return true
end

-- ====== ДВИЖЕНИЕ ЛОДКИ (ОРИГИНАЛЬНЫЙ КОД) ======
local boat = nil
local seat = nil
local root = nil
local dir = -1
local bv = nil
local moving = false
local moveThread = nil

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

local function stopMove()
    moving = false
    if moveThread then task.cancel(moveThread); moveThread = nil end
    if bv then bv:Destroy(); bv = nil end
end

local function startMove()
    if moving then return end
    moving = true
    moveThread = task.spawn(function()
        if not root then return end
        local p = root.Position
        if math.abs(p.Y - TARGET_Y) > 0.5 then
            root.CFrame = CFrame.new(p.X, TARGET_Y, p.Z)
        end
        ensureBV()
        while moving do
            if not (hum.Sit and hum.SeatPart == seat) then
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
                elseif p.X >= X_MAX and dir == 1 then
                    dir = -1
                    ensureBV()
                end
            end
            if bv and bv.Parent then
                local v = bv.Velocity
                bv.Velocity = Vector3.new(v.X, v.Y - 0.0001, v.Z - 0.0001)
            end
            task.wait(0.05)
        end
    end)
end

local function isInBoat()
    if not hum.Sit or not hum.SeatPart then return false end
    local model = hum.SeatPart:FindFirstAncestorOfClass("Model")
    if model and model:FindFirstChildWhichIsA("VehicleSeat") then
        return true, model, hum.SeatPart
    end
    return false
end

-- ====== ПРЕДСТАРТОВАЯ ЛОГИКА ======
-- Активируем 5,6
while getOptionState(BOAT_TAB, BOAT_OPT) ~= "on" do
    setOptionState(BOAT_TAB, BOAT_OPT, "on")
    task.wait(0.5)
end

-- Ждём посадки
while not isInBoat() do
    task.wait(0.5)
end

-- Получаем данные лодки
local _, model, seatPart = isInBoat()
boat = model
seat = seatPart
root = boat.PrimaryPart or boat:FindFirstChildWhichIsA("BasePart")

-- Деактивируем кнопку мгновенно
setOptionState(BOAT_TAB, BOAT_OPT, "off")

-- Ждём 10 секунд
task.wait(10)

-- ====== ОСНОВНОЙ ЦИКЛ ДВИЖЕНИЯ (из оригинального скрипта) ======
task.spawn(function()
    while true do
        task.wait(0.1)
        char = player.Character
        if not char then
            player.CharacterAdded:Wait()
            char = player.Character
            hum = char:WaitForChild("Humanoid")
            hrp = char:WaitForChild("HumanoidRootPart")
            continue
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
                    root = currentBoat.PrimaryPart or currentBoat:FindFirstChildWhichIsA("BasePart")
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
            if boat then
                stopMove()
                boat = nil; seat = nil; root = nil
            end
        end
    end
end)

print("Скрипт движения лодки запущен (с предварительной активацией и задержкой).")
