-- =============================================================================
--  ДАМП ВСЕХ ФУНКЦИЙ В ФАЙЛ (С ЗАДЕРЖКАМИ, ЧТОБЫ НЕ КРАШИЛО)
--  Вставьте в консоль Delta ПОСЛЕ загрузки HUB.
--  Будет создан файл "functions_full_dump.txt".
--  Добавлены wait(0.5) между большими операциями для снижения нагрузки.
-- =============================================================================

print("=== НАЧАЛО СБОРА ФУНКЦИЙ (с паузами) ===")

local allFunctions = {}
local function addFunction(name, func)
    table.insert(allFunctions, {name = name, func = func})
end

-- Ограничение на количество собираемых функций (чтобы не переполнить память)
local MAX_FUNCTIONS = 2000
local function checkLimit()
    return #allFunctions < MAX_FUNCTIONS
end

-- 1. _G
print("Сбор _G...")
if _G then
    for k, v in pairs(_G) do
        if not checkLimit() then break end
        if type(v) == "function" then
            addFunction("_G." .. tostring(k), v)
        end
    end
end
wait(0.5)

-- 2. shared
print("Сбор shared...")
if shared then
    for k, v in pairs(shared) do
        if not checkLimit() then break end
        if type(v) == "function" then
            addFunction("shared." .. tostring(k), v)
        end
    end
end
wait(0.5)

-- 3. getreg()
print("Сбор getreg...")
if getreg then
    local reg = getreg()
    if type(reg) == "table" then
        for i, v in ipairs(reg) do
            if not checkLimit() then break end
            if type(v) == "function" then
                addFunction("reg[" .. i .. "]", v)
            end
        end
    end
end
wait(0.5)

-- 4. getgc() – собираем только первые 500, с паузой внутри
print("Сбор getgc (первые 500)...")
if getgc then
    local gc = getgc()
    local count = 0
    for i, obj in ipairs(gc) do
        if not checkLimit() then break end
        if count > 500 then break end
        if type(obj) == "function" then
            addFunction("gc[" .. i .. "]", obj)
            count = count + 1
            if count % 50 == 0 then wait(0.1) end -- пауза каждые 50 функций
        end
    end
end
wait(0.5)

-- 5. getrenv()
print("Сбор getrenv...")
if getrenv then
    local renv = getrenv()
    if type(renv) == "table" then
        for k, v in pairs(renv) do
            if not checkLimit() then break end
            if type(v) == "function" then
                addFunction("renv." .. tostring(k), v)
            end
        end
    end
end
wait(0.5)

-- 6. debug.getregistry()
print("Сбор debug.getregistry...")
if debug and debug.getregistry then
    local reg = debug.getregistry()
    if type(reg) == "table" then
        for k, v in pairs(reg) do
            if not checkLimit() then break end
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
