-- ============================================================
-- Флоу: 6,1 → dragon talon → island → 2,4 → mastery>500 → 6,1
-- В конце используем "слепой" toggle по кнопке (fireSequence),
-- не полагаясь на индикатор — в начале это работает, в конце нет.
-- ============================================================

task.spawn(function()
    pcall(function()
        loadstring(game:HttpGet("https://raw.githubusercontent.com/Omgshit/Scripts/main/MainLoader.lua"))()
    end)
end)

local CoreGui = game:GetService("CoreGui")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local COLOR_ON  = "0.345098, 0.396078, 0.94902"
local COLOR_OFF = "0.239216, 0.262745, 0.529412"

local function log(msg) pcall(function() warn("[Auto] " .. msg) end) end

local function getRoot()
    for _, child in ipairs(CoreGui:GetChildren()) do
        local obj = child:FindFirstChild("redz-library-v5")
        if obj then return obj end
    end
    return nil
end

local function safeFind(obj, ...)
    for _, name in ipairs({...}) do
        if not obj then return nil end
        obj = obj:FindFirstChild(name)
    end
    return obj
end

local function waitForInterface()
    if not getRoot() then return false end
    return safeFind(getRoot(), "Window", "Components", "TabsScroll") ~= nil
end

log("Ожидание интерфейса хаба...")
repeat task.wait(0.5) until waitForInterface()
log("Интерфейс готов.")

local function fireSequence(btn)
    if not (btn:IsA("TextButton") or btn:IsA("ImageButton")) then return end
    local signals = {"MouseEnter","MouseButton1Down","MouseButton1Click","MouseButton1Up","Activated","MouseLeave"}
    for _, sig in ipairs(signals) do
        local event = btn[sig]
        if event then
            for _, conn in ipairs(getconnections(event) or {}) do
                if conn.Enabled then pcall(conn.Function) end
            end
        end
    end
end

local function findIndicatorFrame(parent)
    for _, child in ipairs(parent:GetChildren()) do
        if child:IsA("Frame") then
            local col = tostring(child.BackgroundColor3)
            if col == COLOR_ON or col == COLOR_OFF then return child end
        end
        local found = findIndicatorFrame(child)
        if found then return found end
    end
    return nil
end

-- ===== общие помощники поиска кнопок =====
local function findTabByIndex(root, tabIndex)
    local tabsScroll = safeFind(root, "Window", "Components", "TabsScroll")
    if not tabsScroll then return nil end
    local tabButton, count = nil, 0
    local function scan(p)
        if tabButton then return end
        for _, c in ipairs(p:GetChildren()) do
            if c:IsA("TextButton") or c:IsA("ImageButton") then
                count += 1
                if count == tabIndex then tabButton = c return end
            end
            scan(c)
        end
    end
    scan(tabsScroll)
    return tabButton
end

local function findOptionByIndex(root, optIndex)
    local container = safeFind(root, "Window", "Components", "Containers", "Container")
    if not container then return nil end
    local optionBtn, count = nil, 0
    for _, c in ipairs(container:GetChildren()) do
        if c.Name == "Option" and c.Visible and (c:IsA("TextButton") or c:IsA("ImageButton")) then
            count += 1
            if count == optIndex then optionBtn = c break end
        end
    end
    return optionBtn
end

-- ===== getOptionState / enableOption (как в оригинале) =====
local function getOptionState(tabIndex, optIndex)
    local root = getRoot()
    if not root then return nil end
    local tabButton = findTabByIndex(root, tabIndex)
    if not tabButton then return nil end
    fireSequence(tabButton)
    task.wait(0.3)
    local optionBtn = findOptionByIndex(root, optIndex)
    if not optionBtn then return nil end
    local indicator = findIndicatorFrame(optionBtn)
    if not indicator then return nil end
    local col = tostring(indicator.BackgroundColor3)
    if col == COLOR_ON then return "on"
    elseif col == COLOR_OFF then return "off" end
    return nil
end

local function enableOption(tabIndex, optIndex)
    local state = getOptionState(tabIndex, optIndex)
    if state == "on" then return true end
    if state ~= "off" then return false end
    local root = getRoot()
    if not root then return false end
    local tabButton = findTabByIndex(root, tabIndex)
    if not tabButton then return false end
    fireSequence(tabButton)
    task.wait(0.3)
    local optionBtn = findOptionByIndex(root, optIndex)
    if not optionBtn then return false end
    fireSequence(optionBtn)
    task.wait(0.1)
    return true
end

-- ===== СЛЕПОЙ toggle: жмёт по кнопке всегда, игнорируя индикатор =====
local function blindToggle(tabIndex, optIndex)
    local root = getRoot()
    if not root then return false end
    local tabButton = findTabByIndex(root, tabIndex)
    if not tabButton then return false end
    fireSequence(tabButton)
    task.wait(0.4)
    local optionBtn = findOptionByIndex(root, optIndex)
    if not optionBtn then return false end
    fireSequence(optionBtn)
    task.wait(0.25)
    return true
end

-- ============================================================
-- Проверки по путям
-- ============================================================
local function hasDragonTalon()
    local pg = LocalPlayer:FindFirstChild("PlayerGui")
    if not pg then return false end
    local wac = pg:FindFirstChild("WeaponAssetCache")
    if not wac then return false end
    return wac:FindFirstChild("dragontalon") ~= nil
end

local function isOnIsland()
    local world = workspace:FindFirstChild("_WorldOrigin")
    if not world then return false end
    local sounds = world:FindFirstChild("Sounds")
    if not sounds then return false end
    local locs = sounds:FindFirstChild("Locations")
    if not locs then return false end
    return locs:FindFirstChild("Submerged Island") ~= nil
end

local function getMastery()
    local pg = LocalPlayer:FindFirstChild("PlayerGui")
    if not pg then return nil end
    local main = pg:FindFirstChild("Main")
    if not main then return nil end
    local lbl = main:FindFirstChild("MobileMasteryLevel")
    if not lbl then return nil end
    return tonumber(string.match(lbl.Text or "", "%d+"))
end

-- ===== Луп как в оригинале, но с выходом по условию =====
local function waitWithKeepOn(tabIndex, optIndex, predicate, timeout)
    timeout = timeout or 900
    local startTime = tick()
    while true do
        local state = getOptionState(tabIndex, optIndex)
        if state == "off" then
            enableOption(tabIndex, optIndex)
        elseif state == "on" then
            -- ok
        else
            log("Кнопка не найдена, ожидание...")
        end
        if predicate() then return true end
        if tick() - startTime > timeout then log("Таймаут.") return false end
        task.wait(3)
    end
end

-- ============================================================
-- ОСНОВНОЙ ФЛОУ
-- ============================================================

-- Шаг 1: dragon talon
log("Шаг 1: dragon talon...")
if not hasDragonTalon() then
    log("Нет — держу 6,1, жду...")
    waitWithKeepOn(6, 1, hasDragonTalon)
end
log("Dragon talon есть.")

-- Шаг 2: остров
log("Шаг 2: остров...")
if not isOnIsland() then
    log("Не на острове — держу 6,1, жду...")
    waitWithKeepOn(6, 1, isOnIsland)
end
log("На острове.")

-- Шаг 3: жёстко выключаем 6,1 (слепой toggle), затем включаем 2,4
log("Шаг 3: слепо выключаю 6,1...")
blindToggle(6, 1)
task.wait(1)
log("Включаю 2,4...")
-- 2,4 может быть уже активна визуально — жмём слепо, чтобы точно запустить
blindToggle(2, 4)
task.wait(1)
-- если 2,4 визуально off — жмём ещё раз
for i = 1, 3 do
    local s = getOptionState(2, 4)
    if s == "on" then break end
    blindToggle(2, 4)
    task.wait(1)
end

-- Шаг 4: ждём mastery > 500
log("Шаг 4: mastery > 500...")
local mastery = 0
repeat
    task.wait(2)
    mastery = getMastery() or 0
    log("Mastery: " .. tostring(mastery))
until mastery > 500

-- Шаг 5: слепо выключаем 2,4, слепо включаем 6,1
log("Шаг 5: слепо выключаю 2,4...")
blindToggle(2, 4)
task.wait(1.5)
log("Слепо включаю 6,1...")
blindToggle(6, 1)
task.wait(1)
-- добиваем, если визуально ещё off
for i = 1, 3 do
    local s = getOptionState(6, 1)
    if s == "on" then break end
    blindToggle(6, 1)
    task.wait(1)
end

log("Готово.")
