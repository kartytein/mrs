-- ============================================================
-- Дело в том, что в твоём рабочем скрипте ГЛАВНЫЙ цикл всё время
-- крутит getOptionState(6,1) + fireSequence(tab6). Этот постоянный
-- клик по вкладке 6 и держит опцию реально активной (не только визуально).
-- Когда я переключал переменные на 2,4 или «умно» форсил — цикл ломался,
-- и hub считал кнопку "on", но функционально она не работала.
--
-- Решение: ОДИН бесконечный цикл как у тебя. Меняю только TAB/OPT
-- переменные, но НИКОГДА не останавливаю паттерн
-- "getOptionState → if off → enableOption → wait(3)".
-- ============================================================

task.spawn(function()
    pcall(function()
        loadstring(game:HttpGet("https://raw.githubusercontent.com/Omgshit/Scripts/main/MainLoader.lua"))()
    end)
end)

local CoreGui = game:GetService("CoreGui")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

-- ТЕКУЩИЕ цели — меняются по ходу флоу, но цикл один и тот же
local TAB = 6
local OPT = 1

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

-- === getOptionState — БУКВАЛЬНО как в твоём скрипте ===
local function getOptionState(tabIndex, optIndex)
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
                if tabCount == tabIndex then tabButton = c return end
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
            if optCount == optIndex then optionBtn = c break end
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

-- === enableOption — БУКВАЛЬНО как в твоём скрипте (использует TAB, OPT) ===
local function enableOption()
    local state = getOptionState(TAB, OPT)
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

-- === disableOption — зеркало (только переключение off) ===
local function disableOption()
    local state = getOptionState(TAB, OPT)
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

-- === Предикаты ===
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
-- ЕДИНЫЙ БЕСКОНЕЧНЫЙ ЦИКЛ (ровно как у тебя).
-- Просто меняю TAB/OPT в нужные моменты.
-- ============================================================

local stage = 1 -- 1: talon, 2: island, 3: switch to 2,4, 4: wait mastery, 5: switch back to 6,1

log("Скрипт запущен. Стадия 1: dragon talon")

while true do
    local state = getOptionState(TAB, OPT)

    if stage == 1 then
        -- держим 6,1 пока не появится dragon talon
        if state == "off" then
            log("6,1 off — включаю...")
            enableOption()
        elseif state == "on" then
            -- ok
        else
            log("6,1 не найдена, ожидание...")
        end
        if hasDragonTalon() then
            log("Dragon talon есть → стадия 2 (остров)")
            stage = 2
        end

    elseif stage == 2 then
        -- продолжаем держать 6,1 пока не окажемся на острове
        if state == "off" then
            enableOption()
        elseif state == "on" then
            -- ok
        else
            log("6,1 не найдена, ожидание...")
        end
        if isOnIsland() then
            log("На острове → стадия 3 (переключаюсь на 2,4)")
            stage = 3
        end

    elseif stage == 3 then
        -- выключаю 6,1
        if state == "on" then
            log("Выключаю 6,1...")
            disableOption()
        elseif state == "off" then
            -- 6,1 выключена → переключаемся на 2,4
            log("6,1 off → переключаю цель на 2,4")
            TAB, OPT = 2, 4
            stage = 4
        else
            log("6,1 не найдена, ожидание...")
        end

    elseif stage == 4 then
        -- держу 2,4 пока mastery не станет > 500
        if state == "off" then
            log("2,4 off — включаю...")
            enableOption()
        elseif state == "on" then
            -- ok
        else
            log("2,4 не найдена, ожидание...")
        end
        local m = getMastery() or 0
        log("Mastery: " .. tostring(m))
        if m > 500 then
            log("Mastery > 500 → стадия 5 (выключаю 2,4)")
            stage = 5
        end

    elseif stage == 5 then
        -- выключаю 2,4
        if state == "on" then
            log("Выключаю 2,4...")
            disableOption()
        elseif state == "off" then
            -- 2,4 выключена → возвращаем цель на 6,1
            log("2,4 off → переключаю цель на 6,1")
            TAB, OPT = 6, 1
            stage = 6
        else
            log("2,4 не найдена, ожидание...")
        end

    elseif stage == 6 then
        -- финально держим 6,1 включённой
        if state == "off" then
            log("6,1 off — включаю...")
            enableOption()
        elseif state == "on" then
            log("6,1 включена. Готово.")
            stage = 7
        else
            log("6,1 не найдена, ожидание...")
        end

    elseif stage == 7 then
        -- просто держим 6,1 (как твой оригинальный скрипт)
        if state == "off" then
            enableOption()
        end
    end

    task.wait(3)
end
