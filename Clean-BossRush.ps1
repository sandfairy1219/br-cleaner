<#
    br-cleaner - Boss Rush practice cleanup for Bloons TD 6

    Practice mods write into the game's live challenge model, which the game persists in the
    profile: 25% tower income, the Endurance round set, a 999999 lives cap, extra revives and
    an end round 10000 past the start round. None of it is restored when the mod is removed.

    This edits the save file directly. No mod loader, nothing loaded into the game.

    Usage:
      Clean-BossRush.bat                 full cleanup (default)
      Clean-BossRush.bat -Check          print the current values, change nothing
      Clean-BossRush.bat -Minimal        income multipliers only
      Clean-BossRush.bat -Save <file>    use a specific Profile.Save
#>
param(
    [string]$GameDir   = $(if ($env:USERPROFILE) { $env:USERPROFILE + "\AppData\LocalLow\Ninja Kiwi\BloonsTD6" } else { "" }),
    [string]$Monke     = (Join-Path $PSScriptRoot "monke.exe"),
    [string]$Save      = "",
    [string[]]$SearchRoots = @(),
    [switch]$Minimal,
    [switch]$Check
)

$ErrorActionPreference = "Stop"

function Fail($msg) { Write-Host "[X] $msg" -ForegroundColor Red; exit 1 }

Write-Host "=== Boss Rush practice cleanup ===" -ForegroundColor Cyan

if (-not (Test-Path $Monke)) { $Monke = Join-Path $PSScriptRoot "tools\monke.exe" }
if (-not (Test-Path $Monke)) { Fail "monke.exe not found: $Monke" }

if (-not $Check) {
    $proc = Get-Process -Name "BloonsTD6" -ErrorAction SilentlyContinue
    if ($proc) { Fail "Bloons TD 6 is running. Close it completely and run again." }
}

# --- locate the profile save -------------------------------------------------
# Steam keeps it under userdata\<id>\960090\local\link\<guid>\; the LocalLow folder is
# often only a link stub, so every known root is searched.
$candidates = @()
if ($Save) {
    if (Test-Path $Save) { $candidates += Get-Item -LiteralPath $Save } else { Fail "save file not found: $Save" }
}

$roots = @()
$roots += $SearchRoots
$roots += $GameDir
if ($env:USERPROFILE) { $roots += ($env:USERPROFILE + "\AppData\LocalLow\Ninja Kiwi") }
if (${env:ProgramFiles(x86)}) { $roots += (${env:ProgramFiles(x86)} + "\Steam\userdata") }
if ($env:ProgramFiles)      { $roots += ($env:ProgramFiles + "\Steam\userdata") }
foreach ($d in @("D:","E:","F:","G:")) { $roots += ($d + "\Steam\userdata"); $roots += ($d + "\SteamLibrary\userdata") }

foreach ($root in ($roots | Where-Object { $_ } | Select-Object -Unique)) {
    if (-not (Test-Path $root)) { continue }
    $candidates += Get-ChildItem -Path $root -File -Force -Recurse -Depth 6 -ErrorAction SilentlyContinue |
                   Where-Object { $_.Name -match '^(profile\.(save|data)|Profile\.Save)$' }
}

if (-not $candidates) {
    Write-Host "No profile save found. Searched:" -ForegroundColor Yellow
    $roots | Where-Object { $_ } | Select-Object -Unique | ForEach-Object { Write-Host ("  " + $_) }
    Fail "no Profile save file found (pass -Save <path>)"
}

$saveFile = $candidates | Sort-Object LastWriteTime -Descending | Select-Object -First 1
if ($candidates.Count -gt 1) {
    Write-Host "`nseveral profile saves found, using the most recent:" -ForegroundColor Yellow
    $candidates | Sort-Object LastWriteTime -Descending | Select-Object -First 10 |
        ForEach-Object { Write-Host ("  " + $_.LastWriteTime + "  " + $_.FullName) }
    Write-Host "  (wrong one? pass -Save <full path>)" -ForegroundColor Yellow
}
Write-Host ("`nsave   : " + $saveFile.FullName)
Write-Host ("modified: " + $saveFile.LastWriteTime + "   (" + $saveFile.Length + " bytes)")
Write-Host ("monke   : " + $Monke)
if ($Check) { Write-Host "mode    : check only" } elseif ($Minimal) { Write-Host "mode    : minimal" } else { Write-Host "mode    : full" }

# --- unpack -----------------------------------------------------------------
$stamp = Get-Date -Format "yyyyMMdd_HHmmss"
$tmp   = [System.IO.Path]::GetTempPath()
$json  = Join-Path $tmp ("btd6_profile_" + $stamp + ".json")
$out   = Join-Path $tmp ("btd6_profile_" + $stamp + "_new.json")

& $Monke unpack $saveFile.FullName -o $json --game btd6 --force | Out-Null
if (-not (Test-Path $json)) { Fail "unpack failed (save format not supported) - nothing was changed" }
$text = [System.IO.File]::ReadAllText($json)

function Show-Hits($blob, $label) {
    $cash = [regex]::Matches($blob, '"cashModifiers"\s*:\s*(\{[^{}]*\})')
    $rules = [regex]::Matches($blob, '"startRules"\s*:\s*(\{[^{}]*\})')
    $rs = [regex]::Matches($blob, '"roundSets"\s*:\s*(\[[^\]]*\])')
    Write-Host ("  " + $label + ": cashModifiers x" + $cash.Count + "  startRules x" + $rules.Count + "  roundSets x" + $rs.Count)
    foreach ($m in ($cash | Select-Object -First 6)) { Write-Host ("    cash  " + $m.Groups[1].Value) }
    foreach ($m in ($rules | Select-Object -First 6)) { Write-Host ("    rules " + $m.Groups[1].Value) }
    foreach ($m in ($rs | Select-Object -First 6)) { Write-Host ("    rs    " + $m.Groups[1].Value) }
}

Write-Host "`n-- current --" -ForegroundColor Yellow
Show-Hits $text "profile"

# --- patch every occurrence, not only the editor draft ----------------------
$counts = @{}

function Swap($pattern, $replacement, $name) {
    $script:working = [regex]::Replace($script:working, $pattern, $replacement)
    $script:counts[$name] = ([regex]::Matches($script:orig, $pattern)).Count
}

$orig = $text
$working = $text

$working = [regex]::Replace($working, '"towerCashMultiplier"\s*:\s*0\.25\d*', '"towerCashMultiplier":1.0')

if (-not $Minimal) {
    $working = [regex]::Replace($working, '"popCashMultiplier"\s*:\s*0\.25\d*',   '"popCashMultiplier":1.0')
    $working = [regex]::Replace($working, '"roundCashMultiplier"\s*:\s*0\.25\d*', '"roundCashMultiplier":1.0')

    # round sets that still point at the practice round set
    $working = [regex]::Replace($working, '"roundSets"\s*:\s*\[[^\]]*EnduranceRoundSet[^\]]*\]', '"roundSets":["default"]')

    # start rules injected by the practice mods
    $working = [regex]::Replace($working, '"maxLives"\s*:\s*(\d{4,})', {
        param($mm) if ([int]$mm.Groups[1].Value -ge 9999) { '"maxLives":0' } else { $mm.Value }
    })
    $working = [regex]::Replace($working, '"endRound"\s*:\s*(\d+)', {
        param($mm) if ([int]$mm.Groups[1].Value -ge 1000) { '"endRound":100' } else { $mm.Value }
    })
    $working = [regex]::Replace($working, '"revives"\s*:\s*([1-9]\d*)', '"revives":0')
}

Write-Host "`n-- after --" -ForegroundColor Yellow
Show-Hits $working "patched"

if ($working -eq $orig) {
    Write-Host "`n[i] nothing to change (already clean)" -ForegroundColor Green
    exit 0
}

if ($Check) {
    Write-Host "`n[i] check only, the save was not written" -ForegroundColor Green
    exit 0
}

# --- write back -------------------------------------------------------------
$backup = Join-Path $saveFile.DirectoryName ("Profile.Save.cleanup-backup-" + $stamp)
Copy-Item -Path $saveFile.FullName -Destination $backup -Force
Write-Host ("`nbackup : " + $backup) -ForegroundColor Green

$utf8 = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($out, $working, $utf8)

& $Monke pack $out -o $saveFile.FullName --game btd6 --force | Out-Null
if ($LASTEXITCODE -ne 0) {
    Copy-Item -Path $backup -Destination $saveFile.FullName -Force
    Fail "pack failed - save restored from backup"
}

$verifyFile = Join-Path $tmp ("btd6_profile_" + $stamp + "_check.json")
& $Monke unpack $saveFile.FullName -o $verifyFile --game btd6 --force | Out-Null
$ver = [System.IO.File]::ReadAllText($verifyFile)
$left = ([regex]::Matches($ver, '"towerCashMultiplier"\s*:\s*([-0-9\.eE]+)')) |
        ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique

Write-Host "`n-- saved --" -ForegroundColor Green
Show-Hits $ver "profile"
Write-Host ("`ntowerCashMultiplier values now: " + ($left -join ", "))
Write-Host ("[OK] written to " + $saveFile.FullName)
Write-Host ("[i] backup: " + $backup)
Write-Host "[i] start the game, then run with -Check to confirm the values survived."
