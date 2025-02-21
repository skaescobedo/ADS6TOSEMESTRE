# Verificar si OpenSSH está instalado
$sshInstalled = Get-WindowsFeature -Name "OpenSSH-Server"
if ($sshInstalled.Installed -eq $false) {
    Write-Host "Instalando OpenSSH Server..."
    Add-WindowsFeature -Name "OpenSSH-Server"
} else {
    Write-Host "OpenSSH Server ya está instalado."
}

# Iniciar y habilitar el servicio SSH
Write-Host "Habilitando y arrancando el servicio SSH..."
Start-Service sshd
Set-Service -Name sshd -StartupType Automatic

# Configurar el firewall para permitir SSH en el puerto 22
Write-Host "Configurando el firewall para permitir SSH..."
New-NetFirewallRule -DisplayName "SSH" -Direction Inbound -Protocol TCP -LocalPort 22 -Action Allow -Enabled True

# Verificar el estado del servicio SSH
Write-Host "Verificando estado de SSH..."
Get-Service sshd

Write-Host "Configuración completada. Ahora puedes conectarte a este servidor vía SSH."
