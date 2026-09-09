#!/data/data/com.termux/files/usr/bin/bash
# Must be executed in su shell
# 1. Fix PATH for root shell
export PATH=/data/data/com.termux/files/usr/bin:$PATH

# 2. Login to Ubuntu with all binds, then fix permissions and start Jellyfin
proot-distro login ubuntu \
  --bind /mnt/media_rw/FABF-AE53:/media/ssd \
  -- /bin/bash -c "
    # 3. Fix permissions on mounted drives (safe to run every time)
    chmod -R 777 /media/ssd 2>/dev/null

    # 4.a Set .NET garbage collection limit (7GB)
    # So jellyfin does not throw the error of heap memory
    #export DOTNET_GCHeapHardLimit=1C0000000

    # 4.b .NET memory tuning (optimized for 4GB RAM phone)
    export DOTNET_GC_SERVER=0
    export DOTNET_GC_CONCURRENT=1
    export DOTNET_GCHeapHardLimit=800000000
    export DOTNET_GCHeapHardLimitPercent=50

    # 5. Start Jellyfin
    echo 'Starting Jellyfin server...'

    #jellyfin --webdir=/usr/share/jellyfin/web --ffmpeg=/usr/lib/jellyfin-ffmpeg/ffmpeg --nonetchange

    # Start jellyfin in background and use the shell
    nohup jellyfin --webdir=/usr/share/jellyfin/web --ffmpeg=/usr/lib/jellyfin-ffmpeg/ffmpeg --nonetchange > /var/log/jellyfin.log 2>&1 &

    # Save the PID so we can stop it later
    echo \$! > /var/run/jellyfin.pid
    echo \"Jellyfin started with PID \$(cat /var/run/jellyfin.pid)\"
    echo 'Access it at: http://<your-phone-ip>:8096'
    echo ''
    echo 'Useful commands:'
    echo '  - Check status: ps aux | grep jellyfin'
    echo '  - View logs: tail -f /var/log/jellyfin.log'
    echo '  - Stop server: kill \$(cat /var/run/jellyfin.pid)'
    echo ''

    # Drop to interactive shell so you can manage things
    exec /bin/bash
  "