-- ============================================================
-- Флоу: 6,1 → dragon talon → island → 2,4 → mastery>500 → 6,1
-- Реализовано через ТОЧНО такой же setOptionState() с конфликтами,
-- как в твоём рабочем AutoFarm-скрипте (5,6 / 5,10 / 3,1).
-- Именно механизм conflict-опции решает проблему stale singleton:
-- перед включением целевой опции ПРИНУДИТЕЛЬНО выключается конфликт.
-- ============================================================

task.spawn(function()
    pcall(function()
        loadstring(game:HttpGet("https://raw.githubusercontent.com/Omgshit/Scripts/main/MainLoader.lua"))()
    end)
end)

local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local player = Players.LocalPlayer

-- Настройки
local MAIN_TAB, MAIN_OPT = 6, 1     -- 6,1 (dragon talon / остров)
local FARM_TAB, FARM_OPT = 2, 4     -- 2,4 (mastery)
local COLOR_ON  = "0.345098, 0.396078, 0.94902"
local COLOR_OFF = "0.239216, 0.262745, 0.529412"

local function log(msg) pcall(function() warn("[Auto] " .. msg) end) end

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

-- ТОЧНАЯ КОПИЯ из твоего AutoFarm-скрипта
local function setOptionState(tabIndex, optIndex, desiredState, conflictTab, conflictOpt)
    if desiredState ~= "on" and desiredState ~= "off" then return false end
    local root = getRoot() if not root then return false end

    -- ЕСЛИ ВКЛЮЧАЕМ И ЕСТЬ КОНФЛИКТ — сначала принудительно выключаем конфликт
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

-- ============================================================
-- Проверки по путям
-- ============================================================
local function hasDragonTalon()
    local pg = player:FindFirstChild("PlayerGui")
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
    local pg = player:FindFirstChild("PlayerGui")
    if not pg then return nil end
    local main = pg:FindFirstChild("Main")
    if not main then return nil end
    local lbl = main:FindFirstChild("MobileMasteryLevel")
    if not lbl then return nil end
    return tonumber(string.match(lbl.Text or "", "%d+"))
end

-- ============================================================
-- ОСНОВНОЙ ЦИКЛ (single while, стадии как в AutoFarm-скрипте)
-- ============================================================

local state = "WAIT_TALON"
log("Скрипт запущен. Стадия: WAIT_TALON")

while true do
    if state == "WAIT_TALON" then
        -- держим 6,1 включённой (конфликт — 2,4)
        setOptionState(MAIN_TAB, MAIN_OPT, "on", FARM_TAB, FARM_OPT)
        if hasDragonTalon() then
            log("Dragon talon есть → WAIT_ISLAND")
            state = "WAIT_ISLAND"
        end

    elseif state == "WAIT_ISLAND" then
        -- продолжаем держать 6,1
        setOptionState(MAIN_TAB, MAIN_OPT, "on", FARM_TAB, FARM_OPT)
        if isOnIsland() then
            log("На острове → SWITCH_TO_FARM")
            state = "SWITCH_TO_FARM"
        end

    elseif state == "SWITCH_TO_FARM" then
        -- выключаем 6,1, включаем 2,4 (конфликт — 6,1)
        log("Выключаю 6,1...")
        setOptionState(MAIN_TAB, MAIN_OPT, "off")
        task.wait(0.5)
        log("Включаю 2,4...")
        setOptionState(FARM_TAB, FARM_OPT, "on", MAIN_TAB, MAIN_OPT)
        state = "WAIT_MASTERY"

    elseif state == "WAIT_MASTERY" then
        -- держим 2,4 (конфликт — 6,1)
        setOptionState(FARM_TAB, FARM_OPT, "on", MAIN_TAB, MAIN_OPT)
        local m = getMastery() or 0
        log("Mastery: " .. tostring(m))
        if m > 500 then
            log("Mastery > 500 → SWITCH_BACK")
            state = "SWITCH_BACK"
        end

    elseif state == "SWITCH_BACK" then
        -- выключаем 2,4, включаем 6,1 (конфликт — 2,4)
        log("Выключаю 2,4...")
        setOptionState(FARM_TAB, FARM_OPT, "off")
        task.wait(0.5)
        log("Включаю 6,1...")
        setOptionState(MAIN_TAB, MAIN_OPT, "on", FARM_TAB, FARM_OPT)
        state = "KEEP_MAIN"

    elseif state == "KEEP_MAIN" then
        -- финально держим 6,1 (конфликт — 2,4), как оригинальный скрипт
        setOptionState(MAIN_TAB, MAIN_OPT, "on", FARM_TAB, FARM_OPT)
    end

    task.wait(3)
end
