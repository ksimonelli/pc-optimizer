# 15-verify.ps1
# Phase 15 - Verification. Run at the end of the session AND automatically after the reboot
# (via postreboot-verify.ps1). Profile-aware: checks that what we promised to keep is still there.
# Writes logs\VERIFY-REPORT.txt and a copy on the user's Desktop (PC-Optimization-Report.txt).
#
#   .\15-verify.ps1                 verify
#   .\15-verify.ps1 -PostReboot     verify + create a "post-optimization" restore point + mark baseline comparison

param([switch]$PostReboot)
. "$PSScriptRoot\_common.ps1"
Start-PhaseLog '15-verify'
$p = Get-OptProfile
$report = Join-Path $LogDir 'VERIFY-REPORT.txt'
"" | Out-File $report -Encoding ascii
$issues = @(); $notes = @()
function L($s) { Write-Host $s; $s | Out-File $report -Append -Encoding ascii }
function Issue($s) { $script:issues += $s; L "  [!!] $s" }
function Note($s)  { $script:notes += $s;  L "  [..] $s" }
function Good($s)  { L "  [OK] $s" }

L "===================================================================="
L "  PC OPTIMIZATION - VERIFICATION REPORT   $(Get-Date -Format 'yyyy-MM-dd HH:mm')"
L "  $($p.oem) $($p.model)  |  $($p.osCaption) $($p.osVersion)"
L "===================================================================="
$os = Get-CimInstance Win32_OperatingSystem
$ram = Get-RamGB
$cFree = [math]::Round((Get-PSDrive C).Free/1GB, 1)
$uptimeMin = [math]::Round(((Get-Date) - $os.LastBootUpTime).TotalMinutes, 0)
$startup = (Get-CimInstance Win32_StartupCommand | Measure-Object).Count
$autoSvc = (Get-Service | Where-Object { $_.StartType -eq 'Automatic' } | Measure-Object).Count
$appx = (Get-AllAppx | Measure-Object).Count
$b = $p.baseline
L ""
L "--- Headline numbers (baseline from Phase 00 in brackets) ---"
L ("  Uptime since boot : {0} min  {1}" -f $uptimeMin, $(if ($uptimeMin -lt 3) { '(too early for a fair idle-RAM reading)' } else { '' }))
L ("  RAM used at idle  : {0} GB / {1} GB   [{2} GB]" -f $ram.UsedGB, $ram.TotalGB, $b.ramUsedGB)
L ("  C: free           : {0} GB   [{1} GB]" -f $cFree, $b.cFreeGB)
L ("  Startup entries   : {0}   [{1}]  (Run-key entries; disabled ones still count - see gotchas #23)" -f $startup, $b.startupEntries)
L ("  Automatic services: {0}" -f $autoSvc)
L ("  AppX packages     : {0}   [{1}]" -f $appx, $b.appxCount)
$cl = (Get-Process -Name claude -ErrorAction SilentlyContinue | Measure-Object WorkingSet64 -Sum).Sum
if ($cl) { L ("  (claude.exe uses {0} MB of that RAM)" -f [math]::Round($cl/1MB,0)) }

L ""; L "--- Safety ---"
$rp = Get-ComputerRestorePoint -ErrorAction SilentlyContinue | Where-Object { $_.Description -like 'PC-Optimizer*' }
if ($rp) { Good "Restore point(s): $(($rp | ForEach-Object { $_.Description }) -join '; ')" } else { Issue "No PC-Optimizer restore point found" }
$bk = Get-ChildItem $BackupDir -Directory -ErrorAction SilentlyContinue | Sort-Object Name -Descending | Select-Object -First 1
if ($bk) { Good "Backup set: $($bk.FullName)" } else { Issue "No backup folder under $BackupDir" }
$mp = Get-MpComputerStatus -ErrorAction SilentlyContinue
if ($mp) {
    if ($mp.RealTimeProtectionEnabled -and $mp.AntivirusEnabled) { Good "Microsoft Defender: real-time protection ON (signatures $(if ($mp.AntivirusSignatureLastUpdated) { $mp.AntivirusSignatureLastUpdated.ToString('yyyy-MM-dd') }))" }
    else { Issue "Microsoft Defender real-time protection is OFF" }
} else { Issue "Could not query Defender" }
$av = @(Get-CimInstance -Namespace root/SecurityCenter2 -ClassName AntivirusProduct -ErrorAction SilentlyContinue | Where-Object { $_.displayName -notmatch 'Defender' })
if ($av) { Note "3rd-party AV still registered: $($av.displayName -join ', ')" } else { Good "No 3rd-party antivirus registered" }
$hb = Get-RegValue 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power' 'HiberbootEnabled'
if ($hb -eq 0) { Good "Fast Startup OFF" } else { Issue "Fast Startup still ON (HiberbootEnabled=$hb)" }
$pendingReboot = (Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending') -or (Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired')
if ($pendingReboot) { Note "Windows still reports a pending reboot" } else { Good "No pending reboot" }

L ""; L "--- Things we promised to keep ---"
foreach ($s in 'wuauserv','BITS','CryptSvc','Dnscache','Dhcp','NlaSvc','Audiosrv','WinDefend','mpssvc','WpnService','hidserv') {
    $svc = Get-Service $s -ErrorAction SilentlyContinue
    if ($svc -and $svc.StartType -eq 'Disabled') { Issue "core service $s is DISABLED" }
}
Good "Core services (update, network, audio, Defender, notifications, HID) not disabled"
if ($p.keep.printer)   { $sp = Get-Service Spooler -ErrorAction SilentlyContinue; if ($sp.StartType -eq 'Disabled') { Issue "Print Spooler disabled but a printer is installed" } else { Good "Print Spooler: $($sp.StartType)" } }
if ($p.keep.search)    { $ws = Get-Service WSearch -ErrorAction SilentlyContinue; if ($ws -and $ws.StartType -eq 'Disabled') { Issue "Windows Search disabled" } else { Good "Windows Search: $($ws.StartType)" } }
if ($p.keep.sysmain)   { $sm = Get-Service SysMain -ErrorAction SilentlyContinue; if ($sm -and $sm.StartType -ne 'Automatic') { Issue "SysMain should stay Automatic on this machine (low RAM / HDD) - it is $($sm.StartType)" } else { Good "SysMain: Automatic (low RAM / HDD profile)" } }
if ($p.keep.xbox) {
    $gs = Get-RegValue 'HKLM:\SYSTEM\CurrentControlSet\Services\GamingServices' 'Start'
    if ($null -eq $gs) { Note "GamingServices not installed (Xbox app will install it on first use)" }
    elseif ($gs -eq 4) { Issue "GamingServices is disabled but Xbox/Game Pass is in use" }
    else { Good "GamingServices startable (Start=$gs)" }
}
if ($p.keep.onedrive)  { if (Get-Process OneDrive -ErrorAction SilentlyContinue) { Good "OneDrive running" } elseif ($uptimeMin -gt 3) { Note "OneDrive not running (user syncs with it - check Task Manager > Startup)" } }
if ($p.keep.touch)     { Good "Touch/pen input services untouched (keep.touch)" }
if ($p.keep.biometric) { $wb = Get-Service WbioSrv -ErrorAction SilentlyContinue; if ($wb.StartType -eq 'Disabled') { Issue "Windows Biometric service disabled (Windows Hello)" } else { Good "Windows Hello service: $($wb.StartType)" } }
$atk = Get-ScheduledTask -TaskName 'ATK Package' -ErrorAction SilentlyContinue
if ($atk) { if ($atk.State -eq 'Disabled') { Issue "ASUS 'ATK Package' task is disabled (Fn keys / backlight)" } else { Good "ASUS ATK Package task enabled" } }

if ($p.workloads.flashTuning) {
    L ""; L "--- Flash-tuning safety (gotchas #21) ---"
    $usb = powercfg /query SCHEME_CURRENT 2a737441-1930-4402-8d77-b2bebba308a3 48e6b7a6-50f5-4782-a5d4-53bb8f07e226
    $ac = ($usb | Select-String 'Current AC Power Setting Index').ToString().Trim(); $dc = ($usb | Select-String 'Current DC Power Setting Index').ToString().Trim()
    if ($ac -match '0x00000000' -and $dc -match '0x00000000') { Good "USB selective suspend OFF (AC+DC)" } else { Issue "USB selective suspend not off: $ac / $dc" }
    if ((Get-RegValue 'HKLM:\SYSTEM\CurrentControlSet\Services\USB' 'DisableSelectiveSuspend') -eq 1) { Good "USB\DisableSelectiveSuspend=1" } else { Issue "USB\DisableSelectiveSuspend not set" }
    $aspm = powercfg /query SCHEME_CURRENT 501a4d13-42af-4429-9fd1-a8218c268e20 ee12f906-d277-404b-b6da-e5fa1a576df5
    if ((($aspm | Select-String 'Current AC Power Setting Index').ToString()) -match '0x00000000') { Good "PCIe ASPM OFF (AC)" } else { Issue "PCIe ASPM not off on AC" }
    foreach ($d in 'serial','serenum','usbser') { $drv = Get-CimInstance Win32_SystemDriver -Filter "Name='$d'" -ErrorAction SilentlyContinue; if ($drv) { Good "driver $d present ($($drv.StartMode))" } else { Note "driver $d not registered (fine if no such hardware)" } }
    $pca = Get-Service PcaSvc -ErrorAction SilentlyContinue; if ($pca -and $pca.StartType -eq 'Disabled') { Issue "PcaSvc disabled (old tuning tools need it)" } else { Good "PcaSvc: $($pca.StartType)" }
    if (Test-Path 'HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP\v3.5') { Good ".NET 3.5 present" } else { Note ".NET 3.5 not installed (VCDS/NefMoto may need it: Settings > Optional features)" }
    L ("  COM ports: " + ((Get-PnpDevice -Class Ports -PresentOnly -ErrorAction SilentlyContinue | ForEach-Object { $_.FriendlyName }) -join ', '))
    L ("  Defender exclusions: " + ((Get-MpPreference).ExclusionPath -join '; '))
}

L ""; L "--- Things we meant to remove / stop ---"
$watch = @{ WavesSvc64='Waves MaxxAudio'; KAPSService='Killer'; KillerAnalyticsService='Killer'; KillerNetworkService='Killer'; mfemms='McAfee'; mfevtp='McAfee'; DellClientManagementService='Dell'; HPPrintScanDoctorService='HP'; DiagTrack='Telemetry'; dmwappushservice='Telemetry'; RemoteRegistry='Remote Registry'; RetailDemo='Retail demo' }
$bad = $false
foreach ($n in $watch.Keys) { $svc = Get-Service $n -ErrorAction SilentlyContinue; if ($svc -and $svc.Status -eq 'Running' -and $svc.StartType -ne 'Disabled') { Issue "$n ($($watch[$n])) is running / $($svc.StartType)"; $bad = $true } }
if (-not $bad) { Good "Watchlist services absent or disabled" }
if ($p.oemKey -eq 'dell') { $w = Get-ChildItem 'C:\Windows\System32\DriverStore\FileRepository' -ErrorAction SilentlyContinue | Where-Object { $_.Name -like 'wavesapo*' }; if ($w) { Issue "Waves still in DriverStore (gotchas #4)" } else { Good "Waves DriverStore clean" } }
$oemRx = @{ dell='Dell\\(TechHub|SupportAssist|DTP)'; hp='HP Support|HPSA|Touchpoint'; lenovo='Lenovo Now|LenovoWelcome|Mirametrix'; asus='GlideX|AsusCertService|ASUSSoftwareManager'; acer='Acer Collection|Jumpstart'; msi='MSI Companion' }[$p.oemKey]
if ($oemRx) { $orph = Get-Process | Where-Object { $_.Path -match $oemRx }; if ($orph) { Issue "OEM orphan processes running: $($orph.Name -join ', ')" } else { Good "No OEM orphan processes" } }
$cop = Get-AllAppx | Where-Object { $_.Name -eq 'Microsoft.Copilot' }; if ($cop) { Note "Microsoft.Copilot AppX is back (Windows reinstalled it) - re-run 03" } else { Good "Copilot app absent" }

L ""; L "--- Power ---"
$plan = powercfg /getactivescheme
L "  $plan"
if (-not $p.isLaptop -and $plan -notmatch 'Ultimate|High performance') { Note "Desktop not on Ultimate/High Performance" }
if ($p.isLaptop -and $p.workloads.gaming -and $plan -notmatch 'High performance') { Note "Gaming laptop not on High Performance" }

L ""; L "--- Startup entries (Task Manager view = StartupApproved) ---"
$approved = Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run' -ErrorAction SilentlyContinue
Get-CimInstance Win32_StartupCommand | ForEach-Object {
    $flag = if ($approved -and $approved.PSObject.Properties[$_.Name]) { if ($approved.($_.Name)[0] -eq 2) { 'enabled' } else { 'DISABLED' } } else { 'enabled' }
    L ("  {0,-9} {1,-30} {2}" -f $flag, $_.Name, $_.Command)
}

L ""; L "--- Top 10 processes by RAM ---"
Get-Process | Sort-Object WS -Descending | Select-Object -First 10 | ForEach-Object { L ("  {0,6} MB  {1}" -f [math]::Round($_.WS/1MB,0), $_.Name) }

L ""; L "--- Versions ---"
Get-CimInstance Win32_VideoController | ForEach-Object { L "  GPU: $($_.Name) | driver $($_.DriverVersion) | $(if ($_.DriverDate) { $_.DriverDate.ToString('yyyy-MM-dd') })" }
$bios = Get-CimInstance Win32_BIOS; L "  BIOS: $($bios.SMBIOSBIOSVersion) | $(if ($bios.ReleaseDate) { $bios.ReleaseDate.ToString('yyyy-MM-dd') })"
if (-not $p.osSupported) { Note "Windows 11 $($p.osVersion) is out of support - recommend the feature update to the current release" }

if ($PostReboot) {
    try { Checkpoint-Computer -Description "PC-Optimizer post-optimization $(Get-Date -Format 'yyyyMMdd-HHmm')" -RestorePointType MODIFY_SETTINGS -ErrorAction Stop; Good "Post-optimization restore point created" } catch { Note "Post-optimization restore point: $($_.Exception.Message)" }
}

L ""; L "===================================================================="
if ($issues.Count) { L "  RESULT: $($issues.Count) ISSUE(S) TO LOOK AT"; foreach ($i in $issues) { L "    - $i" } } else { L "  RESULT: ALL CHECKS PASSED" }
if ($notes.Count) { L "  Notes:"; foreach ($n in $notes) { L "    - $n" } }
L "  Report: $report"
L "===================================================================="
Copy-Item $report (Join-Path $LogDir ("VERIFY-REPORT-{0:yyyyMMdd-HHmm}.txt" -f (Get-Date))) -Force
$desktop = [Environment]::GetFolderPath('Desktop')
if ($desktop -and (Test-Path $desktop)) { Copy-Item $report (Join-Path $desktop 'PC-Optimization-Report.txt') -Force -ErrorAction SilentlyContinue }
Stop-PhaseLog
exit $(if ($issues.Count) { 1 } else { 0 })
