-- ============================================================
-- ЦЕЛЬНЫЙ СКРИПТ: Авто-ферма Prehistoric Island + движение лодки
-- Для Delta, работает с redz-library-v5. Использует getconnections.
-- НЕ использует устаревшие методы (BodyVelocity заменён на LinearVelocity).
-- ============================================================

-- ======================= НАСТРОЙКИ ===========================
local BOAT_TAB = 5       -- Вкладка с кнопками лодки и острова
local BOAT_OPT = 6       -- Кнопка "перемещение в лодку"
local ISLAND_OPT = 10    -- Кнопка "перемещение к острову"

-- Эталонные цвета индикатора (в формате "R, G, B")
local COLOR_ON  = "0.345098, 0.396078, 0.94902"
local COLOR_OFF = "0.239216, 0.262745, 0.529412"

-- Параметры движения лодки
local X_MIN = -77389.3
local X_MAX = -47968.4
local SPEED_X = 250
local TARGET_Y = 100
local SPEED_Y = -2   -- небольшой дрейф вниз для стабильности
local SPEED_Z = -2

-- ================= ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ ==================
local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local Workspace = game:GetService("Workspace")
local player = Players.LocalPlayer

-- Поиск корня redz-library-v5
local function getRoot()
	for _, child in ipairs(CoreGui:GetChildren()) do
		local obj = child:FindFirstChild("redz-library-v5")
		if obj then return obj end
	end
	return nil
end

-- Эмуляция полного клика по кнопке
local function fireSequence(btn)
	local signals = {"MouseEnter","MouseButton1Down","MouseButton1Click","MouseButton1Up","Activated","MouseLeave"}
	for _, sigName in ipairs(signals) do
		local sig = btn[sigName]
		if sig then
			local ok, conns = pcall(function() return getconnections(sig) end)
			if ok and conns then
				for _, conn in ipairs(conns) do
					if conn and conn.Enabled and type(conn.Function) == "function" then
						conn.Function()
					end
				end
			end
		end
	end
end

-- Рекурсивный поиск Frame-индикатора с известными цветами
local function findIndicatorFrame(parent)
	for _, child in ipairs(parent:GetChildren()) do
		if child:IsA("Frame") then
			local col = tostring(child.BackgroundColor3)
			if col == COLOR_ON or col == COLOR_OFF then
				return child
			end
		end
		local found = findIndicatorFrame(child)
		if found then return found end
	end
	return nil
end

-- Получить состояние опции ("on","off",nil) по индексам (вкладка переключается)
local function getOptionState(tabIndex, optIndex)
	local root = getRoot()
	if not root then return nil end

	-- Переключаем вкладку
	local tabsScroll = root:FindFirstChild("Window"):FindFirstChild("Components"):FindFirstChild("TabsScroll")
	if not tabsScroll then return nil end

	local tabButton = nil
	local tabCount = 0
	local function findTab(parent)
		if tabButton then return end
		for _, child in ipairs(parent:GetChildren()) do
			if child:IsA("TextButton") or child:IsA("ImageButton") then
				tabCount = tabCount + 1
				if tabCount == tabIndex then tabButton = child return end
			end
			findTab(child)
		end
	end
	findTab(tabsScroll)
	if not tabButton then return nil end
	fireSequence(tabButton)
	task.wait(0.15)

	-- Ищем нужную Option (только видимые)
	local container = root:FindFirstChild("Window"):FindFirstChild("Components"):FindFirstChild("Containers"):FindFirstChild("Container")
	if not container then return nil end

	local optionBtn = nil
	local optCount = 0
	for _, child in ipairs(container:GetChildren()) do
		if child.Name == "Option" and child.Visible and (child:IsA("TextButton") or child:IsA("ImageButton")) then
			optCount = optCount + 1
			if optCount == optIndex then
				optionBtn = child
				break
			end
		end
	end
	if not optionBtn then return nil end

	local indicator = findIndicatorFrame(optionBtn)
	if not indicator then return nil end
	local col = tostring(indicator.BackgroundColor3)
	if col == COLOR_ON then return "on"
	elseif col == COLOR_OFF then return "off"
	else return nil end
end

-- Принудительно установить состояние опции (с обработкой конфликтов)
-- Возвращает true, если действие выполнено
local function setOptionState(tabIndex, optIndex, desiredState, conflictTab, conflictOpt)
	if desiredState ~= "on" and desiredState ~= "off" then return false end
	local root = getRoot()
	if not root then return false end

	-- Если нужно включить, сначала выключаем конфликтующую опцию (если задана)
	if desiredState == "on" and conflictTab and conflictOpt then
		local conflictState = getOptionState(conflictTab, conflictOpt)
		if conflictState == "on" then
			local cfRoot = getRoot()
			local cfTabsScroll = cfRoot:FindFirstChild("Window"):FindFirstChild("Components"):FindFirstChild("TabsScroll")
			if cfTabsScroll then
				local cfTabBtn = nil
				local cfTabCount = 0
				local function findCfTab(p)
					if cfTabBtn then return end
					for _, c in ipairs(p:GetChildren()) do
						if c:IsA("TextButton") or c:IsA("ImageButton") then
							cfTabCount = cfTabCount + 1
							if cfTabCount == conflictTab then cfTabBtn = c return end
						end
						findCfTab(c)
					end
				end
				findCfTab(cfTabsScroll)
				if cfTabBtn then fireSequence(cfTabBtn) task.wait(0.15) end
			end
			local cfContainer = cfRoot:FindFirstChild("Window"):FindFirstChild("Components"):FindFirstChild("Containers"):FindFirstChild("Container")
			if cfContainer then
				local cfOptCount = 0
				for _, c in ipairs(cfContainer:GetChildren()) do
					if c.Name == "Option" and c.Visible and (c:IsA("TextButton") or c:IsA("ImageButton")) then
						cfOptCount = cfOptCount + 1
						if cfOptCount == conflictOpt then
							local ind = findIndicatorFrame(c)
							if ind and tostring(ind.BackgroundColor3) == COLOR_ON then
								fireSequence(c)
							end
							break
						end
					end
				end
			end
			task.wait(0.1)
		end
	end

	-- Теперь переключаем целевую вкладку и ищем опцию
	local tabsScroll = root:FindFirstChild("Window"):FindFirstChild("Components"):FindFirstChild("TabsScroll")
	if not tabsScroll then return false end

	local tabButton = nil
	local tabCount = 0
	local function findTab(parent)
		if tabButton then return end
		for _, child in ipairs(parent:GetChildren()) do
			if child:IsA("TextButton") or child:IsA("ImageButton") then
				tabCount = tabCount + 1
				if tabCount == tabIndex then tabButton = child return end
			end
			findTab(child)
		end
	end
	findTab(tabsScroll)
	if not tabButton then return false end
	fireSequence(tabButton)
	task.wait(0.15)

	local container = root:FindFirstChild("Window"):FindFirstChild("Components"):FindFirstChild("Containers"):FindFirstChild("Container")
	if not container then return false end

	local optionBtn = nil
	local optCount = 0
	for _, child in ipairs(container:GetChildren()) do
		if child.Name == "Option" and child.Visible and (child:IsA("TextButton") or child:IsA("ImageButton")) then
			optCount = optCount + 1
			if optCount == optIndex then
				optionBtn = child
				break
			end
		end
	end
	if not optionBtn then return false end

	local indicator = findIndicatorFrame(optionBtn)
	if not indicator then return false end
	local currentCol = tostring(indicator.BackgroundColor3)
	local currentState = (currentCol == COLOR_ON and "on") or (currentCol == COLOR_OFF and "off") or nil
	if currentState == desiredState then return true end -- уже в нужном состоянии

	fireSequence(optionBtn)
	task.wait(0.1)
	return true
end

-- ==================== ДВИЖЕНИЕ ЛОДКИ =========================
local boat, seat, boatRoot = nil, nil, nil
local moving = false
local moveThread = nil
local linearVelocity = nil  -- LinearVelocity constraint

local function stopBoatMovement()
	moving = false
	if moveThread then
		task.cancel(moveThread)
		moveThread = nil
	end
	if linearVelocity then
		linearVelocity:Destroy()
		linearVelocity = nil
	end
end

-- Создаёт/обновляет LinearVelocity на boatRoot
local function applyBoatVelocity(dirX, speedY, speedZ)
	if not boatRoot or not boatRoot.Parent then return end
	local velocity = Vector3.new(dirX * SPEED_X, speedY, speedZ)
	if linearVelocity then
		linearVelocity.VectorVelocity = velocity
	else
		linearVelocity = Instance.new("LinearVelocity")
		linearVelocity.MaxForce = math.huge
		linearVelocity.VectorVelocity = velocity
		linearVelocity.Attachment0 = Instance.new("Attachment")
		linearVelocity.Attachment0.Parent = boatRoot
		linearVelocity.Parent = boatRoot
	end
end

local function startBoatMovement()
	if moving then return end
	if not boatRoot then return end
	moving = true
	moveThread = task.spawn(function()
		local dir = -1
		-- Приводим лодку к нужной высоте один раз
		local pos = boatRoot.Position
		if math.abs(pos.Y - TARGET_Y) > 0.5 then
			boat:PivotTo(CFrame.new(pos.X, TARGET_Y, pos.Z))
		end
		applyBoatVelocity(dir, SPEED_Y, SPEED_Z)
		while moving do
			if not boat or not boat.Parent or not seat or not seat.Parent then
				stopBoatMovement()
				break
			end
			if boatRoot then
				local currentPos = boatRoot.Position
				-- Смена направления у границ
				if currentPos.X <= X_MIN and dir == -1 then
					dir = 1
					applyBoatVelocity(dir, SPEED_Y, SPEED_Z)
				elseif currentPos.X >= X_MAX and dir == 1 then
					dir = -1
					applyBoatVelocity(dir, SPEED_Y, SPEED_Z)
				end
				-- Корректировка высоты (небольшая подстройка, чтобы не улететь)
				if math.abs(currentPos.Y - TARGET_Y) > 3 then
					boat:PivotTo(CFrame.new(currentPos.X, TARGET_Y, currentPos.Z))
				end
			end
			task.wait(0.1)
		end
	end)
end

-- Проверка, сидит ли персонаж в лодке (VehicleSeat)
local function isInBoat()
	local char = player.Character
	if not char then return false end
	local hum = char:FindFirstChild("Humanoid")
	if not hum or not hum.Sit or not hum.SeatPart then return false end
	local seatPart = hum.SeatPart
	local model = seatPart:FindFirstAncestorOfClass("Model")
	if model and model:FindFirstChildWhichIsA("VehicleSeat") then
		return true, model, seatPart
	end
	return false
end

-- ==================== ОСТРОВ И ИГРОКИ ========================
local function findIsland()
	local map = Workspace:FindFirstChild("Map")
	if map then
		local island = map:FindFirstChild("PrehistoricIsland")
		if island then
			local core = island:FindFirstChild("Core")
			if core then
				local promptContainer = core:FindFirstChild("ActivationPrompt")
				if promptContainer then
					local prompt = promptContainer:FindFirstChild("ProximityPrompt")
					if prompt and prompt:IsA("ProximityPrompt") and prompt.Enabled then
						return island
					end
				end
			end
		end
	end
	return nil
end

local function getIslandPosition(island)
	if island:IsA("Model") and island.PrimaryPart then
		return island.PrimaryPart.Position
	else
		local part = island:FindFirstChildWhichIsA("BasePart")
		if part then return part.Position end
	end
	return nil
end

local function allPlayersNearIsland(islandPos)
	if not islandPos then return false end
	local allNear = true
	for _, plr in ipairs(Players:GetPlayers()) do
		local char = plr.Character
		if char then
			local hrp = char:FindFirstChild("HumanoidRootPart")
			if hrp then
				if (hrp.Position - islandPos).Magnitude > 100 then
					allNear = false
					break
				end
			else
				allNear = false
				break
			end
		else
			allNear = false
			break
		end
	end
	return allNear
end

-- =================== ОСНОВНОЙ ЦИКЛ ============================
local state = "INIT"
local function waitForCharacter()
	while not player.Character or not player.Character:FindFirstChild("HumanoidRootPart") do
		player.CharacterAdded:Wait()
		task.wait(0.2)
	end
end

print("Скрипт запущен. Ожидание загрузки...")

while true do
	local char = player.Character
	local hum = char and char:FindFirstChild("Humanoid")
	local hrp = char and char:FindFirstChild("HumanoidRootPart")

	if not hum or hum.Health <= 0 or not hrp then
		stopBoatMovement()
		boat, seat, boatRoot = nil, nil, nil
		state = "INIT"
		waitForCharacter()
		continue
	end

	if state == "INIT" then
		if not getRoot() then
			task.wait(0.5)
			continue
		end
		state = "WAITING_FOR_BOAT_OPTION"

	elseif state == "WAITING_FOR_BOAT_OPTION" then
		local curState = getOptionState(BOAT_TAB, BOAT_OPT)
		if curState == "off" then
			print("Активируем кнопку лодки (5,6)")
			setOptionState(BOAT_TAB, BOAT_OPT, "on", BOAT_TAB, ISLAND_OPT)
		elseif curState == nil then
			print("Кнопка лодки не найдена, ждём...")
			task.wait(1)
			continue
		end
		state = "WAITING_FOR_BOARD_BOAT"
		task.wait(0.2)

	elseif state == "WAITING_FOR_BOARD_BOAT" then
		local inBoat, boatModel, seatPart = isInBoat()
		if inBoat then
			print("Персонаж сел в лодку")
			setOptionState(BOAT_TAB, BOAT_OPT, "off")
			boat = boatModel
			seat = seatPart
			boatRoot = boat.PrimaryPart or boat:FindFirstChildWhichIsA("BasePart")
			for _, part in ipairs(boat:GetDescendants()) do
				if part:IsA("BasePart") then
					part.CanCollide = false
				end
			end
			local natScript = boat:FindFirstChild("Script")
			if natScript then natScript.Disabled = true end
			startBoatMovement()
			state = "MOVING_ON_BOAT"
		else
			task.wait(0.5)
			if math.random(1,10) == 1 then
				setOptionState(BOAT_TAB, BOAT_OPT, "on", BOAT_TAB, ISLAND_OPT)
			end
		end

	elseif state == "MOVING_ON_BOAT" then
		local inBoat, boatModel, seatPart = isInBoat()
		if not inBoat or boatModel ~= boat then
			print("Вышли из лодки, перезапуск поиска")
			stopBoatMovement()
			boat, seat, boatRoot = nil, nil, nil
			state = "WAITING_FOR_BOAT_OPTION"
			continue
		end
		local island = findIsland()
		if island then
			print("Prehistoric Island обнаружен!")
			stopBoatMovement()
			state = "GOING_TO_ISLAND"
		end
		task.wait(0.5)

	elseif state == "GOING_TO_ISLAND" then
		print("Переключаемся на остров: выключаем 5,6, включаем 5,10")
		setOptionState(BOAT_TAB, BOAT_OPT, "off")
		setOptionState(BOAT_TAB, ISLAND_OPT, "on", BOAT_TAB, BOAT_OPT)
		local islandObj = findIsland()
		if not islandObj then
			print("Остров пропал, возвращаемся к лодке")
			state = "WAITING_FOR_BOAT_OPTION"
			continue
		end
		local islandPos = getIslandPosition(islandObj)
		if not islandPos then
			state = "WAITING_FOR_BOAT_OPTION"
			continue
		end
		if hrp and (hrp.Position - islandPos).Magnitude <= 100 then
			print("Персонаж на месте, ждём остальных")
			state = "WAITING_ALL_NEAR"
		else
			task.wait(0.3)
		end

	elseif state == "WAITING_ALL_NEAR" then
		local island = findIsland()
		if not island then
			print("Остров исчез, перезапуск")
			state = "WAITING_FOR_BOAT_OPTION"
			continue
		end
		local islandPos = getIslandPosition(island)
		if not islandPos then
			state = "WAITING_FOR_BOAT_OPTION"
			continue
		end
		if allPlayersNearIsland(islandPos) then
			print("Все игроки на острове! Запускаем возврат в лодку")
			state = "RETURN_TO_BOAT"
		else
			task.wait(1)
		end

	elseif state == "RETURN_TO_BOAT" then
		print("Возврат: выключаем 5,10, включаем 5,6")
		setOptionState(BOAT_TAB, ISLAND_OPT, "off")
		setOptionState(BOAT_TAB, BOAT_OPT, "on", BOAT_TAB, ISLAND_OPT)
		state = "WAITING_FOR_BOARD_BOAT"
		task.wait(0.2)
	end

	task.wait(0.1)
end
