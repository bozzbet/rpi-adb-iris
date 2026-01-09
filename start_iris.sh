#!/data/data/com.termux/files/usr/bin/bash

export PREFIX=/data/data/com.termux/files/usr
export HOME=/data/data/com.termux/files/home
export PATH=$PREFIX/bin:$PATH

#LOG="$HOME/ccminerd/log/ccminer.log"
PIDFILE="$HOME/ccminer.pid"
#MAX_LINES=50

# Ensure log directory exists
#mkdir -p "$(dirname "$LOG")"

# Stop existing miner if running
if [ -f "$PIDFILE" ] && ps -p "$(cat "$PIDFILE")" >/dev/null 2>&1; then
    kill "$(cat "$PIDFILE")"
    sleep 2
fi

# Keep CPU awake
termux-wake-lock

cd "$HOME/ccminerd"

# Start miner (append logs in real time)
#nohup "$HOME/ccminerd/ccminer" \
#  -c "$HOME/ccminerd/config.json" \
#  >"$LOG" 2>&1 &

# Clear old log once on start (important)
#: > "$LOG"

# Start miner with fake TTY (CRITICAL)
script -q -c "./ccminer -c config.json" & # "$LOG" &
PID=$!
echo "$PID" > "$PIDFILE"

# Background log trimmer (keeps last 50 lines)
#(
#  while kill -0 "$PID" 2>/dev/null; do
#    echo "[log-trim] $(date '+%Y-%m-%d %H:%M:%S')" >> "$LOG"
    # Trim log to last N lines
#    tail -n "$MAX_LINES" "$LOG" > "$LOG.tmp" && mv "$LOG.tmp" "$LOG"
     
#    sleep 10
#  done
#) &



#PID=$!
#echo "$PID" > "$PIDFILE"

printf '\nMining started.\n'
printf '===============\n'
#printf 'Log file: %s\n' "$LOG"
printf 'PID: %s\n\n' "$PID"

