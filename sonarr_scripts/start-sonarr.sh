#!/system/bin/sh
# /data/local/tmp/start-sonarr.sh
ROOT=/data/data/com.termux/files/usr/var/lib/proot-distro/containers/ubuntu/rootfs
SRC=/mnt/media_rw/FABF-AE53
UBUNTU=/data/data/com.termux/files/home/ubuntu.sh

# 1. SSD — shared with Jellyfin; mount is idempotent (mnt-style check), safe
# to call whichever service starts first.
if grep -q " $ROOT/media/ssd " /proc/mounts; then
  echo "SSD already mounted"
else
  [ -d "$SRC" ] || { echo "SSD not present at $SRC"; exit 1; }
  mkdir -p $ROOT/media/ssd
  mount --bind $SRC $ROOT/media/ssd || { echo "SSD bind failed"; exit 1; }
  echo "SSD mounted at /media/ssd"
fi

# 2. Enter and start
exec sh $UBUNTU /bin/bash -c '
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
  echo ""
  echo "Useful commands:"
  echo "  - Check status: ps aux | grep Sonarr"
  echo "  - View logs:    tail -f /var/log/sonarr.log"
  echo "  - Stop server:  kill \$(cat /run/sonarr.pid)"
  echo ""

  exec /bin/bash
'
