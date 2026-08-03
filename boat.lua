-- ============================================================================
--  РАСШИРЕННАЯ ДИАГНОСТИКА КЛИКА (ЛОВИМ ВСЁ)
--  Перехватывает InputBegan, все события кнопки, изменения свойств, 
--  удалённые вызовы в течение 2 секунд после клика.
--  Работает в Delta, только строки.
-- ============================================================================

local UIS = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")
local Players = game:GetService("Players")
local player = Players.LocalPlayer
local playerGui = player and player:FindFirstChild("PlayerGui")
local RunService = game:GetService("RunService")

-- Флаг клика и время
local clickActive = false
local lastClickTime = 0
local CLICK_WINDOW = 2.0 -- расширенное окно

-- Последняя нажатая кнопка (для связи событий с ней)
local lastClickedButton = nil

-- ===== УНИВЕРСАЛЬНЫЙ ПЕРЕХВАТ УДАЛЁННЫХ ВЫЗОВОВ =====
local function formatArgs(...)
    local args = {...}
    local parts = {}
    for i, v in ipairs(args) do
        if type(v) == "string" then
            table.insert(parts, '"' .. v .. '"')
        elseif type(v) == "table" then
            table.insert(parts, "{...}")
        else
            table.insert(parts, tostring(v))
        end
    end
    return table.concat(parts, ", ")
end

-- Перехват FireServer
local oldFireServer
oldFireServer = hookfunction(Instance.new("RemoteEvent").FireServer, function(self, ...)
    local args = {...}
    local now = tick()
    if clickActive and (now - lastClickTime) < CLICK_WINDOW then
        print(">>> [СВЯЗАНО С КЛИКОМ] RemoteEvent:FireServer")
        print("    Объект: " .. self:GetFullName())
        print("    Аргументы: " .. formatArgs(...))
        print("    Команда эмуляции: fireserver(" .. self:GetFullName() .. ", " .. formatArgs(...) .. ")")
    end
    return oldFireServer(self, ...)
end)

-- Перехват InvokeServer
local oldInvokeServer
pcall(function()
    oldInvokeServer = hookfunction(Instance.new("RemoteFunction").InvokeServer, function(self, ...)
        local now = tick()
        if clickActive and (now - lastClickTime) < CLICK_WINDOW then
            print(">>> [СВЯЗАНО С КЛИКОМ] RemoteFunction:InvokeServer")
            print("    Объект: " .. self:GetFullName())
            print("    Аргументы: " .. formatArgs(...))
            print("    Команда эмуляции: invokeserver(" .. self:GetFullName() .. ", " .. formatArgs(...) .. ")")
        end
        return oldInvokeServer(self, ...)
    end)
end)

-- Перехват BindableEvent:Fire
local oldFire
oldFire = hookfunction(Instance.new("BindableEvent").Fire, function(self, ...)
    local now = tick()
    if clickActive and (now - lastClickTime) < CLICK_WINDOW then
        print(">>> [СВЯЗАНО С КЛИКОМ] BindableEvent:Fire")
        print("    Объект: " .. self:GetFullName())
        print("    Аргументы: " .. formatArgs(...))
        -- команда: firesignal(путь.Event, аргументы)
        print("    Команда эмуляции: firesignal(" .. self:GetFullName() .. ".Event, " .. formatArgs(...) .. ")")
    end
    return oldFire(self, ...)
end)

-- Перехват BindableFunction:Invoke
local oldInvoke
pcall(function()
    oldInvoke = hookfunction(Instance.new("BindableFunction").Invoke, function(self, ...)
        local now = tick()
        if clickActive and (now - lastClickTime) < CLICK_WINDOW then
            print(">>> [СВЯЗАНО С КЛИКОМ] BindableFunction:Invoke")
            print("    Объект: " .. self:GetFullName())
            print("    Аргументы: " .. formatArgs(...))
        end
        return oldInvoke(self, ...)
    end)
end)

-- Перехват InputBegan (ловим клики/тапы)
local inputCon = nil
inputCon = UIS.InputBegan:Connect(function(input, gameProcessed)
    if not clickActive then return end
    local now = tick()
    if (now - lastClickTime) < CLICK_WINDOW then
        local inputType = input.UserInputType
        local pos = input.Position
        print(">>> [СВЯЗАНО С КЛИКОМ] InputBegan: " .. tostring(inputType) .. " в позиции " .. tostring(pos))
        if lastClickedButton then
            print("    Позиция кнопки: " .. tostring(lastClickedButton.AbsolutePosition) .. ", размер: " .. tostring(lastClickedButton.AbsoluteSize))
        end
    end
end)

-- ===== СЛУШАЕМ СОБЫТИЯ КНОПКИ И ОТЛАВЛИВАЕМ ИЗМЕНЕНИЯ =====
local function monitorButton(btn)
    if btn:GetAttribute("_advDiagHooked") then return end
    btn:SetAttribute("_advDiagHooked", true)
    
    -- Стандартные события мыши
    btn.MouseButton1Click:Connect(function()
        clickActive = true
        lastClickTime = tick()
        lastClickedButton = btn
        
        print("=== КЛИК ПО КНОПКЕ ===")
        print("Имя: " .. btn.Name)
        print("Класс: " .. btn.ClassName)
        print("Путь: " .. btn:GetFullName())
        print("Текст: " .. (btn:IsA("TextButton") and btn.Text or "—"))
        print("Атрибуты: " .. (function() local a=""; for k,v in pairs(btn:GetAttributes()) do a=a..k.."="..tostring(v).."; "; end; return a~="" and a or "нет"; end)())
        
        -- Запускаем таймер сброса
        delay(CLICK_WINDOW + 0.1, function()
            if clickActive and (tick() - lastClickTime) >= CLICK_WINDOW then
                print("--- Окно поиска истекло, ничего не поймано ---")
                clickActive = false
            end
        end)
    end)
    
    btn.MouseButton1Down:Connect(function()
        if clickActive and (tick() - lastClickTime) < CLICK_WINDOW then
            print(">>> MouseButton1Down")
        end
    end)
    btn.MouseButton1Up:Connect(function()
        if clickActive and (tick() - lastClickTime) < CLICK_WINDOW then
            print(">>> MouseButton1Up")
        end
    end)
    btn.Activated:Connect(function()
        if clickActive and (tick() - lastClickTime) < CLICK_WINDOW then
            print(">>> Activated")
        end
    end)
    btn.TouchTap:Connect(function()
        if clickActive and (tick() - lastClickTime) < CLICK_WINDOW then
            print(">>> TouchTap (мобильное нажатие)")
        end
    end)
    
    -- Отслеживание изменений свойств, которые могут запускать логику
    -- (например, изменение Visible, Text, или кастомного атрибута)
    local function onPropertyChanged(prop)
        if clickActive and (tick() - lastClickTime) < CLICK_WINDOW then
            local val = btn[prop]
            print(">>> Изменение свойства [" .. prop .. "] = " .. tostring(val) .. " (было изменено после клика)")
        end
    end
    btn.Changed:Connect(onPropertyChanged)
    btn.AttributeChanged:Connect(function(attr)
        if clickActive and (tick() - lastClickTime) < CLICK_WINDOW then
            print(">>> Изменение атрибута [" .. attr .. "] = " .. tostring(btn:GetAttribute(attr)))
        end
    end)
    
    -- Также отслеживаем изменение свойств родительских фреймов (вдруг родитель управляется)
    local parent = btn.Parent
    if parent and parent:IsA("GuiObject") then
        parent.Changed:Connect(function(prop)
            if clickActive and (tick() - lastClickTime) < CLICK_WINDOW then
                print(">>> Изменение у родителя (" .. parent:GetFullName() .. ") свойство [" .. prop .. "] = " .. tostring(parent[prop]))
            end
        end)
    end
end

-- Рекурсивное сканирование
local function scanRecursive(parent)
    for _, child in ipairs(parent:GetChildren()) do
        if child:IsA("TextButton") or child:IsA("ImageButton") then
            monitorButton(child)
        end
        scanRecursive(child)
    end
end

-- Запуск
local targets = {}
if CoreGui then table.insert(targets, CoreGui) end
if playerGui then table.insert(targets, playerGui) end

for _, target in ipairs(targets) do
    if target then
        scanRecursive(target)
        target.DescendantAdded:Connect(function(desc)
            if desc:IsA("TextButton") or desc:IsA("ImageButton") then
                monitorButton(desc)
            end
        end)
    end
end

print("Расширенная диагностика активирована.")
print("Нажмите кнопку, затем смотрите все помеченные [СВЯЗАНО С КЛИКОМ] события в течение 2 секунд.")
