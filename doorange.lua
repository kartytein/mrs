-- ============================================================
-- HOHO Hub + Flask Parser Client
-- ============================================================
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local CoreGui = game:GetService("CoreGui")
local player = Players.LocalPlayer

local FLASK_URL = "http://192.168.31.179:8000"
local HUB_URL   = "https://raw.githubusercontent.com/acsu123/HOHO_H/main/Loading_UI"

local UPTIME_WINDOWS_SEC = {
    {45*60,    53*60},
    {3*60+57,  4*60+5},
    {7*60+10,  7*60+17},
    {10*60+30, 10*60+37},
    {13*60+37, 13*60+44},
    {16*60+53, 17*60+0},
    {20*60+8,  20*60+15},
    {23*60+17, 23*60+24},
}

local RETRY_DELAY = 5
local STEP1_BTN   = { name = "HOMEPAGE_BUTTON", x = 557.18, y = 276.32, tol = 8 }
local STEP2_BTN   = { name = "Button",          x = 484.81, y = 244.62, tol = 8 }
local TARGET_TEXTBOX_X, TARGET_TEXTBOX_Y = 497.3, 279.1

print("[HOHO] === START ===")

-- ============================================================
-- 1. Загрузка хаба СРАЗУ, как в --!nocheck.txt
-- ============================================================
print("[HOHO] Loading hub...")
task.spawn(function()
    local ok, err = pcall(function()
        loadstring(game:HttpGet(HUB_URL))()
    end)
    if ok then print("[HOHO] Hub loaded")
    else warn("[HOHO] Hub load failed: " .. tostring(err)) end
end)

-- ============================================================
-- 2. Команда
-- ============================================================
do
    local remotes = ReplicatedStorage and ReplicatedStorage:FindFirstChild("Remotes")
    if remotes then
        local commF = remotes:FindFirstChild("CommF_")
        if commF then
            pcall(function() commF:InvokeServer("SetTeam", "Marines") end)
        end
    end
end

-- ============================================================
-- 3. Персонаж
-- ============================================================
repeat task.wait(0.5) until player.Character
    and player.Character:FindFirstChild("Humanoid")
    and player.Character:FindFirstChild("HumanoidRootPart")
    and player.Character.Humanoid.Health > 0
task.wait(3)

-- ============================================================
-- 4. Аптайм
-- ============================================================
local function getServerUptimeSeconds()
    local currentTime = workspace:GetServerTimeNow()
    local found
    for _, v in pairs(getgc(true)) do
        if type(v) == "table" then
            for k, val in pairs(v) do
                if type(k) == "string" and (k == "timeIn" or k == "TimeIn")
                   and type(val) == "number" and val > 1700000000 then
                    found = val; break
                end
            end
            if found then break end
        end
    end
    if found then return math.floor(currentTime - found) end
    return nil
end

local function inAnyWindow(sec)
    for _, w in ipairs(UPTIME_WINDOWS_SEC) do
        if sec >= w[1] and sec <= w[2] then return true end
    end
    return false
end

-- ============================================================
-- 5. Blue Moon watcher
-- ============================================================
local blueMoonSeen = false
local function checkLabelText(lbl)
    if lbl and lbl:IsA("TextLabel") and lbl.Text
       and lbl.Text:find("The Blue Moon fades away", 1, true) then
        blueMoonSeen = true
        print("[BlueMoon] detected")
    end
end

task.spawn(function()
    local pg = player:WaitForChild("PlayerGui", 30)
    if not pg then return end
    local notif = pg:WaitForChild("Notifications", 30)
    if not notif then return end
    local stack = notif:WaitForChild("NotificationStack", 30)
    if not stack then return end
    for _, ch in ipairs(stack:GetChildren()) do
        checkLabelText(ch)
        if ch:IsA("GuiObject") then
            checkLabelText(ch:FindFirstChildWhichIsA("TextLabel", true))
        end
    end
    stack.ChildAdded:Connect(function(ch)
        task.spawn(function()
            task.wait(0.05)
            checkLabelText(ch)
            if ch:IsA("GuiObject") then
                checkLabelText(ch:FindFirstChildWhichIsA("TextLabel", true))
            end
        end)
    end)
end)

-- ============================================================
-- 6. Hub helpers
-- ============================================================
local function fireSequence(btn)
    if not btn then return false end
    if not (btn:IsA("TextButton") or btn:IsA("ImageButton")) then return false end
    local fired = false
    for _, sigName in ipairs({
        "MouseEnter","MouseButton1Down","MouseButton1Click",
        "MouseButton1Up","Activated","MouseLeave"
    }) do
        local sig = btn[sigName]
        if sig then
            local ok, conns = pcall(function() return getconnections(sig) end)
            if ok and conns then
                for _, conn in ipairs(conns) do
                    if conn.Enabled and type(conn.Function) == "function" then
                        pcall(conn.Function); fired = true
                    end
                end
            end
        end
    end
    return fired
end

local function findButtonByCoords(name, tx, ty, tol)
    tol = tol or 8
    for _, obj in ipairs(CoreGui:GetDescendants()) do
        if (obj:IsA("TextButton") or obj:IsA("ImageButton")) and obj.Name == name then
            local dx = math.abs(obj.AbsolutePosition.X - tx)
            local dy = math.abs(obj.AbsolutePosition.Y - ty)
            if dx <= tol and dy <= tol then return obj end
        end
    end
    return nil
end

local function findButtonByName(name)
    for _, obj in ipairs(CoreGui:GetDescendants()) do
        if (obj:IsA("TextButton") or obj:IsA("ImageButton")) and obj.Name == name then
            return obj
        end
    end
    return nil
end

local function findMarker(marker)
    local btn = findButtonByCoords(marker.name, marker.x, marker.y, marker.tol)
    if btn then return btn end
    -- fallback: name-only для уникальных кнопок (HOMEPAGE_BUTTON)
    if marker.name == "HOMEPAGE_BUTTON" then
        local fallback = findButtonByName(marker.name)
        if fallback then
            print(string.format("[HOHO] name-fallback HOMEPAGE_BUTTON at (%.1f, %.1f) (expected %.1f, %.1f)",
                fallback.AbsolutePosition.X, fallback.AbsolutePosition.Y,
                marker.x, marker.y))
            return fallback
        end
    end
    return nil
end

local function activateUntilMarker(targetBTN, marker, tag)
    tag = tag or targetBTN.name
    local attempt = 0
    while true do
        attempt += 1
        local btn = findMarker(targetBTN)
        if not btn then
            print(string.format("[HOHO] %s #%d: target missing, wait...", tag, attempt))
            task.wait(1)
        else
            print(string.format("[HOHO] %s #%d: activate (%.1f, %.1f)",
                tag, attempt, btn.AbsolutePosition.X, btn.AbsolutePosition.Y))
            local ok = fireSequence(btn)
            if not ok then
                pcall(function() btn:Click() end)
                task.wait(0.15)
                pcall(function() btn:Activate() end)
            end
        end
        local t0 = tick()
        while tick() - t0 < RETRY_DELAY do
            if findMarker(marker) then
                print(string.format("[HOHO] %s: ✓ %.1fs", tag, tick() - t0))
                return true
            end
            task.wait(0.2)
        end
    end
end

local function findTargetTextBox()
    local best, bestDist = nil, math.huge
    for _, obj in ipairs(CoreGui:GetDescendants()) do
        if obj:IsA("TextBox") then
            local ph = (obj.PlaceholderText or ""):lower()
            local dx = math.abs(obj.AbsolutePosition.X - TARGET_TEXTBOX_X)
            local dy = math.abs(obj.AbsolutePosition.Y - TARGET_TEXTBOX_Y)
            if ph:find("try to text", 1, true) and dx <= 10 and dy <= 10 then
                return obj
            end
            if dx <= 10 and dy <= 10 and (dx+dy) < bestDist then
                best = obj; bestDist = dx + dy
            end
        end
    end
    return best
end

-- Ждём не просто существования, а положения и видимости
local function waitForHubReady(timeout)
    timeout = timeout or 120
    local t0 = tick()
    while tick() - t0 < timeout do
        for _, obj in ipairs(CoreGui:GetDescendants()) do
            if (obj:IsA("TextButton") or obj:IsA("ImageButton"))
               and obj.Name == "HOMEPAGE_BUTTON"
               and obj.Visible
               and obj.AbsoluteSize.X > 0 then
                local dx = math.abs(obj.AbsolutePosition.X - STEP1_BTN.x)
                local dy = math.abs(obj.AbsolutePosition.Y - STEP1_BTN.y)
                if dx <= STEP1_BTN.tol and dy <= STEP1_BTN.tol then
                    print(string.format("[HOHO] Hub ready in %.1fs (button at %.1f, %.1f)",
                        tick() - t0, obj.AbsolutePosition.X, obj.AbsolutePosition.Y))
                    return true
                end
            end
        end
        task.wait(0.5)
    end
    -- диагностика
    print("[HOHO] Hub not ready in " .. timeout .. "s, dump HOMEPAGE_BUTTON:")
    for _, obj in ipairs(CoreGui:GetDescendants()) do
        if (obj:IsA("TextButton") or obj:IsA("ImageButton"))
           and obj.Name == "HOMEPAGE_BUTTON" then
            print(string.format("  pos=(%.1f, %.1f) size=(%.1f, %.1f) visible=%s",
                obj.AbsolutePosition.X, obj.AbsolutePosition.Y,
                obj.AbsoluteSize.X, obj.AbsoluteSize.Y,
                tostring(obj.Visible)))
        end
    end
    return false
end

-- ============================================================
-- 7. Вставка
-- ============================================================
local function doInsert(box, value)
    if not box or not box.Parent then return false end
    print("[HOHO] Insert: " .. value)
    pcall(function() box:CaptureFocus() end)
    task.wait(0.1)
    if not box.Parent then
        warn("[HOHO] TextBox disappeared"); return false
    end
    box.Text = value
    task.wait(0.1)
    pcall(function() box:ReleaseFocus(true) end)
    task.wait(0.1)
    local sig = box.FocusLost
    if sig then
        local ok, conns = pcall(function() return getconnections(sig) end)
        if ok and conns then
            for _, c in ipairs(conns) do
                if c.Enabled and type(c.Function) == "function" then
                    pcall(c.Function)
                end
            end
        end
    end
    print("[HOHO] Insert done, Text='" .. tostring(box.Text) .. "'")
    return true
end

local function navigateAndInsert(value)
    print("[HOHO] Waiting hub ready...")
    if not waitForHubReady(120) then
        warn("[HOHO] Hub not ready, abort insert"); return false
    end

    print("[HOHO] --- STEP 1: HOMEPAGE_BUTTON ---")
    activateUntilMarker(STEP1_BTN, STEP2_BTN, "STEP1")

    print("[HOHO] --- STEP 2: Button ---")
    local targetBox, attempt = nil, 0
    while not targetBox do
        attempt += 1
        local btn2 = findMarker(STEP2_BTN)
        if btn2 then
            print(string.format("[HOHO] STEP2 #%d: activate Button", attempt))
            local ok = fireSequence(btn2)
            if not ok then
                pcall(function() btn2:Click() end)
                task.wait(0.15)
                pcall(function() btn2:Activate() end)
            end
        else
            print(string.format("[HOHO] STEP2 #%d: Button not found", attempt))
        end
        local t0 = tick()
        while tick() - t0 < RETRY_DELAY do
            targetBox = findTargetTextBox()
            if targetBox then
                print(string.format("[HOHO] STEP2: ✓ TextBox in %.1fs", tick() - t0))
                break
            end
            task.wait(0.2)
        end
    end

    print("[HOHO] --- STEP 3: insert ---")
    return doInsert(targetBox, value)
end

-- ============================================================
-- 8. HTTP (только game:HttpGet)
-- ============================================================
local function httpGet(url)
    local success, result = pcall(function()
        return game:HttpGet(url)
    end)
    if success and result then return result end
    warn("[http] error: " .. tostring(result))
    return nil
end

local function requestParse()
    local res = httpGet(FLASK_URL .. "/parse")
    if not res then return nil end
    local ok, data = pcall(HttpService.JSONDecode, HttpService, res)
    if ok and data and data.task_id then return data.task_id end
    warn("[parse] bad response: " .. tostring(res))
    return nil
end

local function pollResult(taskId, timeoutSec)
    timeoutSec = timeoutSec or 600
    local t0 = os.time()
    while os.time() - t0 < timeoutSec do
        local res = httpGet(FLASK_URL .. "/result/" .. taskId)
        if res then
            local ok, data = pcall(HttpService.JSONDecode, HttpService, res)
            if ok and data then
                if data.status == "done"      then return data.result end
                if data.status == "error"     then
                    warn("[parse] error: " .. tostring(data.error)); return nil
                end
                if data.status == "not_found" then return nil end
            end
        end
        task.wait(2)
    end
    return nil
end

-- ============================================================
-- 9. Ждём готовности UI хаба (с диагностикой)
-- ============================================================
print("[HOHO] Waiting hub ready before main loop...")
waitForHubReady(120)  -- не блокируем main loop при неудаче

-- ============================================================
-- 10. Main loop
-- ============================================================
local function needsParse()
    if blueMoonSeen then return true end
    local sec = getServerUptimeSeconds()
    if not sec then return true end
    if not inAnyWindow(sec) then return true end
    return false
end

while true do
    if needsParse() then
        blueMoonSeen = false
        print("[main] request parse...")
        local taskId = requestParse()
        if taskId then
            print("[main] task: " .. taskId)
            local result = pollResult(taskId, 600)
            if result and result.h2o2server and result.h2o2server ~= "" then
                print("[main] got hoho: " .. result.h2o2server)
                navigateAndInsert(result.h2o2server)
            else
                warn("[main] no valid result")
            end
        else
            warn("[main] /parse failed")
        end
        task.wait(5)
    else
        task.wait(3)
    end
end
