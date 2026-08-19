-- ============================================================
-- ПОСЛЕДОВАТЕЛЬНАЯ АКТИВАЦИЯ КНОПОК + ВЫВОД ТЕКСТОВ ТАЙЛОВ (только текст)
-- 1. Main.MenuButton
-- 2. Main.InventoryButton
-- 3. Inventory.Inventory.Main.NavigationRail.HoverBox.UpperBar.Category2
-- Затем ожидание 2 сек и сбор текстов из TileGrid (только первое название).
-- ============================================================

local player = game.Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Универсальная активация кнопки через getconnections
local function fireSequence(btn)
    if not (btn:IsA("TextButton") or btn:IsA("ImageButton")) then
        warn("Объект не является кнопкой: " .. btn.ClassName)
        return false
    end
    local signals = {"MouseEnter", "MouseButton1Down", "MouseButton1Click", "MouseButton1Up", "Activated", "MouseLeave"}
    for _, sigName in ipairs(signals) do
        local sig = btn[sigName]
        if sig then
            local ok, conns = pcall(function() return getconnections(sig) end)
            if ok and conns then
                for _, conn in ipairs(conns) do
                    if conn.Enabled and type(conn.Function) == "function" then
                        pcall(conn.Function)
                    end
                end
            end
        end
    end
    return true
end

-- Поиск объекта по пути
local function findObjectByPath(root, ...)
    local current = root
    for _, segment in ipairs({...}) do
        if not current then return nil end
        current = current:FindFirstChild(segment)
    end
    return current
end

-- Активация кнопки по пути
local function activateButtonByPath(pathSegments, description)
    local btn = findObjectByPath(playerGui, table.unpack(pathSegments))
    if not btn then
        warn("Кнопка не найдена: " .. description)
        return false
    end
    print("Активирую кнопку: " .. description)
    print("Путь: " .. btn:GetFullName())
    local ok = fireSequence(btn)
    if ok then
        print("Активация выполнена.")
    else
        warn("Не удалось активировать кнопку: " .. description)
    end
    return ok
end

-- 1. Main.MenuButton
local path1 = {"Main", "MenuButton"}
print("Шаг 1: Активация MenuButton...")
if not activateButtonByPath(path1, "Main.MenuButton") then return end

task.wait(2)

-- 2. Main.InventoryButton
local path2 = {"Main", "InventoryButton"}
print("Шаг 2: Активация InventoryButton...")
if not activateButtonByPath(path2, "Main.InventoryButton") then return end

task.wait(2)

-- 3. Category2
local path3 = {"Inventory", "Inventory", "Main", "NavigationRail", "HoverBox", "UpperBar", "Category2"}
print("Шаг 3: Активация Category2...")
if not activateButtonByPath(path3, "Inventory.Inventory.Main.NavigationRail.HoverBox.UpperBar.Category2") then return end

-- Ожидание загрузки контента
task.wait(2)

-- ===== СБОР ТЕКСТОВ ИЗ TILEGRID =====
local function collectTileTexts()
    local tileGrid = findObjectByPath(playerGui, "Inventory", "Inventory", "Main", "PageContent", "TileGrid")
    if not tileGrid then
        warn("TileGrid не найден")
        return {}
    end

    local tiles = {}
    for _, child in ipairs(tileGrid:GetChildren()) do
        -- Ищем тайлы по имени, начинающемуся с "Tile-"
        if child:IsA("ImageButton") and child.Name:sub(1,5) == "Tile-" then
            local line1 = nil
            -- Ищем Details.Line-1 внутри тайла
            local details = child:FindFirstChild("Details")
            if details then
                line1 = details:FindFirstChild("Line-1")
            end
            -- Если Line-1 не найден, пробуем найти любой TextLabel с текстом
            if not line1 then
                for _, obj in ipairs(child:GetDescendants()) do
                    if obj:IsA("TextLabel") then
                        line1 = obj
                        break
                    end
                end
            end

            local text = ""
            if line1 and line1:IsA("TextLabel") then
                text = line1.Text
            end

            -- Убираем часть после запятой (например "Sand, Blox Fruit" -> "Sand")
            local cleanText = text
            if cleanText and cleanText:find(",") then
                cleanText = cleanText:sub(1, cleanText:find(",") - 1)
            end
            cleanText = cleanText or ""
            cleanText = cleanText:gsub("%s+$", "") -- убираем пробелы в конце

            -- Извлекаем номер тайла для сортировки
            local tileNumber = tonumber(child.Name:sub(6)) -- после "Tile-"
            table.insert(tiles, {
                Name = child.Name,
                Number = tileNumber or 0,
                Text = cleanText
            })
        end
    end

    -- Сортируем по номеру тайла
    table.sort(tiles, function(a, b) return a.Number < b.Number end)

    return tiles
end

local tiles = collectTileTexts()

-- Выводим только текст (первое название)
print("\n=== ТЕКСТЫ ТАЙЛОВ ===")
for _, tile in ipairs(tiles) do
    print(tile.Text)
end

print("Готово.")
