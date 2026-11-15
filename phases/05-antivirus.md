# Phase 05 - 3rd-Party Antivirus Removal

**Script:** `scripts/05-remove-mcafee.ps1` (McAfee; same pattern for Norton / Avast / AVG / Avira)
**Skip when:** `profile.thirdPartyAV` is empty (Defender only).

Pre-installed antivirus is slow (several services, constant scanning), naggy (subscription pop-ups, fake
alerts), usually expired, and redundant: Microsoft Defender is built in, free and good. Defender switches
itself back on automatically as soon as the third-party product is gone.

**Ask first if the AV is PAID and current** (the user bought Bitdefender/ESET/Kaspersky). That is their choice;
offer the facts, do not remove it unasked.

## McAfee

Products that come bundled: LiveSafe, Total Protection, Security Scan Plus, Safe Connect (VPN), WebAdvisor,
Personal Security (the Store stub).

1. `03-remove-apps.ps1` already removed the AppX stub.
2. `.\05-remove-mcafee.ps1 -Preview`, then `.\05-remove-mcafee.ps1`: runs each product's quiet uninstaller
   from the registry (never `Win32_Product`, gotchas #25), tries the winget ids, deletes `mfe*` / `mc*` / `NAP*`
   orphan services (gotchas #7).
3. Download and run **MCPR** (McAfee Consumer Product Removal) from mcafee.com for anything left.
4. The final reboot finishes it. `15-verify.ps1` re-checks for McAfee services and confirms Defender is active.

## Norton / Avast / AVG / Avira

1. Settings > Apps uninstall (or the uninstall string from `Get-InstalledPrograms`).
2. Vendor removal tool: Norton Remove and Reinstall tool, Avast Clear / AVG Clear, Avira Registry Cleaner.
3. After the final reboot, orphan sweep: `Get-CimInstance Win32_Service | Where-Object { $_.Name -match 'N360|Norton|avast|AVG|Avira' }`
   -> `sc.exe delete <Name>` for stopped services whose binary is gone.

## Confirm Defender

```powershell
Get-MpComputerStatus | Select-Object AMRunningMode, RealTimeProtectionEnabled, AntivirusEnabled, AntivirusSignatureLastUpdated
```
`RealTimeProtectionEnabled` and `AntivirusEnabled` must be True (fully true only after the reboot).

## Do NOT

- Disable Defender, tamper protection, SmartScreen or the firewall "for performance". Not on someone else's PC.
- Install a different third-party AV.
