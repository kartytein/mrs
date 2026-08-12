-- ============================================================
-- Активация кнопки 61
-- ============================================================

-- Загрузка хаба (асинхронно)
task.spawn(function()
    pcall(function()
        loadstring(game:HttpGet("https://raw.githubusercontent.com/Omgshit/Scripts/main/MainLoader.lua"))()
    end)
end)

local CoreGui = game:GetService("CoreGui")
local COLOR_ON  = "0.345098, 0.396078, 0.94902"
local COLOR_OFF = "0.239216, 0.262745, 0.529412"

local function log(msg)
    pcall(function() warn("[Activate61] " .. msg) end)
end

-- ======================== ИНСТРУМЕНТЫ ========================
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

local function waitForInterface()
    return getRoot() and safeFind(getRoot(), "Window", "Components", "TabsScroll")
end

-- Эмуляция полного клика по кнопке
local function fireSequence(btn)
    if not (btn:IsA("TextButton") or btn:IsA("ImageButton")) then return end
    local signals = {
        "MouseEnter", "MouseButton1Down", "MouseButton1Click",
        "MouseButton1Up", "Activated", "MouseLeave"
    }
    for _, sig in ipairs(signals) do
        local event = btn[sig]
        if event then
            for _, conn in ipairs(getconnections(event) or {}) do
                if conn.Enabled then
                    pcall(conn.Function)
                end
            end
        end
    end
end

-- Поиск индикаторного Frame (цвет состояния)
local function findIndicatorFrame(parent)
    for _, child in ipairs(parent:GetChildren()) do
        if child:IsA("Frame") then
            local col = tostring(child.BackgroundColor3)
            if col == COLOR_ON or col == COLOR_OFF then
                return child
            end
        end
        local found = findIndicatorFrame(child)
        if found then return found end
    end
end

-- Проверка состояния опции (tabIndex, optIndex)
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
                if tabCount == tabIndex then
                    tabButton = child
                    return
                end
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
        if child.Name == "Option" and child.Visible
           and (child:IsA("TextButton") or child:IsA("ImageButton")) then
            optCount = optCount + 1
            if optCount == optIndex then
                optionBtn = child
                break
            end
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

-- Включение/выключение опции
local function setOptionState(tabIndex, optIndex, desiredState, conflictTab, conflictOpt)
    if desiredState ~= "on" and desiredState ~= "off" then return false end
    local root = getRoot()
    if not root then return false end

    -- Обработка конфликта (если включаем "on", сначала выключаем указанную пару)
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
                        if c.Name == "Option" and c.Visible
                           and (c:IsA("TextButton") or c:IsA("ImageButton")) then
                            cfOptCount = cfOptCount + 1
                            if cfOptCount == conflictOpt then
                                local ind = findIndicatorFrame(c)
                                if ind and tostring(ind.BackgroundColor3) == COLOR_ON then
                                    fireSequence(c)
                                end
                                break
                            end
                        end
                    end
                end
                task.wait(0.1)
            end
        end
    end

    -- Переключение на нужную вкладку
    local tabsScroll = safeFind(root, "Window", "Components", "TabsScroll")
    if not tabsScroll then return false end

    local tabButton, tabCount = nil, 0
    local function findTab(p)
        if tabButton then return end
        for _, c in ipairs(p:GetChildren()) do
            if c:IsA("TextButton") or c:IsA("ImageButton") then
                tabCount = tabCount + 1
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
        if c.Name == "Option" and c.Visible
           and (c:IsA("TextButton") or c:IsA("ImageButton")) then
            optCount = optCount + 1
            if optCount == optIndex then optionBtn = c break end
        end
    end
    if not optionBtn then return false end

    -- Пропускаем, если уже в нужном состоянии
    local indicator = findIndicatorFrame(optionBtn)
    if indicator then
        local currentCol = tostring(indicator.BackgroundColor3)
        if (currentCol == COLOR_ON and desiredState == "on") or
           (currentCol == COLOR_OFF and desiredState == "off") then
            return true
        end
    end

    fireSequence(optionBtn)
    task.wait(0.1)
    return true
end

-- ======================== АКТИВАЦИЯ ========================
log("Ожидание интерфейса...")
repeat task.wait(0.5) until waitForInterface()
log("Интерфейс готов.")

-- Не уверен, что кнопка 61 – это опция 61 в первой вкладке.
-- При необходимости измените первый аргумент на номер нужной вкладки.
local tabForButton61 = 1     -- номер вкладки (предположительно)
local optIndex = 61          -- номер опции в этой вкладке

local success = setOptionState(tabForButton61, optIndex, "on")
if success then
    log("Кнопка 61 активирована.")
else
    log("Не удалось активировать кнопку 61. Проверьте индексы.")
end
