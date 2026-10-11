#!/system/bin/sh
# /data/data/com.termux/files/home/termux-autostart.sh
#
# Sourced from ~/.bashrc (hook added by deploy.sh) so every new Termux
# session starts all media services automatically. Safe to run repeatedly —
# media-services.sh / the individual start-<x>.sh scripts and the SSD bind
# mount are all idempotent (PID-file / /proc/mounts checks), so re-running
# this on a second terminal tab just no-ops.

su -c "sh $HOME/media-services.sh restart all"
