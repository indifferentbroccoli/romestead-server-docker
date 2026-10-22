FROM mcr.microsoft.com/dotnet/sdk:8.0-alpine AS steamworks_build

RUN apk add git

WORKDIR /opt/build
RUN git clone --depth 1 --branch 2025.164.1 https://github.com/rlabrecque/Steamworks.NET.git
WORKDIR /opt/build/Steamworks.NET
COPY ./patches/steamworks.patch ./steamworks.patch
RUN git apply ./steamworks.patch

WORKDIR /opt/build/Steamworks.NET/Standalone2.0
RUN dotnet build -t:BatchBuild Steamworks.NET.Standard.sln

FROM alpine AS dd-amd64
ARG DEPOT_DOWNLOADER_VERSION=3.4.0
ADD https://github.com/SteamRE/DepotDownloader/releases/download/DepotDownloader_${DEPOT_DOWNLOADER_VERSION}/DepotDownloader-linux-x64.zip /tmp/dd.zip

FROM alpine AS dd-arm64
ARG DEPOT_DOWNLOADER_VERSION=3.4.0
ADD https://github.com/SteamRE/DepotDownloader/releases/download/DepotDownloader_${DEPOT_DOWNLOADER_VERSION}/DepotDownloader-linux-arm64.zip /tmp/dd.zip

FROM dd-${TARGETARCH} AS dd
RUN mkdir -p /depotdownloader && \
    unzip /tmp/dd.zip -d /depotdownloader && \
    chmod +x /depotdownloader/DepotDownloader && \
    rm /tmp/dd.zip

# BUILD THE SERVER IMAGE
FROM mcr.microsoft.com/dotnet/runtime:8.0-bookworm-slim AS final

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    procps \
    libicu-dev \
    gettext-base \
    patch \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

COPY --from=dd /depotdownloader /depotdownloader

RUN useradd -m -s /bin/bash steam

ENV HOME=/home/steam \
    UPDATE_ON_START=true \
    AUTO_START_WORLD_NAME="" \
    AUTO_CREATE_AND_LOAD_WORLD=true \
    AUTO_CREATE_WORLD_SIZE=1 \
    AUTO_CREATE_WORLD_SEED=null \
    PASSWORD="" \
    PORT=8050 \
    MAX_PLAYERS=8 \
    ENABLE_CHEATS=false

COPY ./scripts /home/steam/server/
COPY ./patches/server.patch /home/steam/server/server.patch
COPY --from=steamworks_build /opt/build/Steamworks.NET/Standalone2.0/bin/nuget/runtime/linux-arm64 /home/steam/server/linux-arm64

COPY branding /branding

RUN mkdir -p /home/steam/server-files && \
    chmod +x /home/steam/server/*.sh

WORKDIR /home/steam/server

ENTRYPOINT ["/home/steam/server/init.sh"]