#!/system/bin/sh
# /data/local/tmp/media-services.sh
#
# Thin dispatcher over the individual start-<x>.sh / stop-<x>.sh scripts —
# doesn't duplicate their start/stop logic, just calls the right ones for a
# named group. Every start-<x>.sh accepts --no-shell so this can start
# several in a row without getting stuck in the interactive shell each one
# drops into when run by hand.
#
# Usage:
#   sh media-services.sh jellyfin    # only start Jellyfin
#   sh media-services.sh downloads   # only start the download-stack services
#   sh media-services.sh stop        # stop everything, whatever's running

TMP=/data/local/tmp

JELLYFIN_SERVICES="jellyfin"
# Add qbittorrent here once it has its own start/stop-<name>.sh scripts —
# nothing else in this file needs to change.
DOWNLOAD_SERVICES="prowlarr sabnzbd sonarr"
ALL_SERVICES="$JELLYFIN_SERVICES $DOWNLOAD_SERVICES"

start_group() {
  for name in "$@"; do
    echo "== $name =="
    sh "$TMP/start-$name.sh" --no-shell
    echo ""
  done
}

stop_group() {
  # stop-<name>.sh (via the shared stop_service helper) already no-ops
  # cleanly when a service isn't running, so it's safe to just call all of
  # them regardless of what's actually up.
  for name in "$@"; do
    sh "$TMP/stop-$name.sh"
  done
  echo "Stopped. Details logged to $TMP/ubuntu-boot.log:"
  echo "  tail -20 $TMP/ubuntu-boot.log"
}

case "$1" in
  jellyfin)
    start_group $JELLYFIN_SERVICES
    ;;
  downloads)
    start_group $DOWNLOAD_SERVICES
    ;;
  stop)
    stop_group $ALL_SERVICES
    ;;
  *)
    echo "Usage: $0 {jellyfin|downloads|stop}"
    echo "  jellyfin   start only Jellyfin"
    echo "  downloads  start only: $DOWNLOAD_SERVICES"
    echo "  stop       stop everything ($ALL_SERVICES)"
    exit 1
    ;;
esac
