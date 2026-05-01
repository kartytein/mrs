-- ===== КОРОТКИЙ ФИНАЛЬНЫЙ СКРИПТ (БЕЗ ОШИБОК) =====
local player = game.Players.LocalPlayer
local playerName = player.Name
local HttpService = game:GetService("HttpService")
local webhook = "https://discord.com/api/webhooks/1469730327617601880/E_2KCQuiMpbsp24Q27J9n2PKhj-a4nexepAs1rAfeYrnDgw2QHO5t1FBjTzuZqPF-Wgh"

-- Коллизии
task.spawn(function()
    while true do
        local c = player.Character
        if c then
            for _, p in ipairs(c:GetDescendants()) do if p:IsA("BasePart") then p.CanCollide = false end end
            local lo = c:FindFirstChild("LowerTorso"); if lo then lo.CanCollide = false end
            local up = c:FindFirstChild("UpperTorso"); if up then up.CanCollide = false end
        end
        task.wait(0.3)
    end
end)

-- Перемещение шагами (CFrame)
local function moveStep(target, speed, keepY)
    local c = player.Character; if not c then return end
    local h = c:FindFirstChild("HumanoidRootPart"); local hu = c:FindFirstChild("Humanoid")
    if not h or not hu then return end
    local old = hu.PlatformStand; hu.PlatformStand = true
    local step = 0.05; local stepSz = speed * step
    while (h.Position - target).Magnitude > 0.5 do
        local dir = (target - h.Position).Unit
        local mv = math.min(stepSz, (target - h.Position).Magnitude)
        local newp = h.Position + dir * mv
        if keepY then newp = Vector3.new(newp.X, target.Y, newp.Z) end
        h.CFrame = CFrame.new(newp)
        task.wait(step)
    end
    h.CFrame = CFrame.new(target)
    hu.PlatformStand = old
end

-- Поиск лодки
local function myBoat()
    local bts = workspace:FindFirstChild("Boats"); if not bts then return nil end
    for _, b in ipairs(bts:GetChildren()) do
        if b:IsA("Model") and b:FindFirstChildWhichIsA("VehicleSeat") then
            if b:GetAttribute("Owner") == playerName then return b end
            local o = b:FindFirstChild("Owner"); if o and tostring(o.Value) == playerName then return b end
        end
    end
    return nil
end

-- Покупка
local function buy()
    local rs = game:GetService("ReplicatedStorage"); if rs then local r = rs:FindFirstChild("Remotes"); if r then local c = r:FindFirstChild("CommF_"); if c then pcall(function() c:InvokeServer("BuyBoat", "Guardian") end) end end end
end

-- Детектор фруктов
local sent = {}
local function sendFruit(n)
    local msg = { content = player.Name .. " получил '" .. n .. "'!", username = "Инвентарь" }
    pcall(function() HttpService:RequestAsync({ Url = webhook, Method = "POST", Headers = {["Content-Type"]="application/json"}, Body = HttpService:JSONEncode(msg) }) end)
end
local function check(it)
    if it:IsA("Tool") and it.Name:find("Fruit") then if not sent[it.Name] then sent[it.Name]=true; sendFruit(it.Name) end end
end
task.spawn(function()
    local c = player.Character or player.CharacterAdded:Wait()
    local bp = player:WaitForChild("Backpack")
    bp.ChildAdded:Connect(function(it) task.wait(0.1); check(it) end)
    c.ChildAdded:Connect(function(it) if it:IsA("Tool") then task.wait(0.1); check(it) end end)
end)

-- Анти-idle
task.spawn(function()
    local cam = workspace.CurrentCamera; local orig = cam.CFrame
    while true do task.wait(300); cam.CFrame = cam.CFrame * CFrame.Angles(0, math.rad(1), 0); task.wait(0.5); cam.CFrame = orig end
end)

-- Движение лодки
local boat, seat, root, hum, hrp, bv = nil, nil, nil, nil, nil, nil
local dir = -1
local Xmin = -77389.3; local Xmax = -47968.4
local SpdX = 250; local SpdY = -2; local SpdZ = -2
local TargetY = 100
local moving = false; local moveThread = nil

local function ensureBV()
    local c = player.Character; if not c then return end
    local u = c:FindFirstChild("UpperTorso"); if not u then return end
    local sx = dir * SpdX
    if bv and bv.Parent then bv.Velocity = Vector3.new(sx, SpdY, SpdZ)
    else if bv then bv:Destroy() end; bv = Instance.new("BodyVelocity"); bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge); bv.Parent = u; bv.Velocity = Vector3.new(sx, SpdY, SpdZ) end
end

local function stopMove()
    moving = false; if moveThread then pcall(task.cancel, moveThread); moveThread = nil end; if bv then bv:Destroy(); bv = nil end
end

local function startMove()
    if moving then return end; moving = true
    moveThread = task.spawn(function()
        local c = player.Character; if not c then moving = false; return end
        local u = c:FindFirstChild("UpperTorso"); if not u then moving = false; return end
        if bv then bv:Destroy() end
        bv = Instance.new("BodyVelocity"); bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge); bv.Parent = u; bv.Velocity = Vector3.new(0,0,0)
        if root then local p = root.Position; if math.abs(p.Y - TargetY) > 0.5 then root.CFrame = CFrame.new(p.X, TargetY, p.Z) end end
        local sx = dir * SpdX; bv.Velocity = Vector3.new(sx, SpdY, SpdZ)
        while moving do
            if not (hum and hum.Sit and hum.SeatPart == seat) then stopMove(); break end
            if root then
                local p = root.Position
                if math.abs(p.Y - TargetY) > 0.5 then root.CFrame = CFrame.new(p.X, TargetY, p.Z) end
                if p.X <= Xmin and dir == -1 then dir = 1; ensureBV()
                elseif p.X >= Xmax and dir == 1 then dir = -1; ensureBV() end
            end
            if bv and bv.Parent then local v = bv.Velocity; bv.Velocity = Vector3.new(v.X, v.Y - 0.0001, v.Z - 0.0001) end
            task.wait(0.05)
        end
    end)
end

-- Магнит (плавное следование)
task.spawn(function()
    while true do
        task.wait(0.05)
        local b = myBoat(); if not b then continue end
        local s = b:FindFirstChildWhichIsA("VehicleSeat"); if not s then continue end
        local c = player.Character; if not c then continue end
        local h = c:FindFirstChild("Humanoid"); local r = c:FindFirstChild("HumanoidRootPart"); if not h or not r then continue end
        if h.Sit and h.SeatPart == s then continue end
        local target = s.Position + Vector3.new(0, 2.5, 0)
        local dist = (r.Position - target).Magnitude
        if dist > 0.3 then
            local dir = (target - r.Position).Unit
            local step = math.min(150 * 0.05, dist)
            r.CFrame = CFrame.new(r.Position + dir * step)
        else
            r.CFrame = CFrame.new(target)
        end
    end
end)

-- Остров
local islandMode = false
local function findIsland()
    for _, obj in ipairs(workspace:GetDescendants()) do if obj.Name and obj.Name:lower():find("prehistoricisland") then return obj end end
    return nil
end
task.spawn(function()
    local cooldown = false; local cdTimer = 0
    while true do
        task.wait(0.5)
        local isl = findIsland()
        if isl and not islandMode then
            if not (cooldown and tick() - cdTimer < 10) then cooldown = false end
        end
        if isl and not islandMode then
            islandMode = true; stopMove()
            if hum then hum.Sit = false end
            task.wait(0.5)
            local tgt = isl:GetPivot().Position + Vector3.new(0,30,0)
            moveStep(tgt, 200, true)
            local start = os.clock(); local eggSeen = false
            while islandMode do
                if os.clock() - start >= 600 then break end
                local core = workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("Prehistoricisland") and workspace.Map.Prehistoricisland:FindFirstChild("Core")
                local egg = core and core:FindFirstChild("SpawnedDragonEggs") and core.SpawnedDragonEggs:FindFirstChild("DragonEgg")
                if egg and not eggSeen then eggSeen = true; print("[ОСТРОВ] DragonEgg появился") end
                if eggSeen and not egg then print("[ОСТРОВ] DragonEgg исчез"); break end
                task.wait(1)
            end
            islandMode = false; cooldown = true; cdTimer = tick()
            local nb = myBoat()
            if nb then
                boat = nb; seat = nb:FindFirstChildWhichIsA("VehicleSeat"); root = nb.PrimaryPart or nb:FindFirstChildWhichIsA("BasePart")
                if seat and root then
                    for _, p in ipairs(nb:GetDescendants()) do if p:IsA("BasePart") then p.CanCollide = false end end
                    local nat = nb:FindFirstChild("Script"); if nat then nat.Disabled = true end
                end
            else
                moveStep(Vector3.new(-16917,9.1,447),150,true); buy(); task.wait(3)
                for i=1,10 do nb = myBoat(); if nb then break end; task.wait(1) end
                if nb then
                    boat = nb; seat = nb:FindFirstChildWhichIsA("VehicleSeat"); root = nb.PrimaryPart or nb:FindFirstChildWhichIsA("BasePart")
                    if seat and root then
                        for _, p in ipairs(nb:GetDescendants()) do if p:IsA("BasePart") then p.CanCollide = false end end
                        local nat = nb:FindFirstChild("Script"); if nat then nat.Disabled = true end
                    end
                end
            end
            task.wait(2); cooldown = false
        end
    end
end)

-- Главный монитор
task.spawn(function()
    while true do
        task.wait(0.5)
        local c = player.Character
        if not c then
            if moving then stopMove() end
            boat, seat, root = nil, nil, nil
            player.CharacterAdded:Wait()
            c = player.Character
            hum = c:FindFirstChild("Humanoid"); hrp = c:FindFirstChild("HumanoidRootPart")
            task.wait(1)
        end
        if not hum or not hrp then hum = c:FindFirstChild("Humanoid"); hrp = c:FindFirstChild("HumanoidRootPart") end
        if not boat or not boat.Parent then
            boat = myBoat()
            if boat then
                seat = boat:FindFirstChildWhichIsA("VehicleSeat")
                root = boat.PrimaryPart or boat:FindFirstChildWhichIsA("BasePart")
                if seat and root then
                    for _, p in ipairs(boat:GetDescendants()) do if p:IsA("BasePart") then p.CanCollide = false end end
                    local nat = boat:FindFirstChild("Script"); if nat then nat.Disabled = true end
                end
            end
        end
    end
end)

-- Первичный запуск
task.spawn(function()
    local rs = game:GetService("ReplicatedStorage")
    local remotes = rs and rs:FindFirstChild("Remotes")
    if remotes then
        local commF = remotes:FindFirstChild("CommF_")
        if commF then pcall(function() commF:InvokeServer("SetTeam", "Marines") end) end
        local mods = rs:FindFirstChild("Modules")
        local ev = mods and mods:FindFirstChild("RE/OnEventServiceActivity")
        if ev then pcall(function() ev:FireServer() end) end
    end

    boat = myBoat()
    if not boat then
        moveStep(Vector3.new(-16917,9.1,447),150,true)
        buy()
        task.wait(3)
        for i=1,10 do boat = myBoat(); if boat then break end; task.wait(1) end
        if not boat then error("Лодка не найдена") end
        seat = boat:FindFirstChildWhichIsA("VehicleSeat")
        root = boat.PrimaryPart or boat:FindFirstChildWhichIsA("BasePart")
        if not seat or not root then error("Нет сиденья/части") end
        for _, p in ipairs(boat:GetDescendants()) do if p:IsA("BasePart") then p.CanCollide = false end end
        local nat = boat:FindFirstChild("Script"); if nat then nat.Disabled = true end
    end

    local c = player.Character or player.CharacterAdded:Wait()
    hrp = c:FindFirstChild("HumanoidRootPart"); hum = c:FindFirstChild("Humanoid")
    if not hrp or not hum then return
    local target = seat.Position + Vector3.new(0,2.5,0)
    moveStep(target,150,true)
    hum.Sit = true
    if root then local p = root.Position; root.CFrame = CFrame.new(p.X, TargetY, p.Z) end
    startMove()
end)

print("Скрипт успешно запущен")
