# Phase 11 - GPU & Display Optimization

**Conditional:** Only when `profile.hasDedicatedGpu` is true.
**MANUAL** - GPU control panels are GUI-only. Walk the user through it, or do it with them at the keyboard.
Game Mode / Game DVR and HAGS are already handled by `07-privacy.ps1` and `10-performance.ps1`; what remains
here is the vendor control panel, VRR + frame cap, and refresh rate. For a laptop with hybrid graphics, set
"Prefer maximum performance" per game, not globally (battery + heat).

---

## NVIDIA

### Control Panel Global 3D Settings

Open NVIDIA Control Panel > Manage 3D Settings > Global Settings:

| Setting | Value | Notes |
|---|---|---|
| Power Management Mode | Prefer Maximum Performance | Prevents GPU downclocking |
| Texture Filtering Quality | High Performance | Slight visual tradeoff for FPS |
| Texture Filtering - Trilinear Optimization | On | Negligible visual impact |
| Texture Filtering - Anisotropic Sample Optimization | On | Same |
| Threaded Optimization | On | Turn Off if anti-cheat crashes |
| Low Latency Mode | On | Ultra only when GPU-bound and no Reflex |
| V-Sync | Off (no VRR) / On (with G-Sync) | See VRR section |
| Shader Cache Size | Unlimited | Eliminates shader compilation stutters |
| Max Frame Rate | Off (global) | Set per-app instead |
| Triple Buffering | Off | Only relevant to OpenGL |
| Preferred Refresh Rate | Highest available | |

### Per-Application Profiles

| Workload | Overrides |
|---|---|
| Competitive gaming | Low Latency: Ultra, Max FPS: monitor Hz - 3, Power: Max |
| AAA gaming | Low Latency: On, Texture: Quality, AF: 16x, Power: Max |
| CAD (SolidWorks) | Power: Optimal, Threaded: Off, V-Sync: App-controlled |
| Video editing (Resolve) | Power: Max, Threaded: On, Shader Cache: Unlimited |

### NVIDIA Profile Inspector (advanced)

Download from github.com/Orbmu2k/nvidiaProfileInspector. Provides:
- Frame Rate Limiter v2 (sub-ms precision)
- Pre-rendered frames per-profile
- Texture LOD bias
- DLSS version override
- Export profiles before driver updates (they can be overwritten)

### NVIDIA Reflex vs Low Latency Mode

- **Reflex** (in-game): engine-level, up to 50% latency reduction. Use when available.
- **Low Latency Mode** (driver): 10-20ms reduction. Fallback for games without Reflex.
- If Reflex is active, it overrides Low Latency Mode.

---

## AMD

### Adrenalin Edition Settings

Open AMD Software > Gaming > Graphics:

| Setting | Value | Notes |
|---|---|---|
| Radeon Anti-Lag | Enabled | Reduces input-to-display latency |
| Radeon Anti-Lag+ | Enabled (RDNA 3+) | Per-frame algorithm, superior to standard |
| Radeon Boost | Off (competitive) / On (casual) | Lowers resolution during fast movement |
| Radeon Chill | Off | Dynamic FPS cap, bad for competitive |
| V-Sync | Off (with FreeSync) / Enhanced Sync (without) | |
| Texture Filtering Quality | Performance | Standard for creative work |
| Surface Format Optimization | Enabled | Reduces VRAM bandwidth |

### Smart Access Memory (SAM) / Resizable BAR

Enable in BIOS: "Above 4G Decoding" + "Re-Size BAR Support".
Requirements: Ryzen 5000+ / Intel 10th Gen+, RDNA 2+ / RTX 30+.
Typical gain: 3-7%. Leave on globally, disable per-game if issues.

---

## Display Settings

### Refresh Rate
```
Settings > System > Display > Advanced display > Choose highest refresh rate
```
Verify:
```powershell
Get-CimInstance Win32_VideoController | Select-Object CurrentRefreshRate
```

### G-Sync / FreeSync
- NVIDIA: NVCP > Display > Set up G-SYNC > Enable for windowed and fullscreen
- AMD: Adrenalin > Gaming > Display > AMD FreeSync On

### The VRR + Frame Limiter Recipe (optimal)

1. G-Sync/FreeSync: **On**
2. V-Sync (driver level): **On** (safety net, never activates with cap below)
3. Low Latency / Anti-Lag: **On**
4. Frame cap: **Monitor Hz minus 3** (e.g., 141 for 144Hz, 237 for 240Hz)

Cap keeps you inside VRR range. V-Sync never activates -> zero latency penalty.

### Where to set frame cap (preference order)
1. NVIDIA Reflex (tightest pacing)
2. NVIDIA Control Panel / AMD FRTC (driver-level, sub-ms precision)
3. RTSS / RivaTuner (universal, adds ~1 frame latency)
4. In-game limiter (quality varies)

---

## Game Mode

**Gaming machine (dedicated GPU + games installed):** Game Mode **ON**
```
Settings > Gaming > Game Mode > ON
```
Registers foreground game threads with MMCSS for priority scheduling. Real benefits in borderless windowed mode.

**Non-gaming machine:** Game Mode **OFF**
```powershell
Set-ItemProperty 'HKCU:\Software\Microsoft\GameBar' -Name AutoGameModeEnabled -Value 0
```

## Game Bar - Disable

Adds overhead, conflicts with other overlays:
```
Settings > Gaming > Game Bar > OFF
```

## Fullscreen Optimizations - Disable for Competitive Games

**Per-exe (GUI):** Right-click .exe > Properties > Compatibility > "Disable fullscreen optimizations"

**Globally (registry):**
```powershell
Set-ItemProperty 'HKCU:\System\GameConfigStore' -Name GameDVR_FSEBehaviorMode -Value 2 -Type DWord
Set-ItemProperty 'HKCU:\System\GameConfigStore' -Name GameDVR_HonorUserFSEBehaviorMode -Value 1 -Type DWord
Set-ItemProperty 'HKCU:\System\GameConfigStore' -Name GameDVR_DXGIHonorFSEWindowsCompatible -Value 1 -Type DWord
Set-ItemProperty 'HKCU:\System\GameConfigStore' -Name GameDVR_EFSEFeatureFlags -Value 0 -Type DWord
```

## Game DVR Background Recording - Disable
```
Settings > Gaming > Captures > toggle off "Record what happened"
```

## IRQ Priority for GPU - Not Recommended

Modern GPUs use MSI-X by default. IRQ priority tweaks were relevant on Windows 7/8 but provide no measurable benefit on modern systems and risk instability. Skip this.
