-- ============================================================
-- HOHO Hub + Flask Parser Client
--   • Аптайм: первое timeIn > 60с (фильтр фейков эксплойта)
--   • Окна: "50:00" = 50 МИНУТ, остальные = ЧАСЫ:МИНУТЫ
--   • Каждые 30с: check uptime → OUT → parse+insert
--   • Shrine → 7-мин ожидание blue moon → parse+insert
--   • Blue moon (без shrine) → parse+insert
-- ============================================================
local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService       = game:GetService("HttpService")
local CoreGui           = game:GetService("CoreGui")
local player            = Players.LocalPlayer

local FLASK_URL = "http://192.168.31.179:8000"
local HUB_URL   = "https://raw.githubusercontent.com/acsu123/HOHO_H/main/Loading_UI"

-- Окна аптайма в СЕКУНДАХ.
-- "50:00" = 50 МИНУТ, остальные = ЧАСЫ:МИНУТЫ (допуск -5 мин, как в парсере)
local UPTIME_WINDOWS_SEC = {
    {00*3600 + 46*60,   00*3600 + 56*60 },   -- 00:46–00:56  → 2760  .. 3360
    { 3*3600 + 58*60,    4*3600 +  8*60 },   -- 03:58–04:08  → 14280 .. 14880
    { 7*3600 + 12*60,    7*3600 + 22*60 },   -- 07:12–07:22  → 25920 .. 26520
    {10*3600 + 28*60,   10*3600 + 38*60 },   -- 10:28–10:38  → 37680 .. 38280
    {13*3600 + 46*60,   13*3600 + 56*60 },   -- 13:46–13:56  → 49560 .. 50160
    {17*3600 +  6*60,   17*3600 + 16*60 },   -- 17:06–17:16  → 61560 .. 62160
    {20*3600 + 28*60,   20*3600 + 38*60 },   -- 20:28–20:38  → 73680 .. 74280
    {23*3600 + 52*60,   24*3600 +  2*60 },   -- 23:52–00:02 (+1) → 85920 .. 86520
}
-- Метка в целевом TextBox — самый надёжный ключ
local TARGET_TEXT = "here"
-- Fallback путь (если метку забыл поставить)
local TARGET_PATH = {
    "Hоhо_gеn4","MAIN_UI","MAIN_ZONES","PAGES_TAB","ANCHOR",
    "CONFIG_PAGES","MINI_11_CONFIG_4","ScrollingFrame",
    "Tab2","Textbox2","Box",
}

-- Триггерные тексты
local SHRINE_TEXT    = "A mysterious shrine has appeared in the sea"
local BLUE_MOON_TEXT = "The Blue Moon fades away"

-- Тайминги
local UPTIME_CHECK_SEC = 30
local SHRINE_WAIT_SEC  = 7 * 60
local BOX_WAIT_TIMEOUT = 120
local PARSE_TIMEOUT    = 600

print("[HOHO] === START ===")

-- ============================================================
-- 1. Загрузка хаба (в фоне)
-- ============================================================
task.spawn(function()
    local ok, err = pcall(function()
        loadstring(game:HttpGet(HUB_URL))()
    end)
    if ok then print("[HOHO] Хаб загружен успешно.")
    else warn("[HOHO] Ошибка загрузки хаба: " .. tostring(err)) end
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

-- ============================================================
-- 4. Аптайм
-- ============================================================
local function getServerUptimeSeconds()
    local currentTime = workspace:GetServerTimeNow()
    local foundTimestamp = nil
    for _, v in pairs(getgc(true)) do
        if type(v) == "table" then
            for k, val in pairs(v) do
                if type(k) == "string" and (k == "timeIn" or k == "TimeIn") then
                    if type(val) == "number" and val > 1700000000 then
                        if (currentTime - val) > 60 then
                            foundTimestamp = val
                            break
                        end
                    end
                end
            end
            if foundTimestamp then break end
        end
    end
    if foundTimestamp then return math.floor(currentTime - foundTimestamp) end
    return nil
end

local function inAnyWindow(sec)
    for _, w in ipairs(UPTIME_WINDOWS_SEC) do
        if sec >= w[1] and sec <= w[2] then return true end
    end
    return false
end

local function fmtUptime(sec)
    if not sec then return "nil" end
    local h = math.floor(sec / 3600)
    local m = math.floor((sec % 3600) / 60)
    local s = math.floor(sec % 60)
    return string.format("%dh:%02dm:%02ds (%ds)", h, m, s, sec)
end

-- ============================================================
-- 5. Watcher уведомлений
-- ============================================================
local shrineSeen   = false
local blueMoonSeen = false
local seenLabels   = setmetatable({}, {__mode = "k"})

local function checkTextLabel(lbl)
    if not lbl or not lbl:IsA("TextLabel") then return end
    if seenLabels[lbl] then return end
    seenLabels[lbl] = true

    local t = lbl.Text or ""
    if t:find(SHRINE_TEXT, 1, true) then
        shrineSeen = true
        print("[watch] SHRINE detected: " .. t:sub(1, 60))
    end
    if t:find(BLUE_MOON_TEXT, 1, true) then
        blueMoonSeen = true
        print("[watch] BLUE MOON detected: " .. t:sub(1, 60))
    end
end

task.spawn(function()
    local pg = player:WaitForChild("PlayerGui", 60)
    if not pg then warn("[watch] no PlayerGui"); return end
    local notif = pg:WaitForChild("Notifications", 60)
    if not notif then warn("[watch] no Notifications"); return end
    local stack = notif:WaitForChild("NotificationStack", 60)
    if not stack then warn("[watch] no NotificationStack"); return end

    print("[watch] watching NotificationStack")
    for _, ch in ipairs(stack:GetDescendants()) do
        if ch:IsA("TextLabel") then checkTextLabel(ch) end
    end
    stack.DescendantAdded:Connect(function(obj)
        if obj:IsA("TextLabel") then checkTextLabel(obj) end
    end)
end)

-- ============================================================
-- 6. Поиск целевого TextBox (ждёт до BOX_WAIT_TIMEOUT)
-- ============================================================
local function matchesPath(obj, segments)
    local cur = obj
    for i = #segments, 1, -1 do
        if not cur or cur.Name ~= segments[i] then return false end
        cur = cur.Parent
    end
    return true
end

local function dumpAllTextBoxes()
    print("[find] дамп TextBox под CONFIG_PAGES:")
    local rootSegments = {"Hоhо_gеn4","MAIN_UI","MAIN_ZONES","PAGES_TAB","ANCHOR","CONFIG_PAGES"}
    for _, obj in ipairs(CoreGui:GetDescendants()) do
        if obj:IsA("TextBox") and matchesPath(obj, rootSegments) then
            print(string.format("[find]   text='%s' pos=(%.1f,%.1f) path=%s",
                tostring(obj.Text),
                obj.AbsolutePosition.X, obj.AbsolutePosition.Y,
                obj:GetFullName()))
        end
    end
end

local function findTargetBox(waitTimeout)
    waitTimeout = waitTimeout or BOX_WAIT_TIMEOUT
    local t0 = tick()
    local dumped = false

    while tick() - t0 < waitTimeout do
        -- 1) метка
        if TARGET_TEXT and TARGET_TEXT ~= "" then
            for _, obj in ipairs(CoreGui:GetDescendants()) do
                if obj:IsA("TextBox") and (obj.Text or "") == TARGET_TEXT then
                    print(("[find] по метке '%s' за %.1fs -> %s")
                        :format(TARGET_TEXT, tick() - t0, obj:GetFullName()))
                    return obj
                end
            end
        end

        -- 2) путь
        local cands = {}
        for _, obj in ipairs(CoreGui:GetDescendants()) do
            if obj:IsA("TextBox") and matchesPath(obj, TARGET_PATH) then
                table.insert(cands, obj)
            end
        end
        if #cands >= 1 then
            table.sort(cands, function(a, b)
                return a.AbsolutePosition.Y > b.AbsolutePosition.Y
            end)
            print(("[find] по пути за %.1fs (%d шт), нижний Y=%.1f -> %s")
                :format(tick() - t0, #cands,
                        cands[1].AbsolutePosition.Y, cands[1]:GetFullName()))
            return cands[1]
        end

        -- 3) через 10с один дамп
        if not dumped and (tick() - t0) > 10 then
            dumped = true
            dumpAllTextBoxes()
        end

        task.wait(0.5)
    end

    print(("[find] не нашли за %.1fs — финальный дамп:"):format(waitTimeout))
    dumpAllTextBoxes()
    return nil
end

-- ============================================================
-- 7. Вставка
-- ============================================================
local function doInsert(box, value)
    if not box or not box.Parent then
        warn("[insert] box пропал"); return false
    end
    print("[insert] TextBox: " .. box:GetFullName())
    pcall(function() box:CaptureFocus() end)
    task.wait(0.1)
    if not box.Parent then
        warn("[insert] box пропал после CaptureFocus"); return false
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
    local url = FLASK_URL .. "/parse"
    local ok, res = pcall(function() return game:HttpGet(url) end)
    if not ok then
        warn("[parse] httpGet fail: " .. tostring(res)); return nil
    end
    if not res or res == "" then
        warn("[parse] empty response from " .. url); return nil
    end
    local ok2, data = pcall(HttpService.JSONDecode, HttpService, res)
    if ok2 and data and data.task_id then return data.task_id end
    warn("[parse] bad response: " .. tostring(res):sub(1, 200))
    return nil
end

local function pollResult(taskId, timeoutSec)
    timeoutSec = timeoutSec or PARSE_TIMEOUT
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
-- 9. Обёртки
-- ============================================================
local function doParseOnly(reason)
    print("[parse] " .. (reason or "?"))
    local taskId = requestParse()
    if not taskId then
        warn("[parse] /parse failed")
        return nil
    end
    print("[parse] task: " .. taskId)
    local result = pollResult(taskId, PARSE_TIMEOUT)
    if result and result.h2o2server and result.h2o2server ~= "" then
        print("[parse] got hoho: " .. result.h2o2server:sub(1, 40) .. "...")
        return result
    end
    warn("[parse] no valid result")
    return nil
end

local function doParseAndInsert(reason)
    local result = doParseOnly(reason)
    if not result then return false end
    local box = findTargetBox(BOX_WAIT_TIMEOUT)
    if not box then
        warn("[insert] TextBox не найден")
        return false
    end
    return doInsert(box, result.h2o2server)
end

-- ============================================================
-- 10. Main loop
-- ============================================================
print("[main] main loop started")
local lastUptimeCheck = 0

while true do
    -- ===== SHRINE: приоритет №1, 30с-проверки СТОП =====
    if shrineSeen then
        shrineSeen   = false
        blueMoonSeen = false
        print("[shrine] shrine detected → uptime checks paused, wait blue moon")

        local t0 = os.time()
        local trigger = nil
        while (os.time() - t0) < SHRINE_WAIT_SEC do
            if blueMoonSeen then
                trigger = "blue moon"
                break
            end
            task.wait(1)
        end
        if not trigger then
            trigger = "timeout " .. SHRINE_WAIT_SEC .. "s"
        end
        blueMoonSeen = false

        print(("[shrine] ended (%s, waited %ds) → parse+insert")
            :format(trigger, os.time() - t0))
        doParseAndInsert("shrine: " .. trigger)
        lastUptimeCheck = os.time()

    -- ===== BLUE MOON без shrine =====
    elseif blueMoonSeen then
        blueMoonSeen = false
        print("[main] blue moon (no shrine) → parse+insert")
        doParseAndInsert("blue moon")
        lastUptimeCheck = os.time()

    -- ===== UPTIME CHECK каждые 30с =====
    elseif (os.time() - lastUptimeCheck) >= UPTIME_CHECK_SEC then
        lastUptimeCheck = os.time()
        local sec = getServerUptimeSeconds()
        if not sec then
            print("[main] uptime unknown")
        elseif inAnyWindow(sec) then
            print("[main] " .. fmtUptime(sec) .. " | IN WINDOW")
        else
            print("[main] " .. fmtUptime(sec) .. " | OUT → parse+insert")
            doParseAndInsert("out of window")
        end
    end

    task.wait(1)
end
