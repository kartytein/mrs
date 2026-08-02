-- =====================================================================
--  РАСШИРЕННЫЙ ТРЕКЕР КЛИКОВ (по всем объектам)
-- =====================================================================

print("=== ЗАПУСК ТРЕКЕРА КЛИКОВ (полный перехват) ===")

-- Функция для вывода информации об объекте
local function printObjectInfo(obj, label)
    label = label or "Клик по объекту"
    print("\n=== " .. label .. " ===")
    print("Имя:", obj.Name)
    print("Класс:", obj.ClassName)
    print("Полный путь:", obj:GetFullName())
    print("Visible:", obj.Visible)
    print("Active:", obj.Active)
    if obj:IsA("TextButton") then
        print("Текст:", obj.Text)
    elseif obj:IsA("ImageButton") then
        print("Tooltip:", obj.Tooltip or "")
    end
    -- Выводим родителя
    local parent = obj.Parent
    if parent then
        print("Родитель:", parent:GetFullName() .. " (класс: " .. parent.ClassName .. ")")
    end
    -- Выводим всех потомков, если есть
    local children = obj:GetChildren()
    if #children > 0 then
        print("Дочерние элементы:")
        for _, ch in ipairs(children) do
            print("  -", ch.Name, "(", ch.ClassName, ")")
        end
    end
    -- Проверяем наличие событий
    local events = {"MouseButton1Click", "MouseButton1Down", "MouseButton1Up", "Activated"}
    for _, evName in ipairs(events) do
        local ev = obj:FindFirstChild(evName)
        if ev and ev:IsA("RBXScriptSignal") then
            print("Событие", evName, "присутствует.")
            if getconnections then
                local conns = getconnections(ev)
                if #conns > 0 then
                    print("  Количество привязок:", #conns)
                    for i, c in ipairs(conns) do
                        if c.Script then
                            print("    Привязка", i, "скрипт:", c.Script:GetFullName())
                        end
                        if c.Function then
                            print("    Функция:", tostring(c.Function))
                        end
                    end
                end
            end
        end
    end
    print("===========================")
end

-- 1. Перехват кликов на всех объектах через DescendantAdded (для новых объектов)
local function hookObject(obj)
    if obj:IsA("TextButton") or obj:IsA("ImageButton") or obj:IsA("Frame") then
        if obj:FindFirstChild("MouseButton1Click") then
            local conn = obj.MouseButton1Click:Connect(function()
                printObjectInfo(obj, "ПЕРЕХВАТЧИК НА ОБЪЕКТЕ")
            end)
            -- Сохраняем connection, чтобы не потерять
            if not obj:GetAttribute("_hookActive") then
                obj:SetAttribute("_hookActive", true)
                obj:SetAttribute("_hookConn", conn)
            end
        end
    end
end

-- Обработка существующих объектов
local function scanAndHook(parent)
    if not parent then return end
    for _, child in ipairs(parent:GetChildren()) do
        hookObject(child)
        scanAndHook(child)
    end
end

-- Запускаем для CoreGui и PlayerGui
local sources = {
    game:GetService("CoreGui"),
    game:GetService("Players").LocalPlayer:FindFirstChild("PlayerGui")
}
for _, src in ipairs(sources) do
    if src then
        scanAndHook(src)
        src.DescendantAdded:Connect(hookObject)
    end
end

-- 2. Дополнительный перехват через UserInputService (глобальный)
local inputService = game:GetService("UserInputService")
inputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        -- Получаем объект под курсором
        local mouse = inputService:GetMouseLocation()
        local target = nil
        -- Используем GuiService для поиска объекта под курсором (если доступно)
        pcall(function()
            local guiService = game:GetService("GuiService")
            target = guiService:GetGuiObjectsAtPosition(mouse.X, mouse.Y)
            if target and #target > 0 then
                target = target[1]
            end
        end)
        if target then
            printObjectInfo(target, "ПЕРЕХВАТЧИК UserInputService")
        else
            print("Клик по координатам, но объект не определён.")
        end
    end
end)

print("Трекер запущен. Теперь кликните по кнопке, которая активирует FlyBoat.")
print("Информация о кликнутом объекте появится в консоли.")
