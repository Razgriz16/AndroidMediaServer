#!/system/bin/sh
# /data/local/tmp/stop-prowlarr.sh
# No SSD involved — nothing to unmount, just stop the process.
ROOT=/data/data/com.termux/files/usr/var/lib/proot-distro/containers/ubuntu/rootfs
PIDF=$ROOT/run/prowlarr.pid
LOG=/data/local/tmp/ubuntu-boot.log
TAG=stop-prowlarr

log() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') [$TAG] $*" >> "$LOG"
}

exec >> "$LOG" 2>&1

log "start"

if [ ! -f "$PIDF" ]; then
  log "Prowlarr: no PID file — not running (or already stopped)"
else
  PID=$(cat "$PIDF")
  if ! kill -0 "$PID" 2>/dev/null; then
    log "Prowlarr: PID file present but process $PID is dead — cleaning up"
    rm -f "$PIDF"
  else
    kill "$PID" 2>/dev/null
    i=0
    while kill -0 "$PID" 2>/dev/null && [ $i -lt 15 ]; do
      sleep 1; i=$((i+1))
    done
    if kill -0 "$PID" 2>/dev/null; then
      log "Prowlarr: PID $PID did not exit after 15s — force killing"
      kill -9 "$PID" 2>/dev/null
      sleep 1
    fi
    rm -f "$PIDF"
    log "Prowlarr: stopped"
  fi
fi
