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

$repair = $Config.system_repair

if (-not $repair.enabled) {
    Write-Log "Reparação do sistema desabilitada na configuração"
    return
}

if ($Config.dry_run) {
    Write-Log "[DRY RUN] Reparação do sistema ignorada"
    return
}

# ----------------------------------------
# DISM: ScanHealth + RestoreHealth
# ----------------------------------------
if ($repair.run_dism) {
    Write-Log "DISM: Iniciando ScanHealth..."
    try {
        $dismScan = Start-Process -FilePath "dism.exe" `
            -ArgumentList "/Online /Cleanup-Image /ScanHealth" `
            -NoNewWindow -Wait -PassThru
        Write-Log "DISM ScanHealth concluído (exit code: $($dismScan.ExitCode))"
    }
    catch {
        Write-Log "Erro ao executar DISM ScanHealth: $_"
        if (-not $Config.execution.continue_on_error) { throw }
    }

    Write-Log "DISM: Iniciando RestoreHealth (pode demorar 15-30 min)..."
    try {
        $dismRestore = Start-Process -FilePath "dism.exe" `
            -ArgumentList "/Online /Cleanup-Image /RestoreHealth" `
            -NoNewWindow -Wait -PassThru
        Write-Log "DISM RestoreHealth concluído (exit code: $($dismRestore.ExitCode))"

        if ($dismRestore.ExitCode -ne 0) {
            Write-Log "AVISO: DISM RestoreHealth retornou código $($dismRestore.ExitCode) — verifique C:\Windows\Logs\DISM\dism.log"
        }
    }
    catch {
        Write-Log "Erro ao executar DISM RestoreHealth: $_"
        if (-not $Config.execution.continue_on_error) { throw }
    }
}

# ----------------------------------------
# SFC: verificação de arquivos de sistema
# ----------------------------------------
if ($repair.run_sfc) {
    Write-Log "SFC: Iniciando scannow (pode demorar 10-20 min)..."
    try {
        $sfc = Start-Process -FilePath "sfc.exe" `
            -ArgumentList "/scannow" `
            -NoNewWindow -Wait -PassThru
        Write-Log "SFC concluído (exit code: $($sfc.ExitCode))"

        if ($sfc.ExitCode -ne 0) {
            Write-Log "AVISO: SFC encontrou ou reparou arquivos — verifique C:\Windows\Logs\CBS\CBS.log"
        }
    }
    catch {
        Write-Log "Erro ao executar SFC: $_"
        if (-not $Config.execution.continue_on_error) { throw }
    }
}

# ----------------------------------------
# chkdsk: agendado para próximo boot
# ----------------------------------------
if ($repair.schedule_chkdsk) {
    foreach ($drive in $repair.chkdsk_drives) {
        Write-Log "chkdsk: Agendando verificação de $drive para próximo boot..."
        try {
            # C: não pode ser bloqueada em uso; respondemos Y para agendar no próximo boot
            $output = cmd /c "echo Y | chkdsk $drive /f /r" 2>&1
            Write-Log "chkdsk $drive agendado. Log: $($output | Select-Object -Last 3 | Out-String)"
            Write-Log "ATENÇÃO: reinicialize o computador para executar o chkdsk em $drive"
        }
        catch {
            Write-Log "Erro ao agendar chkdsk em $($drive): $_"
            if (-not $Config.execution.continue_on_error) { throw }
        }
    }
}

Write-Log "Reparação do sistema concluída"
