#!/system/bin/sh
# /data/local/tmp/start-sonarr.sh
. /data/local/tmp/ssd-env.sh
UBUNTU=/data/data/com.termux/files/home/ubuntu.sh

# 1. SSD — shared with Jellyfin; mount is idempotent, safe to call whichever
# service starts first.
mount_ssd || exit 1

# 2. Start — non-interactive, safe to call from a loop/orchestrator
sh $UBUNTU /bin/bash -c '
  if [ -e /run/sonarr.pid ] && kill -0 $(cat /run/sonarr.pid) 2>/dev/null; then
    echo "Sonarr already running with PID $(cat /run/sonarr.pid)"
  else
    echo "Starting Sonarr..."
    mkdir -p /opt/Sonarr/data
    nohup /opt/Sonarr/Sonarr -nobrowser -data=/opt/Sonarr/data \
                   >> /var/log/sonarr.log 2>&1 &
    echo $! > /run/sonarr.pid
    echo "Sonarr started with PID $(cat /run/sonarr.pid)"
  fi

  echo "Access it at: http://$(hostname -I 2>/dev/null | cut -d\  -f1):8989"
'

# 3. Manual use only: drop into an interactive shell with a cheatsheet.
# Orchestrators (media-services.sh) pass --no-shell to skip this and return
# control instead, so they can start the next service in a list.
if [ "$1" != "--no-shell" ]; then
  echo ""
  echo "Useful commands:"
  echo "  - Check status: ps aux | grep Sonarr"
  echo "  - View logs:    tail -f /var/log/sonarr.log"
  echo "  - Stop server:  kill \$(cat /run/sonarr.pid)"
  echo ""
  exec sh $UBUNTU
fi
