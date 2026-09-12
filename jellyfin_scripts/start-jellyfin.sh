#!/system/bin/sh
. /data/local/tmp/ssd-env.sh
UBUNTU=/data/data/com.termux/files/home/ubuntu.sh

# 1. SSD
mount_ssd || exit 1

# 2. Start — non-interactive, safe to call from a loop/orchestrator
sh $UBUNTU /bin/bash -c '
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
'

# 3. Manual use only: drop into an interactive shell with a cheatsheet.
# Orchestrators (media-services.sh) pass --no-shell to skip this and return
# control instead, so they can start the next service in a list.
if [ "$1" != "--no-shell" ]; then
  echo ""
  echo "Useful commands:"
  echo "  - Check status: ps aux | grep jellyfin"
  echo "  - View logs:    tail -f /var/log/jellyfin.log"
  echo "  - Stop server:  kill \$(cat /run/jellyfin.pid)"
  echo ""
  exec sh $UBUNTU
fi