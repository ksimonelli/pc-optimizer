# 04-oem-audit.ps1
# Phase 04 - OEM bloat audit for ANY manufacturer (ASUS, HP, Lenovo, Acer, MSI, Samsung, Razer...).
# Dell has its own script (04-oem-dell.ps1) because its removal needs special handling.
#
# DEFAULT IS REPORT-ONLY. It lists everything on the machine that carries the OEM's name and
# sorts it into three buckets:
#   BLOAT      - safe to remove (promos, "support assistants", registration nags, analytics)
#   ASK FIRST  - has a real function (fan curves, performance modes, battery limits, firmware
#                updates, RGB lighting). Remove only if the user says they do not use it.
#   KEEP       - hotkeys / Fn keys / hardware interface drivers. Never remove.
#
#   .\04-oem-audit.ps1              report
#   .\04-oem-audit.ps1 -Remove      remove the BLOAT bucket (AppX + silent Win32 uninstall where possible)
#   .\04-oem-audit.ps1 -Remove -Also 'MyASUS','GlideX'   also remove named ASK-FIRST items the user approved

param([switch]$Remove, [string[]]$Also = @())
. "$PSScriptRoot\_common.ps1"
Assert-Admin
Start-PhaseLog '04-oem-audit'
Write-Head "PHASE 04: OEM BLOAT AUDIT"
$p = Get-OptProfile
$oemKey = [string]$p.oemKey
Write-Host "OEM: $($p.oem) [$oemKey]"

# Known patterns per OEM. Matched against program names, AppX names, service display names and task names.
$rules = @{
    asus = @{
        keyword = 'ASUS|ROG|TUF|Armoury|ATK'
        bloat   = 'ASUS GlideX|GlideX|ASUS Live Update|AsusCertService|ASUSLinkNear|ASUS Link|ASUSSoftwareManager|ASUS Software Manager|ASUSOptimization|ASUS Optimization|ScreenXpert|ASUS Splendid|ASUS Smart Display|ASUS Product Registration|ASUS WebStorage|ASUS Welcome|GameSDK|McAfee|Norton|WPS Office'
        ask     = 'Armoury Crate|ArmouryCrate|MyASUS|GameFirst|Aura|LightingService|ASUS Framework Service|ROG Live Service|ASUS System Diagnosis|Sonic Studio|Sonic Radar|ASUS Battery Health'
        keep    = 'ATK Package|ATKACPI|ASUS System Control Interface|ASUS Keyboard Hotkeys|ASUS Input|ASUS Precision|ASUS NB Hotkey'
        note    = 'Armoury Crate controls fan curves / performance modes on ROG and TUF laptops; if the user removes it, suggest the open-source G-Helper instead. MyASUS is needed for some BIOS/firmware updates and battery charge limit. ATK Package drives Fn keys and keyboard backlight (gotchas.md #20).'
    }
    hp = @{
        keyword = 'HP |Hewlett|OMEN|HyperX'
        bloat   = 'HP Support Assistant|HP Wolf|HP Sure Sense|HP Sure Click|HP Sure Run|HP JumpStart|HP Smart|HP Print and Scan Doctor|HPPrintScanDoctor|HP Audio Switch|HP Documentation|HP Privacy Settings|HP QuickDrop|HP Easy Clean|HP Touchpoint|HP Registration|myHP|HP PC Hardware Diagnostics|HP Connection Optimizer|HP Notifications|HP Presence|McAfee|Norton|ExpressVPN|WildTangent|Dropbox promotion'
        ask     = 'OMEN Gaming Hub|OMEN Command Center|HP Command Center|HP Audio Control|Bang & Olufsen|HP System Information|HP Client Security|HP Device Access Manager'
        keep    = 'HP Hotkey|HP System Event Utility|HP Analytics driver|HP Universal Camera Driver|HP Inc. - Extension|HP PC Hardware'
        note    = 'OMEN Gaming Hub / HP Command Center set performance mode and fan behaviour on gaming models - ask first. HP Hotkey Support and System Event Utility drive Fn keys.'
    }
    lenovo = @{
        keyword = 'Lenovo|Legion|ThinkPad|IdeaPad|Yoga'
        bloat   = 'Lenovo Now|Lenovo Welcome|Lenovo Smart Appearance|Lenovo Smart Noise|Lenovo Service Bridge|Lenovo Migration Assistant|Lenovo Quick Clean|Lenovo Hotkeys Tips|Glance by Mirametrix|Lenovo Voice|Lenovo Companion|McAfee|Norton|WPS Office|Dropbox promotion'
        ask     = 'Lenovo Vantage|Commercial Vantage|Legion Zone|Lenovo Smart Performance|Lenovo Nerve|X-Rite|Dolby Access|Lenovo Utility'
        keep    = 'Lenovo Hotkeys|Lenovo Fn and Function|Lenovo Power Management|System Interface Foundation|Lenovo System Update|Lenovo Energy Management|Lenovo Pen Settings|Lenovo Keyboard'
        note    = 'Lenovo Vantage / Legion Zone set performance modes, fan curves and the battery charge threshold - ask first (on ThinkPads suggest Commercial Vantage, which is the same tool without ads).'
    }
    acer = @{
        keyword = 'Acer|Predator|Nitro'
        bloat   = 'Acer Collection|Acer Jumpstart|Acer Product Registration|Acer Configuration Manager|Acer UEIP|Acer Portal|abDocs|abFiles|abPhoto|Acer Care Center|Acer Purified Voice|Acer User Experience|McAfee|Norton|WildTangent|Booking.com|Amazon'
        ask     = 'PredatorSense|NitroSense|Acer Quick Access|Acer Control Center|Acer Display Widget|DTS Audio|Acer TrueHarmony'
        keep    = 'Acer Quick Access Service|Acer HotKey|Acer Launch Manager|Acer LM'
        note    = 'PredatorSense / NitroSense control fans and overclocking on gaming models; Quick Access / Launch Manager drive Fn keys - ask first.'
    }
    msi = @{
        keyword = 'MSI|Micro-Star|Dragon'
        bloat   = 'MSI App Player|MSI Companion|MSI Help Desk|MSI Register|MSI Software Installer|MSI Live Update|Nahimic Companion|Norton|McAfee|WildTangent|Cyberlink promotion'
        ask     = 'MSI Center|Dragon Center|MSI Afterburner|MSI True Color|Nahimic|SteelSeries Engine|SteelSeries GG|MSI Mystic Light|MSI Center Pro'
        keep    = 'System Control Manager|MSI SCM|MSI Foundation Service|MSI Central Service'
        note    = 'MSI Center / Dragon Center set fan and performance modes, SCM drives Fn keys - ask first.'
    }
    samsung = @{
        keyword = 'Samsung|Galaxy'
        bloat   = 'Samsung Update|Samsung Recovery promotion|Samsung Studio|Samsung TV Plus|Samsung Gallery|Samsung Notes|Samsung Flow|Samsung Quick Search|Samsung Screen Recorder|Samsung Live Message|Samsung Second Screen|Samsung Multi Control|Bixby|McAfee|Norton'
        ask     = 'Samsung Settings|Samsung Device Care|Samsung Security'
        keep    = 'Samsung System Support Service|Samsung System Event Controller|Samsung Hotkey'
        note    = 'Samsung Settings controls keyboard backlight, battery protection and Fn behaviour on Galaxy Book - ask first.'
    }
    razer = @{
        keyword = 'Razer'
        bloat   = 'Razer Cortex|Razer Game Booster|Razer Central promotion|Razer Chroma Connect'
        ask     = 'Razer Synapse|Razer Chroma|Razer Axon'
        keep    = 'Razer Synapse Service'
        note    = 'Razer Synapse sets keyboard lighting, fan modes and power on Blade laptops - ask first.'
    }
    gigabyte = @{
        keyword = 'Gigabyte|AORUS'
        bloat   = 'Gigabyte App Center promotion|Norton|McAfee'
        ask     = 'Gigabyte Control Center|AORUS Engine|RGB Fusion|Smart Manager|Gigabyte Control'
        keep    = 'Gigabyte Hotkey|Gigabyte Keyboard'
        note    = 'Gigabyte Control Center / AORUS Engine set fan and performance modes - ask first.'
    }
    microsoft = @{ keyword = 'Surface'; bloat = ''; ask = 'Surface App'; keep = 'Surface'; note = 'Surface devices ship almost clean. Leave Surface drivers and the Surface app.' }
    dell = @{ keyword = 'Dell|Alienware'; bloat = 'SupportAssist|TechHub|Dell Digital Delivery|Dell Customer Connect|Dell Mobile Connect|Cinema Guide|MyDell|Dell Optimizer|Waves MaxxAudio|Killer'; ask = 'Alienware Command Center|Dell Peripheral Manager|Dell Display Manager'; keep = 'Dell Power Manager|Dell Command Update|Dell Touchpad|Dell Thermal'; note = 'Use 04-oem-dell.ps1 for removal. Alienware Command Center controls fans/lighting on Alienware - ask first.' }
}
$r = $rules[$oemKey]
if (-not $r) {
    $r = @{ keyword = ($p.oem -split ' ')[0]; bloat = 'McAfee|Norton|WildTangent|Booking.com|ExpressVPN|Dropbox promotion|WPS Office'; ask = ''; keep = ''; note = "Unknown OEM '$($p.oem)' - generic audit only. Research each item before removing." }
}
Write-Host "Note: $($r.note)" -ForegroundColor Yellow
Write-Host ""

function Bucket($name) {
    if ($r.keep -and $name -match $r.keep) { return 'KEEP' }
    if ($r.ask  -and $name -match $r.ask)  { return 'ASK FIRST' }
    if ($r.bloat -and $name -match $r.bloat) { return 'BLOAT' }
    if ($name -match $r.keyword) { return 'UNKNOWN (research)' }
    return $null
}
$rows = @()
foreach ($x in (Get-InstalledPrograms)) { $b = Bucket $x.DisplayName; if ($b) { $rows += [pscustomobject]@{ Bucket=$b; Type='Program'; Name=$x.DisplayName; Detail=$x.Publisher; Ref=$x } } }
foreach ($x in (Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue)) { $b = Bucket "$($x.Name) $($x.Publisher)"; if ($b) { $rows += [pscustomobject]@{ Bucket=$b; Type='AppX'; Name=$x.Name; Detail=$x.Version; Ref=$x } } }
foreach ($x in (Get-CimInstance Win32_Service)) { $b = Bucket "$($x.Name) $($x.DisplayName)"; if ($b) { $rows += [pscustomobject]@{ Bucket=$b; Type='Service'; Name=$x.Name; Detail="$($x.State)/$($x.StartMode) $($x.DisplayName)"; Ref=$x } } }
foreach ($x in (Get-ScheduledTask | Where-Object { $_.State -ne 'Disabled' })) { $b = Bucket "$($x.TaskPath)$($x.TaskName)"; if ($b) { $rows += [pscustomobject]@{ Bucket=$b; Type='Task'; Name="$($x.TaskPath)$($x.TaskName)"; Detail=$x.State; Ref=$x } } }
foreach ($x in (Get-Process | Where-Object { $_.Path })) { $b = Bucket "$($x.Name) $($x.Path)"; if ($b) { $rows += [pscustomobject]@{ Bucket=$b; Type='Process'; Name=$x.Name; Detail=$x.Path; Ref=$x } } }

if (-not $rows) { Write-Ok "Nothing carrying the OEM name was found. Clean machine - skip this phase."; Stop-PhaseLog; return }
foreach ($b in 'KEEP','ASK FIRST','BLOAT','UNKNOWN (research)') {
    $set = $rows | Where-Object { $_.Bucket -eq $b }
    if ($set) { Write-Host "[$b]" -ForegroundColor $(if ($b -eq 'BLOAT') {'Yellow'} elseif ($b -eq 'KEEP') {'Green'} else {'Cyan'}); $set | Select-Object Type, Name, Detail | Out-Table }
}

if (-not $Remove) { Write-Host "REPORT ONLY. Re-run with -Remove to remove the BLOAT bucket (and -Also 'Name' for approved ASK-FIRST items)."; Stop-PhaseLog; return }

Write-Head "REMOVING OEM BLOAT"
$victims = @($rows | Where-Object { $row = $_; ($row.Bucket -eq 'BLOAT') -or ($row.Bucket -eq 'ASK FIRST' -and ($Also | Where-Object { $_ -and $row.Name -match [regex]::Escape($_) })) })
foreach ($v in $victims | Where-Object { $_.Type -eq 'Process' }) { try { Stop-Process -Id $v.Ref.Id -Force -ErrorAction Stop; Write-Ok "stopped process $($v.Name)" } catch { } }
foreach ($v in $victims | Where-Object { $_.Type -eq 'AppX' }) {
    try { $v.Ref | Remove-AppxPackage -AllUsers -ErrorAction Stop; Write-Ok "removed AppX $($v.Name)" } catch { Write-Warn "AppX $($v.Name): $($_.Exception.Message.Split("`n")[0])" }
    Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -eq $v.Name } | Remove-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Out-Null
}
foreach ($v in $victims | Where-Object { $_.Type -eq 'Program' }) {
    $cmd = $v.Ref.QuietUninstallString
    if (-not $cmd -and $v.Ref.UninstallString -match 'msiexec') { $cmd = ($v.Ref.UninstallString -replace '/I','/X' -replace '/i','/x') + ' /qn /norestart' }
    if ($cmd) {
        Write-Info "uninstalling $($v.Name): $cmd"
        try { Start-Process cmd.exe -ArgumentList "/c $cmd" -Wait -WindowStyle Hidden -ErrorAction Stop; Write-Ok "uninstalled $($v.Name)" } catch { Write-Warn "$($v.Name): $($_.Exception.Message)" }
    } else { Write-Warn "$($v.Name) has no silent uninstaller. Remove it via Settings > Apps, or: $($v.Ref.UninstallString)" }
}
foreach ($v in $victims | Where-Object { $_.Type -eq 'Task' }) { try { Disable-ScheduledTask -TaskPath $v.Ref.TaskPath -TaskName $v.Ref.TaskName -ErrorAction Stop | Out-Null; Write-Ok "disabled task $($v.Name)" } catch { } }
foreach ($v in $victims | Where-Object { $_.Type -eq 'Service' }) {
    if (Test-NeverTouchService $v.Name) { Write-Skip "never-touch service $($v.Name)"; continue }
    try { Stop-Service $v.Name -Force -ErrorAction SilentlyContinue; Set-Service $v.Name -StartupType Disabled -ErrorAction Stop; Write-Ok "disabled service $($v.Name) (not deleted - delete with sc.exe only once its program is gone)" } catch { Write-Warn "service $($v.Name): $($_.Exception.Message)" }
}
Write-Host ""
Write-Ok "OEM removal pass done. Re-run without -Remove to see what is left; check for orphan processes after the final reboot (gotchas.md #5, #17)."
Stop-PhaseLog
