# PC Tools

Automação de manutenção para Windows: limpeza de arquivos temporários, esvaziamento de lixeira, atualização de apps e gerenciamento de drivers.

## O que é

Este projeto fornece um conjunto de scripts PowerShell para executar rotinas de manutenção de PC de forma automática e configurável. Ele foi pensado para ser instalado localmente e rodar como uma tarefa agendada semanalmente em Windows.

## Funcionalidades

### Core
- Limpeza de arquivos temporários definidos em `config.json`
- Esvaziamento da Lixeira
- Atualização de aplicativos via `winget`
- Atualização de drivers via `PSWindowsUpdate`
- Execução de rotina completa com um único comando

### Automação / Processamento
- Empacotamento do script principal em `pc-tools.exe` via `ps2exe`
- Criação de tarefa agendada no Windows Task Scheduler
- Logs de execução gerados automaticamente em `logs/`
- Instalação e desinstalação com elevação administrativa

## Como Usar

### Pré-requisitos

- Windows 10/11
- PowerShell com permissão para executar scripts
- `winget` disponível no sistema (para atualizações de apps)

### Instalação

1. Clone o repositório:

```powershell
git clone https://github.com/leogsantos/cleanup-desktop.git
cd cleanup-desktop
```

2. Execute o instalador com permissão de administrador:

```powershell
.\\setup\\setup.ps1
```

### Execução

Após a instalação, o executável gerado fica em `%LOCALAPPDATA%\\PCTools\\pc-tools.exe`.

Para rodar a rotina completa manualmente:

```powershell
%LOCALAPPDATA%\\PCTools\\pc-tools.exe run-all
```

Para executar diretamente pelo script fonte:

```powershell
powershell -ExecutionPolicy Bypass -File .\\src\\pc-tools.ps1 -Command run-all
```

### Desinstalação

```powershell
.\\setup\\uninstall.ps1
```

## Estrutura do Projeto

- `config.json` — arquivo de configuração principal
- `src/pc-tools.ps1` — script principal que orquestra as rotinas
- `src/scripts/clean_temp.ps1` — limpeza de arquivos temporários
- `src/scripts/empty_trash.ps1` — esvaziamento de lixeira
- `src/scripts/update_apps.ps1` — atualização de apps via winget
- `src/scripts/update_drivers.ps1` — atualização de drivers via PSWindowsUpdate
- `setup/setup.ps1` — instalador e criação de tarefa agendada
- `setup/uninstall.ps1` — desinstalador e remoção da tarefa agendada
- `.github/workflows/` — pipelines de build e testes
- `logs/` — local onde os logs de execução são gravados

## Fluxo Técnico

1. Usuário executa `setup\setup.ps1` como administrador.
2. O script copia os arquivos para `%LOCALAPPDATA%\\PCTools`, gera o executável e cria a tarefa agendada.
3. A tarefa agendada roda semanalmente e executa `pc-tools.exe run-all`.
4. O comando lê `config.json` e dispara as rotinas de limpeza, lixo, apps e drivers.
5. O resultado de cada execução é gravado em um arquivo de log dentro de `logs/`.

## Detalhes Técnicos

- `config.json` controla quais rotinas devem rodar e define comportamentos de execução
- `setup/setup.ps1` garante elevação administrativa antes de instalar e criar a tarefa agendada
- `ps2exe` é usado para gerar `pc-tools.exe` com `RequireAdmin` e sem console
- `winget` é validado durante a instalação, mas a rotina de apps indica caso não esteja disponível
- `PSWindowsUpdate` é instalado se necessário para permitir a atualização de drivers

## Configuração do config.json

O arquivo `config.json` define o comportamento da manutenção e permite ativar/desativar cada rotina.

- `log_level`:
  - `info`, `debug`, `warning`, etc. (controle de nível de logs)
- `dry_run`:
  - `true` — executa em modo de simulação sem alterar o sistema
  - `false` — executa normalmente
- `temp_paths`:
  - lista de caminhos que serão limpos pelo `clean_temp.ps1`
  - aceita variáveis de ambiente como `%TEMP%`
- `cleanup.empty_recycle_bin`:
  - `true` — esvazia a Lixeira
  - `false` — pula essa rotina
- `cleanup.clean_temp_files`:
  - `true` — limpa arquivos temporários
  - `false` — pula essa rotina
- `updates.update_all_apps`:
  - `true` — tenta atualizar aplicativos com `winget`
  - `false` — ignora a rotina de apps
- `updates.excluded_apps`:
  - lista de identificadores de apps a ignorar durante a atualização
- `updates.include_unknown`:
  - `true` — inclui apps desconhecidos no processo de verificação/atualização
- `updates.auto_accept_agreements`:
  - `true` — aceita automaticamente prompts de licença durante atualização de apps
- `drivers.update_drivers`:
  - `true` — ativa atualização de drivers
  - `false` — desliga essa rotina
- `drivers.use_windows_update`:
  - `true` — usa o Windows Update como fonte de drivers
  - `false` — depende de `PSWindowsUpdate` e configurações adicionais
- `drivers.auto_reboot`:
  - `true` — permite reinicializar automaticamente após atualização de drivers
  - `false` — não reinicia o sistema automaticamente
- `execution.continue_on_error`:
  - `true` — continua executando mesmo se uma rotina falhar
  - `false` — interrompe na primeira falha
- `execution.generate_json_output`:
  - `true` — habilita geração de saída em JSON
  - `false` — não gera saída JSON
- `execution.save_logs`:
  - `true` — grava logs em disco
  - `false` — não grava logs

## Agendador do setup.ps1

O `setup/setup.ps1` cria uma tarefa agendada no Windows Task Scheduler para rodar a rotina completa automaticamente.

- Tarefa criada em `\cleanup-dektop\`
- Nome da tarefa: `PC Tools Maintenance`
- Agendada para rodar semanalmente aos sábados às 10:00
- Ação: executa `%LOCALAPPDATA%\\PCTools\\pc-tools.exe run-all`
- Configurações principais:
  - `StartWhenAvailable` — inicia a tarefa assim que possível caso tenha sido perdida
  - `RestartCount 3` — reinicia até 3 vezes em caso de falha
  - `RestartInterval 5 minutos` — intervalo entre tentativas de reinício
- Executa com `Highest` privileges e com logon interativo do usuário atual
- O script `setup.ps1` tenta elevar automaticamente para administrador antes de criar o instalador e a tarefa

## Stack Tecnológica

| Camada | Tecnologia |
|---|---|
| Automação / Scripts | PowerShell |
| Empacotamento | ps2exe |
| Atualização de apps | winget |
| Atualização de drivers | PSWindowsUpdate |