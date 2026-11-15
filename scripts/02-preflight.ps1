# 02-preflight.ps1
# Phase 02 - Safety net BEFORE any change: restore point, full backup set, Fast Startup off,
# SFC + DISM health check. Nothing here is destructive.
#
#   .\02-preflight.ps1                 normal run
#   .\02-preflight.ps1 -SkipScans      skip SFC/DISM (only when they were run recently)
#   .\02-preflight.ps1 -ResetNetwork   ALSO reset Winsock/TCP-IP (wipes static IP / custom DNS - ask first)
#
# If the restore point cannot be created the script writes backup\RESTORE-POINT-FAILED.txt
# and the operator must decide (with the user) whether to continue on the .reg backups alone.

param([switch]$SkipScans, [switch]$ResetNetwork)
. "$PSScriptRoot\_common.ps1"
Assert-Admin
Start-PhaseLog '02-preflight'
Write-Head "PHASE 02: PRE-FLIGHT"
$p = Get-OptProfile
$stamp = Get-Date -Format 'yyyyMMdd-HHmm'
$bk = Join-Path $BackupDir $stamp
New-Item -ItemType Directory -Path $bk -Force | Out-Null

# ---------------------------------------------------------------- 1. baseline
$ram = Get-RamGB
$baseline = @"
BASELINE $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
RAM used at idle : $($ram.UsedGB) GB / $($ram.TotalGB) GB
C: free          : $([math]::Round((Get-PSDrive C).Free/1GB,1)) GB
Startup entries  : $((Get-CimInstance Win32_StartupCommand | Measure-Object).Count)
Automatic svcs   : $((Get-Service | Where-Object { $_.StartType -eq 'Automatic' } | Measure-Object).Count)
AppX (all users) : $((Get-AppxPackage -AllUsers | Measure-Object).Count)
Programs         : $((Get-InstalledPrograms | Measure-Object).Count)
"@
$baseline | Out-File (Join-Path $bk 'baseline.txt') -Encoding ascii
Write-Host $baseline

# ---------------------------------------------------------------- 2. restore point
Write-Info "Enabling System Restore on C: and creating a restore point..."
try { Enable-ComputerRestore -Drive 'C:\' -ErrorAction Stop } catch { Write-Warn "Enable-ComputerRestore: $($_.Exception.Message)" }
# Windows silently skips restore points created within 24h of the last one; lift that throttle.
Set-Reg 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore' 'SystemRestorePointCreationFrequency' 0
$rpOk = $false
try {
    Checkpoint-Computer -Description "PC-Optimizer pre-optimization $stamp" -RestorePointType MODIFY_SETTINGS -ErrorAction Stop
    $rp = Get-ComputerRestorePoint -ErrorAction SilentlyContinue | Sort-Object SequenceNumber -Descending | Select-Object -First 1
    if ($rp -and $rp.Description -like "PC-Optimizer pre-optimization*") { $rpOk = $true }
} catch { Write-Warn "Checkpoint-Computer: $($_.Exception.Message)" }
if ($rpOk) { Write-Ok "Restore point created: $($rp.Description) (#$($rp.SequenceNumber))" }
else {
    Write-Fail "RESTORE POINT NOT CREATED. Check Control Panel > System Protection (C: must have protection ON and some disk space allotted)."
    "Restore point creation failed at $(Get-Date). Decide with the user before continuing." | Out-File (Join-Path $bk 'RESTORE-POINT-FAILED.txt') -Encoding ascii
}
Get-ComputerRestorePoint -ErrorAction SilentlyContinue | Select-Object SequenceNumber, Description, @{N='Created';E={$_.ConvertToDateTime($_.CreationTime)}} | Out-Table

# ---------------------------------------------------------------- 3. backup set
Write-Info "Exporting registry hives and state snapshots to $bk ..."
$exports = @{
    'HKLM-Services.reg'    = 'HKLM\SYSTEM\CurrentControlSet\Services'
    'HKLM-Power.reg'       = 'HKLM\SYSTEM\CurrentControlSet\Control\Power'
    'HKLM-Policies.reg'    = 'HKLM\SOFTWARE\Policies'
    'HKLM-Run.reg'         = 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Run'
    'HKLM-Multimedia.reg'  = 'HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia'
    'HKLM-Tcpip.reg'       = 'HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters'
    'HKLM-Graphics.reg'    = 'HKLM\SYSTEM\CurrentControlSet\Control\GraphicsDrivers'
    'HKCU-Run.reg'         = 'HKCU\Software\Microsoft\Windows\CurrentVersion\Run'
    'HKCU-StartupApproved.reg' = 'HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved'
    'HKCU-Explorer.reg'    = 'HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer'
    'HKCU-ContentDelivery.reg' = 'HKCU\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'
    'HKCU-GameBar.reg'     = 'HKCU\Software\Microsoft\GameBar'
    'HKCU-GameConfigStore.reg' = 'HKCU\System\GameConfigStore'
    'HKCU-ControlPanel.reg' = 'HKCU\Control Panel'
}
foreach ($f in $exports.Keys) { reg export $exports[$f] (Join-Path $bk $f) /y 2>&1 | Out-Null }
Get-CimInstance Win32_StartupCommand | Select-Object Name,User,Location,Command | Export-Csv (Join-Path $bk 'startup-before.csv') -NoTypeInformation
Get-Service | Select-Object Name,DisplayName,Status,StartType | Export-Csv (Join-Path $bk 'services-before.csv') -NoTypeInformation
Get-AppxPackage -AllUsers | Select-Object Name,PackageFullName,Version | Export-Csv (Join-Path $bk 'appx-before.csv') -NoTypeInformation
Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Select-Object DisplayName,PackageName | Export-Csv (Join-Path $bk 'appx-provisioned-before.csv') -NoTypeInformation
Get-ScheduledTask | Select-Object TaskName,TaskPath,State | Export-Csv (Join-Path $bk 'tasks-before.csv') -NoTypeInformation
Get-InstalledPrograms | Export-Csv (Join-Path $bk 'programs-before.csv') -NoTypeInformation
Get-MpPreference -ErrorAction SilentlyContinue | Select-Object ExclusionPath, ExclusionProcess, ExclusionExtension | ConvertTo-Json | Out-File (Join-Path $bk 'defender-exclusions-before.json') -Encoding ascii
powercfg /getactivescheme | Out-File (Join-Path $bk 'powerscheme-before.txt') -Encoding ascii
powercfg /query 2>&1 | Out-File (Join-Path $bk 'powercfg-query-before.txt') -Encoding ascii
Get-ChildItem $bk | Select-Object Name, @{N='KB';E={[math]::Round($_.Length/1KB,0)}} | Out-Table
Write-Ok "Backup set written. To undo a registry change later: double-click the matching .reg file."
@"
HOW TO UNDO
- Registry: double-click any .reg file in this folder to restore that key as it was before the optimization.
- Everything else: Control Panel > Recovery > Open System Restore > choose "PC-Optimizer pre-optimization $stamp".
- services-before.csv / startup-before.csv / appx-before.csv show exactly what was present before.
"@ | Out-File (Join-Path $bk 'README-UNDO.txt') -Encoding ascii

# ---------------------------------------------------------------- 4. fast startup
Write-Info "Disabling Fast Startup (Hybrid Boot) - gotchas.md #9"
Set-Reg 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power' 'HiberbootEnabled' 0
if ($p.isLaptop) {
    Write-Ok "Fast Startup OFF. Hibernate left ON (laptop: hibernate protects unsaved work when the battery dies)."
} else {
    powercfg /hibernate off | Out-Null
    Write-Ok "Fast Startup OFF and hibernate OFF (desktop: reclaims hiberfil.sys)."
}

# ---------------------------------------------------------------- 5. SFC / DISM
if ($SkipScans) { Write-Skip "SFC/DISM skipped by request." }
else {
    Write-Info "SFC /scannow (5-15 min)..."
    sfc /scannow
    Write-Info "DISM /ScanHealth (5-10 min)..."
    $scan = DISM /Online /Cleanup-Image /ScanHealth
    $scan | Select-Object -Last 4
    if (($scan -join "`n") -match 'repairable|corrupt') {
        Write-Warn "Component store corruption found - running DISM /RestoreHealth (10-30 min, needs internet)..."
        DISM /Online /Cleanup-Image /RestoreHealth | Select-Object -Last 4
        Write-Info "Re-running SFC after RestoreHealth..."
        sfc /scannow | Select-Object -Last 3
    } else { Write-Ok "Component store healthy." }
}

# ---------------------------------------------------------------- 6. network reset (opt-in)
if ($ResetNetwork) {
    Write-Warn "Resetting Winsock / TCP-IP / DNS cache (static IPs and custom DNS will be lost)..."
    netsh winsock reset | Out-Null; netsh int ip reset | Out-Null; ipconfig /flushdns | Out-Null
    Write-Ok "Network stack reset (takes effect after the final reboot)."
} else { Write-Skip "Network stack reset not requested (-ResetNetwork). Only do this if the user has network problems." }

Write-Host ""
Write-Ok "PRE-FLIGHT COMPLETE. Backup folder: $bk"
if (-not $rpOk) { Write-Fail "Remember: no restore point exists. Ask the user before making changes." }
Stop-PhaseLog
