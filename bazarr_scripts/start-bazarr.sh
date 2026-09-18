#!/system/bin/sh
# /data/local/tmp/start-bazarr.sh
. /data/local/tmp/ssd-env.sh
UBUNTU=/data/data/com.termux/files/home/ubuntu.sh

# 1. SSD — Bazarr writes subtitles next to media on the SSD, same mount
# shared with Jellyfin/Sonarr; mount is idempotent, safe to call whichever
# service starts first.
mount_ssd || exit 1

# 2. Start — non-interactive, safe to call from a loop/orchestrator
sh $UBUNTU /bin/bash -c '
  if [ -e /run/bazarr.pid ] && kill -0 $(cat /run/bazarr.pid) 2>/dev/null; then
    echo "Bazarr already running with PID $(cat /run/bazarr.pid)"
  else
    echo "Starting Bazarr..."
    mkdir -p /opt/bazarr/data
    nohup python3 /opt/bazarr/bazarr.py --no-update --config=/opt/bazarr/data \
                   >> /var/log/bazarr.log 2>&1 &
    echo $! > /run/bazarr.pid
    echo "Bazarr started with PID $(cat /run/bazarr.pid)"
  fi

  echo "Access it at: http://$(hostname -I 2>/dev/null | cut -d\  -f1):6767"
'

# 3. Manual use only: drop into an interactive shell with a cheatsheet.
# Orchestrators (media-services.sh) pass --no-shell to skip this and return
# control instead, so they can start the next service in a list.
if [ "$1" != "--no-shell" ]; then
  echo ""
  echo "Useful commands:"
  echo "  - Check status: ps aux | grep bazarr.py"
  echo "  - View logs:    tail -f /var/log/bazarr.log"
  echo "  - Stop server:  sh /data/local/tmp/stop-bazarr.sh  (or: kill \$(cat /run/bazarr.pid))"
  echo ""
  exec sh $UBUNTU
fi
