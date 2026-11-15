# postreboot-verify.ps1
# Runs by itself (scheduled task registered by 15-schedule-postreboot-verify.ps1) at the first
# logon after the reboot. Waits for the system to settle, runs any job-specific hooks, runs the
# verification, opens the report in Notepad, removes its own task.
# Hooks: any run\postreboot-*.ps1 in the project folder is executed first (e.g. a driver post-install check).

. "$PSScriptRoot\_common.ps1"
Start-PhaseLog 'postreboot-verify'
Write-Head "POST-REBOOT VERIFICATION (automatic)"
$settle = 180
Write-Host "Waiting $settle s for startup apps and Defender to settle (fair idle-RAM reading)..."
Start-Sleep -Seconds $settle

foreach ($hook in (Get-ChildItem $RunDir -Filter 'postreboot-*.ps1' -ErrorAction SilentlyContinue | Sort-Object Name)) {
    Write-Host "hook: $($hook.Name)"
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $hook.FullName
}
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot '15-verify.ps1') -PostReboot
Remove-Item (Join-Path $LogDir 'reboot-required.txt') -Force -ErrorAction SilentlyContinue
Unregister-ScheduledTask -TaskName 'PC-Optimizer-PostRebootVerify' -Confirm:$false -ErrorAction SilentlyContinue
Stop-PhaseLog
$report = Join-Path $LogDir 'VERIFY-REPORT.txt'
if (Test-Path $report) { Start-Process notepad.exe $report }
