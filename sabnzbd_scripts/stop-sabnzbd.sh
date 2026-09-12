#!/system/bin/sh
# /data/local/tmp/stop-sabnzbd.sh
# No SSD involved — nothing to unmount, just stop the process.
. /data/local/tmp/stop-service.sh
stop_service sabnzbd
