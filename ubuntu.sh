#!/system/bin/sh
# /data/data/com.termux/files/home/ubuntu.sh
ROOT=/data/data/com.termux/files/usr/var/lib/proot-distro/containers/ubuntu/rootfs

grep -q " $ROOT/proc " /proc/mounts || {
  echo "Base mounts missing — run chroot-mount.sh first"; exit 1; }

# No args → interactive login shell. Args → run them inside.
[ $# -eq 0 ] && set -- /bin/bash --login

exec chroot $ROOT /usr/bin/env -i \
  HOME=/root \
  TERM="${TERM:-xterm-256color}" \
  PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
  "$@"

  