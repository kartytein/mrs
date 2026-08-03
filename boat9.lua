-- ============================================================
--  ПРОВЕРКА СОСТОЯНИЯ (ВКЛ/ВЫКЛ) И ПЕРЕКЛЮЧЕНИЕ (если нужно)
--  Индикатор – Frame внутри кнопки Option (рекурсивный поиск)
--  Цвета:
--    Вкл:  0.345098, 0.396078, 0.94902
--    Выкл: 0.239216, 0.262745, 0.529412
--  Параметры TAB_INDEX, OPTION_INDEX и TOGGLE
-- ============================================================

local TAB_INDEX = 5        -- номер вкладки
local OPTION_INDEX = 6     -- номер видимой Option
local TOGGLE = false       -- true = переключить, false = только узнать состояние

local COLOR_ON  = "0.345098, 0.396078, 0.94902"
local COLOR_OFF = "0.239216, 0.262745, 0.529412"

-- ======== ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ ========

-- Поиск redz-library-v5
local function getRoot()
    for _, child in ipairs(game:GetService("CoreGui"):GetChildren()) do
        local obj = child:FindFirstChild("redz-library-v5")
        if obj then return obj end
    end
    return nil
end

-- Вызов полной последовательности сигналов
local function fireSequence(btn)
    for _, sigName in ipairs({"MouseEnter","MouseButton1Down","MouseButton1Click","MouseButton1Up","Activated","MouseLeave"}) do
        local sig = btn[sigName]
        if sig then
            local ok, conns = pcall(function() return getconnections(sig) end)
            if ok and conns then
                for _, conn in ipairs(conns) do
                    if conn and conn.Enabled and type(conn.Function) == "function" then
                        conn.Function()
                    end
                end
            end
        end
    end
end

-- Рекурсивный поиск Frame с заданным цветом
local function findIndicatorFrame(parent)
    for _, child in ipairs(parent:GetChildren()) do
        if child:IsA("Frame") then
            local col = tostring(child.BackgroundColor3)
            if col == COLOR_ON or col == COLOR_OFF then
                return child
            end
        end
        -- ищем глубже
        local found = findIndicatorFrame(child)
        if found then return found end
    end
    return nil
end

-- ======== ОСНОВНОЙ КОД ========
local root = getRoot()
if not root then print("[Ошибка] redz-library-v5 не найден") return end

-- 1. Переключаем вкладку (если нужно)
local tabsScroll = root:FindFirstChild("Window")
tabsScroll = tabsScroll and tabsScroll:FindFirstChild("Components")
tabsScroll = tabsScroll and tabsScroll:FindFirstChild("TabsScroll")
if not tabsScroll then print("[Ошибка] TabsScroll") return end

-- Найти кнопку вкладки по индексу
local tabButton = nil
local tabIdx = 0
local function findTab(parent)
    if tabButton then return end
    for _, child in ipairs(parent:GetChildren()) do
        if child:IsA("TextButton") or child:IsA("ImageButton") then
            tabIdx = tabIdx + 1
            if tabIdx == TAB_INDEX then tabButton = child return end
        end
        findTab(child)
    end
end
findTab(tabsScroll)
if not tabButton then print("[Ошибка] Вкладка " .. TAB_INDEX) return end

fireSequence(tabButton)
wait(0.15)  -- ждём обновления UI

-- 2. Найти нужную Option (только видимые)
local container = root:FindFirstChild("Window")
container = container and container:FindFirstChild("Components")
container = container and container:FindFirstChild("Containers")
container = container and container:FindFirstChild("Container")
if not container then print("[Ошибка] Container") return end

local optionBtn = nil
local optIdx = 0
for _, child in ipairs(container:GetChildren()) do
    if child.Name == "Option" and child.Visible and (child:IsA("TextButton") or child:IsA("ImageButton")) then
        optIdx = optIdx + 1
        if optIdx == OPTION_INDEX then optionBtn = child break end
    end
end
if not optionBtn then print("[Ошибка] Option " .. OPTION_INDEX) return end

-- 3. Ищем индикаторный Frame
local indicator = findIndicatorFrame(optionBtn)
if not indicator then
    print("[Ошибка] Индикаторный Frame не найден внутри кнопки.")
    return
end

-- 4. Определяем состояние
local currentColor = tostring(indicator.BackgroundColor3)
if currentColor == COLOR_ON then
    print("Состояние: ВКЛЮЧЕНО")
elseif currentColor == COLOR_OFF then
    print("Состояние: ВЫКЛЮЧЕНО")
else
    print("Состояние: НЕИЗВЕСТНО (цвет " .. currentColor .. ")")
end

-- 5. Переключение при TOGGLE = true
if TOGGLE then
    print("Переключаем...")
    fireSequence(optionBtn)
    wait(0.1)
    -- Повторный поиск индикатора (на случай, если дерево изменилось)
    indicator = findIndicatorFrame(optionBtn)
    if indicator then
        local newColor = tostring(indicator.BackgroundColor3)
        if newColor == COLOR_ON then
            print("Новое состояние: ВКЛЮЧЕНО")
        elseif newColor == COLOR_OFF then
            print("Новое состояние: ВЫКЛЮЧЕНО")
        else
            print("Новое состояние: НЕИЗВЕСТНО")
        end
    else
        print("Не удалось проверить новое состояние (индикатор не найден).")
    end
end
