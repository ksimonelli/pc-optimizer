# 07-privacy.ps1
# Phase 07 - Privacy, telemetry, ads, Copilot/Recall. Registry only; every key is in the
# pre-flight backup (HKLM-Policies.reg, HKCU-*.reg) so it is fully reversible.
# Does NOT block outbound traffic or firewall anything (tuning suites and games need to phone home).
#
#   .\07-privacy.ps1                 apply
#   .\07-privacy.ps1 -DenyLocation   also deny location to all apps (NOT default on laptops: breaks Find My Device, weather, maps)

param([switch]$DenyLocation)
. "$PSScriptRoot\_common.ps1"
Assert-Admin
Start-PhaseLog '07-privacy'
Write-Head "PHASE 07: PRIVACY + TELEMETRY"
$p = Get-OptProfile

# --- telemetry / diagnostics ------------------------------------------------
Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection' 'AllowTelemetry' 0
Set-Reg 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection' 'AllowTelemetry' 0
Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection' 'DoNotShowFeedbackNotifications' 1
Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection' 'LimitDiagnosticLogCollection' 1
Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection' 'DisableOneSettingsDownloads' 1
Set-Reg 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Privacy' 'TailoredExperiencesWithDiagnosticDataEnabled' 0
Set-Reg 'HKCU:\SOFTWARE\Microsoft\Siuf\Rules' 'NumberOfSIUFInPeriod' 0
Write-Ok "Telemetry: minimum (Security/Required), feedback prompts off, tailored experiences off"

# --- advertising / suggestions ---------------------------------------------
Set-Reg 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\AdvertisingInfo' 'Enabled' 0
Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\AdvertisingInfo' 'DisabledByGroupPolicy' 1
$cdm = 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'
foreach ($v in 'SystemPaneSuggestionsEnabled','SubscribedContent-338388Enabled','SubscribedContent-338389Enabled','SubscribedContent-338393Enabled',
               'SubscribedContent-353694Enabled','SubscribedContent-353696Enabled','SubscribedContent-310093Enabled','SubscribedContent-314559Enabled',
               'RotatingLockScreenOverlayEnabled','SoftLandingEnabled','SilentInstalledAppsEnabled','PreInstalledAppsEnabled','OemPreInstalledAppsEnabled','ContentDeliveryAllowed') { Set-Reg $cdm $v 0 }
Set-Reg 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'Start_TrackProgs' 0
Set-Reg 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'Start_IrisRecommendations' 0
Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent' 'DisableWindowsConsumerFeatures' 1
Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent' 'DisableSoftLanding' 1
Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent' 'DisableThirdPartySuggestions' 1
Set-Reg 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\UserProfileEngagement' 'ScoobeSystemSettingEnabled' 0
Write-Ok "Advertising ID off, Start/lock-screen/Settings suggestions off, auto-installed promo apps off"

# --- search / Cortana / Copilot / Recall -----------------------------------
Set-Reg 'HKCU:\SOFTWARE\Policies\Microsoft\Windows\Explorer' 'DisableSearchBoxSuggestions' 1
Set-Reg 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Search' 'BingSearchEnabled' 0
Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search' 'AllowCortana' 0
Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot' 'TurnOffWindowsCopilot' 1
Set-Reg 'HKCU:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot' 'TurnOffWindowsCopilot' 1
Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI' 'DisableAIDataAnalysis' 1      # Recall (Copilot+ PCs); harmless elsewhere
Set-Reg 'HKCU:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI' 'DisableAIDataAnalysis' 1
Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI' 'AllowRecallEnablement' 0
Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Edge' 'HubsSidebarEnabled' 0                        # Edge Copilot sidebar
Write-Ok "Bing in Start off, Cortana off, Copilot off, Recall off"

# --- activity history / timeline -------------------------------------------
foreach ($v in 'EnableActivityFeed','PublishUserActivities','UploadUserActivities') { Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System' $v 0 }
Write-Ok "Activity history off"

# --- delivery optimization: LAN only (no uploads to the internet) ----------
Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization' 'DODownloadMode' 1
Write-Ok "Delivery Optimization: LAN only"

# --- location (opt-in) -----------------------------------------------------
if ($DenyLocation) {
    Set-Reg 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location' 'Value' 'Deny' 'String'
    Write-Ok "Location: denied for all apps"
} else { Write-Skip "Location left as-is (use -DenyLocation on a desktop if the user wants it off; laptops keep it for Find My Device)" }
# Camera / microphone are never touched: locking them breaks Zoom, Teams, Discord, browser calls.

# --- game mode / game DVR (profile-aware) ----------------------------------
if ($p.workloads.gaming) {
    Set-Reg 'HKCU:\Software\Microsoft\GameBar' 'AutoGameModeEnabled' 1
    Set-Reg 'HKCU:\Software\Microsoft\GameBar' 'AllowAutoGameMode' 1
    Set-Reg 'HKCU:\System\GameConfigStore' 'GameDVR_Enabled' 0              # background recording off; manual capture still works
    Write-Ok "Game Mode ON (gaming machine), background Game DVR recording OFF, Game Bar left available"
} else {
    Set-Reg 'HKCU:\Software\Microsoft\GameBar' 'AutoGameModeEnabled' 0
    Set-Reg 'HKCU:\Software\Microsoft\GameBar' 'AllowAutoGameMode' 0
    Set-Reg 'HKCU:\System\GameConfigStore' 'GameDVR_Enabled' 0
    Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR' 'AllowGameDVR' 0
    Write-Ok "Game Mode OFF, Game DVR OFF (non-gaming machine)"
}

# --- small usability wins (reversible) -------------------------------------
Set-Reg 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'HideFileExt' 0     # show file extensions (safer against fake .pdf.exe)
Set-Reg 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'ShowSyncProviderNotifications' 0   # OneDrive ads in Explorer
Write-Ok "File extensions shown, Explorer sync-provider ads off"

Write-Host ""
Write-Ok "Privacy settings applied. Explorer picks most of them up on next sign-in; nothing here needs a reboot on its own."
Stop-PhaseLog
