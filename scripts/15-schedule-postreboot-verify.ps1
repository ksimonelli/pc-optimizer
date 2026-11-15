# 15-schedule-postreboot-verify.ps1
# Makes the ONE reboot hands-off (gotchas.md #22): registers a scheduled task that runs
# postreboot-verify.ps1 elevated at the user's next logon, then (optionally) reboots.
# Claude Code cannot survive a reboot, so EVERYTHING Claude-side (checkpoint, retrospective,
# report, lessons) must be finished BEFORE this is run with -Reboot.
#
#   .\15-schedule-postreboot-verify.ps1            register the task only
#   .\15-schedule-postreboot-verify.ps1 -Reboot    register, then restart in 60 s
#   .\15-schedule-postreboot-verify.ps1 -Unregister
#
# Why a scheduled task and not HKLM\RunOnce: RunOnce entries run with the user's un-elevated
# token under UAC; a task with RunLevel Highest runs elevated and shows Notepad in the user's session.
# The task deletes itself when postreboot-verify.ps1 finishes.

param([switch]$Reboot, [switch]$Unregister, [int]$Delay = 60)
. "$PSScriptRoot\_common.ps1"
Assert-Admin
$taskName = 'PC-Optimizer-PostRebootVerify'
if ($Unregister) { Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue; Write-Ok "task removed"; return }

$script = Join-Path $PSScriptRoot 'postreboot-verify.ps1'
if (-not (Test-Path $script)) { Write-Fail "missing $script"; exit 1 }
$user = "$env:USERDOMAIN\$env:USERNAME"
$action    = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Minimized -File `"$script`""
$trigger   = New-ScheduledTaskTrigger -AtLogOn -User $user
$principal = New-ScheduledTaskPrincipal -UserId $user -LogonType Interactive -RunLevel Highest
$settings  = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit (New-TimeSpan -Hours 1) -StartWhenAvailable
Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue
Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Description 'PC Optimizer: one-time post-reboot verification; removes itself when done.' | Out-Null
Write-Ok "Scheduled task '$taskName' registered for $user (runs once at next logon, elevated)."

if ($Reboot) {
    $onBattery = Test-OnBattery
    if ($onBattery) { Write-Warn "Laptop is on battery. A reboot is fine; a pending BIOS update would not be." }
    Write-Host ""
    Write-Host "RESTARTING IN $Delay SECONDS. After the restart: log in, wait a few minutes, the report opens by itself." -ForegroundColor Yellow
    shutdown /r /t $Delay /c "PC optimization: restarting to apply changes. Log in when it comes back; the verification report will open by itself."
} else {
    Write-Host "Not rebooting (no -Reboot). When ready: shutdown /r /t 60"
}
