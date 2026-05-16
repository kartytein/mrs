-- ========== ДИАГНОСТИК ДВИГАТЕЛЕЙ (ИСПРАВЛЕННЫЙ) ==========
local player = game.Players.LocalPlayer
local playerName = player.Name

local function getTimestamp()
    local now = os.time()
    local ms = tick() % 1 * 1000
    return string.format("%s.%03d", os.date("%H:%M:%S", now), ms)
end

local function watchMotor(instance, parentName)
    if not instance then return end
    local className = instance.ClassName
    local props = {}
    if className == "BodyVelocity" then
        props = {"Velocity", "MaxForce"}
    elseif className == "BodyPosition" then
        props = {"Position", "MaxForce"}
    elseif className == "BodyThrust" then
        props = {"Force", "Location", "MaxForce"}
    elseif className == "AlignPosition" then
        props = {"Position", "MaxForce", "Responsiveness"}
    elseif className == "LinearVelocity" then
        props = {"VectorVelocity", "MaxForce"}
    else
        return
    end
    
    print(string.format("[%s] НАЙДЕН %s на %s", getTimestamp(), className, parentName))
    for _, prop in ipairs(props) do
        local val = instance[prop]
        local valStr = type(val) == "Vector3" and string.format("(%.1f, %.1f, %.1f)", val.X, val.Y, val.Z) or tostring(val)
        print(string.format("  └─ %s = %s", prop, valStr))
    end
    
    for _, prop in ipairs(props) do
        instance:GetPropertyChangedSignal(prop):Connect(function()
            local newVal = instance[prop]
            local newStr = type(newVal) == "Vector3" and string.format("(%.1f, %.1f, %.1f)", newVal.X, newVal.Y, newVal.Z) or tostring(newVal)
            print(string.format("[%s] %s на %s: %s изменён на %s", getTimestamp(), className, parentName, prop, newStr))
        end)
    end
end

local function scanForMotors(container, containerName)
    if not container then return end
    for _, child in ipairs(container:GetDescendants()) do
        if child:IsA("BodyVelocity") or child:IsA("BodyPosition") or child:IsA("BodyThrust") or 
           child:IsA("AlignPosition") or child:IsA("LinearVelocity") then
            watchMotor(child, containerName .. "/" .. child.Parent.Name)
        end
    end
end

local function watchContainer(container, containerName)
    if not container then return end
    scanForMotors(container, containerName)
    container.DescendantAdded:Connect(function(desc)
        if desc:IsA("BodyVelocity") or desc:IsA("BodyPosition") or desc:IsA("BodyThrust") or 
           desc:IsA("AlignPosition") or desc:IsA("LinearVelocity") then
            watchMotor(desc, containerName .. "/" .. desc.Parent.Name)
        end
    end)
end

local function startDiagnostic()
    print("[ДИАГНОСТ] Начинаю наблюдение...")
    
    local function watchCharacter()
        local char = player.Character
        if char then
            watchContainer(char, "Character")
        end
    end
    watchCharacter()
    player.CharacterAdded:Connect(watchCharacter)
    
    local function findAndWatchBoat()
        local boats = workspace:FindFirstChild("Boats")
        if not boats then return nil end
        for _, boat in ipairs(boats:GetChildren()) do
            if boat:IsA("Model") then
                local owner = boat:GetAttribute("Owner") or (boat:FindFirstChild("Owner") and boat.Owner.Value)
                if owner == playerName then
                    print("[ДИАГНОСТ] Найдена моя лодка: " .. boat.Name)
                    watchContainer(boat, "Boat/" .. boat.Name)
                    return boat
                end
            end
        end
        return nil
    end
    
    -- Периодический поиск лодки
    task.spawn(function()
        while true do
            findAndWatchBoat()
            task.wait(3)
        end
    end)
    
    local boatsFolder = workspace:FindFirstChild("Boats")
    if boatsFolder then
        boatsFolder.ChildAdded:Connect(function(boat)
            if boat:IsA("Model") then
                local owner = boat:GetAttribute("Owner") or (boat:FindFirstChild("Owner") and boat.Owner.Value)
                if owner == playerName then
                    print("[ДИАГНОСТ] Появилась моя лодка: " .. boat.Name)
                    watchContainer(boat, "Boat/" .. boat.Name)
                end
            end
        end)
    end
end

task.wait(2)
startDiagnostic()
print("[ДИАГНОСТ] Скрипт активен. Начинайте движение эталонным скриптом.")
