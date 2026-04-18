param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("clean-temp","empty-trash","update-apps","update-drivers","run-all")]
    [string]$Command
)

$root = $PSScriptRoot
$configPath = "$root\config.json"
$logDir = "$root\logs"

if (!(Test-Path $logDir)) {
    New-Item -ItemType Directory -Path $logDir | Out-Null
}

$logFile = "$logDir\execution_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"

function Write-Log {
    param([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$timestamp - $Message" | Out-File -Append $logFile
}

if (!(Test-Path $configPath)) {
    throw "config.json não encontrado"
}

$config = Get-Content $configPath | ConvertFrom-Json

Write-Log "Iniciando comando: $Command"

try {

    switch ($Command) {

        "clean-temp" {
            if ($config.cleanup.clean_temp_files) {
                . "$root\src\scripts\clean_temp.ps1" -Config $config -LogFile $logFile
            }
        }

        "empty-trash" {
            if ($config.cleanup.empty_recycle_bin) {
                . "$root\src\scripts\empty_trash.ps1" -Config $config -LogFile $logFile
            }
        }

        "update-apps" {
            . "$root\src\scripts\update_apps.ps1" -Config $config -LogFile $logFile
        }

        "update-drivers" {
            . "$root\src\scripts\update_drivers.ps1" -Config $config -LogFile $logFile
        }

        "run-all" {
            Write-Log "Executando rotina completa"

            . "$root\src\scripts\clean_temp.ps1" -Config $config -LogFile $logFile
            . "$root\src\scripts\empty_trash.ps1" -Config $config -LogFile $logFile
            . "$root\src\scripts\update_apps.ps1" -Config $config -LogFile $logFile
            . "$root\src\scripts\update_drivers.ps1" -Config $config -LogFile $logFile
        }
    }

}
catch {
    Write-Log "Erro geral: $_"
    Write-Error $_
}