loadstring(game:HttpGet("https://raw.githubusercontent.com/Omgshit/Scripts/main/MainLoader.lua"))()
-- ============================================================
-- ЦЕЛЬНЫЙ СКРИПТ: Авто-ферма Prehistoric Island + движение лодки
-- Для Delta, работает с redz-library-v5. Использует getconnections.
-- Не содержит устаревших методов (BodyVelocity заменён на ручное перемещение).
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
local BOAT_SPEED_Y = -2   -- небольшой дрейф, чтобы физика не спала
local BOAT_SPEED_Z = -2

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
		-- Рекурсивно не вызываем, чтобы избежать петли, просто принудительно выключаем
		local conflictState = getOptionState(conflictTab, conflictOpt)
		if conflictState == "on" then
			-- переключаем вкладку конфликтной опции и кликаем
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
							-- Проверим, что она ещё on (могла измениться)
							local ind = findIndicatorFrame(c)
							if ind and tostring(ind.BackgroundColor3) == COLOR_ON then
								fireSequence(c)
							end
							break
						end
					end
				end
			end
			task.wait(0.1) -- даём интерфейсу обновиться
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

local function stopBoatMovement()
	moving = false
	if moveThread then
		task.cancel(moveThread)
		moveThread = nil
	end
end

local function startBoatMovement()
	if moving then return end
	if not boatRoot then return end
	moving = true
	moveThread = task.spawn(function()
		-- Направление: -1 влево, 1 вправо
		local dir = -1
		-- Первоначально ставим высоту
		local pos = boatRoot.Position
		if math.abs(pos.Y - TARGET_Y) > 0.5 then
			boat:PivotTo(CFrame.new(pos.X, TARGET_Y, pos.Z))
		end
		while moving do
			if not boat or not boat.Parent or not seat or not seat.Parent then
				stopBoatMovement()
				break
			end
			-- Двигаем лодку
			local currentPos = boatRoot.Position
			local newX = currentPos.X + dir * SPEED_X * 0.05
			local newY = TARGET_Y
			local newZ = currentPos.Z + BOAT_SPEED_Z * 0.05
			-- Коррекция границ и смена направления
			if newX <= X_MIN and dir == -1 then
				dir = 1
				newX = X_MIN
			elseif newX >= X_MAX and dir == 1 then
				dir = -1
				newX = X_MAX
			end
			boat:PivotTo(CFrame.new(newX, newY, newZ))
			-- Дополнительный дрейф по Y для предотвращения сна физики
			newY = newY + BOAT_SPEED_Y * 0.05
			boat:PivotTo(CFrame.new(newX, newY, newZ))
			task.wait(0.05)
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
	-- Ищем через Map.PrehistoricIsland.Core.ActivationPrompt.ProximityPrompt
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

-- Проверка, что все игроки в пределах 100 единиц от позиции острова
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

	-- Если персонаж умер или перезагрузился, сбрасываем всё
	if not hum or hum.Health <= 0 or not hrp then
		stopBoatMovement()
		boat, seat, boatRoot = nil, nil, nil
		state = "INIT"
		waitForCharacter()
		continue
	end

	if state == "INIT" then
		-- Ждём появления хаба
		if not getRoot() then
			task.wait(0.5)
			continue
		end
		state = "WAITING_FOR_BOAT_OPTION"

	elseif state == "WAITING_FOR_BOAT_OPTION" then
		-- Активируем кнопку лодки, если выключена
		local curState = getOptionState(BOAT_TAB, BOAT_OPT)
		if curState == "off" then
			print("Активируем кнопку лодки (5,6)")
			setOptionState(BOAT_TAB, BOAT_OPT, "on", BOAT_TAB, ISLAND_OPT) -- конфликт с островом
		elseif curState == nil then
			print("Кнопка лодки не найдена, ждём...")
			task.wait(1)
			continue
		end
		state = "WAITING_FOR_BOARD_BOAT"
		task.wait(0.2)

	elseif state == "WAITING_FOR_BOARD_BOAT" then
		-- Ждём, пока персонаж сядет в лодку
		local inBoat, boatModel, seatPart = isInBoat()
		if inBoat then
			print("Персонаж сел в лодку")
			-- Деактивируем кнопку лодки (она больше не нужна в активном состоянии)
			setOptionState(BOAT_TAB, BOAT_OPT, "off")
			-- Настраиваем переменные лодки
			boat = boatModel
			seat = seatPart
			boatRoot = boat.PrimaryPart or boat:FindFirstChildWhichIsA("BasePart")
			-- Отключаем коллизии и скрипты лодки
			for _, part in ipairs(boat:GetDescendants()) do
				if part:IsA("BasePart") then
					part.CanCollide = false
				end
			end
			local natScript = boat:FindFirstChild("Script")
			if natScript then natScript.Disabled = true end
			-- Запускаем движение
			startBoatMovement()
			state = "MOVING_ON_BOAT"
		else
			-- Таймаут? Не в лодке — пробуем снова активировать кнопку
			task.wait(0.5)
			-- Для надёжности иногда повторно включаем кнопку
			if math.random(1,10) == 1 then
				setOptionState(BOAT_TAB, BOAT_OPT, "on", BOAT_TAB, ISLAND_OPT)
			end
		end

	elseif state == "MOVING_ON_BOAT" then
		-- Проверяем, всё ещё ли мы в лодке
		local inBoat, boatModel, seatPart = isInBoat()
		if not inBoat or boatModel ~= boat then
			print("Вышли из лодки, перезапуск поиска")
			stopBoatMovement()
			boat, seat, boatRoot = nil, nil, nil
			state = "WAITING_FOR_BOAT_OPTION"
			continue
		end
		-- Проверяем появление острова
		local island = findIsland()
		if island then
			print("Prehistoric Island обнаружен!")
			stopBoatMovement()
			state = "GOING_TO_ISLAND"
		end
		task.wait(0.5)

	elseif state == "GOING_TO_ISLAND" then
		-- Деактивируем лодку (5,6), активируем остров (5,10)
		print("Переключаемся на остров: выключаем 5,6, включаем 5,10")
		setOptionState(BOAT_TAB, BOAT_OPT, "off")
		setOptionState(BOAT_TAB, ISLAND_OPT, "on", BOAT_TAB, BOAT_OPT) -- конфликт с лодкой
		-- Ждём, пока персонаж окажется рядом с островом
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
		-- Выключаем остров (5,10), включаем лодку (5,6)
		print("Возврат: выключаем 5,10, включаем 5,6")
		setOptionState(BOAT_TAB, ISLAND_OPT, "off")
		setOptionState(BOAT_TAB, BOAT_OPT, "on", BOAT_TAB, ISLAND_OPT)
		-- Ждём посадки в лодку
		state = "WAITING_FOR_BOARD_BOAT"
		task.wait(0.2)
	end

	task.wait(0.1)
end
