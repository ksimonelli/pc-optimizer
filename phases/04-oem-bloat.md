# Phase 04 - OEM Bloat

**Scripts:** `scripts/04-oem-audit.ps1` (any OEM, report-first) and `scripts/04-oem-dell.ps1` (Dell removal)
**Skip when:** `profile.oemKey` is `custom` (self-built PC).

OEM software is the biggest RAM and nag source on a pre-built machine, but some of it is the only way to
control fans, performance modes, keyboard lighting or the battery charge limit (gotchas #30). So: audit,
sort into buckets, remove only what is clearly junk, ask about the rest.

## Buckets (what `04-oem-audit.ps1` prints)

| Bucket | Meaning | Action |
|---|---|---|
| BLOAT | promos, registration nags, "support assistants", analytics, bundled AV/VPN/office trials | removed with `-Remove` |
| ASK FIRST | has a real function (fans, perf modes, RGB, battery limit, firmware) | removed only with `-Remove -Also 'Name'` after the user says they do not use it |
| KEEP | Fn-key / hotkey helpers, hardware interface services | never |
| UNKNOWN | carries the OEM name but matches no rule | research, then decide |

It scans programs, AppX, services, scheduled tasks and running processes.

## Per-OEM notes

**Dell** - use `04-oem-dell.ps1`. Removes SupportAssist, TechHub, Digital Delivery, Customer Connect,
Mobile Connect, Cinema Guide, MyDell, Dell Optimizer, Waves MaxxAudio (service + DriverStore INFs, gotchas #4),
Killer Network Manager services (gotchas #3), DellClientManagementService (gotchas #6); kills orphan
processes and folders (gotchas #5); installs Dell Command Update as the clean driver/BIOS updater.
Keep: Dell Power Manager (battery limit), Dell Command Update, Dell Touchpad. Alienware Command Center = ask.

**HP** - BLOAT: Support Assistant, Wolf Security, Sure Sense/Click/Run, JumpStart, HP Smart (unless they have
an HP printer - then it is their printer app), Print Scan Doctor service, Audio Switch, Documentation,
Touchpoint Analytics, myHP, QuickDrop. ASK: OMEN Gaming Hub / HP Command Center (fans, perf modes), Bang &
Olufsen audio control. KEEP: HP Hotkey Support, System Event Utility. Driver updates: HP Image Assistant (manual).

**Lenovo** - BLOAT: Lenovo Now, Welcome, Smart Appearance, Smart Noise Cancelling, Service Bridge, Migration
Assistant, Glance by Mirametrix, bundled McAfee. ASK: Lenovo Vantage / Legion Zone (perf modes, fan, battery
threshold - on ThinkPads suggest Commercial Vantage). KEEP: Hotkeys, Power Management Driver, System Interface
Foundation, System Update (the clean updater, `09-updates.ps1 -Oem` drives it).

**ASUS** - BLOAT: GlideX, Live Update, AsusCertService, ASUS Link Near, Software Manager, ASUS Optimization
(if not used), ScreenXpert, Splendid, Product Registration, WebStorage, GameSDK, bundled McAfee/WPS.
ASK: Armoury Crate (fan curves + perf modes on ROG/TUF - offer G-Helper as the light replacement), MyASUS
(firmware, battery limit), GameFirst, Aura/LightingService, Sonic Studio. KEEP: **ATK Package** scheduled task
and ATKACPI (Fn keys, keyboard backlight - gotchas #20), ASUS System Control Interface, keyboard hotkeys.

**Acer** - BLOAT: Acer Collection, Jumpstart, Product Registration, Configuration Manager, UEIP, Portal,
abDocs/abFiles/abPhoto, Purified Voice, bundled WildTangent/Norton/Booking. ASK: PredatorSense / NitroSense
(fans, OC), Quick Access (also hotkeys - test first), Care Center. KEEP: Quick Access Service / Launch Manager (Fn).

**MSI** - BLOAT: App Player, Companion, Help Desk, Register, Live Update, Nahimic Companion, bundled Norton.
ASK: MSI Center / Dragon Center (fans, perf), Afterburner (user's tool), True Color, Nahimic, SteelSeries GG.
KEEP: System Control Manager (Fn keys), MSI Foundation Service.

**Samsung** - BLOAT: Update, Studio, TV Plus, Gallery, Notes, Flow, Quick Search, Screen Recorder, Live
Message, Second Screen, Multi Control, Bixby. ASK: Samsung Settings (backlight, battery protection, Fn).
KEEP: System Support Service, System Event Controller.

**Razer** - BLOAT: Cortex, Game Booster. ASK: Synapse (lighting, fan, power on Blade). **Microsoft Surface** -
ships clean; leave the Surface app and drivers. **Gigabyte/AORUS** - ASK: Control Center / AORUS Engine.

**Unknown OEM** - the audit still runs with the manufacturer's name as the keyword plus the universal bundled
junk (McAfee, Norton, WildTangent, Booking.com, ExpressVPN, WPS Office). Research each hit before `-Remove`.

## Procedure

```powershell
.\04-oem-audit.ps1                              # report
.\04-oem-audit.ps1 -Remove                      # BLOAT bucket only
.\04-oem-audit.ps1 -Remove -Also 'MyASUS'       # plus an approved ASK-FIRST item
```

After the final reboot, `15-verify.ps1` checks for OEM orphan processes and Waves/Killer leftovers (gotchas #17).
Delete orphan services with `sc.exe delete <Name>` only once their program is confirmed gone (gotchas #13).
