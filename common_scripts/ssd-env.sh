#!/system/bin/sh
# /data/local/tmp/ssd-env.sh
#
# Shared SSD config + mount/unmount helpers. Source this, don't execute it:
#   . /data/local/tmp/ssd-env.sh
#
# Every script that touches the SSD bind mount (currently start/stop-jellyfin,
# start/stop-sonarr) pulls its config from here instead of declaring its own
# copy. Swap the SSD (new exFAT label, different mount point, etc.) by editing
# SSD_SRC/SSD_MNT once, here.

ROOT=/data/data/com.termux/files/usr/var/lib/proot-distro/containers/ubuntu/rootfs
SSD_SRC=/mnt/media_rw/FABF-AE53
SSD_MNT=$ROOT/media/ssd

# Idempotent bind-mount. Status goes to stdout (caller decides where that
# ends up); returns non-zero if the source is missing or the mount fails.
mount_ssd() {
  if grep -q " $SSD_MNT " /proc/mounts; then
    echo "SSD already mounted"
    return 0
  fi
  [ -d "$SSD_SRC" ] || { echo "SSD not present at $SSD_SRC"; return 1; }
  mkdir -p "$SSD_MNT"
  mount --bind "$SSD_SRC" "$SSD_MNT" || { echo "SSD bind failed"; return 1; }
  echo "SSD mounted at /media/ssd"
}

# Unmount the SSD, but only once no other live service still needs it.
# Checks every $ROOT/run/*.pid except the caller's own pidfile — so a new SSD
# consumer just works by dropping a pidfile in $ROOT/run, no need to hardcode
# "other" services by name in every stop script.
#
# Usage: unmount_ssd <own-pidfile-basename, e.g. jellyfin.pid>
# Requires a log() function to already be defined by the caller.
unmount_ssd() {
  own=$1
  still_needed=0
  for pidfile in "$ROOT"/run/*.pid; do
    [ -f "$pidfile" ] || continue
    [ "$(basename "$pidfile")" = "$own" ] && continue
    kill -0 "$(cat "$pidfile" 2>/dev/null)" 2>/dev/null && still_needed=1
  done

  if [ "$still_needed" = "1" ]; then
    log "SSD: left mounted — still in use by another service"
  elif grep -q " $SSD_MNT " /proc/mounts; then
    if umount "$SSD_MNT" 2>/dev/null; then
      log "SSD: unmounted"
    else
      log "SSD: umount FAILED — something still has it open"
      log "SSD: holders: $(fuser -m "$SSD_MNT" 2>/dev/null)"
    fi
  else
    log "SSD: was not mounted"
  fi
}
