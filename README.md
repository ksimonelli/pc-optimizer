# Windows 11 Optimization Framework

Drop this folder on any Windows 11 PC, open an Administrator terminal, run `claude`, and say
**"Run the optimization on this machine"**. Claude detects the hardware, the manufacturer and what the
PC is used for (gaming, sim racing, video editing, CAD, development, office, vehicle flash-tuning, a
low-RAM budget machine...) and runs the right phases for it: bloatware off, telemetry off, startup
trimmed, services tuned, power settings right for the use case, updates applied, one restart at the end.

Everything is reversible (restore point + registry backups), nothing the user relies on is touched
without asking, and a plain-language report is left on the Desktop.

## For the person running it (no technical knowledge needed)

1. Install Claude Code if it is not already installed (https://claude.com/claude-code) and sign in once.
2. Get this folder onto the PC somewhere simple, e.g. `C:\PC-Optimizer`. Either:
   - with git: `git clone https://github.com/ksimonelli/pc-optimizer C:\PC-Optimizer`, or
   - without git: on https://github.com/ksimonelli/pc-optimizer click **Code > Download ZIP**, extract it,
     and rename the extracted folder to `C:\PC-Optimizer`.
3. Plug the laptop in. Save your work and close your programs.
4. Open an **Administrator** terminal: press Start, type `terminal`, right-click **Terminal**, choose
   **Run as administrator**, click Yes.
5. Type `cd C:\PC-Optimizer` and press Enter, then type `claude` and press Enter.
6. Say: **Run the optimization on this machine.**
7. Claude will explain what it found and ask a few questions (do you use Xbox/Game Pass? OneDrive? a printer?
   should Steam start with Windows?). Answer honestly - "I don't know" is fine; it then leaves things alone.
8. It takes 1 to 2 hours. Leave the PC alone during that time; don't close the window.
9. At the end the PC restarts once. Log in when it comes back. A few minutes later a report opens by itself
   (`PC-Optimization-Report.txt`, also saved on your Desktop).

**Undo:** everything is backed up before it changes. To put a setting back, open the `backup\<date>` folder
and double-click the matching `.reg` file, or use Control Panel > Recovery > Open System Restore and pick the
"PC-Optimizer pre-optimization" point. Startup apps can be switched back on in Task Manager > Startup apps.

## Results from real runs

| Machine | RAM idle before | after | Disk freed | Notes |
|---|---|---|---|---|
| Dell XPS 13 7390, 16 GB | ~10.1 GB | 6.39 GB | 107 GB | McAfee + Dell bloat removed, BIOS updated |
| Ryzen 5 5600 / RTX 3060, 16 GB | n/a | n/a | ~9 GB | 91 apps removed, GPU/gaming/dev tuning |
| ASUS TUF FX504GD, 8 GB (flash-tuning laptop) | 4.4-4.9 GB | 3.67 GB | ~2 GB | 41 apps, 8 services, 20 tasks; USB-suspend/ASPM off for ECU flashing; NVIDIA 512 -> 582 |

## How it works

- `CLAUDE.md` is what Claude reads first: the rules, the phase order, what to ask before doing.
- `scripts\00-detect-system.ps1` writes `profile.json` (hardware, OEM, workloads, and "keep-flags" such as
  *has a printer*, *uses OneDrive*, *uses Xbox*). Every later script reads it and adapts.
- Each phase is one script in `scripts\` plus one explanation in `phases\`. Scripts are pure ASCII,
  run on the stock Windows PowerShell 5.1, refuse to run un-elevated, log to `logs\`, and have a `-Preview` mode.
- Anything destructive or taste-dependent is behind a switch Claude only uses after asking.
- The single reboot is hands-off: a one-time scheduled task runs the verification after login and opens the report.
- After every run Claude writes a retrospective and folds new lessons into `gotchas.md` and
  `lessons-learned.md`, so the next machine benefits.

## Folder structure

```
CLAUDE.md                 <- Claude's instructions (auto-loaded)
README.md                 <- this file
gotchas.md                <- hard-won failure modes, numbered; read before every run
lessons-learned.md        <- knowledge base that grows across sessions
profile.json              <- created by Phase 00: what this machine is and is used for
checkpoint.md             <- created during a run: progress + decisions (deleted when done)
phases/                   <- one explanation per phase (why, what, manual steps)
  00-detect-and-plan.md ... 16-session-retrospective.md
scripts/                  <- one script per phase (pure ASCII, PowerShell 5.1)
  _common.ps1             <- shared helpers + never-touch lists
  _lint.ps1               <- ASCII / parse check for any script before it runs
  00-detect-system.ps1 ... 15-verify.ps1, postreboot-verify.ps1
run/                      <- scripts Claude writes for this specific machine (kept as the record)
logs/                     <- one log per phase, inventory, VERIFY-REPORT.txt
backup/<date>/            <- registry exports + CSV snapshots taken before any change (README-UNDO.txt inside)
```

`profile.json`, `checkpoint.md`, `run/`, `logs/` and `backup/` are per-machine and git-ignored.

## Without Claude

Run the scripts in `scripts\` in numeric order from an Administrator PowerShell, reading the matching
`phases\` doc first. Start with `00-detect-system.ps1`, check `profile.json`, and use `-Preview` on every
changing script before running it for real.

## Learning from another session

Say: **"Ingest this session: [path to a checkpoint or retrospective]"**. Claude extracts new gotchas and
lessons and merges them into the knowledge base.
