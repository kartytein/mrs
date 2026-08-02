-- =====================================================================
--  ТРЕКЕР КЛИКОВ ПО КНОПКЕ OPTION (на основе позиции мыши)
--  Не использует события кнопки, работает через UserInputService.
--  При клике левой кнопкой мыши проверяет, попадает ли курсор в область кнопки.
--  Если да – выводит стек вызовов и информацию.
-- =====================================================================

print("=== ТРЕКЕР КЛИКОВ ПО ПОЗИЦИИ МЫШИ (для Option) ===")

local path = "CoreGui.5254c01c4691269e68d25763275f564b3f6d90d88346ad2f0bba357e7d8c00c1.redz-library-v5.Window.Components.Containers.Container.Option"

local function getByPath(p)
    local parts = {}
    for part in string.gmatch(p, "[^%.]+") do table.insert(parts, part) end
    local current = game:GetService(parts[1])
    for i = 2, #parts do
        current = current:FindFirstChild(parts[i])
        if not current then return nil end
    end
    return current
end

local target = getByPath(path)
if not target then
    print("[✗] Объект Option не найден.")
    return
end

print("[✓] Найден объект: " .. target:GetFullName() .. " (класс: " .. target.ClassName .. ")")

-- Функция проверки попадания точки в область объекта
local function isPointInsideGuiObject(obj, x, y)
    if not obj or not obj.Visible then return false end
    local absPos = obj.AbsolutePosition
    local absSize = obj.AbsoluteSize
    if not absPos or not absSize then return false end
    return x >= absPos.X and x <= absPos.X + absSize.X and
           y >= absPos.Y and y <= absPos.Y + absSize.Y
end

local input = game:GetService("UserInputService")
local connection

connection = input.InputBegan:Connect(function(inputObj, gameProcessed)
    if gameProcessed then return end
    if inputObj.UserInputType == Enum.UserInputType.MouseButton1 then
        -- Получаем позицию мыши
        local mousePos = input:GetMouseLocation()
        local x, y = mousePos.X, mousePos.Y

        -- Проверяем все дочерние объекты (включая вложенные)
        local function checkChildren(parent)
            for _, child in ipairs(parent:GetChildren()) do
                if child:IsA("GuiObject") and child.Visible then
                    if isPointInsideGuiObject(child, x, y) then
                        -- Попали внутрь дочернего объекта
                        print("===== КЛИК НА " .. child:GetFullName() .. " =====")
                        print(debug.traceback("Стек вызовов:"))
                        print("=============================================")
                        return true
                    end
                end
                -- рекурсивно проверяем вложенные
                local found = checkChildren(child)
                if found then return true end
            end
            return false
        end

        -- Сначала проверяем сам целевой объект
        if isPointInsideGuiObject(target, x, y) then
            print("===== КЛИК НА " .. target:GetFullName() .. " =====")
            print(debug.traceback("Стек вызовов:"))
            print("=============================================")
        else
            -- Проверяем дочерние объекты
            checkChildren(target)
        end
    end
end)

print("[✓] Трекер запущен. Теперь кликните по кнопке Option (или её дочерним элементам).")
print("    При клике в консоль будет выведен стек вызовов.")
print("    Для остановки выполните: connection:Disconnect()")

-- Сохраняем подключение в глобальную переменную для отключения
_G._tracker_connection = connection
