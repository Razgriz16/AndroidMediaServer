#!/system/bin/sh
ROOT=/data/data/com.termux/files/usr/var/lib/proot-distro/containers/ubuntu/rootfs
SRC=/mnt/media_rw/FABF-AE53
UBUNTU=/data/data/com.termux/files/home/ubuntu.sh

# 1. SSD
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
  export DOTNET_gcServer=0
  export DOTNET_gcConcurrent=1
  export DOTNET_GCHeapHardLimitPercent=50
  export DOTNET_EnableDiagnostics=0

  if [ -e /run/jellyfin.pid ] && kill -0 $(cat /run/jellyfin.pid) 2>/dev/null; then
    echo "Jellyfin already running with PID $(cat /run/jellyfin.pid)"
  else
    echo "Starting Jellyfin server..."
    nohup jellyfin --webdir=/usr/share/jellyfin/web \
                   --ffmpeg=/usr/lib/jellyfin-ffmpeg/ffmpeg \
                   >> /var/log/jellyfin.log 2>&1 &
    echo $! > /run/jellyfin.pid
    echo -1000 > /proc/$!/oom_score_adj 2>/dev/null
    echo "Jellyfin started with PID $(cat /run/jellyfin.pid)"
  fi

  echo "Access it at: http://$(hostname -I 2>/dev/null | cut -d\  -f1):8096"
  echo ""
  echo "Useful commands:"
  echo "  - Check status: ps aux | grep jellyfin"
  echo "  - View logs:    tail -f /var/log/jellyfin.log"
  echo "  - Stop server:  kill \$(cat /run/jellyfin.pid)"
  echo ""

  exec /bin/bash
'