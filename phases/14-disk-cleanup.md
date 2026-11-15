# Phase 14 - Disk Cleanup

**Script:** `scripts/14-disk-cleanup.ps1`

Clears genuine junk by default. Anything that removes a safety net or user data is a switch Claude only uses
after asking. Disk space is rarely the user's problem; do not chase gigabytes at the cost of a rollback.

## Default (safe)

| What | Guard |
|---|---|
| User TEMP (all profiles) + `C:\Windows\Temp` | skips `*\Temp\claude\*` (Claude Code's live task pipe, gotchas #19) and anything modified in the last 24 h (installers in progress) |
| Windows Update download cache | service stopped/started around it |
| Delivery Optimization cache | `Delete-DeliveryOptimizationCache` |
| WER report queues, old CBS/DISM logs, minidumps, MEMORY.DMP | logs older than 24 h only |
| GPU installer leftovers (`C:\NVIDIA`, `C:\AMD`, NVIDIA Downloader) | |
| `DISM /StartComponentCleanup` (without `/ResetBase`) | superseded components go, update uninstall still works |
| Storage Sense ON, monthly, temp files only | explicitly configured NOT to empty the Recycle Bin or touch Downloads |

Never cleared: `Prefetch` (SysMain's data - hurts low-RAM machines), shader caches (they rebuild with stutter),
user folders, Downloads.

## Opt-in (ask)

| Switch | Removes | Cost |
|---|---|---|
| `-EmptyRecycleBin` | Recycle Bin on all drives | users recover files from it |
| `-RemoveWindowsOld` | `C:\Windows.old` (10-30 GB) | rollback of a recent feature update; Windows deletes it itself after 10 days |
| `-ResetBase` | `DISM /ResetBase` | installed updates can no longer be uninstalled |
| `-BrowserCaches` | Chrome / Edge / Brave / Firefox caches (1-5 GB) | first visits slower; browsers must be closed |

## Expected savings

Temp 0.5-5 GB, WU cache 1-8 GB, WinSxS 1-5 GB, hiberfil (desktops, Phase 02) 4-48 GB, OEM bloat folders
(Phase 04) 1-5 GB. A healthy machine often only yields 1-3 GB here - that is fine.

## Stage 2 - what is actually using the disk (read-only, for the user)

```powershell
Get-Volume | Where-Object DriveLetter | Select-Object DriveLetter, FileSystemLabel,
    @{N='FreeGB';E={[math]::Round($_.SizeRemaining/1GB,1)}}, @{N='SizeGB';E={[math]::Round($_.Size/1GB,1)}} | Out-String
# biggest folders under the user profile
Get-ChildItem $env:USERPROFILE -Directory -Force | ForEach-Object {
    [pscustomobject]@{ Folder=$_.Name; GB=[math]::Round((Get-ChildItem $_.FullName -Recurse -File -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum/1GB,1) }
} | Sort-Object GB -Descending | Select-Object -First 12 | Out-String
# biggest files on C:
Get-ChildItem C:\ -Recurse -File -ErrorAction SilentlyContinue | Sort-Object Length -Descending |
    Select-Object -First 20 @{N='GB';E={[math]::Round($_.Length/1GB,2)}}, FullName | Out-String
```

Show the user the result and let THEM decide what to move or delete (game libraries to a second drive,
old video exports, duplicate installers). Steam > Settings > Storage moves games between drives safely.
