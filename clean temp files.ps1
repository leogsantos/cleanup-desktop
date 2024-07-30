# Limpa arquivos temporários
Remove-Item -Path "C:\Windows\Temp\*" -Recurse -Force
Remove-Item -Path "$env:TEMP\*" -Recurse -Force

# Limpa a lixeira
Clear-RecycleBin -Force