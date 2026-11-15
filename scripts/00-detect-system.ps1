# 00-detect-system.ps1
# Phase 00 - Detect hardware, OEM, OS and USE CASE; write profile.json; print the plan.
# Read-only. Safe to run as many times as you like.
#
#   .\00-detect-system.ps1                       detect and write profile.json
#   .\00-detect-system.ps1 -AddWorkload gaming   force a workload on (after asking the user)
#   .\00-detect-system.ps1 -RemoveWorkload dev   force a workload off
#
# Every later script reads profile.json, so fix the profile here (or edit the
# JSON by hand) before running anything that changes the system.

param(
    [string[]]$AddWorkload = @(),
    [string[]]$RemoveWorkload = @()
)
. "$PSScriptRoot\_common.ps1"
Start-PhaseLog '00-detect-system'
Write-Head "PHASE 00: SYSTEM DETECTION"

# ------------------------------------------------------------ hardware
$cs   = Get-CimInstance Win32_ComputerSystem
$os   = Get-CimInstance Win32_OperatingSystem
$cpu  = Get-CimInstance Win32_Processor | Select-Object -First 1
$bios = Get-CimInstance Win32_BIOS
$gpus = @(Get-CimInstance Win32_VideoController)
$ram  = Get-RamGB
$isLaptop = Test-Laptop
$diskType = Get-SystemDiskType

$oem = [string]$cs.Manufacturer
$oemKey = 'other'
if     ($oem -match 'Dell')                 { $oemKey = 'dell' }
elseif ($oem -match 'HP|Hewlett')           { $oemKey = 'hp' }
elseif ($oem -match 'LENOVO')               { $oemKey = 'lenovo' }
elseif ($oem -match 'ASUS')                 { $oemKey = 'asus' }
elseif ($oem -match 'Acer')                 { $oemKey = 'acer' }
elseif ($oem -match 'Micro-Star|MSI')       { $oemKey = 'msi' }
elseif ($oem -match 'Samsung')              { $oemKey = 'samsung' }
elseif ($oem -match 'Microsoft')            { $oemKey = 'microsoft' }
elseif ($oem -match 'Razer')                { $oemKey = 'razer' }
elseif ($oem -match 'Gigabyte')             { $oemKey = 'gigabyte' }
elseif ($oem -match 'To Be Filled|System manufacturer|Default string|^\s*$') { $oemKey = 'custom' }

$dedicated = $gpus | Where-Object { $_.Name -match 'NVIDIA|GeForce|RTX|GTX|Radeon RX|Radeon Pro|Arc A|Arc B' }
$gpuBrand = 'Integrated'
if     ($gpus.Name -match 'NVIDIA|GeForce')       { $gpuBrand = 'NVIDIA' }
elseif ($gpus.Name -match 'Radeon RX|Radeon Pro') { $gpuBrand = 'AMD' }
elseif ($gpus.Name -match 'Arc A|Arc B')          { $gpuBrand = 'Intel Arc' }
# AdapterRAM is a 32-bit field and caps at 4 GB; read the real size from the registry when possible.
$vramGB = 0
foreach ($g in $gpus) {
    $v = [math]::Round($g.AdapterRAM/1GB, 1)
    try {
        $k = Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}\0*' -ErrorAction SilentlyContinue |
             Where-Object { $_.DriverDesc -eq $g.Name } | Select-Object -First 1
        if ($k -and $k.'HardwareInformation.qwMemorySize') { $v = [math]::Round($k.'HardwareInformation.qwMemorySize'/1GB, 1) }
    } catch { }
    if ($v -gt $vramGB) { $vramGB = $v }
}

$displayVersion = Get-RegValue 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' 'DisplayVersion'
$ubr = Get-RegValue 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' 'UBR'
$osSupported = $true
if ($displayVersion -match '^(21H2|22H2|23H2)$' -and $os.Caption -match 'Home|Pro') { $osSupported = $false }
$secureBoot = 'n/a'
try { $secureBoot = [string](Confirm-SecureBootUEFI -ErrorAction Stop) } catch { }

Write-Host "Machine   : $oem $($cs.Model)  [oemKey=$oemKey]  $(if ($isLaptop) {'Laptop'} else {'Desktop'})"
Write-Host "CPU       : $($cpu.Name) ($($cpu.NumberOfCores)c/$($cpu.NumberOfLogicalProcessors)t)"
foreach ($g in $gpus) { Write-Host "GPU       : $($g.Name)  driver $($g.DriverVersion) ($(if ($g.DriverDate) { $g.DriverDate.ToString('yyyy-MM-dd') }))" }
Write-Host "GPU class : $gpuBrand  dedicated=$([bool]$dedicated)  VRAM=$vramGB GB"
Write-Host "RAM       : $($ram.UsedGB) GB used / $($ram.TotalGB) GB total"
Write-Host "System SSD: $diskType"
Write-Host "OS        : $($os.Caption) $displayVersion (build $($os.BuildNumber).$ubr)"
Write-Host "BIOS      : $($bios.SMBIOSBIOSVersion) ($(if ($bios.ReleaseDate) { $bios.ReleaseDate.ToString('yyyy-MM-dd') }))"
Write-Host "SecureBoot: $secureBoot"
if (-not $osSupported) { Write-Warn "Windows 11 $displayVersion no longer receives security updates. Recommend upgrading to the current release AFTER this optimization (separate task)." }

# ------------------------------------------------------------ antivirus
$av = @(Get-CimInstance -Namespace root/SecurityCenter2 -ClassName AntivirusProduct -ErrorAction SilentlyContinue |
        Where-Object { $_.displayName -notmatch 'Windows Defender|Microsoft Defender' } | ForEach-Object { $_.displayName })
if ($av.Count) { foreach ($a in $av) { Write-Warn "3rd-party antivirus: $a" } } else { Write-Ok "Antivirus: Microsoft Defender only" }

# ------------------------------------------------------------ workloads
$programs = @(Get-InstalledPrograms)
$names = ($programs | ForEach-Object { $_.DisplayName }) -join "`n"
$appx  = @(Get-AllAppx | ForEach-Object { $_.Name })
$appxText = $appx -join "`n"
$pnpNames = (Get-PnpDevice -PresentOnly -ErrorAction SilentlyContinue | ForEach-Object { $_.FriendlyName }) -join "`n"

$steamPath = Get-RegValue 'HKCU:\Software\Valve\Steam' 'SteamPath'
$hasGameLauncher = ($names -match $Detect.gamingApps) -or ($steamPath -and (Test-Path $steamPath)) -or
                   (Test-Path 'C:\Program Files (x86)\Steam') -or (Test-Path 'C:\Program Files\Epic Games') -or
                   (Test-Path "$env:ProgramData\Battle.net") -or ($appxText -match 'Microsoft.GamingApp')
$devCmd = Get-Command git,node,python,docker,code -ErrorAction SilentlyContinue
$w = [ordered]@{
    gaming      = [bool]$hasGameLauncher
    simRacing   = [bool](($names -match $Detect.simRacing) -or ($pnpNames -match 'Fanatec|Thrustmaster|Logitech G|MOZA|Simucube|Simagic|Wheel'))
    streaming   = [bool]($names -match $Detect.streaming)
    creative    = [bool](($names -match $Detect.creative) -or ($appxText -match 'CapCut|DaVinci|Blender'))
    cad         = [bool]($names -match $Detect.cad)
    dev         = [bool](($names -match $Detect.dev) -or $devCmd)
    flashTuning = [bool](($names -match $Detect.flashTuning) -or (Test-Path 'C:\Ross-Tech') -or ($pnpNames -match 'Ross-Tech|HEX-|J2534|Tactrix|FTDI|USB Serial Port'))
    office      = [bool](($names -match $Detect.office) -or ($appxText -match 'Microsoft.Office|MSTeams'))
}
foreach ($a in $AddWorkload)    { if ($w.Contains($a)) { $w[$a] = $true } else { Write-Warn "Unknown workload '$a' (valid: $($w.Keys -join ', '))" } }
foreach ($r in $RemoveWorkload) { if ($w.Contains($r)) { $w[$r] = $false } }
if ($w.simRacing) { $w.gaming = $true }

Write-Host ""
Write-Host "Workloads detected:"
foreach ($k in $w.Keys) { Write-Host ("  [{0}] {1}" -f $(if ($w[$k]) {'x'} else {' '}), $k) }
if (-not ($w.Values -contains $true)) { Write-Host "  (none detected - treating as general / office use)" }

# ------------------------------------------------------------ keep-flags
# Things the user relies on that a careless optimization breaks.
$printers = @(Get-Printer -ErrorAction SilentlyContinue | Where-Object { $_.Name -notmatch 'Microsoft|OneNote|Fax|PDF|XPS' })
$xboxApp  = [bool]($appxText -match 'Microsoft.GamingApp|Microsoft.XboxApp')
$odFolder = Get-RegValue 'HKCU:\Software\Microsoft\OneDrive\Accounts\Personal' 'UserFolder'
$onedrive = [bool]((Get-Process OneDrive -ErrorAction SilentlyContinue) -or ($odFolder -and (Test-Path $odFolder)))
$touch    = [bool](Get-PnpDevice -PresentOnly -ErrorAction SilentlyContinue | Where-Object { $_.Class -eq 'HIDClass' -and $_.FriendlyName -match 'touch screen|pen' })
$bio      = [bool](Get-PnpDevice -PresentOnly -ErrorAction SilentlyContinue | Where-Object { $_.Class -eq 'Biometric' })
$keep = [ordered]@{
    xbox      = ($xboxApp -or $w.gaming)   # keep Xbox services startable (Game Pass, Xbox app, some anti-cheat)
    printer   = ($printers.Count -gt 0)    # keep Print Spooler
    onedrive  = $onedrive                  # never remove OneDrive from startup without asking
    touch     = $touch                     # keep TabletInputService / TextInputManagement
    biometric = $bio                       # keep WbioSrv (Windows Hello)
    search    = $true                      # Windows Search stays ON unless the user says they never use it
    sysmain   = ($ram.TotalGB -le 8.5 -or $diskType -eq 'HDD')   # SysMain helps on low RAM or spinning disk
}
Write-Host ""
Write-Host "Keep-flags (what we must NOT break):"
foreach ($k in $keep.Keys) { Write-Host ("  [{0}] {1}" -f $(if ($keep[$k]) {'x'} else {' '}), $k) }
if ($printers.Count) { Write-Host "  printers: $($printers.Name -join ', ')" }

# ------------------------------------------------------------ profile.json
$gpuList = @()
foreach ($g in $gpus) { $gpuList += [ordered]@{ name=[string]$g.Name; driver=[string]$g.DriverVersion; driverDate=$(if ($g.DriverDate) { $g.DriverDate.ToString('yyyy-MM-dd') } else { '' }) } }
$prof = [ordered]@{
    detectedAt      = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
    hostname        = $env:COMPUTERNAME
    user            = $env:USERNAME
    oem             = $oem
    oemKey          = $oemKey
    model           = [string]$cs.Model
    isLaptop        = $isLaptop
    cpu             = [string]$cpu.Name
    gpus            = $gpuList
    gpuBrand        = $gpuBrand
    hasDedicatedGpu = [bool]$dedicated
    vramGB          = $vramGB
    ramGB           = $ram.TotalGB
    lowRam          = ($ram.TotalGB -le 8.5)
    systemDiskType  = $diskType
    osCaption       = [string]$os.Caption
    osVersion       = [string]$displayVersion
    osBuild         = "$($os.BuildNumber).$ubr"
    osSupported     = $osSupported
    secureBoot      = $secureBoot
    biosVersion     = [string]$bios.SMBIOSBIOSVersion
    thirdPartyAV    = $av
    workloads       = $w
    keep            = $keep
    baseline        = [ordered]@{ ramUsedGB = $ram.UsedGB; cFreeGB = [math]::Round((Get-PSDrive C).Free/1GB,1)
                                  startupEntries = (Get-CimInstance Win32_StartupCommand | Measure-Object).Count
                                  appxCount = $appx.Count; programCount = $programs.Count }
}
$prof | ConvertTo-Json -Depth 6 | Out-File $ProfilePath -Encoding ascii -Force
Write-Ok "profile.json written: $ProfilePath"

# ------------------------------------------------------------ plan
$oemPlan = "04-oem-audit.ps1 (report first, then remove only confirmed bloat) [$oemKey]"
if ($oemKey -eq 'dell')   { $oemPlan = '04-oem-dell.ps1 (SupportAssist, TechHub, Waves, Killer)' }
if ($oemKey -eq 'custom') { $oemPlan = 'SKIP - custom build' }
$flagsOn = @()
if ($prof.lowRam)           { $flagsOn += 'LOW-RAM (<=8 GB): keep SysMain + Search, leave pagefile system-managed, visual effects -> performance' }
if ($w.flashTuning)         { $flagsOn += 'FLASH-TUNING: USB selective suspend OFF, PCIe ASPM OFF, keep serial/FTDI/PcaSvc/.NET 3.5, no outbound blocking, Defender exclusions for tuning dirs' }
if ($w.simRacing)           { $flagsOn += 'SIM-RACING: USB selective suspend OFF, keep wheel/pedal software in startup' }
if ($isLaptop)              { $flagsOn += 'LAPTOP: keep hibernate + sleep on battery, High Performance only on AC, BIOS flash only on charger' }
if (-not $osSupported)      { $flagsOn += 'OS OUT OF SUPPORT: recommend feature update after optimization' }

function Mark($on) { if ($on) { '[x] ' } else { '[-] ' } }
Write-Host ""
Write-Host "=== OPTIMIZATION PLAN FOR $env:COMPUTERNAME ===" -ForegroundColor Cyan
Write-Host "  [x] 01 System inventory              01-system-info.ps1"
Write-Host "  [x] 02 Pre-flight + backups           02-preflight.ps1"
Write-Host "  [x] 03 Remove bloatware apps          03-remove-apps.ps1 $(if ($keep.xbox) {'(Xbox apps KEPT)'} else {'(-RemoveXbox allowed)'})"
Write-Host "  $(Mark ($oemKey -ne 'custom'))04 OEM bloat                     $oemPlan"
Write-Host "  $(Mark ($av.Count -gt 0))05 3rd-party AV removal          $(if ($av.Count) { $av -join ', ' } else { 'SKIP - Defender only' })"
Write-Host "  [x] 06 Services + background tasks    06-services.ps1"
Write-Host "  [x] 07 Privacy + telemetry            07-privacy.ps1"
Write-Host "  [x] 08 Startup cleanup                08-startup-cleanup.ps1"
Write-Host "  [x] 09 Updates (no reboot)            09-updates.ps1"
Write-Host "  [x] 10 Power + performance            10-performance.ps1"
Write-Host "  $(Mark ([bool]$dedicated))11 GPU + display                 $(if ($dedicated) { "$gpuBrand - manual (control panel)" } else { 'SKIP - integrated graphics' })"
Write-Host "  $(Mark $w.gaming)12 Gaming + network              $(if ($w.gaming) { '12-gaming-network.ps1' } else { 'SKIP - not a gaming machine' })"
Write-Host "  $(Mark ($w.dev -or $w.cad -or $w.creative))13 Dev / CAD / creative          $(if ($w.dev -or $w.cad -or $w.creative) { 'manual (phases/13-dev-tools.md)' } else { 'SKIP' })"
Write-Host "  [x] 14 Disk cleanup                   14-disk-cleanup.ps1"
Write-Host "  [x] 15 Verification                   15-verify.ps1 (+ post-reboot auto-run)"
Write-Host "  [x] 16 Session retrospective          (Claude writes it)"
if ($flagsOn.Count) {
    Write-Host ""
    Write-Host "Profile rules in force:" -ForegroundColor Yellow
    foreach ($f in $flagsOn) { Write-Host "  * $f" -ForegroundColor Yellow }
}
Write-Host ""
Write-Host "CONFIRM WITH THE USER before continuing: the workloads above, whether they use Xbox/Game Pass, OneDrive, a printer, and Windows Search."
Stop-PhaseLog
