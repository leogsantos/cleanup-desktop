param(
    $Config,
    [string]$LogFile
)

function Write-Log {
    param($msg)
    "$((Get-Date).ToString("yyyy-MM-dd HH:mm:ss")) - $msg" | Out-File -Append $LogFile
}

if ($Config.dry_run) {
    Write-Log "[DRY RUN] Limpeza de temporários ignorada"
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
            Write-Log "Erro em $resolved"
        }
    }
}

$result = [PSCustomObject]@{
    Action = "Clean Temp"
    FilesRemoved = $totalDeleted
    Status = "Completed"
    Timestamp = Get-Date
}

if ($Config.execution.generate_json_output) {
    $result | ConvertTo-Json
}