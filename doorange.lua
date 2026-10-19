-- ============================================================
-- HOHO Hub + Flask Parser Client (без кликов: находим TextBox
-- по метке "here" или path MINI_11_CONFIG_4 + нижний Y, вставляем)
-- ============================================================
local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService       = game:GetService("HttpService")
local CoreGui           = game:GetService("CoreGui")
local player            = Players.LocalPlayer

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

-- Метка, которую ты сам ставишь в целевой TextBox (ускоряет поиск).
-- Если пусто — не используется.
local TARGET_TEXT = "here"

-- Целевой путь (родитель, в котором 2 TextBox; берём нижний по Y)
local TARGET_PATH = {
    "Hоhо_gеn4","MAIN_UI","MAIN_ZONES","PAGES_TAB","ANCHOR",
    "CONFIG_PAGES","MINI_11_CONFIG_4","ScrollingFrame",
    "Tab2","Textbox2","Box",
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
local function isCharacterReady()
    local ok, res = pcall(function()
        local c = player.Character
        if not c then return false end
        local h = c:FindFirstChild("Humanoid")
        local r = c:FindFirstChild("HumanoidRootPart")
        if not h or not r then return false end
        return h.Health > 0
    end)
    return ok and res
end

repeat task.wait(0.5) until isCharacterReady()
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
-- 6. Поиск целевого TextBox
-- ============================================================
local function matchesPath(obj, segments)
    local cur = obj
    for i = #segments, 1, -1 do
        if not cur or cur.Name ~= segments[i] then return false end
        cur = cur.Parent
    end
    return true
end

local function walkPath(segments)
    local cur = CoreGui
    for _, seg in ipairs(segments) do
        if not cur then return nil end
        cur = cur:FindFirstChild(seg)
    end
    return cur
end

local function dumpAllBoxes()
    print("[HOHO DEBUG] Все TextBox по CONFIG_PAGES:")
    for _, obj in ipairs(CoreGui:GetDescendants()) do
        if obj:IsA("TextBox") and matchesPath(obj, {"Hоhо_gеn4","MAIN_UI","MAIN_ZONES","PAGES_TAB","ANCHOR","CONFIG_PAGES"}) then
            print(string.format("[HOHO DEBUG]   pos=(%.1f, %.1f) text='%s' path=%s",
                obj.AbsolutePosition.X, obj.AbsolutePosition.Y,
                tostring(obj.Text), obj:GetFullName()))
        end
    end
end

local function findTargetBox()
    -- 1) быстрая проверка по метке
    if TARGET_TEXT and TARGET_TEXT ~= "" then
        for _, obj in ipairs(CoreGui:GetDescendants()) do
            if obj:IsA("TextBox") and (obj.Text or "") == TARGET_TEXT then
                print("[find] по метке '"..TARGET_TEXT.."' -> " .. obj:GetFullName())
                return obj
            end
        end
    end

    -- 2) все TextBox по целевому пути (там 2 — берём нижний по Y)
    local cands = {}
    for _, obj in ipairs(CoreGui:GetDescendants()) do
        if obj:IsA("TextBox") and matchesPath(obj, TARGET_PATH) then
            table.insert(cands, obj)
        end
    end

    if #cands == 0 then
        print("[find] по пути MINI_11_CONFIG_4 ничего нет")
        dumpAllBoxes()
        return nil
    end
    if #cands == 1 then
        print("[find] единственный по пути -> " .. cands[1]:GetFullName())
        return cands[1]
    end

    table.sort(cands, function(a, b)
        return a.AbsolutePosition.Y > b.AbsolutePosition.Y
    end)
    print(("[find] %d дублей по пути, выбран нижний Y=%.1f -> %s")
        :format(#cands, cands[1].AbsolutePosition.Y, cands[1]:GetFullName()))
    return cands[1]
end

-- ============================================================
-- 7. Вставка
-- ============================================================
local function doInsert(box, value)
    if not box or not box.Parent then
        warn("[insert] box пропал")
        return false
    end
    print("[insert] TextBox: " .. box:GetFullName())
    print("[insert] вставляю: '" .. value .. "'")
    pcall(function() box:CaptureFocus() end)
    task.wait(0.1)
    if not box.Parent then
        warn("[insert] box пропал после CaptureFocus")
        return false
    end
    box.Text = value
    task.wait(0.1)
    pcall(function() box:ReleaseFocus(true) end)
    task.wait(0.1)
    print("[insert] после вставки Text = '" .. tostring(box.Text) .. "'")
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
-- 8. HTTP
-- ============================================================
local function httpGet(url)
    local ok, res = pcall(function() return game:HttpGet(url) end)
    if ok and res then return res end
    warn("[http] error: " .. tostring(res))
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
-- 9. Main loop
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
                local box = findTargetBox()
                if box then
                    doInsert(box, result.h2o2server)
                else
                    warn("[main] целевой TextBox не найден")
                end
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
