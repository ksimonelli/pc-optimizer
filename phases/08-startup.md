# Phase 08 - Startup Entries

**Script:** `scripts/08-startup-cleanup.ps1`

Startup entries slow the boot and keep apps resident. The script disables them the way Task Manager does -
by writing the `StartupApproved` flag (first byte 03 = disabled) - instead of deleting Run values. That means:
fully reversible by the user in Task Manager > Startup apps, and apps that re-create their Run value (Teams,
Edge, Spotify - gotchas #8) stay disabled.

## Where startup lives (all covered)

1. `HKCU\...\CurrentVersion\Run` -> `StartupApproved\Run` (HKCU)
2. `HKLM\...\CurrentVersion\Run` -> `StartupApproved\Run` (HKLM)
3. `HKLM\SOFTWARE\WOW6432Node\...\Run` -> `StartupApproved\Run32`
4. Startup folders (user + all users) -> `StartupApproved\StartupFolder`
5. Logon-triggered scheduled tasks (Edge auto-launch, updaters) -> disabled directly
6. Edge "startup boost" / background mode -> off by policy (Edge re-adds itself every update otherwise)

## Tiers

**DEFAULT (disabled without asking):** Edge / Chrome / Brave auto-launch, consumer Teams, Spotify, CCleaner,
iTunes helper, Adobe Creative Cloud + updaters, CyberLink, bundled McAfee/Norton, OEM assistants (SupportAssist,
TechHub, HP Support, Lenovo Now/Welcome, Acer Collection, MSI Companion, GlideX, QuickDrop), Skype, Java updater,
Booking/WildTangent promos.

**ASK FIRST (`-AlsoDisable 'Steam','Discord'`):** Steam, Epic, Discord, Battle.net, EA, Ubisoft, Riot, GOG,
OneDrive, Dropbox, Google Drive, iCloud, Zoom, Slack, Telegram/WhatsApp/Signal, Wallpaper Engine, Afterburner /
RTSS, OBS, Overwolf, Rainmeter, NZXT CAM, iCUE, SteelSeries, Razer Synapse, Armoury Crate, MyASUS, Vantage, OMEN,
Parsec, Plex, Backblaze, f.lux... Gamers often WANT Steam and Discord at login (friends list, downloads). Ask:
"Do you want Steam and Discord to open by themselves when the PC starts?"

**NEVER:** Windows Security tray, Realtek / Conexant / Dolby / Nahimic audio, NVIDIA / AMD / Intel graphics
trays, Synaptics / ELAN / Alps touchpad, Bluetooth, OEM hotkey helpers (ATK, HP Hotkey, Lenovo Utility, Dell
Power Manager), RT-Updater (VCDS) and Ross-Tech, wheel/pedal software (Fanatec, Thrustmaster, MOZA, Simucube,
Simagic, Logitech G HUB on gaming/sim machines), Elgato/Stream Deck, Citrix/VMware, ctfmon, OneDrive when
`keep.onedrive` is true, anything passed in `-Keep`.

## Procedure

```powershell
.\08-startup-cleanup.ps1 -Preview
.\08-startup-cleanup.ps1
.\08-startup-cleanup.ps1 -AlsoDisable 'Steam','Discord' -Keep 'Spotify'    # after asking
```

## Verifying

`Win32_StartupCommand` still lists disabled entries (gotchas #23). Use Task Manager > Startup apps, or the
"Startup entries" section of `15-verify.ps1`, which reads the StartupApproved flag and prints enabled/DISABLED.
