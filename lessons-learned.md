# Lessons Learned - Evolving Knowledge Base

This file grows across sessions. Read it at the start of every new optimization run.
Each lesson includes the source session so you can judge its relevance.

---

## Methodology

### Always inventory before changing anything
*Source: Both sessions (Dell XPS + Ryzen 5600)*

Running a full system inventory first (CPU, GPU, RAM, drives, installed apps, services, startup, scheduled tasks) makes every subsequent decision data-driven. Without it, you're guessing what to remove.

### Pre-flight SFC/DISM catches hidden corruption
*Source: Dell XPS session*

Running `sfc /scannow` and `DISM /Online /Cleanup-Image /RestoreHealth` before any optimization catches component store corruption that would cause mysterious failures later. On the Dell, SFC found and repaired corrupt files. On the Ryzen, DISM RepairHealth was needed after the ADAM artifact cleanup.

### Check OS edition BEFORE starting optimization
*Source: Ryzen 5600 session*

The Home-to-Pro upgrade consumed massive time and tokens as a mid-session rabbit hole. If an edition change is needed, do it first as a separate task, or at minimum identify it in Phase 00 and handle it before touching services/settings.

### Separate automatable from manual steps upfront
*Source: Ryzen 5600 session*

The original guide mixed PowerShell commands with manual GUI steps. This made it unclear what Claude could do automatically vs what needed user action. Each phase should clearly label: AUTOMATABLE (script), MANUAL (user GUI), VERIFICATION (confirm command).

### One document per phase, not a monolith
*Source: Comparison of both sessions*

The Dell project's phase-per-file structure with matching scripts was far more navigable than the Ryzen project's single 800-line guide. Breaking into phases also enables the checkpoint system.

### Set services to Manual, not Disabled
*Source: Ryzen 5600 session*

Manual means "don't auto-start but can start on demand." Disabled means "refuse to start even if something needs it." Manual is safer and caused zero breakage. Only use Disabled for services you're certain nothing depends on (telemetry, fax).

### Win11Debloat was fast, but a remote script is the wrong tool on someone else's PC (superseded)
*Source: Ryzen 5600 session; superseded 2026-11-15*

Win11Debloat in Custom mode removed 91 apps in one shot on the Ryzen machine. It is no longer used: piping a
remote script into PowerShell on a stranger's PC is a trust and reproducibility problem (the script changes,
there is no preview, no backup, no profile awareness). Everything useful it did is now in `03-remove-apps.ps1`
(tiered, previewable), `07-privacy.ps1` and `08-startup-cleanup.ps1`.

---

## Technical

### NVIDIA Profile Inspector > NVIDIA Control Panel
*Source: Ryzen 5600 session + GPU research agent*

Profile Inspector exposes frame limiter v2 (sub-ms precision), pre-rendered frames per-profile, texture LOD bias, and DLSS version overrides. Always use it in addition to NVCP for gaming rigs.

### The VRR + frame limiter recipe
*Source: GPU research agent*

G-Sync/FreeSync ON + driver V-Sync ON + Low Latency ON + frame cap at monitor Hz minus 3 = optimal tear-free low-latency gaming. V-Sync never activates because FPS never hits the ceiling.

### Nagle's algorithm matters for online gaming
*Source: Ryzen 5600 session*

`TcpAckFrequency=1` and `TCPNoDelay=1` per adapter GUID reduces network latency for online racing/gaming. Real measurable impact on packet delay.

### Windows Defender exclusions cut npm install time by 50%+
*Source: Ryzen 5600 session + dev tools research agent*

Excluding node_modules, npm cache, .claude, and node.exe from real-time scanning is the single biggest Node.js performance improvement on Windows.

### Git fsmonitor and untrackedcache are significant on large repos
*Source: Dev tools research agent*

`core.fsmonitor true` and `core.untrackedcache true` (Git 2.37+) use a filesystem monitor daemon to track changes, making `git status` and `git diff` near-instant on large repos.

### HAGS: enable on RTX 3000+/RX 7000+ with 10+ GB VRAM
*Source: Power research agent*

Average FPS gain is negligible (~0.3%) but frame pacing and input latency can improve. Can consume ~1GB extra VRAM, so avoid on 6-8GB cards. Benchmark per-game.

### SysMain: negligible on NVMe, disable if you want clean idle
*Source: Both sessions + power research agent*

On NVMe SSDs with 16+ GB RAM, SysMain's impact is negligible in either direction. Disabling reduces background disk I/O during idle. Leaving it on is also fine.

### Ultimate Performance > High Performance for gaming desktops
*Source: Ryzen 5600 session*

Ultimate Performance prevents CPU cores from entering deep idle, eliminating micro-latency of core wake-ups. Helps 1% low frametimes in competitive gaming. Not available by default - must unhide with `powercfg -duplicatescheme`.

### Fast Startup causes boot issues on many OEM laptops
*Source: Dell XPS session*

Disable Fast Startup in Phase 02 before anything else. It's the most common cause of black screen on boot and inconsistent shutdown behavior.

---

## Pitfalls

### Unknown apps: check registry before researching online
*Source: Ryzen 5600 session*

"MyUninstallAppNmae" cost investigation time. Checking the registry uninstall key directly would have revealed it was SimHub junk immediately. Many orphaned entries are just bad registry data.

### OEM AppX removal != complete removal
*Source: Dell XPS session*

Dell TechHub, Dell SupportAssist, and other OEM apps leave Win32 processes and services running after AppX removal. Always check for orphan processes and services after AppX cleanup.

### Some services are Windows-protected
*Source: Dell XPS session*

GamingServices ignores `Set-Service` and re-enables after reboot. Must use direct registry `Start=4` under `HKLM:\SYSTEM\CurrentControlSet\Services\`.

### The bash $ expansion problem is silent and devastating
*Source: Dell XPS session*

Inline PowerShell from bash silently expands `$variables` to empty strings. Always write to .ps1 files. This single gotcha has wasted more time than any other issue across all sessions.

---

## Session History

| Date | Machine | Key Outcomes |
|------|---------|-------------|
| 2026-03-16 | AMD Ryzen 5600 / RTX 3060 / 16GB | Full optimization + Home->Pro upgrade. 9GB freed, 91 apps removed, GPU/gaming/dev tuning. |
| 2026-03 | Dell XPS 13 7390 / i7 / 16GB | 8-session debloat. RAM idle 10.1->6.39GB, 107GB freed, McAfee+Dell bloat removed, BIOS updated. |
| 2026-03-23 | N/A (meta-session) | Combined both sessions into unified framework with self-improvement system. |
| 2026-09-10 | ASUS TUF FX504GD / i5-8300H / GTX 1050 / 8GB | VW/Audi flash-tuning laptop + gaming/video. Aggressive debloat 151->118 AppX, 8 telemetry svcs + 20 tasks off, USB-suspend/ASPM off for flashing safety. NVIDIA 512->582 clean install. New "flash-tuning" + "low-RAM" profiles. |
| 2026-11-15 | N/A (framework rebuild) | Profiles wired into the scripts via `profile.json`; one script per phase with matching numbers; tiered removals (safe / ask / never); hands-off single reboot via scheduled task; generic OEM audit; Windows Update via COM API; ASCII lint. |

---

## Profiles (wired into the scripts since 2026-11-15)

Phase 00 writes `profile.json`; every script reads it. The rules below are what the scripts do.

### Low-RAM branch (<= 8 GB physical) - invert the 16GB+ NVMe defaults
*Source: 2026-09-10 ASUS TUF session*
- SysMain stays ON (prefetch helps working-set management under memory pressure) - `06-services.ps1`.
- WSearch stays ON unless the user says they never search (`-DisableSearch`).
- Pagefile never touched - system-managed. `10-performance.ps1` only reports it.
- Visual effects -> performance preset, keeping font smoothing and thumbnails - `10-performance.ps1`.
- Prefetch folder never cleared - `14-disk-cleanup.ps1`.

### Flash-tuning / OBD laptop (see gotchas.md #21)
*Source: 2026-09-10 ASUS TUF session*
USB selective suspend + per-device USB power + PCIe ASPM all OFF (`10-performance.ps1`); serial/FTDI stack,
PcaSvc, .NET 3.5+4.x preserved (never-touch list in `_common.ps1`, PCA tasks kept in `06`); Defender exclusions
for tuning dirs added by hand after asking; no outbound blocking anywhere (tuning suites need it for licensing).
Detected via the `flashTuning` regex in `_common.ps1` ($Detect), `C:\Ross-Tech`, or FTDI/J2534/USB-serial hardware.

### Gaming (incl. sim racing)
*Source: Ryzen 5600 session, ASUS TUF session, 2026-11 review*
Xbox apps and GamingServices are kept (Game Pass, Minecraft sign-in, anti-cheat); Xbox services go to Manual.
Game Mode ON, background Game DVR OFF, Nagle off, throttling off. Steam/Discord autostart is the user's call.
Sim racing adds USB selective suspend OFF and protects wheel/pedal software in startup.

### Low-interaction defaults for an unknown user
*Source: 2026-11 review*
When nothing is detected the machine is treated as office/general: only the SAFE tier of apps goes, Mail /
Phone Link / OneNote / Teams / Spotify stay unless asked, location stays on, Search stays on, Spooler stays if
a printer exists, OneDrive is never touched.

### Hands-off reboot
*Source: ASUS TUF session, gotchas #22*
All phases run with no reboot; `09-updates.ps1` defers reboots and writes `logs\reboot-required.txt`;
`15-schedule-postreboot-verify.ps1 -Reboot` is the last command of the session, after the retrospective.

### Keep personal details out of the shared files
*Source: 2026-11 review (public repository)*
Retrospectives and lessons describe the machine and the decisions, never the person: no names, e-mail
addresses, Windows usernames in paths (`$env:USERPROFILE`, not `C:\Users\<name>`), or hostnames that identify
someone. `profile.json`, `logs\`, `backup\` and `run\` are git-ignored because they contain those.
