# 03-remove-apps.ps1
# Phase 03 - Remove and deprovision pre-installed Store (AppX) bloat.
# Three tiers so the default is safe on ANY machine:
#   SAFE      - removed by default: ads, trials, promos, Copilot, Cortana, 3rd-party games, social apps
#   OPTIONAL  - only with -IncludeOptional (ASK THE USER FIRST): Mail, Phone Link, To Do, OneNote,
#               Spotify, consumer Teams, Movies & TV, Maps, Outlook (new), Roblox
#   XBOX      - only with -RemoveXbox AND profile.keep.xbox = false (Game Pass / Xbox app / Minecraft
#               sign-in need these; some anti-cheat needs GamingServices)
#
#   .\03-remove-apps.ps1 -Preview                       list what WOULD be removed, change nothing
#   .\03-remove-apps.ps1                                remove SAFE tier
#   .\03-remove-apps.ps1 -IncludeOptional -Keep 'Microsoft.YourPhone','SpotifyAB.SpotifyMusic'
#   .\03-remove-apps.ps1 -RemoveXbox                    (non-gaming machine, user confirmed)
# "Deprovision" means Windows will not reinstall the app for new user accounts either.

param([switch]$Preview, [switch]$IncludeOptional, [switch]$RemoveXbox, [string[]]$Keep = @())
. "$PSScriptRoot\_common.ps1"
Assert-Admin
Start-PhaseLog '03-remove-apps'
Write-Head "PHASE 03: REMOVE BLOATWARE APPS"
$p = Get-OptProfile

$safe = @(
    'Microsoft.Copilot', 'Microsoft.Windows.Ai.Copilot.Provider',
    'Microsoft.549981C3F5F10',                 # Cortana
    'Microsoft.BingNews', 'Microsoft.BingWeather', 'Microsoft.BingFinance', 'Microsoft.BingSports', 'Microsoft.BingSearch',
    'Microsoft.GetHelp', 'Microsoft.Getstarted', 'Microsoft.WindowsFeedbackHub',
    'Microsoft.MicrosoftSolitaireCollection', 'Microsoft.MicrosoftMahjong', 'Microsoft.MicrosoftMinesweeper', 'Microsoft.MicrosoftSudoku',
    'Microsoft.MixedReality.Portal', 'Microsoft.Microsoft3DViewer', 'Microsoft.MSPaint',   # MSPaint = Paint 3D, not classic Paint
    'Microsoft.People', 'Microsoft.SkypeApp', 'Microsoft.PowerAutomateDesktop', 'Microsoft.MicrosoftOfficeHub',
    'Microsoft.Windows.DevHome', 'Microsoft.LinkedIn',
    'MicrosoftCorporationII.MicrosoftFamily', 'MicrosoftCorporationII.QuickAssist',
    'MicrosoftWindows.Client.WebExperience',   # Widgets / news feed
    'Clipchamp.Clipchamp',
    'Amazon.com.Amazon', 'AmazonVideo.PrimeVideo', 'Disney.37853D22215B2', 'Hulu.HuluApp', 'Netflix.Netflix',
    '9E2F88E3.Twitter', 'TikTok.TikTok', 'Facebook.Facebook', 'Facebook.InstagramBeta', 'BytedancePte.Ltd.TikTok',
    'king.com.CandyCrushSaga', 'king.com.CandyCrushFriends', 'king.com.CandyCrushSodaSaga', 'king.com.BubbleWitch3Saga',
    'A278AB0D.MarchofEmpires', 'A278AB0D.DisneyMagicKingdoms', 'GAMELOFTSA.Asphalt8Airborne',
    'McAfee.McAfeeConsumerAppsSupport', 'C27EB4BA.DropboxOEM', 'AdobeSystemsIncorporated.AdobePhotoshopExpress',
    'Microsoft.Advertising.Xaml'
)
$optional = @(
    'microsoft.windowscommunicationsapps',    # Mail & Calendar (deprecated, but people still use it)
    'Microsoft.OutlookForWindows',            # new Outlook
    'Microsoft.YourPhone',                    # Phone Link
    'Microsoft.Todos', 'Microsoft.Office.OneNote',
    'Microsoft.WindowsMaps', 'Microsoft.ZuneVideo',   # Movies & TV is a default video player
    'SpotifyAB.SpotifyMusic', 'MSTeams', 'MicrosoftTeams',
    'ROBLOXCORPORATION.ROBLOX', 'Microsoft.MicrosoftJournal', 'Microsoft.Whiteboard'
)
$xbox = @('Microsoft.GamingApp','Microsoft.XboxApp','Microsoft.Xbox.TCUI','Microsoft.XboxGameOverlay',
          'Microsoft.XboxGamingOverlay','Microsoft.XboxIdentityProvider','Microsoft.XboxSpeechToTextOverlay')
# Never remove (listed so nobody adds them by mistake): Microsoft.WindowsStore, Microsoft.WindowsCalculator,
# Microsoft.Windows.Photos, Microsoft.ScreenSketch, Microsoft.WindowsNotepad, Microsoft.WindowsCamera,
# Microsoft.WindowsTerminal, Microsoft.ZuneMusic (Media Player), Microsoft.WindowsSoundRecorder,
# Microsoft.MicrosoftStickyNotes, Microsoft.WindowsAlarms, Microsoft.SecHealthUI, Microsoft.Paint,
# Microsoft.DesktopAppInstaller (winget), Microsoft.StorePurchaseApp, NVIDIA/Realtek/Intel control apps, OneDrive.

$targets = @($safe)
if ($IncludeOptional) { $targets += $optional } else { Write-Skip "OPTIONAL tier not included (Mail, Phone Link, To Do, OneNote, Spotify, Teams, Movies & TV...). Ask the user, then re-run with -IncludeOptional." }
if ($RemoveXbox) {
    if ($p.keep.xbox) { Write-Warn "profile.keep.xbox is TRUE (gaming machine or Xbox app in use) - Xbox apps KEPT. Edit profile.json if the user is sure." }
    else { $targets += $xbox }
} else { Write-Skip "Xbox apps kept (use -RemoveXbox on a non-gaming machine after asking)." }
$targets = $targets | Where-Object { $Keep -notcontains $_ } | Select-Object -Unique

$installed = Get-AllAppx
$prov = Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue
$removed = 0; $deprov = 0; $hits = @()
foreach ($name in $targets) {
    $pk = @($installed | Where-Object { $_.Name -eq $name })
    $pv = @($prov | Where-Object { $_.DisplayName -eq $name })
    if (-not $pk -and -not $pv) { continue }
    $hits += $name
    if ($Preview) { Write-Info "would remove: $name (installed=$($pk.Count) provisioned=$($pv.Count))"; continue }
    foreach ($x in $pk) {
        try { $x | Remove-AppxPackage -AllUsers -ErrorAction Stop; $removed++; Write-Ok "removed: $name" }
        catch { Write-Warn "could not remove $name : $($_.Exception.Message.Split("`n")[0])" }
    }
    foreach ($x in $pv) {
        try { $x | Remove-AppxProvisionedPackage -Online -ErrorAction Stop | Out-Null; $deprov++ } catch { }
    }
}
if (-not $hits) { Write-Ok "Nothing from the selected tiers is installed." }
if ($Preview) { Write-Host ""; Write-Host "PREVIEW ONLY - nothing removed. Candidates: $($hits.Count)" }
else { Write-Host ""; Write-Ok "Removed $removed package instances, deprovisioned $deprov." }

# Hide the Widgets button / Copilot button on the taskbar (cosmetic, reversible)
if (-not $Preview) {
    Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'TaskbarDa' 0
    Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'ShowCopilotButton' 0
}
Write-Host ""
Write-Host "Remaining non-system AppX (review for anything unexpected):"
Get-AllAppx | Where-Object { -not $_.IsFramework -and $_.SignatureKind -ne 'System' -and $_.Publisher -notlike '*Microsoft Corporation*' } |
    Sort-Object Name | Select-Object Name, Version | Out-Table
Stop-PhaseLog
