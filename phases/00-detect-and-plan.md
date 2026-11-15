# Phase 00 - Detect System, Use Case and Plan

**Script:** `scripts/00-detect-system.ps1` (read-only; writes `profile.json`)

Runs before anything else. Works out what the machine is, who it belongs to in terms of USE, what must not
be broken, and which phases apply. Every later script reads `profile.json`, so getting this right is most of
the safety of the whole run.

## What is detected

| Field | How | Drives |
|---|---|---|
| `oemKey` | `Win32_ComputerSystem.Manufacturer` -> dell / hp / lenovo / asus / acer / msi / samsung / microsoft / razer / gigabyte / custom / other | Phase 04 variant |
| `isLaptop` | chassis type or a battery present | hibernate kept, power plan, BIOS-on-charger rule |
| `gpuBrand`, `hasDedicatedGpu`, `vramGB` | `Win32_VideoController` + registry `HardwareInformation.qwMemorySize` (AdapterRAM caps at 4 GB) | Phase 11, HAGS, visual effects |
| `ramGB`, `lowRam` (<= 8 GB) | `Win32_OperatingSystem` | SysMain/Search kept, pagefile untouched, visual effects |
| `systemDiskType` | the physical disk behind C: (NVMe / SSD / HDD) | SysMain decision |
| `osVersion`, `osSupported` | `DisplayVersion` in the registry; 21H2/22H2/23H2 Home/Pro are out of support | recommend a feature update (separate task) |
| `thirdPartyAV` | `root/SecurityCenter2` minus Defender | Phase 05 |
| `workloads` | installed programs (uninstall registry keys, never Win32_Product), AppX names, PnP device names, `Get-Command` | see below |
| `keep` flags | printer present, Xbox app present, OneDrive in use, touch/pen, biometrics | never-touch decisions |
| `baseline` | RAM used, C: free, startup entries, AppX count, program count | before/after numbers in Phase 15 |

### Workloads

| Workload | Signals (regexes live in `_common.ps1` `$Detect`) |
|---|---|
| gaming | Steam / Epic / GOG / Battle.net / EA / Ubisoft / Riot / Xbox app / Rockstar / Minecraft |
| simRacing | iRacing, Assetto, SimHub, rFactor, BeamNG...; Fanatec / Thrustmaster / Logitech G / MOZA / Simucube hardware |
| streaming | OBS, Streamlabs, XSplit, Elgato, NVIDIA Broadcast |
| creative | DaVinci, Premiere, After Effects, Photoshop, Lightroom, CapCut, Blender, Affinity, DAWs |
| cad | SolidWorks, AutoCAD, Fusion 360, Inventor, FreeCAD, SketchUp, Revit, KiCad... |
| dev | Visual Studio, JetBrains, Docker, Unity/Unreal, `git`/`node`/`python`/`docker`/`code` on PATH |
| flashTuning | VCDS / Ross-Tech, HP Tuners, EFILive, COBB, SCT, NefMoto, J2534, Tactrix, OBDeleven, WinOLS, Forscan, BimmerCode, ODIS, Techstream...; `C:\Ross-Tech`; FTDI / "USB Serial Port" / J2534 devices |
| office | Microsoft 365 / Office, LibreOffice, Zoom, Teams, Slack, Webex, accounting software |

Nothing detected = general / office use, which is the most conservative set of defaults.

### Keep-flags

These are the things a careless optimization breaks for a real person:

- `printer` -> Print Spooler stays
- `xbox` (Xbox app present OR gaming) -> Xbox apps stay, GamingServices stays startable
- `onedrive` (process running or a synced folder exists) -> never touched in startup, never removed
- `touch` -> TabletInputService / TextInputManagementService stay
- `biometric` -> WbioSrv (Windows Hello) stays
- `search` -> always true until the user says otherwise
- `sysmain` -> true on <= 8 GB RAM or an HDD

## Confirm with the user

Read the plan out in plain language and ask (one question at a time, plain words):

1. "Do you play games on this PC? Do you use Xbox Game Pass or the Xbox app?"
2. "Do you use OneDrive to keep your files backed up?"
3. "Do you print from this PC?"
4. "Do you use the search box in the Start menu to find files?"
5. Anything the detection got wrong: `.\00-detect-system.ps1 -AddWorkload gaming` / `-RemoveWorkload dev`,
   or edit `profile.json` directly.

Then write the first `checkpoint.md` with the profile summary and the plan.

## Output

```
=== OPTIMIZATION PLAN FOR <HOST> ===
  [x] 01 System inventory              01-system-info.ps1
  [x] 02 Pre-flight + backups           02-preflight.ps1
  [x] 03 Remove bloatware apps          03-remove-apps.ps1 (Xbox apps KEPT)
  [x] 04 OEM bloat                      04-oem-audit.ps1 ... [asus]
  [-] 05 3rd-party AV removal           SKIP - Defender only
  ...
Profile rules in force:
  * LOW-RAM (<=8 GB): ...
  * FLASH-TUNING: ...
```

## Edition / version check

If `osSupported` is false (21H2 / 22H2 / 23H2 on Home or Pro), tell the user the PC is no longer getting
security updates and recommend the feature update to the current release as a SEPARATE task after this run.
Do not mix a feature update into the optimization (lessons-learned: the Home->Pro rabbit hole).
