param(
    $Config,
    [string]$LogFile
)

function Write-Log {
    param($msg)
    $line = "$((Get-Date).ToString("yyyy-MM-dd HH:mm:ss")) - $msg"
    $line | Out-File -Append $LogFile
    Write-Host $line
}

if ($Config.dry_run) {
    Write-Log "[DRY RUN] Lixeira nao sera esvaziada"
    return
}

try {
    Clear-RecycleBin -Force -ErrorAction Stop
    Write-Log "Lixeira esvaziada"
}
catch {
    Write-Log "Erro ao esvaziar lixeira: $($_.Exception.Message)"
}
