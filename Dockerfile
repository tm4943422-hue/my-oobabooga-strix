FROM ubuntu:22.04

# Отключаем интерактивные запросы при установке
ENV DEBIAN_FRONTEND=noninteractive
ENV ROCM_PATH=/opt/rocm
ENV LD_LIBRARY_PATH=/opt/rocm/lib:/usr/lib/x86_64-linux-gnu:$LD_LIBRARY_PATH

# 1. Системные зависимости
RUN apt-get update && apt-get install -y \
    build-essential cmake git libomp-dev libxml2-dev \
    wget tzdata nano && \
    rm -rf /var/lib/apt/lists/*

# 2. Установка ROCm 7.2.4
RUN wget https://repo.radeon.com/amdgpu-install/7.2.4/ubuntu/jammy/amdgpu-install_7.2.4.70204-1_all.deb && \
    apt-get update && apt-get install -y ./amdgpu-install_7.2.4.70204-1_all.deb && \
    amdgpu-install --usecase=rocm --no-dkms -y && \
    rm amdgpu-install_7.2.4.70204-1_all.deb && \
    rm -rf /var/lib/apt/lists/*

# 3. Установка Miniconda и создание среды
RUN wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O miniconda.sh && \
    bash miniconda.sh -b -p /opt/conda && \
    rm miniconda.sh
ENV PATH="/opt/conda/bin:$PATH"
RUN conda create -n textgen python=3.11 -y

# Переключаем выполнение команд Docker внутрь среды Conda
SHELL ["conda", "run", "-n", "textgen", "/bin/bash", "-c"]

# 4. Подготовка окружения и клонирование Oobabooga
WORKDIR /app
RUN git clone https://github.com/oobabooga/text-generation-webui
WORKDIR /app/text-generation-webui

# 5. Установка PyTorch и зависимостей веб-интерфейса
RUN pip install --no-cache-dir torch torchvision torchaudio markupsafe pillow --index-url https://download.pytorch.org/whl/rocm7.2
RUN pip install --no-cache-dir -r requirements.txt

# 6. Сборка llama-cpp-binaries жестко под Strix Halo (gfx1151)
RUN git clone https://github.com/oobabooga/llama-cpp-binaries && \
    cd llama-cpp-binaries && \
    sed -i 's/git@github.com:/https:\/\/github.com\//g' .gitmodules && \
    git submodule sync && \
    git submodule update --init --recursive && \
    export CFLAGS="-I${ROCM_PATH}/include" && \
    export CXXFLAGS="-I${ROCM_PATH}/include" && \
    export LDFLAGS="-L${ROCM_PATH}/lib -Wl,--allow-shlib-undefined -Wl,-rpath=${ROCM_PATH}/lib" && \
    export CMAKE_TLS_VERIFY=0 && \
    export CMAKE_ARGS="-DGGML_HIP=ON -DGPU_TARGETS=gfx1151 -DCMAKE_PREFIX_PATH=${ROCM_PATH} -DLLAMA_SERVER=OFF -DLLAMA_CURL=OFF" && \
    sed -i 's/license = "AGPL-3.0-only"/license = {text = "AGPL-3.0-only"}/g' pyproject.toml && \
    FORCE_CMAKE=1 pip install . --no-cache-dir --force-reinstall --no-build-isolation && \
    cd .. && rm -rf llama-cpp-binaries

# 7. Подготовка кастомного скрипта запуска
COPY start_custom.sh /app/text-generation-webui/start_custom.sh
RUN chmod +x /app/text-generation-webui/start_custom.sh

# Открываем порты для UI и API агентов
EXPOSE 7860 5000

# Запускаем скрипт без оболочки SHELL, чтобы он сам активировал Conda
ENTRYPOINT ["/bin/bash", "/app/text-generation-webui/start_custom.sh"]
