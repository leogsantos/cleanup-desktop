param(
    [Parameter(Mandatory=$false)]
    [ValidateSet("clean-temp","empty-trash","update-apps","update-drivers","repair-system","run-all")]
    [string]$Command = "run-all"
)

$scriptDir = $PSScriptRoot
$configPath = Join-Path $scriptDir 'config.json'

if (!(Test-Path $configPath)) {
    $configPath = Join-Path (Split-Path -Parent $scriptDir) 'config.json'
}

if (!(Test-Path $configPath)) {
    throw "config.json não encontrado"
}

$root = Split-Path -Parent $configPath
$logDir = Join-Path $root 'logs'

if (!(Test-Path $logDir)) {
    New-Item -ItemType Directory -Path $logDir | Out-Null
}

$logFile = Join-Path $logDir "execution_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"

function Write-Log {
    param([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $line = "$timestamp - $Message"
    $line | Out-File -Append $logFile
    Write-Host $line
}

$config = Get-Content $configPath | ConvertFrom-Json

# Log rotation
if ($config.log_rotation.enabled) {
    $keepDays = $config.log_rotation.keep_last_days
    $cutoff = (Get-Date).AddDays(-$keepDays)
    Get-ChildItem $logDir -Filter "*.log" |
        Where-Object { $_.LastWriteTime -lt $cutoff } |
        Remove-Item -Force -ErrorAction SilentlyContinue
}

$scriptRoot = Join-Path $root 'src\scripts'
$cleanTempScript     = Join-Path $scriptRoot 'clean_temp.ps1'
$emptyTrashScript    = Join-Path $scriptRoot 'empty_trash.ps1'
$updateAppsScript    = Join-Path $scriptRoot 'update_apps.ps1'
$updateDriversScript = Join-Path $scriptRoot 'update_drivers.ps1'
$repairSystemScript  = Join-Path $scriptRoot 'repair_system.ps1'

Write-Log "Iniciando comando: $Command"

try {

    switch ($Command) {

        "clean-temp" {
            if ($config.cleanup.clean_temp_files) {
                . $cleanTempScript -Config $config -LogFile $logFile
            }
        }

        "empty-trash" {
            if ($config.cleanup.empty_recycle_bin) {
                . $emptyTrashScript -Config $config -LogFile $logFile
            }
        }

        "update-apps" {
            . $updateAppsScript -Config $config -LogFile $logFile
        }

        "update-drivers" {
            . $updateDriversScript -Config $config -LogFile $logFile
        }

        "repair-system" {
            Write-Host ""
            Write-Host ">>> Reparacao do sistema (DISM + SFC)" -ForegroundColor Cyan
            . $repairSystemScript -Config $config -LogFile $logFile
            Write-Host ""
            Write-Log "Reparacao finalizada"
        }

        "run-all" {
            Write-Log "Executando rotina completa"

            Write-Host ""
            Write-Host ">>> [1/4] Limpeza de temporarios" -ForegroundColor Cyan
            . $cleanTempScript     -Config $config -LogFile $logFile

            Write-Host ""
            Write-Host ">>> [2/4] Esvaziando lixeira" -ForegroundColor Cyan
            . $emptyTrashScript    -Config $config -LogFile $logFile

            Write-Host ""
            Write-Host ">>> [3/4] Atualizando apps (winget)" -ForegroundColor Cyan
            . $updateAppsScript    -Config $config -LogFile $logFile

            Write-Host ""
            Write-Host ">>> [4/4] Atualizando drivers" -ForegroundColor Cyan
            . $updateDriversScript -Config $config -LogFile $logFile

            Write-Host ""
            Write-Log "Rotina completa finalizada"
        }
    }

}
catch {
    Write-Log "Erro geral: $_"
    Write-Error $_
}
