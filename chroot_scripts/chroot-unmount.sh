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
  if grep -q " $ROOT/$m " /proc/mounts; then
    if umount $ROOT/$m 2>/dev/null; then
      echo "$m: unmounted"
    elif umount -l $ROOT/$m 2>/dev/null; then
      echo "$m: lazy-unmounted"
    else
      echo "$m: FAILED to unmount"
    fi
  fi
done

if grep -q " $ROOT" /proc/mounts; then
  echo "WARNING: mounts remain"
  echo "$(date): teardown left mounts behind" >> $LOG
else
  echo "clean"
  echo "$(date): teardown clean" >> $LOG
fi