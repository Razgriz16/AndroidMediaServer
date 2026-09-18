#!/system/bin/sh
# deploy.sh — copies this repo's scripts to their real on-device paths.
#
# Run from inside the repo clone, as root:
#   su
#   sh deploy.sh              # copy everything that's new or changed
#   sh deploy.sh --dry-run    # show what would happen, change nothing

TMP=/data/local/tmp
SERVICE_D=/data/adb/service.d
TERMUX_HOME=/data/data/com.termux/files/home

TO_TMP="
common_scripts/ssd-env.sh
common_scripts/stop-service.sh
chroot_scripts/chroot-unmount.sh
jellyfin_scripts/start-jellyfin.sh
jellyfin_scripts/stop-jellyfin.sh
sonarr_scripts/start-sonarr.sh
sonarr_scripts/stop-sonarr.sh
prowlarr_scripts/start-prowlarr.sh
prowlarr_scripts/stop-prowlarr.sh
bazarr_scripts/start-bazarr.sh
bazarr_scripts/stop-bazarr.sh
qbittorrent_scripts/start-qbittorrent.sh
qbittorrent_scripts/stop-qbittorrent.sh
"

# Magisk boot services — must exist here to run at boot at all.
TO_SERVICE_D="
chroot_scripts/chroot-mount.sh
chroot_scripts/chroot-unmount-watch.sh
"

TO_TERMUX_HOME="
ubuntu.sh
common_scripts/media-services.sh
"

REPO_DIR=$(cd "$(dirname "$0")" && pwd)
DRY_RUN=0
[ "$1" = "--dry-run" ] && DRY_RUN=1

# deploy_group <destination-dir> <repo-relative-path>...
deploy_group() {
  destdir=$1
  shift
  for rel in "$@"; do
    src="$REPO_DIR/$rel"
    dst="$destdir/$(basename "$rel")"

    if [ ! -f "$src" ]; then
      echo "SKIP (missing in repo): $src"
      continue
    fi

    if [ -f "$dst" ] && cmp -s "$src" "$dst"; then
      echo "unchanged: $dst"
      continue
    fi

    if [ "$DRY_RUN" = "1" ]; then
      if [ -f "$dst" ]; then
        echo "would UPDATE (differs): $dst"
      else
        echo "would create: $dst"
      fi
    else
      mkdir -p "$destdir"
      # chmod explicitly rather than relying on cp + umask to carry over the
      # executable bit from the repo
      cp "$src" "$dst" && chmod 755 "$dst" && echo "deployed: $dst"
    fi
  done
}

deploy_group "$TMP" $TO_TMP
deploy_group "$SERVICE_D" $TO_SERVICE_D
deploy_group "$TERMUX_HOME" $TO_TERMUX_HOME

[ "$DRY_RUN" = "1" ] && echo "(dry run — nothing changed)"
