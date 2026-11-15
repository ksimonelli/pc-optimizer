# 09-updates.ps1
# Phase 09 - Windows Update (incl. driver updates offered by Microsoft), winget app upgrades
# and OEM updaters - ALL WITHOUT REBOOTING. The single reboot happens at the very end of the run
# (gotchas.md #22). Uses the built-in Windows Update COM API: no modules to install, works on PS 5.1.
#
#   .\09-updates.ps1                scan and list only
#   .\09-updates.ps1 -Install       download + install pending Windows updates (no reboot)
#   .\09-updates.ps1 -Install -Winget   also upgrade winget-managed apps silently
#   .\09-updates.ps1 -Install -Oem      also run Dell Command Update / Lenovo System Update if installed
#
# GPU drivers: do NOT rely on Windows Update for a gaming machine - see phases/09-drivers-updates.md.
# BIOS: never on battery, never from this script - OEM tool, with the charger plugged in.
# Writes logs\reboot-required.txt when a reboot is pending so the final step knows.

param([switch]$Install, [switch]$Winget, [switch]$Oem)
. "$PSScriptRoot\_common.ps1"
Assert-Admin
Start-PhaseLog '09-updates'
Write-Head "PHASE 09: UPDATES (NO REBOOT)"
$p = Get-OptProfile
$onBattery = Test-OnBattery
if ($onBattery) { Write-Warn "Running on battery. Firmware/BIOS updates will be skipped; plug the charger in for those." }
$rebootFlag = Join-Path $LogDir 'reboot-required.txt'

# ---------------------------------------------------------------- Windows Update (COM)
try {
    $session  = New-Object -ComObject Microsoft.Update.Session
    $searcher = $session.CreateUpdateSearcher()
    Write-Info "Searching Windows Update (30-120 s)..."
    $result = $searcher.Search("IsInstalled=0 and IsHidden=0")
    $updates = @($result.Updates | ForEach-Object { $_ })
    if (-not $updates.Count) { Write-Ok "Windows Update: nothing pending." }
    else {
        $updates | Select-Object @{N='Title';E={$_.Title}}, @{N='MB';E={[math]::Round($_.MaxDownloadSize/1MB,0)}}, @{N='Driver';E={$_.DriverClass -ne $null}} | Out-Table
        if ($Install) {
            $coll = New-Object -ComObject Microsoft.Update.UpdateColl
            foreach ($u in $updates) {
                if ($u.InstallationBehavior.CanRequestUserInput) { Write-Skip "needs user input: $($u.Title)"; continue }
                if ($onBattery -and $u.Title -match 'firmware|BIOS|UEFI') { Write-Skip "on battery: $($u.Title)"; continue }
                if (-not $u.EulaAccepted) { $u.AcceptEula() }
                $coll.Add($u) | Out-Null
            }
            if ($coll.Count) {
                Write-Info "Downloading $($coll.Count) update(s)..."
                $dl = $session.CreateUpdateDownloader(); $dl.Updates = $coll; $dl.Download() | Out-Null
                Write-Info "Installing (no reboot)..."
                $inst = $session.CreateUpdateInstaller(); $inst.Updates = $coll; $inst.ForceQuiet = $true
                $r = $inst.Install()
                for ($i = 0; $i -lt $coll.Count; $i++) {
                    $code = $r.GetUpdateResult($i).ResultCode   # 2 = succeeded, 3 = succeeded with errors, 4 = failed
                    $tag = switch ($code) { 2 {'OK'} 3 {'OK (warnings)'} 4 {'FAILED'} 5 {'ABORTED'} default {"code $code"} }
                    Write-Host "  [$tag] $($coll.Item($i).Title)"
                }
                if ($r.RebootRequired) { "Windows Update $(Get-Date -Format 'yyyy-MM-dd HH:mm')" | Out-File $rebootFlag -Append -Encoding ascii; Write-Warn "Reboot required (deferred to the end of the run)." }
            }
        } else { Write-Host "Scan only. Re-run with -Install to apply." }
    }
} catch { Write-Warn "Windows Update API: $($_.Exception.Message)" }

# ---------------------------------------------------------------- winget
if ($Winget) {
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        Write-Info "winget upgrade (silent, pinned/unknown versions skipped)..."
        winget upgrade --all --silent --accept-package-agreements --accept-source-agreements --disable-interactivity 2>&1 | Select-String -Pattern 'Successfully|Failed|No applicable|upgrades available' | ForEach-Object { Write-Host "  $_" }
    } else { Write-Warn "winget not available (install 'App Installer' from the Microsoft Store)." }
} else { Write-Skip "winget upgrade not requested (-Winget). Check 'winget upgrade' output with the user first - it also updates game launchers and browsers." }

# ---------------------------------------------------------------- OEM updaters
if ($Oem) {
    $dcu = @('C:\Program Files\Dell\CommandUpdate\dcu-cli.exe','C:\Program Files (x86)\Dell\CommandUpdate\dcu-cli.exe') | Where-Object { Test-Path $_ } | Select-Object -First 1
    if ($dcu) {
        $types = if ($onBattery) { 'driver,application,others' } else { 'bios,firmware,driver,application,others' }
        Write-Info "Dell Command Update: applying $types (no reboot)..."
        & $dcu /applyUpdates -reboot=disable -updateType=$types -silent 2>&1 | Select-Object -Last 5
        "Dell Command Update $(Get-Date -Format 'yyyy-MM-dd HH:mm')" | Out-File $rebootFlag -Append -Encoding ascii
    }
    $tvsu = @('C:\Program Files (x86)\Lenovo\System Update\tvsu.exe','C:\Program Files\Lenovo\System Update\tvsu.exe') | Where-Object { Test-Path $_ } | Select-Object -First 1
    if ($tvsu) {
        Write-Info "Lenovo System Update: installing critical + recommended (no reboot)..."
        & $tvsu /CM -search A -action INSTALL -noicon -noreboot -nolicense 2>&1 | Select-Object -Last 3
        "Lenovo System Update $(Get-Date -Format 'yyyy-MM-dd HH:mm')" | Out-File $rebootFlag -Append -Encoding ascii
    }
    if (-not $dcu -and -not $tvsu) { Write-Skip "No scripted OEM updater found (HP: run HP Image Assistant manually; ASUS/Acer/MSI: check the support site for BIOS/driver versions)." }
}

# ---------------------------------------------------------------- state
$pending = (Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending') -or
           (Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired')
if ($pending) { Write-Warn "Windows reports a pending reboot. Keep going - the single reboot at the end applies everything."; if (-not (Test-Path $rebootFlag)) { "Pending reboot detected $(Get-Date)" | Out-File $rebootFlag -Encoding ascii } }
Get-CimInstance Win32_VideoController | ForEach-Object { Write-Host "GPU driver now: $($_.Name) $($_.DriverVersion) ($(if ($_.DriverDate) { $_.DriverDate.ToString('yyyy-MM-dd') }))" }
Write-Host "BIOS: $((Get-CimInstance Win32_BIOS).SMBIOSBIOSVersion) - compare with the OEM support page for this model."
Stop-PhaseLog
