# Issues log — Poco X3 NFC

Device issues (root, Magisk, ROM) plus project-level issues hit during the
build that aren't chroot-migration mechanics — those are already tracked in
`README.md`'s "Failures hit during the build" table and not repeated here.
Most of `poco-x3-chroot-setup.md`'s draft notes (gitignored, local-only)
already migrated into that table over the course of the project; nothing
unique was left to pull from it.

See `postmortem.md` for the project's final verdict and decision trail.

---

## ACCA / ACC keeps dying — battery charge limit stops being enforced

**Symptom:** ACCA (Magisk GUI for VR-25's ACC daemon, `accd`), configured to
keep the battery between 75–80%, randomly stops enforcing the limit. Only a
reboot brings it back, until it dies again.

**Cause:** `accd` runs in "auto" mode by default — every cycle it probes
several possible charging-control sysfs nodes. If, on a given cycle, *all* of
them fail to actually stop charging (a kernel quirk, a fast-charge/PD
renegotiation, coming out of deep sleep), `accd` exits with **code 7** ("all
charging switches failed") and deliberately shuts itself down instead of
pretending it's still enforcing the limit. It's a safety abort, not a crash.

**Fix — pin the known-working switch for Poco X3 NFC (`surya`) instead of
relying on auto-probing:**
```sh
acc -s "s=/sys/class/power_supply/battery/input_suspend 0 1 --"
```
The trailing `--` disables auto mode fallback, so `accd` won't re-probe (and
won't self-terminate) if a single write ever looks like it failed.

Confirm the switch is actually the right one for this kernel first:
```sh
acc --test
```

Also whitelist ACCA from battery optimization (Settings → Battery →
Battery optimization → ACCA → **Don't optimize**) — LineageOS's Doze can
freeze the background loop during deep sleep, which looks identical to the
daemon "stopping."

If it still dies, capture a real log instead of guessing:
```sh
accd -x         # persistent log at /sdcard/Download/accd-<device>.log
acc -l tail     # last 10 lines of the daemon log right after it dies
acc -le         # full diagnostic export, incl. power_supply-*.log (every control node the kernel exposes)
```

**Outcome: rolled back.** Pinning `input_suspend` did not hold up in
practice — `accd` still stopped enforcing intermittently with the switch
pinned. Reverted to auto-probing mode. Deprioritized as low-impact once the
media-server project itself was declared failed; not revisited.

### References
#### ACCA
- **VR-25/acc** — https://github.com/VR-25/acc — upstream ACC daemon docs:
  exit codes (7 = all charging switches failed), pinning a switch with `-s`,
  `--test`, `-l tail`, `-le`, `accd -x` debug logging.
- **AccA issue #183 — "ACC daemon randomly stops"** —
  https://github.com/MatteCarra/AccA/issues/183
- **XDA — "AccA users, what Charging Switch are you using?"** —
  https://xdaforums.com/t/acca-advanced-charging-controller-app-users-what-charging-switch-are-you-using.4401471/
  — source for the Poco X3 (`surya`) working switch, `battery/input_suspend`.
- **Advanced Charging Controller (acc) — XDA megathread** —
  https://xdaforums.com/t/advanced-charging-controller-acc.3668427/

---

## Project-level issues (download/automation build, not chroot mechanics)

| # | Symptom | Cause | Resolution |
|---|---|---|---|
| 1 | `tar: Cannot open: Function not implemented` extracting Sonarr/Prowlarr | GNU tar used a newer file-creation syscall the phone's kernel/seccomp doesn't support — `mkdir` worked, regular-file creation didn't | Switched extraction to `bsdtar` / Python `tarfile` |
| 2 | `apt install git` failed, 404s on `perl`/`libperl`/`perl-modules` | Stale local apt package index vs. current mirror (unrelated to chroot) | `apt update`, retry |
| 3 | SABnzbd: "not writable with special character filenames," Direct Write disabled (no sparse-file support) | exFAT SSD lacks a POSIX filename charset and sparse files | Accepted as advisory, not fatal — moot once SABnzbd was removed |
| 4 | Usenet.Farm free-trial test download failed twice: 69→24 articles missing, PAR2 repair short by 879 blocks | Free-trial backend has incomplete article availability vs. the paid tier | Root-caused via retry pattern; not fixable without paying — contributed to dropping Usenet |
| 5 | 4 configured indexers returned zero results for two popular, well-seeded series | Unresolved — likely a Prowlarr↔Sonarr sync or category-mapping problem, not content absence (never confirmed via manual search on the tracker itself) | Not resolved before the project ended |
| 6 | **Download throughput to the SSD capped ~48 MB/s regardless of SSD speed or software config** | Poco X3 NFC's USB-C port is hardware-limited to USB 2.0 — confirmed via device research, not a driver/exFAT/chroot issue | **Root cause of the final verdict — no software fix exists** |
