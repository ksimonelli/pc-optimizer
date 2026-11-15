# Phase 09 - Updates: Windows, Drivers, Apps, BIOS (no reboot)

**Script:** `scripts/09-updates.ps1`

Everything in this phase runs WITHOUT rebooting; the single reboot at the end applies it all (gotchas #22).
The script uses the built-in Windows Update COM API (no modules to install) and writes
`logs/reboot-required.txt` when a reboot is pending.

```powershell
.\09-updates.ps1                    # scan and list
.\09-updates.ps1 -Install           # install pending Windows updates (incl. Microsoft-offered drivers), no reboot
.\09-updates.ps1 -Install -Winget   # also upgrade winget-managed apps (ASK: it updates browsers, launchers, everything)
.\09-updates.ps1 -Install -Oem      # also run Dell Command Update / Lenovo System Update if installed
```

## Order of importance

1. **Windows cumulative update** - security. Always.
2. **Chipset / platform drivers** - from the OEM tool (Dell/Lenovo scripted; HP via HP Image Assistant; ASUS,
   Acer, MSI, Samsung: support page for the exact model) or from Windows Update.
3. **GPU driver** - see below. On a gaming machine do not rely on Windows Update's GPU driver.
4. **Audio, network, Bluetooth** - OEM tool or Windows Update.
5. **BIOS / firmware** - only when it fixes something (stability, security advisories, CPU support), only
   from the OEM tool or the OEM's own installer, **only on the charger**, never interrupted. The script skips
   firmware-class updates when on battery.

## GPU drivers

**NVIDIA** - download the current Game Ready (gaming) or Studio (creative/CAD) driver for the exact GPU from
nvidia.com. Custom install > "Perform a clean installation". The plain driver package still bundles GeForce
Experience / the NVIDIA app; a clean install of Display.Driver + PhysX + NVI2 only gives a driver with no
telemetry tasks (ASUS session: 25 packages -> 3, zero NVIDIA scheduled tasks). DDU in Safe Mode is only needed
when the existing install is broken. Old GPUs (GTX 9xx/10xx) stay on the last security branch that supports them.
NVIDIA Profile Inspector settings are lost on clean installs: export first (gotchas #15).

**AMD** - amd.com/support, the "Factory Reset" option in the installer is the clean install.

**Intel Arc / iGPU** - Intel Driver & Support Assistant or the OEM's package on laptops (OEM-customised).

**Laptops with Optimus/hybrid graphics**: the OEM driver is sometimes required for the display to work
correctly; if the vendor driver refuses to install, use the OEM's.

Run GPU installers with their no-reboot option and let the final reboot apply them. If the job needs a post-
install check, write `run/postreboot-gpu.ps1`; `postreboot-verify.ps1` runs it automatically.

## winget

`winget upgrade` lists what is upgradable. `-Winget` runs `--all --silent`. Ask first: it also upgrades
Steam/Discord/browsers (fine) and anything the user pinned to a version (not fine). On machines with tuning
or lab software, check the list and exclude with `winget pin add <id>` if needed.

## Verify

```powershell
Get-CimInstance Win32_VideoController | Select-Object Name, DriverVersion, DriverDate
(Get-CimInstance Win32_BIOS).SMBIOSBIOSVersion
```
Compare the BIOS version with the OEM support page for the model. Note any available BIOS update in the
checkpoint with the user's decision; never flash from inside an automated run.
