# Phase 12 - Gaming and Network

**Script:** `scripts/12-gaming-network.ps1`
**Runs when:** `profile.workloads.gaming` (sim racing implies gaming).

Only evidence-backed, reversible tweaks. All registry keys are in the Phase 02 backup (`HKLM-Tcpip.reg`,
`HKLM-Multimedia.reg`, `HKCU-GameBar.reg`, `HKCU-ControlPanel.reg`).

## Applied by default

**Nagle's algorithm off** per active adapter (`TcpAckFrequency = 1`, `TCPNoDelay = 1`, `TcpDelAckTicks = 0`
under `Tcpip\Parameters\Interfaces\{GUID}`): measurably lower latency for small-packet online games.

**Network throttling off / MMCSS**: `NetworkThrottlingIndex = 0xffffffff`, `SystemResponsiveness = 10`
(default 20 = 20 % CPU reserved for background while a game runs).

**Game Mode ON, background Game DVR recording OFF** (also set in Phase 07).

## Opt-in (ask the user)

| Switch | What | Why ask |
|---|---|---|
| `-DisableMouseAccel` | "Enhance pointer precision" off | changes how the mouse feels; competitive players want it, others may hate it |
| `-DefenderExclusions` | Steam libraries (parsed from `libraryfolders.vdf`), Epic, GOG, EA, Ubisoft, Riot, Xbox games folders | excluded folders are not scanned in real time |
| `-Dns cloudflare` / `-Dns google` | DNS on all active adapters | the router's DNS is usually fine; some ISPs/parental controls depend on theirs |

## Manual (Phase 11)

GPU control panel, G-Sync/FreeSync, frame cap, refresh rate, per-game profiles - `phases/11-gpu-display.md`.

## Sim racing specifics

- USB selective suspend is already OFF (Phase 10) and wheel/pedal software is protected in startup (Phase 08).
- Force feedback, polling rate, LUTs: in the manufacturer software (Fanatec, Simucube, MOZA, Thrustmaster,
  Logitech G HUB), not in Windows.
- SimHub, Crew Chief, Content Manager: leave them in startup if the user has them there.

## Deliberately not here

Timer-resolution tools, IRQ priority, `Win32PrioritySeparation`, global "disable fullscreen optimizations",
"disable HPET", "disable Spectre mitigations": no reproducible gain on Windows 11, measurable risk, and the
per-game Compatibility tab exists for the rare title that needs fullscreen optimizations off.

## Procedure

```powershell
.\12-gaming-network.ps1 -Preview
.\12-gaming-network.ps1 [-DisableMouseAccel] [-DefenderExclusions] [-Dns cloudflare]
```
