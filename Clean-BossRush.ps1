<#
    Boss Rush practice cleanup for Bloons TD 6
    Resets the challenge-editor model that Boss Rush practice mods leave behind
    (income multiplier 0.25 etc.) directly in the local save file.

    Usage:  Clean-BossRush.ps1 [-GameDir <path>] [-Monke <path>] [-Full]
    Close the game first. A timestamped backup is written next to the save.
#>
param(
    [string]$GameDir = (Join-Path $env:USERPROFILE "AppData\LocalLow\Ninja Kiwi\BloonsTD6"),
    [string]$Monke   = (Join-Path $PSScriptRoot "monke.exe"),
    [switch]$Full
)

$ErrorActionPreference = "Stop"

function Fail($msg) { Write-Host "[X] $msg" -ForegroundColor Red; exit 1 }

Write-Host "=== Boss Rush practice cleanup ===" -ForegroundColor Cyan

if (-not (Test-Path $Monke)) { $Monke = Join-Path $PSScriptRoot "tools\monke.exe" }
if (-not (Test-Path $Monke)) { Fail "monke.exe not found: $Monke" }
if (-not (Test-Path $GameDir)) { Fail "game folder not found: $GameDir" }

$proc = Get-Process -Name "BloonsTD6" -ErrorAction SilentlyContinue
if ($proc) { Fail "Bloons TD 6 is running. Close it completely and run again." }

$save = Get-ChildItem -Path $GameDir -File |
        Where-Object { $_.Name -match '^Profile\.(Save|save|data|Data)$' } |
        Sort-Object @{Expression={ if ($_.Name -match '\.Save$') {0} else {1} }} |
        Select-Object -First 1
if (-not $save) {
    Write-Host "Files in $GameDir :" -ForegroundColor Yellow
    Get-ChildItem -Path $GameDir -File | Select-Object Name, Length | Format-Table | Out-String | Write-Host
    Fail "no Profile save file found"
}
Write-Host ("save   : " + $save.FullName + "  (" + $save.Length + " bytes)")
Write-Host ("monke  : " + $Monke)

$stamp  = Get-Date -Format "yyyyMMdd_HHmmss"
$backup = Join-Path $GameDir ("Profile.Save.cleanup-backup-" + $stamp)
Copy-Item -Path $save.FullName -Destination $backup -Force
Write-Host ("backup : " + $backup) -ForegroundColor Green

$json = Join-Path ([System.IO.Path]::GetTempPath()) ("btd6_profile_" + $stamp + ".json")
$out  = Join-Path ([System.IO.Path]::GetTempPath()) ("btd6_profile_" + $stamp + "_new.json")

& $Monke unpack $save.FullName -o $json --game btd6 --force | Out-Null
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
if ($Full) {
    $obj = [regex]::Replace($obj, '"popCashMultiplier"\s*:\s*[-0-9\.eE]+',   '"popCashMultiplier":1.0')
    $obj = [regex]::Replace($obj, '"roundCashMultiplier"\s*:\s*[-0-9\.eE]+', '"roundCashMultiplier":1.0')
    $obj = [regex]::Replace($obj, '"roundSets"\s*:\s*\[[^\]]*\]',           '"roundSets":["default"]')
}

if ($obj -eq $orig) {
    Write-Host "`n[i] nothing to change (already clean)" -ForegroundColor Green
    exit 0
}

Write-Host "`n-- after --" -ForegroundColor Yellow
Show-Values $obj "editor"

$text = $text.Substring(0, $start) + $obj + $text.Substring($end + 1)
$utf8 = New-Object System.Text.UTF8Encoding($true)
[System.IO.File]::WriteAllText($out, $text, $utf8)

& $Monke pack $out -o $save.FullName --game btd6 --force | Out-Null
if ($LASTEXITCODE -ne 0) {
    Copy-Item -Path $backup -Destination $save.FullName -Force
    Fail "pack failed - save restored from backup"
}

$check = Join-Path ([System.IO.Path]::GetTempPath()) ("btd6_profile_" + $stamp + "_check.json")
& $Monke unpack $save.FullName -o $check --game btd6 --force | Out-Null
$ver = [System.IO.File]::ReadAllText($check)
$v   = [regex]::Match($ver, '"challengeEditorModel"\s*:.*?"towerCashMultiplier"\s*:\s*([-0-9\.eE]+)')
Write-Host ("`n[OK] saved. challengeEditorModel.towerCashMultiplier = " + $(if ($v.Success) { $v.Groups[1].Value } else { "?" })) -ForegroundColor Green
Write-Host ("[i] backup kept at: " + $backup)
Write-Host "[i] Start the game and check tower income on a new challenge."
