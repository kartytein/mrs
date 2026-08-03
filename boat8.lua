-- ============================================================
--  ДИАГНОСТИКА: ВЫВОД ВСЕХ FRAME И ИХ ЦВЕТОВ ВНУТРИ OPTION
--  Поможет понять, почему не находится индикаторный Frame.
--  Запустите после ручного переключения в нужную вкладку.
-- ============================================================

local TAB_INDEX = 5
local OPTION_INDEX = 6

local coreGui = game:GetService("CoreGui")

local root
for _, child in ipairs(coreGui:GetChildren()) do
    root = child:FindFirstChild("redz-library-v5")
    if root then break end
end
if not root then print("[Ошибка] redz-library-v5") return end

-- Переключение вкладки
local tabsScroll = root:FindFirstChild("Window")
tabsScroll = tabsScroll and tabsScroll:FindFirstChild("Components")
tabsScroll = tabsScroll and tabsScroll:FindFirstChild("TabsScroll")
if not tabsScroll then print("[Ошибка] TabsScroll") return end

local function fireSequence(btn)
    for _, sigName in ipairs({"MouseEnter","MouseButton1Down","MouseButton1Click","MouseButton1Up","Activated","MouseLeave"}) do
        local sig = btn[sigName]
        if sig then
            local ok, conns = pcall(function() return getconnections(sig) end)
            if ok and conns then
                for _, conn in ipairs(conns) do
                    if conn and conn.Enabled and type(conn.Function) == "function" then
                        conn.Function()
                    end
                end
            end
        end
    end
end

local tabButton
local tabIdx = 0
local function findTab(parent)
    if tabButton then return end
    for _, child in ipairs(parent:GetChildren()) do
        if child:IsA("TextButton") or child:IsA("ImageButton") then
            tabIdx = tabIdx + 1
            if tabIdx == TAB_INDEX then tabButton = child return end
        end
        findTab(child)
    end
end
findTab(tabsScroll)
if not tabButton then print("[Ошибка] Вкладка") return end

fireSequence(tabButton)
wait(0.15)

local container = root:FindFirstChild("Window")
container = container and container:FindFirstChild("Components")
container = container and container:FindFirstChild("Containers")
container = container and container:FindFirstChild("Container")
if not container then print("[Ошибка] Container") return end

local optionBtn
local optIdx = 0
for _, child in ipairs(container:GetChildren()) do
    if child.Name == "Option" and child.Visible and (child:IsA("TextButton") or child:IsA("ImageButton")) then
        optIdx = optIdx + 1
        if optIdx == OPTION_INDEX then optionBtn = child break end
    end
end
if not optionBtn then print("[Ошибка] Option") return end

print("Кнопка: " .. optionBtn:GetFullName())
print("--- Все Frame внутри кнопки ---")
for _, child in ipairs(optionBtn:GetChildren()) do
    if child:IsA("Frame") then
        local col = tostring(child.BackgroundColor3)
        print("Frame '" .. child.Name .. "' BG: " .. col .. " BGTrans: " .. child.BackgroundTransparency)
    end
end
print("--------------------------------")
