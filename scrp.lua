local player = game:GetService("Players").LocalPlayer
if not player then return end

local data = player:WaitForChild("Data")
local level = data:WaitForChild("Level")

-- Проверка уровня
if level.Value < 50 then
    -- Запускаем основной скрипт (сервер хоп / кик)
    loadstring(game:HttpGet("https://raw.githubusercontent.com/kartytein/mrs/refs/heads/main/scrp2.lua"))()
else
    -- Запускаем скрипт отправки в Discord (детектор фруктов)
    loadstring(game:HttpGet("https://raw.githubusercontent.com/kartytein/mrs/refs/heads/main/config.lua"))()
end
