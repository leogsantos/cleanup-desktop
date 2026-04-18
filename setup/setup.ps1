# ================================
# PC-TOOLS SETUP SCRIPT
# ================================

Write-Host "=== Iniciando setup do PC Tools ==="

function Test-IsAdmin {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Ensure-RunAsAdmin {
    if (-not (Test-IsAdmin)) {
        Write-Host "Reiniciando o script como administrador..."
        $powershellPath = Join-Path $env:WINDIR 'System32\WindowsPowerShell\v1.0\powershell.exe'
        $scriptPath = $PSCommandPath
        if (-not $scriptPath) {
            $scriptPath = $MyInvocation.MyCommand.Path
        }
        if (-not $scriptPath) {
            throw "Não foi possível determinar o caminho do script para reiniciar como administrador."
        }

        $arguments = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $scriptPath)
        Start-Process -FilePath $powershellPath -ArgumentList $arguments -Verb RunAs -Wait
        exit
    }
}

Ensure-RunAsAdmin

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$installDir = "$env:LOCALAPPDATA\PCTools"
$exePath = "$installDir\pc-tools.exe"

# ================================
# Criar pasta de instalação
# ================================
if (!(Test-Path $installDir)) {
    New-Item -ItemType Directory -Path $installDir | Out-Null
    Write-Host "Pasta criada: $installDir"
}

# ================================
# Copiar arquivos
# ================================
Write-Host "Copiando arquivos..."

Copy-Item "$root\..\src\pc-tools.ps1" $installDir -Force
Copy-Item "$root\..\config.json" $installDir -Force
Copy-Item "$root\..\src\scripts" $installDir -Recurse -Force

# ================================
# Criar pasta de logs
# ================================
$logDir = "$installDir\logs"
if (!(Test-Path $logDir)) {
    New-Item -ItemType Directory -Path $logDir | Out-Null
}

# ================================
# Validar winget
# ================================
Write-Host "Validando winget..."

if (!(Get-Command winget -ErrorAction SilentlyContinue)) {
    Write-Warning "Winget não encontrado. Instale pela Microsoft Store (App Installer)."
}
else {
    Write-Host "Winget OK"
}

# ================================
# Instalar PS2EXE (se necessário)
# ================================
if (-not (Get-Module -ListAvailable -Name ps2exe)) {
    Write-Host "Instalando PS2EXE..."
    Install-Module ps2exe -Scope CurrentUser -Force
}

Import-Module ps2exe

# ================================
# Gerar EXE
# ================================
Write-Host "Gerando executável..."

Invoke-PS2EXE `
    -InputFile "$installDir\pc-tools.ps1" `
    -OutputFile "$exePath" `
    -NoConsole `
    -RequireAdmin

Write-Host "EXE criado em: $exePath"

# ================================
# Instalar módulo de driver (opcional)
# ================================
Write-Host "Configurando suporte a drivers..."

if (-not (Get-Module -ListAvailable -Name PSWindowsUpdate)) {
    try {
        Install-Module PSWindowsUpdate -Scope CurrentUser -Force -ErrorAction Stop
        Write-Host "PSWindowsUpdate instalado"
    }
    catch {
        Write-Warning "Falha ao instalar PSWindowsUpdate"
    }
}

# ================================
# Criar tarefa agendada
# ================================
Write-Host "Criando tarefa agendada..."

$taskFolder = "\cleanup-dektop\"
$taskName = "PC Tools Maintenance"

# Remove se já existir na pasta de tarefas específica
try {
    $existingTask = Get-ScheduledTask -TaskPath $taskFolder -TaskName $taskName -ErrorAction Stop
    if ($existingTask) {
        Unregister-ScheduledTask -TaskPath $taskFolder -TaskName $taskName -Confirm:$false
    }
}
catch [System.Management.Automation.ItemNotFoundException] {
    # Ignorar se a pasta ou a tarefa não existirem
}
catch {
    Write-Warning "Falha ao verificar tarefa agendada: $_"
}

$action = New-ScheduledTaskAction -Execute $exePath -Argument "run-all"

$trigger = New-ScheduledTaskTrigger `
    -Weekly `
    -DaysOfWeek Saturday `
    -WeeksInterval 1 `
    -At 10am

$settings = New-ScheduledTaskSettingsSet `
    -StartWhenAvailable `
    -RestartCount 3 `
    -RestartInterval (New-TimeSpan -Minutes 5)

$principal = New-ScheduledTaskPrincipal `
    -UserId "$env:USERDOMAIN\$env:USERNAME" `
    -LogonType Interactive `
    -RunLevel Highest

try {
    Register-ScheduledTask `
        -TaskName $taskName `
        -TaskPath $taskFolder `
        -Action $action `
        -Trigger $trigger `
        -Settings $settings `
        -Principal $principal `
        -Description "Automated system maintenance (cleanup, updates, drivers)"

    Write-Host "Tarefa criada com sucesso (rodando como admin sem UAC)"
}
catch {
    Write-Error "Falha ao criar a tarefa agendada: $_"
    exit 1
}

# ================================
# Finalização
# ================================
Write-Host ""
Write-Host "=== Setup concluído com sucesso ==="
Write-Host "Local instalado: $installDir"
Write-Host "Tarefa: $taskName"
Write-Host ""