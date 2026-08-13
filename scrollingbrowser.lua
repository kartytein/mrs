-- ============================================================
-- SERVER HOP: Открыть браузер серверов -> прокрутка -> случайный Join
-- Шаги:
--   1. Ожидание и активация ServerBrowserButton
--   2. Ожидание появления кнопки Join
--   3. Прокрутка случайное время (1-10 сек)
--   4. Активация случайной видимой кнопки Join
-- ============================================================

local player = game.Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Универсальная активация кнопки (fireSequence)
local function fireSequence(btn)
    if not (btn:IsA("TextButton") or btn:IsA("ImageButton")) then return end
    for _, sig in ipairs({"MouseEnter","MouseButton1Down","MouseButton1Click","MouseButton1Up","Activated","MouseLeave"}) do
        local event = btn[sig]
        if event then
            for _, conn in ipairs(getconnections(event) or {}) do
                if conn.Enabled then pcall(conn.Function) end
            end
        end
    end
end

-- ===== 1. Ожидание и активация ServerBrowserButton =====
local function findServerBrowserButton()
    local topbar = playerGui:FindFirstChild("Topbar")
    if topbar then
        local frame = topbar:FindFirstChild("Frame")
        if frame then
            return frame:FindFirstChild("ServerBrowserButton")
        end
    end
    return nil
end

print("Ожидание ServerBrowserButton...")
while not findServerBrowserButton() do
    task.wait(0.5)
end
local serverButton = findServerBrowserButton()
print("ServerBrowserButton найден, активирую...")
fireSequence(serverButton)

-- ===== 2. Ожидание появления кнопки Join =====
local function findVisibleJoinButton()
    for _, v in ipairs(playerGui:GetDescendants()) do
        if (v:IsA("TextButton") or v:IsA("TextBox")) and v.Text == "Join" and v.Visible then
            return v
        end
    end
    return nil
end

print("Ожидание кнопки Join...")
while not findVisibleJoinButton() do
    task.wait(0.5)
end
print("Кнопка Join появилась.")

-- ===== 3. Прокрутка списка серверов =====
local serverBrowser = playerGui:FindFirstChild("ServerBrowser")
if not serverBrowser then return print("ServerBrowser не найден") end

local frame = serverBrowser:FindFirstChild("Frame")
if not frame then return print("Frame не найден") end

local sf = frame:FindFirstChild("ScrollingFrame")
if not sf then return print("ScrollingFrame не найден") end

print("ScrollingFrame найден: " .. sf:GetFullName())

local canvasSizeY = sf.CanvasSize.Y
local maxY = (typeof(canvasSizeY) == "UDim") and canvasSizeY.Offset or canvasSizeY
print("Максимальный Y: " .. maxY)

local scrollDuration = math.random(1, 10)
print("Прокручиваю " .. scrollDuration .. " секунд...")

local STEP = 150
local DELAY = 0.03
local currentY = 0
local startTime = tick()

sf.CanvasPosition = Vector2.new(0, 0)
task.wait(0.2)

while (tick() - startTime) < scrollDuration and currentY < maxY do
    currentY = math.min(currentY + STEP, maxY)
    sf.CanvasPosition = Vector2.new(0, currentY)
    task.wait(DELAY)
end

print("Прокрутка остановлена. Собираю видимые кнопки Join...")

-- ===== 4. Сбор и активация случайной Join =====
local joinButtons = {}
local function collectJoins(parent)
    for _, child in ipairs(parent:GetChildren()) do
        if (child:IsA("TextButton") or child:IsA("TextBox")) and child.Text == "Join" and child.Visible then
            table.insert(joinButtons, child)
        end
        collectJoins(child)
    end
end
collectJoins(serverBrowser)

if #joinButtons == 0 then
    return print("Нет видимых кнопок Join")
end

print("Найдено видимых Join: " .. #joinButtons)

local chosen = joinButtons[math.random(1, #joinButtons)]
print("Активирую: " .. chosen:GetFullName())
fireSequence(chosen)
print("Готово.")
