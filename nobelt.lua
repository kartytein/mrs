-- ============================================================
-- Понял в чём дело. В твоём рабочем скрипте ничего не форсится:
-- он просто крутит while-цикл каждые 3 сек и ждёт, пока хаб
-- сам всё прогрузит (state == nil → просто ждём).
-- Я же форсил клики ДО того, как элементы появились, и это ломало.
-- Теперь КАЖДАЯ стадия — это ТОЧНО ТАКОЙ ЖЕ цикл, что и твой.
-- Продвижение только по подтверждённому игровому состоянию.
-- ============================================================

task.spawn(function()
    pcall(function()
        loadstring(game:HttpGet("https://raw.githubusercontent.com/Omgshit/Scripts/main/MainLoader.lua"))()
    end)
end)

local CoreGui = game:GetService("CoreGui")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local COLOR_ON  = "0.345098, 0.396078, 0.94902"
local COLOR_OFF = "0.239216, 0.262745, 0.529412"

local function log(msg) pcall(function() warn("[Auto] " .. msg) end) end

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

-- === enableOption — БУКВАЛЬНО как в твоём скрипте, но с параметрами ===
local function enableOption(tabIndex, optIndex)
    local state = getOptionState(tabIndex, optIndex)
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
                if tabCount == tabIndex then tabButton = c return end
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
            if optCount == optIndex then optionBtn = c break end
        end
    end
    if not optionBtn then return false end
    fireSequence(optionBtn)
    task.wait(0.1)
    return true
end

-- === toggleOption — принудительный клик (для выключения) ===
local function toggleOption(tabIndex, optIndex)
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
                if tabCount == tabIndex then tabButton = c return end
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
            if optCount == optIndex then optionBtn = c break end
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
-- СТАДИИ. Каждая — цикл ровно как в твоём рабочем скрипте:
--   getOptionState → если off → enableOption → task.wait(3)
-- Если state == nil — НЕ форсим, просто ждём следующий тик.
-- ============================================================

-- СТАДИЯ 1: держим 6,1, пока dragon talon не появится
log("Стадия 1: dragon talon...")
while true do
    local state = getOptionState(6, 1)
    if state == "off" then
        log("6,1 off — включаю...")
        enableOption(6, 1)
    elseif state == "on" then
        -- ok
    else
        log("6,1 не найдена, ждём полной прогрузки...")
    end
    if hasDragonTalon() then break end
    task.wait(3)
end
log("Dragon talon есть.")

-- СТАДИЯ 2: держим 6,1, пока не окажемся на острове
log("Стадия 2: остров...")
while true do
    local state = getOptionState(6, 1)
    if state == "off" then
        enableOption(6, 1)
    elseif state == "on" then
        -- ok
    else
        log("6,1 не найдена, ждём...")
    end
    if isOnIsland() then break end
    task.wait(3)
end
log("На острове.")

-- СТАДИЯ 3: выключаем 6,1
log("Стадия 3: выключаю 6,1...")
while true do
    local state = getOptionState(6, 1)
    if state == "on" then
        toggleOption(6, 1)
    elseif state == "off" then
        break
    else
        log("6,1 не найдена, ждём...")
    end
    task.wait(3)
end
log("6,1 отключена.")

-- СТАДИЯ 4: включаем 2,4
log("Стадия 4: включаю 2,4...")
while true do
    local state = getOptionState(2, 4)
    if state == "off" then
        enableOption(2, 4)
    elseif state == "on" then
        break
    else
        log("2,4 не найдена, ждём...")
    end
    task.wait(3)
end
log("2,4 активна.")

-- СТАДИЯ 5: ждём mastery > 500
log("Стадия 5: mastery > 500...")
while true do
    local m = getMastery() or 0
    log("Mastery: " .. tostring(m))
    if m > 500 then break end
    task.wait(3)
end
log("Mastery > 500.")

-- СТАДИЯ 6: выключаем 2,4
log("Стадия 6: выключаю 2,4...")
while true do
    local state = getOptionState(2, 4)
    if state == "on" then
        toggleOption(2, 4)
    elseif state == "off" then
        break
    else
        log("2,4 не найдена, ждём...")
    end
    task.wait(3)
end
log("2,4 отключена.")

-- СТАДИЯ 7: включаем 6,1
log("Стадия 7: включаю 6,1...")
while true do
    local state = getOptionState(6, 1)
    if state == "off" then
        enableOption(6, 1)
    elseif state == "on" then
        break
    else
        log("6,1 не найдена, ждём...")
    end
    task.wait(3)
end
log("6,1 включена. Готово.")
