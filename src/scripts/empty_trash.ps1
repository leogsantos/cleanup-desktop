param(
    $Config,
    [string]$LogFile
)

function Write-Log {
    param($msg)
    "$((Get-Date).ToString("yyyy-MM-dd HH:mm:ss")) - $msg" | Out-File -Append $LogFile
}

if ($Config.dry_run) {
    Write-Log "[DRY RUN] Lixeira não será esvaziada"
    return
}

try {
    Clear-RecycleBin -Force -ErrorAction Stop
    Write-Log "Lixeira esvaziada"
}
catch {
    Write-Log "Erro ao esvaziar lixeira"
}