--from flask import Flask, request

--app = Flask(__name__)

--@app.route('/send', methods=['GET'])
--def send():
--    message = request.args.get('message', '')
--    if message:
--        print(f"Получено сообщение из Roblox: {message}")
--        return "OK", 200
--    return "No message", 400

--if __name__ == '__main__':
--    app.run(host='0.0.0.0', port=8000, debug=False)


local function sendMessage(text)
    local url = "http://192.168.1.100:8000/send?message=" .. text  -- замените IP
    local success, result = pcall(function()
        return game:HttpGet(url)
    end)
    if success then
        print("Сообщение отправлено:", text)
    else
        warn("Ошибка отправки:", result)
    end
end

-- Пример: отправить "1"
sendMessage("1")
