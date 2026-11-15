# Phase 01 - System Inventory

**Script:** `scripts/01-system-info.ps1` (read-only; saves `logs/inventory-<date>.txt`)

Establishes the complete "before" picture. Every later decision ("is this service bloat or does something
use it?") comes back to this file. Keep it: the retrospective quotes it.

## What it collects

- Machine, CPU, BIOS, OS build, uptime, RAM used/total, pagefile mode
- Memory modules, GPUs (driver version + date, current resolution/refresh), physical disks (type, bus, health), volumes
- Network adapters that are up
- Antivirus products (SecurityCenter2) and Defender status
- Power plan, Fast Startup state
- Printers, COM ports / serial devices, present USB and HID devices (wheels, pedals, tuning cables show up here)
- Installed programs (three uninstall registry hives, never `Win32_Product`), non-system AppX packages
- Running services with non-Windows binaries, all Automatic services
- Startup entries (Win32_StartupCommand) and the StartupApproved flags
- Enabled non-Microsoft scheduled tasks
- Top 15 processes by RAM
- Pending-reboot indicators

## What to look for

**RAM at idle** (fair reading needs >= 3 min uptime):
- 16 GB machine under 4 GB: already clean. 6-10 GB: typical OEM bloat. Over 10 GB: heavy.
- 8 GB machine: 3.5-4.5 GB is normal and good; do not chase numbers here, chase background processes.

**Programs / processes that signal a use case** that detection may have missed (odd tuning tools, lab
software, a kiosk app): add the workload with `00-detect-system.ps1 -AddWorkload ...` or protect the item with
the `-Keep` switches of later phases.

**Unknown programs:** check the uninstall key's Publisher/InstallLocation first (gotchas #12) before searching
the web; orphaned entries are usually just bad uninstallers.

**Hardware helpers in startup** (Realtek tray, touchpad, OEM hotkeys, wheel software, RT-Updater for VCDS):
these go on the never-touch side of Phase 08.

## Save baseline

Phase 00 already stored the numeric baseline in `profile.json`. Add to `checkpoint.md`:
- anything surprising (3rd-party AV, enterprise/VDI software, remote-access tools the user did not mention)
- programs the user says they rely on
