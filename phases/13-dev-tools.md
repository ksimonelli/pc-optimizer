# Phase 13 - Dev Tools, CAD & Creative Software

**Conditional:** Only when `profile.workloads.dev`, `.cad` or `.creative` is true. MANUAL / with the user.
Everything below is a recommendation to offer, not to apply silently: Defender exclusions for dev folders, git
config and Node settings change how the user's tools behave. Ask, then apply only what they want. Use
`$env:USERPROFILE` in any command, never a literal `C:\Users\<name>` path.

---

## Node.js / Claude Code

### Version
Stay on active LTS. Check and upgrade:
```powershell
node --version
winget upgrade OpenJS.NodeJS.LTS
```

### Git Performance Config
```bash
git config --global core.preloadindex true
git config --global core.fscache true
git config --global core.fsmonitor true
git config --global core.untrackedcache true
git config --global gc.auto 256
git config --global core.longpaths true
git config --global core.autocrlf true
git config --global credential.helper manager
git config --global init.defaultBranch main
git config --global diff.algorithm histogram
git config --global merge.conflictstyle zdiff3
git config --global pull.rebase true
git config --global push.autoSetupRemote true
```

### Long Path Support
```powershell
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem" -Name "LongPathsEnabled" -Value 1 -Type DWord
```

### Node.js Memory (for large projects)
```powershell
[System.Environment]::SetEnvironmentVariable("NODE_OPTIONS", "--max-old-space-size=4096", "User")
```
Scale by RAM: 16GB->2048, 32GB->4096, 64GB->8192.

### PowerShell 7
```powershell
winget install Microsoft.PowerShell
```
Use `pwsh.exe` as default shell. Faster startup, better tab completion, `ForEach-Object -Parallel`.

### Windows Terminal Settings
Verify Atlas engine is enabled in Windows Terminal settings:
```jsonc
{ "profiles": { "defaults": { "useAtlasEngine": true } } }
```

### PowerShell Execution Policy
```powershell
Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned
```

---

## SolidWorks Performance Tuning

### System Options > Performance (inside SolidWorks)

| Setting | Value | Why |
|---|---|---|
| Verification on rebuild | OFF | Massive rebuild time savings |
| Auto load components lightweight | ON | Loads only essential data |
| Enhanced graphics performance | ON | Modern GPU pipeline |
| Hardware accelerated silhouette edges | ON | Offloads to GPU |
| Use Software OpenGL | OFF | Only enable for GPU crash diagnosis |
| Curvature generation on rebuild | OFF | Skip unless using curvature display |

### Large Assembly Settings
Set threshold to 500 components (lower on weaker hardware). Suspends auto-rebuild, simplifies display.

### Image Quality
Tools > Options > Document Properties > Image Quality: slider toward Low for daily work, increase for final renders.

### Add-in Management
Disable startup for unused add-ins: CAM, Simulation, Visualize, PDM, Flow Sim, PhotoView 360.

### GPU Profile for SolidWorks (NVIDIA)

NVIDIA Control Panel > Program Settings > add `sldworks.exe`:
| Setting | Value |
|---|---|
| OpenGL rendering GPU | Your NVIDIA GPU |
| Power management | Prefer maximum performance |
| Threaded optimization | Off |
| V-Sync | Application-controlled |

### RealView on GeForce (registry hack)
```
HKCU\Software\SolidWorks\SOLIDWORKS <year>\Performance\Graphics\Hardware\Current
Gl2Shaders = DWORD 1
Gl2ShadersNoSWFallback = DWORD 1
```

### GDI Handle Limit (prevents "Resources Running Low")
```powershell
Set-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Windows" -Name GDIProcessHandleQuota -Value 16384
Set-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Windows" -Name USERProcessHandleQuota -Value 18000
```
Reboot required.

### File References
Tools > Options > File Locations > Referenced Documents: add root folder of assemblies. SolidWorks searches here first, skipping slow default search.

---

## DaVinci Resolve

### GPU Configuration
Preferences > System > Memory and GPU:
- GPU Processing Mode: CUDA (NVIDIA) or OpenCL (AMD)
- GPU Selection: Auto

### Memory
- Default (auto) or ~75% of RAM if crashing
- When running alongside other heavy apps, cap at 60% of total RAM

### Proxy Workflow (4K+)
- Media Pool > right-click > Generate Proxy Media
- Proxy Media Resolution: Quarter
- Proxy Media Format: DNxHR LB
- Proxy Generation Location: fastest SSD (not boot drive)

### Cache Location
Project Settings > Master Settings > Working Folders:
- Cache files: dedicated SSD/NVMe (not boot, not media drive)
- Render Cache: Smart, format DNxHR SQ

### Key Principle
Separate media read drive from cache write drive to avoid I/O contention.

---

## General Creative Workflow

### Drive Layout
| Drive | Contents |
|---|---|
| C: (NVMe boot) | OS, applications - keep 20%+ free |
| Media drive | Photos, raw video, final exports |
| Scratch NVMe | Resolve cache, render intermediates, SolidWorks temp |
| Project SSD | Active project files (timelines, assemblies) |

### RAM Budget (when running multiple heavy apps)

| Total RAM | Strategy |
|---|---|
| 16 GB | Don't run SolidWorks and Resolve simultaneously |
| 32 GB | Any two heavy apps. Cap Resolve at 60%. Node max-old-space 4096. |
| 64 GB | Run everything. Increase Fusion cache to 16 GB. |
