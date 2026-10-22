#!/bin/bash

export LINE='\n'
export RESET='\033[0m'
export WhiteText='\033[0;37m'
export RedBoldText='\033[1;31m'
export GreenBoldText='\033[1;32m'
export YellowBoldText='\033[1;33m'
export CyanBoldText='\033[1;36m'

LogInfo() {
  Log "$1" "$WhiteText"
}
LogWarn() {
  Log "$1" "$YellowBoldText"
}
LogError() {
  Log "$1" "$RedBoldText"
}
LogSuccess() {
  Log "$1" "$GreenBoldText"
}
LogAction() {
  Log "$1" "$CyanBoldText" "====" "===="
}
Log() {
  local message="$1"
  local color="$2"
  local prefix="$3"
  local suffix="$4"

  printf "$color%s$RESET$LINE" "$prefix$message$suffix"
}

write_config() {
  local auto_create_world_seed_json
  if [ -n "${AUTO_CREATE_WORLD_SEED:-}" ] && [ "${AUTO_CREATE_WORLD_SEED}" != "null" ]; then
    auto_create_world_seed_json="\"${AUTO_CREATE_WORLD_SEED}\""
  else
    auto_create_world_seed_json="null"
  fi

  cat > /home/steam/server-files/config.json <<EOF
{
  "AutoStartWorldName": "${AUTO_START_WORLD_NAME:-}",
  "AutoCreateAndLoadWorld": ${AUTO_CREATE_AND_LOAD_WORLD:-true},
  "AutoCreateWorldSize": ${AUTO_CREATE_WORLD_SIZE:-1},
  "AutoCreateWorldSeed": ${auto_create_world_seed_json},
  "Password": "${PASSWORD:-}",
  "Port": ${PORT:-8050},
  "MaxPlayers": ${MAX_PLAYERS:-8},
  "EnableCheats": ${ENABLE_CHEATS:-false}
}
EOF

  LogSuccess "Wrote /home/steam/server-files/config.json"
}

install() {
  LogAction "Starting server install"
  LogInfo "Installing Romestead Dedicated Server"

  /depotdownloader/DepotDownloader \
    -app 4763510 \
    -dir /home/steam/server-files \
    -validate

  patch -l -p1 -d /home/steam/server-files < server.patch
  cp -r /home/steam/server/linux-arm64 /home/steam/server-files/runtimes
  LogSuccess "Server install complete"
}

shutdown_server() {
  local return_val=0
  LogAction "Attempting graceful server shutdown"

  local pid
  pid=$(pgrep -f "dotnet Server.dll")

  if [ -n "$pid" ]; then
    echo "stop" > /tmp/romestead-stdin

    local count=0
    while [ $count -lt 30 ] && kill -0 "$pid" 2>/dev/null; do
      sleep 1
      count=$((count + 1))
    done

    if kill -0 "$pid" 2>/dev/null; then
      LogWarn "Server did not shutdown gracefully, forcing shutdown"
      return_val=1
    else
      LogSuccess "Server shutdown gracefully"
    fi
  else
    LogWarn "Server process not found"
    return_val=1
  fi

  return "$return_val"
}
