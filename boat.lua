-- ============================================================
--  ПРОСТОЙ ТРЕКЕР КЛИКОВ ПО КНОПКЕ OPTION
--  Вставьте в консоль Delta. При клике на кнопку выведет стек.
-- ============================================================

local path = "CoreGui.5254c01c4691269e68d25763275f564b3f6d90d88346ad2f0bba357e7d8c00c1.redz-library-v5.Window.Components.Containers.Container.Option"

local function getByPath(p)
    local parts = {}
    for part in string.gmatch(p, "[^%.]+") do table.insert(parts, part) end
    local current = game:GetService(parts[1])
    for i = 2, #parts do
        current = current:FindFirstChild(parts[i])
        if not current then return nil end
    end
    return current
end

local btn = getByPath(path)
if not btn then print("Кнопка не найдена") return end

print("Трекер запущен. Нажми на кнопку Option.")

btn.MouseButton1Click:Connect(function()
    print("===== КЛИК ПО КНОПКЕ =====")
    print(debug.traceback("Стек вызовов:"))
    print("===========================")
end)

-- Если события нет, пробуем альтернативу
if not btn:FindFirstChild("MouseButton1Click") then
    print("Событие MouseButton1Click отсутствует, пробуем Activated...")
    btn.Activated:Connect(function()
        print("===== КЛИК (Activated) =====")
        print(debug.traceback("Стек вызовов:"))
        print("============================")
    end)
end
