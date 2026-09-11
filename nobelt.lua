-- ============================================================
-- Флоу: 6,1 → dragon talon → island → 2,4 → mastery>500 → 6,1
-- Один бесконечный цикл (как в оригинале). Смена цели — через TAB/OPT.
-- Финал: принудительный сброс 6,1 → включение → верификация → hold.
-- ============================================================

task.spawn(function()
    pcall(function()
        loadstring(game:HttpGet("https://raw.githubusercontent.com/Omgshit/Scripts/main/MainLoader.lua"))()
    end)
end)

local CoreGui = game:GetService("CoreGui")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

-- Текущая цель (меняется по стадиям)
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

-- === getOptionState — как в оригинале (кликает по вкладке) ===
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

-- === enableOption — как в оригинале (читает глобальные TAB/OPT) ===
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

-- === disableOption — зеркало (читает глобальные TAB/OPT) ===
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
-- ЕДИНЫЙ ЦИКЛ
-- ============================================================
local stage = 1
-- 1: talon (6,1)
-- 2: island (6,1)
-- 3: выключить 6,1
-- 4: включить 2,4 и ждать mastery > 500
-- 5: выключить 2,4
-- 6: сброс 6,1 (если on — выключаем) → включение
-- 7: верификация 6,1
-- 8: hold

log("Скрипт запущен. Стадия 1: dragon talon")

while true do
    local state = getOptionState(TAB, OPT)

    if stage == 1 then
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
        if state == "off" then
            enableOption()
        elseif state == "on" then
            -- ok
        else
            log("6,1 не найдена, ожидание...")
        end
        if isOnIsland() then
            log("На острове → стадия 3 (выключаю 6,1)")
            stage = 3
        end

    elseif stage == 3 then
        if state == "on" then
            log("Выключаю 6,1...")
            disableOption()
        elseif state == "off" then
            log("6,1 off → стадия 4 (2,4)")
            TAB, OPT = 2, 4
            stage = 4
        else
            log("6,1 не найдена, ожидание...")
        end

    elseif stage == 4 then
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
        if state == "on" then
            log("Выключаю 2,4...")
            disableOption()
        elseif state == "off" then
            log("2,4 off → стадия 6 (возврат на 6,1 со сбросом)")
            TAB, OPT = 6, 1
            stage = 6
        else
            log("2,4 не найдена, ожидание...")
        end

    elseif stage == 6 then
        -- После вкладки 2 индикатор 6,1 может показывать stale "on".
        -- Сначала принудительно сбрасываем, потом включаем.
        if state == "on" then
            log("6,1 показывает on (возможно stale) — сбрасываю...")
            disableOption()
        elseif state == "off" then
            log("6,1 off — включаю...")
            enableOption()
            stage = 7
        else
            log("6,1 не найдена, ожидание...")
        end

    elseif stage == 7 then
        -- Верификация: реально ли on?
        if state == "off" then
            log("6,1 снова off — возврат в stage 6")
            stage = 6
        elseif state == "on" then
            log("6,1 стабильно включена.")
            stage = 8
        else
            log("6,1 не найдена, ждём...")
        end

    elseif stage == 8 then
        -- hold как оригинальный скрипт
        if state == "off" then
            enableOption()
        end
    end

    task.wait(3)
end
