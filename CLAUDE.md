# PC Optimizer - instructions for Claude Code

You are running on someone else's Windows 11 PC to make it faster, cleaner and more private
WITHOUT breaking anything they rely on. The person at the keyboard is probably not technical.
Explain in plain words, ask before anything irreversible, and leave a written record they can read.

## Hard rules

1. **PowerShell goes in a `.ps1` file**, run as
   `powershell.exe -NoProfile -ExecutionPolicy Bypass -File "C:\...\script.ps1"`.
   Never `powershell -Command "..."` from bash: bash eats `$variables` silently (gotchas #1).
2. **Anything you write yourself goes in `run\`** (never in Temp - Phase 14 cleans Temp), is **pure ASCII**
   (no em-dashes, arrows, smart quotes: gotchas #18), and is checked with `scripts\_lint.ps1` before it runs.
   Dot-source `scripts\_common.ps1` for logging, `Set-Reg`, `Get-InstalledPrograms`, `Out-Table`, the never-touch lists.
3. **No change before Phase 02 has made a restore point and a backup set.** If the restore point fails, stop and ask.
4. **`profile.json` drives every decision.** Run Phase 00 first, read the plan out to the user in plain words,
   confirm the workloads and the keep-flags (Xbox/Game Pass, printer, OneDrive, Windows Search, touch),
   and fix the file (or re-run 00 with `-AddWorkload` / `-RemoveWorkload`) if they correct you.
5. **Manual beats Disabled.** The never-touch lists in `_common.ps1` are final. Never change the pagefile.
   Never delete user files, Downloads, the Recycle Bin, Windows.old, browser data, OneDrive, or an app the
   user might use, without an explicit yes. Every changing script has `-Preview`: preview, summarise, then apply.
6. **One reboot, at the very end, hands-off** (gotchas #22). Everything before it runs with no reboot.
   Finish ALL Claude-side work (checkpoint, retrospective, lessons, report) BEFORE
   `scripts\15-schedule-postreboot-verify.ps1 -Reboot`. The post-reboot verification runs by itself.
7. Never `Win32_Product` (gotchas #25). Never `netsh int ip reset` unless the user has a network problem (#26).
   Never block outbound traffic or firewall anything. Never touch camera/microphone permissions.
   Never install tools from the internet (Win11Debloat, "optimizer" apps); the scripts here cover it.
8. Pipe structured output through `Out-String` / the `Out-Table` helper, or tables are swallowed (gotchas #24).
9. On a laptop: BIOS/firmware only on the charger; keep hibernate; keep sleep on battery.
10. If anything unexpected happens, stop, read the log in `logs\`, and tell the user what you see.

## Session start

1. Read `gotchas.md`, `lessons-learned.md`, and `checkpoint.md` if it exists (interrupted session - resume from it).
2. Confirm the terminal is elevated (`scripts\_common.ps1` has `Test-Admin`; every changing script refuses otherwise).
3. Tell the user, in plain language, before touching anything:
   - what will happen and roughly how long (1-2 hours; SFC/DISM and updates are the slow parts)
   - keep the laptop plugged in, don't use the PC heavily, don't close this window
   - there will be ONE restart at the end; they only have to log in afterwards; a report then opens by itself
   - everything is reversible: restore point + `backup\<date>\` (double-click a `.reg` file to undo that part)
4. Run Phase 00, confirm the profile, write the first `checkpoint.md`.

## Phases

| # | Phase | Script | Runs when |
|---|-------|--------|-----------|
| 00 | Detect + plan (writes `profile.json`) | `00-detect-system.ps1` | always |
| 01 | Inventory (saves `logs\inventory-*.txt`) | `01-system-info.ps1` | always |
| 02 | Pre-flight: restore point, backup set, Fast Startup off, SFC/DISM | `02-preflight.ps1` | always |
| 03 | Remove bloat apps (SAFE tier; `-IncludeOptional`, `-RemoveXbox` after asking) | `03-remove-apps.ps1` | always |
| 04 | OEM bloat: audit (any OEM) / Dell removal | `04-oem-audit.ps1`, `04-oem-dell.ps1` | oemKey != custom |
| 05 | 3rd-party antivirus | `05-remove-mcafee.ps1` (+ vendor tool) | thirdPartyAV present |
| 06 | Services + background tasks (profile-aware) | `06-services.ps1` | always |
| 07 | Privacy, telemetry, Copilot/Recall, ads | `07-privacy.ps1` | always |
| 08 | Startup entries (Task Manager mechanism, reversible) | `08-startup-cleanup.ps1` | always |
| 09 | Windows/driver/app updates, NO reboot | `09-updates.ps1 -Install` | always |
| 10 | Power plan, USB/PCIe power, visual effects, HAGS | `10-performance.ps1` | always |
| 11 | GPU control panel + display | manual: `phases/11-gpu-display.md` | hasDedicatedGpu |
| 12 | Gaming + network | `12-gaming-network.ps1` | workloads.gaming |
| 13 | Dev / CAD / creative tuning | manual: `phases/13-dev-tools.md` | dev, cad or creative |
| 14 | Disk cleanup (guarded; destructive parts opt-in) | `14-disk-cleanup.ps1` | always |
| 15 | Verify, then schedule the hands-off reboot | `15-verify.ps1`, `15-schedule-postreboot-verify.ps1 -Reboot` | always |
| 16 | Retrospective + lessons (you write them) | `phases/16-session-retrospective.md` | always, BEFORE the reboot |

Each phase has a doc in `phases/` with the reasoning and the manual steps. Read it before running the script.

## Use-case profiles (from `profile.json`)

| Profile | Detected by | What changes |
|---|---|---|
| gaming | Steam/Epic/GOG/Battle.net/EA/Riot/Xbox app | Xbox apps + GamingServices kept, Game Mode ON, Phase 12, HAGS if VRAM >= 10 GB, High Performance on laptops, Steam/Discord startup only disabled if asked |
| simRacing | iRacing/Assetto/SimHub/wheel software or wheel hardware | as gaming + USB selective suspend OFF, wheel/pedal software never touched in startup |
| creative | DaVinci/Premiere/CapCut/Blender/Affinity/DAWs | FrameServer kept, Phase 13 creative section, no shader-cache clearing |
| cad | SolidWorks/AutoCAD/Fusion/Inventor... | Phase 13 CAD section, Studio driver advice |
| dev | VS/JetBrains/git/node/python/docker | Phase 13 dev section, WebClient kept |
| flashTuning | VCDS/Ross-Tech/HP Tuners/EFILive/COBB/NefMoto/J2534/FTDI... | USB suspend + per-device USB power + PCIe ASPM OFF, PcaSvc + serial/FTDI stack + .NET 3.5 kept, no outbound blocking, PCA tasks kept, Defender exclusions for the tuning folders (ask), BIOS only on charger |
| office / general | Office/Teams/Zoom or nothing detected | conservative defaults, Phone Link/Mail/OneNote/Teams only removed if asked |
| lowRam (<= 8 GB) | RAM | SysMain + Windows Search stay ON, pagefile untouched, visual effects -> performance, Prefetch never cleared |
| laptop | chassis / battery | hibernate kept, sleep on battery kept, Balanced plan unless gaming, location kept (Find My Device) |
| OEM | manufacturer string | Dell: dedicated script. Others: audit -> BLOAT / ASK FIRST / KEEP buckets, only BLOAT removed by default |

## Ask the user before

- removing anything in the OPTIONAL tier of Phase 03 (Mail, Phone Link, To Do, OneNote, Spotify, Teams, Movies & TV)
- removing Xbox apps / disabling GamingServices (only on a non-gaming machine)
- removing an OEM tool in the ASK FIRST bucket (Armoury Crate, MyASUS, Vantage, OMEN Hub, PredatorSense, MSI Center, Synapse: they control fans, performance modes, battery limits, lighting)
- disabling Steam / Discord / Epic / OneDrive / Dropbox / Zoom at startup (`08 -AlsoDisable`)
- Windows Search off (`06 -DisableSearch`), location off (`07 -DenyLocation`), mouse acceleration off (`12 -DisableMouseAccel`)
- Defender exclusions (`12 -DefenderExclusions`; flash-tuning folders by hand), DNS change (`12 -Dns`)
- winget upgrade of all apps (`09 -Winget`), OEM updater run (`09 -Oem`), any BIOS update
- emptying the Recycle Bin, deleting Windows.old, browser caches, `/ResetBase` (`14` switches)
- `-ResetNetwork` in Phase 02
- a Windows feature update when `osSupported` is false (recommend it; do it as a separate task after this run)

## Checkpoint (`checkpoint.md` in the project root)

Update it after every phase, not only before the reboot. A new Claude session must be able to resume from it alone.

```markdown
# Checkpoint - [DATE TIME]
## Machine / profile
[one line: OEM model, CPU, GPU, RAM, OS version, workloads, keep-flags]
## Done
- [x] 00 Detect - [summary]
- [x] 01 Inventory - logs\inventory-....txt
- [x] 02 Pre-flight - restore point #N, backup\<stamp>\
...
## Current
Phase NN: [name] - [in-progress | blocked: why]
## Next
Phase NN: [name] - [exact command to run]
## User decisions so far
- keep OneDrive (uses it) / remove Phone Link (never used) / ...
## Numbers
RAM idle: X -> Y GB | C: free: X -> Y GB | startup entries: N -> M | apps removed: N | services changed: N
## Issues
- [what failed, the error, the workaround]
```

## Reboot protocol (Phase 15)

1. `15-verify.ps1` now (pre-reboot) and fix anything it flags.
2. Write the retrospective (`session-retrospective-YYYY-MM-DD.md`), update `gotchas.md` / `lessons-learned.md`,
   update `checkpoint.md` to say "waiting for reboot; post-reboot verify is automatic", and give the user a short
   plain-language summary of what was done and where the undo lives.
3. If the job needs a post-reboot step of its own (driver post-check, orphan sweep), write it as
   `run\postreboot-<name>.ps1`; `postreboot-verify.ps1` runs every such hook before the verification.
4. `scripts\15-schedule-postreboot-verify.ps1 -Reboot`. Tell the user: log in when it comes back; the
   report (`logs\VERIFY-REPORT.txt`, copy on the Desktop) opens by itself a few minutes after login.
5. If the user comes back to Claude later: read `logs\VERIFY-REPORT.txt`, act on issues, delete `checkpoint.md`.

## Retrospective (Phase 16)

Write `session-retrospective-YYYY-MM-DD.md` using the template in `phases/16-session-retrospective.md`
(machine, before/after numbers, what went well, what wasted time and WHY, what failed, new gotchas, ranked
improvements). Then fold new gotchas into `gotchas.md` and new lessons into `lessons-learned.md` (with the source
session), and add a row to the session history table. If a script needed a fix to work on this machine, fix the
script in `scripts\` so the next machine benefits. Keep names, usernames and other personal details out of the
shared files: describe the machine, not the person.

## Learning ingestion

When asked to ingest another session's files: read them, extract new gotchas / lessons / better techniques /
failed approaches, compare against what is already recorded (update, merge or skip duplicates), apply to
`gotchas.md`, `lessons-learned.md`, the phase docs and the scripts, and record the source session.

## Script reference

| Script | Purpose | Key switches |
|---|---|---|
| `_common.ps1` | shared helpers + never-touch lists (dot-source it) | - |
| `_lint.ps1` | ASCII + parse + anti-pattern check for `scripts\` and `run\` | `[path]` |
| `00-detect-system.ps1` | hardware, OEM, OS, workloads, keep-flags -> `profile.json` + plan | `-AddWorkload`, `-RemoveWorkload` |
| `01-system-info.ps1` | full inventory to `logs\inventory-*.txt` | - |
| `02-preflight.ps1` | restore point, backup set, Fast Startup off, SFC/DISM | `-SkipScans`, `-ResetNetwork` |
| `03-remove-apps.ps1` | AppX removal in tiers | `-Preview`, `-IncludeOptional`, `-RemoveXbox`, `-Keep` |
| `04-oem-audit.ps1` | OEM software -> BLOAT / ASK FIRST / KEEP; removal on request | `-Remove`, `-Also` |
| `04-oem-dell.ps1` | Dell SupportAssist/TechHub/Waves/Killer removal + Command Update | `-KeepWaves`, `-SkipCommandUpdate` |
| `05-remove-mcafee.ps1` | McAfee uninstall + orphan services | `-Preview` |
| `06-services.ps1` | services Manual/Disabled by profile + telemetry tasks | `-Preview`, `-DisableSearch`, `-DisableXbox` |
| `07-privacy.ps1` | telemetry, ads, Copilot, Recall, Game Mode by profile | `-DenyLocation` |
| `08-startup-cleanup.ps1` | StartupApproved-based startup disable | `-Preview`, `-AlsoDisable`, `-Keep` |
| `09-updates.ps1` | Windows Update via COM API, winget, OEM updaters, no reboot | `-Install`, `-Winget`, `-Oem` |
| `10-performance.ps1` | power plan, USB/PCIe, visual effects, HAGS | `-Preview`, `-NoUsbSuspend`, `-HighPerformance` |
| `12-gaming-network.ps1` | Nagle, throttling, Game Mode, optional mouse/DNS/exclusions | `-Preview`, `-DisableMouseAccel`, `-DefenderExclusions`, `-Dns` |
| `14-disk-cleanup.ps1` | guarded junk removal, Storage Sense on | `-EmptyRecycleBin`, `-RemoveWindowsOld`, `-ResetBase`, `-BrowserCaches` |
| `15-verify.ps1` | profile-aware verification -> `logs\VERIFY-REPORT.txt` + Desktop copy | `-PostReboot` |
| `15-schedule-postreboot-verify.ps1` | register the self-removing post-reboot task, optional reboot | `-Reboot`, `-Unregister` |
| `postreboot-verify.ps1` | what the task runs: hooks, verify, open report | - |
