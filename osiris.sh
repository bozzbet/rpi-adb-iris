#!/data/data/com.termux/files/usr/bin/bash

set -e
#set -euo pipefail

# ===============================
# Environment
# ===============================
export PREFIX=/data/data/com.termux/files/usr
export HOME=/data/data/com.termux/files/home
export PATH="$PREFIX/bin:$PATH"

BASE_DIR="$HOME/ccminerd"
PIDFILE="$HOME/ccminer.pid"

RESTART_DELAY=10
MAX_RUNTIME=0          # seconds, 0 = disabled
HANG_TIMEOUT=300       # seconds of zero CPU before restart

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
if [ -f "$PIDFILE" ]; then
  OLD_PID=$(cat "$PIDFILE" || true)
  if [ -n "${OLD_PID:-}" ] && ps -p "$OLD_PID" >/dev/null 2>&1; then
    echo "[*] Stopping existing miner"
    kill "$OLD_PID" 2>/dev/null || true
    sleep 2
    if ps -p "$OLD_PID" >/dev/null 2>&1; then
      echo "[!] Miner did not stop, sending SIGKILL"
      kill -9 "$OLD_PID" 2>/dev/null || true
    fi
  fi
fi

# ===============================
# Keep CPU awake
# ===============================
termux-wake-lock || true

cd "$BASE_DIR"

echo "[*] Starting miner watchdog for: $MINER_NAME"
echo "[*] Config: $CONFIG_FILE"
echo

# ===============================
# Watchdog loop (no logs)
# ===============================
while true; do
  START_TS=$(date +%s)

  echo "[*] Launching ccminer..."
  ./ccminer -c "$CONFIG_FILE" &
  PID=$!
  echo "$PID" > "$PIDFILE"
  echo "[*] ccminer pid=$PID"

  # Track CPU time to detect hangs
  LAST_CPU_TS=$(date +%s)
  LAST_CPU_TICKS=$(ps -o cputime= -p "$PID" 2>/dev/null | tr -d ' ' || echo "0")

  while ps -p "$PID" >/dev/null 2>&1; do
    sleep 5
    NOW=$(date +%s)

    # -------------------------------
    # Max runtime enforcement
    # -------------------------------
    if [ "$MAX_RUNTIME" -gt 0 ]; then
      RUNTIME=$((NOW - START_TS))
      if [ "$RUNTIME" -ge "$MAX_RUNTIME" ]; then
        echo "[!] MAX_RUNTIME reached (${RUNTIME}s), killing miner"
        kill "$PID" 2>/dev/null || true
        sleep 2
        kill -9 "$PID" 2>/dev/null || true
        break
      fi
    fi

    # -------------------------------
    # CPU stall / hang detection
    # -------------------------------
    CPU_TICKS=$(ps -o cputime= -p "$PID" 2>/dev/null | tr -d ' ' || echo "0")

    if [ "$CPU_TICKS" != "$LAST_CPU_TICKS" ]; then
      LAST_CPU_TICKS="$CPU_TICKS"
      LAST_CPU_TS="$NOW"
    else
      IDLE=$((NOW - LAST_CPU_TS))
      if [ "$IDLE" -ge "$HANG_TIMEOUT" ]; then
        echo "[!] Miner CPU stalled for ${IDLE}s, assuming hang. Killing..."
        kill "$PID" 2>/dev/null || true
        sleep 2
        kill -9 "$PID" 2>/dev/null || true
        break
      fi
    fi
  done

  END_TS=$(date +%s)
  RUNTIME=$((END_TS - START_TS))
  echo "[!] ccminer exited or was killed (runtime=${RUNTIME}s)"
  echo "[*] Restarting in ${RESTART_DELAY}s..."
  sleep "$RESTART_DELAY"
done
