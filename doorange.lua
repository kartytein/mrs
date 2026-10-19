-- ============================================================
-- HOHO Hub + Flask Parser Client
--   • Аптайм: как в -- Сервисы.txt + фильтр > 60с
--   • Окна: "50:00" = 50 МИНУТ, остальные = ЧАСЫ:МИНУТЫ
--   • Один раз при старте: ждём аптайм → проверяем окно
--   • Вне окна → парсим с ретраями; в окне → ждём blue moon
--   • Дальше ТОЛЬКО blue moon триггерит парсинг (с ретраями)
--   • findTargetBox ждёт до 120с пока хаб достроится
-- ============================================================
local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService       = game:GetService("HttpService")
local CoreGui           = game:GetService("CoreGui")
local player            = Players.LocalPlayer

local FLASK_URL = "http://192.168.31.179:8000"
local HUB_URL   = "https://raw.githubusercontent.com/acsu123/HOHO_H/main/Loading_UI"

local UPTIME_WINDOWS_SEC = {
    {45*60,             50*60          },   --  50 мин       → 2700 .. 3000
    { 3*3600 + 55*60,   4*3600         },   --  4 часа       → 14100 .. 14400
    { 7*3600 + 10*60,   7*3600 + 15*60 },   --  7:15         → 25800 .. 26100
    {10*3600 + 30*60,  10*3600 + 35*60 },   -- 10:35         → 37800 .. 38100
    {13*3600 + 37*60,  13*3600 + 42*60 },   -- 13:42         → 49020 .. 49320
    {16*3600 + 51*60,  16*3600 + 56*60 },   -- 16:56         → 60660 .. 60960
    {20*3600 +  7*60,  20*3600 + 12*60 },   -- 20:12         → 72420 .. 72720
    {23*3600 + 18*60,  23*3600 + 23*60 },   -- 23:23         → 83880 .. 84180
}

local TARGET_TEXT = "here"
local TARGET_PATH = {
    "Hоhо_gеn4","MAIN_UI","MAIN_ZONES","PAGES_TAB","ANCHOR",
    "CONFIG_PAGES","MINI_11_CONFIG_4","ScrollingFrame",
    "Tab2","Textbox2","Box",
}

local UPTIME_WAIT_TIMEOUT = 60
local BOX_WAIT_TIMEOUT    = 120

-- Ретраи для /parse
local PARSE_STARTUP_MAX_ATTEMPTS = 12   -- 12 × 15с = 3 минуты
local PARSE_STARTUP_DELAY        = 15
local PARSE_BLUEMOON_MAX_ATTEMPTS = 6   -- 6 × 10с = 1 минута
local PARSE_BLUEMOON_DELAY        = 10

print("[HOHO] === START ===")
print("[HOHO] Flask URL: " .. FLASK_URL)

-- 1. Хаб
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

local function waitForUptime(timeout)
    timeout = timeout or UPTIME_WAIT_TIMEOUT
    local t0 = tick()
    while tick() - t0 < timeout do
        local sec = getServerUptimeSeconds()
        if sec then
            print(string.format("[uptime] получен за %.1fs", tick() - t0))
            return sec
        end
        task.wait(0.5)
    end
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
        if TARGET_TEXT and TARGET_TEXT ~= "" then
            for _, obj in ipairs(CoreGui:GetDescendants()) do
                if obj:IsA("TextBox") and (obj.Text or "") == TARGET_TEXT then
                    print(("[find] по метке '%s' за %.1fs -> %s")
                        :format(TARGET_TEXT, tick() - t0, obj:GetFullName()))
                    return obj
                end
            end
        end

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
-- 8. HTTP (строкий, пустой ответ = nil)
-- ============================================================
local function httpGet(url)
    local ok, res = pcall(function() return game:HttpGet(url) end)
    if not ok then
        warn("[http] httpGet error: " .. tostring(res))
        return nil
    end
    if type(res) ~= "string" then
        warn("[http] httpGet non-string: " .. type(res))
        return nil
    end
    if res == "" then
        warn("[http] httpGet empty from " .. url)
        return nil
    end
    return res
end

local function requestParse()
    local res = httpGet(FLASK_URL .. "/parse")
    if not res then
        return nil
    end
    local ok, data = pcall(HttpService.JSONDecode, HttpService, res)
    if ok and data and data.task_id then
        return data.task_id
    end
    warn("[parse] bad response (" .. #res .. "B): " .. res:sub(1, 200))
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
-- 9. Parse + insert (возвращает true = «попытка завершена успешно»,
--    false = «надо повторить /parse, потому что он не прошёл»)
-- ============================================================
local function doParseAndInsert(reason)
    print("[main] parse (" .. (reason or "?") .. ")")
    local taskId = requestParse()
    if not taskId then
        warn("[main] /parse failed")
        return false
    end
    print("[main] task: " .. taskId)
    local result = pollResult(taskId, 600)
    if result and result.h2o2server and result.h2o2server ~= "" then
        print("[main] got hoho: " .. result.h2o2server)
        local box = findTargetBox(BOX_WAIT_TIMEOUT)
        if box then
            doInsert(box, result.h2o2server)
            return true
        else
            warn("[main] TextBox не найден за " .. BOX_WAIT_TIMEOUT .. "с")
            return false  -- retry: хаб мог не догрузиться
        end
    else
        warn("[main] no valid result (no match in discord)")
        return true   -- /parse прошёл, матча нет → retry бесполезен
    end
end

-- ============================================================
-- 10. Health check + одноразовая стартовая проверка
-- ============================================================
print("[main] health check: " .. FLASK_URL .. "/health")
do
    local h = httpGet(FLASK_URL .. "/health")
    if h then print("[main] flask alive: " .. h)
    else warn("[main] flask NOT reachable — will retry /parse") end
end

print("[main] ждём данные аптайма...")
local initialUptime = waitForUptime(UPTIME_WAIT_TIMEOUT)

if not initialUptime then
    print("[main] аптайм не получен за " .. UPTIME_WAIT_TIMEOUT ..
          "с → форсируем парсинг")
    for attempt = 1, PARSE_STARTUP_MAX_ATTEMPTS do
        if doParseAndInsert("uptime timeout") then break end
        warn(("[main] retry %d/%d через %ds")
            :format(attempt, PARSE_STARTUP_MAX_ATTEMPTS, PARSE_STARTUP_DELAY))
        task.wait(PARSE_STARTUP_DELAY)
    end
else
    print("[main] initial uptime=" .. fmtUptime(initialUptime))
    if inAnyWindow(initialUptime) then
        print("[main] ✓ в окне — парсер не нужен, ждём blue moon")
    else
        print("[main] ✗ вне окна — парсим сейчас (с ретраями)")
        for attempt = 1, PARSE_STARTUP_MAX_ATTEMPTS do
            if doParseAndInsert("out of window") then break end
            warn(("[main] retry %d/%d через %ds")
                :format(attempt, PARSE_STARTUP_MAX_ATTEMPTS, PARSE_STARTUP_DELAY))
            task.wait(PARSE_STARTUP_DELAY)
        end
    end
end

-- ============================================================
-- 11. Дальше — только blue moon (с ретраями)
-- ============================================================
print("[main] ожидание blue moon...")
while true do
    if blueMoonSeen then
        blueMoonSeen = false
        for attempt = 1, PARSE_BLUEMOON_MAX_ATTEMPTS do
            if doParseAndInsert("blue moon") then break end
            warn(("[main] blue moon retry %d/%d через %ds")
                :format(attempt, PARSE_BLUEMOON_MAX_ATTEMPTS, PARSE_BLUEMOON_DELAY))
            task.wait(PARSE_BLUEMOON_DELAY)
        end
    end
    task.wait(1)
end
