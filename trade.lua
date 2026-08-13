local player = game.Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Путь к кнопке от PlayerGui
local path = {"Main", "Trade", "Container", "FrameAdd", "Frame", "1404"}

-- Поиск объекта
local current = playerGui
for _, segment in ipairs(path) do
    current = current:FindFirstChild(segment)
    if not current then
        warn("Не найден сегмент: " .. segment)
        return
    end
end

local btn = current
print("Кнопка найдена: " .. btn:GetFullName())
print("Класс: " .. btn.ClassName)

-- ===== Метод 1: Вызов сигналов через getconnections =====
local function tryFireSequence()
    local results = {}
    local signals = {"MouseEnter","MouseButton1Down","MouseButton1Click","MouseButton1Up","Activated","MouseLeave"}
    for _, sigName in ipairs(signals) do
        local success, err = pcall(function()
            local sig = btn[sigName]
            if sig then
                local conns = getconnections(sig)
                if conns and #conns > 0 then
                    for _, conn in ipairs(conns) do
                        if conn.Enabled and type(conn.Function) == "function" then
                            conn.Function()
                        end
                    end
                    return "OK (" .. #conns .. " connections)"
                else
                    return "NO_CONNECTIONS"
                end
            else
                return "NO_SIGNAL"
            end
        end)
        if success then
            results[sigName] = "SUCCESS: " .. tostring(err)
        else
            results[sigName] = "ERROR: " .. tostring(err)
        end
    end
    return results
end

print("Метод 1: getconnections")
local res1 = tryFireSequence()
for sig, res in pairs(res1) do
    print("  " .. sig .. " -> " .. res)
end
