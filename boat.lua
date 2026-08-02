-- =====================================================================
--  ПОЛУЧЕНИЕ ОБРАБОТЧИКА КНОПКИ Option И ПРЯМОЙ ВЫЗОВ
-- =====================================================================

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

local btn = getObjectByPath(path)
if not btn then
    print("Кнопка не найдена.")
    return
end

print("=== АНАЛИЗ КНОПКИ ===")
print("Путь:", btn:GetFullName())
print("Класс:", btn.ClassName)

-- Проверяем, есть ли событие MouseButton1Click и привязки
if not getconnections then
    print("Функция getconnections не доступна. Попробуйте другой метод.")
    return
end

local clickEvent = btn:FindFirstChild("MouseButton1Click")
if not clickEvent or not clickEvent:IsA("RBXScriptSignal") then
    print("Событие MouseButton1Click не найдено.")
    return
end

local connections = getconnections(clickEvent)
if #connections == 0 then
    print("Нет привязок к MouseButton1Click.")
else
    print("Найдено", #connections, "привязок.")
    for i, conn in ipairs(connections) do
        print("\n--- Привязка", i, "---")
        local func = conn.Function
        if func then
            print("Тип функции:", type(func))
            -- Получаем информацию о функции (имя, строка, файл)
            local info = debug.getinfo(func)
            if info then
                print("Имя функции:", info.name or "(анонимная)")
                print("Источник:", info.short_src or "неизвестно")
                print("Строка:", info.linedefined or "?")
            end
            -- Извлекаем upvalues
            local upvalues = debug.getupvalues(func)
            if #upvalues > 0 then
                print("Upvalues (" .. #upvalues .. "):")
                for j, uv in ipairs(upvalues) do
                    print("  [" .. j .. "] =", tostring(uv))
                    -- Если upvalue - это функция или таблица с нужной нам функцией, пробуем вызвать
                    if type(uv) == "function" then
                        print("    Попытка вызвать upvalue как функцию...")
                        pcall(function() uv() end)
                        pcall(function() uv(true) end)
                        pcall(function() uv("FlyBoat") end)
                    elseif type(uv) == "table" then
                        for k, v in pairs(uv) do
                            if type(k) == "string" and (string.find(k:lower(), "fly") or string.find(k:lower(), "boat")) then
                                print("    В таблице найден ключ:", k, "=>", tostring(v))
                                if type(v) == "function" then
                                    print("      Вызов функции", k, "...")
                                    pcall(function() v() end)
                                    pcall(function() v(true) end)
                                    pcall(function() v("FlyBoat") end)
                                end
                            end
                        end
                    end
                end
            else
                print("Нет upvalues.")
            end
            -- Пытаемся вызвать саму функцию-обработчик с разными аргументами
            print("Попытка прямого вызова обработчика...")
            pcall(function() func() end)
            pcall(function() func(true) end)
            pcall(function() func(false) end)
            pcall(function() func({}) end)
            pcall(function() func(btn) end)
            -- Если обработчик ожидает объект события, передадим заглушку
            local fakeEvent = { x = 0, y = 0, Position = Vector2.new(0,0) }
            pcall(function() func(fakeEvent) end)
        else
            print("Функция не найдена.")
        end
        -- Если есть скрипт, в котором определена функция, попробуем получить его окружение
        if conn.Script then
            print("Скрипт:", conn.Script:GetFullName())
            local env = getfenv(conn.Script)
            if env then
                print("Окружение скрипта содержит:")
                for k, v in pairs(env) do
                    if type(k) == "string" and (string.find(k:lower(), "fly") or string.find(k:lower(), "boat")) then
                        print("  " .. k .. " =", tostring(v))
                        if type(v) == "function" then
                            print("    Вызов функции", k, "...")
                            pcall(function() v() end)
                            pcall(function() v(true) end)
                        end
                    end
                end
            end
        end
    end
end

print("\n=== ЗАВЕРШЕНО ===")
print("Если функция не найдена, попробуйте метод анализа стека при реальном клике.")
