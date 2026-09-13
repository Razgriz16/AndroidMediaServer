# Postmortem

**Verdict: failed** as a fully-automated acquisition + streaming pipeline.
Jellyfin media streaming itself succeeded and remains functional — the
failure is specifically in the download-automation half added on top.

## Goal

Repurpose a spare rooted phone (Poco X3 NFC) as a home media server:
Jellyfin streaming + automated TV/movie acquisition (Sonarr/Prowlarr + a
download backend), self-hosted, free or cheap, avoiding a VPN if possible.

## Decision trail

1. **`proot` → `chroot` migration.** `proot`'s `ptrace`-based syscall
   interception added ~160 µs/call; real chroot removes it entirely.
   Measured ~40–80× lower syscall overhead. **Worked.**
2. **Download backend, first attempt: a Usenet-based client-server model.**
   Evaluated backend architectures for cost, network exposure, and
   automation fit. Chose a client-server (Usenet) model over a peer-to-peer
   one for its smaller network attack surface, despite higher upfront cost
   and setup complexity. Built Sonarr + Prowlarr + SABnzbd end to end.
3. **That backend abandoned.** SABnzbd's from-source install (venv, ARM
   build deps) was materially more complex than Sonarr/Prowlarr's binary
   installs; the exFAT SSD threw filename/sparse-file warnings; the free
   trial provider's backend had confirmed incomplete data availability
   (`issues.md` #3–4). Not worth the ongoing cost for an unproven pipeline.
4. **Pivoted to a peer-to-peer backend (qBittorrent) with a network-privacy
   layer.** Compared several IP-exposure mitigations before committing:
   ruled out Tor (its peer-discovery traffic runs over UDP, which Tor
   doesn't proxy — leaks the real IP regardless of routing through it; also
   actively discouraged by the Tor Project itself for this use) and a
   self-hosted proxy on a generic cloud VPS (cheaper, but most providers'
   ToS prohibit this traffic class and terminate accounts on abuse
   complaints — confirmed via a provider's own community forum). Settled on
   a flat-rate, month-to-month VPN.
5. **Final blocker: hardware, not software.** Confirmed via research that the
   Poco X3 NFC's USB-C port is hardware-limited to USB 2.0 — real-world
   ceiling ~48 MB/s regardless of the SSD's own speed, the cable, or any
   config. Every download-side throughput problem traced back to this one
   constraint. No software fix exists for it.
6. **Unresolved in parallel:** 4 configured indexers returned zero results
   for two popular, well-seeded series — never diagnosed before the hardware
   issue ended the project (`issues.md` #5).

## What worked

- Jellyfin streaming, and the chroot migration's syscall-overhead win
- Full service orchestration: SSD-mount reference-counting across 4
  independent services, graceful shutdown, a single dispatcher
  (`media-services.sh`) for start/stop-by-group
- Reasoned, sourced research at every fork (backend architecture, network-
  privacy options, self-hosted vs. paid) rather than assumed decisions

## What didn't

- Download throughput — hard USB 2.0 ceiling specific to this phone
- Automated search — never completed a single successful automated grab
- ACCA battery charge-limit fix — rolled back, didn't hold in practice
  (`issues.md`)

## Root cause

Not a configuration or software failure — a hardware I/O ceiling discovered
only empirically, after the automation stack was already built around it.

## Lesson

Verify hardware throughput ceilings (USB transfer speed, in this case)
*before* building software around them. Would have caught this before the
backend research and rebuild, not after.

---

See `README.md` (build reference), `architecture.md` (system/storage
design), `issues.md` (full issue log) for the detail behind each point above.
