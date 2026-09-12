# Device issues — Poco X3 NFC

Problems hit on this phone that aren't part of the media-server build itself,
kept here so a fix isn't re-discovered from scratch next time. See
`README.md` for the media server; this file is everything else about the
device (root, Magisk modules, ROM quirks).

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
