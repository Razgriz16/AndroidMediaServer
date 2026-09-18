#!/system/bin/sh
# /data/local/tmp/media-services.sh
#
# Thin dispatcher over the individual start-<x>.sh / stop-<x>.sh scripts —
# doesn't duplicate their start/stop logic, just calls the right ones for a
# named service or group. Every start-<x>.sh accepts --no-shell so this can
# start several in a row without getting stuck in the interactive shell each
# one drops into when run by hand.
#
# Usage:
#   sh media-services.sh start all            # start every known service
#   sh media-services.sh start jellyfin       # start one group
#   sh media-services.sh start sonarr qbittorrent   # start specific services
#   sh media-services.sh stop all             # stop everything, whatever's running
#   sh media-services.sh stop jellyfin
#   sh media-services.sh restart downloads    # stop then start a group
#
# Adding a new service:
#   1. Add its name to ALL_SERVICES.
#   2. Add it to an existing GROUP_* list, or define a new GROUP_<name> and
#      register the name in resolve_target()'s case statement.

TMP=/data/local/tmp

# --- Service registry ---------------------------------------------------
# Every service the dispatcher knows about. Add new services here.
ALL_SERVICES="jellyfin prowlarr qbittorrent sonarr"

# --- Groups ---------------------------------------------------------------
GROUP_JELLYFIN="jellyfin"
GROUP_DOWNLOADS="prowlarr qbittorrent sonarr"

# Resolve a single token ("all", a group name, or a lone service name) to
# a space-separated list of service names. Prints nothing and returns
# non-zero if the token is unrecognized.
resolve_target() {
  case "$1" in
    all)       echo "$ALL_SERVICES" ;;
    jellyfin)  echo "$GROUP_JELLYFIN" ;;
    downloads) echo "$GROUP_DOWNLOADS" ;;
    *)
      for svc in $ALL_SERVICES; do
        if [ "$svc" = "$1" ]; then
          echo "$svc"
          return 0
        fi
      done
      return 1
      ;;
  esac
}

# Expand a list of tokens (any mix of "all"/groups/service names) into a
# deduped, first-seen-order list of service names.
expand_targets() {
  result=""
  for tok in "$@"; do
    names=$(resolve_target "$tok") || { echo "Unknown service or group: $tok" >&2; return 1; }
    for name in $names; do
      case " $result " in
        *" $name "*) ;;  # already included
        *) result="$result $name" ;;
      esac
    done
  done
  echo "$result"
}

start_group() {
  for name in "$@"; do
    echo "== $name =="
    sh "$TMP/start-$name.sh" --no-shell
    echo "  log: /var/log/$name.log (inside chroot — tail -f it from ubuntu.sh)"
    echo ""
  done
}

stop_group() {
  # stop-<name>.sh (via the shared stop_service helper) already no-ops
  # cleanly when a service isn't running, so it's safe to call it
  # regardless of what's actually up.
  for name in "$@"; do
    sh "$TMP/stop-$name.sh"
  done
  echo "Stopped. Details logged to $TMP/ubuntu-boot.log:"
  echo "  tail -20 $TMP/ubuntu-boot.log"
}

usage() {
  echo "Usage: $0 {start|stop|restart} {all|jellyfin|downloads|<service> [<service> ...]}"
  echo ""
  echo "  Groups:"
  echo "    all          $ALL_SERVICES"
  echo "    jellyfin     $GROUP_JELLYFIN"
  echo "    downloads    $GROUP_DOWNLOADS"
  echo ""
  echo "  Individual services: $ALL_SERVICES"
  echo ""
  echo "Examples:"
  echo "  $0 start all"
  echo "  $0 start downloads"
  echo "  $0 start sonarr qbittorrent"
  echo "  $0 stop jellyfin"
  echo "  $0 restart all"
  exit 1
}

[ $# -ge 2 ] || usage

action="$1"
shift

targets=$(expand_targets "$@") || exit 1
[ -n "$targets" ] || usage

case "$action" in
  start)   start_group $targets ;;
  stop)    stop_group $targets ;;
  restart) stop_group $targets; start_group $targets ;;
  *)       usage ;;
esac
