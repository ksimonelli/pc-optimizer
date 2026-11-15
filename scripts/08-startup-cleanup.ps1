# 08-startup-cleanup.ps1
# Phase 08 - Startup entries. Uses the same mechanism as Task Manager > Startup (the
# StartupApproved registry keys), so every change is reversible by the user in Task Manager
# and apps that re-add their Run value (Teams, Edge, Spotify) still stay disabled (gotchas #8).
# Nothing is deleted.
#
# Tiers:
#   DEFAULT    disabled without asking: browser auto-launch, consumer Teams, Spotify, updaters/nag tools,
#              OEM "assistants", CCleaner, iTunes helper
#   ASK FIRST  only with -AlsoDisable: Steam, Epic, Discord, Battle.net, EA, Ubisoft, Riot, GOG, OneDrive,
#              Dropbox, Google Drive, iCloud, Zoom, Slack, Wallpaper Engine, Afterburner/RTSS, OBS...
#   NEVER      Windows Security, audio/GPU/touchpad trays, Bluetooth, OEM hotkey helpers (ATK, HP, Lenovo),
#              RT-Updater (VCDS), wheel/pedal software, Citrix/VMware, anything in -Keep
#
#   .\08-startup-cleanup.ps1 -Preview
#   .\08-startup-cleanup.ps1
#   .\08-startup-cleanup.ps1 -AlsoDisable 'Steam','Discord' -Keep 'Spotify'

param([switch]$Preview, [string[]]$AlsoDisable = @(), [string[]]$Keep = @())
. "$PSScriptRoot\_common.ps1"
Assert-Admin
Start-PhaseLog '08-startup-cleanup'
Write-Head "PHASE 08: STARTUP CLEANUP"
$p = Get-OptProfile

$defaultRx = 'MicrosoftEdgeAutoLaunch|GoogleChromeAutoLaunch|BraveSoftware.*AutoLaunch|com\.squirrel\.Teams\.Teams|^Teams$|^Spotify|CCleaner|iTunesHelper|Booking|WildTangent|Adobe Creative Cloud|AdobeAAMUpdater|Acrobat Assistant|AdobeGCInvoker|CyberLink|McAfee|Norton|SupportAssist|TechHub|HP Support|HPSA|Lenovo Now|Lenovo Welcome|Acer Collection|MSI Companion|GlideX|Skype|Cortana|SunJavaUpdateSched|Logitech Download Assistant|KeePassXC.*Update|EpicGamesLauncher.*Promo|Opera.*Assistant|Greenshot.*Upd|Update\.exe --processStart|QuickDrop'
$askRx     = 'Steam|EpicGamesLauncher|Discord|Battle\.net|EADesktop|EA app|Ubisoft|UplayWebCore|RiotClient|GalaxyClient|OneDrive|Dropbox|GoogleDrive|Google Drive|iCloud|Zoom|Slack|Telegram|WhatsApp|Signal|Wallpaper Engine|wallpaper32|MSIAfterburner|RTSS|OBS|Overwolf|Rainmeter|Rocket League|NZXT CAM|Corsair iCUE|SteelSeries|Razer Synapse|Armoury Crate|MyASUS|Lenovo Vantage|OMEN|Parsec|Plex|Backblaze|Everything|ShareX|f\.lux|Lively'
$neverRx   = 'SecurityHealth|Windows Defender|Realtek|RtkAud|RAVCpl|RAVBg|NVIDIA|NvBackend|RadeonSoftware|AMD|igfx|Intel|Synaptics|SynTP|ETD|ELAN|Alps|ApointTray|ATK|ASUS System|HP Hotkey|HPSysInfo|Lenovo Hotkey|LenovoUtility|RT-Updater|Ross-Tech|Fanatec|Thrustmaster|MOZA|Simucube|Simagic|Bluetooth|BTTray|Citrix|VMware|WindowsTerminal|SecurityHealthSystray|ctfmon|Dell Power Manager|DPM|Conexant|Waves(?!.*MaxxAudio)|Dolby|Nahimic|Sonic|Cirrus|Elgato|Stream Deck'
if ($p.workloads.simRacing -or $p.workloads.gaming) { $neverRx += '|Logitech G HUB|LGHUB|lghub' }   # wheel / headset profiles
if ($p.keep.onedrive) { $neverRx += '|OneDrive' }

function Tier($name) {
    foreach ($k in $Keep) { if ($k -and $name -match [regex]::Escape($k)) { return 'KEEP (-Keep)' } }
    if ($name -match $neverRx) { return 'NEVER' }
    foreach ($a in $AlsoDisable) { if ($a -and $name -match [regex]::Escape($a)) { return 'DISABLE (approved)' } }
    if ($name -match $defaultRx) { return 'DISABLE' }
    if ($name -match $askRx) { return 'ASK FIRST' }
    return 'UNKNOWN (leave)'
}
$disabledFlag = [byte[]](0x03,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00)

# Run keys -> StartupApproved key that governs them
$sources = @(
    @{ Run='HKCU:\Software\Microsoft\Windows\CurrentVersion\Run';                 Approved='HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run' },
    @{ Run='HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run';                 Approved='HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run' },
    @{ Run='HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Run';     Approved='HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run32' }
)
$rows = @(); $changed = 0
foreach ($s in $sources) {
    $props = Get-ItemProperty $s.Run -ErrorAction SilentlyContinue
    if (-not $props) { continue }
    foreach ($prop in $props.PSObject.Properties | Where-Object { $_.Name -notlike 'PS*' }) {
        $name = $prop.Name; $cmd = [string]$prop.Value
        $cur = Get-RegValue $s.Approved $name
        $isDisabled = ($cur -and $cur[0] -ne 2)
        $tier = Tier "$name $cmd"
        $rows += [pscustomobject]@{ Tier=$tier; Entry=$name; Source=$s.Run.Split(':')[0]; Currently=$(if ($isDisabled) {'disabled'} else {'enabled'}); Command=$cmd }
        if ($tier -like 'DISABLE*' -and -not $isDisabled) {
            if ($Preview) { continue }
            if (-not (Test-Path $s.Approved)) { New-Item $s.Approved -Force | Out-Null }
            Set-ItemProperty $s.Approved -Name $name -Value $disabledFlag -Type Binary -Force
            $changed++
        }
    }
}
# Startup folders -> StartupApproved\StartupFolder (value name = shortcut file name)
$folders = @(
    @{ Path="$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup";     Approved='HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\StartupFolder' },
    @{ Path="$env:ProgramData\Microsoft\Windows\Start Menu\Programs\Startup"; Approved='HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\StartupFolder' }
)
foreach ($f in $folders) {
    foreach ($item in (Get-ChildItem $f.Path -File -ErrorAction SilentlyContinue | Where-Object { $_.Name -ne 'desktop.ini' })) {
        $cur = Get-RegValue $f.Approved $item.Name
        $isDisabled = ($cur -and $cur[0] -ne 2)
        $tier = Tier $item.BaseName
        $rows += [pscustomobject]@{ Tier=$tier; Entry=$item.Name; Source='StartupFolder'; Currently=$(if ($isDisabled) {'disabled'} else {'enabled'}); Command=$item.FullName }
        if ($tier -like 'DISABLE*' -and -not $isDisabled -and -not $Preview) {
            if (-not (Test-Path $f.Approved)) { New-Item $f.Approved -Force | Out-Null }
            Set-ItemProperty $f.Approved -Name $item.Name -Value $disabledFlag -Type Binary -Force; $changed++
        }
    }
}
$rows | Sort-Object Tier, Entry | Out-Table

# Logon-triggered scheduled tasks from the same vendors (Edge auto-launch, updaters that spawn at logon)
Write-Info "Logon-triggered tasks"
$taskRx = 'MicrosoftEdgeAutoLaunch|GoogleUpdateTaskUser.*UA|Spotify|CCleaner|Adobe.*Startup|McAfee|Norton|SupportAssist|HP Support|Lenovo Welcome'
foreach ($t in (Get-ScheduledTask | Where-Object { $_.State -ne 'Disabled' -and $_.TaskName -match $taskRx })) {
    if (Test-NeverTouchTask $t.TaskPath $t.TaskName) { continue }
    if ($Preview) { Write-Info "would disable task $($t.TaskPath)$($t.TaskName)"; continue }
    Disable-ScheduledTask -TaskPath $t.TaskPath -TaskName $t.TaskName -ErrorAction SilentlyContinue | Out-Null; Write-Ok "disabled task $($t.TaskName)"; $changed++
}
# Edge: no startup boost / background mode (policy; Edge otherwise re-adds itself every update)
if (-not $Preview) {
    Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Edge' 'StartupBoostEnabled' 0
    Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Edge' 'BackgroundModeEnabled' 0
    Write-Ok "Edge startup boost + background mode off (policy)"
}

Write-Host ""
if ($Preview) { Write-Host "PREVIEW ONLY. ASK FIRST entries need -AlsoDisable 'Name' after the user agrees." }
else { Write-Ok "Startup entries disabled: $changed. The user can re-enable any of them in Task Manager > Startup apps." }
Write-Host "Note: Win32_StartupCommand still lists disabled entries (it reads the Run key, not the approval flag) - gotchas.md #23."
Stop-PhaseLog
