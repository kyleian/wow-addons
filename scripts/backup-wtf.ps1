[CmdletBinding()]
param( [int]$MaxBackups = 7 )
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot   = Split-Path -Parent $PSScriptRoot
$configPath = Join-Path $repoRoot "config.json"
if (-not (Test-Path $configPath)) { Write-Error "config.json not found"; exit 1 }

$config    = Get-Content $configPath -Raw | ConvertFrom-Json
$wtfPath   = $config.wow.wtfPath
$backupDir = Join-Path $repoRoot $config.deployment.wtfBackupDir

if (-not (Test-Path $wtfPath)) {
    Write-Warning "[backup-wtf] WTF path not found: $wtfPath"
    exit 0
}

if (-not (Test-Path $backupDir)) { New-Item -ItemType Directory -Path $backupDir -Force | Out-Null }

$timestamp  = Get-Date -Format "yyyy-MM-dd_HHmmss"
$destFolder = Join-Path $backupDir $timestamp

Write-Host "[backup-wtf] Backing up WTF to: $destFolder" -ForegroundColor Cyan
Copy-Item $wtfPath $destFolder -Recurse -Force
Write-Host "[backup-wtf] Backup complete." -ForegroundColor Green

$existing = Get-ChildItem $backupDir -Directory | Sort-Object Name
if ($existing.Count -gt $MaxBackups) {
    $toDelete = $existing | Select-Object -First ($existing.Count - $MaxBackups)
    foreach ($dir in $toDelete) {
        Write-Host "[backup-wtf] Removing old backup: $($dir.Name)" -ForegroundColor Gray
        Remove-Item $dir.FullName -Recurse -Force
    }
}
Write-Host "[backup-wtf] Done. $([Math]::Min($existing.Count, $MaxBackups)) backup(s) retained." -ForegroundColor Gray