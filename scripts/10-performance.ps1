# 10-performance.ps1
# Phase 10 - Power plan, USB/PCIe power management, visual effects, NTFS last-access, HAGS.
# Profile-aware. NEVER touches the pagefile (system-managed is right for low-RAM machines,
# and a user-sized pagefile is their choice).
#
#   .\10-performance.ps1 -Preview
#   .\10-performance.ps1
#   .\10-performance.ps1 -NoUsbSuspend     force USB selective suspend OFF (auto for flashTuning / simRacing)
#   .\10-performance.ps1 -HighPerformance  laptop: use High Performance plan (auto for gaming laptops)
#
# Decisions:
#   Desktop            -> Ultimate Performance (fallback High Performance), core parking off, sleep never
#   Laptop, gaming     -> High Performance; sleep never on AC, 30 min on battery
#   Laptop, other      -> keep Balanced (power-mode slider stays available), AC tweaks only
#   flashTuning/simRacing -> USB selective suspend OFF (AC+DC) + per-device USB power mgmt OFF + PCIe ASPM OFF
#   lowRam or no dGPU  -> visual effects: performance (keeps font smoothing + thumbnails)
#   dGPU >= 10 GB VRAM -> HAGS on (reboot applies it)

param([switch]$Preview, [switch]$NoUsbSuspend, [switch]$HighPerformance)
. "$PSScriptRoot\_common.ps1"
Assert-Admin
Start-PhaseLog '10-performance'
Write-Head "PHASE 10: POWER + PERFORMANCE"
$p = Get-OptProfile
function Step($desc, [scriptblock]$action) { if ($Preview) { Write-Info "would: $desc" } else { & $action; Write-Ok $desc } }

# powercfg GUIDs
$HP  = '8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c'; $ULT = 'e9a42b02-d5df-448d-aa00-03f14749eb61'; $BAL = '381b4222-f694-41f0-9685-ff5bb260df2e'
$SUB_USB='2a737441-1930-4402-8d77-b2bebba308a3'; $USBSEL='48e6b7a6-50f5-4782-a5d4-53bb8f07e226'
$SUB_PCI='501a4d13-42af-4429-9fd1-a8218c268e20'; $ASPM='ee12f906-d277-404b-b6da-e5fa1a576df5'
$SUB_DISK='0012ee47-9041-4b5d-9b77-535fba8b1442'; $DISKTO='6738e2c4-e8a5-4a42-b16a-e040e769756e'
$SUB_PROC='54533251-82be-4824-96c1-47b60b740d00'; $PROCMIN='893dee8e-2bef-41e0-89c6-b55d0929964c'; $PROCMAX='bc5038f7-23e0-4960-96da-33abaf5935ec'
$SUB_WIFI='19cbb8fa-5279-450e-9fac-8a3d5fedd0c1'; $WIFIPWR='12bbebe6-58d6-4636-95bb-3217ef867c1a'

# ---------------------------------------------------------------- 1. power plan
$plans = (powercfg /list) -join "`n"
if (-not $p.isLaptop) {
    Step "Desktop: Ultimate Performance plan" {
        $guid = $null
        if ($plans -match "([0-9a-f-]{36})\s+\(Ultimate Performance\)") { $guid = $matches[1] }
        else { $out = (powercfg -duplicatescheme $ULT 2>&1) -join ' '; if ($out -match '([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})') { $guid = $matches[1] } }
        if ($guid) { powercfg /setactive $guid | Out-Null } else { powercfg -duplicatescheme $HP 2>&1 | Out-Null; powercfg /setactive $HP | Out-Null }
    }
    Step "Desktop: core parking off, sleep never, display off 20 min, disk never" {
        powercfg -attributes SUB_PROCESSOR CPMINCORES -ATTRIB_HIDE 2>$null
        powercfg /setacvalueindex SCHEME_CURRENT SUB_PROCESSOR CPMINCORES 100 2>$null
        powercfg /change standby-timeout-ac 0; powercfg /change monitor-timeout-ac 20
        powercfg /setacvalueindex SCHEME_CURRENT $SUB_DISK $DISKTO 0
    }
} elseif ($HighPerformance -or $p.workloads.gaming) {
    Step "Laptop (gaming): High Performance plan" {
        if ($plans -notmatch $HP) { powercfg -duplicatescheme $HP 2>&1 | Out-Null }
        powercfg /setactive $HP | Out-Null
    }
    Step "Laptop: sleep never on AC / 30 min on battery, display 20 / 10 min, CPU max 100%" {
        powercfg /change standby-timeout-ac 0;  powercfg /change standby-timeout-dc 30
        powercfg /change monitor-timeout-ac 20; powercfg /change monitor-timeout-dc 10
        powercfg /change hibernate-timeout-ac 0
        powercfg /setacvalueindex SCHEME_CURRENT $SUB_PROC $PROCMAX 100; powercfg /setdcvalueindex SCHEME_CURRENT $SUB_PROC $PROCMAX 100
        powercfg /setacvalueindex SCHEME_CURRENT $SUB_PROC $PROCMIN 5
        powercfg /setacvalueindex SCHEME_CURRENT $SUB_WIFI $WIFIPWR 0
    }
} else {
    Step "Laptop (non-gaming): keep Balanced; AC = never sleep, display 20 min, CPU max 100%, Wi-Fi max perf" {
        powercfg /setactive $BAL 2>$null | Out-Null
        powercfg /change standby-timeout-ac 0; powercfg /change monitor-timeout-ac 20
        powercfg /setacvalueindex SCHEME_CURRENT $SUB_PROC $PROCMAX 100
        powercfg /setacvalueindex SCHEME_CURRENT $SUB_WIFI $WIFIPWR 0
    }
}

# ---------------------------------------------------------------- 2. USB / PCIe (flash-tuning + sim-racing safety)
$usbOff = $NoUsbSuspend -or $p.workloads.flashTuning -or $p.workloads.simRacing
if ($usbOff) {
    $why = if ($p.workloads.flashTuning) { 'flash-tuning: a USB port sleeping mid-flash can brick an ECU' } else { 'sim-racing / USB peripherals' }
    Step "USB selective suspend OFF (AC + DC) + global USB\DisableSelectiveSuspend=1  [$why]" {
        powercfg /setacvalueindex SCHEME_CURRENT $SUB_USB $USBSEL 0; powercfg /setdcvalueindex SCHEME_CURRENT $SUB_USB $USBSEL 0
        Set-Reg 'HKLM:\SYSTEM\CurrentControlSet\Services\USB' 'DisableSelectiveSuspend' 1
    }
    Step "PCI Express link state power management OFF (AC + DC)" {
        powercfg /setacvalueindex SCHEME_CURRENT $SUB_PCI $ASPM 0; powercfg /setdcvalueindex SCHEME_CURRENT $SUB_PCI $ASPM 0
    }
    Step "Per-device USB power management OFF (hubs, controllers, serial adapters)" {
        $n = 0
        Get-PnpDevice -Class USB,Ports -PresentOnly -ErrorAction SilentlyContinue | ForEach-Object {
            $k = "HKLM:\SYSTEM\CurrentControlSet\Enum\$($_.InstanceId)\Device Parameters"
            if (Test-Path $k) {
                foreach ($v in 'EnhancedPowerManagementEnabled','AllowIdleIrpInD3','DeviceSelectiveSuspended','SelectiveSuspendEnabled') {
                    Set-ItemProperty $k -Name $v -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
                }
                $n++
            }
        }
        Write-Host "  updated $n device parameter keys"
    }
} else { Write-Skip "USB selective suspend left at default (not flash-tuning / sim-racing; use -NoUsbSuspend to force)" }
if (-not $Preview) { powercfg /setactive SCHEME_CURRENT | Out-Null }

# ---------------------------------------------------------------- 3. visual effects
if ($p.lowRam -or -not $p.hasDedicatedGpu) {
    Step "Visual effects -> performance (animations/transparency off; font smoothing + thumbnails kept)" {
        Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects' 'VisualFXSetting' 3
        Set-Reg 'HKCU:\Control Panel\Desktop' 'FontSmoothing' '2' 'String'
        Set-Reg 'HKCU:\Control Panel\Desktop' 'DragFullWindows' '1' 'String'
        Set-Reg 'HKCU:\Control Panel\Desktop\WindowMetrics' 'MinAnimate' '0' 'String'
        Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'TaskbarAnimations' 0
        Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'IconsOnly' 0
        Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'ListviewShadow' 1
        Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize' 'EnableTransparency' 0
        Set-ItemProperty 'HKCU:\Control Panel\Desktop' -Name 'UserPreferencesMask' -Value ([byte[]](0x90,0x12,0x03,0x80,0x10,0x00,0x00,0x00)) -Type Binary -Force
    }
} else { Write-Skip "Visual effects left at default (dedicated GPU and enough RAM - the overhead is negligible)" }

# ---------------------------------------------------------------- 4. filesystem
Step "NTFS last-access timestamps off (fewer SSD writes)" { fsutil behavior set disablelastaccess 1 | Out-Null }

# ---------------------------------------------------------------- 5. HAGS
if ($p.hasDedicatedGpu) {
    $eligible = ($p.vramGB -ge 10) -or ($p.gpus.name -match 'RTX [3-5]0|RX [7-9][0-9]00')
    if ($eligible) { Step "HAGS on ($($p.gpuBrand), $($p.vramGB) GB VRAM) - takes effect after the final reboot" { Set-Reg 'HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers' 'HwSchMode' 2 } }
    else { Write-Skip "HAGS left off ($($p.vramGB) GB VRAM; it costs ~1 GB VRAM and gains little on this class of GPU)" }
} else { Write-Skip "HAGS: no dedicated GPU" }

# ---------------------------------------------------------------- 6. report (no changes)
Write-Host ""
Write-Host "Power plan now : $(powercfg /getactivescheme)"
$cs = Get-CimInstance Win32_ComputerSystem
Write-Host "Pagefile       : automatic=$($cs.AutomaticManagedPagefile) (left untouched)"
if (-not $cs.AutomaticManagedPagefile) { Write-Warn "Pagefile is manually sized. On $($p.ramGB) GB RAM, system-managed is usually best - mention it to the user, do not change it silently." }
Write-Host "SysMain        : $((Get-Service SysMain -ErrorAction SilentlyContinue).StartType) (decided in 06-services.ps1; kept on low RAM / HDD)"
$cpu = Get-CimInstance Win32_Processor | Select-Object -First 1
Write-Host "CPU clock      : $($cpu.CurrentClockSpeed) / $($cpu.MaxClockSpeed) MHz"
Stop-PhaseLog
