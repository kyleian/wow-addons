[CmdletBinding()]
param(
    [string]$AddonName = "",
    [switch]$DryRun
)
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot   = Split-Path -Parent $PSScriptRoot
$configPath = Join-Path $repoRoot "config.json"
if (-not (Test-Path $configPath)) { Write-Error "config.json not found"; exit 1 }

$config     = Get-Content $configPath -Raw | ConvertFrom-Json
$addonsPath = $config.wow.addonsPath

if (-not (Test-Path $addonsPath)) {
    Write-Error "WoW AddOns path not found: $addonsPath"
    exit 1
}

if ($config.deployment.backupWtfOnDeploy -and -not $DryRun) {
    $bs = Join-Path $PSScriptRoot "backup-wtf.ps1"
    if (Test-Path $bs) {
        Write-Host "[deploy] Running WTF backup..." -ForegroundColor Cyan
        PowerShell -ExecutionPolicy Bypass -File $bs
    }
}

$addonsToDeploy = $config.addons | Where-Object { $_.enabled -eq $true }
if ($AddonName -ne "") {
    $addonsToDeploy = $addonsToDeploy | Where-Object { $_.name -eq $AddonName }
    if (-not $addonsToDeploy) { Write-Error "Addon '$AddonName' not found"; exit 1 }
}

$deployed = 0; $skipped = 0; $errors = 0

foreach ($addon in $addonsToDeploy) {
    $srcDir  = Join-Path $repoRoot $addon.sourceDir
    $destDir = Join-Path $addonsPath $addon.name

    if (-not (Test-Path $srcDir)) {
        Write-Warning "[deploy] SKIP $($addon.name) - source not found: $srcDir"
        $skipped++
        continue
    }

    if ($DryRun) {
        Write-Host "[DRY RUN] $srcDir -> $destDir" -ForegroundColor Yellow
        $deployed++
        continue
    }

    try {
        if (Test-Path $destDir) { Remove-Item $destDir -Recurse -Force }
        Copy-Item $srcDir $destDir -Recurse -Force
        Write-Host "[deploy] OK  $($addon.name) v$($addon.version)" -ForegroundColor Green
        $deployed++
    } catch {
        Write-Host "[deploy] FAIL $($addon.name): $_" -ForegroundColor Red
        $errors++
    }
}

Write-Host ""
if ($DryRun) {
    Write-Host "[deploy] Dry run: $deployed addon(s) would be deployed." -ForegroundColor Yellow
} else {
    Write-Host "[deploy] Done. $deployed deployed, $skipped skipped, $errors errors." -ForegroundColor Cyan
    if ($deployed -gt 0) { Write-Host "[deploy] Use /reload in-game to pick up changes." -ForegroundColor Gray }
}