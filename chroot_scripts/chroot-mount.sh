#!/system/bin/sh
# /data/adb/service.d/chroot-mount.sh
export PATH=/data/data/com.termux/files/usr/bin:/system/bin:/system/xbin:$PATH
ROOT=/data/data/com.termux/files/usr/var/lib/proot-distro/containers/ubuntu/rootfs
LOG=/data/local/tmp/ubuntu-boot.log
TAG=chroot-mount

log() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') [$TAG] $*" >> "$LOG"
}

# Send everything else (command noise, stray errors) to the log too, not the console
exec >> "$LOG" 2>&1

log "start"

for i in $(seq 1 60); do
  [ -d "$ROOT/etc" ] && break
  sleep 2
done

[ -d "$ROOT/etc" ] || { log "rootfs not found at $ROOT"; exit 1; }

mount | grep ' /data ' | grep -q nosuid && mount -o remount,dev,suid /data

mnt() {
  target="$1"; shift
  grep -q " $target " /proc/mounts && return 0
  mount "$@" || log "FAILED: $*"
}

mnt $ROOT/proc    -t proc   proc   $ROOT/proc
mnt $ROOT/sys     -t sysfs  sysfs  $ROOT/sys
mnt $ROOT/dev     --bind    /dev   $ROOT/dev
mkdir -p $ROOT/dev/shm $ROOT/dev/pts
mnt $ROOT/dev/pts -t devpts devpts $ROOT/dev/pts
mnt $ROOT/dev/shm -t tmpfs -o size=128M tmpfs $ROOT/dev/shm
mnt $ROOT/run     -t tmpfs -o size=64M  tmpfs $ROOT/run

rm -f $ROOT/etc/resolv.conf
printf 'nameserver 1.1.1.1\nnameserver 8.8.8.8\n' > $ROOT/etc/resolv.conf

log "env mounted"
log "mounts active: $(grep -c " $ROOT" /proc/mounts)"
