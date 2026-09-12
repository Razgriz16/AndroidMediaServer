# Android Media Server — Poco X3 NFC

Personal notes for running Jellyfin on a rooted Poco X3 NFC (LineageOS), inside
an Ubuntu rootfs entered via a **real `chroot`** instead of `proot-distro login`.
This file is the "how did I set this up again" reference: paths, commands, the
scripts, and every failure hit along the way with its fix.

Original guides this was built from:
- https://github.com/Boss17536/android-media-server
- https://gist.github.com/Valienteuh/2ad0fe58c3c9ecad50425b19478ab61d

Device issues unrelated to the media server itself (root, Magisk modules, ROM
quirks) live in [`issues.md`](issues.md). The component/storage diagrams live
in [`architecture.md`](architecture.md).

---

## The setup at a glance

| Thing | Value |
|---|---|
| Device | Poco X3 NFC, rooted (Magisk), LineageOS |
| Container | Ubuntu rootfs originally installed with `proot-distro`, now entered with `chroot` |
| App | Jellyfin (+ jellyfin-ffmpeg), transcoding disabled |
| Media | External SSD, **exFAT**, plugged via USB-OTG |
| Why chroot | `proot` rewrites every path-bearing syscall via `ptrace` (~160 µs/call). `chroot` is one kernel call, zero ongoing cost. Expect ~2–5× on library scans / apt / startup; streaming throughput barely changes. |

**Never run `proot-distro login ubuntu` while the chroot mounts are live.** Two
mount views of the same SQLite DBs is the one genuinely destructive failure mode
here. Same rootfs directory, pick one entry mechanism at a time.

---

## Key paths

| What | Path |
|---|---|
| Rootfs (`$ROOT`) | `/data/data/com.termux/files/usr/var/lib/proot-distro/containers/ubuntu/rootfs` |
| Boot / teardown log | `/data/local/tmp/ubuntu-boot.log` |
| Jellyfin app log | `/var/log/jellyfin.log` inside the chroot (`$ROOT/var/log/jellyfin.log` from the host) |
| Jellyfin PID file | `/run/jellyfin.pid` inside (tmpfs — cleared every boot, so no stale PID) |
| SSD source (host) | `/mnt/media_rw/FABF-AE53` — defined once in `common_scripts/ssd-env.sh` (`/data/local/tmp/ssd-env.sh` on device), sourced by every script that binds it |
| SSD inside container | `/media/ssd` — bind mount, must be **exactly** `$ROOT/media/ssd` |
| Jellyfin web UI | `http://<phone-ip>:8096` |
| SSH | port `8022`, Termux user `u0_a193` (e.g. `192.168.1.198`) |

> The rootfs path shows up in `mount` output under three aliases at once
> (`/data/data/...`, `/data/user/0/...`, `/data_mirror/data_ce/null/0/...`) —
> Android's own bind-mounts for the same storage, not duplicates. Unmounting one
> clears all three.
>
> It is **NOT** `.../installed-rootfs/ubuntu` — that was an older proot-distro
> layout, wrong for this install.

---

## Repo layout → on-device paths

The repo folders are just for version control. On the phone the scripts live
elsewhere; deploy by copying them to the paths below.

| Repo file | Deployed to | Runs as / when |
|---|---|---|
| `common_scripts/ssd-env.sh` | `/data/local/tmp/ssd-env.sh` | sourced (`. /data/local/tmp/ssd-env.sh`), never run directly — shared SSD path + mount/unmount helpers for every script below that touches the SSD |
| `common_scripts/stop-service.sh` | `/data/local/tmp/stop-service.sh` | sourced, never run directly — shared `stop_service <name> [--ssd]` used by every `stop-*.sh` below (kill-by-pidfile w/ 15s grace + force-kill, logging, optional SSD release) |
| `common_scripts/media-services.sh` | `/data/local/tmp/media-services.sh` | root shell, manual — dispatcher: `jellyfin` / `downloads` / `stop` |
| `chroot_scripts/chroot-mount.sh` | `/data/adb/service.d/chroot-mount.sh` | root, at boot (Magisk `service.d`) |
| `chroot_scripts/chroot-unmount.sh` | `/data/local/tmp/chroot-unmount.sh` | root, manually or from the shutdown watcher |
| `chroot_scripts/chroot-unmount-watch.sh` | `/data/adb/service.d/chroot-unmount-watch.sh` | root, at boot — polls for shutdown, then calls the unmount script |
| `jellyfin_scripts/start-jellyfin.sh` | `/data/local/tmp/start-jellyfin.sh` | root shell, manual |
| `jellyfin_scripts/stop-jellyfin.sh` | `/data/local/tmp/stop-jellyfin.sh` | root shell, manual or from `chroot-unmount.sh` |
| `sonarr_scripts/start-sonarr.sh` | `/data/local/tmp/start-sonarr.sh` | root shell, manual |
| `sonarr_scripts/stop-sonarr.sh` | `/data/local/tmp/stop-sonarr.sh` | root shell, manual or from `chroot-unmount.sh` |
| `prowlarr_scripts/start-prowlarr.sh` | `/data/local/tmp/start-prowlarr.sh` | root shell, manual |
| `prowlarr_scripts/stop-prowlarr.sh` | `/data/local/tmp/stop-prowlarr.sh` | root shell, manual or from `chroot-unmount.sh` |
| `ubuntu.sh` | `/data/data/com.termux/files/home/ubuntu.sh` | root shell — entry point into the container |

`.env` and `poco-x3-chroot-setup.md` are gitignored (local secrets / long-form
migration notes).

---

## Deploying updates

The phone has its own clone; `deploy.sh` copies each file to its path above.

```sh
cd ~/AndroidMediaServer && git pull
su
sh deploy.sh --dry-run   # optional: preview what's new/changed
sh deploy.sh
```

`chroot-mount.sh`/`chroot-unmount-watch.sh` (Magisk `service.d`) only take
effect next boot; everything else immediately.

---

## Everyday commands

### SSH into the phone (from Termux, first time)
```sh
sshd            # start the ssh daemon
passwd          # set a password for ssh login
```
Then from the PC: `ssh -p 8022 u0_a201@192.168.1.198`

### Enter the Ubuntu container
```sh
su
sh /data/data/com.termux/files/home/ubuntu.sh          # interactive login shell
sh /data/data/com.termux/files/home/ubuntu.sh /bin/bash -c 'apt update'   # run one command
```
`ubuntu.sh` refuses to run if the base mounts are missing — run the mount script
first (see below). Always invoke as `sh script.sh`, never `./script.sh`
(`/data` may be mounted `noexec`).

### Mount / unmount the chroot environment manually
```sh
su
sh /data/adb/service.d/chroot-mount.sh     # proc, sys, dev, devpts, shm, run + DNS
sh /data/local/tmp/chroot-unmount.sh       # stops Jellyfin if running, then tears mounts down
```
The mount script waits up to 120 s (`seq 1 60`, 2 s each) for the rootfs to
become readable — it lives under credential-encrypted storage and isn't visible
until the **first unlock after boot**. The wait loop breaks on the first poll
after you unlock; if you're already unlocked it returns immediately.

### Jellyfin: start / stop / status
```sh
su
sh /data/local/tmp/start-jellyfin.sh       # binds SSD if needed, enters chroot, starts Jellyfin
sh /data/local/tmp/stop-jellyfin.sh        # kills Jellyfin (TERM, then KILL after 15 s), unmounts SSD
```
Jellyfin is intentionally **manual** — the phone gets used for other things, so
it isn't left running.

From inside the container:
```sh
ps aux | grep jellyfin           # is it running
tail -f /var/log/jellyfin.log    # live app log
kill $(cat /run/jellyfin.pid)    # stop it
```

### Sonarr / Prowlarr: start / stop / status
```sh
su
sh /data/local/tmp/start-sonarr.sh     # binds SSD if needed (shared with Jellyfin), enters chroot, starts Sonarr
sh /data/local/tmp/stop-sonarr.sh      # kills Sonarr, unmounts SSD only if Jellyfin isn't also using it

sh /data/local/tmp/start-prowlarr.sh   # no SSD involved — Prowlarr only holds indexer configs
sh /data/local/tmp/stop-prowlarr.sh
```
Sonarr's root/library folder and import target live on the SSD, same as
Jellyfin — the two now **share** that mount. Prowlarr never touches media, so
its scripts skip the SSD step entirely.

### Start/stop by group: `media-services.sh`
```sh
su
sh /data/local/tmp/media-services.sh jellyfin    # only Jellyfin
sh /data/local/tmp/media-services.sh downloads   # only Prowlarr + Sonarr
sh /data/local/tmp/media-services.sh stop        # stop whatever's running, all of it
```
A thin dispatcher, not a reimplementation — it just calls the `start-<x>.sh` /
`stop-<x>.sh` scripts above for whichever group you name. Every `start-<x>.sh`
now takes an optional `--no-shell` flag (used only by this dispatcher) that
skips the interactive drop-in shell and returns instead, so starting several
services in a row doesn't get stuck inside the first one's shell. Run a
`start-<x>.sh` by hand with no flag and it behaves exactly as before —
cheatsheet, then drops you into the container.

Raw start line (what the script runs), for reference:
```sh
nohup jellyfin --webdir=/usr/share/jellyfin/web \
               --ffmpeg=/usr/lib/jellyfin-ffmpeg/ffmpeg \
               >> /var/log/jellyfin.log 2>&1 &
```

### Logs
```sh
tail -f /data/local/tmp/ubuntu-boot.log        # mount / unmount / stop-* (all of them log here)
grep -i jellyfin /data/local/tmp/ubuntu-boot.log
```
`chroot-mount`, `chroot-unmount`, and every `stop-*.sh` (via the shared
`stop_service` in `common_scripts/stop-service.sh`) send **every** line —
their own messages plus stray command output — to `ubuntu-boot.log` via a
`log()` helper + `exec >> "$LOG" 2>&1`. Nothing prints to the console. One
file so a graceful shutdown reads as a single timeline. Jellyfin's own
application log is separate: `/var/log/jellyfin.log` inside.


Line format is `YYYY-MM-DD HH:MM:SS [tag] message`, where `tag` is the script the
line came from (`chroot-mount`, `chroot-unmount`, `stop-jellyfin`, `stop-sonarr`,
`stop-prowlarr`) — so a failure is traceable to its source and `grep '\[tag\]'`
isolates one script:
```
2026-09-09 14:03:11 [chroot-mount] start
2026-09-09 14:03:11 [chroot-mount] env mounted
2026-09-09 22:47:02 [chroot-unmount] start
2026-09-09 22:47:02 [chroot-unmount] stopping stop-jellyfin...
2026-09-09 22:47:04 [stop-jellyfin] Jellyfin: stopped
2026-09-09 22:47:04 [stop-jellyfin] SSD: unmounted
2026-09-09 22:47:04 [chroot-unmount] clean
```

### Inspect mounts
```sh
ROOT=/data/data/com.termux/files/usr/var/lib/proot-distro/containers/ubuntu/rootfs
grep " $ROOT" /proc/mounts               # everything mounted into the rootfs
grep -c " $ROOT" /proc/mounts            # how many
mount | grep ' /data ' | grep nosuid     # is /data still nosuid/nodev
```

### Copy media from the PC
```sh
# scp port flag is capital -P (lowercase -p means "preserve timestamps")
scp -P 8022 -r "C:\Users\pdavi\Videos\Some.Show.S03" \
    u0_a201@192.168.1.198:/mnt/media_rw/FABF-AE53/media/tv
```

---

## Boot & shutdown automation

- **Boot** — `chroot-mount.sh` in `/data/adb/service.d/` mounts the base env
  automatically. Safe to fully automate: nothing at this layer has persistent
  state, a hard crash loses nothing.
- **Shutdown** — Android/Magisk has **no real shutdown hook**.
  `chroot-unmount-watch.sh` polls `getprop sys.shutdown.requested` once a second
  and runs the unmount script when it fires. This only covers **graceful**
  power-off / reboot. Battery death, kernel panic, and hard power-button resets
  are not covered — nothing can cover them, power is gone before any script runs.
- **SSD + Jellyfin** — deliberately manual.

---

## What each script does

- **`chroot-mount.sh`** — waits for the rootfs to unlock, remounts `/data` with
  `dev,suid` if it came up `nosuid`, then mounts `proc`, `sys`, bind-`dev`,
  `devpts`, `dev/shm` (tmpfs), `run` (tmpfs) into the rootfs, and writes a
  `resolv.conf` (1.1.1.1 / 8.8.8.8). `mnt()` skips anything already mounted
  (checked against `/proc/mounts`).
- **`chroot-unmount.sh`** — walks a `SERVICES` list of `pidfile:stopscript`
  pairs; if a service's PID is alive it runs its stop script. Then unmounts
  `media/ssd → run → dev/pts → dev/shm → dev → sys → proc` (children first),
  trying `umount`, then `umount -l` (lazy), logging which. Warns if anything
  remains.
- **`chroot-unmount-watch.sh`** — the shutdown poller described above.
- **`ubuntu.sh`** — the entry point that replaces `proot-distro login`. Checks
  base mounts exist, then `exec chroot $ROOT /usr/bin/env -i` with a clean
  `HOME`/`TERM`/`PATH`. No args → `/bin/bash --login`; with args → runs them
  inside and exits. Entering via `env -i` with an explicit `PATH` sidesteps the
  empty-PATH problem (see failures).
- **`start-jellyfin.sh`** — binds the SSD (`/mnt/media_rw/FABF-AE53` →
  `$ROOT/media/ssd`) if not already mounted, then `exec`s `ubuntu.sh` with an
  inline command that sets the DOTNET env vars, starts Jellyfin with `nohup`,
  writes the PID to `/run/jellyfin.pid`, sets `oom_score_adj` to `-1000`, prints
  the access URL + a cheatsheet, and drops into an interactive bash.
- **`stop-jellyfin.sh`** — `TERM` the PID, wait 15 s, `KILL -9` if still alive,
  remove the PID file, then unmount the SSD **only if Sonarr's PID file also
  shows nothing alive** (with `fuser -m` logged if the unmount fails). Safe to
  run when nothing's running — every branch reports.
- **`start-sonarr.sh` / `stop-sonarr.sh`** — same shape as the Jellyfin pair:
  bind the SSD if not already mounted, `exec` into `ubuntu.sh`, start
  `/opt/Sonarr/Sonarr -nobrowser -data=/opt/Sonarr/data`, PID to
  `/run/sonarr.pid`. Stop mirrors Jellyfin's TERM→wait→KILL, and — since the
  SSD is now a **shared** mount — only unmounts it if `jellyfin.pid` also
  shows nothing alive. Whichever of the two stops last is the one that
  actually unmounts.
- **`start-prowlarr.sh` / `stop-prowlarr.sh`** — no SSD step at all. Prowlarr's
  data (indexer configs, API keys) lives entirely under `/opt/Prowlarr/data`;
  it never reads or writes media, so there's nothing to bind and nothing to
  race with the other two services over.
- **`media-services.sh`** — dispatcher over the three pairs above. `jellyfin`
  and `downloads` (currently `prowlarr sonarr`) each call `start-<x>.sh
  --no-shell` for their group in sequence; `stop` calls every `stop-<x>.sh`
  unconditionally (safe — `stop_service` no-ops cleanly when a service isn't
  running). Adding NZBGet/qBittorrent later is a one-line edit to
  `DOWNLOAD_SERVICES`, once their own `start`/`stop` scripts exist.

---

## One-time setup inside the chroot (must survive)

Run these **once**, inside the container, or things silently break. `proot`'s
uid/gid emulation faked all of this, so none of it surfaced before.

```sh
# apt: Android "paranoid networking" denies the _apt user network access.
# Add the magic Android net groups and put root + _apt in them.
groupadd -g 3003 inet
groupadd -g 3004 inet_raw
for g in inet inet_raw; do gpasswd -a root $g; gpasswd -a _apt $g; done
# then exit and re-enter the chroot for group membership to take effect

# dpkg tries to start daemons via a systemd that isn't there — stub it out
printf '#!/bin/sh\nexit 101\n' > /usr/sbin/policy-rc.d
chmod +x /usr/sbin/policy-rc.d

# silences the "run-parts: command not found" warning on bash -l
apt install debianutils
```

Status: net groups **done and confirmed** (`apt update` works). `policy-rc.d`
and `debianutils` — recommended, not yet confirmed done.

---

## .NET / Jellyfin environment variables

The original tuning was **inert** — wrong casing, and a hex-parsed limit:

- `DOTNET_GC_SERVER` / `DOTNET_GC_CONCURRENT` — real names are
  `DOTNET_gcServer` / `DOTNET_gcConcurrent` (lowercase letter after the prefix).
- `DOTNET_GCHeapHardLimit=800000000` — parsed as **hex**, so it set a ~32 GB
  limit, not 800 MB. Setting it also silently disables `GCHeapHardLimitPercent`.
- `export DOTNET_GCHeapHardLimit=1C0000000` was the old proot heap-crash
  workaround (termux/proot#283). Not needed under chroot with a real `/proc`.

Current set (in `start-jellyfin.sh`):
```sh
export DOTNET_gcServer=0
export DOTNET_gcConcurrent=1
export DOTNET_GCHeapHardLimitPercent=50
export DOTNET_EnableDiagnostics=0
```

`--nonetchange` was dropped from the launch line — it worked around netlink
issues under proot and should be unnecessary now. Re-add it if the startup log
shows network-change errors.

---

## Failures hit during the build (and the fix)

| # | Symptom | Cause / fix |
|---|---|---|
| 1 | Boot logged "rootfs unreadable, aborting", worked on manual re-run | `service.d` fires before credential-encrypted storage unlocks (first PIN entry). Fix: retry-loop the rootfs check (`seq 1 60`, sleep 2). |
| 2 | Paths like `$ROOT/etc/proc` | `ROOT` must be the rootfs **root**, no `/etc` appended. |
| 3 | `dev/shm` missing after mount | Binding Android's `/dev` over the rootfs `/dev` wipes its `shm` dir. `mkdir -p $ROOT/dev/shm` must come **after** the bind. |
| 4 | `mountpoint: not found` / bind mounts to wrong target | `mountpoint` binary isn't on the root shell PATH → check `grep " $target " /proc/mounts` instead. For `--bind`, a naive `$2` is the *source*, not the target → `mnt()` takes target as an explicit first arg. |
| 5 | `apt update` fails inside chroot | Android paranoid networking — `_apt` has no net-permitted group. Fix: add `inet` (3003) / `inet_raw` (3004) groups (see above). |
| 6 | dpkg errors trying to start services | No systemd. Stub `/usr/sbin/policy-rc.d` → `exit 101`. |
| 7 | Empty `$PATH` inside chroot; `run-parts: command not found` | `/etc/profile` bails before setting PATH when `run-parts` (debianutils) is missing. Fix: enter via `env -i` with explicit PATH (`ubuntu.sh` does this); optionally `apt install debianutils`. |
| 8 | Script won't execute | `/data` may be `noexec` → always `sh script.sh`, not `./script.sh`. |
| 9 | mount / device nodes misbehave | `/data` came up `nosuid`/`nodev` → `mount -o remount,dev,suid /data` (mount script does this automatically). |
| 10 | `chmod -R 777` on the SSD does nothing | It's **exFAT** — no Unix permission bits. It was a silent full-tree no-op. Removed. Real root bypasses mount perms anyway. |
| 11 | SSD not visible from inside the chroot | `/mnt/media_rw/...` is a host path. Bind it to `$ROOT/media/ssd` from the **host** shell, before entering. |
| 12 | Every Jellyfin library shows "unavailable" | `library.db` stores **absolute** paths. Bind target must be exactly `$ROOT/media/ssd` to match. |
| 13 | Jellyfin heap-alloc crash (under proot) | termux/proot#283. Worked around with `DOTNET_GCHeapHardLimit` (hex). Moot under chroot. |
| 14 | DOTNET tuning had no effect | Wrong var casing + hex-parsed limit — see the env-vars section. |
| 15 | (avoided) SQLite corruption | Never run `proot-distro login` and `chroot` against this rootfs at the same time. |
| 16 | Shutdown teardown doesn't always run | No real shutdown hook exists. `getprop sys.shutdown.requested` poller covers graceful power-off/reboot only. |

---

## Benchmark: proot vs chroot

Synthetic syscall-overhead test (run inside the container):
```sh
python3 -c "import os,time; t=time.time(); [os.stat('/etc/hostname') for _ in range(50000)]; print(time.time()-t)"
```

| Entry mechanism | Result |
|---|---|
| `proot-distro login` | ~**8.0 s** (3 runs: 8.03 / 8.21 / 8.04) → ~160 µs/syscall ptrace overhead |
| `chroot` (expected) | ~0.15–0.4 s |
| `chroot` (measured) | ~0.09-0.1 s |

The microbenchmark is the best-case ceiling. Real-world gain on library scans /
apt / startup expected ~2–5×; streaming throughput was already near-native.

---

## Known loose ends

- Chroot-side benchmark not captured — the whole point of the migration.
- No convenience aliases yet. Options considered: `.bashrc` in root's real
  `$HOME` (only if the root shell is actually bash — `echo $0` after `su`);
  a sourced `aliases.sh`; or copying scripts into `/system/bin` as `ub` /
  `mntub` / `umntub` / `jf` / `jfstop` (needs `/system` remounted rw).
  Putting `aliases.sh` in `service.d` **cannot work** — `service.d` runs
  detached, aliases only exist in the shell that defines them.
- `proot-distro` guard function (block `proot-distro login` while chroot mounts
  are live) discussed, not added.

---

## Roadmap

1. Prowlarr, Sonarr, qBittorrent.
2. Firewall hardening — known blocklists.
3. Jellyseerr, integrated with the above.

---

## References

If something here stops making sense, these are the sources to re-read. Grouped
by which part of the setup they explain.

### Running things at boot / shutdown
- **Magisk — Boot Scripts** — https://topjohnwu.github.io/Magisk/guides.html —
  what `/data/adb/service.d/` is, `post-fs-data` vs `service` (late_start),
  execution context. Explains why `service.d` runs before storage unlock and as
  a non-app SELinux domain.
- **Termux:Boot** — https://wiki.termux.com/wiki/Termux:Boot — the *intended*
  way to auto-start Termux-user services (e.g. `sshd`, `termux-wake-lock`) on
  boot, as the Termux user in the right context. Preferred over hand-rolling it
  in a Magisk script.
- **Termux — Remote Access** — https://wiki.termux.com/wiki/Remote_Access —
  `sshd` setup, `passwd`, host keys, port 8022, `authorized_keys`.
- https://github.com/tytydraco/KTweak

### Useful sites to check out
- **proot-distro** — https://github.com/termux/proot-distro — how the Ubuntu
  rootfs is installed and where it puts things (`containers/<distro>/rootfs`).
- **termux/proot#283** — https://github.com/termux/proot/issues/283 — the
  Jellyfin/.NET heap-allocation crash under proot and the `DOTNET_GCHeapHardLimit`
  workaround (moot under chroot, kept for history).
- **Termux Wiki** — https://wiki.termux.com/wiki/Main_Page — general Termux
  behaviour, `$PREFIX`, storage layout.
- **`chroot(2)`** — https://man7.org/linux/man-pages/man2/chroot.2.html and
  **`mount(8)`** — https://man7.org/linux/man-pages/man8/mount.8.html — the
  `--bind`, `-t proc/sysfs/devpts/tmpfs`, and `remount` semantics the mount
  script relies on.
- https://www.termuxgenius.com/2026/08/how-to-fix-unable-to-locate-package.html
- https://github.com/termux/proot/issues/283

### Fun sites to check out for new integrations
- https://github.com/AwesomeHomelab/awesome-homelab
- https://github.com/awesome-selfhosted/awesome-selfhosted
- https://github.com/Ralex91/Razzia
- https://www.youtube.com/watch?v=_mP5z-IBVgU
- https://github.com/iptv-org/iptv
- https://www.youtube.com/watch?v=G-pi8fGJU7k