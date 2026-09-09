#!/system/bin/sh
(
  while true; do
    P=$(getprop sys.shutdown.requested)
    if [ -n "$P" ]; then
      /system/bin/sh /data/local/tmp/ubuntu-down.sh
      exit 0
    fi
    sleep 1
  done
) &