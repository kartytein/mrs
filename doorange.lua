-- ============================================================
-- HOHO Hub + Flask Parser Client — динамический выбор кнопок
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

-- Пути: если сегменты в порядке встречаются в GetFullName — кандидат подходит.
-- Специфичные пути сужают выбор, fallback — если хаб обновится.
local STEP1 = {
    name = "HOMEPAGE_BUTTON",
    specific_path = {"MAIN_UI", "MAIN_ZONES", "HOME_TAB", "Functions",
                     "HOME_PAGER", "PAGES_HOLDER", "PAGE_SHORTCUTS"},
    fallback_paths = {"MAIN_UI", "MAIN_ZONES"},
}
local STEP2 = {
    name = "Button",
    specific_path = {"MAIN_UI", "MAIN_ZONES", "PAGES_TAB", "ANCHOR", "MINI_PAGES"},
    fallback_paths = {"MINI_PAGES"},
}
local TEXTBOX = {
    name = "Box",
    placeholder_substr = "try to text",
    specific_path = {"MAIN_UI", "MAIN_ZONES", "PAGES_TAB", "ANCHOR",
                     "CONFIG_PAGES", "MINI_11_CONFIG_4", "ScrollingFrame",
                     "Tab2", "Textbox2"},
    fallback_paths = {"CONFIG_PAGES", "Textbox2"},
}

print("[HOHO] === START ===")

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

-- 3. Персонаж (pcall — если Character успел сброситься)
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
-- 6. Hub helpers + динамический выбор
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

local function pathMatches(obj, segments)
    if not segments or #segments == 0 then return true end
    local full = obj:GetFullName()
    local pos = 1
    for _, seg in ipairs(segments) do
        local found = full:find(seg, pos, true)
        if not found then return false end
        pos = found + #seg
    end
    return true
end

local function collectCandidates(class_check, name, segments)
    local out = {}
    for _, obj in ipairs(CoreGui:GetDescendants()) do
        if class_check(obj) and obj.Name == name and pathMatches(obj, segments) then
            table.insert(out, obj)
        end
    end
    return out
end

local function pickRightmost(list)
    if #list == 0 then return nil end
    local best = list[1]
    for i = 2, #list do
        if list[i].AbsolutePosition.X > best.AbsolutePosition.X then
            best = list[i]
        end
    end
    return best
end

local function isButton(obj)
    return obj:IsA("TextButton") or obj:IsA("ImageButton")
end

local function pickBestButton(cfg)
    -- 1) специфичный путь
    local c = collectCandidates(isButton, cfg.name, cfg.specific_path)
    if #c >= 1 then return pickRightmost(c) end
    -- 2) fallback путь
    c = collectCandidates(isButton, cfg.name, cfg.fallback_paths)
    if #c >= 1 then return pickRightmost(c) end
    -- 3) любой по имени
    c = collectCandidates(isButton, cfg.name, nil)
    return pickRightmost(c)
end

local function pickBestTextBox(cfg)
    -- 1) специфичный путь
    local function isTB(o) return o:IsA("TextBox") end
    local c = collectCandidates(isTB, cfg.name, cfg.specific_path)
    if #c >= 1 then return c[1] end
    -- 2) fallback путь
    c = collectCandidates(isTB, cfg.name, cfg.fallback_paths)
    if #c >= 1 then return c[1] end
    -- 3) по placeholder
    local ph_list = {}
    for _, obj in ipairs(CoreGui:GetDescendants()) do
        if obj:IsA("TextBox") then
            local ph = (obj.PlaceholderText or ""):lower()
            if ph:find(cfg.placeholder_substr, 1, true) then
                table.insert(ph_list, obj)
            end
        end
    end
    if #ph_list >= 1 then return ph_list[1] end
    return nil
end

local function dumpButtons(name)
    print(string.format("[HOHO DEBUG] Все %s:", name))
    for _, obj in ipairs(CoreGui:GetDescendants()) do
        if isButton(obj) and obj.Name == name then
            print(string.format("[HOHO DEBUG]   pos=(%.1f, %.1f) vis=%s path=%s",
                obj.AbsolutePosition.X, obj.AbsolutePosition.Y,
                tostring(obj.Visible), obj:GetFullName()))
        end
    end
end

local function dumpTextBoxes()
    print("[HOHO DEBUG] Все TextBox:")
    for _, obj in ipairs(CoreGui:GetDescendants()) do
        if obj:IsA("TextBox") then
            print(string.format("[HOHO DEBUG]   pos=(%.1f, %.1f) ph='%s' path=%s",
                obj.AbsolutePosition.X, obj.AbsolutePosition.Y,
                tostring(obj.PlaceholderText), obj:GetFullName()))
        end
    end
end

-- Ждём следующую кнопку после клика, пересчитывая позицию каждый раз
local function activateUntil(cfgTarget, cfgNext, tag)
    tag = tag or cfgTarget.name
    local attempt = 0
    local dumped = false
    while true do
        attempt += 1
        local btn = pickBestButton(cfgTarget)
        if not btn then
            print(string.format("[HOHO] %s #%d: target не найден, ждём...", tag, attempt))
            if not dumped then
                dumped = true
                dumpButtons(cfgTarget.name)
            end
            task.wait(1)
        else
            print(string.format("[HOHO] %s #%d: активирую (%.1f, %.1f) %s",
                tag, attempt,
                btn.AbsolutePosition.X, btn.AbsolutePosition.Y,
                btn:GetFullName()))
            local ok = fireSequence(btn)
            if not ok then
                pcall(function() btn:Click() end)
                task.wait(0.15)
                pcall(function() btn:Activate() end)
            end
        end
        local t0 = tick()
        while tick() - t0 < RETRY_DELAY do
            local nxt = pickBestButton(cfgNext)
            if nxt then
                print(string.format("[HOHO] %s: ✓ следующий маркер через %.1fs", tag, tick() - t0))
                return nxt
            end
            task.wait(0.2)
        end
        print(string.format("[HOHO] %s: следующий маркер не появился за %dс — повтор", tag, RETRY_DELAY))
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
        warn("[HOHO] Ошибка: TextBox исчез до вставки!")
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
        local found = false
        for _, obj in ipairs(CoreGui:GetDescendants()) do
            if isButton(obj) and obj.Name == "HOMEPAGE_BUTTON" then
                found = true; break
            end
        end
        if found then
            print(string.format("[HOHO] UI появился через %.1fс", tick() - t0))
            break
        end
        task.wait(0.5)
    end

    print("[HOHO] --- ШАГ 1: HOMEPAGE_BUTTON ---")
    activateUntil(STEP1, STEP2, "STEP1")

    print("[HOHO] --- ШАГ 2: Button ---")
    local attempt2, targetBox = 0, nil
    while not targetBox do
        attempt2 += 1
        local btn2 = pickBestButton(STEP2)
        if btn2 then
            print(string.format("[HOHO] STEP2 #%d: активирую (%.1f, %.1f)",
                attempt2, btn2.AbsolutePosition.X, btn2.AbsolutePosition.Y))
            local ok = fireSequence(btn2)
            if not ok then
                pcall(function() btn2:Click() end)
                task.wait(0.15)
                pcall(function() btn2:Activate() end)
            end
        else
            print(string.format("[HOHO] STEP2 #%d: Button не найден", attempt2))
            dumpButtons(STEP2.name)
        end
        local t1 = tick()
        while tick() - t1 < RETRY_DELAY do
            targetBox = pickBestTextBox(TEXTBOX)
            if targetBox then
                print(string.format("[HOHO] STEP2: ✓ TextBox через %.1fс", tick() - t1))
                break
            end
            task.wait(0.2)
        end
        if not targetBox then
            print("[HOHO] STEP2: TextBox не появился, повтор...")
            dumpTextBoxes()
        end
    end

    print("[HOHO] --- ШАГ 3: Вставка ---")
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
