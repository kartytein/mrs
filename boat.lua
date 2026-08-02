-- =============================================================================
--  ТРЕКЕР ВЫЗОВОВ ФУНКЦИЙ ПРИ КЛИКЕ НА КНОПКУ (Option)
--  Вставьте в консоль Delta ПОСЛЕ загрузки HUB.
--  При клике на кнопку (вручную) скрипт выведет информацию о всех обработчиках.
--  Также попытается перехватить вызовы и показать, какие функции сработали.
-- =============================================================================

print("=== ТРЕКЕР КЛИКОВ НА КНОПКУ Option ===")

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
    print("[!] Кнопка Option не найдена по указанному пути.")
    return
end
print("[✓] Кнопка найдена: " .. btn:GetFullName())

-- Функция получения информации о функции
local function getFunctionInfo(func)
    if type(func) ~= "function" then return "Не функция" end
    local info = {}
    if debug and debug.getinfo then
        local di = debug.getinfo(func, "Slunf")
        if di then
            info.source = di.source or "?"
            info.linedefined = di.linedefined or "?"
            info.name = di.name or "?"
            info.short_src = di.short_src or "?"
        end
    end
    return info
end

-- Перехват вызовов через добавление слушателей на события кнопки
local events = {"MouseButton1Click", "Activated", "MouseButton1Down", "MouseButton1Up"}
local function setupEventTracker(btn)
    for _, evName in ipairs(events) do
        local signal = btn:FindFirstChild(evName)
        if signal and signal:IsA("RBXScriptSignal") then
            -- Получаем существующие подключения
            if getconnections then
                local conns = getconnections(signal)
                if #conns > 0 then
                    print("\n--- Событие " .. evName .. " — найдено привязок: " .. #conns)
                    for i, c in ipairs(conns) do
                        print("  Обработчик #" .. i)
                        if c.Function then
                            local info = getFunctionInfo(c.Function)
                            print("    Функция: " .. tostring(c.Function))
                            print("    Источник: " .. (info.source or "неизвестно"))
                            print("    Строка: " .. (info.linedefined or "неизвестно"))
                            print("    Имя: " .. (info.name or "неизвестно"))
                        end
                        if c.Script then
                            print("    Скрипт: " .. c.Script:GetFullName())
                        end
                    end
                else
                    print("  Событие " .. evName .. " не имеет привязок.")
                end
            else
                print("  getconnections недоступен, невозможно отследить обработчики.")
            end
        end
    end
end

-- Вывод информации о кнопке и её событиях
setupEventTracker(btn)

-- Дополнительно: попытаемся найти функцию, которая вызывается через глобальные переменные
print("\n--- Поиск глобальных переменных, связанных с Option ---")
local keywords = {"option", "toggle", "enable", "disable", "activate", "fly", "noclip", "god", "esp"}
local function searchGlobals(tbl, name)
    for k, v in pairs(tbl) do
        local key = tostring(k):lower()
        for _, kw in ipairs(keywords) do
            if key:find(kw, 1, true) then
                print("Найдена " .. name .. "." .. tostring(k) .. " = " .. tostring(v) .. " (тип: " .. type(v) .. ")")
                if type(v) == "function" then
                    local info = getFunctionInfo(v)
                    print("  Источник: " .. (info.source or "неизвестно"))
                    print("  Строка: " .. (info.linedefined or "неизвестно"))
                end
                break
            end
        end
    end
end

searchGlobals(_G, "_G")
if shared then searchGlobals(shared, "shared") end

-- Если есть возможность, добавляем временный обработчик для логирования кликов
print("\n--- Добавление временного обработчика для логирования кликов ---")
local function logClick()
    print(">>> КЛИК ПО КНОПКЕ ОБНАРУЖЕН! <<<")
    -- Повторно выведем информацию о привязках (они могли измениться)
    setupEventTracker(btn)
end

-- Подключаемся к событию кнопки (свой локальный обработчик)
local conn
if btn.MouseButton1Click then
    conn = btn.MouseButton1Click:Connect(logClick)
    print("[✓] Временный обработчик добавлен на MouseButton1Click.")
else
    print("[✗] Не удалось добавить обработчик (событие отсутствует).")
end

print("\n=== ТРЕКЕР ЗАПУЩЕН ===")
print("Теперь нажмите на кнопку Option вручную, и скрипт покажет, какие функции сработали.")
print("Для остановки трекера выполните: if conn then conn:Disconnect() end")

-- Сохраняем обработчик в глобальную переменную для возможности отключения
_G._tracker_connection = conn
