-- ============================================================
-- ОДИН В ОДИН как в твоём рабочем скрипте.
-- Твои функции не тронуты (используют глобальные TAB и OPT).
-- Сверху — только флоу с ожиданиями.
-- ============================================================

-- 1. Загружаем хаб в фоне (как у тебя)
task.spawn(function()
    pcall(function()
        loadstring(game:HttpGet("https://raw.githubusercontent.com/Omgshit/Scripts/main/MainLoader.lua"))()
    end)
end)

local CoreGui = game:GetService("CoreGui")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

-- Глобальные настройки — как в оригинале. Меняются перед каждым действием.
TAB = 6
OPT = 1
local COLOR_ON  = "0.345098, 0.396078, 0.94902"
local COLOR_OFF = "0.239216, 0.262745, 0.529412"

-- Логирование
local function log(msg)
    pcall(function() warn("[Auto] " .. msg) end)
end

-- Поиск корня интерфейса
local function getRoot()
    for _, child in ipairs(CoreGui:GetChildren()) do
        local obj = child:FindFirstChild("redz-library-v5")
        if obj then return obj end
    end
    return nil
end

-- Безопасный поиск цепочки
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

log("Ожидание интерфейса хаба...")
repeat task.wait(0.5) until waitForInterface()
log("Интерфейс готов.")

-- Эмуляция клика по кнопке (как у тебя)
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

-- Поиск индикатора (цветного Frame) — как у тебя
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

-- ============================================================
-- getOptionState — ОДИН В ОДИН как в оригинале (использует TAB, OPT)
-- ============================================================
local function getOptionState()
    local root = getRoot()
    if not root then return nil end
    local tabsScroll = safeFind(root, "Window", "Components", "TabsScroll")
    if not tabsScroll then return nil end
    local tabButton, tabCount = nil, 0
    local function findTab(p)
        if tabButton then return end
        for _, c in ipairs(p:GetChildren()) do
            if c:IsA("TextButton") or c:IsA("ImageButton") then
                tabCount += 1
                if tabCount == TAB then tabButton = c return end
            end
            findTab(c)
        end
    end
    findTab(tabsScroll)
    if not tabButton then return nil end
    fireSequence(tabButton)
    task.wait(0.3)
    local container = safeFind(root, "Window", "Components", "Containers", "Container")
    if not container then return nil end
    local optionBtn, optCount = nil, 0
    for _, c in ipairs(container:GetChildren()) do
        if c.Name == "Option" and c.Visible and (c:IsA("TextButton") or c:IsA("ImageButton")) then
            optCount += 1
            if optCount == OPT then optionBtn = c break end
        end
    end
    if not optionBtn then return nil end
    local indicator = findIndicatorFrame(optionBtn)
    if not indicator then return nil end
    local col = tostring(indicator.BackgroundColor3)
    if col == COLOR_ON then return "on"
    elseif col == COLOR_OFF then return "off"
    else return nil
    end
end

-- ============================================================
-- enableOption — ОДИН В ОДИН как в оригинале (использует TAB, OPT)
-- ============================================================
local function enableOption()
    local state = getOptionState()
    if state == "on" then return true end
    if state ~= "off" then return false end

    local root = getRoot()
    if not root then return false end
    local tabsScroll = safeFind(root, "Window", "Components", "TabsScroll")
    if not tabsScroll then return false end
    local tabButton, tabCount = nil, 0
    local function findTab(p)
        if tabButton then return end
        for _, c in ipairs(p:GetChildren()) do
            if c:IsA("TextButton") or c:IsA("ImageButton") then
                tabCount += 1
                if tabCount == TAB then tabButton = c return end
            end
            findTab(c)
        end
    end
    findTab(tabsScroll)
    if not tabButton then return false end
    fireSequence(tabButton)
    task.wait(0.3)
    local container = safeFind(root, "Window", "Components", "Containers", "Container")
    if not container then return false end
    local optionBtn, optCount = nil, 0
    for _, c in ipairs(container:GetChildren()) do
        if c.Name == "Option" and c.Visible and (c:IsA("TextButton") or c:IsA("ImageButton")) then
            optCount += 1
            if optCount == OPT then optionBtn = c break end
        end
    end
    if not optionBtn then return false end
    fireSequence(optionBtn)
    task.wait(0.1)
    return true
end

-- ============================================================
-- disableOption — ЗЕРКАЛО enableOption (использует TAB, OPT)
-- Отличие только в целевой проверке state == "on"
-- ============================================================
local function disableOption()
    local state = getOptionState()
    if state == "off" then return true end
    if state ~= "on" then return false end

    local root = getRoot()
    if not root then return false end
    local tabsScroll = safeFind(root, "Window", "Components", "TabsScroll")
    if not tabsScroll then return false end
    local tabButton, tabCount = nil, 0
    local function findTab(p)
        if tabButton then return end
        for _, c in ipairs(p:GetChildren()) do
            if c:IsA("TextButton") or c:IsA("ImageButton") then
                tabCount += 1
                if tabCount == TAB then tabButton = c return end
            end
            findTab(c)
        end
    end
    findTab(tabsScroll)
    if not tabButton then return false end
    fireSequence(tabButton)
    task.wait(0.3)
    local container = safeFind(root, "Window", "Components", "Containers", "Container")
    if not container then return false end
    local optionBtn, optCount = nil, 0
    for _, c in ipairs(container:GetChildren()) do
        if c.Name == "Option" and c.Visible and (c:IsA("TextButton") or c:IsA("ImageButton")) then
            optCount += 1
            if optCount == OPT then optionBtn = c break end
        end
    end
    if not optionBtn then return false end
    fireSequence(optionBtn)
    task.wait(0.1)
    return true
end

-- ============================================================
-- Проверки по путям
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
-- Дать хабу ещё чуть-чуть времени догрузить вкладки/опции
-- ============================================================
task.wait(2)

-- ============================================================
-- ФЛОУ
-- ============================================================

-- Шаг 1: dragon talon (6,1 держим включённой через тот же while-loop)
TAB, OPT = 6, 1
log("Шаг 1: проверка dragon talon...")
if not hasDragonTalon() then
    log("Dragon talon нет — включаю 6,1 и жду...")
    while true do
        local state = getOptionState()
        if state == "off" then
            enableOption()
        end
        if hasDragonTalon() then break end
        task.wait(3)
    end
end
log("Dragon talon есть.")
task.wait(2)

-- Шаг 2: остров (6,1 всё ещё активна)
TAB, OPT = 6, 1
log("Шаг 2: проверка острова...")
if not isOnIsland() then
    log("Не на острове — жду...")
    while true do
        local state = getOptionState()
        if state == "off" then
            enableOption()
        end
        if isOnIsland() then break end
        task.wait(3)
    end
end
log("На острове.")
task.wait(2)

-- Шаг 3: выключаем 6,1
TAB, OPT = 6, 1
log("Шаг 3: выключаю 6,1...")
disableOption()
task.wait(2)
-- если всё ещё on — пробуем ещё
for i = 1, 3 do
    local s = getOptionState()
    if s ~= "on" then break end
    disableOption()
    task.wait(2)
end
log("6,1 отключена.")

-- Шаг 4: включаем 2,4
TAB, OPT = 2, 4
log("Шаг 4: включаю 2,4...")
enableOption()
task.wait(2)
for i = 1, 3 do
    local s = getOptionState()
    if s == "on" then break end
    enableOption()
    task.wait(2)
end
log("2,4 активна.")

-- Шаг 5: ждём mastery > 500
log("Шаг 5: ожидание mastery > 500...")
repeat
    task.wait(3)
    local m = getMastery() or 0
    log("Mastery: " .. tostring(m))
until (getMastery() or 0) > 500
log("Mastery > 500.")
task.wait(2)

-- Шаг 6: выключаем 2,4
TAB, OPT = 2, 4
log("Шаг 6: выключаю 2,4...")
disableOption()
task.wait(2)
for i = 1, 3 do
    local s = getOptionState()
    if s ~= "on" then break end
    disableOption()
    task.wait(2)
end
log("2,4 отключена.")
task.wait(2)

-- Шаг 7: включаем 6,1
TAB, OPT = 6, 1
log("Шаг 7: включаю 6,1...")
enableOption()
task.wait(2)
for i = 1, 5 do
    local s = getOptionState()
    if s == "on" then break end
    enableOption()
    task.wait(2)
end
log("6,1 включена. Готово.")
