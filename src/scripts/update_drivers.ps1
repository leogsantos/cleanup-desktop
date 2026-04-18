param(
    $Config,
    [string]$LogFile
)

function Write-Log {
    param($msg)
    "$((Get-Date).ToString("yyyy-MM-dd HH:mm:ss")) - $msg" | Out-File -Append $LogFile
}

if (-not $Config.drivers.update_drivers) {
    Write-Log "Atualização de drivers desativada no config"
    return
}

if ($Config.dry_run) {
    Write-Log "[DRY RUN] Update de drivers ignorado"
    return
}

Write-Log "Iniciando atualização de drivers"

try {

    if ($Config.drivers.use_windows_update) {

        # Verifica se módulo existe
        if (-not (Get-Module -ListAvailable -Name PSWindowsUpdate)) {
            Write-Log "Instalando PSWindowsUpdate"
            Install-Module PSWindowsUpdate -Force -Scope CurrentUser
        }

        Import-Module PSWindowsUpdate

        Write-Log "Buscando updates (incluindo drivers)"

        $params = @{
            MicrosoftUpdate = $true
            AcceptAll       = $true
            Install         = $true
        }

        if ($Config.drivers.auto_reboot) {
            $params["AutoReboot"] = $true
        }

        Get-WindowsUpdate @params

        Write-Log "Drivers atualizados via Windows Update"
    }

}
catch {
    Write-Log "Erro ao atualizar drivers: $_"
}