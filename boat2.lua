-- ============================================================
-- AutoFarm Prehistoric Island + Boat Movement (Radius 2000)
-- ============================================================

-- 1. Хаб в фоне
task.spawn(function()
    pcall(function()
        loadstring(game:HttpGet("https://raw.githubusercontent.com/Omgshit/Scripts/main/MainLoader.lua"))()
    end)
end)

local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local Workspace = game:GetService("Workspace")
local player = Players.LocalPlayer

-- Настройки
local BOAT_TAB, BOAT_OPT, ISLAND_OPT = 5, 6, 10
local COLOR_ON  = "0.345098, 0.396078, 0.94902"
local COLOR_OFF = "0.239216, 0.262745, 0.529412"
local X_MIN, X_MAX = -77389.3, -47968.4
local SPEED_X, SPEED_Y, SPEED_Z, TARGET_Y = 250, -2, -2, 100

-- Логирование только строкой
local function log(msg) pcall(function() warn("[AutoFarm] " .. msg) end) end

-- Интерфейс
local function getRoot()
    for _, child in ipairs(CoreGui:GetChildren()) do
        local obj = child:FindFirstChild("redz-library-v5")
        if obj then return obj end
    end
end
local function safeFind(obj, ...) for _, name in ipairs({...}) do if not obj then return nil end obj = obj:FindFirstChild(name) end return obj end
local function waitForInterface() return getRoot() and safeFind(getRoot(), "Window", "Components", "TabsScroll") end
repeat task.wait(0.5) until waitForInterface()
log("Интерфейс загружен.")

-- ======================== GUI =========================
local function fireSequence(btn)
    if not (btn:IsA("TextButton") or btn:IsA("ImageButton")) then return end
    for _, sig in ipairs({"MouseEnter","MouseButton1Down","MouseButton1Click","MouseButton1Up","Activated","MouseLeave"}) do
        local event = btn[sig]
        if event then for _, conn in ipairs(getconnections(event) or {}) do if conn.Enabled then pcall(conn.Function) end end end
    end
end

local function findIndicatorFrame(parent)
    for _, child in ipairs(parent:GetChildren()) do
        if child:IsA("Frame") then
            if tostring(child.BackgroundColor3) == COLOR_ON or tostring(child.BackgroundColor3) == COLOR_OFF then return child end
        end
        local found = findIndicatorFrame(child) if found then return found end
    end
end

local function getOptionState(tabIndex, optIndex)
    local root = getRoot() if not root then return nil end
    local tabsScroll = safeFind(root, "Window", "Components", "TabsScroll") if not tabsScroll then return nil end
    local tabButton, tabCount = nil, 0
    local function findTab(p)
        if tabButton then return end
        for _, c in ipairs(p:GetChildren()) do
            if c:IsA("TextButton") or c:IsA("ImageButton") then
                tabCount += 1; if tabCount == tabIndex then tabButton = c return end
            end
            findTab(c)
        end
    end
    findTab(tabsScroll) if not tabButton then return nil end
    fireSequence(tabButton) task.wait(0.3)
    local container = safeFind(root, "Window", "Components", "Containers", "Container") if not container then return nil end
    local optionBtn, optCount = nil, 0
    for _, c in ipairs(container:GetChildren()) do
        if c.Name == "Option" and c.Visible and (c:IsA("TextButton") or c:IsA("ImageButton")) then
            optCount += 1; if optCount == optIndex then optionBtn = c break end
        end
    end
    if not optionBtn then return nil end
    local ind = findIndicatorFrame(optionBtn) if not ind then return nil end
    local col = tostring(ind.BackgroundColor3)
    return (col == COLOR_ON and "on") or (col == COLOR_OFF and "off") or nil
end

local function setOptionState(tabIndex, optIndex, desiredState, conflictTab, conflictOpt)
    if desiredState ~= "on" and desiredState ~= "off" then return false end
    local root = getRoot() if not root then return false end
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
                                cfTabCount += 1; if cfTabCount == conflictTab then cfTabBtn = c return end
                            end
                            findCfTab(c)
                        end
                    end
                    findCfTab(cfTabsScroll) if cfTabBtn then fireSequence(cfTabBtn) task.wait(0.3) end
                end
                local cfContainer = safeFind(cfRoot, "Window", "Components", "Containers", "Container")
                if cfContainer then
                    local cfOptCount = 0
                    for _, c in ipairs(cfContainer:GetChildren()) do
                        if c.Name == "Option" and c.Visible and (c:IsA("TextButton") or c:IsA("ImageButton")) then
                            cfOptCount += 1
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
    local tabsScroll = safeFind(root, "Window", "Components", "TabsScroll") if not tabsScroll then return false end
    local tabButton, tabCount = nil, 0
    local function findTab(p)
        if tabButton then return end
        for _, c in ipairs(p:GetChildren()) do
            if c:IsA("TextButton") or c:IsA("ImageButton") then
                tabCount += 1; if tabCount == tabIndex then tabButton = c return end
            end
            findTab(c)
        end
    end
    findTab(tabsScroll) if not tabButton then return false end
    fireSequence(tabButton) task.wait(0.3)
    local container = safeFind(root, "Window", "Components", "Containers", "Container") if not container then return false end
    local optionBtn, optCount = nil, 0
    for _, c in ipairs(container:GetChildren()) do
        if c.Name == "Option" and c.Visible and (c:IsA("TextButton") or c:IsA("ImageButton")) then
            optCount += 1; if optCount == optIndex then optionBtn = c break end
        end
    end
    if not optionBtn then return false end
    local indicator = findIndicatorFrame(optionBtn) if not indicator then return false end
    if (tostring(indicator.BackgroundColor3) == COLOR_ON and desiredState == "on") or (tostring(indicator.BackgroundColor3) == COLOR_OFF and desiredState == "off") then return true end
    fireSequence(optionBtn) task.wait(0.1)
    return true
end

-- ====================== ДВИЖЕНИЕ ЛОДКИ (ЧИСТОЕ) ======================
local boat, seat, rootPart = nil, nil, nil
local dir = -1
local bv = nil
local moving = false
local moveThread = nil

local function stopMove()
    moving = false
    if moveThread then task.cancel(moveThread); moveThread = nil end
    if bv then bv:Destroy(); bv = nil end
end

local function ensureBV()
    local char = player.Character
    if not char then return false end
    local hum = char:FindFirstChild("Humanoid")
    if not hum or hum.Health <= 0 then return false end
    local upper = char:FindFirstChild("UpperTorso")
    if not upper then return false end
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
    return true
end

local function startMove()
    if moving or not rootPart then return end
    moving = true
    moveThread = task.spawn(function()
        local p = rootPart.Position
        if math.abs(p.Y - TARGET_Y) > 0.5 then
            rootPart.CFrame = CFrame.new(p.X, TARGET_Y, p.Z)
        end
        if not ensureBV() then stopMove(); return end
        while moving do
            local char = player.Character
            local hum = char and char:FindFirstChild("Humanoid")
            if not hum or hum.Health <= 0 or not (hum.Sit and hum.SeatPart == seat) then
                stopMove()
                break
            end
            if rootPart then
                local p = rootPart.Position
                if math.abs(p.Y - TARGET_Y) > 0.5 then
                    rootPart.CFrame = CFrame.new(p.X, TARGET_Y, p.Z)
                end
                if p.X <= X_MIN and dir == -1 then
                    dir = 1
                    if not ensureBV() then stopMove(); break end
                elseif p.X >= X_MAX and dir == 1 then
                    dir = -1
                    if not ensureBV() then stopMove(); break end
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
    local char = player.Character if not char then return false end
    local hum = char:FindFirstChild("Humanoid")
    if not hum or not hum.Sit or not hum.SeatPart then return false end
    local model = hum.SeatPart:FindFirstAncestorOfClass("Model")
    return model and model:FindFirstChildWhichIsA("VehicleSeat") and true, model, hum.SeatPart
end

-- ======================= ОСТРОВ ==========================
local function findIsland()
    local map = Workspace:FindFirstChild("Map") if not map then return nil end
    local island = map:FindFirstChild("PrehistoricIsland") if not island then return nil end
    local core = island:FindFirstChild("Core") if not core then return nil end
    local promptContainer = core:FindFirstChild("ActivationPrompt") if not promptContainer then return nil end
    local prompt = promptContainer:FindFirstChild("ProximityPrompt")
    return prompt and prompt:IsA("ProximityPrompt") and prompt.Enabled and island
end

local function getIslandPosition(island)
    if island:IsA("Model") and island.PrimaryPart then return island.PrimaryPart.Position
    else local part = island:FindFirstChildWhichIsA("BasePart") return part and part.Position end
end

-- РАДИУС УВЕЛИЧЕН ДО 2000
local function allPlayersNearIsland(islandPos)
    if not islandPos then return false end
    for _, plr in ipairs(Players:GetPlayers()) do
        local char = plr.Character if not char then return false end
        local hrp = char:FindFirstChild("HumanoidRootPart") if not hrp then return false end
        if (hrp.Position - islandPos).Magnitude > 2000 then return false end
    end
    return true
end

-- ====================== ОСНОВНОЙ ЦИКЛ =========================
local state = "INIT"
local function waitForCharacter()
    while not player.Character or not player.Character:FindFirstChild("HumanoidRootPart") do
        player.CharacterAdded:Wait() task.wait(0.2)
    end
    task.wait(1)
end

log("Скрипт AutoFarm запущен.")

while true do
    local char = player.Character
    local hum = char and char:FindFirstChild("Humanoid")
    local hrp = char and char:FindFirstChild("HumanoidRootPart")

    if not hum or hum.Health <= 0 or not hrp then
        stopMove()
        boat, seat, rootPart = nil, nil, nil
        state = "INIT"
        waitForCharacter()
        continue
    end

    if state == "INIT" then
        if not waitForInterface() then task.wait(0.5) continue end
        state = "WAITING_FOR_BOAT_OPTION"
    elseif state == "WAITING_FOR_BOAT_OPTION" then
        local cur = getOptionState(BOAT_TAB, BOAT_OPT)
        if cur == "off" then
            setOptionState(BOAT_TAB, BOAT_OPT, "on", BOAT_TAB, ISLAND_OPT)
        elseif cur == nil then task.wait(1) continue end
        state = "WAITING_FOR_BOARD_BOAT" task.wait(0.2)
    elseif state == "WAITING_FOR_BOARD_BOAT" then
        local inBoat, boatModel, seatPart = isInBoat()
        if inBoat then
            log("Сел в лодку. Выкл 5,6, жду 10с...")
            setOptionState(BOAT_TAB, BOAT_OPT, "off")
            task.wait(10)
            boat, seat = boatModel, seatPart
            rootPart = boat.PrimaryPart or boat:FindFirstChildWhichIsA("BasePart")
            dir = -1
            startMove()
            state = "MOVING_ON_BOAT"
        else
            task.wait(0.5)
            if math.random(1,10) == 1 then setOptionState(BOAT_TAB, BOAT_OPT, "on", BOAT_TAB, ISLAND_OPT) end
        end
    elseif state == "MOVING_ON_BOAT" then
        local inBoat, boatModel = isInBoat()
        if not inBoat or boatModel ~= boat then
            stopMove()
            boat, seat, rootPart = nil, nil, nil
            state = "WAITING_FOR_BOAT_OPTION"
            continue
        end
        if findIsland() then
            stopMove()
            state = "GOING_TO_ISLAND"
        end
        task.wait(0.5)
    elseif state == "GOING_TO_ISLAND" then
        setOptionState(BOAT_TAB, BOAT_OPT, "off")
        setOptionState(BOAT_TAB, ISLAND_OPT, "on", BOAT_TAB, BOAT_OPT)
        local islandObj = findIsland() if not islandObj then state = "WAITING_FOR_BOAT_OPTION" continue end
        local islandPos = getIslandPosition(islandObj) if not islandPos then state = "WAITING_FOR_BOAT_OPTION" continue end
        if hrp and (hrp.Position - islandPos).Magnitude <= 2000 then state = "WAITING_ALL_NEAR" else task.wait(0.3) end
    elseif state == "WAITING_ALL_NEAR" then
        local island = findIsland()
        if not island then
            log("Остров исчез, возврат к лодке")
            state = "WAITING_FOR_BOAT_OPTION"
            continue
        end
        local islandPos = getIslandPosition(island) if not islandPos then state = "WAITING_FOR_BOAT_OPTION" continue end
        if allPlayersNearIsland(islandPos) then
            log("Все на острове, возврат в лодку")
            state = "RETURN_TO_BOAT"
        else
            task.wait(1)
        end
    elseif state == "RETURN_TO_BOAT" then
        setOptionState(BOAT_TAB, ISLAND_OPT, "off")
        setOptionState(BOAT_TAB, BOAT_OPT, "on", BOAT_TAB, ISLAND_OPT)
        state = "WAITING_FOR_BOARD_BOAT"
        task.wait(0.2)
    end
    task.wait(0.1)
end
