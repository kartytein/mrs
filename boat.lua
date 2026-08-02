-- ============================================================================
--  ДИАГНОСТИКА КНОПКИ: собираем ВСЕ данные для понимания, как её активировать
--  Запустите в Delta. В консоль выведется полный отчёт.
-- ============================================================================

local targetPath = "CoreGui.5254c01c4691269e68d25763275f564b3f6d90d88346ad2f0bba357e7d8c00c1.redz-library-v5.Window.Components.Containers.Container.Option"
local btn = nil

-- Попытка получить кнопку
pcall(function()
    btn = _G[targetPath] or game:GetService("CoreGui"):FindFirstChild("5254c01c4691269e68d25763275f564b3f6d90d88346ad2f0bba357e7d8c00c1") -- лучше искать по полному пути динамически
end)
-- Упростим: найдём объект напрямую, используя GetFullName
local function findTarget()
    for _, obj in ipairs(game:GetDescendants()) do
        if obj:GetFullName() == targetPath then
            return obj
        end
    end
    return nil
end

btn = findTarget()

if not btn then
    print("Кнопка не найдена. Проверьте путь.")
    return
end

print("=== ДИАГНОСТИКА КНОПКИ ===")
print("Путь:", targetPath)
print("Класс:", btn.ClassName)
print("Имя:", btn.Name)

-- 1. Все атрибуты
print("\nАтрибуты:")
for _, attr in ipairs(btn:GetAttributes()) do
    print("  " .. attr .. " = " .. tostring(btn:GetAttribute(attr)))
end

-- 2. Теги CollectionService (могут быть важны)
local CollectionService = game:GetService("CollectionService")
local tags = {}
for _, tag in ipairs(CollectionService:GetTags(btn)) do
    table.insert(tags, tag)
end
print("Теги: " .. table.concat(tags, ", "))

-- 3. Дочерние элементы (возможно, скрытый ClickDetector?)
print("\nДочерние элементы:")
for _, child in ipairs(btn:GetChildren()) do
    print("  " .. child:GetFullName() .. " (" .. child.ClassName .. ")")
end

-- 4. Родительские скрипты, обрабатывающие клики (рекурсивно вверх)
print("\nОбработчики в родительской иерархии:")
local parent = btn
while parent do
    for _, child in ipairs(parent:GetChildren()) do
        if child:IsA("LocalScript") or child:IsA("Script") or child:IsA("ModuleScript") then
            -- Пытаемся получить его код (может не дать из-за безопасности)
            local src = "недоступен"
            pcall(function()
                src = child:GetFullName() .. ":\n" .. child.Source:sub(1, 500) -- первые 500 символов
            end)
            print(string.format("  Скрипт: %s (%s)", child:GetFullName(), child.ClassName))
            print("    Первые 500 символов: " .. src)
        end
        -- Возможно, есть RemoteEvent или BindableEvent для кликов
        if child:IsA("RemoteEvent") or child:IsA("BindableEvent") then
            print(string.format("  Событие: %s (%s)", child:GetFullName(), child.ClassName))
        end
    end
    parent = parent.Parent
end

-- 5. Подключаем наблюдателей за событиями на кнопке и родителе
-- Ловим Activated, MouseButton1Click, MouseButton1Down, InputBegan на 3 родителя вверх
print("\nПодключаем наблюдателей событий...")
local events = {"Activated", "MouseButton1Click", "MouseButton1Down", "MouseButton2Click", "MouseEnter", "MouseLeave"}
local connectedSignals = {}

local function connectSignal(obj, eventName)
    local signal = obj[eventName]
    if signal then
        local conn = signal:Connect(function(...)
            local args = {...}
            print(string.format("  [!] Событие %s на %s вызвано! Аргументы: %s", eventName, obj:GetFullName(), tostring(#args > 0 and args[1] or "нет")))
            -- Ловим сам факт вызова, чтобы понять, какое событие реально реагирует
        end)
        table.insert(connectedSignals, conn)
    end
end

for _, ev in ipairs(events) do
    connectSignal(btn, ev)
end

-- Также на родителя (Container), вдруг обработка на нём
local container = btn.Parent
if container then
    for _, ev in ipairs(events) do
        connectSignal(container, ev)
    end
    -- InputBegan на GuiObject ловит любые вводы (включая мышь)
    if container:IsA("GuiObject") then
        connectSignal(container, "InputBegan")
    end
end

-- Ещё выше на Components
local components = container and container.Parent
if components then
    connectSignal(components, "InputBegan")
end

print("Теперь вручную кликните по кнопке. В консоли отобразится, какие события сработали.")

-- 6. Дополнительно: проверим, подключен ли VirtualUser и может ли Delta симулировать мышь
local VirtualInputManager = game:GetService("VirtualInputManager")
local UserInputService = game:GetService("UserInputService")
print("\nИнформация для симуляции мыши:")
print("  Позиция кнопки (AbsolutePosition):", btn.AbsolutePosition)
print("  Размер кнопки (AbsoluteSize):", btn.AbsoluteSize)
local center = btn.AbsolutePosition + btn.AbsoluteSize / 2
print("  Центр кнопки:", center)
print("  Текущая позиция мыши:", UserInputService:GetMouseLocation())
-- Проверка на возможность использования SendMouseInputEvent (может быть запрещено)
print("  VirtualInputManager доступен:", VirtualInputManager and "Да" or "Нет")
print("  Поддерживается SendMouseInputEvent:", pcall(function() VirtualInputManager:SendMouseInputEvent(center.X, center.Y, 0, true, game, 0) end) and "Да" or "Нет")

print("\n=== ДИАГНОСТИКА ЗАВЕРШЕНА ===")
print("После клика проанализируйте, какие события сработали, и используйте соответствующий firesignal.")
