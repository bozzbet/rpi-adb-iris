#!/data/data/com.termux/files/usr/bin/bash
set -e

# ==================================================
# Environment
# ==================================================
export PREFIX=/data/datacom.termux/files/usr
export HOME=/data/data/com.termux/files/home
export PATH="$PREFIX/bin:$PATH"

PIDFILE="$HOME/ccminer.pid"

# ==================================================
# Stop miner if running
# ==================================================
if [ ! -f "$PIDFILE" ]; then
  echo "[*] Miner is not running (no PID file)"
else
  PID=$(cat "$PIDFILE" 2>/dev/null || true)

  if [ -n "$PID" ] && ps -p "$PID" >/dev/null 2>&1; then
    echo "[*] Stopping miner (PID $PID)"
    kill "$PID"
    sleep 2
  else
    echo "[*] Stale PID file found, cleaning up"
  fi

  rm -f "$PIDFILE"
fi

# ==================================================
# Release wakelock
# ==================================================
termux-wake-unlock >/dev/null 2>&1 || true

echo "[✓] Miner stopped"
