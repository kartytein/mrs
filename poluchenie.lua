--from flask import Flask, jsonify

--app = Flask(__name__)

--# Здесь вы можете указать свой server_id
--SERVER_ID = "EXAMPLE123"

--@app.route('/get_server_id', methods=['GET'])
--def get_server_id():
   -- return jsonify({"server_id": SERVER_ID})

--if __name__ == '__main__':
--    # Запускаем сервер на всех интерфейсах, порт 8000
--    app.run(host='0.0.0.0', port=8000, debug=False)



-- ===== ПОЛУЧЕНИЕ SERVER_ID С PYTHON-СЕРВЕРА =====
local http = game:GetService("HttpService")
local url = "http://192.168.1.100:8000/get_server_id"  -- замените на ваш IP

local function fetchServerId()
    local success, response = pcall(function()
        return game:HttpGet(url)
    end)
    if success and response then
        local data = http:JSONDecode(response)
        if data and data.server_id then
            print("Получен server_id:", data.server_id)
            return data.server_id
        else
            warn("Не удалось получить server_id из ответа")
        end
    else
        warn("Ошибка запроса:", response)
    end
    return nil
end

-- Пример использования: вызвать один раз или в цикле
local id = fetchServerId()
if id then
    print("SERVER_ID:", id)
else
    print("Не удалось получить server_id")
end
