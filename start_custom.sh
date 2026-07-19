#!/bin/bash

# Активируем среду Conda
source /opt/conda/etc/profile.d/conda.sh
conda activate textgen

# Ищем пути к библиотекам ROCm
SP_PATH=$(python -c "import site; print(site.getsitepackages()[0])")
export LD_LIBRARY_PATH="${SP_PATH}/_rocm_sdk_devel/lib:${SP_PATH}/_rocm_sdk_core/lib:$LD_LIBRARY_PATH"

echo "Проверка и установка зависимостей для расширений..."

# Список расширений, для которых нужно проверять requirements.txt
EXTENSIONS=(
    "google_translate"
    #"silero_tts"
    #"sd_api_pictures"
    #"send_pictures"
    #"superboogav2"
)

# Проходим по списку и устанавливаем пакеты, если файл существует
for ext in "${EXTENSIONS[@]}"; do
    REQ_FILE="extensions/$ext/requirements.txt"
    if [ -f "$REQ_FILE" ]; then
        echo "Установка пакетов для: $ext"
        pip install -r "$REQ_FILE" --upgrade --quiet
    fi
done

# Отдельно устанавливаем whisper
pip install openai-whisper --upgrade --quiet

# Запускаем прокси авто-переключения моделей (для Roo Code / CrewAI на порту 5005).
# Он перехватывает /v1/chat/completions и /v1/completions, сверяет поле "model"
# с реально загруженной моделью и при расхождении дергает /v1/internal/model/load,
# чего сам oobabooga не делает.
python model_switch_proxy.py &

# Запускаем сервер
python server.py \
    --listen \
    --listen-host 0.0.0.0 \
    --api \
    --loader llama.cpp \
    --n_ctx 8192
