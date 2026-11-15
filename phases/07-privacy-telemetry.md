# Phase 07 - Privacy, Telemetry, Ads, Copilot / Recall

**Script:** `scripts/07-privacy.ps1`

Registry policies only. Every key is exported in the Phase 02 backup (`HKLM-Policies.reg`, `HKCU-*.reg`), so
the whole phase is reversible with a double-click. Nothing here blocks network traffic or breaks an app.

## What it sets

| Area | Keys (summary) |
|---|---|
| Telemetry | `AllowTelemetry = 0` (Security/Required), `DoNotShowFeedbackNotifications`, `LimitDiagnosticLogCollection`, `DisableOneSettingsDownloads`, tailored experiences off, SIUF feedback frequency 0 |
| Advertising | Advertising ID off (user + policy), ContentDeliveryManager suggestions/lock-screen Spotlight ads/silently-installed promo apps off, `DisableWindowsConsumerFeatures`, Start recommendations off, Settings "finish setup" nag off |
| Search / assistants | Bing in Start off, Cortana off, Copilot off (HKLM + HKCU policy), **Recall off** (`WindowsAI\DisableAIDataAnalysis`, `AllowRecallEnablement = 0` - relevant on Copilot+ PCs, harmless elsewhere), Edge Copilot sidebar off |
| Activity history | feed / publish / upload off |
| Delivery Optimization | `DODownloadMode = 1` (LAN only, no uploading updates to strangers) |
| Game Mode / DVR | from `profile.workloads.gaming`: gaming -> Game Mode ON, background recording OFF, Game Bar available; otherwise Game Mode OFF and Game DVR policy OFF |
| Usability | show file extensions (safer against `invoice.pdf.exe`), OneDrive ads in Explorer off |

## Deliberately NOT changed

- **Camera / microphone access** - locking them breaks Zoom, Teams, Discord, browser calls.
- **Location** - opt-in `-DenyLocation`. Laptops keep it for Find My Device, weather, maps, time zone.
- **Windows Update, SmartScreen, Defender cloud protection** - these are security, not telemetry.
- **Outbound firewall / hosts-file blocking** - breaks licensing for games, Adobe, tuning suites (gotchas #21).
- **Edge/Chrome telemetry inside the browser** - the user's browser settings are theirs.

## Notes

- Policy keys survive feature updates. Explorer picks the HKCU changes up at the next sign-in (the final reboot).
- On Windows 11 Home the `Policies` keys still work even though gpedit.msc is absent.
- If the user later wants Copilot back: delete `HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot`
  or import the backup `.reg`.
