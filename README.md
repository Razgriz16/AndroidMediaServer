Android media server

Guía principal media server: 
https://github.com/Boss17536/android-media-server
https://gist.github.com/Valienteuh/2ad0fe58c3c9ecad50425b19478ab61d

# inicializar servidor ssh
sshd
# agregar contraseña ssh
passwd

proot-distro login ubuntu
termux-wake-lock

start jellyfin:
ps aux | grep jellyfin (revisa servicio de jellyfin)

(en caso de error de memoria de heap: https://github.com/termux/proot/issues/283)
export DOTNET_GCHeapHardLimit=1C0000000

jellyfin --webdir=/usr/share/jellyfin/web --ffmpeg=/usr/lib/jellyfin-ffmpeg/ffmpeg  
(& hace que se ejecute en el background)
nohup jellyfin --webdir=/usr/share/jellyfin/web --ffmpeg=/usr/lib/jellyfin-ffmpeg/ffmpeg &
(hace que se ejecute en 2do plano y deje la terminal libre para ser usada)

kill jellyfin:
pkill -9 -f jellyfin
pkill -9 -f ffmpeg

setup storage:
# 1. Ensure Termux has permission to see the new format
termux-setup-storage

# 2. Look up your SD card's exact name
ls -l ~/storage

/data/data/com.termux/files/home/storage/external-1/media/tv


scp -p 8022 -r "C:\Users\pdavi\Videos\[LostYears] KonoSuba - God's Blessing on this Wonderful World! - Season 03 (WEB-DL 1080p x264 AAC E-AC-3) [Dual-Audio] [Multi-Sub]\"  u0_a201@192.168.1.180:/storage/3F69-12EE/Android/data/com.termux/files/media/tv 


1. install prowlarr, sonarr qbittorrent
2. improve firewall security, add known blacklists to the firewall
3. install jellyseer ant integrate it with the previous setup


time syscalls:
proot-distro:
Time taken: 8.0280 seconds
Time taken: 8.2098 seconds
Time taken: 8.0388 seconds