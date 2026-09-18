#!/system/bin/sh
# /data/local/tmp/stop-bazarr.sh
#
# Bazarr doesn't fit the generic stop_service (kill-by-pidfile) helper the
# rest of the stack uses. The PID in bazarr.pid is bazarr.py, a supervisor
# that spawns the actual webserver as a *child* process (bazarr/main.py via
# subprocess.Popen) and only reaps it when it notices a "bazarr.stop" file
# in its config dir (it polls for this every 5s). The supervisor installs no
# SIGTERM handler, so a plain `kill` on that PID just kills the supervisor
# outright via the OS default action, orphaning main.py — which keeps
# holding port 6767. That's why the generic approach never actually stopped
# it.
#
# So: speak Bazarr's own protocol (drop the stop file, wait out its poll
# loop) and only fall back to a hard kill — of both the supervisor and any
# orphaned child found by scanning /proc — if it doesn't respond.

. /data/local/tmp/ssd-env.sh

PIDF=$ROOT/run/bazarr.pid
CONFIG_DIR=$ROOT/opt/bazarr/data
STOP_FILE=$CONFIG_DIR/bazarr.stop
LOG=/data/local/tmp/ubuntu-boot.log
TAG=stop-bazarr

log() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') [$TAG] $*" >> "$LOG"
}

# Send everything else (command noise, stray errors) to the log too, not
# the console.
exec >> "$LOG" 2>&1

log "start"

# Any bazarr/main.py (the child the supervisor spawns) still alive after we
# think the supervisor is down — the normal shutdown path already reaps it,
# this is only a safety net for when we had to force-kill our way through.
reap_orphaned_child() {
  for p in /proc/[0-9]*; do
    pid=${p#/proc/}
    [ -r "$p/cmdline" ] || continue
    if tr '\0' ' ' < "$p/cmdline" 2>/dev/null | grep -q "bazarr/main.py"; then
      log "bazarr: killing orphaned child PID $pid"
      kill -9 "$pid" 2>/dev/null
    fi
  done
}

if [ ! -f "$PIDF" ]; then
  log "bazarr: no PID file — not running (or already stopped)"
  reap_orphaned_child
else
  PID=$(cat "$PIDF")
  if ! kill -0 "$PID" 2>/dev/null; then
    log "bazarr: PID file present but process $PID is dead — cleaning up"
    rm -f "$PIDF"
    reap_orphaned_child
  else
    log "bazarr: dropping stop file for supervisor PID $PID to pick up"
    mkdir -p "$CONFIG_DIR"
    echo 0 > "$STOP_FILE"

    # One 5s poll cycle plus shutdown time; give it 4 cycles' worth before
    # giving up on the graceful path.
    i=0
    while kill -0 "$PID" 2>/dev/null && [ $i -lt 20 ]; do
      sleep 1; i=$((i+1))
    done

    if kill -0 "$PID" 2>/dev/null; then
      log "bazarr: PID $PID still up after 20s — stop file ignored, force killing"
      kill -9 "$PID" 2>/dev/null
      sleep 1
    else
      log "bazarr: supervisor $PID stopped cleanly"
    fi

    rm -f "$STOP_FILE" "$PIDF"
    reap_orphaned_child
    log "bazarr: stopped"
  fi
fi

unmount_ssd bazarr.pid
