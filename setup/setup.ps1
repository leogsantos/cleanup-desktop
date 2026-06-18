# ================================
# PC-TOOLS SETUP SCRIPT
# ================================

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

Write-Host "=== Iniciando setup do PC Tools ==="

function Test-IsAdmin {
    $identity  = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Invoke-AdminElevation {
    if (-not (Test-IsAdmin)) {
        Write-Host "Reiniciando como administrador..."
        $psExePath  = Join-Path $env:WINDIR 'System32\WindowsPowerShell\v1.0\powershell.exe'
        $scriptPath = $PSCommandPath
        if (-not $scriptPath) { $scriptPath = $MyInvocation.MyCommand.Path }
        if (-not $scriptPath) { throw "Nao foi possivel determinar o caminho do script." }
        Start-Process -FilePath $psExePath -ArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-File',$scriptPath) -Verb RunAs -Wait
        exit
    }
}

Invoke-AdminElevation

try {

    $setupDir   = Split-Path -Parent $MyInvocation.MyCommand.Path
    $repoRoot   = Split-Path -Parent $setupDir
    $mainScript = Join-Path $repoRoot "src\pc-tools.ps1"
    $psExe      = Join-Path $env:WINDIR 'System32\WindowsPowerShell\v1.0\powershell.exe'

    if (-not (Test-Path $mainScript)) {
        throw "Script principal nao encontrado em: $mainScript"
    }

    Write-Host "Scripts em: $repoRoot"

    # ================================
    # Validar winget
    # ================================
    Write-Host "Validando winget..."
    if (!(Get-Command winget -ErrorAction SilentlyContinue)) {
        Write-Warning "Winget nao encontrado. Instale pela Microsoft Store (App Installer)."
    } else {
        Write-Host "Winget OK"
    }

    # ================================
    # Instalar PSWindowsUpdate (opcional)
    # ================================
    Write-Host "Configurando suporte a drivers..."
    if (-not (Get-Module -ListAvailable -Name PSWindowsUpdate)) {
        try {
            Install-Module PSWindowsUpdate -Scope CurrentUser -Force -ErrorAction Stop
            Write-Host "PSWindowsUpdate instalado"
        }
        catch {
            Write-Warning "Falha ao instalar PSWindowsUpdate: $($_.Exception.Message)"
        }
    }

    # ================================
    # Criar tarefas agendadas
    # ================================
    Write-Host "Criando tarefas agendadas..."

    $taskMaintenance = "PC Tools Maintenance"
    $taskRepair      = "PC Tools System Repair"

    # Limpar versoes anteriores (root e subpastas legadas)
    foreach ($tn in @($taskMaintenance, $taskRepair,
                      "\cleanup-desktop\$taskMaintenance", "\cleanup-desktop\$taskRepair",
                      "\cleanup-dektop\$taskMaintenance",  "\cleanup-dektop\$taskRepair")) {
        schtasks /Delete /TN $tn /F 2>$null | Out-Null
    }

    $userSid = ([System.Security.Principal.WindowsIdentity]::GetCurrent()).User.Value

    function New-PcTask {
        param(
            [string]$TaskName,
            [string]$ArgCommand,
            [string]$DayElement,
            [int]$WeeksInterval,
            [string]$StartBoundary
        )

        $xml = @"
<?xml version="1.0" encoding="UTF-16"?>
<Task version="1.2" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
  <RegistrationInfo>
    <Description>PC Tools scheduled task</Description>
  </RegistrationInfo>
  <Principals>
    <Principal id="Author">
      <UserId>$userSid</UserId>
      <LogonType>InteractiveToken</LogonType>
      <RunLevel>HighestAvailable</RunLevel>
    </Principal>
  </Principals>
  <Settings>
    <DisallowStartIfOnBatteries>true</DisallowStartIfOnBatteries>
    <StopIfGoingOnBatteries>true</StopIfGoingOnBatteries>
    <ExecutionTimeLimit>PT0S</ExecutionTimeLimit>
    <MultipleInstancesPolicy>IgnoreNew</MultipleInstancesPolicy>
    <RestartOnFailure>
      <Count>3</Count>
      <Interval>PT5M</Interval>
    </RestartOnFailure>
    <StartWhenAvailable>true</StartWhenAvailable>
    <IdleSettings>
      <StopOnIdleEnd>true</StopOnIdleEnd>
      <RestartOnIdle>false</RestartOnIdle>
    </IdleSettings>
  </Settings>
  <Triggers>
    <CalendarTrigger>
      <StartBoundary>$StartBoundary</StartBoundary>
      <ScheduleByWeek>
        <WeeksInterval>$WeeksInterval</WeeksInterval>
        <DaysOfWeek>
          $DayElement
        </DaysOfWeek>
      </ScheduleByWeek>
    </CalendarTrigger>
  </Triggers>
  <Actions Context="Author">
    <Exec>
      <Command>$psExe</Command>
      <Arguments>-NoProfile -ExecutionPolicy Bypass -File "$mainScript" $ArgCommand</Arguments>
    </Exec>
  </Actions>
</Task>
"@
        $tmpXml = [System.IO.Path]::GetTempFileName() -replace '\.tmp$', '.xml'
        try {
            $xml | Out-File -FilePath $tmpXml -Encoding Unicode
            $out = schtasks /Create /XML $tmpXml /TN $TaskName /F 2>&1
            if ($LASTEXITCODE -ne 0) { throw ($out | Out-String) }
        }
        finally {
            Remove-Item $tmpXml -ErrorAction SilentlyContinue
        }
    }

    New-PcTask -TaskName $taskMaintenance -ArgCommand "run-all" `
               -DayElement "<Saturday />" -WeeksInterval 1 -StartBoundary "2025-01-04T10:00:00"
    Write-Host "Tarefa criada: $taskMaintenance (semanal, sabados 10h)"

    New-PcTask -TaskName $taskRepair -ArgCommand "repair-system" `
               -DayElement "<Sunday />" -WeeksInterval 2 -StartBoundary "2025-01-05T02:00:00"
    Write-Host "Tarefa criada: $taskRepair (quinzenal, domingos 02h)"

    # ================================
    # Criar pasta de logs
    # ================================
    $logDir = Join-Path $repoRoot "logs"
    if (!(Test-Path $logDir)) {
        New-Item -ItemType Directory -Path $logDir | Out-Null
    }

    # ================================
    # Finalizacao
    # ================================
    Write-Host ""
    Write-Host "=== Setup concluido com sucesso ===" -ForegroundColor Green
    Write-Host "Scripts em : $repoRoot"
    Write-Host "Tarefas    : $taskMaintenance (sab 10h) | $taskRepair (dom 02h, quinzenal)"
    Write-Host ""
    Write-Host "Rodar manualmente:"
    Write-Host "  powershell -ExecutionPolicy Bypass -File `"$mainScript`" run-all"
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
