-- =============================================================================
--  ПОДРОБНЫЙ ДАМП ФУНКЦИЙ (с защитой от ошибок и паузами)
--  Вставьте в консоль Delta ПОСЛЕ загрузки HUB.
--  Файл: functions_detailed_dump.txt
-- =============================================================================

print("=== ПОДРОБНЫЙ ДАМП ФУНКЦИЙ (без ограничений, но с паузами) ===")

local allData = {}  -- массив строк для вывода
local function addLine(line)
    table.insert(allData, line)
end

-- Функция получения подробной информации о функции (безопасно)
local function getFunctionInfo(func, nameHint)
    local info = {}
    -- Пытаемся получить debug.getinfo
    if debug and debug.getinfo then
        local ok, di = pcall(debug.getinfo, func)
        if ok and di then
            info.name = di.name or ""
            info.namewhat = di.namewhat or ""
            info.source = di.source or ""
            info.linedefined = di.linedefined or 0
            info.lastlinedefined = di.lastlinedefined or 0
            info.nparams = di.nparams or 0
            info.isvararg = di.isvararg or false
        end
    end
    if not info.name or info.name == "" then
        info.name = nameHint or "unknown"
    end
    -- Получаем upvalues (безопасно)
    local upvalues = {}
    if debug and debug.getupvalue then
        local i = 1
        while true do
            local ok, name, value = pcall(debug.getupvalue, func, i)
            if not ok or not name then break end
            table.insert(upvalues, {name = name, value = tostring(value), type = type(value)})
            i = i + 1
        end
    end
    info.upvalues = upvalues
    return info
end

-- Сбор функций из таблицы (только прямой обход, без рекурсии вглубь)
local function collectFromTable(tbl, prefix)
    if type(tbl) ~= "table" then return end
    for k, v in pairs(tbl) do
        if type(v) == "function" then
            local hint = prefix .. "." .. tostring(k)
            local info = getFunctionInfo(v, hint)
            addLine("=== ФУНКЦИЯ ===")
            addLine("Путь: " .. hint)
            if info.name and info.name ~= "" and info.name ~= hint then
                addLine("Имя (debug): " .. info.name)
            end
            addLine("Источник: " .. (info.source or "неизвестно"))
            addLine("Строки определения: " .. info.linedefined .. " - " .. info.lastlinedefined)
            addLine("Кол-во параметров: " .. info.nparams)
            addLine("Vararg: " .. tostring(info.isvararg))
            if #info.upvalues > 0 then
                addLine("Upvalues (" .. #info.upvalues .. "):")
                for _, uv in ipairs(info.upvalues) do
                    addLine("  " .. uv.name .. " = " .. uv.value .. " (" .. uv.type .. ")")
                end
            else
                addLine("Upvalues: нет")
            end
            addLine("Адрес: " .. tostring(v))
            addLine("")
        end
    end
end

-- Источники для сбора (только прямые таблицы, без рекурсии)
local sources = {
    {tbl = _G, name = "_G"},
    {tbl = shared, name = "shared"},
    {tbl = getreg and getreg(), name = "getreg"},
    {tbl = getrenv and getrenv(), name = "getrenv"},
    {tbl = debug and debug.getregistry and debug.getregistry(), name = "debug_registry"},
}

-- Собираем из каждого источника
for _, src in ipairs(sources) do
    if src.tbl and type(src.tbl) == "table" then
        print("Сканируем: " .. src.name)
        collectFromTable(src.tbl, src.name)
        wait(0.5)  -- пауза между источниками
    end
end

-- Также собираем из getgc (все функции в памяти) – но с паузами и без обработки upvalues
if getgc then
    print("Сканируем getgc (это может занять время)...")
    local gc = getgc()
    local count = 0
    for i, obj in ipairs(gc) do
        if type(obj) == "function" then
            -- Для gc не используем полную информацию, чтобы не перегружать
            local info = getFunctionInfo(obj, "gc[" .. i .. "]")
            addLine("=== ФУНКЦИЯ ===")
            addLine("Путь: gc[" .. i .. "]")
            if info.name and info.name ~= "" then
                addLine("Имя (debug): " .. info.name)
            end
            addLine("Источник: " .. (info.source or "неизвестно"))
            addLine("Строки определения: " .. info.linedefined .. " - " .. info.lastlinedefined)
            addLine("Кол-во параметров: " .. info.nparams)
            addLine("Vararg: " .. tostring(info.isvararg))
            addLine("Upvalues: " .. #info.upvalues .. " (не отображаем для экономии)")
            addLine("Адрес: " .. tostring(obj))
            addLine("")
            count = count + 1
            if count % 50 == 0 then wait(0.1) end
        end
        if i % 1000 == 0 then wait(0.1) end
    end
    print("Собрано из gc: " .. count)
end

print("Собрано записей: " .. #allData)

-- Сохраняем в файл
if writefile then
    local fileName = "functions_detailed_dump.txt"
    local content = table.concat(allData, "\n")
    writefile(fileName, content)
    print("Файл сохранён: " .. fileName)
    print("Размер файла: " .. #content .. " байт")
else
    print("writefile недоступен. Вывожу первые 50 строк в консоль:")
    for i = 1, math.min(50, #allData) do
        print(allData[i])
    end
end

print("=== ДАМП ЗАВЕРШЁН ===")
