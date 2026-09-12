#!/system/bin/sh
# /data/local/tmp/start-prowlarr.sh
# No SSD mount — Prowlarr only manages indexer configs/API keys in its own
# app-data dir, it never reads or writes media.
UBUNTU=/data/data/com.termux/files/home/ubuntu.sh

# Start — non-interactive, safe to call from a loop/orchestrator
sh $UBUNTU /bin/bash -c '
  if [ -e /run/prowlarr.pid ] && kill -0 $(cat /run/prowlarr.pid) 2>/dev/null; then
    echo "Prowlarr already running with PID $(cat /run/prowlarr.pid)"
  else
    echo "Starting Prowlarr..."
    mkdir -p /opt/Prowlarr/data
    nohup /opt/Prowlarr/Prowlarr -nobrowser -data=/opt/Prowlarr/data \
                   >> /var/log/prowlarr.log 2>&1 &
    echo $! > /run/prowlarr.pid
    echo "Prowlarr started with PID $(cat /run/prowlarr.pid)"
  fi

  echo "Access it at: http://$(hostname -I 2>/dev/null | cut -d\  -f1):9696"
'

# Manual use only: drop into an interactive shell with a cheatsheet.
# Orchestrators (media-services.sh) pass --no-shell to skip this and return
# control instead, so they can start the next service in a list.
if [ "$1" != "--no-shell" ]; then
  echo ""
  echo "Useful commands:"
  echo "  - Check status: ps aux | grep Prowlarr"
  echo "  - View logs:    tail -f /var/log/prowlarr.log"
  echo "  - Stop server:  sh /data/local/tmp/stop-prowlarr.sh  (or: kill \$(cat /run/prowlarr.pid))"
  echo ""
  exec sh $UBUNTU
fi
