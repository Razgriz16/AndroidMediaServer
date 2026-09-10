#!/system/bin/sh
# /data/local/tmp/stop-jellyfin.sh
ROOT=/data/data/com.termux/files/usr/var/lib/proot-distro/containers/ubuntu/rootfs
PIDF=$ROOT/run/jellyfin.pid
LOG=/data/local/tmp/ubuntu-boot.log
TAG=stop-jellyfin

log() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') [$TAG] $*" >> "$LOG"
}

# Send everything else (command noise, stray errors) to the log too, not the console
exec >> "$LOG" 2>&1

log "start"

if [ ! -f "$PIDF" ]; then
  log "Jellyfin: no PID file — not running (or already stopped)"
else
  PID=$(cat "$PIDF")
  if ! kill -0 "$PID" 2>/dev/null; then
    log "Jellyfin: PID file present but process $PID is dead — cleaning up"
    rm -f "$PIDF"
  else
    kill "$PID" 2>/dev/null
    i=0
    while kill -0 "$PID" 2>/dev/null && [ $i -lt 15 ]; do
      sleep 1; i=$((i+1))
    done
    if kill -0 "$PID" 2>/dev/null; then
      log "Jellyfin: PID $PID did not exit after 15s — force killing"
      kill -9 "$PID" 2>/dev/null
      sleep 1
    fi
    rm -f "$PIDF"
    log "Jellyfin: stopped"
  fi
fi

if grep -q " $ROOT/media/ssd " /proc/mounts; then
  if umount "$ROOT/media/ssd" 2>/dev/null; then
    log "SSD: unmounted"
  else
    log "SSD: umount FAILED — something still has it open"
    log "SSD: holders: $(fuser -m "$ROOT/media/ssd" 2>/dev/null)"
  fi
else
  log "SSD: was not mounted"
fi