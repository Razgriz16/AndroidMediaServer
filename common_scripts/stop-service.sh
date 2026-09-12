#!/system/bin/sh
# /data/local/tmp/stop-service.sh
#
# Shared "kill by pidfile, then log it" logic for every stop-<service>.sh
# script. Source it, don't execute it:
#   . /data/local/tmp/stop-service.sh
#
# Usage: stop_service <name> [--ssd]
#   <name>   service name — used for the pidfile ($ROOT/run/<name>.pid),
#            the log tag (stop-<name>), and log messages.
#   --ssd    the service is an SSD consumer: once it's down, also try to
#            release the SSD via unmount_ssd (refcounted against every
#            other service's pidfile — see ssd-env.sh).
#
# A stop-<service>.sh script is then just:
#   #!/system/bin/sh
#   . /data/local/tmp/stop-service.sh
#   stop_service jellyfin --ssd

. /data/local/tmp/ssd-env.sh

stop_service() {
  name=$1
  want_ssd=0
  [ "$2" = "--ssd" ] && want_ssd=1

  PIDF=$ROOT/run/$name.pid
  LOG=/data/local/tmp/ubuntu-boot.log
  TAG=stop-$name

  log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [$TAG] $*" >> "$LOG"
  }

  # Send everything else (command noise, stray errors) to the log too, not
  # the console.
  exec >> "$LOG" 2>&1

  log "start"

  if [ ! -f "$PIDF" ]; then
    log "$name: no PID file — not running (or already stopped)"
  else
    PID=$(cat "$PIDF")
    if ! kill -0 "$PID" 2>/dev/null; then
      log "$name: PID file present but process $PID is dead — cleaning up"
      rm -f "$PIDF"
    else
      kill "$PID" 2>/dev/null
      i=0
      while kill -0 "$PID" 2>/dev/null && [ $i -lt 15 ]; do
        sleep 1; i=$((i+1))
      done
      if kill -0 "$PID" 2>/dev/null; then
        log "$name: PID $PID did not exit after 15s — force killing"
        kill -9 "$PID" 2>/dev/null
        sleep 1
      fi
      rm -f "$PIDF"
      log "$name: stopped"
    fi
  fi

  if [ "$want_ssd" = "1" ]; then
    unmount_ssd "$name.pid"
  fi
}
