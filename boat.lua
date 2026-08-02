local path = "CoreGui.5254c01c4691269e68d25763275f564b3f6d90d88346ad2f0bba357e7d8c00c1.redz-library-v5.Window.Components.Containers.Container.Option"

local function getObjectByPath(p)
    local parts = {}
    for part in string.gmatch(p, "[^%.]+") do table.insert(parts, part) end
    local current = game:GetService(parts[1])
    for i = 2, #parts do
        current = current:FindFirstChild(parts[i])
        if not current then return nil end
    end
    return current
end

local frame = getObjectByPath(path)
if not frame then
    print("Frame не найден.")
    return
end

if frame:FindFirstChild("MouseButton1Click") then
    frame.MouseButton1Click:Connect(function()
        print("\n=== КЛИК ПЕРЕХВАЧЕН ===")
        print(debug.traceback())
        print("=========================\n")
    end)
    print("Теперь кликните по кнопке (по тексту 'Option'). Стек появится в консоли.")
else
    print("У Frame нет события MouseButton1Click. Возможно, обработчик висит на родителе.")
    -- Попробуем подключиться к родителю
    local parent = frame.Parent
    if parent and parent:FindFirstChild("MouseButton1Click") then
        parent.MouseButton1Click:Connect(function()
            print("\n=== КЛИК НА РОДИТЕЛЕ ПЕРЕХВАЧЕН ===")
            print(debug.traceback())
            print("=========================\n")
        end)
        print("Подключились к родителю. Кликните по 'Option'.")
    else
        print("Не удалось найти событие MouseButton1Click ни на Frame, ни на родителе.")
    end
end
