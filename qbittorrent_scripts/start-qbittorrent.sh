#!/system/bin/sh
# /data/local/tmp/start-qbittorrent.sh
. /data/local/tmp/ssd-env.sh
UBUNTU=/data/data/com.termux/files/home/ubuntu.sh

mount_ssd || exit 1

# Start — non-interactive, safe to call from a loop/orchestrator
sh $UBUNTU /bin/bash -c '
  if [ -e /run/qbittorrent.pid ] && kill -0 $(cat /run/qbittorrent.pid) 2>/dev/null; then
    echo "qBittorrent already running with PID $(cat /run/qbittorrent.pid)"
  else
    echo "Starting qBittorrent..."
    mkdir -p /opt/qBittorrent/data
    mkdir -p /media/ssd/downloads/torrents/incomplete /media/ssd/downloads/torrents/seeding
    nohup qbittorrent-nox --profile=/opt/qBittorrent/data \
                   --webui-port=8080 \
                   >> /var/log/qbittorrent.log 2>&1 &
    echo $! > /run/qbittorrent.pid
    echo "qBittorrent started with PID $(cat /run/qbittorrent.pid)"
  fi

  echo "Access it at: http://$(hostname -I 2>/dev/null | cut -d\  -f1):8080"
'

# Manual use only: drop into an interactive shell with a cheatsheet.
if [ "$1" != "--no-shell" ]; then
  echo ""
  echo "Useful commands:"
  echo "  - Check status: ps aux | grep qbittorrent-nox"
  echo "  - View logs:    tail -f /var/log/qbittorrent.log"
  echo "  - Stop server:  sh /data/local/tmp/stop-qbittorrent.sh  (or: kill \$(cat /run/qbittorrent.pid))"
  echo ""
  exec sh $UBUNTU
fi
