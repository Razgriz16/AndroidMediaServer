#!/system/bin/sh
# /data/local/tmp/start-sabnzbd.sh
. /data/local/tmp/ssd-env.sh
UBUNTU=/data/data/com.termux/files/home/ubuntu.sh

# 1. SSD — shared with Jellyfin/Sonarr; mount is idempotent, safe to call
# whichever service starts first.
mount_ssd || exit 1

# 2. Start — non-interactive, safe to call from a loop/orchestrator
sh $UBUNTU /bin/bash -c '
  if [ -e /run/sabnzbd.pid ] && kill -0 $(cat /run/sabnzbd.pid) 2>/dev/null; then
    echo "SABnzbd already running with PID $(cat /run/sabnzbd.pid)"
  else
    echo "Starting SABnzbd..."
    mkdir -p /opt/SABnzbd/data
    mkdir -p /media/ssd/downloads/usenet/incomplete /media/ssd/downloads/usenet/complete
    nohup /opt/SABnzbd/venv/bin/python3 /opt/SABnzbd/SABnzbd.py \
                   -f /opt/SABnzbd/data/sabnzbd.ini \
                   -s 0.0.0.0:8080 -b 0 --logging 1 \
                   >> /var/log/sabnzbd.log 2>&1 &
    echo $! > /run/sabnzbd.pid
    echo "SABnzbd started with PID $(cat /run/sabnzbd.pid)"
  fi

  echo "Access it at: http://$(hostname -I 2>/dev/null | cut -d\  -f1):8080"
'

# 3. Manual use only: drop into an interactive shell with a cheatsheet.
# Orchestrators (media-services.sh) pass --no-shell to skip this and return
# control instead, so they can start the next service in a list.
if [ "$1" != "--no-shell" ]; then
  echo ""
  echo "First run: the web UI wizard adds the news server (Usenet.Farm"
  echo "host/port/user/pass). Also set, under Config > Folders:"
  echo "  Temporary Download Folder: /media/ssd/downloads/usenet/incomplete"
  echo "  Completed Download Folder: /media/ssd/downloads/usenet/complete"
  echo "The directories exist already — SABnzbd just needs to be told to use"
  echo "them; this isn't set by the command line."
  echo ""
  echo "Useful commands:"
  echo "  - Check status: ps aux | grep SABnzbd"
  echo "  - View logs:    tail -f /var/log/sabnzbd.log"
  echo "  - Stop server:  sh /data/local/tmp/stop-sabnzbd.sh  (or: kill \$(cat /run/sabnzbd.pid))"
  echo ""
  exec sh $UBUNTU
fi
