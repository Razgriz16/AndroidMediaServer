#!/system/bin/sh
ROOT=/data/data/com.termux/files/usr/var/lib/proot-distro/containers/ubuntu/rootfs
PIDF=$ROOT/run/jellyfin.pid

if [ ! -f "$PIDF" ]; then
  echo "Jellyfin: no PID file — not running (or already stopped)"
else
  PID=$(cat "$PIDF")
  if ! kill -0 "$PID" 2>/dev/null; then
    echo "Jellyfin: PID file present but process $PID is dead — cleaning up"
    rm -f "$PIDF"
  else
    kill "$PID" 2>/dev/null
    i=0
    while kill -0 "$PID" 2>/dev/null && [ $i -lt 15 ]; do
      sleep 1; i=$((i+1))
    done
    if kill -0 "$PID" 2>/dev/null; then
      echo "Jellyfin: PID $PID did not exit after 15s — force killing"
      kill -9 "$PID" 2>/dev/null
      sleep 1
    fi
    rm -f "$PIDF"
    echo "Jellyfin: stopped"
  fi
fi

if grep -q " $ROOT/media/ssd " /proc/mounts; then
  if umount "$ROOT/media/ssd" 2>/dev/null; then
    echo "SSD: unmounted"
  else
    echo "SSD: umount FAILED — something still has it open"
    fuser -m "$ROOT/media/ssd" 2>/dev/null
  fi
else
  echo "SSD: was not mounted"
fi