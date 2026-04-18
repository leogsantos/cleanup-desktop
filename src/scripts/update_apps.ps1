param(
    $Config,
    [string]$LogFile
)

function Write-Log {
    param($msg)
    "$((Get-Date).ToString("yyyy-MM-dd HH:mm:ss")) - $msg" | Out-File -Append $LogFile
}

if ($Config.dry_run) {
    Write-Log "[DRY RUN] Update de apps ignorado"
    return
}

Write-Log "Iniciando atualização via winget"

$baseArgs = @(
    "upgrade",
    "--all"
)

if ($Config.updates.include_unknown) {
    $baseArgs += "--include-unknown"
}

if ($Config.updates.auto_accept_agreements) {
    $baseArgs += "--accept-source-agreements"
    $baseArgs += "--accept-package-agreements"
}

$baseArgs += "--silent"

try {
    winget @baseArgs
    Write-Log "Atualização concluída"
}
catch {
    Write-Log "Erro no update de apps"
}