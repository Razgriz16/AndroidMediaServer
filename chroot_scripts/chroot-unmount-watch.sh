#!/system/bin/sh
# /data/adb/service.d/chroot-unmount-watch.sh
(
  while true; do
    P=$(getprop sys.shutdown.requested)
    if [ -n "$P" ]; then
      /system/bin/sh /data/local/tmp/chroot-unmount.sh
      exit 0
    fi
    sleep 1
  done
) &