# PC Tools

Automação de manutenção para Windows: limpeza de temporários, esvaziamento de lixeira, atualização de apps, drivers e reparação do sistema operacional.

## O que faz

| Rotina | Quando roda | Comando |
|---|---|---|
| Limpeza de temporários + lixeira + flush DNS | Semanal (sáb 10h) | `run-all` |
| Atualização de apps via `winget` | Semanal (sáb 10h) | `run-all` |
| Atualização de drivers via `PSWindowsUpdate` | Semanal (sáb 10h) | `run-all` |
| DISM RestoreHealth + SFC scannow | Quinzenal (dom 02h) | `repair-system` |
| chkdsk (agendado p/ próximo boot) | Opcional via config | `repair-system` |

## Como instalar

### Pré-requisitos

- Windows 10/11
- PowerShell (já vem no Windows)
- `winget` instalado (App Installer da Microsoft Store)

### Instalação

1. Clone o repositório:

```powershell
git clone https://github.com/leogsantos/cleanup-desktop.git
cd cleanup-desktop
```

2. Execute o instalador:

```powershell
.\setup\setup.ps1
```

O script pede elevação de administrador automaticamente. Ele vai:
- Copiar os arquivos para `%LOCALAPPDATA%\PCTools\`
- Criar as duas tarefas no Agendador de Tarefas do Windows
- Instalar o módulo `PSWindowsUpdate` (para drivers)

### O que é criado no Agendador de Tarefas

| Tarefa | Frequência | Horário | Ação |
|---|---|---|---|
| PC Tools Maintenance | Semanal | Sábado 10:00 | `run-all` |
| PC Tools System Repair | Quinzenal | Domingo 02:00 | `repair-system` |

Ambas ficam na pasta `\cleanup-desktop\` do Agendador de Tarefas.

## Como rodar manualmente

Abra o PowerShell como administrador e execute:

```powershell
# Rotina completa (limpeza + updates)
powershell -ExecutionPolicy Bypass -File "$env:LOCALAPPDATA\PCTools\pc-tools.ps1" run-all

# Só reparação do sistema (DISM + SFC)
powershell -ExecutionPolicy Bypass -File "$env:LOCALAPPDATA\PCTools\pc-tools.ps1" repair-system

# Comandos individuais
powershell -ExecutionPolicy Bypass -File "$env:LOCALAPPDATA\PCTools\pc-tools.ps1" clean-temp
powershell -ExecutionPolicy Bypass -File "$env:LOCALAPPDATA\PCTools\pc-tools.ps1" empty-trash
powershell -ExecutionPolicy Bypass -File "$env:LOCALAPPDATA\PCTools\pc-tools.ps1" update-apps
powershell -ExecutionPolicy Bypass -File "$env:LOCALAPPDATA\PCTools\pc-tools.ps1" update-drivers
```

Ou, se quiser rodar direto do repositório sem instalar:

```powershell
powershell -ExecutionPolicy Bypass -File .\src\pc-tools.ps1 run-all
```

## Como desinstalar

```powershell
.\setup\uninstall.ps1
```

Remove os arquivos de `%LOCALAPPDATA%\PCTools\` e as duas tarefas do Agendador.

## Estrutura do projeto

```
cleanup-desktop/
├── config.json              # Configuração de todas as rotinas
├── setup/
│   ├── setup.ps1            # Instalador (copia arquivos + cria tarefas)
│   └── uninstall.ps1        # Desinstalador
└── src/
    ├── pc-tools.ps1         # Orquestrador principal
    └── scripts/
        ├── clean_temp.ps1   # Limpeza de temp + flush DNS
        ├── empty_trash.ps1  # Esvaziamento de lixeira
        ├── update_apps.ps1  # Atualização de apps via winget
        ├── update_drivers.ps1  # Atualização de drivers via PSWindowsUpdate
        └── repair_system.ps1   # DISM + SFC + chkdsk (quinzenal)
```

Os logs de cada execução ficam em `%LOCALAPPDATA%\PCTools\logs\` com o formato `execution_yyyyMMdd_HHmmss.log`. Logs com mais de 30 dias são removidos automaticamente.

## Configuração (config.json)

```jsonc
{
  "dry_run": false,          // true = simula sem alterar nada

  "temp_paths": ["%TEMP%", "C:\\Windows\\Temp"],  // pastas a limpar

  "cleanup": {
    "empty_recycle_bin": true,
    "clean_temp_files": true
  },

  "updates": {
    "excluded_apps": ["Microsoft.Edge", "Git.Git"],  // IDs winget a ignorar
    "include_unknown": true,
    "auto_accept_agreements": true
  },

  "drivers": {
    "update_drivers": true,
    "auto_reboot": false     // nunca reinicia automaticamente
  },

  "system_repair": {
    "enabled": true,
    "run_dism": true,        // DISM /Online /Cleanup-Image /RestoreHealth
    "run_sfc": true,         // sfc /scannow
    "schedule_chkdsk": false,   // true = agenda chkdsk para próximo boot
    "chkdsk_drives": ["C:"]
  },

  "log_rotation": {
    "enabled": true,
    "keep_last_days": 30
  },

  "execution": {
    "continue_on_error": true
  }
}
```

## Stack

| Camada | Tecnologia |
|---|---|
| Scripts | PowerShell |
| Atualização de apps | winget |
| Atualização de drivers | PSWindowsUpdate |
| Reparação do SO | DISM, SFC, chkdsk (nativos do Windows) |
