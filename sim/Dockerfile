# Headless Connect IQ simulator (needs webkit2gtk-4.0, gone from newer Ubuntu)
FROM ubuntu:22.04
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
    libwebkit2gtk-4.0-37 libsoup2.4-1 libjavascriptcoregtk-4.0-18 libusb-1.0-0 libsm6 \
    libxtst6 libxrender1 libxi6 xvfb x11-apps imagemagick xdotool ca-certificates fonts-dejavu-core \
    && rm -rf /var/lib/apt/lists/*
