-- =============================================================================
--  УПРОЩЁННЫЙ ДАМП ВСЕХ ФУНКЦИЙ (без вызова debug.getupvalues)
--  Вставьте в консоль Delta ПОСЛЕ загрузки HUB.
--  Будет создан файл "functions_dump_safe.txt" со списком функций.
--  Все опасные операции обёрнуты в pcall.
-- =============================================================================

print("=== БЕЗОПАСНЫЙ СБОР ФУНКЦИЙ (с паузами) ===")

local allFunctions = {}
local MAX = 5000 -- лимит, чтобы не перегрузить память

-- Функция добавления с проверкой лимита
local function addFunc(name, func)
    if #allFunctions >= MAX then return false end
    table.insert(allFunctions, {name = name, func = func})
    return true
end

-- Обработка таблицы: собираем функции (только прямой уровень)
local function collectFromTable(tbl, prefix, depth)
    depth = depth or 0
    if depth > 1 then return end -- только один уровень вложенности
    if type(tbl) ~= "table" then return end
    for k, v in pairs(tbl) do
        if #allFunctions >= MAX then break end
        if type(v) == "function" then
            local key = tostring(k)
            local fullName = prefix .. key
            addFunc(fullName, v)
        elseif type(v) == "table" and depth == 0 then
            -- Рекурсивно на один уровень глубже
            collectFromTable(v, prefix .. tostring(k) .. ".", depth + 1)
        end
    end
end

-- Этап 1: _G
print("Сбор _G...")
pcall(function()
    collectFromTable(_G, "_G.")
end)
wait(0.3)

-- Этап 2: shared
if shared then
    print("Сбор shared...")
    pcall(function()
        collectFromTable(shared, "shared.")
    end)
end
wait(0.3)

-- Этап 3: getreg()
if getreg then
    print("Сбор getreg...")
    pcall(function()
        local reg = getreg()
        if type(reg) == "table" then
            for i, v in ipairs(reg) do
                if #allFunctions >= MAX then break end
                if type(v) == "function" then
                    addFunc("reg[" .. i .. "]", v)
                end
            end
        end
    end)
end
wait(0.3)

-- Этап 4: getgc() – первые 500
if getgc then
    print("Сбор getgc (первые 500)...")
    pcall(function()
        local gc = getgc()
        local count = 0
        for i, obj in ipairs(gc) do
            if #allFunctions >= MAX then break end
            if count >= 500 then break end
            if type(obj) == "function" then
                addFunc("gc[" .. i .. "]", obj)
                count = count + 1
                if count % 50 == 0 then wait(0.1) end
            end
        end
    end)
end
wait(0.3)

-- Этап 5: getrenv()
if getrenv then
    print("Сбор getrenv...")
    pcall(function()
        local renv = getrenv()
        if type(renv) == "table" then
            collectFromTable(renv, "renv.")
        end
    end)
end
wait(0.3)

-- Этап 6: debug.getregistry()
if debug and debug.getregistry then
    print("Сбор debug.getregistry...")
    pcall(function()
        local reg = debug.getregistry()
        if type(reg) == "table" then
            collectFromTable(reg, "debug_registry.")
        end
    end)
end

print("Собрано функций: " .. #allFunctions)

-- Формируем содержимое файла
local fileContent = "===== ДАМП ФУНКЦИЙ (безопасный) =====\n"
fileContent = fileContent .. "Всего функций: " .. #allFunctions .. "\n\n"

for i, item in ipairs(allFunctions) do
    fileContent = fileContent .. "[" .. i .. "] " .. item.name .. "\n"
    fileContent = fileContent .. "    Адрес: " .. tostring(item.func) .. "\n\n"
end

-- Сохраняем в файл
local saved = false
if writefile then
    local success, err = pcall(function()
        writefile("functions_dump_safe.txt", fileContent)
        saved = true
        print("Файл 'functions_dump_safe.txt' сохранён.")
    end)
    if not success then
        print("Ошибка записи файла: " .. tostring(err))
    end
end

if not saved then
    print("writefile недоступен или ошибка. Вывод первых 200 функций в консоль:")
    for i = 1, math.min(200, #allFunctions) do
        print("[" .. i .. "] " .. allFunctions[i].name)
    end
end

print("=== ДАМП ЗАВЕРШЁН ===")
