local TeleportService = game:GetService("TeleportService")

local function serverHop(player)
	if player then
		TeleportService:Teleport(game.PlaceId, player)
	end
end

local function monitorPlayer(player)
	local data = player:FindFirstChild("Data")
	if not data then return end
	
	local level = data:FindFirstChild("Level")
	if not level then return end
	
	while player.Parent do
		local lastValue = level.Value
		task.wait(60)
		
		if level.Value == lastValue or level.Value > 50 then
			serverHop(player)
			break
		end
	end
end

for _, player in ipairs(game:GetService("Players"):GetPlayers()) do
	task.wait(3)
	monitorPlayer(player)
end

game:GetService("Players").PlayerAdded:Connect(function(player)
	task.wait(3)
	monitorPlayer(player)
end)
