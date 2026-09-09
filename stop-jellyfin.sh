#!/system/bin/sh
ROOT=/data/data/com.termux/files/usr/var/lib/proot-distro/containers/ubuntu/rootfs

[ -f $ROOT/run/jellyfin.pid ] && {
  kill $(cat $ROOT/run/jellyfin.pid) 2>/dev/null
  i=0
  while kill -0 $(cat $ROOT/run/jellyfin.pid) 2>/dev/null && [ $i -lt 15 ]; do
    sleep 1; i=$((i+1))
  done
  rm -f $ROOT/run/jellyfin.pid
  echo "Jellyfin stopped"
}

umount $ROOT/media/ssd 2>/dev/null && echo "SSD unmounted"