# 12-gaming-network.ps1
# Phase 12 - Gaming + network tweaks. CONDITIONAL: only on machines where profile.workloads.gaming is true.
# Only evidence-backed, reversible tweaks (all keys are in the pre-flight backup):
#   - Nagle's algorithm off per active adapter (TcpAckFrequency / TCPNoDelay) - lower latency in online games
#   - NetworkThrottlingIndex off, SystemResponsiveness 10 (MMCSS gives the game more CPU)
#   - Game Mode on, background Game DVR recording off (also done in 07)
#   - optional: mouse acceleration off (-DisableMouseAccel: changes how the mouse feels - ask)
#   - optional: Defender exclusions for the Steam/Epic/GOG libraries (-DefenderExclusions: ask; excluded
#     folders are not scanned in real time)
#   - optional: DNS to Cloudflare (-Dns cloudflare) or Google (-Dns google) on all active adapters (ask)
# Deliberately NOT here: timer-resolution hacks, IRQ priority, Win32PrioritySeparation, global fullscreen
# optimization changes - no measurable benefit on Windows 11, some risk.

param([switch]$Preview, [switch]$DisableMouseAccel, [switch]$DefenderExclusions, [ValidateSet('','cloudflare','google')][string]$Dns = '')
. "$PSScriptRoot\_common.ps1"
Assert-Admin
Start-PhaseLog '12-gaming-network'
Write-Head "PHASE 12: GAMING + NETWORK"
$p = Get-OptProfile
if (-not $p.workloads.gaming) { Write-Warn "profile.workloads.gaming is false. Run 00-detect-system.ps1 -AddWorkload gaming if the user games on this machine."; Stop-PhaseLog; return }
function Step($desc, [scriptblock]$action) { if ($Preview) { Write-Info "would: $desc" } else { & $action; Write-Ok $desc } }

# ---------------------------------------------------------------- network
$ifs = 'HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces'
foreach ($a in (Get-NetAdapter | Where-Object Status -eq 'Up')) {
    $k = Join-Path $ifs $a.InterfaceGuid
    if (Test-Path $k) {
        Step "Nagle off on '$($a.Name)' ($($a.InterfaceDescription))" {
            Set-ItemProperty $k -Name 'TcpAckFrequency' -Value 1 -Type DWord -Force
            Set-ItemProperty $k -Name 'TCPNoDelay' -Value 1 -Type DWord -Force
            Set-ItemProperty $k -Name 'TcpDelAckTicks' -Value 0 -Type DWord -Force
        }
    }
}
Step "NetworkThrottlingIndex off, SystemResponsiveness 10" {
    Set-Reg 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile' 'NetworkThrottlingIndex' 0xffffffff
    Set-Reg 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile' 'SystemResponsiveness' 10
}
if ($Dns) {
    $servers = if ($Dns -eq 'cloudflare') { @('1.1.1.1','1.0.0.1') } else { @('8.8.8.8','8.8.4.4') }
    foreach ($a in (Get-NetAdapter | Where-Object Status -eq 'Up')) {
        Step "DNS on '$($a.Name)' -> $($servers -join ', ')" { Set-DnsClientServerAddress -InterfaceIndex $a.ifIndex -ServerAddresses $servers }
    }
} else { Write-Skip "DNS unchanged (-Dns cloudflare|google after asking; the router's DNS is usually fine)" }

# ---------------------------------------------------------------- game mode / DVR
Step "Game Mode ON, background recording OFF" {
    Set-Reg 'HKCU:\Software\Microsoft\GameBar' 'AutoGameModeEnabled' 1
    Set-Reg 'HKCU:\Software\Microsoft\GameBar' 'AllowAutoGameMode' 1
    Set-Reg 'HKCU:\System\GameConfigStore' 'GameDVR_Enabled' 0
}

# ---------------------------------------------------------------- input
if ($DisableMouseAccel) {
    Step "Mouse 'Enhance pointer precision' OFF" {
        Set-Reg 'HKCU:\Control Panel\Mouse' 'MouseSpeed' '0' 'String'
        Set-Reg 'HKCU:\Control Panel\Mouse' 'MouseThreshold1' '0' 'String'
        Set-Reg 'HKCU:\Control Panel\Mouse' 'MouseThreshold2' '0' 'String'
    }
} else { Write-Skip "Mouse acceleration unchanged (-DisableMouseAccel after asking - it changes the feel of the mouse; takes effect at next sign-in)" }

# ---------------------------------------------------------------- Defender exclusions (opt-in)
if ($DefenderExclusions) {
    $paths = @()
    $steam = Get-RegValue 'HKCU:\Software\Valve\Steam' 'SteamPath'
    if ($steam) {
        $steam = $steam -replace '/','\'
        $paths += Join-Path $steam 'steamapps'
        $vdf = Join-Path $steam 'steamapps\libraryfolders.vdf'
        if (Test-Path $vdf) { foreach ($m in ([regex]::Matches((Get-Content $vdf -Raw), '"path"\s+"([^"]+)"'))) { $paths += (Join-Path ($m.Groups[1].Value -replace '\\\\','\') 'steamapps') } }
    }
    foreach ($c in @('C:\Program Files\Epic Games','C:\Program Files (x86)\GOG Galaxy\Games','C:\Program Files\EA Games','C:\Program Files (x86)\Ubisoft Game Launcher\games','C:\Riot Games','C:\XboxGames','C:\Program Files (x86)\Battle.net')) { if (Test-Path $c) { $paths += $c } }
    $existing = @((Get-MpPreference).ExclusionPath)
    foreach ($path in ($paths | Where-Object { $_ -and (Test-Path $_) } | Select-Object -Unique)) {
        if ($existing -contains $path) { Write-Skip "already excluded: $path"; continue }
        Step "Defender exclusion: $path" { Add-MpPreference -ExclusionPath $path }
    }
    if (-not $paths) { Write-Skip "no game library folders found" }
} else { Write-Skip "Defender exclusions not requested (-DefenderExclusions after asking; only for big trusted game libraries)" }

Write-Host ""
Write-Host "MANUAL next (phases/11-gpu-display.md): NVIDIA/AMD control panel settings, G-Sync/FreeSync + frame cap, monitor refresh rate."
Write-Host "Sim racing (if applicable): USB selective suspend is handled in 10-performance.ps1; keep wheel/pedal software in startup."
Stop-PhaseLog
