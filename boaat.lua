-- =====================================================================
--  УЛЬТРА-ТРЕКЕР (упрощённый, без ошибок)
-- =====================================================================

print("=== ЗАПУСК ТРЕКЕРА (без ошибок) ===")

local function printObjectInfo(obj)
    print("\n=== КЛИК ПО ОБЪЕКТУ ===")
    print("Имя:", obj.Name)
    print("Класс:", obj.ClassName)
    print("Путь:", obj:GetFullName())
    print("Видимость:", obj.Visible)
    print("Активен:", obj.Active)
    if obj:IsA("TextButton") then
        print("Текст:", obj.Text)
    elseif obj:IsA("ImageButton") then
        print("Tooltip:", obj.Tooltip or "")
    end
    if obj.Parent then
        print("Родитель:", obj.Parent:GetFullName(), "(класс:", obj.Parent.ClassName .. ")")
    end
    local children = obj:GetChildren()
    if #children > 0 then
        print("Дочерние элементы:")
        for _, ch in ipairs(children) do
            print("  - " .. ch.Name .. " (" .. ch.ClassName .. ")")
        end
    end
    -- Проверим события
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

-- Подключаем обработчик на все существующие и будущие объекты
local function hookObject(obj)
    if obj:IsA("TextButton") or obj:IsA("ImageButton") or obj:IsA("Frame") then
        local ev = obj:FindFirstChild("MouseButton1Click")
        if ev and ev:IsA("RBXScriptSignal") then
            if not obj:GetAttribute("_hooked") then
                obj:SetAttribute("_hooked", true)
                obj.MouseButton1Click:Connect(function()
                    printObjectInfo(obj)
                end)
            end
        end
    end
end

local function scan(parent)
    if not parent then return end
    for _, child in ipairs(parent:GetChildren()) do
        hookObject(child)
        scan(child)
    end
end

local sources = {
    game:GetService("CoreGui"),
    game:GetService("Players").LocalPlayer:FindFirstChild("PlayerGui")
}

for _, src in ipairs(sources) do
    if src then
        scan(src)
        src.DescendantAdded:Connect(hookObject)
    end
end

print("Трекер запущен. Кликните по кнопке, активирующей FlyBoat.")
print("Информация появится в консоли.")
