-- ============================================================================
--  ПРЯМОЙ ВЫЗОВ ОБРАБОТЧИКОВ КЛИКА ЧЕРЕЗ getconnections
--  Этот скрипт находит указанную кнопку, считывает все подключённые функции
--  к событиям Activated и MouseButton1Click, выводит их и вызывает первую
--  активную. Эмулирует нажатие без необходимости firesignal.
--  Вставьте в консоль Delta.
-- ============================================================================

-- Путь к кнопке (скопируйте из вывода предыдущей диагностики)
local buttonPath = "CoreGui.5254c01c4691269e68d25763275f564b3f6d90d88346ad2f0bba357e7d8c00c1.redz-library-v5.Window.Components.Containers.Container.Option"

local button = nil
pcall(function()
    button = game:GetObjects(buttonPath)[1]
end)
if not button then
    -- Прямой путь (на случай, если GetObjects не подходит)
    local parts = {}
    for part in buttonPath:gmatch("[^%.]+") do
        table.insert(parts, part)
    end
    local obj = game
    for _, name in ipairs(parts) do
        obj = obj:FindFirstChild(name)
        if not obj then break end
    end
    button = obj
end

if not button or not button:IsA("GuiButton") then
    print("Кнопка не найдена. Проверьте путь.")
    return
end

print("Кнопка найдена: " .. button:GetFullName())

-- Функция для работы с getconnections (если доступна)
local function tryFireConnections(signal)
    local conns
    local success, err = pcall(function()
        conns = getconnections(signal)
    end)
    if not success then
        print("getconnections недоступен для " .. tostring(signal) .. ": " .. tostring(err))
        return false
    end
    print("Найдено " .. #conns .. " подключений к " .. tostring(signal))
    for i, conn in ipairs(conns) do
        local status = conn.Enabled and "АКТИВНО" or "ОТКЛЮЧЕНО"
        local fn = conn.Function
        local info = "неизвестно"
        pcall(function()
            local di = debug.getinfo(fn, "Sl")
            if di then
                info = (di.name or "<anonymous>") .. " в " .. (di.short_src or "?") .. ":" .. (di.linedefined or "?")
            end
        end)
        print("  [" .. i .. "] " .. status .. " | Функция: " .. info)
        
        if conn.Enabled and fn then
            print("  -> Вызываю эту функцию...")
            local callSuccess, callErr = pcall(fn)
            if callSuccess then
                print("  -> Функция выполнена успешно.")
            else
                print("  -> Ошибка при вызове: " .. tostring(callErr))
            end
            return true -- достаточно одного вызова
        end
    end
    return false
end

-- Пробуем Activated
print("\n--- Проверка Activated ---")
local fired = tryFireConnections(button.Activated)

-- Пробуем MouseButton1Click, если Activated не дал результата
if not fired then
    print("\n--- Проверка MouseButton1Click ---")
    fired = tryFireConnections(button.MouseButton1Click)
end

if not fired then
    print("\nНе удалось найти активные функции для вызова.")
    print("Возможно, обработчик находится внутри другого скрипта (LocalScript),")
    print("который подключается иначе. Попробуйте найти его вручную в CoreGui.")
end
