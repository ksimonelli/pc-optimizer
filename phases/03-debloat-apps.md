# Phase 03 - Remove Bloatware Apps

**Script:** `scripts/03-remove-apps.ps1`

Removes and deprovisions Store (AppX) packages in three tiers so that the default is safe on any machine.
No internet downloads, no third-party debloat scripts: the user is trusting this folder, not a URL.

## Tiers

**SAFE (default)** - nobody misses these: Copilot + Copilot provider, Cortana, Bing News/Weather/Finance/Sports/Search,
Get Help, Tips, Feedback Hub, Solitaire/Mahjong/Minesweeper/Sudoku, Mixed Reality Portal, 3D Viewer, Paint 3D,
People, Skype, Power Automate, Office Hub, Dev Home, LinkedIn, Family Safety, Quick Assist, Widgets feed,
Clipchamp, and the pre-installed trials (Amazon, Prime Video, Disney+, Hulu, Netflix, Twitter, TikTok,
Facebook/Instagram, Candy Crush and friends, Dropbox OEM promo, Photoshop Express, McAfee stub).

**OPTIONAL (`-IncludeOptional`, ASK FIRST)** - real apps some people use: Mail & Calendar, new Outlook,
Phone Link, To Do, OneNote, Maps, Movies & TV, Spotify, consumer Teams, Roblox, Journal, Whiteboard.
Ask: "Do you use the Mail app? Phone Link to see your phone's texts? Spotify from the Store?" Keep any yes
with `-Keep 'Microsoft.YourPhone'`.

**XBOX (`-RemoveXbox`, non-gaming machines only)** - Xbox app, Game Bar, Xbox identity provider, TCUI,
speech-to-text overlay. On a gaming machine these are NOT bloat (gotchas #29): Game Pass, Minecraft sign-in
and some anti-cheat need them. The script refuses when `profile.keep.xbox` is true.

**Never** (listed in the script as a reminder): Store, Calculator, Photos, Snipping Tool, Notepad, Camera,
Terminal, Media Player, Sound Recorder, Sticky Notes, Alarms, Windows Security UI, classic Paint,
App Installer (winget), Store Purchase App, NVIDIA/Realtek/Intel control apps, OneDrive.

## Procedure

```powershell
.\03-remove-apps.ps1 -Preview                 # list what would go, change nothing
.\03-remove-apps.ps1                          # SAFE tier
.\03-remove-apps.ps1 -IncludeOptional -Keep 'Microsoft.YourPhone','microsoft.windowscommunicationsapps'
```

The script also hides the Widgets and Copilot taskbar buttons (cosmetic, reversible) and prints the remaining
non-Microsoft AppX packages for review.

## Why not Win11Debloat

The earlier version of this phase piped a remote script into PowerShell. On a stranger's machine that is a
trust problem and a reproducibility problem (the remote script changes). Everything useful it did is in
`03-remove-apps.ps1` + `07-privacy.ps1` + `08-startup-cleanup.ps1`, with a backup and a preview.

## After

Deprovisioning stops reinstalls for new accounts. Feature updates sometimes bring Copilot or Widgets back;
`15-verify.ps1` checks for Copilot and the user can simply re-run this script.
