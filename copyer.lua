-- Трекер проблем (запустить отдельно)
local player = game.Players.LocalPlayer
local lastSit = nil
local lastSeatPart = nil
local lastBVPresent = nil
local lastBVSpeed = nil
local lastBoatPos = nil
local lastCharPos = nil

task.spawn(function()
    while true do
        task.wait(0.5)
        local char = player.Character
        if not char then
            print("[TRACKER] Персонаж отсутствует")
            continue
        end
        local humanoid = char:FindFirstChild("Humanoid")
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if not humanoid or not hrp then
            print("[TRACKER] Нет Humanoid или HRP")
            continue
        end

        local sit = humanoid.Sit
        local seatPart = humanoid.SeatPart
        local bv = hrp:FindFirstChildWhichIsA("BodyVelocity")
        local bvPresent = bv ~= nil
        local bvSpeed = bv and bv.Velocity or Vector3.new(0,0,0)
        local charPos = hrp.Position

        -- Поиск лодки (если есть)
        local boat = nil
        if seatPart then
            boat = seatPart:FindFirstAncestorWhichIsA("Model")
        end
        local boatPos = boat and (boat.PrimaryPart or boat:FindFirstChildWhichIsA("BasePart")) and boat:GetPivot().Position or nil

        -- Проверка изменений
        if sit ~= lastSit then
            print("[TRACKER] Sit изменился на", sit)
            lastSit = sit
        end
        if seatPart ~= lastSeatPart then
            print("[TRACKER] SeatPart изменился на", seatPart and seatPart:GetFullName() or "nil")
            lastSeatPart = seatPart
        end
        if bvPresent ~= lastBVPresent then
            print("[TRACKER] BodyVelocity присутствует:", bvPresent)
            lastBVPresent = bvPresent
        end
        if bvSpeed.X ~= lastBVSpeed then
            print("[TRACKER] Скорость BodyVelocity изменилась:", bvSpeed.X)
            lastBVSpeed = bvSpeed.X
        end

        -- Критические события
        if sit and seatPart and bvPresent and bvSpeed.X == 0 then
            print("[TRACKER] ВНИМАНИЕ: персонаж сидит, но скорость BodyVelocity = 0")
        end
        if sit and not bvPresent then
            print("[TRACKER] ВНИМАНИЕ: персонаж сидит, но BodyVelocity отсутствует")
        end
        if sit and not seatPart then
            print("[TRACKER] ВНИМАНИЕ: персонаж сидит, но SeatPart = nil")
        end

        -- Отслеживание движения лодки
        if boatPos and lastBoatPos then
            local delta = (boatPos - lastBoatPos).Magnitude
            if delta < 0.1 and sit and bvPresent and bvSpeed.X ~= 0 then
                print("[TRACKER] ВНИМАНИЕ: лодка не двигается, хотя скорость задана")
            end
        end
        lastBoatPos = boatPos
        lastCharPos = charPos
    end
end)
