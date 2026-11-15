# Phase 15 - Verification and the Hands-Off Reboot

**Scripts:** `scripts/15-verify.ps1`, `scripts/15-schedule-postreboot-verify.ps1`, `scripts/postreboot-verify.ps1`

Two runs: once now (pre-reboot, catches mistakes while Claude is still here) and once automatically after
the reboot (catches everything that re-enables itself - gotchas #17 - and gives the real idle numbers).

## What `15-verify.ps1` checks

- Headline numbers against the Phase 00 baseline: RAM at idle, C: free, startup entries, Automatic services, AppX count
- Safety: PC-Optimizer restore point exists, backup folder exists, Defender real-time ON, no 3rd-party AV left,
  Fast Startup off, pending reboot
- **Things we promised to keep** (from `profile.keep`): core services not disabled, Spooler if printer, Windows
  Search, SysMain on low RAM, GamingServices startable if Xbox/gaming, OneDrive running, Windows Hello service,
  ASUS ATK Package task enabled
- **Flash-tuning safety** (if `workloads.flashTuning`): USB selective suspend AC+DC index 0,
  `USB\DisableSelectiveSuspend = 1`, PCIe ASPM off, serial/serenum/usbser drivers, PcaSvc not disabled, .NET 3.5,
  COM ports present, Defender exclusions listed
- **Things we meant to remove**: Waves, Killer, McAfee, Dell/HP orphan services and processes, DiagTrack and
  friends not running, Waves DriverStore clean (Dell), Copilot AppX not back
- Power plan as expected for the profile
- Startup entries with their real Task-Manager state (enabled / DISABLED - gotchas #23)
- Top 10 processes by RAM, GPU driver versions, BIOS version, OS support status

Output: `logs/VERIFY-REPORT.txt` (+ timestamped copy) and `PC-Optimization-Report.txt` on the Desktop.
Exit code 1 if any issue was found. `-PostReboot` additionally creates a "post-optimization" restore point.

## The reboot protocol

Claude Code does not survive a reboot (gotchas #22). So:

1. `.\15-verify.ps1` now. Fix anything flagged.
2. Phase 16: write the retrospective, update gotchas/lessons, update `checkpoint.md` ("waiting for reboot,
   post-reboot verify is automatic"), summarise for the user in plain words.
3. Job-specific post-reboot checks (driver post-install, orphan sweep): write them as `run/postreboot-<name>.ps1`.
4. `.\15-schedule-postreboot-verify.ps1 -Reboot`
   - registers the one-time scheduled task `PC-Optimizer-PostRebootVerify` (AtLogOn for the current user,
     RunLevel Highest, 1 h limit, allowed on battery, removes itself)
   - `shutdown /r /t 60` with a message telling the user to log in when it comes back
5. After login `postreboot-verify.ps1` waits 3 minutes, runs the hooks, runs `15-verify.ps1 -PostReboot`,
   opens the report in Notepad and deletes the task.

Why a scheduled task and not `HKLM\RunOnce`: RunOnce runs with the user's un-elevated token under UAC; a task
with RunLevel Highest runs elevated and in the interactive session, so Notepad actually appears.

Tell the user at the START of the session that logging in is the one thing that cannot be automated.

## If the user comes back to Claude later

Read `logs/VERIFY-REPORT.txt`. Fix issues (re-run the relevant phase script), then delete `checkpoint.md`.
If the post-reboot task did not run (no report on the Desktop): `Get-ScheduledTask PC-Optimizer-PostRebootVerify`,
check `logs/postreboot-verify.log`, run `15-verify.ps1 -PostReboot` by hand.
