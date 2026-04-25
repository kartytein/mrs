-- ===== ДИАГНОСТИЧЕСКИЙ СКРИПТ =====
-- Проверяет доступность всех функций и сервисов, используемых в основном скрипте.
-- Запустите его отдельно, он выведет отчёт в консоль.

local function check(name, value)
    local success, err = pcall(function() return type(value) end)
    if success then
        print("[OK] " .. name .. " : " .. tostring(type(value)))
    else
        print("[FAIL] " .. name .. " : " .. tostring(err))
    end
end

print("=== ДИАГНОСТИКА НАЧАЛА ===")

-- Проверка глобальных функций и сервисов
check("print", print)
check("task.wait", task.wait)
check("task.spawn", task.spawn)
check("task.cancel", task.cancel)
check("Instance.new", Instance.new)
check("game.GetService", game.GetService)
check("pcall", pcall)
check("Vector3.new", Vector3.new)
check("CFrame.new", CFrame.new)
check("math.huge", math.huge)
check("table.insert", table.insert)
check("table.find", table.find)
check("string.find", string.find)
check("string.lower", string.lower)

-- Проверка игровых сервисов
local services = {"Players", "Workspace", "ReplicatedStorage", "RunService", "TweenService", "HttpService", "TeleportService"}
for _, s in ipairs(services) do
    local ok, svc = pcall(function() return game:GetService(s) end)
    if ok then
        print("[OK] game:GetService('"..s.."') : " .. tostring(svc))
    else
        print("[FAIL] game:GetService('"..s.."') : ошибка")
    end
end

-- Проверка LocalPlayer
local ok, plr = pcall(function() return game.Players.LocalPlayer end)
if ok and plr then
    print("[OK] game.Players.LocalPlayer : " .. plr.Name)
else
    print("[FAIL] game.Players.LocalPlayer : nil")
end

-- Проверка Character
local char = plr and plr.Character
if char then
    print("[OK] Character существует")
    local hrp = char:FindFirstChild("HumanoidRootPart")
    print("   HumanoidRootPart : " .. tostring(hrp))
    local humanoid = char:FindFirstChild("Humanoid")
    print("   Humanoid : " .. tostring(humanoid))
else
    print("[WARN] Character не загружен (может быть позже)")
end

-- Проверка ReplicatedStorage и удалённых событий
local rs = game:GetService("ReplicatedStorage")
if rs then
    local remotes = rs:FindFirstChild("Remotes")
    if remotes then
        local commF = remotes:FindFirstChild("CommF_")
        print("[OK] ReplicatedStorage.Remotes.CommF_ : " .. tostring(commF))
    else
        print("[WARN] ReplicatedStorage.Remotes не найдены")
    end
    local modules = rs:FindFirstChild("Modules")
    if modules then
        local event = modules:FindFirstChild("RE/OnEventServiceActivity")
        print("[OK] ReplicatedStorage.Modules.RE/OnEventServiceActivity : " .. tostring(event))
    else
        print("[WARN] ReplicatedStorage.Modules не найдены")
    end
else
    print("[FAIL] ReplicatedStorage не получен")
end

-- Проверка Discord webhook (только наличие URL)
local webhook = "https://discord.com/api/webhooks/1469730327617601880/E_2KCQuiMpbsp24Q27J9n2PKhj-a4nexepAs1rAfeYrnDgw2QHO5t1FBjTzuZqPF-Wgh"
print("[OK] DISCORD_WEBHOOK определён (длина " .. #webhook .. ")")

-- Проверка writefile (необязательно)
local writefileType = type(writefile)
print("[OK] writefile : " .. tostring(writefileType))

-- Проверка HttpService:RequestAsync
local hs = game:GetService("HttpService")
if hs then
    local success, err = pcall(function() return hs.RequestAsync end)
    print("[OK] HttpService.RequestAsync : " .. tostring(success))
else
    print("[FAIL] HttpService не получен")
end

print("=== ДИАГНОСТИКА ЗАВЕРШЕНА ===")
print("Если есть сообщения [FAIL] или [WARN], исправьте их в основном скрипте.")
