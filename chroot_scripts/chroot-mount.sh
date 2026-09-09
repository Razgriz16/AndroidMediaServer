#!/system/bin/sh
export PATH=/data/data/com.termux/files/usr/bin:/system/bin:/system/xbin:$PATH
ROOT=/data/data/com.termux/files/usr/var/lib/proot-distro/containers/ubuntu/rootfs
LOG=/data/local/tmp/ubuntu-boot.log

[ -d "$ROOT/etc" ] || { echo "rootfs not found at $ROOT"; exit 1; }

mount | grep ' /data ' | grep -q nosuid && mount -o remount,dev,suid /data

mnt() {
  target="$1"; shift
  grep -q " $target " /proc/mounts && return 0
  mount "$@" || echo "FAILED: $*" >&2
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

echo "$(date): env mounted" >> $LOG
grep -c " $ROOT" /proc/mounts | xargs echo "mounts active:"
