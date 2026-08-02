-- =============================================================================
--  ДАМП ВСЕХ ФУНКЦИЙ В ФАЙЛ (полный сбор)
--  Вставьте в консоль Delta ПОСЛЕ загрузки HUB.
--  Будет создан файл "functions_full_dump.txt" со всеми найденными функциями.
-- =============================================================================

print("=== НАЧАЛО СБОРА ФУНКЦИЙ ===")

local allFunctions = {}
local function addFunction(name, func)
    table.insert(allFunctions, {name = name, func = func})
end

-- 1. _G
if _G then
    for k, v in pairs(_G) do
        if type(v) == "function" then
            addFunction("_G." .. tostring(k), v)
        end
    end
end

-- 2. shared
if shared then
    for k, v in pairs(shared) do
        if type(v) == "function" then
            addFunction("shared." .. tostring(k), v)
        end
    end
end

-- 3. getreg()
if getreg then
    local reg = getreg()
    if type(reg) == "table" then
        for i, v in ipairs(reg) do
            if type(v) == "function" then
                addFunction("reg[" .. i .. "]", v)
            end
        end
    end
end

-- 4. getgc() (первые 1000 объектов)
if getgc then
    local gc = getgc()
    local count = 0
    for i, obj in ipairs(gc) do
        if count > 1000 then break end
        if type(obj) == "function" then
            addFunction("gc[" .. i .. "]", obj)
            count = count + 1
        end
    end
end

-- 5. getrenv()
if getrenv then
    local renv = getrenv()
    if type(renv) == "table" then
        for k, v in pairs(renv) do
            if type(v) == "function" then
                addFunction("renv." .. tostring(k), v)
            end
        end
    end
end

-- 6. debug.getregistry() (если доступно)
if debug and debug.getregistry then
    local reg = debug.getregistry()
    if type(reg) == "table" then
        for k, v in pairs(reg) do
            if type(v) == "function" then
                addFunction("debug_registry." .. tostring(k), v)
            end
        end
    end
end

print("Собрано функций: " .. #allFunctions)

-- Формируем содержимое файла
local fileContent = "===== ПОЛНЫЙ ДАМП ФУНКЦИЙ =====\n"
fileContent = fileContent .. "Всего функций: " .. #allFunctions .. "\n\n"

for i, item in ipairs(allFunctions) do
    fileContent = fileContent .. "[" .. i .. "] " .. item.name .. "\n"
    fileContent = fileContent .. "    Тип: function\n"
    fileContent = fileContent .. "    Адрес: " .. tostring(item.func) .. "\n\n"
end

-- Сохраняем в файл
if writefile then
    local fileName = "functions_full_dump.txt"
    writefile(fileName, fileContent)
    print("Файл сохранён: " .. fileName)
    print("Путь: " .. (getcwd and getcwd() or "рабочая папка Delta"))
else
    print("writefile недоступен. Вывод в консоль (первые 100 записей):")
    for i = 1, math.min(100, #allFunctions) do
        print("[" .. i .. "] " .. allFunctions[i].name)
    end
end

print("=== ДАМП ЗАВЕРШЁН ===")
