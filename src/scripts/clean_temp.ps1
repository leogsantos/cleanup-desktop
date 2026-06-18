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
    Write-Log "[DRY RUN] Limpeza de temporarios ignorada"
    return
}

$totalDeleted = 0

foreach ($path in $Config.temp_paths) {
    $resolved = [Environment]::ExpandEnvironmentVariables($path)
    if (Test-Path $resolved) {
        Write-Log "Limpando: $resolved"
        try {
            $files = Get-ChildItem $resolved -Recurse -Force -ErrorAction SilentlyContinue
            foreach ($file in $files) {
                try {
                    Remove-Item $file.FullName -Recurse -Force -ErrorAction Stop
                    $totalDeleted++
                }
                catch {
                    if (-not $Config.execution.continue_on_error) { throw }
                }
            }
        }
        catch {
            Write-Log "Erro em $($resolved): $($_.Exception.Message)"
        }
    }
}

Write-Log "Temporarios removidos: $totalDeleted arquivo(s)"

try {
    Clear-DnsClientCache
    Write-Log "Cache DNS limpo"
}
catch {
    Write-Log "Aviso: nao foi possivel limpar o cache DNS: $($_.Exception.Message)"
}
