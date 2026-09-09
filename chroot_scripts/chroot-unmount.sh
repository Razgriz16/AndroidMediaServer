#!/system/bin/sh
ROOT=/data/data/com.termux/files/usr/var/lib/proot-distro/containers/ubuntu/rootfs
LOG=/data/local/tmp/ubuntu-boot.log

# List of "is it running -> how to stop it" pairs.
# Add more services here as needed: pidfile:stopscript
SERVICES="
$ROOT/run/jellyfin.pid:/data/local/tmp/stop-jellyfin.sh
"

for entry in $SERVICES; do
  pidfile="${entry%%:*}"
  stopscript="${entry##*:}"
  if [ -f "$pidfile" ] && kill -0 "$(cat "$pidfile" 2>/dev/null)" 2>/dev/null; then
    echo "Stopping $(basename "$stopscript" .sh)..."
    sh "$stopscript"
  fi
done

for m in media/ssd run dev/pts dev/shm dev sys proc; do
  umount $ROOT/$m 2>/dev/null || umount -l $ROOT/$m 2>/dev/null
done

if grep -q " $ROOT" /proc/mounts; then
  echo "WARNING: mounts remain"
  echo "$(date): teardown left mounts behind" >> $LOG
else
  echo "clean"
  echo "$(date): teardown clean" >> $LOG
fi