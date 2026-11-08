<#
    Boss Rush practice cleanup for Bloons TD 6
    Resets the challenge-editor model that Boss Rush practice mods leave behind
    (income multiplier 0.25 etc.) directly in the local save file.

    Usage:  Clean-BossRush.ps1 [-GameDir <path>] [-Save <file>] [-Monke <path>] [-Minimal]
            Default: full cleanup. -Minimal: income multiplier only.
    Close the game first. A timestamped backup is written next to the save.
#>
param(
    [string]$GameDir   = $(if ($env:USERPROFILE) { $env:USERPROFILE + "\AppData\LocalLow\Ninja Kiwi\BloonsTD6" } else { "" }),
    [string]$Monke     = (Join-Path $PSScriptRoot "monke.exe"),
    [string]$Save      = "",
    [string[]]$SearchRoots = @(),
    [switch]$Minimal
)

$ErrorActionPreference = "Stop"

function Fail($msg) { Write-Host "[X] $msg" -ForegroundColor Red; exit 1 }

Write-Host "=== Boss Rush practice cleanup ===" -ForegroundColor Cyan

if (-not (Test-Path $Monke)) { $Monke = Join-Path $PSScriptRoot "tools\monke.exe" }
if (-not (Test-Path $Monke)) { Fail "monke.exe not found: $Monke" }
# save location is searched below (Steam userdata, LocalLow, Epic)

$proc = Get-Process -Name "BloonsTD6" -ErrorAction SilentlyContinue
if ($proc) { Fail "Bloons TD 6 is running. Close it completely and run again." }

# Locate the profile save. Steam keeps it under userdata\<id>\960090\local\link\<guid>\
# and the LocalLow folder is often just a link stub, so search every known root.
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
    Write-Host "`nPass the file explicitly: Clean-BossRush.bat -Save <path to Profile.Save>" -ForegroundColor Yellow
    Fail "no Profile save file found"
}

$saveFile = $candidates | Sort-Object LastWriteTime -Descending | Select-Object -First 1
if ($candidates.Count -gt 1) {
    Write-Host "`nfound several profile saves, using the most recent:" -ForegroundColor Yellow
    $candidates | Sort-Object LastWriteTime -Descending | Select-Object -First 10 |
        ForEach-Object { Write-Host ("  " + $_.LastWriteTime + "  " + $_.FullName) }
    Write-Host "  (wrong one? pass -Save <full path>)" -ForegroundColor Yellow
}
Write-Host ("save   : " + $saveFile.FullName + "  (" + $saveFile.Length + " bytes)")
Write-Host ("monke  : " + $Monke)
if ($Minimal) { Write-Host "mode   : minimal (income only)" } else { Write-Host "mode   : full" }

$stamp  = Get-Date -Format "yyyyMMdd_HHmmss"
$backup = Join-Path $saveFile.DirectoryName ("Profile.Save.cleanup-backup-" + $stamp)
Copy-Item -Path $saveFile.FullName -Destination $backup -Force
Write-Host ("backup : " + $backup) -ForegroundColor Green

$json = Join-Path ([System.IO.Path]::GetTempPath()) ("btd6_profile_" + $stamp + ".json")
$out  = Join-Path ([System.IO.Path]::GetTempPath()) ("btd6_profile_" + $stamp + "_new.json")

& $Monke unpack $saveFile.FullName -o $json --game btd6 --force | Out-Null
if (-not (Test-Path $json)) { Fail "unpack failed" }

$text = [System.IO.File]::ReadAllText($json)

$m = [regex]::Match($text, '"challengeEditorModel"\s*:\s*\{')
if (-not $m.Success) { Fail "challengeEditorModel not found in the save (nothing to clean)" }

$start = $m.Index + $m.Length - 1
$depth = 0
$end = -1
for ($i = $start; $i -lt $text.Length; $i++) {
    $c = $text[$i]
    if ($c -eq '{') { $depth++ }
    elseif ($c -eq '}') { $depth--; if ($depth -eq 0) { $end = $i; break } }
}
if ($end -lt 0) { Fail "could not parse challengeEditorModel" }

$obj  = $text.Substring($start, $end - $start + 1)
$orig = $obj

function Show-Values($blob, $label) {
    $cash  = [regex]::Match($blob, '"cashModifiers"\s*:\s*(\{[^{}]*\})')
    $rules = [regex]::Match($blob, '"startRules"\s*:\s*(\{[^{}]*\})')
    $rs    = [regex]::Match($blob, '"roundSets"\s*:\s*(\[[^\]]*\])')
    Write-Host ("  " + $label + ".cashModifiers  " + $(if ($cash.Success) { $cash.Groups[1].Value } else { "(none)" }))
    Write-Host ("  " + $label + ".startRules      " + $(if ($rules.Success) { $rules.Groups[1].Value } else { "(none)" }))
    Write-Host ("  " + $label + ".roundSets       " + $(if ($rs.Success) { $rs.Groups[1].Value } else { "(none)" }))
}

Write-Host "`n-- before --" -ForegroundColor Yellow
Show-Values $obj "editor"

$obj = [regex]::Replace($obj, '"towerCashMultiplier"\s*:\s*[-0-9\.eE]+', '"towerCashMultiplier":1.0')

if (-not $Minimal) {
    $obj = [regex]::Replace($obj, '"popCashMultiplier"\s*:\s*[-0-9\.eE]+',   '"popCashMultiplier":1.0')
    $obj = [regex]::Replace($obj, '"roundCashMultiplier"\s*:\s*[-0-9\.eE]+', '"roundCashMultiplier":1.0')
    $obj = [regex]::Replace($obj, '"roundSets"\s*:\s*\[[^\]]*\]',           '"roundSets":["default"]')

    # start rules injected by the practice mods
    $obj = [regex]::Replace($obj, '"maxLives"\s*:\s*(\d{4,})', {
        param($mm)
        if ([int]$mm.Groups[1].Value -ge 9999) { '"maxLives":0' } else { $mm.Value }
    })
    $obj = [regex]::Replace($obj, '"endRound"\s*:\s*(\d+)', {
        param($mm)
        if ([int]$mm.Groups[1].Value -ge 1000) { '"endRound":100' } else { $mm.Value }
    })
    $obj = [regex]::Replace($obj, '"revives"\s*:\s*([1-9]\d*)', '"revives":0')
}

if ($obj -eq $orig) {
    Write-Host "`n[i] nothing to change (already clean)" -ForegroundColor Green
    exit 0
}

Write-Host "`n-- after --" -ForegroundColor Yellow
Show-Values $obj "editor"

$text = $text.Substring(0, $start) + $obj + $text.Substring($end + 1)
$utf8 = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($out, $text, $utf8)

& $Monke pack $out -o $saveFile.FullName --game btd6 --force | Out-Null
if ($LASTEXITCODE -ne 0) {
    Copy-Item -Path $backup -Destination $saveFile.FullName -Force
    Fail "pack failed - save restored from backup"
}

$check = Join-Path ([System.IO.Path]::GetTempPath()) ("btd6_profile_" + $stamp + "_check.json")
& $Monke unpack $saveFile.FullName -o $check --game btd6 --force | Out-Null
$ver = [System.IO.File]::ReadAllText($check)
$v   = [regex]::Match($ver, '"challengeEditorModel"\s*:.*?"towerCashMultiplier"\s*:\s*([-0-9\.eE]+)')
Write-Host ("`n[OK] saved. challengeEditorModel.towerCashMultiplier = " + $(if ($v.Success) { $v.Groups[1].Value } else { "?" })) -ForegroundColor Green
Write-Host ("[i] backup kept at: " + $backup)
Write-Host "[i] Start the game and check tower income on a new challenge."
