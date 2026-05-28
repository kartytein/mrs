-- ===== ПОЛНЫЙ СКРИПТ (ВЕРСИЯ 8.9) =====
-- Исправлены: таймаут + детектор зависания в moveStep, проверка подъёма над островом,
-- убрана лишняя задержка в магните.

local player = game.Players.LocalPlayer
local playerName = player.Name
local HttpService = game:GetService("HttpService")
local DISCORD_WEBHOOK = "https://discord.com/api/webhooks/1469730327617601880/E_2KCQuiMpbsp24Q27J9n2PKhj-a4nexepAs1rAfeYrnDgw2QHO5t1FBjTzuZqPF-Wgh"

-- ========== 1. ПОСТОЯННОЕ ОТКЛЮЧЕНИЕ КОЛЛИЗИЙ ==========
task.spawn(function()
	while true do
		local char = player.Character
		if char then
			for _, part in ipairs(char:GetDescendants()) do
				if part:IsA("BasePart") then part.CanCollide = false end
			end
		end
		task.wait(0.3)
	end
end)

-- ========== 2. ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ ==========
local BOAT_BUY_POS = Vector3.new(-16917.0, 9.1, 447.0)

-- moveStep с таймаутом и детектором зависания
local function moveStep(targetPos, speed, keepY, timeout)
	timeout = timeout or 30
	local char = player.Character
	if not char then return false end
	local hrp = char:FindFirstChild("HumanoidRootPart")
	if not hrp then return false end

	for _, part in ipairs(char:GetDescendants()) do
		if part:IsA("BasePart") then part.CanCollide = false end
	end

	local bv = Instance.new("BodyVelocity")
	bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
	bv.Velocity = Vector3.zero
	bv.Parent = hrp

	local STEP = 14
	local MAX_STEPS = 5000
	local startTime = tick()
	local lastDist = math.huge
	local stuckTime = 0

	for i = 1, MAX_STEPS do
		if tick() - startTime > timeout then break end

		local current = hrp.Position
		local diff = targetPos - current
		local dist = diff.Magnitude
		if dist < 1 then break end

		-- детектор зависания: если расстояние не уменьшается 3 секунды – выходим
		if dist >= lastDist - 0.1 then
			stuckTime = stuckTime + 0.02
			if stuckTime > 3 then
				warn("[MOVE] Застревание, прерываем")
				break
			end
		else
			stuckTime = 0
		end
		lastDist = dist

		local dir = diff.Unit
		local move = dir * math.min(STEP, dist)
		local newPos = current + move
		if keepY then
			newPos = Vector3.new(newPos.X, targetPos.Y, newPos.Z)
		end
		hrp.CFrame = CFrame.new(newPos)
		task.wait(0.02)
	end

	bv:Destroy()
	local finalDist = (hrp.Position - targetPos).Magnitude
	return finalDist < 2
end

-- safeMoveStep с повторами
local function safeMoveStep(targetPos, speed, keepY, maxAttempts, timeout)
	maxAttempts = maxAttempts or 3
	for attempt = 1, maxAttempts do
		print("[MOVE] Попытка " .. attempt .. " достичь " .. tostring(targetPos))
		if moveStep(targetPos, speed, keepY, timeout) then
			return true
		end
		if attempt < maxAttempts then
			local char = player.Character
			if char and char:FindFirstChild("HumanoidRootPart") then
				local hrp = char.HumanoidRootPart
				hrp.CFrame = hrp.CFrame + Vector3.new(0, 5, 0)
				task.wait(0.5)
			end
			print("[MOVE] Не удалось, повторяем...")
		end
	end
	return false
end

-- Посадка на сиденье
local function forceSitOnSeat(targetSeat, maxAttempts)
	maxAttempts = maxAttempts or 3
	for attempt = 1, maxAttempts do
		local char = player.Character
		if not char then continue end
		local hum = char:FindFirstChild("Humanoid")
		local hrp = char:FindFirstChild("HumanoidRootPart")
		if not hum or not hrp then continue end
		local targetPos = targetSeat.Position + Vector3.new(0, 2.5, 0)
		safeMoveStep(targetPos, 300, true, 2, 5)
		hum.Sit = true
		task.wait(0.5)
		if hum.Sit and hum.SeatPart == targetSeat then
			return true
		else
			hum.Sit = false
			local jump = hum:FindFirstChild("Jump")
			if jump then pcall(function() jump:Fire() end) end
			task.wait(0.5)
		end
	end
	return false
end

local function moveToBuyPoint()
	return safeMoveStep(BOAT_BUY_POS, 200, true, 3, 10)
end

local function buyBoatOnly()
	local args = { "BuyBoat", "Guardian" }
	local rs = game:GetService("ReplicatedStorage")
	local commF = rs and rs:FindFirstChild("Remotes") and rs.Remotes:FindFirstChild("CommF_")
	if commF then
		pcall(function() commF:InvokeServer(unpack(args)) end)
		print("[ПОКУПКА] Лодка заказана")
	else
		warn("[ПОКУПКА] CommF_ не найден")
	end
end

local function buyBoatAfterMove()
	if moveToBuyPoint() then
		task.wait(0.5)
		buyBoatOnly()
		return true
	else
		warn("[ПОКУПКА] Не удалось достичь точки покупки после 3 попыток")
		return false
	end
end

local function resetCharacter()
	local char = player.Character
	if char then
		local hum = char:FindFirstChild("Humanoid")
		if hum then hum.Health = 0 else char:BreakJoints() end
	end
	player.CharacterAdded:Wait()
	task.wait(1)
end

local function findMyBoat()
	local boats = workspace:FindFirstChild("Boats")
	if not boats then return nil end
	for _, b in ipairs(boats:GetChildren()) do
		if b:IsA("Model") and b:FindFirstChildWhichIsA("VehicleSeat") then
			if b:GetAttribute("Owner") == playerName then return b end
			local own = b:FindFirstChild("Owner")
			if own and tostring(own.Value) == playerName then return b end
		end
	end
	return nil
end

-- ========== 3. ДВИЖЕНИЕ ЛОДКИ ==========
local boat = nil
local seat = nil
local root = nil
local hum = nil
local hrp = nil
local bv = nil
local dir = -1
local X_MIN = -77389.3
local X_MAX = -47968.4
local SPEED_X = 250
local SPEED_Y = -2
local SPEED_Z = -2
local TARGET_Y = 100
local moving = false
local moveThread = nil
local islandModeActive = false
local waitingForDespawn = false
local isReseating = false
local isBuying = false
local recoveryInProgress = false

local function ensureBV()
	if islandModeActive then return end
	local ch = player.Character
	if not ch then return end
	local upper = ch:FindFirstChild("UpperTorso")
	if not upper then return end
	local sx = dir * SPEED_X
	if bv and bv.Parent then
		bv.Velocity = Vector3.new(sx, SPEED_Y, SPEED_Z)
	else
		if bv then bv:Destroy() end
		bv = Instance.new("BodyVelocity")
		bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
		bv.Parent = upper
		bv.Velocity = Vector3.new(sx, SPEED_Y, SPEED_Z)
	end
end

local function stopMove()
	moving = false
	if moveThread then pcall(task.cancel, moveThread); moveThread = nil end
	if bv then bv:Destroy(); bv = nil end
end

local function startMove()
	if moving or islandModeActive then return end
	moving = true
	moveThread = task.spawn(function()
		local ch = player.Character
		if not ch then moving = false; return end
		local upper = ch:FindFirstChild("UpperTorso")
		if not upper then moving = false; return end
		if bv then bv:Destroy() end
		bv = Instance.new("BodyVelocity")
		bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
		bv.Parent = upper
		bv.Velocity = Vector3.new(0, 0, 0)
		if root then
			local p = root.Position
			if math.abs(p.Y - TARGET_Y) > 0.5 then
				root.CFrame = CFrame.new(p.X, TARGET_Y, p.Z)
			end
		end
		local sx = dir * SPEED_X
		bv.Velocity = Vector3.new(sx, SPEED_Y, SPEED_Z)
		while moving and not islandModeActive do
			if not (hum and hum.Sit and hum.SeatPart == seat) then
				stopMove()
				break
			end
			if root then
				local p = root.Position
				if math.abs(p.Y - TARGET_Y) > 0.5 then
					root.CFrame = CFrame.new(p.X, TARGET_Y, p.Z)
				end
				if p.X <= X_MIN and dir == -1 then
					dir = 1
					ensureBV()
				elseif p.X >= X_MAX and dir == 1 then
					dir = -1
					ensureBV()
				end
			end
			task.wait(0.05)
		end
	end)
end

-- ========== 4. МАГНИТ (без лишних задержек) ==========
local magnetBodyPos = nil
local magnetBodyPosActive = false

local function updateMagnetBodyPos(targetY)
	if not magnetBodyPosActive or islandModeActive then return end
	local char = player.Character
	if not char then return end
	local hrp = char:FindFirstChild("HumanoidRootPart")
	if not hrp then return end
	if not magnetBodyPos then
		magnetBodyPos = Instance.new("BodyPosition")
		magnetBodyPos.MaxForce = Vector3.new(0, math.huge, 0)
		magnetBodyPos.Parent = hrp
	end
	magnetBodyPos.Position = Vector3.new(hrp.Position.X, targetY, hrp.Position.Z)
end

local function stopMagnetBodyPos()
	magnetBodyPosActive = false
	if magnetBodyPos then magnetBodyPos:Destroy(); magnetBodyPos = nil end
end

local function fastMagnet()
	if islandModeActive then return end
	if not seat then return end
	local char = player.Character
	if not char then return end
	local h = char:FindFirstChild("Humanoid")
	local r = char:FindFirstChild("HumanoidRootPart")
	if not h or not r then return end
	if h.Sit and h.SeatPart == seat then
		stopMagnetBodyPos()
		return
	end
	if not magnetBodyPosActive then
		magnetBodyPosActive = true
	end
	local targetPos = seat.Position + Vector3.new(0, 2.5, 0)
	updateMagnetBodyPos(targetPos.Y)
	local dist = (r.Position - targetPos).Magnitude
	if dist > 0.3 then
		local dirVec = (targetPos - r.Position).Unit
		local step = math.min(200 * 0.02, dist)
		local newPos = r.Position + dirVec * step
		newPos = Vector3.new(newPos.X, targetPos.Y, newPos.Z)
		r.CFrame = CFrame.new(newPos)
	else
		r.CFrame = CFrame.new(targetPos)
	end
end

-- ========== 5. ОСТРОВ (АКТИВАЦИЯ ЯИЦ) ==========
local pendingReturn = false

local function findIsland()
	for _, obj in ipairs(workspace:GetDescendants()) do
		if obj.Name and string.find(string.lower(obj.Name), "prehistoricisland") then
			return obj
		end
	end
	return nil
end

local function activateProximityPrompt(obj)
	local prompt = obj:FindFirstChildWhichIsA("ProximityPrompt", true)
	if prompt then
		pcall(function()
			prompt:InputHoldBegin()
			task.wait(1.5)
			prompt:InputHoldEnd()
		end)
		return true
	end
	return false
end

local function getAllEggs()
	local island = findIsland()
	if not island then return {} end
	local core = island:FindFirstChild("Core")
	if not core then return {} end
	local spawned = core:FindFirstChild("SpawnedDragonEggs")
	if not spawned then return {} end
	local eggs = {}
	for _, child in ipairs(spawned:GetChildren()) do
		if child:IsA("Model") and child.Name == "DragonEgg" then
			local eggPart = child:FindFirstChild("EggCrust") or child:FindFirstChildWhichIsA("BasePart")
			if eggPart and eggPart.Parent then
				table.insert(eggs, {part = eggPart, model = child})
			end
		end
	end
	return eggs
end

local function activateEgg(eggModel)
	if not eggModel or not eggModel.Parent then return false end
	local eggPart = eggModel:FindFirstChild("EggCrust") or eggModel:FindFirstChildWhichIsA("BasePart")
	if not eggPart then return false end

	local targetPos = eggPart.Position + Vector3.new(0, 4.5, 0)
	print("[ЯЙЦО] Перемещение к яйцу на высоту", targetPos.Y)

	if not safeMoveStep(targetPos, 500, true, 3, 5) then
		warn("[ЯЙЦО] Не удалось приблизиться к яйцу, продолжаем на месте")
	end

	local char = player.Character
	if not char then return false end
	local hrp = char:FindFirstChild("HumanoidRootPart")
	if not hrp then return false end

	local bodyPos = Instance.new("BodyPosition")
	bodyPos.MaxForce = Vector3.new(0, math.huge, 0)
	bodyPos.P = 10000
	bodyPos.Parent = hrp

	local startTime = tick()
	while eggModel and eggModel.Parent do
		if tick() - startTime > 60 then
			warn("[ЯЙЦО] Таймаут активации (60 сек), пропускаем")
			break
		end
		bodyPos.Position = Vector3.new(hrp.Position.X, targetPos.Y, hrp.Position.Z)
		local lookAt = (eggPart.Position - hrp.Position).Unit
		hrp.CFrame = CFrame.new(hrp.Position, hrp.Position + lookAt)

		if not activateProximityPrompt(eggModel) then
			local vim = game:GetService("VirtualInputManager")
			vim:SendKeyEvent(true, "E", false, game)
			task.wait(1.5)
			vim:SendKeyEvent(false, "E", false, game)
		end
		task.wait(1)
	end
	bodyPos:Destroy()
	return true
end

-- ========== 6. WATCHDOG ==========
local islandModeEnterTime = 0
task.spawn(function()
	while true do
		task.wait(30)
		if islandModeActive and (tick() - islandModeEnterTime > 1500) then
			print("[WATCHDOG] Островной режим висит >25 мин – принудительный сброс")
			islandModeActive = false
			waitingForDespawn = true
			pendingReturn = true
		end

		if islandModeActive or isBuying or recoveryInProgress then continue end

		local char = player.Character
		if not char then continue end
		local h = char:FindFirstChild("Humanoid")
		local hrp = char:FindFirstChild("HumanoidRootPart")
		if not h or not hrp then continue end

		if boat and boat.Parent and seat then
			if not (h.Sit and h.SeatPart == seat) and not magnetBodyPosActive then
				print("[WATCHDOG] Не в лодке и магнит выключен – пробуем сесть")
				task.spawn(function()
					forceSitOnSeat(seat, 2)
					if h.Sit and h.SeatPart == seat then
						stopMagnetBodyPos()
						if not moving then startMove() end
					else
						print("[WATCHDOG] Посадка не удалась – включаем магнит")
						fastMagnet()
					end
				end)
			end
		else
			if not isBuying and not recoveryInProgress then
				print("[WATCHDOG] Лодка отсутствует – запускаем полное восстановление")
				recoveryInProgress = true
				task.spawn(function()
					isBuying = true
					resetCharacter()
					if buyBoatAfterMove() then
						for i = 1, 30 do
							boat = findMyBoat()
							if boat then break end
							task.wait(1)
						end
						if boat then
							seat = boat:FindFirstChildWhichIsA("VehicleSeat")
							root = boat.PrimaryPart or boat:FindFirstChildWhichIsA("BasePart")
							if seat and root then
								for _, p in ipairs(boat:GetDescendants()) do
									if p:IsA("BasePart") then p.CanCollide = false end
								end
								local nat = boat:FindFirstChild("Script")
								if nat then nat.Disabled = true end
								forceSitOnSeat(seat, 3)
								startMove()
							end
						end
					end
					isBuying = false
					recoveryInProgress = false
				end)
			end
		end
	end
end)

-- ========== 7. ОСТРОВНОЙ ПОТОК (с проверкой подъёма) ==========
task.spawn(function()
	while true do
		task.wait(1)
		local island = findIsland()
		local present = island ~= nil

		if waitingForDespawn and not present then
			waitingForDespawn = false
			print("[ОСТРОВ] Остров исчез, готов к новой активации")
		end

		if present and not islandModeActive and not waitingForDespawn then
			print("[ОСТРОВ] Обнаружен, входим в режим")
			islandModeActive = true
			islandModeEnterTime = tick()

			stopMove()
			stopMagnetBodyPos()

			local char = player.Character
			if char then
				local h = char:FindFirstChild("Humanoid")
				if h and h.Sit then h.Sit = false end
			end

			local target = island:GetPivot().Position + Vector3.new(0, 330, 0)
			local success = safeMoveStep(target, 200, true, 3, 10)
			if not success then
				print("[ОСТРОВ] Не удалось подняться к острову, выходим")
				islandModeActive = false
				waitingForDespawn = true
				pendingReturn = true
				continue   -- пропускаем ожидание яиц
			end

			local startTime = os.clock()
			local eggsList = {}
			print("[ОСТРОВ] Ожидание яиц...")
			while os.clock() - startTime < 600 do
				if tick() - islandModeEnterTime > 1200 then
					print("[ОСТРОВ] Общий таймаут острова (20 мин)")
					break
				end
				eggsList = getAllEggs()
				if #eggsList > 0 then break end
				if not findIsland() then
					print("[ОСТРОВ] Остров исчез при ожидании")
					break
				end
				task.wait(1)
			end

			if islandModeActive then
				if #eggsList == 0 then
					print("[ОСТРОВ] Яйца не появились")
				else
					print("[ОСТРОВ] Найдено яиц:", #eggsList)
					local activatedCount = 0
					while islandModeActive do
						if tick() - islandModeEnterTime > 1200 then
							print("[ОСТРОВ] Таймаут, прерываем активацию")
							break
						end
						local currentEggs = getAllEggs()
						if #currentEggs == 0 then break end
						if not findIsland() then
							print("[ОСТРОВ] Остров исчез во время активации")
							break
						end
						local charNow = player.Character
						if charNow and charNow:FindFirstChild("HumanoidRootPart") then
							local hrpNow = charNow.HumanoidRootPart
							for _, egg in ipairs(currentEggs) do
								if egg.part then
									egg.dist = (hrpNow.Position - egg.part.Position).Magnitude
								else
									egg.dist = math.huge
								end
							end
							table.sort(currentEggs, function(a,b) return a.dist < b.dist end)
						end
						local eggToActivate = currentEggs[1]
						if eggToActivate and eggToActivate.model and eggToActivate.model.Parent then
							print("[ОСТРОВ] Активация яйца", activatedCount+1)
							activateEgg(eggToActivate.model)
							activatedCount = activatedCount + 1
							task.wait(1)
						else
							break
						end
					end
					print("[ОСТРОВ] Активировано яиц:", activatedCount)
				end

				islandModeActive = false
				waitingForDespawn = true
				pendingReturn = true
				print("[ОСТРОВ] Режим завершён, ждём исчезновения острова")
			else
				islandModeActive = false
				waitingForDespawn = true
				pendingReturn = true
			end
		end
	end
end)

-- ========== 8. ОСНОВНОЙ ЦИКЛ (ЛОДКА) ==========
local rs = game:GetService("ReplicatedStorage")
local remotes = rs and rs:FindFirstChild("Remotes")
if remotes then
	local commF = remotes:FindFirstChild("CommF_")
	if commF then pcall(function() commF:InvokeServer("SetTeam", "Marines") end) end
end

local function fullRecovery()
	if isBuying or recoveryInProgress then return end
	recoveryInProgress = true
	isBuying = true
	print("[ВОССТАНОВЛЕНИЕ] Запущено...")
	resetCharacter()
	if buyBoatAfterMove() then
		for i = 1, 30 do
			boat = findMyBoat()
			if boat then break end
			task.wait(1)
		end
		if boat then
			seat = boat:FindFirstChildWhichIsA("VehicleSeat")
			root = boat.PrimaryPart or boat:FindFirstChildWhichIsA("BasePart")
			if seat and root then
				for _, p in ipairs(boat:GetDescendants()) do
					if p:IsA("BasePart") then p.CanCollide = false end
				end
				local nat = boat:FindFirstChild("Script")
				if nat then nat.Disabled = true end
				forceSitOnSeat(seat, 3)
				startMove()
				waitingForDespawn = false
				print("[ВОССТАНОВЛЕНИЕ] Успешно, лодка готова")
			end
		else
			warn("[ВОССТАНОВЛЕНИЕ] Лодка не появилась")
		end
	else
		warn("[ВОССТАНОВЛЕНИЕ] Не удалось купить лодку")
	end
	isBuying = false
	recoveryInProgress = false
end

task.spawn(function()
	task.wait(1)
	fullRecovery()
end)

task.spawn(function()
	while true do
		task.wait(0.05)
		if islandModeActive then continue end

		if pendingReturn then
			pendingReturn = false
			print("[ГЛАВНЫЙ] Возврат с острова")
			boat = nil; seat = nil; root = nil
			boat = findMyBoat()
			if boat then
				seat = boat:FindFirstChildWhichIsA("VehicleSeat")
				root = boat.PrimaryPart or boat:FindFirstChildWhichIsA("BasePart")
				if seat and root then
					for _, p in ipairs(boat:GetDescendants()) do
						if p:IsA("BasePart") then p.CanCollide = false end
					end
					local nat = boat:FindFirstChild("Script")
					if nat then nat.Disabled = true end
					local char = player.Character
					if char then
						local h = char:FindFirstChild("Humanoid")
						if h and forceSitOnSeat(seat, 3) then
							stopMove()
							moving = false
							if bv then bv:Destroy() bv = nil end
							startMove()
							waitingForDespawn = false
							print("[ГЛАВНЫЙ] Посадка выполнена, waitingForDespawn сброшен")
						end
					end
				end
			else
				print("[ГЛАВНЫЙ] Лодка не найдена после острова – запускаю восстановление")
				task.spawn(fullRecovery)
			end
		end

		if boat and not boat.Parent then
			print("[ГЛАВНЫЙ] Лодка исчезла, восстановление")
			boat = nil; seat = nil; root = nil
			stopMove()
			stopMagnetBodyPos()
			if not isBuying and not recoveryInProgress then
				task.spawn(fullRecovery)
			end
		end

		if (not boat or not boat.Parent) and not isBuying and not recoveryInProgress then
			print("[ГЛАВНЫЙ] Лодка отсутствует – запускаю восстановление")
			task.spawn(fullRecovery)
		end

		local char = player.Character
		if char then
			hum = char:FindFirstChild("Humanoid")
			hrp = char:FindFirstChild("HumanoidRootPart")
		end

		if hum and hum.Sit then
			if hum.SeatPart == seat then
				if not moving and not islandModeActive then
					startMove()
				end
			else
				if not isReseating then
					isReseating = true
					if seat then forceSitOnSeat(seat, 3) end
					isReseating = false
				end
				if moving then stopMove() end
			end
		else
			if moving then stopMove() end
			fastMagnet()
		end
	end
end)

-- ========== 9. ФРУКТЫ (DISCORD + StoreFruit) ==========
local commF = rs and rs:FindFirstChild("Remotes") and rs.Remotes:FindFirstChild("CommF_")
local processedFruits = {}

local function sendDiscordFruit(name)
	local msg = { content = player.Name .. " получил '" .. name .. "'!", username = "Инвентарь" }
	pcall(function()
		HttpService:RequestAsync({
			Url = DISCORD_WEBHOOK,
			Method = "POST",
			Headers = {["Content-Type"] = "application/json"},
			Body = HttpService:JSONEncode(msg)
		})
	end)
	print("[DISCORD] Отправлено:", name)
end

local function sellFruit(tool)
	local fullName = tool.Name
	if processedFruits[fullName] then return end
	processedFruits[fullName] = true

	print("[ФРУКТ] Найден:", fullName)
	sendDiscordFruit(fullName)

	local storeName = fullName:gsub(" Fruit", ""):gsub(" ", "-")
	print("[ФРУКТ] Сдаём как:", storeName)

	task.wait(3)
	if tool.Parent ~= player.Character then
		tool.Parent = player.Character
		task.wait(3)
	end

	if tool.Parent ~= player.Character then
		warn("[ФРУКТ] Не удалось экипировать", fullName)
		processedFruits[fullName] = nil
		return
	end

	local args = { "StoreFruit", storeName, tool }
	local success, err = pcall(function()
		commF:InvokeServer(unpack(args))
	end)
	if success then
		print("[ФРУКТ] Сдан успешно:", storeName)
	else
		warn("[ФРУКТ] Ошибка сдачи:", err)
		processedFruits[fullName] = nil
	end
end

local function onToolAdded(tool)
	if tool:IsA("Tool") and tool.Name:find("Fruit") then
		task.wait(3)
		sellFruit(tool)
	end
end

local backpack = player:WaitForChild("Backpack")
backpack.ChildAdded:Connect(onToolAdded)

local function onCharAdded(char)
	char.ChildAdded:Connect(onToolAdded)
end
if player.Character then
	onCharAdded(player.Character)
end
player.CharacterAdded:Connect(onCharAdded)

task.wait(3)
for _, tool in ipairs(backpack:GetChildren()) do
	if tool:IsA("Tool") and tool.Name:find("Fruit") then
		sellFruit(tool)
		break
	end
end
if player.Character then
	for _, tool in ipairs(player.Character:GetChildren()) do
		if tool:IsA("Tool") and tool.Name:find("Fruit") then
			sellFruit(tool)
			break
		end
	end
end

print("[ФРУКТ] Монитор запущен")

-- ========== 10. АНТИ-IDLE ==========
task.spawn(function()
	local cam = workspace.CurrentCamera
	while true do
		task.wait(300)
		local current = cam.CFrame
		cam.CFrame = current * CFrame.Angles(0, math.rad(1), 0)
		task.wait(0.5)
		cam.CFrame = current
	end
end)
task.spawn(function()
	local vim = game:GetService("VirtualInputManager")
	if vim then
		while true do
			task.wait(600)
			pcall(function()
				vim:SendKeyEvent(true, "W", false, game)
				task.wait(0.1)
				vim:SendKeyEvent(false, "W", false, game)
			end)
		end
	end
end)

print("Скрипт версии 8.9 запущен. Исправлены таймауты и проверка подъёма.")
