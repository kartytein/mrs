import subprocess
import time
import cv2
import numpy as np

# НАСТРОЙКИ
SERIAL = "127.0.0.1:5593"          # серийный номер эмулятора (порт)
PACKAGE_NAME = "com.roblox.client"  # пакет приложения
THRESHOLD = 0.8                     # порог совпадения

# Первый этап
BUTTON_TEMPLATE = "button.png"           # кнопка, которую ищем и кликаем
BUTTON_SUCCESS_TEMPLATE = "button1true.png"  # шаблон успешного нажатия кнопки
TEXT_TO_INPUT = "test123"                # текст для ввода

# Второй этап
PEOPLE_TEMPLATE = "people.png"           # следующая кнопка (people)
PEOPLE_SUCCESS_TEMPLATE = "peopleact.png" # шаблон успешного нажатия people

# Третий этап (клик по координатам)
COORD_CLICK_X = 200
COORD_CLICK_Y = 200
ADD_TEMPLATE = "add.png"                 # шаблон, появляющийся после успешного клика по координате

# Четвёртый этап (клик по add.png)
ADD_SUCCESS_TEMPLATE = "addactive.png"   # шаблон успешного нажатия add.png

# Тайминги и параметры
CLICK_DELAY = 3                     # задержка перед кликом после нахождения шаблона (или после предыдущего действия)
CHECK_DELAY = 2                     # пауза между проверками после клика
SUCCESS_CHECK_TIMEOUT = 10          # сколько секунд ждать успешный шаблон
TEXT_INPUT_DELAY = 1                # пауза перед вводом текста после успешной проверки
WAIT_TEMPLATE_TIMEOUT = 60          # таймаут ожидания шаблона (секунд)
MAX_ATTEMPTS = 3                    # максимальное количество попыток клика (включая первую)

def run_adb(command):
    """Выполняет ADB-команду для нашего эмулятора"""
    full_cmd = f"adb -s {SERIAL} {command}"
    result = subprocess.run(full_cmd, shell=True, capture_output=True, text=True)
    return result.stdout, result.stderr

def launch_app(package):
    """Запускает приложение по имени пакета"""
    print(f"Запускаю приложение {package}...")
    out, err = run_adb(f"shell monkey -p {package} -c android.intent.category.LAUNCHER 1")
    if err:
        print("Ошибка запуска:", err)

def force_stop_app(package):
    """Останавливает приложение"""
    print(f"Останавливаю приложение {package}...")
    run_adb(f"shell am force-stop {package}")

def take_screenshot():
    """Делает скриншот эмулятора и возвращает изображение"""
    run_adb("shell screencap /sdcard/screen.png")
    run_adb("pull /sdcard/screen.png")
    img = cv2.imread("screen.png")
    if img is None:
        raise Exception("Не удалось загрузить скриншот")
    return img

def find_template(screen_img, template_path, threshold):
    """Ищет шаблон на скриншоте, возвращает координаты центра и уверенность"""
    template = cv2.imread(template_path)
    if template is None:
        raise FileNotFoundError(f"Шаблон {template_path} не найден. Проверь, что файл лежит рядом со скриптом.")
    
    screen_gray = cv2.cvtColor(screen_img, cv2.COLOR_BGR2GRAY)
    template_gray = cv2.cvtColor(template, cv2.COLOR_BGR2GRAY)
    
    result = cv2.matchTemplate(screen_gray, template_gray, cv2.TM_CCOEFF_NORMED)
    _, max_val, _, max_loc = cv2.minMaxLoc(result)
    
    if max_val >= threshold:
        h, w = template_gray.shape
        center_x = max_loc[0] + w // 2
        center_y = max_loc[1] + h // 2
        return (center_x, center_y), max_val
    else:
        return None, max_val

def click(x, y):
    """Кликает по указанным координатам"""
    run_adb(f"shell input tap {x} {y}")

def input_text(text):
    """Вводит текст через ADB"""
    run_adb(f"shell input text '{text}'")

def press_enter():
    """Нажимает клавишу Enter"""
    run_adb("shell input keyevent 66")

def wait_and_click_template(template_path, timeout=WAIT_TEMPLATE_TIMEOUT):
    """Ожидает появления шаблона на экране и кликает по нему.
    Возвращает True, если шаблон найден и клик выполнен, иначе False."""
    print(f"Ожидаю появления шаблона '{template_path}' (таймаут {timeout} сек)...")
    start_time = time.time()
    while time.time() - start_time < timeout:
        screen = take_screenshot()
        pos, confidence = find_template(screen, template_path, THRESHOLD)
        if pos:
            print(f"Шаблон найден! Координаты: {pos}, уверенность: {confidence:.2f}")
            print(f"Жду {CLICK_DELAY} секунд перед кликом...")
            time.sleep(CLICK_DELAY)
            click(*pos)
            print("Клик выполнен.")
            return True
        else:
            print(f"Шаблон не найден, уверенность: {confidence:.2f}. Жду 2 секунды...")
            time.sleep(2)
    print(f"Время ожидания шаблона '{template_path}' истекло ({timeout} сек).")
    return False

def check_success_template(success_template_path):
    """Проверяет, появился ли шаблон успешного состояния.
    Возвращает True, если шаблон найден, иначе False."""
    print(f"Проверяю появление шаблона успеха '{success_template_path}'...")
    check_start = time.time()
    while time.time() - check_start < SUCCESS_CHECK_TIMEOUT:
        time.sleep(CHECK_DELAY)
        screen = take_screenshot()
        pos_success, conf_success = find_template(screen, success_template_path, THRESHOLD)
        if pos_success:
            print(f"Успех! Шаблон '{success_template_path}' найден. Уверенность: {conf_success:.2f}")
            return True
        else:
            print(f"Шаблон успеха не найден, уверенность: {conf_success:.2f}. Пробую ещё...")
    print(f"Шаблон '{success_template_path}' не появился за отведённое время.")
    return False

def perform_click_and_verify(click_template, success_template):
    """Выполняет клик по шаблону и проверяет успешность. Повторяет до MAX_ATTEMPTS раз.
    Возвращает True при успехе, иначе False."""
    for attempt in range(1, MAX_ATTEMPTS + 1):
        print(f"\n--- Попытка {attempt} из {MAX_ATTEMPTS} для шаблона '{click_template}' ---")
        if not wait_and_click_template(click_template):
            print(f"Шаблон '{click_template}' не появился за таймаут.")
            return False
        if check_success_template(success_template):
            return True
        else:
            print("Проверка успеха не удалась после клика.")
            if attempt < MAX_ATTEMPTS:
                print("Пробую ещё раз...")
                time.sleep(2)
            else:
                print("Все попытки исчерпаны.")
                return False

def perform_coordinate_click_and_verify(x, y, success_template):
    """Кликает по координатам и проверяет появление success_template. Повторяет до MAX_ATTEMPTS."""
    for attempt in range(1, MAX_ATTEMPTS + 1):
        print(f"\n--- Попытка {attempt} из {MAX_ATTEMPTS} для клика по координате ({x},{y}) ---")
        print(f"Кликаю по координате ({x}, {y})")
        click(x, y)
        print("Клик выполнен.")
        if check_success_template(success_template):
            return True
        else:
            print("Шаблон успеха не появился после клика по координате.")
            if attempt < MAX_ATTEMPTS:
                print("Пробую ещё раз...")
                time.sleep(2)
            else:
                print("Все попытки исчерпаны.")
                return False

def run_automation():
    """Основная логика: все этапы кликов, ввода текста и проверок.
    Возвращает True при полном успехе, False при неудаче."""
    # Этап 1: кнопка -> подтверждение -> ввод текста -> Enter
    print("\n=== Этап 1: кнопка и ввод текста ===")
    if not perform_click_and_verify(BUTTON_TEMPLATE, BUTTON_SUCCESS_TEMPLATE):
        return False
    
    print("Теперь ввожу текст...")
    time.sleep(TEXT_INPUT_DELAY)
    input_text(TEXT_TO_INPUT)
    print(f"Текст '{TEXT_TO_INPUT}' введён.")
    print("Нажимаю Enter...")
    time.sleep(0.5)
    press_enter()
    print("Enter нажат.")

    # Этап 2: people -> клик -> подтверждение peopleact
    print("\n=== Этап 2: people и подтверждение ===")
    if not perform_click_and_verify(PEOPLE_TEMPLATE, PEOPLE_SUCCESS_TEMPLATE):
        return False

    # Этап 3: клик по координате и ожидание add.png
    print("\n=== Этап 3: клик по координате и ожидание add.png ===")
    # Ждём 3 секунды после подтверждения peopleact перед кликом по координате
    time.sleep(CLICK_DELAY)
    if not perform_coordinate_click_and_verify(COORD_CLICK_X, COORD_CLICK_Y, ADD_TEMPLATE):
        return False
    print("Координата успешно нажата, add.png появился.")

    # Этап 4: клик по add.png и проверка addactive.png
    print("\n=== Этап 4: клик по add.png и проверка addactive.png ===")
    if not perform_click_and_verify(ADD_TEMPLATE, ADD_SUCCESS_TEMPLATE):
        return False

    print("Все этапы выполнены успешно!")
    return True

def main():
    # Проверяем подключение
    out, _ = run_adb("get-state")
    if "device" not in out:
        print("Устройство не подключено, пробую подключиться...")
        run_adb(f"connect {SERIAL}")
        time.sleep(2)
    
    # Запускаем приложение в первый раз
    launch_app(PACKAGE_NAME)
    
    # Основной цикл с перезапуском при неудаче
    restart_count = 0
    while True:
        print(f"\n=== Запуск автоматизации (перезапусков: {restart_count}) ===")
        success = run_automation()
        if success:
            print("Автоматизация успешно завершена!")
            break
        else:
            print("Автоматизация не удалась. Перезапускаю приложение...")
            force_stop_app(PACKAGE_NAME)
            time.sleep(2)
            launch_app(PACKAGE_NAME)
            restart_count += 1
            # Опционально можно добавить лимит перезапусков

if __name__ == "__main__":
    main()
