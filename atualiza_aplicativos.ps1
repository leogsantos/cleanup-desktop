# Oculta a janela do PowerShell e atualiza todos os aplicativos usando winget
Start-Process "powershell" -ArgumentList "-Command Start-Process 'winget' -ArgumentList 'upgrade --all' -NoNewWindow -Wait" -WindowStyle Hidden -Wait

# Atualiza definições de antivírus (usando o Windows Defender como exemplo)
Start-Process "powershell" -ArgumentList "-Command Update-MpSignature" -WindowStyle Hidden -Wait

# Realiza verificação de malware (usando o Windows Defender como exemplo)
Start-Process "powershell" -ArgumentList "-Command Start-MpScan -ScanType QuickScan" -WindowStyle Hidden -Wait

# Limpa a lixeira
Clear-RecycleBin -Force
