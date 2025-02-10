# Instalar DNS Server
Write-Host " [INFO] Instalando Servidor DNS"
Install-WindowsFeature -Name DNS -IncludeManagementTools

# Configurar ip estática
$ip = "192.168.1.10"
$mask = "255.255.255.0"
$gateway = "192.168.1.1"
$interface = Get-NetAdapter | Where-Object {$_.Status -eq "Up"}

Write-Host "[INFO] Restaurando configuración de IP estática..."
New-NetIPAddress -IPAddress $IP -PrefixLength 24 -InterfaceIndex $interface.ifIndex -DefaultGateway $gateway
Set-DnsClientServerAddress -InterfaceIndex $interface.ifIndex -ServerAddresses ("192.168.1.10", "8.8.4.4")
Write-Host "[INFO] Configuración de IP estática aplicada."

# Configurar Zona DNS
Write-Host "[INFO] Configurando archivo de zona DNS..."
Add-DnsServerPrimaryZone -Name "reprobados.com" -ZoneFile "reprobados.com.dns"
Add-DnsServerResourceRecordA -ZoneName "reprobados.com" -Name "@" -IPv4Address $ip
Add-DnsServerResourceRecordA -ZoneName "reprobados.com" -Name "www" -IPv4Address $ip

# Reiniciar el servicio DNS
Restart-Service DNS
Write-Host "[INFO] Terminado con éxito"