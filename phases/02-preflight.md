# Phase 02 - Pre-Flight (safety net)

**Script:** `scripts/02-preflight.ps1`

Nothing in later phases may run until this phase has produced a restore point AND a backup set.

## Steps

### 1. Baseline numbers
RAM used, C: free, startup entries, Automatic services, AppX count, program count -> `backup/<stamp>/baseline.txt`.

### 2. System Restore point
- `Enable-ComputerRestore -Drive C:\` (System Protection is OFF by default on many OEM images).
- Lift the 24-hour throttle: `SystemRestorePointCreationFrequency = 0`, otherwise `Checkpoint-Computer`
  silently does nothing if any point was created in the last 24 h.
- `Checkpoint-Computer -Description "PC-Optimizer pre-optimization <stamp>"`.
- The script verifies the point exists. If not it writes `backup/<stamp>/RESTORE-POINT-FAILED.txt`.
  **Stop and ask the user** before continuing on registry backups alone. Usual fix: Control Panel > System >
  System Protection > Configure > Turn on, give it 2-5 % of the drive.

### 3. Backup set (`backup/<stamp>/`)
Registry exports of every hive the framework touches (Services, Power, Policies, Run keys, StartupApproved,
Explorer, ContentDeliveryManager, GameBar/GameConfigStore, Multimedia profile, Tcpip interfaces,
GraphicsDrivers, Control Panel), plus CSV snapshots of services, startup, AppX (installed + provisioned),
scheduled tasks, programs, Defender exclusions, and the full `powercfg /query`. `README-UNDO.txt` explains to a
non-technical user how to use them (double-click a `.reg`, or System Restore).

### 4. Fast Startup off
`HiberbootEnabled = 0` (gotchas #9). On a **desktop** hibernate is also turned off (reclaims hiberfil.sys).
On a **laptop** hibernate stays on: it is what saves unsaved work when the battery dies.

### 5. SFC + DISM
`sfc /scannow`, then `DISM /ScanHealth`; only if corruption is reported, `DISM /RestoreHealth` and a second SFC.
15-45 minutes total. `-SkipScans` only when they were run very recently.

### 6. Network stack reset - OPT-IN
`-ResetNetwork` runs `netsh winsock reset` / `netsh int ip reset` / `ipconfig /flushdns`. It wipes static IPs,
custom DNS and VPN adapter settings (gotchas #26). Only for a user who actually has network problems.

## Notes

- SFC/DISM are safe on any machine. If DISM cannot repair (no internet, broken component store), note it in
  the checkpoint; the machine may need a repair install later, but the optimization can continue.
- Do not reboot here. Nothing in this phase needs it before the final reboot.
