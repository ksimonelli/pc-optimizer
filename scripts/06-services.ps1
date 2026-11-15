# 06-services.ps1
# Phase 06 - Services and background (scheduled) tasks. Profile-aware.
# Policy: Manual, not Disabled. Disabled is used only for pure telemetry / legacy services
# nothing legitimate depends on. The never-touch list in _common.ps1 is enforced.
#
#   .\06-services.ps1 -Preview           show decisions, change nothing
#   .\06-services.ps1                    apply
#   .\06-services.ps1 -DisableSearch     Windows Search indexer -> Manual (user said they never use Search)
#   .\06-services.ps1 -DisableXbox       GamingServices Start=4 (NON-gaming machine, user confirmed)
#
# Profile rules:
#   lowRam / HDD        -> SysMain stays ON (prefetch helps under memory pressure)
#   keep.printer        -> Spooler untouched
#   keep.touch          -> TabletInputService / TextInputManagementService untouched
#   keep.biometric      -> WbioSrv untouched
#   keep.xbox / gaming  -> Xbox services -> Manual (start on demand), GamingServices untouched
#   flashTuning         -> PcaSvc, serial/FTDI stack untouched (never-touch list)
#   laptop              -> lfsvc (location) kept Manual not Disabled; RmSvc (radio) untouched

param([switch]$Preview, [switch]$DisableSearch, [switch]$DisableXbox)
. "$PSScriptRoot\_common.ps1"
Assert-Admin
Start-PhaseLog '06-services'
Write-Head "PHASE 06: SERVICES + BACKGROUND TASKS"
$p = Get-OptProfile
$before = (Get-RamGB).UsedGB

# ---------------------------------------------------------------- decisions
$disable = @('DiagTrack','dmwappushservice','RemoteRegistry','RetailDemo','Fax','wisvc','WMPNetworkSvc','MapsBroker','AJRouter','PNRPsvc','p2psvc','p2pimsvc','PNRPAutoReg','NetTcpPortSharing','diagnosticshub.standardcollector.service','SharedAccess')
$manual  = @('WerSvc','DiagSvc','WdiServiceHost','WdiSystemHost','PhoneSvc','lfsvc','WalletService','MessagingService','PrintNotify','SCardSvr','ScDeviceEnum','CscService','WpcMonSvc','TroubleshootingSvc','wercplsupport','BcastDVRUserService','CDPSvc','SEMgrSvc','FrameServer','PerfHost','SSDPSRV','upnphost','fhsvc','icssvc','RemoteAccess','SmsRouter','TapiSrv','WbioSrv','TabletInputService','TextInputManagementService','Spooler','SysMain','XblAuthManager','XblGameSave','XboxNetApiSvc','XboxGipSvc','GameInputSvc','AdobeARMservice','edgeupdate','edgeupdatem','GoogleUpdaterService','gupdate','gupdatem','MozillaMaintenance')
$never = @()

if ($p.keep.printer)   { $never += 'Spooler','PrintNotify' }
if ($p.keep.touch)     { $never += 'TabletInputService','TextInputManagementService' }
if ($p.keep.biometric) { $never += 'WbioSrv' }
if ($p.keep.sysmain -or $p.lowRam -or $p.systemDiskType -eq 'HDD') { $never += 'SysMain' }
if ($p.keep.xbox -or $p.workloads.gaming) { $never += 'XboxGipSvc','GameInputSvc' }   # controller input services
if ($p.isLaptop)       { $never += 'RmSvc','lfsvc' }       # radios / Find My Device
if ($p.workloads.flashTuning) { $never += 'PcaSvc' }
if ($p.workloads.office -or $p.workloads.dev) { $never += 'WebClient','CDPSvc' }   # WebDAV / nearby share
if ($p.workloads.creative) { $never += 'FrameServer' }    # camera frame server used by capture apps
if ($DisableSearch) { $manual += 'WSearch' } else { $never += 'WSearch' }

function Decide($name) {
    if ((Test-NeverTouchService $name) -or ($never -contains $name)) { return 'KEEP' }
    if ($disable -contains $name) { return 'Disabled' }
    if ($manual -contains $name)  { return 'Manual' }
    return $null
}

$changes = 0
foreach ($name in ($disable + $manual | Select-Object -Unique)) {
    $svc = Get-Service -Name $name -ErrorAction SilentlyContinue
    if (-not $svc) { continue }
    $d = Decide $name
    if ($d -eq 'KEEP') { Write-Skip "$name kept ($($svc.StartType))"; continue }
    if ($svc.StartType -eq $d) { continue }
    if ($Preview) { Write-Info "would set $name : $($svc.StartType) -> $d"; continue }
    try {
        if ($d -eq 'Disabled') { Stop-Service $name -Force -ErrorAction SilentlyContinue }
        Set-Service -Name $name -StartupType $d -ErrorAction Stop
        Write-Ok "$name : $($svc.StartType) -> $d"; $changes++
    } catch {
        Set-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Services\$name" -Name Start -Value $(if ($d -eq 'Disabled') {4} else {3}) -ErrorAction SilentlyContinue
        Write-Ok "$name : -> $d (via registry)"; $changes++
    }
}

# GamingServices is Windows-protected (gotchas #2). Only on a confirmed non-gaming machine.
if ($DisableXbox) {
    if ($p.keep.xbox -or $p.workloads.gaming) { Write-Warn "GamingServices NOT disabled: profile says Xbox/gaming is in use." }
    else {
        foreach ($g in 'GamingServices','GamingServicesNet') {
            if (Test-Path "HKLM:\SYSTEM\CurrentControlSet\Services\$g") {
                if ($Preview) { Write-Info "would set $g Start=4" } else { Set-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Services\$g" -Name Start -Value 4; Write-Ok "$g Start=4 (registry)" }
            }
        }
    }
}

# ---------------------------------------------------------------- orphan services (binary missing)
Write-Host ""
Write-Info "Orphan services (binary missing) - delete with sc.exe only after confirming the program is really gone:"
function Get-ServiceExe($pathName) {
    if ($pathName -match '^"([^"]+)"') { return $matches[1] }
    if ($pathName -match '^(.*?\.(exe|sys))') { return $matches[1] }
    return $pathName.Split(' ')[0]
}
Get-CimInstance Win32_Service | Where-Object {
    $_.PathName -and ($_.PathName -notmatch 'svchost|dllhost') -and -not (Test-Path (Get-ServiceExe $_.PathName))
} | Select-Object Name, DisplayName, State, PathName | Out-Table

# ---------------------------------------------------------------- scheduled tasks (telemetry / CEIP / nag)
Write-Host ""
Write-Info "Background tasks"
$tasks = @(
    '\Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser',
    '\Microsoft\Windows\Application Experience\ProgramDataUpdater',
    '\Microsoft\Windows\Application Experience\StartupAppTask',
    '\Microsoft\Windows\Application Experience\PcaPatchDbTask',
    '\Microsoft\Windows\Application Experience\MareBackup',
    '\Microsoft\Windows\Customer Experience Improvement Program\Consolidator',
    '\Microsoft\Windows\Customer Experience Improvement Program\UsbCeip',
    '\Microsoft\Windows\Customer Experience Improvement Program\KernelCeipTask',
    '\Microsoft\Windows\Autochk\Proxy',
    '\Microsoft\Windows\Feedback\Siuf\DmClient',
    '\Microsoft\Windows\Feedback\Siuf\DmClientOnScenarioDownload',
    '\Microsoft\Windows\Windows Error Reporting\QueueReporting',
    '\Microsoft\Windows\DiskDiagnostic\Microsoft-Windows-DiskDiagnosticDataCollector',
    '\Microsoft\Windows\CloudExperienceHost\CreateObjectTask',
    '\Microsoft\Windows\Maps\MapsToastTask',
    '\Microsoft\Windows\Maps\MapsUpdateTask',
    '\Microsoft\Windows\Shell\FamilySafetyMonitor',
    '\Microsoft\Windows\Shell\FamilySafetyRefreshTask',
    '\Microsoft\Windows\Retail Demo\CleanupOfflineContent',
    '\Microsoft\Windows\Power Efficiency Diagnostics\AnalyzeSystem'
)
$taskRegex = 'NvTmRep|NvTmMon|NvProfileUpdater|NvDriverUpdateCheck|GFExperienceSelfUpdate|NvNodeLauncher|AMDRyzenMasterSDK|Adobe Acrobat Update Task|AdobeGCInvoker|CCleaner|OneDrive Standalone Update|Booking|MicrosoftEdgeUpdateBrowserReplacement|XblGameSaveTask'
if ($p.workloads.flashTuning -or $p.workloads.office) { $tasks = $tasks | Where-Object { $_ -notmatch 'PcaPatchDbTask' } }  # PCA shims for old tools
$tdone = 0
foreach ($t in $tasks) {
    $path = (Split-Path $t) + '\'; $name = Split-Path $t -Leaf
    $obj = Get-ScheduledTask -TaskPath $path -TaskName $name -ErrorAction SilentlyContinue
    if (-not $obj -or $obj.State -eq 'Disabled') { continue }
    if (Test-NeverTouchTask $path $name) { Write-Skip "task $t (never-touch)"; continue }
    if ($Preview) { Write-Info "would disable task $t"; continue }
    Disable-ScheduledTask -TaskPath $path -TaskName $name -ErrorAction SilentlyContinue | Out-Null; $tdone++; Write-Ok "disabled task $name"
}
foreach ($obj in (Get-ScheduledTask | Where-Object { $_.TaskName -match $taskRegex -and $_.State -ne 'Disabled' })) {
    if (Test-NeverTouchTask $obj.TaskPath $obj.TaskName) { continue }
    if ($Preview) { Write-Info "would disable task $($obj.TaskPath)$($obj.TaskName)"; continue }
    Disable-ScheduledTask -TaskPath $obj.TaskPath -TaskName $obj.TaskName -ErrorAction SilentlyContinue | Out-Null; $tdone++; Write-Ok "disabled task $($obj.TaskName)"
}
# Note: '\ATK Package' (ASUS Fn keys) and all OEM hotkey tasks are protected by the never-touch list.

$after = (Get-RamGB).UsedGB
Write-Host ""
if ($Preview) { Write-Host "PREVIEW ONLY - nothing changed." } else { Write-Ok "Services changed: $changes, tasks disabled: $tdone. RAM $before GB -> $after GB (true idle shows after reboot)." }
Stop-PhaseLog
