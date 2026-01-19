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
LOGFILE="$BASE_DIR/ccminer.log"

RESTART_DELAY=10          # seconds before restart
MAX_RUNTIME=0             # 0 = disabled, otherwise seconds

LOG_MAX_SIZE=$((10 * 1024 * 1024))   # 10 MB
LOG_BACKUPS=3

# ===============================
# Find config folder (EXACTLY ONE)
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
MINER_NAME=$(basename "$MINER_DIR")

if [ ! -f "$CONFIG_FILE" ]; then
  echo "[✗] Missing config.json in $MINER_DIR"
  exit 1
fi

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

echo "[*] Starting miner watchdog for: $MINER_NAME"
echo "[*] Config: $CONFIG_FILE"
echo

# ===============================
# Maintain LogSize
# ===============================

rotate_log() {
  [ -f "$LOGFILE" ] || return 0

  SIZE=$(stat -c %s "$LOGFILE" 2>/dev/null || wc -c < "$LOGFILE")

  if [ "$SIZE" -lt "$LOG_MAX_SIZE" ]; then
    return 0
  fi

  echo "[*] Rotating log (size=${SIZE} bytes)"

  i=$LOG_BACKUPS
  while [ "$i" -gt 0 ]; do
    if [ -f "$LOGFILE.$i" ]; then
      mv "$LOGFILE.$i" "$LOGFILE.$((i+1))"
    fi
    i=$((i - 1))
  done

  mv "$LOGFILE" "$LOGFILE.1"
  : > "$LOGFILE"
}

# ===============================
# Watchdog loop
# ===============================
while true; do
  rotate_log
  START_TS=$(date +%s)

  echo "[*] Launching ccminer..."
  # script -q -c "./ccminer -c \"$CONFIG_FILE\"" >> "$LOGFILE" 2>&1 &
  script -q -f -c "./ccminer -c \"$CONFIG_FILE\"" "$LOGFILE" &

  PID=$!

  echo "$PID" > "$PIDFILE"

  wait "$PID"
  EXIT_CODE=$?

  END_TS=$(date +%s)
  RUNTIME=$((END_TS - START_TS))

  echo "[!] ccminer exited (code=$EXIT_CODE, runtime=${RUNTIME}s)"

  if [ "$MAX_RUNTIME" -gt 0 ] && [ "$RUNTIME" -ge "$MAX_RUNTIME" ]; then
    echo "[*] Max runtime reached — restarting miner"
  fi

  sleep "$RESTART_DELAY"
done
