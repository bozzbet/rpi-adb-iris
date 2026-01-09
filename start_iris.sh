#!/data/data/com.termux/files/usr/bin/bash
set -e

# ===============================
# Environment
# ===============================
export PREFIX=/data/data/com.termux/files/usr
export HOME=/data/data/com.termux/files/home
export PATH="$PREFIX/bin:$PATH"

BASE_DIR="$HOME/ccminerd"
PIDFILE="$HOME/ccminer.pid"

# ===============================
# Find config folder
# ===============================
CONFIG_DIRS=$(find "$BASE_DIR" -mindepth 1 -maxdepth 1 -type d ! -name '.git' | wc -l)

if [ "$CONFIG_DIRS" -eq 0 ]; then
  echo "[✗] No miner config folder found in $BASE_DIR"
  exit 1
fi

if [ "$CONFIG_DIRS" -gt 1 ]; then
  echo "[✗] Multiple miner config folders found:"
  find "$BASE_DIR" -mindepth 1 -maxdepth 1 -type d
  echo "Refusing to start. Only ONE config folder is allowed per phone."
  exit 1
fi

MINER_DIR=$(find "$BASE_DIR" -mindepth 1 -maxdepth 1 -type d)
CONFIG_FILE="$MINER_DIR/config.json"

if [ ! -f "$CONFIG_FILE" ]; then
  echo "[✗] Missing config.json in $MINER_DIR"
  exit 1
fi

MINER_NAME=$(basename "$MINER_DIR")

# ===============================
# Stop existing miner
# ===============================
if [ -f "$PIDFILE" ] && ps -p "$(cat "$PIDFILE")" >/dev/null 2>&1; then
  echo "[*] Stopping existing miner"
  kill "$(cat "$PIDFILE")"
  sleep 2
fi

# ===============================
# Keep CPU awake
# ===============================
termux-wake-lock

cd "$BASE_DIR"

# ===============================
# Start miner (fake TTY)
# ===============================
echo "[*] Starting miner: $MINER_NAME"

script -q -c "./ccminer -c \"$CONFIG_FILE\"" &
PID=$!

echo "$PID" > "$PIDFILE"

# ===============================
# Status
# ===============================
echo
echo "Mining started"
echo "=============="
echo "Miner: $MINER_NAME"
echo "PID:   $PID"
echo
