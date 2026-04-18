# ================================
# PC-TOOLS UNINSTALL SCRIPT
# ================================

Write-Host "=== Desinstalador PC Tools ===" -ForegroundColor Yellow

function Test-IsAdmin {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Ensure-RunAsAdmin {
    if (-not (Test-IsAdmin)) {
        $powershellPath = Join-Path $env:WINDIR 'System32\WindowsPowerShell\v1.0\powershell.exe'
        $arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$($MyInvocation.MyCommand.Path)`""
        Start-Process -FilePath $powershellPath -ArgumentList $arguments -Verb RunAs
        exit
    }
}

Ensure-RunAsAdmin

$installDir = "$env:LOCALAPPDATA\PCTools"
$taskFolder = "\cleanup-dektop\"
$taskName = "PC Tools Maintenance"

# ================================
# Confirmação do usuário
# ================================
$confirm = Read-Host "Tem certeza que deseja desinstalar o PC Tools? (Y/N)"

if ($confirm -notin @("Y","y")) {
    Write-Host "Cancelado."
    exit
}

# ================================
# Remover tarefa agendada
# ================================
Write-Host "Removendo tarefa agendada..."

# O script já vai solicitar elevação se ainda não estiver em admin.

try {
    if (Get-ScheduledTask -TaskPath $taskFolder -TaskName $taskName -ErrorAction SilentlyContinue) {
        Unregister-ScheduledTask -TaskPath $taskFolder -TaskName $taskName -Confirm:$false
        Write-Host "Tarefa removida"
    }
    else {
        Write-Host "Tarefa não encontrada"
    }
}
catch {
    Write-Warning "Erro ao remover tarefa: $_"
}

# ================================
# Remover arquivos instalados
# ================================
Write-Host "Removendo arquivos..."

if (Test-Path $installDir) {
    try {
        Remove-Item $installDir -Recurse -Force -ErrorAction Stop
        Write-Host "Arquivos removidos: $installDir"
    }
    catch {
        Write-Warning "Erro ao remover pasta"
    }
}
else {
    Write-Host "Pasta não encontrada"
}

# ================================
# Remover módulo de drivers (opcional)
# ================================
$removeModule = Read-Host "Deseja remover o módulo PSWindowsUpdate? (Y/N)"

if ($removeModule -in @("Y","y")) {
    try {
        if (Get-Module -ListAvailable -Name PSWindowsUpdate) {
            Uninstall-Module PSWindowsUpdate -AllVersions -Force
            Write-Host "PSWindowsUpdate removido"
        }
        else {
            Write-Host "PSWindowsUpdate não encontrado"
        }
    }
    catch {
        Write-Warning "Erro ao remover módulo"
    }
}

# ================================
# Finalização
# ================================
Write-Host ""
Write-Host "=== Desinstalação concluída ===" -ForegroundColor Green
Write-Host ""