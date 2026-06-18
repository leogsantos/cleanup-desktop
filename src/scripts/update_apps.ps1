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
    Write-Log "[DRY RUN] Update de apps ignorado"
    return
}

Write-Log "Iniciando atualização via winget"

$excluded = @()
if ($Config.updates.excluded_apps) {
    $excluded = @($Config.updates.excluded_apps)
}

$acceptArgs = @()
if ($Config.updates.auto_accept_agreements) {
    $acceptArgs += "--accept-source-agreements"
    $acceptArgs += "--accept-package-agreements"
}

# Sem exclusões: caminho simples com --all
if ($excluded.Count -eq 0) {
    $allArgs = @("upgrade", "--all", "--silent") + $acceptArgs
    if ($Config.updates.include_unknown) { $allArgs += "--include-unknown" }
    try {
        winget @allArgs
        Write-Log "Atualização concluída"
    }
    catch {
        Write-Log "Erro no update de apps: $_"
    }
    return
}

# Com exclusões: lista apps atualizáveis, filtra e atualiza individualmente
Write-Log "Obtendo lista de apps atualizáveis (excluídos: $($excluded -join ', '))"

$listArgs = @("upgrade") + $acceptArgs
if ($Config.updates.include_unknown) { $listArgs += "--include-unknown" }
$rawOutput = & winget @listArgs 2>&1

# Parser baseado na linha separadora (---) para localizar colunas
$ids = @()
$idColStart = -1
$versionColStart = -1
$afterSep = $false

foreach ($line in $rawOutput) {
    if (-not $afterSep) {
        # Linha de cabeçalho: localiza posição da coluna "Id"
        if ($line -match '\bId\b') {
            $idColStart = $line.IndexOf("Id")
            $versionColStart = $line.IndexOf("Version", $idColStart + 2)
        }
        # Linha separadora: a partir daqui vêm os dados
        if ($line -match '^[-\s]{10,}$') {
            $afterSep = $true
        }
        continue
    }

    # Fim da tabela (linha de resumo)
    if ($line -match '^\d+ (pacote|package)' -or [string]::IsNullOrWhiteSpace($line)) { continue }

    if ($idColStart -ge 0 -and $line.Length -gt ($idColStart + 3)) {
        $endIdx = if ($versionColStart -gt $idColStart) { $versionColStart } else { $line.Length }
        $id = $line.Substring($idColStart, [Math]::Min($endIdx, $line.Length) - $idColStart).Trim()
        if ($id -and $id -notmatch '^-') {
            $ids += $id
        }
    }
}

if ($ids.Count -eq 0) {
    Write-Log "Nenhum app atualizável encontrado ou falha ao parsear saída do winget"
    return
}

$toUpgrade = $ids | Where-Object { $excluded -notcontains $_ }
$skipped   = $ids | Where-Object { $excluded -contains $_ }

if ($skipped.Count -gt 0) {
    Write-Log "Apps ignorados (excluded_apps): $($skipped -join ', ')"
}

Write-Log "Atualizando $($toUpgrade.Count) app(s)"

foreach ($appId in $toUpgrade) {
    $appArgs = @("upgrade", "--id", $appId, "--exact", "--silent") + $acceptArgs
    try {
        winget @appArgs
        Write-Log "Atualizado: $appId"
    }
    catch {
        Write-Log "Erro ao atualizar $($appId): $($_.Exception.Message)"
        if (-not $Config.execution.continue_on_error) { throw }
    }
}

Write-Log "Atualização concluída"
