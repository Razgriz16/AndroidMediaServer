#!/system/bin/sh
# /data/local/tmp/chroot-unmount.sh
ROOT=/data/data/com.termux/files/usr/var/lib/proot-distro/containers/ubuntu/rootfs
LOG=/data/local/tmp/ubuntu-boot.log
TAG=chroot-unmount

log() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') [$TAG] $*" >> "$LOG"
}

# Send everything else (command noise, stray errors) to the log too, not the console
exec >> "$LOG" 2>&1

log "start"

# List of "is it running -> how to stop it" pairs.
# Add more services here as needed: pidfile:stopscript
SERVICES="
$ROOT/run/jellyfin.pid:/data/local/tmp/stop-jellyfin.sh
$ROOT/run/sonarr.pid:/data/local/tmp/stop-sonarr.sh
$ROOT/run/prowlarr.pid:/data/local/tmp/stop-prowlarr.sh
$ROOT/run/sabnzbd.pid:/data/local/tmp/stop-sabnzbd.sh
"

for entry in $SERVICES; do
  pidfile="${entry%%:*}"
  stopscript="${entry##*:}"
  if [ -f "$pidfile" ] && kill -0 "$(cat "$pidfile" 2>/dev/null)" 2>/dev/null; then
    log "stopping $(basename "$stopscript" .sh)..."
    sh "$stopscript"
  fi
done

for m in media/ssd run dev/pts dev/shm dev sys proc; do
  if grep -q " $ROOT/$m " /proc/mounts; then
    if umount $ROOT/$m 2>/dev/null; then
      log "$m: unmounted"
    elif umount -l $ROOT/$m 2>/dev/null; then
      log "$m: lazy-unmounted"
    else
      log "$m: FAILED to unmount"
    fi
  fi
done

if grep -q " $ROOT" /proc/mounts; then
  log "WARNING: mounts remain"
  log "teardown left mounts behind"
else
  log "clean"
  log "teardown clean"
fi