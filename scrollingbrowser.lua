-- ============================================================
-- ПЛАВНАЯ ПРОКРУТКА СПИСКА СЕРВЕРОВ (Vector2 для CanvasPosition)
-- ============================================================

local Players = game:GetService("Players")
local player = Players.LocalPlayer
local playerGui = player:FindFirstChild("PlayerGui")

if not playerGui then return print("PlayerGui не найден") end

local serverBrowser = playerGui:FindFirstChild("ServerBrowser")
if not serverBrowser then return print("ServerBrowser не найден") end
local frame = serverBrowser:FindFirstChild("Frame")
if not frame then return print("Frame не найден") end
local sf = frame:FindFirstChild("ScrollingFrame")
if not sf then return print("ScrollingFrame не найден") end

print("ScrollingFrame найден: " .. sf:GetFullName())

-- Параметры прокрутки
local STEP = 150
local DELAY = 0.03

-- Определяем максимальный Y из CanvasSize (UDim2)
local canvasSizeY = sf.CanvasSize.Y
local maxY = (typeof(canvasSizeY) == "UDim") and canvasSizeY.Offset or canvasSizeY

print("CanvasSize: " .. tostring(sf.CanvasSize))
print("Максимальный Y: " .. maxY)

-- Текущий Y из CanvasPosition (Vector2)
local currentY = sf.CanvasPosition.Y

if maxY <= currentY then
    print("Список уже в конце или пуст.")
    return
end

print("Начинаем плавную прокрутку...")
while currentY < maxY do
    currentY = math.min(currentY + STEP, maxY)
    -- CanvasPosition ожидает Vector2
    sf.CanvasPosition = Vector2.new(0, currentY)
    local percent = math.floor((currentY / maxY) * 100)
    if percent % 10 == 0 then
        print(string.format("Прогресс: %d%%", percent))
    end
    task.wait(DELAY)
end

print("Прокрутка завершена.")
