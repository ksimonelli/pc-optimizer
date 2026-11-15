# _common.ps1 - shared helpers, dot-sourced by every phase script:
#     . "$PSScriptRoot\_common.ps1"
# Pure ASCII. Works on Windows PowerShell 5.1 and PowerShell 7.
# Nothing in this file changes the system.

Set-StrictMode -Off
$ErrorActionPreference = 'Continue'

# ---------------------------------------------------------------- paths
$script:ProjectRoot = Split-Path -Parent $PSScriptRoot
$script:LogDir      = Join-Path $ProjectRoot 'logs'
$script:BackupDir   = Join-Path $ProjectRoot 'backup'
$script:RunDir      = Join-Path $ProjectRoot 'run'
$script:ProfilePath = Join-Path $ProjectRoot 'profile.json'
foreach ($d in @($LogDir, $BackupDir, $RunDir)) {
    if (-not (Test-Path $d)) { New-Item -ItemType Directory -Path $d -Force | Out-Null }
}

# ---------------------------------------------------------------- output
function Write-Ok   ($msg) { Write-Host "[OK]   $msg" -ForegroundColor Green }
function Write-Info ($msg) { Write-Host "[..]   $msg" }
function Write-Warn ($msg) { Write-Host "[WARN] $msg" -ForegroundColor Yellow }
function Write-Fail ($msg) { Write-Host "[FAIL] $msg" -ForegroundColor Red }
function Write-Skip ($msg) { Write-Host "[SKIP] $msg" -ForegroundColor DarkGray }
function Write-Head ($msg) {
    Write-Host ""
    Write-Host "=== $msg ($(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')) ===" -ForegroundColor Cyan
}

# Tables piped through Format-Table are swallowed by some hosts (including the
# Claude Code tool runner) unless converted to a string first. Always use this.
function Out-Table {
    param([Parameter(ValueFromPipeline = $true)] $InputObject)
    begin { $items = @() }
    process { $items += $InputObject }
    end { if ($items.Count -gt 0) { $items | Format-Table -AutoSize -Wrap | Out-String -Width 200 | Write-Host } }
}

# ---------------------------------------------------------------- logging
function Start-PhaseLog ($name) {
    $path = Join-Path $LogDir "$name.log"
    try { Start-Transcript -Path $path -Append -Force | Out-Null } catch { }
    $script:PhaseLogPath = $path
}
function Stop-PhaseLog { try { Stop-Transcript | Out-Null } catch { } }

# ---------------------------------------------------------------- admin
function Test-Admin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    $p  = New-Object Security.Principal.WindowsPrincipal($id)
    return $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}
function Assert-Admin {
    if (-not (Test-Admin)) {
        Write-Fail "This script must run from an elevated (Administrator) terminal."
        exit 1
    }
}

# ---------------------------------------------------------------- registry
function Set-Reg {
    param([string]$Path, [string]$Name, $Value, [string]$Type = 'DWord')
    if (-not (Test-Path $Path)) { New-Item -Path $Path -Force | Out-Null }
    Set-ItemProperty -Path $Path -Name $Name -Value $Value -Type $Type -Force
}
function Get-RegValue {
    param([string]$Path, [string]$Name)
    try { return (Get-ItemProperty -Path $Path -Name $Name -ErrorAction Stop).$Name } catch { return $null }
}

# ---------------------------------------------------------------- inventory
# Installed programs from the uninstall registry keys (all three hives).
# NEVER use Win32_Product: it is slow and triggers MSI self-repair of every product.
function Get-InstalledPrograms {
    $keys = @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*'
    )
    Get-ItemProperty $keys -ErrorAction SilentlyContinue |
        Where-Object { $_.DisplayName } |
        Select-Object DisplayName, DisplayVersion, Publisher, InstallDate, UninstallString, QuietUninstallString,
            @{N='EstimatedMB';E={ if ($_.EstimatedSize) { [math]::Round($_.EstimatedSize/1024,0) } else { $null } }},
            @{N='KeyName';E={ $_.PSChildName }}
}

# Get-AppxPackage -AllUsers throws a TERMINATING "Access is denied" when not elevated,
# even with -ErrorAction SilentlyContinue. Fall back to the current user's packages.
function Get-AllAppx {
    try { return @(Get-AppxPackage -AllUsers -ErrorAction Stop) }
    catch { return @(Get-AppxPackage -ErrorAction SilentlyContinue) }
}

function Get-RamGB {
    $os = Get-CimInstance Win32_OperatingSystem
    return [pscustomobject]@{
        TotalGB = [math]::Round($os.TotalVisibleMemorySize/1MB, 1)
        UsedGB  = [math]::Round(($os.TotalVisibleMemorySize - $os.FreePhysicalMemory)/1MB, 2)
    }
}

# Media type (SSD / HDD / NVMe / Unspecified) of the disk that hosts C:
function Get-SystemDiskType {
    try {
        $disk = Get-Partition -DriveLetter C -ErrorAction Stop | Get-Disk -ErrorAction Stop
        $pd = Get-PhysicalDisk -ErrorAction Stop | Where-Object { $_.DeviceId -eq [string]$disk.Number } | Select-Object -First 1
        if ($pd) {
            if ($pd.BusType -eq 'NVMe') { return 'NVMe' }
            return [string]$pd.MediaType
        }
    } catch { }
    return 'Unknown'
}

function Test-Laptop {
    $chassis = (Get-CimInstance Win32_SystemEnclosure).ChassisTypes
    $laptopTypes = @(8,9,10,11,12,14,18,21,30,31,32)
    foreach ($c in $chassis) { if ($laptopTypes -contains $c) { return $true } }
    # fallback: a battery means a laptop
    if (Get-CimInstance Win32_Battery -ErrorAction SilentlyContinue) { return $true }
    return $false
}

function Test-OnBattery {
    $b = Get-CimInstance Win32_Battery -ErrorAction SilentlyContinue
    if (-not $b) { return $false }
    # BatteryStatus 2 = AC power
    return ($b.BatteryStatus -ne 2)
}

# ---------------------------------------------------------------- profile
# Phase 00 writes profile.json. Every later script reads it so that decisions
# (gaming, low RAM, flash-tuning, laptop...) are made once and used everywhere.
# Claude may edit profile.json by hand after confirming details with the user.
function Get-OptProfile {
    if (Test-Path $ProfilePath) {
        try { return (Get-Content $ProfilePath -Raw | ConvertFrom-Json) } catch { }
    }
    Write-Warn "profile.json not found or unreadable - run scripts\00-detect-system.ps1 first. Using minimal self-detection."
    $ram = Get-RamGB
    return [pscustomobject]@{
        hostname = $env:COMPUTERNAME; oemKey = 'unknown'; isLaptop = (Test-Laptop)
        ramGB = $ram.TotalGB; lowRam = ($ram.TotalGB -le 8.5); systemDiskType = (Get-SystemDiskType)
        hasDedicatedGpu = $false; gpuBrand = 'Unknown'; vramGB = 0
        workloads = [pscustomobject]@{ gaming=$false; simRacing=$false; streaming=$false; creative=$false; cad=$false; dev=$false; flashTuning=$false; office=$false }
        keep = [pscustomobject]@{ xbox=$true; printer=$true; onedrive=$true; touch=$true; biometric=$true; search=$true }
        thirdPartyAV = @()
    }
}

# ---------------------------------------------------------------- never-touch data
# Services that must never be disabled or deleted by this framework, whatever the profile.
$script:NeverTouchServices = @(
    # core / security / update
    'Audiosrv','AudioEndpointBuilder','PlugPlay','Power','ProfSvc','Themes','UserManager','Winmgmt','RpcSs','DcomLaunch',
    'wuauserv','BITS','CryptSvc','TrustedInstaller','UsoSvc','WaaSMedicSvc','DoSvc',
    'WinDefend','WdNisSvc','Sense','mpssvc','SecurityHealthService','wscsvc','BFE',
    'Dhcp','Dnscache','NlaSvc','nsi','LanmanWorkstation','WlanSvc','bthserv','BluetoothUserService',
    'hidserv','DeviceInstall','DsmSvc','StorSvc','EventLog','Schedule','SENS','ShellHWDetection','SystemEventsBroker','TimeBrokerSvc',
    'WpnService','WpnUserService','StateRepository','AppXSvc','ClipSVC','LicenseManager','InstallService','camsvc',
    # vendor hardware
    'RtkAudUService','NVDisplay.ContainerLocalSystem','AMD External Events Utility','igfxCUIService',
    # flash-tuning / serial stack (gotchas.md #21)
    'PcaSvc','serial','serenum','usbser','ftdibus','ftser2k',
    # enterprise VDI
    'CtxSvc','deviceTRUST'
)

# Scheduled tasks that must never be disabled (drive hotkeys, backlight, hardware).
$script:NeverTouchTasks = @(
    '\ATK Package',                       # ASUS Fn keys + keyboard backlight (gotchas.md #20)
    '\ASUS System Control Interface',     # ASUS hardware interface
    '\HP\*HotKey*','\Lenovo\*Hotkey*','\Dell\*Power*',
    '\Microsoft\Windows\Windows Defender\*','\Microsoft\Windows\WindowsUpdate\*','\Microsoft\Windows\UpdateOrchestrator\*',
    '\Microsoft\Windows\SystemRestore\*','\Microsoft\Windows\Defrag\*','\Microsoft\Windows\Maintenance\*'
)

function Test-NeverTouchService ($name) {
    foreach ($n in $NeverTouchServices) { if ($name -like $n) { return $true } }
    return $false
}
function Test-NeverTouchTask ($taskPath, $taskName) {
    $full = ($taskPath.TrimEnd('\') + '\' + $taskName)
    foreach ($p in $NeverTouchTasks) { if ($full -like $p) { return $true } }
    return $false
}

# Programs that signal a use case. Keep these regexes in one place.
$script:Detect = @{
    flashTuning = 'VCDS|Ross-Tech|HP Tuners|MPVI|EFILive|COBB|Accessport|SCT Performance|NefMoto|J2534|Tactrix|OpenPort|OBDeleven|VCP|ECUFlash|WinOLS|Forscan|BimmerCode|BMW Standard Tools|E-Sys|ISTA|Alientech|KESS|MPPS|Galletto|TOAD|Diagbox|ODIS|Techstream|HDS|IDS|FDRS'
    simRacing   = 'iRacing|Assetto|SimHub|Content Manager|Fanatec|Thrustmaster|MOZA|Simucube|rFactor|Automobilista|BeamNG|Dirt Rally|Forza|Gran Turismo|Simagic|Logitech G HUB|Crew Chief'
    creative    = 'DaVinci|Premiere|After Effects|Photoshop|Lightroom|Illustrator|CapCut|Blender|Vegas|Filmora|Audition|Affinity|GIMP|Krita|Cubase|FL Studio|Ableton|Reaper|Pro Tools'
    cad         = 'SolidWorks|AutoCAD|Fusion 360|Inventor|FreeCAD|SketchUp|Revit|Creo|CATIA|NX |Rhino|Onshape|KiCad|Altium'
    dev         = 'Visual Studio|JetBrains|PyCharm|IntelliJ|Rider|WebStorm|Docker|Node\.js|Python 3|Git version|Android Studio|Unity|Unreal|Godot|Postman'
    streaming   = 'OBS Studio|Streamlabs|XSplit|Elgato|NVIDIA Broadcast'
    office      = 'Microsoft 365|Microsoft Office|LibreOffice|Zoom|Microsoft Teams|Slack|Webex|QuickBooks|Sage'
    gamingApps  = 'Steam|Epic Games|GOG GALAXY|EA app|Ubisoft Connect|Battle\.net|Riot|Xbox|Rockstar Games Launcher|Minecraft'
}
