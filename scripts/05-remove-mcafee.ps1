# 05-remove-mcafee.ps1
# Phase 05 - Remove McAfee (the most common pre-installed AV) and its orphan services.
# For Norton / Avast / AVG use the same pattern: uninstall, vendor removal tool, orphan sweep.
# Microsoft Defender re-enables itself automatically once the 3rd-party AV is gone.
#
# Run 03-remove-apps.ps1 first (it removes the McAfee AppX stub). After this script,
# download and run MCPR (McAfee Consumer Product Removal) for anything the uninstaller missed.
# The orphan-service sweep only works fully AFTER the final reboot - 15-verify.ps1 re-checks.

param([switch]$Preview)
. "$PSScriptRoot\_common.ps1"
Assert-Admin
Start-PhaseLog '05-remove-mcafee'
Write-Head "PHASE 05: McAFEE REMOVAL"

# ---------------------------------------------------------------- 1. AppX
foreach ($pkg in (Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue | Where-Object { $_.Name -like '*McAfee*' })) {
    if ($Preview) { Write-Info "would remove AppX $($pkg.Name)"; continue }
    $pkg | Remove-AppxPackage -AllUsers -ErrorAction SilentlyContinue; Write-Ok "removed AppX $($pkg.Name)"
}
Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $_.PackageName -like '*McAfee*' } | ForEach-Object {
    if (-not $Preview) { $_ | Remove-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Out-Null }
}

# ---------------------------------------------------------------- 2. Win32 products (registry uninstall strings, never Win32_Product)
$products = @(Get-InstalledPrograms | Where-Object { $_.DisplayName -match 'McAfee' -or $_.Publisher -match 'McAfee' })
if (-not $products) { Write-Ok "No McAfee programs registered." }
foreach ($prog in $products) {
    Write-Info "found: $($prog.DisplayName) $($prog.DisplayVersion)"
    if ($Preview) { continue }
    $cmd = $prog.QuietUninstallString
    if (-not $cmd -and $prog.UninstallString -match 'msiexec') { $cmd = ($prog.UninstallString -replace '/I','/X' -replace '/i','/x') + ' /qn /norestart' }
    if (-not $cmd -and $prog.UninstallString) { $cmd = $prog.UninstallString + ' /quiet /silent' }   # McAfee uninstaller accepts these on most builds
    if ($cmd) {
        try { Start-Process cmd.exe -ArgumentList "/c $cmd" -Wait -WindowStyle Hidden -ErrorAction Stop; Write-Ok "uninstaller finished for $($prog.DisplayName)" }
        catch { Write-Warn "$($prog.DisplayName): $($_.Exception.Message)" }
    }
}
# winget as a second pass (ids vary by bundle; failures are fine)
if (-not $Preview -and (Get-Command winget -ErrorAction SilentlyContinue)) {
    foreach ($id in 'McAfee.LiveSafe','McAfee.SecurityScanPlus','McAfee.WebAdvisor','McAfee.SafeConnect') {
        winget uninstall --id $id --silent --accept-source-agreements 2>&1 | Where-Object { $_ -match 'Successfully' } | ForEach-Object { Write-Ok "winget removed $id" }
    }
}

# ---------------------------------------------------------------- 3. orphan services (gotchas #7)
$orphans = Get-CimInstance Win32_Service | Where-Object { $_.Name -match '^(mfe|mc|McAfee|NAP|ModuleCore)' -or $_.DisplayName -match 'McAfee' }
foreach ($svc in $orphans) {
    if ($Preview) { Write-Info "would delete service $($svc.Name) ($($svc.State))"; continue }
    Stop-Service $svc.Name -Force -ErrorAction SilentlyContinue
    sc.exe delete $svc.Name | Out-Null
    Write-Ok "deleted service $($svc.Name)"
}
foreach ($dir in @('C:\Program Files\McAfee','C:\Program Files (x86)\McAfee','C:\Program Files\Common Files\McAfee','C:\ProgramData\McAfee')) {
    if (Test-Path $dir) { Write-Warn "leftover folder: $dir (MCPR or a post-reboot delete will clear it)" }
}

Write-Host ""
Write-Host "NEXT: download MCPR from mcafee.com (search 'MCPR'), run it, and let the FINAL reboot finish the job."
Write-Host "Defender will show as active in 15-verify.ps1 once McAfee is fully gone."
Stop-PhaseLog
