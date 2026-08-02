-- ============================================================================
--  ПОИСК И АКТИВАЦИЯ ФУНКЦИИ "FlyBoat" (несколько подходов)
--  Вставьте в консоль Delta после загрузки HUB.
--  Попробуйте каждый из методов по очереди.
-- ============================================================================

-- ======================================================================
--  МЕТОД 1: Поиск глобальной переменной или функции с именем "FlyBoat"
-- ======================================================================
print("=== МЕТОД 1: Поиск в _G и shared ===")
local function findGlobal(name)
    if _G[name] then
        print("Найдено в _G." .. name .. " = " .. tostring(_G[name]))
        return _G[name]
    end
    if shared and shared[name] then
        print("Найдено в shared." .. name .. " = " .. tostring(shared[name]))
        return shared[name]
    end
    -- Поиск по частичному совпадению
    for k, v in pairs(_G) do
        if type(k) == "string" and string.find(k:lower(), name:lower()) then
            print("Найдено частичное совпадение: _G." .. k .. " = " .. tostring(v))
            return v
        end
    end
    if shared then
        for k, v in pairs(shared) do
            if type(k) == "string" and string.find(k:lower(), name:lower()) then
                print("Найдено частичное совпадение: shared." .. k .. " = " .. tostring(v))
                return v
            end
        end
    end
    return nil
end

local flyFunc = findGlobal("FlyBoat")
if flyFunc then
    if type(flyFunc) == "function" then
        print("Попытка вызвать функцию...")
        pcall(function() flyFunc() end)
        pcall(function() flyFunc(true) end)
        pcall(function() flyFunc(false) end)
        pcall(function() flyFunc("FlyBoat") end)
    else
        print("Найдена переменная, но не функция: " .. type(flyFunc))
    end
else
    print("Функция FlyBoat не найдена в _G или shared.")
end

-- ======================================================================
--  МЕТОД 2: Поиск кнопки с текстом "FlyBoat" и клик по ней
-- ======================================================================
print("\n=== МЕТОД 2: Поиск кнопки с текстом FlyBoat ===")
local function findButtonByText(text)
    local function search(parent)
        if not parent then return nil end
        for _, child in ipairs(parent:GetChildren()) do
            if child:IsA("TextButton") and child.Text and child.Text:find(text, 1, true) then
                return child
            end
            if child:IsA("ImageButton") and child.Tooltip and child.Tooltip:find(text, 1, true) then
                return child
            end
            local found = search(child)
            if found then return found end
        end
        return nil
    end
    local sources = {
        game:GetService("CoreGui"),
        game:GetService("Players").LocalPlayer:FindFirstChild("PlayerGui")
    }
    for _, src in ipairs(sources) do
        if src then
            local btn = search(src)
            if btn then return btn end
        end
    end
    return nil
end

local flyBtn = findButtonByText("FlyBoat")
if flyBtn then
    print("Найдена кнопка: " .. flyBtn:GetFullName())
    print("Текст: " .. (flyBtn.Text or "") .. " Tooltip: " .. (flyBtn.Tooltip or ""))
    -- Пытаемся кликнуть
    local function safeClick(btn)
        if btn.Click then pcall(function() btn:Click() end) return end
        if btn.FireEvent then pcall(function() btn:FireEvent("MouseButton1Click") end) return end
        if btn.SendEvent then pcall(function() btn:SendEvent("MouseButton1Click") end) return end
        -- Эмуляция мыши
        local input = game:GetService("UserInputService")
        local pos = btn.AbsolutePosition + btn.AbsoluteSize / 2
        pcall(function()
            input:SetMousePosition(pos.X, pos.Y)
            input:FireEvent("MouseButton1Click")
        end)
    end
    safeClick(flyBtn)
    print("Кнопка активирована (попытка).")
else
    print("Кнопка с текстом FlyBoat не найдена.")
end

-- ======================================================================
--  МЕТОД 3: Извлечение обработчика клика с кнопки Option (если функция там)
-- ======================================================================
print("\n=== МЕТОД 3: Поиск обработчика на кнопке Option ===")
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

local btnOption = getObjectByPath(path)
if btnOption then
    print("Кнопка Option найдена. Проверяем привязки...")
    if getconnections then
        local events = {"MouseButton1Click", "Activated", "MouseButton1Down", "MouseButton1Up"}
        for _, evName in ipairs(events) do
            local ev = btnOption:FindFirstChild(evName)
            if ev and ev:IsA("RBXScriptSignal") then
                local conns = getconnections(ev)
                if #conns > 0 then
                    print("Найдено " .. #conns .. " привязок к " .. evName)
                    for i, c in ipairs(conns) do
                        if c.Function then
                            print("  Функция: " .. tostring(c.Function))
                            -- Попробуем получить upvalues
                            if debug and debug.getupvalues then
                                local ups = debug.getupvalues(c.Function)
                                print("    Upvalues (" .. #ups .. "):")
                                for j, uv in ipairs(ups) do
                                    print("      " .. j .. ": " .. tostring(uv))
                                end
                            end
                            -- Попытаемся вызвать функцию напрямую (с осторожностью)
                            pcall(function()
                                local result = c.Function()
                                print("    Вызов функции без аргументов -> " .. tostring(result))
                            end)
                            pcall(function()
                                local result = c.Function(true)
                                print("    Вызов с аргументом true -> " .. tostring(result))
                            end)
                        end
                        if c.Script then
                            print("    Исходный скрипт: " .. c.Script:GetFullName())
                        end
                    end
                end
            end
        end
    else
        print("getconnections недоступен.")
    end
else
    print("Кнопка Option не найдена.")
end

-- ======================================================================
--  МЕТОД 4: Поиск по всем скриптам на наличие строки "FlyBoat"
-- ======================================================================
print("\n=== МЕТОД 4: Поиск строки 'FlyBoat' в скриптах ===")
local function searchScripts(container)
    if not container then return end
    for _, child in ipairs(container:GetChildren()) do
        if child:IsA("Script") or child:IsA("LocalScript") or child:IsA("ModuleScript") then
            -- Проверяем исходный код (если доступен)
            local source = child:IsA("Script") and child.Source or (child:IsA("LocalScript") and child.Source) or nil
            if source and string.find(source, "FlyBoat") then
                print("Найдено упоминание 'FlyBoat' в скрипте: " .. child:GetFullName())
                -- Попробуем найти функцию в окружении скрипта
                if child:IsA("Script") and child.Environment then
                    local env = child.Environment
                    for k, v in pairs(env) do
                        if type(k) == "string" and string.find(k:lower(), "flyboat") then
                            print("  В окружении скрипта: " .. k .. " = " .. tostring(v))
                        end
                    end
                end
            end
        end
        searchScripts(child) -- рекурсия
    end
end

searchScripts(game:GetService("CoreGui"))
searchScripts(game:GetService("Players").LocalPlayer:FindFirstChild("PlayerGui"))

print("\n=== ЗАВЕРШЕНО ===")
print("Если ни один метод не сработал, скорее всего функция FlyBoat вызывается через другой триггер (например, через RemoteEvent).")
print("Попробуйте найти RemoteEvent с именем 'FlyBoat' или похожим и вызвать его через FireServer.")
