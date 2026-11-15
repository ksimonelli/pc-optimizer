# _lint.ps1 - run BEFORE executing any .ps1 (shipped or written during a session).
# Checks: (1) pure ASCII (gotchas.md #18 - PowerShell 5.1 -File reads BOM-less files as ANSI),
#         (2) parses without errors, (3) no Win32_Product, (4) no unguarded $env:TEMP wipe (gotchas #19).
#   .\_lint.ps1                 lint scripts\ and run\
#   .\_lint.ps1 C:\path\x.ps1   lint one file or folder
# Exit code 1 if anything fails.

param([string]$Path = '')
$root = Split-Path -Parent $PSScriptRoot
$targets = @()
if ($Path) { $targets = @(Get-ChildItem $Path -Filter *.ps1 -Recurse -File -ErrorAction SilentlyContinue); if (-not $targets -and (Test-Path $Path)) { $targets = @(Get-Item $Path) } }
else { $targets = @(Get-ChildItem (Join-Path $root 'scripts'),(Join-Path $root 'run') -Filter *.ps1 -File -ErrorAction SilentlyContinue) }
$fail = 0
foreach ($f in $targets) {
    if ($f.Name -eq '_lint.ps1') { continue }
    $problems = @()
    $bytes = [IO.File]::ReadAllBytes($f.FullName)
    $bad = @($bytes | Where-Object { $_ -gt 127 })
    if ($bad.Count) {
        $text = [IO.File]::ReadAllText($f.FullName, [Text.Encoding]::UTF8)
        $lines = $text -split "`n"
        for ($i = 0; $i -lt $lines.Count; $i++) { if ($lines[$i] -match '[^\x00-\x7F]') { $problems += "non-ASCII at line $($i+1)"; if ($problems.Count -ge 5) { break } } }
        if (-not $problems) { $problems += "non-ASCII bytes ($($bad.Count))" }
    }
    $errs = $null
    [System.Management.Automation.Language.Parser]::ParseFile($f.FullName, [ref]$null, [ref]$errs) | Out-Null
    foreach ($e in $errs) { $problems += "parse error line $($e.Extent.StartLineNumber): $($e.Message)" }
    $src = Get-Content $f.FullName -Raw
    if ($src -match '(Get-WmiObject|Get-CimInstance|-Class|-ClassName)[^\r\n]*Win32_Product') { $problems += 'queries Win32_Product (slow, triggers MSI repair) - use Get-InstalledPrograms' }
    if ($src -match 'Remove-Item\s+"?\$env:TEMP\\\*' -and $src -notmatch 'claude') { $problems += 'wipes $env:TEMP without the *\Temp\claude\* guard (gotchas #19)' }
    if ($problems) { $fail++; Write-Host "[FAIL] $($f.Name)" -ForegroundColor Red; foreach ($pr in $problems) { Write-Host "       $pr" } }
    else { Write-Host "[OK]   $($f.Name)" -ForegroundColor Green }
}
Write-Host ""
if ($fail) { Write-Host "$fail file(s) failed lint. Fix before running." -ForegroundColor Red; exit 1 }
Write-Host "All $($targets.Count) script(s) clean." -ForegroundColor Green
exit 0
