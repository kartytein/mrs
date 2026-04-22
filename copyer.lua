-- ===== ДИАГНОСТИКА ДВИЖЕНИЯ ЛОДКИ =====
-- Добавьте этот код в конец вашего основного скрипта (перед последним print).
-- Он будет каждые 0.5 секунды выводить состояние и фиксировать изменения.

local player = game.Players.LocalPlayer
local lastState = {}

task.spawn(function()
    while true do
        task.wait(0.5)
        local char = player.Character
        if not char then
            print("[DIAG] Персонаж отсутствует")
            continue
        end
        local hrp = char:FindFirstChild("HumanoidRootPart")
        local humanoid = char:FindFirstChild("Humanoid")
        local bv = hrp and hrp:FindFirstChildWhichIsA("BodyVelocity")
        local seatPart = humanoid and humanoid.SeatPart
        
        -- Получаем глобальные переменные из основного скрипта (если они доступны)
        local myBoat = _G.__myBoat or (rawget(_G, "myBoat") or "nil")
        local currentDirection = _G.__currentDirection or (rawget(_G, "currentDirection") or "nil")
        
        local state = {
            sit = humanoid and humanoid.Sit or false,
            seatPart = seatPart and seatPart:GetFullName() or "nil",
            bvExists = bv ~= nil,
            bvSpeed = bv and bv.Velocity or Vector3.new(0,0,0),
            hrpPos = hrp and hrp.Position or nil,
            boatExists = myBoat and myBoat.Parent ~= nil,
            direction = currentDirection,
        }
        
        -- Вывод изменений
        for k, v in pairs(state) do
            if lastState[k] ~= v then
                print(string.format("[DIAG] %s: %s -> %s", k, tostring(lastState[k]), tostring(v)))
            end
        end
        
        -- Критические ситуации
        if state.sit and not state.bvExists then
            print("[DIAG] КРИТИЧЕСКАЯ ОШИБКА: сидим, но BodyVelocity отсутствует!")
        end
        if state.sit and state.bvExists and state.bvSpeed.X == 0 then
            print("[DIAG] ВНИМАНИЕ: сидим, BodyVelocity есть, но скорость X = 0")
        end
        if state.sit and state.bvExists and state.bvSpeed.X ~= 0 and state.bvSpeed.X ~= (state.direction == -1 and -BOAT_SPEED or BOAT_SPEED) then
            print(string.format("[DIAG] ВНИМАНИЕ: скорость BodyVelocity (%s) не соответствует направлению (%s)", state.bvSpeed.X, state.direction))
        end
        
        lastState = state
    end
end)
