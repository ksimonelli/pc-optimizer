# 01-system-info.ps1
# Phase 01 - Full system inventory. Read-only.
# Prints to the console and saves a copy to logs\inventory-<date>.txt so Claude can
# refer back to it (and the retrospective can quote the "before" state).

. "$PSScriptRoot\_common.ps1"
Start-PhaseLog '01-system-info'
Write-Head "PHASE 01: SYSTEM INVENTORY"
$inv = Join-Path $LogDir ("inventory-{0}.txt" -f (Get-Date -Format 'yyyyMMdd-HHmm'))
"INVENTORY $(Get-Date)" | Out-File $inv -Encoding ascii

function Section($title, $obj) {
    Write-Host ""; Write-Host "--- $title ---" -ForegroundColor Cyan
    $text = ($obj | Format-Table -AutoSize -Wrap | Out-String -Width 220)
    if (-not $text.Trim()) { $text = "(none)" }
    Write-Host $text
    "`n--- $title ---`n$text" | Out-File $inv -Append -Encoding ascii
}
function Line($s) { Write-Host $s; $s | Out-File $inv -Append -Encoding ascii }

$cs = Get-CimInstance Win32_ComputerSystem; $os = Get-CimInstance Win32_OperatingSystem
$cpu = Get-CimInstance Win32_Processor | Select-Object -First 1; $bios = Get-CimInstance Win32_BIOS
$ram = Get-RamGB
Line "Machine      : $($cs.Manufacturer) $($cs.Model)"
Line "CPU          : $($cpu.Name)"
Line "BIOS         : $($bios.SMBIOSBIOSVersion)"
Line "OS           : $($os.Caption) $(Get-RegValue 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' 'DisplayVersion') build $($os.BuildNumber)"
Line "Uptime       : $([math]::Round(((Get-Date) - $os.LastBootUpTime).TotalHours,1)) h"
Line "RAM          : $($ram.UsedGB) GB used / $($ram.TotalGB) GB"
Line "Pagefile     : automatic=$($cs.AutomaticManagedPagefile)"

Section "Memory modules" (Get-CimInstance Win32_PhysicalMemory | Select-Object @{N='GB';E={[math]::Round($_.Capacity/1GB,0)}}, Speed, Manufacturer, PartNumber)
Section "GPUs" (Get-CimInstance Win32_VideoController | Select-Object Name, DriverVersion, @{N='DriverDate';E={ if ($_.DriverDate) { $_.DriverDate.ToString('yyyy-MM-dd') } }}, CurrentHorizontalResolution, CurrentVerticalResolution, CurrentRefreshRate)
Section "Physical disks" (Get-PhysicalDisk | Select-Object FriendlyName, MediaType, BusType, HealthStatus, @{N='GB';E={[math]::Round($_.Size/1GB,0)}})
Section "Volumes" (Get-Volume | Where-Object DriveLetter | Select-Object DriveLetter, FileSystemLabel, FileSystem, @{N='FreeGB';E={[math]::Round($_.SizeRemaining/1GB,1)}}, @{N='TotalGB';E={[math]::Round($_.Size/1GB,1)}})
Section "Network adapters (up)" (Get-NetAdapter | Where-Object Status -eq 'Up' | Select-Object Name, InterfaceDescription, LinkSpeed)
Section "Antivirus (SecurityCenter2)" (Get-CimInstance -Namespace root/SecurityCenter2 -ClassName AntivirusProduct -ErrorAction SilentlyContinue | Select-Object displayName, productState)
Section "Defender status" (Get-MpComputerStatus -ErrorAction SilentlyContinue | Select-Object AMRunningMode, RealTimeProtectionEnabled, AntivirusEnabled, AntivirusSignatureLastUpdated)
Line "Power plan   : $(powercfg /getactivescheme)"
Line "Fast Startup : HiberbootEnabled=$(Get-RegValue 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power' 'HiberbootEnabled')"
Section "Printers" (Get-Printer -ErrorAction SilentlyContinue | Select-Object Name, DriverName, PortName)
Section "COM ports / serial devices" (Get-PnpDevice -Class Ports -PresentOnly -ErrorAction SilentlyContinue | Select-Object FriendlyName, Status)
Section "USB devices (present)" (Get-PnpDevice -Class USB,HIDClass -PresentOnly -ErrorAction SilentlyContinue | Where-Object { $_.FriendlyName -notmatch 'Root Hub|Composite|Generic|Host Controller' } | Select-Object FriendlyName, Class)

Section "Installed programs (registry)" (Get-InstalledPrograms | Sort-Object DisplayName | Select-Object DisplayName, DisplayVersion, Publisher, EstimatedMB)
Section "AppX packages (all users, non-framework)" (Get-AllAppx | Where-Object { -not $_.IsFramework -and $_.SignatureKind -ne 'System' } | Sort-Object Name | Select-Object Name, Version)
Section "Running services (non-Microsoft binaries)" (Get-CimInstance Win32_Service | Where-Object { $_.State -eq 'Running' -and $_.PathName -notlike '*\Windows\*' } | Select-Object Name, DisplayName, StartMode, PathName)
Section "Automatic services (all)" (Get-Service | Where-Object { $_.StartType -eq 'Automatic' } | Select-Object Name, Status, DisplayName)
Section "Startup entries" (Get-CimInstance Win32_StartupCommand | Select-Object Name, User, Location, Command)
Section "StartupApproved (Run)" (Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run' -ErrorAction SilentlyContinue | Select-Object * -ExcludeProperty PS*)
Section "Non-Microsoft scheduled tasks (enabled)" (Get-ScheduledTask | Where-Object { $_.TaskPath -notlike '\Microsoft\*' -and $_.State -ne 'Disabled' } | Select-Object TaskName, TaskPath, State)
Section "Top 15 processes by RAM" (Get-Process | Sort-Object WS -Descending | Select-Object -First 15 Name, @{N='RAM_MB';E={[math]::Round($_.WS/1MB,0)}}, Path)
Section "Pending reboot?" ([pscustomobject]@{
    CBSRebootPending = Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending'
    WURebootRequired = Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired'
    PendingFileRename = [bool](Get-RegValue 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager' 'PendingFileRenameOperations') })

Write-Host ""
Write-Ok "Inventory saved: $inv"
Stop-PhaseLog
