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

print("=== ПОИСК ОБРАБОТЧИКОВ НА FRAME ===")
local events = {"MouseButton1Click", "MouseButton1Down", "MouseButton1Up", "Activated"}
local found = false

if getconnections then
    for _, evName in ipairs(events) do
        local ev = frame:FindFirstChild(evName)
        if ev and ev:IsA("RBXScriptSignal") then
            local conns = getconnections(ev)
            if #conns > 0 then
                found = true
                print("Найдено", #conns, "привязок к", evName)
                for i, conn in ipairs(conns) do
                    print("  Привязка", i)
                    if conn.Function then
                        print("    Функция:", tostring(conn.Function))
                        -- Попытка вызвать функцию напрямую
                        pcall(function() conn.Function() end)
                        pcall(function() conn.Function(true) end)
                        pcall(function() conn.Function(false) end)
                    end
                    if conn.Script then
                        print("    Скрипт:", conn.Script:GetFullName())
                    end
                end
            end
        end
    end

    -- Проверим родителя (Container)
    local parent = frame.Parent
    if parent then
        print("\n=== ПОИСК НА РОДИТЕЛЕ:", parent:GetFullName(), "===")
        for _, evName in ipairs(events) do
            local ev = parent:FindFirstChild(evName)
            if ev and ev:IsA("RBXScriptSignal") then
                local conns = getconnections(ev)
                if #conns > 0 then
                    found = true
                    print("Найдено", #conns, "привязок к", evName, "на родителе")
                    for i, conn in ipairs(conns) do
                        print("  Привязка", i)
                        if conn.Function then
                            print("    Функция:", tostring(conn.Function))
                            pcall(function() conn.Function() end)
                            pcall(function() conn.Function(true) end)
                        end
                        if conn.Script then
                            print("    Скрипт:", conn.Script:GetFullName())
                        end
                    end
                end
            end
        end
    end

    if not found then
        print("Обработчиков не найдено ни на Frame, ни на родителе.")
    end
else
    print("getconnections не доступен.")
end

print("\n=== ЗАВЕРШЕНО ===")
