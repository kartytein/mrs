-- ============================================================
--  ОПРЕДЕЛЕНИЕ СОСТОЯНИЯ (ВКЛ/ВЫКЛ) И ПЕРЕКЛЮЧЕНИЕ ПО ЖЕЛАНИЮ
--  Индикатор: цвет дочернего Frame внутри Option.
--  Вкл:  0.345098, 0.396078, 0.94902
--  Выкл: 0.239216, 0.262745, 0.529412
--  Измените TAB_INDEX и OPTION_INDEX под свою кнопку.
--  Установите TOGGLE = true, чтобы переключить состояние.
-- ============================================================

local TAB_INDEX = 5        -- Номер вкладки в TabsScroll
local OPTION_INDEX = 6     -- Номер видимой Option
local TOGGLE = false       -- true: переключить (кликнуть), false: только проверить

-- Эталонные цвета
local COLOR_ON  = "0.345098, 0.396078, 0.94902"
local COLOR_OFF = "0.239216, 0.262745, 0.529412"

-- Поиск корня и контейнера
local coreGui = game:GetService("CoreGui")
local root
for _, child in ipairs(coreGui:GetChildren()) do
    root = child:FindFirstChild("redz-library-v5")
    if root then break end
end
if not root then print("[Ошибка] redz-library-v5") return end

-- Переключаем вкладку, если нужно (полная последовательность)
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

-- Найти кнопку вкладки
local tabsScroll = root:FindFirstChild("Window")
tabsScroll = tabsScroll and tabsScroll:FindFirstChild("Components")
tabsScroll = tabsScroll and tabsScroll:FindFirstChild("TabsScroll")
if not tabsScroll then print("[Ошибка] TabsScroll") return end

local tabButton
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
if not tabButton then print("[Ошибка] Вкладка "..TAB_INDEX) return end

fireSequence(tabButton)   -- переключаем вкладку
wait(0.15)

-- Получаем Option
local container = root:FindFirstChild("Window")
container = container and container:FindFirstChild("Components")
container = container and container:FindFirstChild("Containers")
container = container and container:FindFirstChild("Container")
if not container then print("[Ошибка] Container") return end

local optionBtn
local optIdx = 0
for _, child in ipairs(container:GetChildren()) do
    if child.Name == "Option" and child.Visible and (child:IsA("TextButton") or child:IsA("ImageButton")) then
        optIdx = optIdx + 1
        if optIdx == OPTION_INDEX then optionBtn = child break end
    end
end
if not optionBtn then print("[Ошибка] Option "..OPTION_INDEX) return end

-- Функция поиска индикаторного Frame
local function getIndicatorFrame(btn)
    for _, child in ipairs(btn:GetChildren()) do
        if child:IsA("Frame") and child.Name == "Frame" then
            -- Проверяем, что у него есть BackgroundColor3 и он совпадает с одним из эталонов
            local col = tostring(child.BackgroundColor3)
            if col == COLOR_ON or col == COLOR_OFF then
                return child
            end
        end
    end
    -- Если не нашлось по имени, ищем любой Frame с подходящим цветом
    for _, child in ipairs(btn:GetChildren()) do
        if child:IsA("Frame") then
            local col = tostring(child.BackgroundColor3)
            if col == COLOR_ON or col == COLOR_OFF then
                return child
            end
        end
    end
    return nil
end

local indicator = getIndicatorFrame(optionBtn)
if not indicator then
    print("[Ошибка] Индикаторный Frame не найден внутри кнопки.")
    return
end

-- Определяем состояние
local currentColor = tostring(indicator.BackgroundColor3)
local isOn = (currentColor == COLOR_ON)
if isOn then
    print("Состояние: ВКЛЮЧЕНО")
elseif currentColor == COLOR_OFF then
    print("Состояние: ВЫКЛЮЧЕНО")
else
    print("Состояние: НЕИЗВЕСТНО (цвет " .. currentColor .. ")")
end

-- Переключение, если нужно
if TOGGLE then
    print("Переключаем...")
    fireSequence(optionBtn)
    -- Ждём обновления UI
    wait(0.1)
    -- Проверяем новое состояние
    indicator = getIndicatorFrame(optionBtn)
    if indicator then
        local newColor = tostring(indicator.BackgroundColor3)
        if newColor == COLOR_ON then
            print("Новое состояние: ВКЛЮЧЕНО")
        elseif newColor == COLOR_OFF then
            print("Новое состояние: ВЫКЛЮЧЕНО")
        else
            print("Новое состояние: НЕИЗВЕСТНО")
        end
    end
end
