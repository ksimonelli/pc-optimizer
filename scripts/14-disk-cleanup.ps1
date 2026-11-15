# 14-disk-cleanup.ps1
# Phase 14 - Disk cleanup. Clears only genuine junk by default; anything that removes a
# safety net (update rollback, Windows.old, Recycle Bin contents) is opt-in.
#
#   .\14-disk-cleanup.ps1                    temp (guarded), WU cache, DO cache, WER dumps, old logs,
#                                            NVIDIA installer leftovers, DISM StartComponentCleanup
#   .\14-disk-cleanup.ps1 -EmptyRecycleBin   also empty the Recycle Bin (ask - users restore from it)
#   .\14-disk-cleanup.ps1 -RemoveWindowsOld  also delete C:\Windows.old (ask - kills the feature-update rollback)
#   .\14-disk-cleanup.ps1 -ResetBase         DISM /ResetBase (installed updates can no longer be uninstalled)
#   .\14-disk-cleanup.ps1 -BrowserCaches     also clear Chrome/Edge/Firefox caches (browsers must be closed)
#
# Guards (gotchas.md #19): never touches *\Temp\claude\* (Claude Code's live task pipe), skips temp
# files modified in the last 24 h (installers in progress), never clears Prefetch (hurts low-RAM boxes).

param([switch]$EmptyRecycleBin, [switch]$RemoveWindowsOld, [switch]$ResetBase, [switch]$BrowserCaches)
. "$PSScriptRoot\_common.ps1"
Assert-Admin
Start-PhaseLog '14-disk-cleanup'
Write-Head "PHASE 14: DISK CLEANUP"
$before = [math]::Round((Get-PSDrive C).Free/1GB, 2)
$cutoff = (Get-Date).AddHours(-24)

function Clear-Folder($path, $label) {
    if (-not (Test-Path $path)) { return }
    $items = Get-ChildItem $path -Force -Recurse -ErrorAction SilentlyContinue |
             Where-Object { $_.FullName -notmatch '\\Temp\\claude\\' -and $_.LastWriteTime -lt $cutoff }
    $mb = [math]::Round((($items | Where-Object { -not $_.PSIsContainer } | Measure-Object Length -Sum).Sum)/1MB, 0)
    $items | Where-Object { -not $_.PSIsContainer } | Remove-Item -Force -ErrorAction SilentlyContinue
    $items | Where-Object { $_.PSIsContainer } | Sort-Object { $_.FullName.Length } -Descending | ForEach-Object {
        if ($_.FullName -notmatch '\\Temp\\claude') { Remove-Item $_.FullName -Force -Recurse -ErrorAction SilentlyContinue }
    }
    Write-Ok "$label : ~$mb MB"
}

Write-Info "[1] Temp folders (files older than 24 h, Claude Code temp excluded)"
Clear-Folder $env:TEMP 'User TEMP'
Clear-Folder "$env:SystemRoot\Temp" 'Windows Temp'
foreach ($u in (Get-ChildItem 'C:\Users' -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -notin 'Public','Default','All Users' -and $_.Name -ne $env:USERNAME })) {
    Clear-Folder (Join-Path $u.FullName 'AppData\Local\Temp') "TEMP of $($u.Name)"
}

Write-Info "[2] Windows Update download cache"
Stop-Service wuauserv -Force -ErrorAction SilentlyContinue; Start-Sleep 2
$wu = "$env:SystemRoot\SoftwareDistribution\Download"
$mb = [math]::Round(((Get-ChildItem $wu -Recurse -File -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum)/1MB, 0)
Remove-Item "$wu\*" -Recurse -Force -ErrorAction SilentlyContinue
Start-Service wuauserv -ErrorAction SilentlyContinue
Write-Ok "Windows Update cache: ~$mb MB"

Write-Info "[3] Delivery Optimization cache"
try { Delete-DeliveryOptimizationCache -Force -ErrorAction Stop; Write-Ok "DO cache cleared" } catch { Write-Skip "DO cache: $($_.Exception.Message.Split("`n")[0])" }

Write-Info "[4] Error-report queues, old CBS/DISM logs, crash dumps"
foreach ($d in @("$env:ProgramData\Microsoft\Windows\WER\ReportQueue","$env:ProgramData\Microsoft\Windows\WER\ReportArchive","$env:LOCALAPPDATA\Microsoft\Windows\WER\ReportQueue","$env:SystemRoot\Minidump","$env:SystemRoot\LiveKernelReports")) {
    if (Test-Path $d) { Get-ChildItem $d -Recurse -Force -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue }
}
Get-ChildItem "$env:SystemRoot\Logs\CBS" -Filter '*.log' -ErrorAction SilentlyContinue | Where-Object { $_.LastWriteTime -lt $cutoff } | Remove-Item -Force -ErrorAction SilentlyContinue
Get-ChildItem "$env:SystemRoot\Logs\DISM" -Filter '*.log' -ErrorAction SilentlyContinue | Where-Object { $_.LastWriteTime -lt $cutoff } | Remove-Item -Force -ErrorAction SilentlyContinue
if (Test-Path "$env:SystemRoot\MEMORY.DMP") { Remove-Item "$env:SystemRoot\MEMORY.DMP" -Force -ErrorAction SilentlyContinue }
Write-Ok "WER / logs / dumps cleared"

Write-Info "[5] GPU installer leftovers"
foreach ($d in @('C:\NVIDIA','C:\AMD',"$env:ProgramData\NVIDIA Corporation\Downloader")) { if (Test-Path $d) { Remove-Item $d -Recurse -Force -ErrorAction SilentlyContinue; Write-Ok "removed $d" } }

if ($BrowserCaches) {
    Write-Info "[6] Browser caches"
    $caches = @("$env:LOCALAPPDATA\Google\Chrome\User Data\*\Cache","$env:LOCALAPPDATA\Google\Chrome\User Data\*\Code Cache",
                "$env:LOCALAPPDATA\Microsoft\Edge\User Data\*\Cache","$env:LOCALAPPDATA\Microsoft\Edge\User Data\*\Code Cache",
                "$env:LOCALAPPDATA\BraveSoftware\Brave-Browser\User Data\*\Cache","$env:LOCALAPPDATA\Mozilla\Firefox\Profiles\*\cache2")
    foreach ($c in $caches) { Get-ChildItem $c -Recurse -Force -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue }
    Write-Ok "browser caches cleared (locked files skipped if a browser was open)"
} else { Write-Skip "[6] Browser caches kept (-BrowserCaches; 1-5 GB but they rebuild and slow the first visits)" }

if ($EmptyRecycleBin) { Clear-RecycleBin -Force -ErrorAction SilentlyContinue; Write-Ok "[7] Recycle Bin emptied" } else { Write-Skip "[7] Recycle Bin kept (-EmptyRecycleBin after asking)" }

if (Test-Path 'C:\Windows.old') {
    $gb = [math]::Round(((Get-ChildItem 'C:\Windows.old' -Recurse -File -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum)/1GB, 1)
    if ($RemoveWindowsOld) {
        Write-Info "[8] Removing C:\Windows.old (~$gb GB)..."
        takeown /f 'C:\Windows.old' /r /d y 2>&1 | Out-Null; icacls 'C:\Windows.old' /grant administrators:F /t 2>&1 | Out-Null
        Remove-Item 'C:\Windows.old' -Recurse -Force -ErrorAction SilentlyContinue
        if (Test-Path 'C:\Windows.old') { Write-Warn "could not fully remove - use Settings > System > Storage > Temporary files > Previous Windows installation" } else { Write-Ok "Windows.old removed" }
    } else { Write-Skip "[8] C:\Windows.old present (~$gb GB). It is the rollback for a recent feature update; -RemoveWindowsOld after asking (Windows deletes it itself after 10 days)." }
}

Write-Info "[9] DISM component store cleanup (5-20 min)$(if ($ResetBase) { ' with /ResetBase' })"
$args = @('/Online','/Cleanup-Image','/StartComponentCleanup'); if ($ResetBase) { $args += '/ResetBase' }
& DISM @args | Select-String -Pattern 'complete|error|Error' | Select-Object -Last 2
Write-Ok "component store cleanup done"

Write-Info "[10] Storage Sense ON (automatic temp cleanup every month; does not touch Downloads)"
Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\StorageSense\Parameters\StoragePolicy' '01' 1
Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\StorageSense\Parameters\StoragePolicy' '2048' 30     # run monthly
Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\StorageSense\Parameters\StoragePolicy' '04' 1        # temp files
Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\StorageSense\Parameters\StoragePolicy' '08' 0        # do NOT auto-empty Recycle Bin
Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\StorageSense\Parameters\StoragePolicy' '32' 0        # do NOT touch Downloads

$after = [math]::Round((Get-PSDrive C).Free/1GB, 2)
Write-Host ""
Write-Ok ("C: free {0} GB -> {1} GB (reclaimed {2} GB)" -f $before, $after, [math]::Round($after - $before, 2))
Write-Host "Largest folders / files are a user decision - see phases/14-disk-cleanup.md Stage 2 for the audit commands."
Stop-PhaseLog
