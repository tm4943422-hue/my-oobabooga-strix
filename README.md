# my-oobabooga-strix
# Oobabooga Docker & Conda: AMD Strix Halo (gfx1151) Optimized

Эта сборка представляет собой полностью изолированный, готовый к работе Docker-контейнер с [Text-Generation-WebUI (Oobabooga)](https://github.com/oobabooga/text-generation-webui). 

Главная особенность: движок `llama.cpp` **жестко скомпилирован под архитектуру AMD Strix Halo (gfx1151)** с использованием ROCm 7.2.4. 

## ⚠️ Важное предупреждение по железу
Этот образ собран с флагом компилятора `-DGPU_TARGETS=gfx1151`. Это означает, что аппаратное ускорение будет работать **только на APU архитектуры Strix Halo**. На других видеокартах AMD (RDNA2, RDNA3) или NVIDIA пакет выдаст ошибку совместимости.

## Зачем нужен этот репозиторий?
1. **Решение проблемы с `libxml2` на новых ОС:** Устраняет конфликт зависимостей компилятора LLVM/lld в инструментах AMD ROCm на дистрибутивах вроде Ubuntu 24.04+ (t64 transition).
2. **Чистая среда Miniconda:** Внутри контейнера развернута полноценная среда Conda для максимальной стабильности C/C++ зависимостей.
3. **Готовность к агентам:** Автоматически открыт API-порт (5000) для подключения внешних фреймворков вроде Roo Code или CrewAI.
4. **Бесшовная установка расширений:** Скрипт запуска сам проверяет и устанавливает `requirements.txt` для активированных плагинов.
5. **Авто-переключение моделей для Roo Code:** Родной OpenAI API oobabooga игнорирует поле `model` в запросе и всегда отвечает той моделью, что уже загружена. Roo Code при выборе модели в интерфейсе не вызывает `/v1/internal/model/load`, поэтому переключение "не работает". Контейнер поднимает на порту **5005** прокси (`model_switch_proxy.py`), который сверяет `model` из запроса с реально загруженной моделью и сам вызывает `/v1/internal/model/load` при расхождении.

## 🚀 Быстрый старт

### Требования
* ОС Linux с установленными драйверами `amdgpu`.
* Установленный Docker и плагин Docker Compose.

### Установка и запуск
1. Склонируйте репозиторий:
   ```bash
   git clone https://github.com/tm4943422-hue/my-oobabooga-strix
   cd textgen-webui

Запустите сборку и старт контейнера:

   ```bash
   docker compose up --build -d


Первая сборка займет время, так как Docker скачает ROCm и скомпилирует llama.cpp с нуля.

Положите ваши нейросети в формате .gguf в появившуюся папку models/.

Откройте веб-интерфейс в браузере: http://127.0.0.1:7860

⚙️ Критические настройки в браузере (UMA Memory)
Так как мы используем APU с объединенной памятью (UMA), при первой загрузке модели обязательно перейдите на вкладку Model и активируйте:

✅ no_mmap — загружает веса модели напрямую в выделенную оперативную память (спасает от намертво зависшей системы).

✅ flash_attn — экономит память и ускоряет генерацию токенов.

Порты по умолчанию
7860 — Web UI (браузер)

5000 — OpenAI-совместимый API (родной, без авто-переключения моделей)

5005 — Прокси с авто-переключением моделей — **используйте этот порт в Roo Code / CrewAI**, чтобы выбор модели в клиенте реально переключал модель на сервере

Лицензия
Этот проект распространяется под лицензией AGPL-3.0, наследуя лицензию оригинальных репозиториев Oobabooga.

# Oobabooga Docker & Conda: AMD Strix Halo (gfx1151) Optimized

This build is a fully isolated, ready-to-use Docker container with [Text-Generation-WebUI (Oobabooga)](https://github.com/oobabooga/text-generation-webui). 

The main feature: the `llama.cpp` engine here is **hard-compiled for the AMD Strix Halo (gfx1151) architecture** using ROCm 7.2.4.

## ⚠️ Important Hardware Warning
This image is built with the `-DGPU_TARGETS=gfx1151` compiler flag. This means hardware acceleration will **only work on Strix Halo architecture APUs**. On other AMD GPUs (RDNA2, RDNA3) or NVIDIA, the package will throw a compatibility error.

## Why does this repository exist?
1. **Fixes the `libxml2` issue on newer OS:** Resolves the LLVM/lld compiler dependency conflict in AMD ROCm tools on distributions like Ubuntu 24.04+ (t64 transition).
2. **Clean Miniconda Environment:** A full Conda environment is deployed inside the container for maximum C/C++ dependency stability.
3. **Agent-Ready:** The API port (5000) is automatically exposed for connecting external frameworks like Roo Code or CrewAI.
4. **Seamless Extension Installation:** The startup script automatically checks and installs `requirements.txt` for activated plugins.
5. **Model auto-switch for Roo Code:** oobabooga's native OpenAI API ignores the `model` field in requests and always answers with whatever model is currently loaded. Roo Code never calls `/v1/internal/model/load` when you pick a model in its UI, so switching "does nothing". The container runs a proxy (`model_switch_proxy.py`) on port **5005** that compares the request's `model` field against the currently loaded model and calls `/v1/internal/model/load` itself when they differ.

## 🚀 Quick Start

### Requirements
* Linux OS with `amdgpu` drivers installed.
* Installed Docker and Docker Compose plugin.

### Installation and Run
1. Clone the repository:
   ```bash
   git clone https://github.com/tm4943422-hue/my-oobabooga-strix
   cd textgen-webui

Build and start the container:

   ```bash
   docker compose up --build -d

The first build will take some time as Docker downloads ROCm and compiles llama.cpp from scratch.

Place your neural networks in .gguf format into the newly created models/ folder.

Open the web interface in your browser: http://127.0.0.1:7860

⚙️ Critical Browser Settings (UMA Memory)
Since we are using an APU with Unified Memory Architecture (UMA), when loading a model for the first time, you must go to the Model tab and check:

✅ no_mmap — loads model weights directly into allocated RAM (saves the system from freezing completely).

✅ flash_attn — saves memory and speeds up token generation.

Default Ports
7860 — Web UI (browser)

5000 — OpenAI-compatible API (native, no model auto-switch)

5005 — Model auto-switch proxy — **point Roo Code / CrewAI at this port** so picking a model in the client actually switches it on the server

License
This project is distributed under the AGPL-3.0 license, inheriting the license of the original Oobabooga repositories.
