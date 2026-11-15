# Phase 10 - Power, USB/PCIe Power Management, Visual Effects, HAGS

**Script:** `scripts/10-performance.ps1`

Profile-aware. Never touches the pagefile (system-managed is right on low RAM, and a user-sized pagefile is
their decision; the script only reports it). SysMain is decided in Phase 06.

## Power plan

| Machine | Plan | Extra |
|---|---|---|
| Desktop | Ultimate Performance (unhidden via `powercfg -duplicatescheme`), fallback High Performance | core parking off, sleep never, display off 20 min, disk never. ~5-15 W more at idle; better 1 % lows |
| Laptop, gaming (`workloads.gaming` or `-HighPerformance`) | High Performance | sleep never on AC / 30 min on battery, display 20 / 10 min, CPU max 100 %, Wi-Fi max performance on AC |
| Laptop, other | **Balanced** (keeps the Windows 11 power-mode slider usable) | AC only: never sleep, display 20 min, CPU max 100 %, Wi-Fi max performance |

Hibernate was already handled in Phase 02 (kept on laptops, off on desktops).

## USB selective suspend + PCIe ASPM - flash-tuning and sim-racing safety

When `workloads.flashTuning` or `workloads.simRacing` (or `-NoUsbSuspend`):
- USB selective suspend OFF for AC and DC in the active plan
- `HKLM\SYSTEM\CurrentControlSet\Services\USB\DisableSelectiveSuspend = 1` (global)
- per-device `EnhancedPowerManagementEnabled = 0`, `AllowIdleIrpInD3 = 0`, `DeviceSelectiveSuspended = 0`,
  `SelectiveSuspendEnabled = 0` on every present USB and COM-port device
- PCI Express Link State Power Management OFF (AC + DC)

A USB port sleeping mid-flash can brick an ECU; a wheel dropping out mid-race is nearly as bad (gotchas #21).
`15-verify.ps1` checks these survive the reboot on flash-tuning machines.

## Visual effects

`lowRam` or no dedicated GPU -> performance preset that keeps font smoothing, window-content dragging and
thumbnails, drops animations, transparency and shadows (VisualFXSetting 3 + UserPreferencesMask). Otherwise
left at default: on a dGPU + 16 GB the overhead is unmeasurable and users notice the missing animations.

## NTFS last-access timestamps

`fsutil behavior set disablelastaccess 1` - fewer metadata writes. Safe everywhere.

## HAGS (Hardware-Accelerated GPU Scheduling)

Enabled only for dedicated GPUs with >= 10 GB VRAM or RTX 30/40/50 / RX 7000+. Left off on 2-8 GB cards: it
costs ~1 GB VRAM for a negligible gain. Applies after the reboot.

## Deliberately not here

- Timer resolution hacks, IRQ priority, Win32PrioritySeparation, "disable memory compression", "disable
  paging executive": no measurable benefit on Windows 11, some risk, cargo-cult.
- Undervolting / fan curves: the OEM tool's job (Armoury Crate, Vantage...) or the user's.

## Verify

```powershell
powercfg /getactivescheme
powercfg /query SCHEME_CURRENT 2a737441-1930-4402-8d77-b2bebba308a3 48e6b7a6-50f5-4782-a5d4-53bb8f07e226   # USB selective suspend, 0 = off
fsutil behavior query disablelastaccess
```
