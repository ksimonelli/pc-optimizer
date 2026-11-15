# Gotchas - Hard-Won Lessons from Real Experience

These are things that weren't obvious, wasted time, or required multiple attempts to get right.
Read this before starting a session on a new machine.

---

## 1. The Bash/PowerShell $ Variable Problem

**Problem:** Running `powershell.exe -Command "..."` inside bash causes bash to expand `$variable`
before PowerShell ever sees it. Variables silently become empty strings. The script appears to run
but does nothing or throws cryptic errors like "Missing condition in if statement."

**Fix:** Always write PowerShell to a `.ps1` file, then run:
```bash
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "C:\path\to\script.ps1"
```

**Symptom to watch for:** An `if` statement with an empty condition, or `$null` where you expect
a value, or no output when output is expected.

---

## 2. GamingServices Re-enables Itself After Every Reboot

**Problem:** `Set-Service -Name GamingServices -StartupType Disabled` appears to work, but after
reboot the service is running again. Windows protects GamingServices from being changed via normal
service management APIs.

**Fix:** Set the registry value directly:
```powershell
Set-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Services\GamingServices' -Name Start -Value 4
Set-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Services\GamingServicesNet' -Name Start -Value 4
```
Value 4 = Disabled. Verify it holds after reboot.

---

## 3. Killer Network Manager Comes Back Under Different Names

**Problem:** Intel/Rivet "Killer Network Manager" installs 5+ services. You delete them by
registry key name, reboot, and they're back - because Windows re-registers them with display
names that differ from the key names.

**Fix:** After removal and reboot, check by display name:
```powershell
Get-Service | Where-Object { $_.DisplayName -like '*Killer*' }
```
Delete each survivor with `sc.exe delete <Name>` (use `.Name`, not `.DisplayName`).

---

## 4. WavesSvc64 Survives Normal Uninstall via DriverStore

**Problem:** Removing Waves MaxxAudio through Add/Remove Programs still leaves DriverStore
entries (`wavesapo*.inf`). Windows reinstalls the driver on reboot from cached entries.

**Fix:** Force-delete every Waves INF from the DriverStore:
```powershell
$waves = pnputil /enum-drivers | Select-String -Pattern 'wavesapo' -Context 4
# For each oem##.inf found:
pnputil /delete-driver oem##.inf /uninstall /force
```
Verify:
```powershell
Get-ChildItem 'C:\Windows\System32\DriverStore\FileRepository' | Where-Object { $_.Name -like 'wavesapo*' }
```

---

## 5. Dell TechHub Survives AppX Removal as Win32 Orphan

**Problem:** `Remove-AppxPackage` succeeds but Dell TechHub processes keep running from
`C:\Program Files\Dell\`. The AppX is gone but Win32 EXEs are orphaned.

**Fix:** After AppX removal:
```powershell
Get-Process | Where-Object { $_.Path -like '*\Dell\*' } | Stop-Process -Force
Remove-Item 'C:\Program Files\Dell\TechHub' -Recurse -Force
Remove-Item 'C:\Program Files\Dell\DTP' -Recurse -Force
Remove-Item 'C:\Program Files\Dell\MyDell' -Recurse -Force
```

---

## 6. DellClientManagementService Survives as a Standalone Service

**Problem:** Even after removing Dell Update (AppX), `DellClientManagementService` runs
`ServiceShell.exe` and locks the directory.

**Fix:**
```powershell
Stop-Service -Name DellClientManagementService -Force
sc.exe delete DellClientManagementService
Stop-Process -Name ServiceShell -Force -ErrorAction SilentlyContinue
Remove-Item 'C:\Program Files (x86)\Dell\UpdateService' -Recurse -Force
```

---

## 7. McAfee Leaves Orphan Services After Removal

**Problem:** McAfee's uninstaller (and even MCPR) leaves stopped services with missing binaries.

**Fix:**
```powershell
Get-WmiObject Win32_Service | Where-Object {
    $_.Name -like 'mfe*' -and $_.State -eq 'Stopped'
} | ForEach-Object { sc.exe delete $_.Name }
```

---

## 8. Teams Keeps Re-adding Itself to Startup

**Problem:** Deleting the Teams Run key works until Teams runs again - it re-registers on every launch.

**Fix:** Use the StartupApproved key:
```powershell
$val = [byte[]](0x03,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00)
Set-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run' `
    -Name 'com.squirrel.Teams.Teams' -Value $val -Type Binary
```

---

## 9. Fast Startup Causes Black Screen on Boot

**Problem:** Recurring black screen (no OEM logo, dark for 10-30 seconds) is commonly caused by
Fast Startup (Hybrid Boot) failing to reinitialize display drivers properly.

**Fix:** Disable Fast Startup first, before anything else:
```powershell
powercfg /hibernate off
reg add 'HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Power' /v HiberbootEnabled /t REG_DWORD /d 0 /f
```

---

## 10. Orphaned CBS Packages Can Block OS Upgrades

**Problem:** On the Ryzen 5600 machine, 63 orphaned AD LDS / ADAM CBS packages blocked a
Home-to-Pro upgrade with `0x8007042B - 0x2000D`. DISM `/Get-Packages` didn't show them as
installed - they were phantom registrations invisible to normal tooling.

**Fix:** Check for orphan packages in `C:\Windows\servicing\Packages\` that don't appear in
`DISM /Online /Get-Packages`. If found: back up, then remove via DISM `/Remove-Package` or
rename to `.bak` for stubborn TrustedInstaller-owned files.

**Lesson:** Before starting optimization, verify the OS edition is correct. If an edition change
is needed, do it FIRST as a separate task.

---

## 11. Missing License Token Files Block Edition Upgrades

**Problem:** Windows 11 Home-to-Pro upgrade failed with `0xc004f050` because the SPP token store
(`C:\Windows\System32\spp\tokens\skus\`) had no `Professional` directory.

**Fix:** Install the Pro license token package via DISM:
```powershell
DISM /Online /Add-Package /PackagePath:"C:\Windows\servicing\Packages\Microsoft-Windows-Security-SPP-Component-SKU-Professional-License-Package~...~amd64~~<version>.mum" /NoRestart
```

---

## 12. "MyUninstallAppNmae" is SimHub Orphan

**Problem:** Unknown app "MyUninstallAppNmae (SIMSONN Manager)" appeared in installed programs.
Investigation revealed it was an orphaned SimHub registry entry with a developer typo.

**Lesson:** When encountering unknown apps, check the registry uninstall key for clues before
spending time researching. Many orphaned entries are just bad registry data from poorly written
uninstallers.

---

## 13. sc.exe delete vs Remove-Service vs Set-Service

- `Set-Service -StartupType Disabled` - changes startup type but leaves service registered
- `Remove-Service` - works in newer PS, sometimes blocked by ACL
- `sc.exe delete` - most reliable, works in all PS versions, uses SCM directly

Use `sc.exe delete` for anything you want fully gone.

---

## 14. Running Processes Lock Directories You're Trying to Delete

**Problem:** `Remove-Item` fails with "Access denied" for directories that have running processes.

**Fix:** Check for processes holding the path:
```powershell
Get-WmiObject Win32_Service | Where-Object { $_.PathName -like "*FolderName*" }
Get-Process | Where-Object { $_.Path -like "*FolderName*" }
```
Stop the process/service first, then delete.

---

## 15. NVIDIA Profile Inspector Settings Reset on Driver Update

**Problem:** Custom NVIDIA Profile Inspector settings (frame limiter, pre-rendered frames, etc.)
can be overwritten during driver updates, especially "clean install" updates.

**Fix:** Always export your profile before driver updates (File > Export in Profile Inspector).
After updating, re-import. Consider keeping the export in this project's `scripts/` folder.

---

## 16. Game Mode Should Be ON for Gaming Machines, OFF for Non-Gaming

**Problem:** The Dell XPS optimization turned Game Mode OFF (correct for a non-gaming laptop).
But on a gaming desktop, Game Mode provides real scheduler benefits - MMCSS priority for the
foreground game and DWM scheduling improvements.

**Fix:** Phase 00 should detect whether this is a gaming machine. If dedicated GPU is present
and gaming software is installed, Game Mode = ON. Otherwise OFF.

---

## 17. Verify After Every Reboot

Things that can silently re-enable after reboot:
- GamingServices (Windows-protected)
- Killer Network services (re-register under new names)
- WavesSvc64 (reinstalls from DriverStore)
- Dell services (Win32 orphans restart)
- Teams startup entry (re-adds itself)

Always run the verification script after any reboot before continuing.

---

## 18. .ps1 Files Must Be Pure ASCII (PowerShell 5.1 -File)

**Problem:** Scripts authored by an editor that saves UTF-8 without BOM, containing an em-dash,
smart quote, or arrow glyph in a comment or string, fail under
`powershell.exe -File script.ps1` with confusing errors: "The string is missing the terminator",
"Unexpected token ')'", "Unexpected token" on lines that look fine.

**Cause:** PowerShell 5.1 reads a BOM-less file as ANSI. A UTF-8 em-dash (0xE2 0x80 0x94)
becomes three mojibake chars, one of which the parser treats like a quote.

**Fix:** Keep shipped `.ps1` files ASCII-only. Use `-` not em-dash, `->` not an arrow,
straight quotes only. Lint before running:
```powershell
Get-ChildItem *.ps1 | % { if ((Get-Content $_ -Raw) -match '[^\x00-\x7F]') { "NON-ASCII: $($_.Name)" } }
```

*Source: 2026-09-10 ASUS TUF FX504GD session*

---

## 19. Temp Cleanup Kills the Claude Code Task Pipe

**Problem:** A disk-cleanup phase that does `Remove-Item "$env:TEMP\*" -Recurse` deletes
Claude Code's own live task-output file under
`...\AppData\Local\Temp\claude\<project>\tasks\*.output`, and the tool call returns
"bash output unavailable ... could not be read (ENOENT)".

**Fix:** In temp-cleanup, skip anything matching `*\Temp\claude\*`, or only clear known
subfolders instead of the `$env:TEMP` root. The system is unharmed; only that phase's
console output is lost (the transcript log survives).

*Source: 2026-09-10 ASUS TUF FX504GD session*

---

## 20. ASUS TUF/ROG: Keep the ATK Package Scheduled Task

`\ATK Package` (ATKACPI) drives the Fn-key hotkeys and keyboard backlight on ASUS TUF/ROG
laptops. Do not disable it during startup/task cleanup. (Armoury Crate, MyASUS, GameFirst,
AsusCertService, GameSDK are fair game if present - this machine had none.)

*Source: 2026-09-10 ASUS TUF FX504GD session*

---

## 21. Flash-Tuning / OBD Laptop Profile

A laptop used to flash vehicle ECUs (VCDS, HP Tuners, EFILive, COBB, NefMoto, J2534) has
hard constraints a normal optimization can break:
- **USB selective suspend OFF** - AC and DC, plus `HKLM\SYSTEM\CurrentControlSet\Services\USB
  \DisableSelectiveSuspend = 1`, plus per-device `EnhancedPowerManagementEnabled = 0`.
  A USB port sleeping mid-flash can brick an ECU.
- **PCI Express ASPM OFF** - link-state power management causes comms glitches.
- Never disable `serial`, `serenum`, `usbser`, `ftdibus`, `ftser2k`, or the "Ports (COM & LPT)"
  class. Keep `PcaSvc` (Program Compatibility Assistant) for old tuning tools.
- Keep .NET Framework 3.5 AND 4.x (VCDS, NefMoto need them).
- Do not aggressively firewall/telemetry-block outbound - several tuning suites phone home
  for license/credit validation (HP Tuners, EFILive).
- Add the tuning tool folders to Defender exclusions so a scan can't lock a flash DLL.

*Source: 2026-09-10 ASUS TUF FX504GD session (VCDS + NefMoto)*

---

## 22. Claude Code Does Not Survive a Reboot - Make Reboots Hands-Off

**Problem:** A reboot kills the Claude Code session, and nothing restarts it. If the plan puts steps after a
reboot ("log in, open an elevated terminal, run claude --continue"), a user who stepped away comes back to a
half-finished job and has to drive it themselves.

**Fix:**
1. Order the work so there is ONE reboot, at the very end. Driver downloads, uninstalls and installs can all run
   with `-noreboot` before it.
2. Finish ALL Claude-side work (checkpoint, retrospective, report) BEFORE rebooting.
3. Put post-reboot verification in a self-running script. `scripts\15-schedule-postreboot-verify.ps1` registers a
   one-time scheduled task (AtLogOn, RunLevel Highest, deletes itself) that runs `postreboot-verify.ps1`: wait a few
   minutes, run any `run\postreboot-*.ps1` hooks, run the verify script, open the report in Notepad.
   Prefer the task over `HKLM\...\RunOnce`: RunOnce entries run with the user's UN-elevated token under UAC.
4. Tell the user at the START that Windows login itself can't be automated without storing their
   password, so "log in when you get back" is the only thing left for them.

*Source: 2026-09-10 ASUS TUF FX504GD session - user had to relaunch Claude by hand after reboot #1*

---

## 23. Win32_StartupCommand Still Lists Entries You Disabled

Disabling a startup entry the Task Manager way (StartupApproved binary = 03...) leaves the Run-key value in
place, so `Get-CimInstance Win32_StartupCommand` keeps listing it. That is expected. Verify via the
StartupApproved value (first byte 2 = enabled, 3 = disabled) or Task Manager > Startup apps, which is what
`15-verify.ps1` prints. Deleting Run values instead is NOT better: Teams/Edge/Spotify re-add them (#8).

*Source: 2026-09-10 ASUS TUF FX504GD session*

---

## 24. Tables Vanish in Claude Code Tool Output Unless Piped Through Out-String

`Select-Object ... | Format-Table` inside a script run from the Claude Code tool often shows nothing for
multi-object output. Always finish with `| Out-String -Width 200` (the `Out-Table` helper in `_common.ps1`
does this) for any structured output that matters.

*Source: 2026-09-10 ASUS TUF FX504GD session*

---

## 25. Never Query Win32_Product

`Get-WmiObject Win32_Product` (and `Get-CimInstance Win32_Product`) enumerates by making Windows Installer
validate and REPAIR every MSI product on the machine. It takes minutes, writes "reconfigured" events for every
product, and can trigger repair installs. Read the three uninstall registry keys instead -
`Get-InstalledPrograms` in `_common.ps1`. `_lint.ps1` flags any script that still uses it.

*Source: 2026-11 framework review (old 01/06/07 scripts used it)*

---

## 26. `netsh int ip reset` Wipes Static IPs and Custom DNS

The "network stack reset" in the old pre-flight ran `netsh winsock reset` + `netsh int ip reset` on every
machine. On a PC with a static IP, custom DNS or a VPN adapter that silently breaks networking after the
reboot. It is now opt-in (`02-preflight.ps1 -ResetNetwork`) and only for users who actually have network problems.

*Source: 2026-11 framework review*

---

## 27. `Do` Is a Reserved Word - Function Names That Break Parsing

`function Do($x) {...}` parses, but every call `Do "text" { ... }` is read as a `do {} while` loop and the
whole script fails with "Missing statement body in do loop". The same applies to `foreach`, `switch`, `try`,
`process`, `begin`, `end`, `filter`, `class`. Name helpers `Step`, `Invoke-X`, `Set-X`. `_lint.ps1` catches it
because the file no longer parses.

*Source: 2026-11 framework review*

---

## 28. `Get-AppxPackage -AllUsers` Throws a Terminating Error When Not Elevated

Even with `-ErrorAction SilentlyContinue`, an un-elevated shell gets a terminating "Access is denied" from
`Get-AppxPackage -AllUsers`. Wrap it in try/catch and fall back to the current user's packages
(`Get-AllAppx` in `_common.ps1`), and run `Assert-Admin` first in every script that changes anything.

*Source: 2026-11 framework review (seen while validating 00-detect-system.ps1)*

---

## 29. Gaming Machines: Xbox Apps and GamingServices Are Not Bloat

Removing `Microsoft.GamingApp` / `XboxIdentityProvider` / `Xbox.TCUI` or registry-disabling GamingServices
breaks Game Pass, Minecraft sign-in, the Xbox app and some anti-cheat. The old 03/04 scripts did this
unconditionally. Now: Xbox apps are a separate tier (`03 -RemoveXbox`), Xbox services go to Manual (start on
demand), and GamingServices is only disabled with `06 -DisableXbox` when `profile.keep.xbox` is false.

*Source: 2026-11 framework review*

---

## 30. OEM Control Apps Are Not Always Bloat

Armoury Crate (ASUS), OMEN Gaming Hub (HP), Lenovo Vantage / Legion Zone, PredatorSense / NitroSense (Acer),
MSI Center, Razer Synapse, Samsung Settings: ugly and heavy, but on many laptops they are the ONLY way to set
fan curves, performance modes, keyboard lighting and the battery charge limit, and some deliver firmware.
`04-oem-audit.ps1` puts them in the ASK FIRST bucket; remove only when the user says they do not use them
(and suggest G-Helper for ROG/TUF owners who drop Armoury Crate). Fn-key / hotkey helpers are KEEP.

*Source: 2026-11 framework review, 2026-09-10 ASUS session (ATK Package)*
