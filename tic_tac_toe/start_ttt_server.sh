#!/bin/bash

PORT=12346
STATE_DIR="/tmp/wazzap_ttt"

echo "[*] Starting Wazzap Tic-Tac-Toe server..."

# Stop an old listener if one is still using the port
OLD_PID=$(fuser ${PORT}/tcp 2>/dev/null)

if [ -n "$OLD_PID" ]; then
    echo "[*] Stopping old server on port $PORT..."
    fuser -k ${PORT}/tcp >/dev/null 2>&1
    sleep 1
fi

# Remove stale multiplayer state
if [ -d "$STATE_DIR" ]; then
    echo "[*] Cleaning old lobby state..."
    rm -rf "$STATE_DIR"
fi

echo "[+] Lobby ready"
echo "[+] Listening on TCP port $PORT"
echo "[+] Waiting for two players..."
echo

ncat -lk -p "$PORT" -c "./tic_tac_toe.sh"
