# 04-oem-dell.ps1
# Phase 04 (Dell only) - remove Dell SupportAssist, TechHub, Waves MaxxAudio, Killer Network Manager,
# DellClientManagementService; install Dell Command Update as the clean replacement.
# Proven on Dell XPS 13 7390 (see gotchas.md #3-#6). Run 04-oem-audit.ps1 first to see what is present.
#
#   .\04-oem-dell.ps1            remove
#   .\04-oem-dell.ps1 -KeepWaves keep Waves MaxxAudio (only if the user actually likes its audio processing)

param([switch]$KeepWaves, [switch]$SkipCommandUpdate)
. "$PSScriptRoot\_common.ps1"
Assert-Admin
Start-PhaseLog '04-oem-dell'
Write-Head "PHASE 04: DELL BLOAT REMOVAL"
$p = Get-OptProfile
if ($p.oemKey -ne 'dell') { Write-Fail "profile.oemKey is '$($p.oemKey)', not dell. Use 04-oem-audit.ps1."; Stop-PhaseLog; return }
$before = (Get-RamGB).UsedGB

# ---------------------------------------------------------------- 1. AppX
Write-Info "[1/6] Dell AppX packages"
$dellApps = @('*DellTechHub*','*SupportAssistAgent*','*DellSupportAssist*','*Dell.Mobile.Connect*','*DellMobileConnect*',
              '*CinemaGuide*','*DellCinemaGuide*','*MyDell*','*DellDigitalDelivery*','*DellCustomerConnect*','*DellOptimizer*','*DellCommandUpdate*')
foreach ($pattern in $dellApps) {
    foreach ($pkg in (Get-AppxPackage -AllUsers -Name $pattern -ErrorAction SilentlyContinue)) {
        Write-Ok "removing AppX: $($pkg.Name)"; $pkg | Remove-AppxPackage -AllUsers -ErrorAction SilentlyContinue
    }
    Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $_.PackageName -like $pattern } |
        Remove-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Out-Null
}

# ---------------------------------------------------------------- 2. Win32 uninstallers (silent where possible)
Write-Info "[2/6] Dell Win32 programs"
foreach ($prog in (Get-InstalledPrograms | Where-Object { $_.DisplayName -match 'SupportAssist|Dell Digital Delivery|Dell Customer Connect|Dell Optimizer|Dell Update|Dell Mobile Connect|TechHub' })) {
    $cmd = $prog.QuietUninstallString
    if (-not $cmd -and $prog.UninstallString -match 'msiexec') { $cmd = ($prog.UninstallString -replace '/I','/X' -replace '/i','/x') + ' /qn /norestart' }
    if ($cmd) { Write-Info "uninstalling $($prog.DisplayName)"; Start-Process cmd.exe -ArgumentList "/c $cmd" -Wait -WindowStyle Hidden -ErrorAction SilentlyContinue }
    else { Write-Warn "$($prog.DisplayName): no silent uninstaller - remove via Settings > Apps" }
}

# ---------------------------------------------------------------- 3. orphan processes + folders (gotchas #5)
Write-Info "[3/6] Dell orphan processes and folders"
Get-Process | Where-Object { $_.Path -like 'C:\Program Files\Dell\*' -or $_.Path -like 'C:\Program Files (x86)\Dell\*' } | ForEach-Object {
    if ($_.Path -match 'Power Manager|CommandUpdate') { return }
    Write-Ok "stopping $($_.Name) ($($_.Path))"; Stop-Process -Id $_.Id -Force -ErrorAction SilentlyContinue
}
Start-Sleep -Seconds 2
foreach ($dir in @('C:\Program Files\Dell\TechHub','C:\Program Files\Dell\DTP','C:\Program Files\Dell\MyDell','C:\Program Files\Dell\DellDataVault','C:\Program Files\Dell\SupportAssistAgent','C:\Program Files\Dell\SupportAssist')) {
    if (Test-Path $dir) { Remove-Item $dir -Recurse -Force -ErrorAction SilentlyContinue; if (Test-Path $dir) { Write-Warn "still present (in use, retry after reboot): $dir" } else { Write-Ok "deleted $dir" } }
}

# ---------------------------------------------------------------- 4. Waves MaxxAudio (gotchas #4)
if ($KeepWaves) { Write-Skip "[4/6] Waves MaxxAudio kept by request" }
else {
    Write-Info "[4/6] Waves MaxxAudio"
    if (Get-Service WavesSvc64 -ErrorAction SilentlyContinue) { Stop-Service WavesSvc64 -Force -ErrorAction SilentlyContinue; sc.exe delete WavesSvc64 | Out-Null; Write-Ok "WavesSvc64 deleted" }
    Remove-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run' -Name 'WavesSysTray' -ErrorAction SilentlyContinue
    $wavesDrivers = pnputil /enum-drivers | Select-String -Pattern 'waves' -Context 4
    if ($wavesDrivers) {
        $infNames = ($wavesDrivers | Select-String 'oem\d+\.inf' -AllMatches).Matches.Value | Sort-Object -Unique
        foreach ($inf in $infNames) { Write-Ok "deleting driver $inf"; pnputil /delete-driver $inf /uninstall /force 2>&1 | Out-Null }
    }
    $left = Get-ChildItem 'C:\Windows\System32\DriverStore\FileRepository' -ErrorAction SilentlyContinue | Where-Object { $_.Name -like 'wavesapo*' }
    if ($left) { Write-Warn "Waves folders still in DriverStore (re-check after reboot): $($left.Name -join ', ')" } else { Write-Ok "Waves DriverStore clean" }
}

# ---------------------------------------------------------------- 5. Killer Network Manager (gotchas #3)
Write-Info "[5/6] Killer Network Manager"
foreach ($svc in (Get-CimInstance Win32_Service | Where-Object { $_.Name -match '^(KAPSService|KillerAnalyticsService|KillerNetworkService|KillerProviderDataHelperService|KNDBWM)$' -or $_.DisplayName -like '*Killer*' })) {
    Write-Ok "deleting service $($svc.Name)"; Stop-Service $svc.Name -Force -ErrorAction SilentlyContinue; sc.exe delete $svc.Name | Out-Null
}
Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue | Where-Object { $_.Name -like '*Killer*' } | Remove-AppxPackage -AllUsers -ErrorAction SilentlyContinue
# The Killer NIC driver itself (Intel/Rivet) stays - it is the network card driver.

# ---------------------------------------------------------------- 6. DellClientManagementService (gotchas #6) + Command Update
Write-Info "[6/6] DellClientManagementService / Dell Command Update"
if (Get-Service DellClientManagementService -ErrorAction SilentlyContinue) {
    Stop-Service DellClientManagementService -Force -ErrorAction SilentlyContinue; sc.exe delete DellClientManagementService | Out-Null
    Stop-Process -Name ServiceShell -Force -ErrorAction SilentlyContinue; Start-Sleep 2
    Remove-Item 'C:\Program Files (x86)\Dell\UpdateService' -Recurse -Force -ErrorAction SilentlyContinue
    Write-Ok "DellClientManagementService removed"
}
if (-not $SkipCommandUpdate) {
    if (Get-InstalledPrograms | Where-Object { $_.DisplayName -like 'Dell Command*Update*' }) { Write-Ok "Dell Command Update already installed" }
    elseif (Get-Command winget -ErrorAction SilentlyContinue) {
        Write-Info "installing Dell Command Update via winget (clean driver/BIOS updater)"
        winget install Dell.CommandUpdate --silent --accept-package-agreements --accept-source-agreements 2>&1 | Select-Object -Last 2
    } else { Write-Warn "winget not available - install Dell Command Update manually from dell.com/support" }
}

$after = (Get-RamGB).UsedGB
Write-Host ""
Write-Ok "Dell removal done. RAM $before GB -> $after GB. Re-check Waves/Killer/Dell services after the final reboot (gotchas.md #17)."
Write-Host "Driver updates (Phase 09, no reboot): & 'C:\Program Files\Dell\CommandUpdate\dcu-cli.exe' /applyUpdates -reboot=disable"
Stop-PhaseLog
