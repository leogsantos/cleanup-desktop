# ================================
# PC-TOOLS UNINSTALL SCRIPT
# ================================

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

Write-Host "=== Desinstalador PC Tools ===" -ForegroundColor Yellow

function Test-IsAdmin {
    $identity  = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Invoke-AdminElevation {
    if (-not (Test-IsAdmin)) {
        $psExePath  = Join-Path $env:WINDIR 'System32\WindowsPowerShell\v1.0\powershell.exe'
        $scriptPath = $PSCommandPath
        if (-not $scriptPath) { $scriptPath = $MyInvocation.MyCommand.Path }
        Start-Process -FilePath $psExePath -ArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-File',$scriptPath) -Verb RunAs -Wait
        exit
    }
}

Invoke-AdminElevation

try {

    $confirm = Read-Host "Tem certeza que deseja desinstalar o PC Tools? (Y/N)"
    if ($confirm -notin @("Y","y")) {
        Write-Host "Cancelado."
        return
    }

    $taskFolderName  = "cleanup-desktop"
    $taskMaintenance = "PC Tools Maintenance"
    $taskRepair      = "PC Tools System Repair"

    # ================================
    # Remover tarefas agendadas via COM
    # ================================
    Write-Host "Removendo tarefas agendadas..."

    $scheduler = New-Object -ComObject Schedule.Service
    $scheduler.Connect()
    $rootFolder = $scheduler.GetFolder("\")

    # Limpar root (tasks que foram criadas sem subpasta em runs anteriores)
    foreach ($name in @("PCToolsTest", $taskMaintenance, $taskRepair)) {
        try { $rootFolder.DeleteTask($name, 0) } catch { }
    }

    # Limpar pasta legada com typo
    try {
        $legacy = $scheduler.GetFolder("\cleanup-dektop")
        try { $legacy.DeleteTask($taskMaintenance, 0) } catch { }
        try { $legacy.DeleteTask($taskRepair, 0) } catch { }
        try { $rootFolder.DeleteFolder("cleanup-dektop", 0) } catch { }
    } catch { }

    # Limpar pasta correta e remover
    try {
        $taskDir = $scheduler.GetFolder("\$taskFolderName")
        try { $taskDir.DeleteTask($taskMaintenance, 0) } catch { }
        try { $taskDir.DeleteTask($taskRepair, 0) } catch { }
        try { $rootFolder.DeleteFolder($taskFolderName, 0) } catch { }
    } catch { }

    Write-Host "Tarefas removidas"

    # ================================
    # Remover pasta legada (instalacoes antigas com EXE)
    # ================================
    $legacyDir = "$env:LOCALAPPDATA\PCTools"
    if (Test-Path $legacyDir) {
        try {
            Remove-Item $legacyDir -Recurse -Force -ErrorAction Stop
            Write-Host "Pasta legada removida: $legacyDir"
        }
        catch {
            Write-Warning "Nao foi possivel remover $($legacyDir): $($_.Exception.Message)"
        }
    }

    # ================================
    # Remover modulo de drivers (opcional)
    # ================================
    $removeModule = Read-Host "Deseja remover o modulo PSWindowsUpdate? (Y/N)"
    if ($removeModule -in @("Y","y")) {
        try {
            if (Get-Module -ListAvailable -Name PSWindowsUpdate) {
                Uninstall-Module PSWindowsUpdate -AllVersions -Force -ErrorAction Stop
                Write-Host "PSWindowsUpdate removido"
            } else {
                Write-Host "PSWindowsUpdate nao encontrado"
            }
        }
        catch {
            Write-Warning "Nao foi possivel remover PSWindowsUpdate: $($_.Exception.Message)"
            Write-Warning "Feche todas as sessoes do PowerShell e tente novamente, ou remova manualmente com: Uninstall-Module PSWindowsUpdate -AllVersions -Force"
        }
    }

    Write-Host ""
    Write-Host "=== Desinstalacao concluida ===" -ForegroundColor Green
    Write-Host ""

}
catch {
    Write-Host ""
    Write-Host "ERRO: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host ""
}
finally {
    Read-Host "Pressione Enter para fechar"
}
