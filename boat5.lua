-- ===== МАГНИТ (ИСПРАВЛЕННЫЙ) =====
local player = game.Players.LocalPlayer
local stepDur = 0.05
local walkSpd = 150
local stepSz = walkSpd * stepDur

local function moveSmooth(pos, keepY)
    local c = player.Character
    if not c then return end
    local h = c:FindFirstChild("HumanoidRootPart")
    local hu = c:FindFirstChild("Humanoid")
    if not h or not hu then return end
    local old = hu.PlatformStand
    hu.PlatformStand = true
    while (h.Position - pos).Magnitude > 0.5 do
        local dir = (pos - h.Position).Unit
        local m = math.min(stepSz, (pos - h.Position).Magnitude)
        local np = h.Position + dir * m
        if keepY then np = Vector3.new(np.X, pos.Y, np.Z) end
        h.CFrame = CFrame.new(np)
        task.wait(stepDur)
    end
    h.CFrame = CFrame.new(pos)
    hu.PlatformStand = old
end

local function findBoat()
    local boats = workspace:FindFirstChild("Boats")
    if not boats then return nil end
    for _, b in ipairs(boats:GetChildren()) do
        if b:IsA("Model") and b:FindFirstChildWhichIsA("VehicleSeat") then
            local o = b:GetAttribute("Owner")
            if o == player.Name then return b end
            local ow = b:FindFirstChild("Owner")
            if ow and tostring(ow.Value) == player.Name then return b end
        end
    end
end

local boat, seat
task.spawn(function()
    while true do
        task.wait(0.2)
        if not boat or not boat.Parent then
            boat = findBoat()
            if boat then seat = boat:FindFirstChildWhichIsA("VehicleSeat") end
        end
        if not boat or not seat then continue
        local c = player.Character
        if not c then continue
        local hu = c:FindFirstChild("Humanoid")
        local h = c:FindFirstChild("HumanoidRootPart")
        if not hu or not h then continue
        if not (hu.Sit and hu.SeatPart == seat) then
            local target = seat.Position + Vector3.new(0, 2.5, 0)
            moveSmooth(target, true)
            hu.Sit = true
            task.wait(0.3)
        end
    end
end)
print("Магнит работает")
