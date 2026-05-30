FROM ubuntu:22.04

RUN apt-get update && apt-get install -y \
    libgl1 \
    libgles2 \
    libx11-6 \
    libxcursor1 \
    libxinerama1 \
    libxrandr2 \
    libxi6 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY export/server/ .

RUN chmod +x FishGambleGame.x86_64 && mkdir -p data

EXPOSE 7070

CMD ["./FishGambleGame.x86_64", "--headless", "--server"]
