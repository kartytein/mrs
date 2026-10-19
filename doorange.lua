-- ============================================================
-- HOHO Hub (1:1) + Flask Parser Client — актуальные координаты
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

-- ==== АКТУАЛЬНЫЕ КООРДИНАТЫ ====
local STEP1_BTN = {
    name = "HOMEPAGE_BUTTON",
    x = 889.99, y = 488.06, tol = 12,
    path = {"Hоhо_gеn4", "MAIN_UI", "MAIN_ZONES", "HOME_TAB",
            "Functions", "HOME_PAGER", "PAGES_HOLDER", "PAGE_SHORTCUTS"},
}
local STEP2_BTN = {
    name = "Button",
    x = 775.60, y = 437.97, tol = 15,
}
local TARGET_TEXTBOX = {
    name = "Box",
    placeholder_substr = "try to text",
    x = 795.3, y = 492.5, tol = 20,
    path = {"Hоhо_gеn4", "MAIN_UI", "MAIN_ZONES", "PAGES_TAB", "ANCHOR",
            "CONFIG_PAGES", "MINI_11_CONFIG_4", "ScrollingFrame",
            "Tab2", "Textbox2"},
}

print("[HOHO] === START ===")

-- 1. Загрузка хаба
task.spawn(function()
    local ok, err = pcall(function()
        loadstring(game:HttpGet(HUB_URL))()
    end)
    if ok then print("[HOHO] Хаб загружен успешно.")
    else warn("[HOHO] Ошибка загрузки хаба: " .. tostring(err)) end
end)

-- 2. Команда
do
    local remotes = ReplicatedStorage and ReplicatedStorage:FindFirstChild("Remotes")
    if remotes then
        local commF = remotes:FindFirstChild("CommF_")
        if commF then
            pcall(function() commF:InvokeServer("SetTeam", "Marines") end)
        end
    end
end

-- 3. Персонаж
repeat task.wait(0.5) until player.Character
    and player.Character:FindFirstChild("Humanoid")
    and player.Character:FindFirstChild("HumanoidRootPart")
    and player.Character.Humanoid.Health > 0
task.wait(3)

-- 4. Аптайм
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

-- 5. Blue Moon watcher
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

local function walkPath(segments)
    local cur = CoreGui
    for _, seg in ipairs(segments) do
        if not cur then return nil end
        cur = cur:FindFirstChild(seg)
    end
    return cur
end

local function findMarker(marker)
    if marker.path then
        local parent = walkPath(marker.path)
        if parent then
            for _, c in ipairs(parent:GetChildren()) do
                if c.Name == marker.name and (c:IsA("TextButton") or c:IsA("ImageButton")) then
                    local dx = math.abs(c.AbsolutePosition.X - marker.x)
                    local dy = math.abs(c.AbsolutePosition.Y - marker.y)
                    if dx <= (marker.tol or 8) and dy <= (marker.tol or 8) then
                        return c
                    end
                end
            end
        end
    end
    return findButtonByCoords(marker.name, marker.x, marker.y, marker.tol)
end

local function dumpMarkers(name)
    print(string.format("[HOHO DEBUG] Все %s:", name))
    for _, obj in ipairs(CoreGui:GetDescendants()) do
        if (obj:IsA("TextButton") or obj:IsA("ImageButton")) and obj.Name == name then
            print(string.format("[HOHO DEBUG]   pos=(%.1f, %.1f) size=(%.1f, %.1f) vis=%s path=%s",
                obj.AbsolutePosition.X, obj.AbsolutePosition.Y,
                obj.AbsoluteSize.X, obj.AbsoluteSize.Y,
                tostring(obj.Visible), obj:GetFullName()))
        end
    end
end

local function activateUntilMarker(targetBTN, marker, tag)
    tag = tag or targetBTN.name
    local attempt = 0
    local dumped = false
    while true do
        attempt += 1
        local btn = findMarker(targetBTN)
        if not btn then
            print(string.format("[HOHO] %s: попытка #%d — target не найден, ждём...", tag, attempt))
            if not dumped then
                dumped = true
                dumpMarkers(targetBTN.name)
            end
            task.wait(1)
        else
            print(string.format("[HOHO] %s: попытка #%d — активирую (%.1f, %.1f)",
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
            local m = findMarker(marker)
            if m then
                print(string.format("[HOHO] %s: ✓ успех через %.1fс", tag, tick() - t0))
                return m
            end
            task.wait(0.2)
        end
        print(string.format("[HOHO] %s: маркер не появился за %dс — повтор", tag, RETRY_DELAY))
    end
end

-- ============================================================
-- TextBox: 1) по path → 2) по placeholder → 3) по координатам
-- ============================================================
local function findTargetTextBox()
    -- 1) точный path (самый надёжный, убьёт любые дубликаты)
    local parent = walkPath(TARGET_TEXTBOX.path)
    if parent then
        local b = parent:FindFirstChild(TARGET_TEXTBOX.name)
        if b and b:IsA("TextBox") then
            return b
        end
    end

    -- 2) по placeholder с координатами как tiebreaker
    local phMatches = {}
    for _, obj in ipairs(CoreGui:GetDescendants()) do
        if obj:IsA("TextBox") then
            local ph = (obj.PlaceholderText or ""):lower()
            if ph:find(TARGET_TEXTBOX.placeholder_substr, 1, true) then
                table.insert(phMatches, obj)
            end
        end
    end
    if #phMatches == 1 then return phMatches[1] end
    if #phMatches > 1 then
        local best, bestDist = nil, math.huge
        for _, obj in ipairs(phMatches) do
            local dx = math.abs(obj.AbsolutePosition.X - TARGET_TEXTBOX.x)
            local dy = math.abs(obj.AbsolutePosition.Y - TARGET_TEXTBOX.y)
            if (dx + dy) < bestDist then best, bestDist = obj, dx + dy end
        end
        return best
    end

    -- 3) fallback: ближайший TextBox по координатам
    local best, bestDist = nil, math.huge
    for _, obj in ipairs(CoreGui:GetDescendants()) do
        if obj:IsA("TextBox") then
            local dx = math.abs(obj.AbsolutePosition.X - TARGET_TEXTBOX.x)
            local dy = math.abs(obj.AbsolutePosition.Y - TARGET_TEXTBOX.y)
            if dx <= TARGET_TEXTBOX.tol and dy <= TARGET_TEXTBOX.tol
               and (dx + dy) < bestDist then
                best, bestDist = obj, dx + dy
            end
        end
    end
    return best
end

local function dumpTextBoxes()
    print("[HOHO DEBUG] Все TextBox:")
    for _, obj in ipairs(CoreGui:GetDescendants()) do
        if obj:IsA("TextBox") then
            print(string.format("[HOHO DEBUG]   pos=(%.1f, %.1f) ph='%s' text='%s' vis=%s path=%s",
                obj.AbsolutePosition.X, obj.AbsolutePosition.Y,
                tostring(obj.PlaceholderText), tostring(obj.Text),
                tostring(obj.Visible), obj:GetFullName()))
        end
    end
end

-- ============================================================
-- 7. Вставка
-- ============================================================
local function doInsert(box, value)
    print("[HOHO] Найден TextBox: " .. box:GetFullName())
    print("[HOHO] Вставляю текст: '" .. value .. "'")
    pcall(function() box:CaptureFocus() end)
    task.wait(0.1)
    if not box.Parent then
        warn("[HOHO] Ошибка: TextBox исчез до вставки текста!")
        return false
    end
    box.Text = value
    task.wait(0.1)
    pcall(function() box:ReleaseFocus(true) end)
    task.wait(0.1)
    print("[HOHO] Текст после вставки: '" .. tostring(box.Text) .. "'")
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
    return true
end

-- ============================================================
-- 8. Пайплайн
-- ============================================================
local function runHubInsert(value)
    print("[HOHO] Жду появления UI (HOMEPAGE_BUTTON)...")
    local t0 = tick()
    while true do
        local ready = false
        for _, obj in ipairs(CoreGui:GetDescendants()) do
            if (obj:IsA("TextButton") or obj:IsA("ImageButton"))
               and obj.Name == "HOMEPAGE_BUTTON" then
                ready = true; break
            end
        end
        if ready then
            print(string.format("[HOHO] UI появился через %.1fс", tick() - t0))
            break
        end
        task.wait(0.5)
    end

    print("[HOHO] --- ШАГ 1: HOMEPAGE_BUTTON ---")
    activateUntilMarker(STEP1_BTN, STEP2_BTN, "STEP1")

    print("[HOHO] --- ШАГ 2: Button ---")
    local attempt2, targetBox = 0, nil
    while not targetBox do
        attempt2 += 1
        local btn2 = findMarker(STEP2_BTN)
        if btn2 then
            print(string.format("[HOHO] STEP2: попытка #%d — активирую Button", attempt2))
            local ok = fireSequence(btn2)
            if not ok then
                pcall(function() btn2:Click() end)
                task.wait(0.15)
                pcall(function() btn2:Activate() end)
            end
        else
            print(string.format("[HOHO] STEP2: попытка #%d — Button не найден", attempt2))
            dumpMarkers(STEP2_BTN.name)
        end
        local t1 = tick()
        while tick() - t1 < RETRY_DELAY do
            targetBox = findTargetTextBox()
            if targetBox then
                print(string.format("[HOHO] STEP2: ✓ TextBox появился через %.1fс", tick() - t1))
                break
            end
            task.wait(0.2)
        end
        if not targetBox then
            print("[HOHO] STEP2: TextBox не появился, повтор...")
            dumpTextBoxes()
        end
    end

    print("[HOHO] --- ШАГ 3: Вставка текста ---")
    return doInsert(targetBox, value)
end

-- ============================================================
-- 9. HTTP
-- ============================================================
local function httpGet(url)
    local success, result = pcall(function() return game:HttpGet(url) end)
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
-- 10. Main loop
-- ============================================================
local function needsParse()
    if blueMoonSeen then
        print("[main] needsParse=true (blueMoonSeen)")
        return true
    end
    local sec = getServerUptimeSeconds()
    if not sec then
        print("[main] needsParse=true (uptime unknown)")
        return true
    end
    if not inAnyWindow(sec) then
        print("[main] needsParse=true (uptime=" .. sec .. "s out of windows)")
        return true
    end
    print("[main] needsParse=false (uptime=" .. sec .. "s in window, waiting)")
    return false
end

print("[main] main loop started")
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
                runHubInsert(result.h2o2server)
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
