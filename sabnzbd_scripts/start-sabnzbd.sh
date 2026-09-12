#!/system/bin/sh
# /data/local/tmp/start-sabnzbd.sh
# No SSD mount — SABnzbd's own download folders live on the chroot's local
# disk (/opt/SABnzbd/downloads), same reasoning as NZBGet in
# torrent-privacy.md: keep incomplete/working data off the exFAT SSD. Sonarr
# does the final move onto /media/ssd once a download is complete.
UBUNTU=/data/data/com.termux/files/home/ubuntu.sh

# Start — non-interactive, safe to call from a loop/orchestrator
sh $UBUNTU /bin/bash -c '
  if [ -e /run/sabnzbd.pid ] && kill -0 $(cat /run/sabnzbd.pid) 2>/dev/null; then
    echo "SABnzbd already running with PID $(cat /run/sabnzbd.pid)"
  else
    echo "Starting SABnzbd..."
    mkdir -p /opt/SABnzbd/data /opt/SABnzbd/downloads/incomplete /opt/SABnzbd/downloads/complete
    nohup /opt/SABnzbd/venv/bin/python3 /opt/SABnzbd/SABnzbd.py \
                   -f /opt/SABnzbd/data/sabnzbd.ini \
                   -s 0.0.0.0:8080 -b 0 --logging 1 \
                   >> /var/log/sabnzbd.log 2>&1 &
    echo $! > /run/sabnzbd.pid
    echo "SABnzbd started with PID $(cat /run/sabnzbd.pid)"
  fi

  echo "Access it at: http://$(hostname -I 2>/dev/null | cut -d\  -f1):8080"
'

# Manual use only: drop into an interactive shell with a cheatsheet.
# Orchestrators (media-services.sh) pass --no-shell to skip this and return
# control instead, so they can start the next service in a list.
if [ "$1" != "--no-shell" ]; then
  echo ""
  echo "First run: the web UI walks you through picking a language and adding"
  echo "a news server — that's where the Usenet.Farm host/port/user/pass goes."
  echo ""
  echo "Useful commands:"
  echo "  - Check status: ps aux | grep SABnzbd"
  echo "  - View logs:    tail -f /var/log/sabnzbd.log"
  echo "  - Stop server:  sh /data/local/tmp/stop-sabnzbd.sh  (or: kill \$(cat /run/sabnzbd.pid))"
  echo ""
  exec sh $UBUNTU
fi
