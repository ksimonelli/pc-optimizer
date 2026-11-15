# Phase 06 - Services and Background Tasks

**Script:** `scripts/06-services.ps1`

Policy: **Manual, not Disabled.** Manual = does not auto-start, but anything that needs it can still start it
(zero breakage in every session so far). Disabled is reserved for pure telemetry / legacy services nothing
legitimate depends on. The never-touch list in `scripts/_common.ps1` is enforced inside the script.

## Decisions by profile

| Condition | Effect |
|---|---|
| `lowRam` or system disk is HDD, or `keep.sysmain` | SysMain (Superfetch) stays Automatic |
| `keep.printer` | Spooler + PrintNotify untouched |
| `keep.touch` | TabletInputService / TextInputManagementService untouched |
| `keep.biometric` | WbioSrv (Windows Hello) untouched |
| `keep.xbox` or gaming | Xbox services -> Manual (start on demand); GamingServices untouched; controller services untouched |
| laptop | RmSvc (radios/airplane mode) and lfsvc (location - Find My Device) untouched |
| flashTuning | PcaSvc untouched; serial/serenum/usbser/ftdibus never touched; PCA scheduled tasks kept |
| office / dev | WebClient (WebDAV) and CDPSvc (nearby share) untouched |
| creative / streaming | FrameServer (camera) untouched |
| `-DisableSearch` | WSearch -> Manual (only when the user says they never use Start-menu search) |
| `-DisableXbox` | GamingServices Start=4 via registry (gotchas #2) - refused when `keep.xbox` |

## Disabled (telemetry / legacy, nothing depends on them)

DiagTrack, dmwappushservice, RemoteRegistry, RetailDemo, Fax, wisvc (Insider), WMPNetworkSvc, MapsBroker,
AJRouter, PNRPsvc, p2psvc, p2pimsvc, PNRPAutoReg, NetTcpPortSharing, diagnosticshub.standardcollector.service,
SharedAccess (ICS).

## Manual (start on demand)

WerSvc, DiagSvc, WdiServiceHost, WdiSystemHost, PhoneSvc, lfsvc (desktop only), WalletService,
MessagingService, PrintNotify, SCardSvr, ScDeviceEnum, CscService, WpcMonSvc, TroubleshootingSvc,
wercplsupport, BcastDVRUserService, CDPSvc, SEMgrSvc, FrameServer, PerfHost, SSDPSRV, upnphost, fhsvc,
icssvc, RemoteAccess, SmsRouter, TapiSrv, WbioSrv, TabletInputService, TextInputManagementService, Spooler,
SysMain, XblAuthManager, XblGameSave, XboxNetApiSvc, XboxGipSvc, GameInputSvc, AdobeARMservice,
edgeupdate/edgeupdatem, GoogleUpdater/gupdate, MozillaMaintenance - each subject to the profile rules above.

## Never touch (excerpt - full list in `_common.ps1`)

Audio stack, PlugPlay/Power/ProfSvc/Themes, Windows Update (wuauserv, BITS, CryptSvc, TrustedInstaller, UsoSvc,
WaaSMedicSvc, DoSvc), Defender + firewall, networking (Dhcp, Dnscache, NlaSvc, nsi, WlanSvc, Bluetooth), hidserv,
WpnService (notifications), StateRepository/AppXSvc/ClipSVC/LicenseManager (Store + licensing), GPU vendor
services, Realtek audio service, PcaSvc, the serial/FTDI drivers, Citrix/deviceTRUST.

## Background tasks

Disables the Microsoft CEIP / Compatibility Appraiser / feedback / error-reporting / disk-diagnostic / maps /
family-safety / retail-demo / power-diagnostics tasks, and vendor nag tasks (NVIDIA telemetry + update checks,
Adobe updater, CCleaner, OneDrive standalone update, Edge browser-replacement). Never: `\ATK Package` (ASUS Fn
keys), OEM hotkey tasks, Defender, Windows Update, System Restore, Defrag, Maintenance.

## Orphan services

The script lists services whose binary is missing. Delete with `sc.exe delete <Name>` (gotchas #13) only after
confirming the program really is gone; never `Remove-Service` on PS 5.1.

## Procedure

```powershell
.\06-services.ps1 -Preview
.\06-services.ps1                     # [-DisableSearch] [-DisableXbox] after asking
```

RAM drops are only visible after the final reboot (stopped services keep their pages until then).
