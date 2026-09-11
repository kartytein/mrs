-- ============================================================
-- Сценарий: 6,1 → dragon talon → island → 2,4 → mastery>500 → 6,1
-- ============================================================

task.spawn(function()
    pcall(function()
        loadstring(game:HttpGet("https://raw.githubusercontent.com/Omgshit/Scripts/main/MainLoader.lua"))()
    end)
end)

local CoreGui = game:GetService("CoreGui")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local TAB_MAIN, OPT_MAIN = 6, 1
local TAB_SEC,  OPT_SEC  = 2, 4

local COLOR_ON  = "0.345098, 0.396078, 0.94902"
local COLOR_OFF = "0.239216, 0.262745, 0.529412"

local function log(msg)
    pcall(function() warn("[Auto] " .. msg) end)
end

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

local function waitForInterface()
    if not getRoot() then return false end
    return safeFind(getRoot(), "Window", "Components", "TabsScroll") ~= nil
end

log("Ожидание интерфейса хаба...")
repeat task.wait(0.5) until waitForInterface()
log("Интерфейс готов.")

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

local function findTab(root, tabIndex)
    local tabsScroll = safeFind(root, "Window", "Components", "TabsScroll")
    if not tabsScroll then return nil end
    local tabButton, count = nil, 0
    local function scan(p)
        if tabButton then return end
        for _, c in ipairs(p:GetChildren()) do
            if c:IsA("TextButton") or c:IsA("ImageButton") then
                count += 1
                if count == tabIndex then tabButton = c return end
            end
            scan(c)
        end
    end
    scan(tabsScroll)
    return tabButton
end

-- Получить контейнер активной вкладки
local function getActiveContainer()
    local root = getRoot()
    if not root then return nil end
    return safeFind(root, "Window", "Components", "Containers", "Container")
end

-- Найти опцию по индексу (только видимые и внутри активного контейнера)
local function findOption(root, optIndex)
    local container = safeFind(root, "Window", "Components", "Containers", "Container")
    if not container then return nil end
    local optionBtn, count = nil, 0
    for _, c in ipairs(container:GetChildren()) do
        if c.Name == "Option" and c.Visible and (c:IsA("TextButton") or c:IsA("ImageButton")) then
            count += 1
            if count == optIndex then optionBtn = c break end
        end
    end
    return optionBtn
end

-- ============================================================
-- ХОРОШИЙ ВЭЙТ: ждём, пока на активной вкладке реально прогрузятся опции
-- ============================================================
local function waitForOptions(expectedMin, timeout)
    timeout = timeout or 8
    expectedMin = expectedMin or 1
    local t0 = tick()
    local lastCount = -1
    local stable = 0
    while tick() - t0 < timeout do
        local root = getRoot()
        local container = root and safeFind(root, "Window", "Components", "Containers", "Container")
        local count = 0
        if container then
            for _, c in ipairs(container:GetChildren()) do
                if c.Name == "Option" and c.Visible and (c:IsA("TextButton") or c:IsA("ImageButton")) then
                    count += 1
                end
            end
        end
        if count >= expectedMin then
            if count == lastCount then
                stable += 1
                if stable >= 2 then return true end -- 2 подряд одинаковых = стабилизировалось
            else
                stable = 0
                lastCount = count
            end
        else
            lastCount = -1
            stable = 0
        end
        task.wait(0.15)
    end
    return false
end

-- Получить состояние кнопки
local function getOptionState(tabIndex, optIndex)
    local root = getRoot()
    if not root then return nil end
    local tabButton = findTab(root, tabIndex)
    if not tabButton then return nil end
    fireSequence(tabButton)
    -- ХОРОШИЙ ВЭЙТ после переключения вкладки
    if not waitForOptions(optIndex, 8) then return nil end
    local optionBtn = findOption(root, optIndex)
    if not optionBtn then return nil end
    local indicator = findIndicatorFrame(optionBtn)
    if not indicator then return nil end
    local col = tostring(indicator.BackgroundColor3)
    if col == COLOR_ON then return "on"
    elseif col == COLOR_OFF then return "off" end
    return nil
end

-- Установить состояние
local function setOption(tabIndex, optIndex, wantOn)
    local root = getRoot()
    if not root then return false end
    local tabButton = findTab(root, tabIndex)
    if not tabButton then return false end
    fireSequence(tabButton)

    -- ЖДЁМ, пока опции реально загрузятся и стабилизируются
    if not waitForOptions(optIndex, 8) then
        log("Не дождался опций на вкладке " .. tabIndex)
        return false
    end

    local optionBtn = findOption(root, optIndex)
    if not optionBtn then return false end

    -- Проверяем текущее состояние
    local indicator = findIndicatorFrame(optionBtn)
    if not indicator then return false end
    local col = tostring(indicator.BackgroundColor3)
    local currentOn = (col == COLOR_ON)

    if currentOn == wantOn then return true end

    -- Кликаем
    fireSequence(optionBtn)
    task.wait(0.2)

    -- Проверяем, что переключилось (с ретраями)
    for _ = 1, 5 do
        local ind2 = findIndicatorFrame(optionBtn)
        if ind2 then
            local c2 = tostring(ind2.BackgroundColor3)
            if (c2 == COLOR_ON) == wantOn then return true end
        end
        fireSequence(optionBtn)
        task.wait(0.25)
    end
    return false
end

-- ============================================================
-- Проверки путей
-- ============================================================

local function hasDragonTalon()
    local pg = LocalPlayer:FindFirstChild("PlayerGui")
    if not pg then return false end
    local wac = pg:FindFirstChild("WeaponAssetCache")
    if not wac then return false end
    return wac:FindFirstChild("dragontalon") ~= nil
end

local function isOnIsland()
    local world = workspace:FindFirstChild("_WorldOrigin")
    if not world then return false end
    local sounds = world:FindFirstChild("Sounds")
    if not sounds then return false end
    local locs = sounds:FindFirstChild("Locations")
    if not locs then return false end
    return locs:FindFirstChild("Submerged Island") ~= nil
end

local function getMastery()
    local pg = LocalPlayer:FindFirstChild("PlayerGui")
    if not pg then return nil end
    local main = pg:FindFirstChild("Main")
    if not main then return nil end
    local lbl = main:FindFirstChild("MobileMasteryLevel")
    if not lbl then return nil end
    return tonumber(string.match(lbl.Text or "", "%d+"))
end

-- ============================================================
-- Основной сценарий
-- ============================================================

-- Шаг 1: dragon talon
log("Проверка dragon talon...")
if not hasDragonTalon() then
    log("Dragon talon нет — включаю 6,1 и жду...")
    repeat
        setOption(TAB_MAIN, OPT_MAIN, true)
        task.wait(2)
    until hasDragonTalon()
end
log("Dragon talon есть.")

-- Шаг 2: остров
log("Проверка острова...")
if not isOnIsland() then
    setOption(TAB_MAIN, OPT_MAIN, true)
    log("Не на острове — жду...")
    repeat task.wait(2) until isOnIsland()
end
log("На острове.")

-- Шаг 3: 6,1 off → 2,4 on
log("Отключаю 6,1, включаю 2,4...")
setOption(TAB_MAIN, OPT_MAIN, false)
task.wait(0.5)
setOption(TAB_SEC, OPT_SEC, true)

-- Шаг 4: ждём mastery > 500
log("Ожидание mastery > 500...")
local mastery = 0
repeat
    task.wait(2)
    mastery = getMastery() or 0
    log("Mastery: " .. tostring(mastery))
until mastery > 500

-- Шаг 5: 2,4 off → 6,1 on
log("Mastery > 500. Отключаю 2,4, включаю 6,1...")
setOption(TAB_SEC, OPT_SEC, false)
task.wait(0.5)
setOption(TAB_MAIN, OPT_MAIN, true)

log("Готово.")
