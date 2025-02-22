# Cargar la librería de funciones
Import-Module .\libreria.ps1 

# Instalar DNS Server
Write-Host " [INFO] Instalando Servidor DNS"
Install-WindowsFeature -Name DNS -IncludeManagementTools

# Configurar IP estática
$ip = Leer-IPValidada "Ingrese la IP del servidor DNS:"
$mask = Leer-IPValidada "Ingrese la máscara de subred:"
$gateway = Leer-IPValidada "Ingrese la puerta de enlace predeterminada:"
$interface = Get-NetAdapter | Where-Object {$_.Status -eq "Up"}

Write-Host "[INFO] Restaurando configuración de IP estática..."
New-NetIPAddress -IPAddress $ip -PrefixLength 24 -InterfaceIndex $interface.ifIndex -DefaultGateway $gateway
Set-DnsClientServerAddress -InterfaceIndex $interface.ifIndex -ServerAddresses ($ip, "8.8.4.4")
Write-Host "[INFO] Configuración de IP estática aplicada."

# Configurar Zona DNS
Write-Host "[INFO] Configurando archivo de zona DNS..."
$direccionRed = Obtener-DireccionRed -IP $ip -MascaraSubred $mask
Add-DnsServerPrimaryZone -Name "reprobados.com" -ZoneFile "reprobados.com.dns"
Add-DnsServerResourceRecordA -ZoneName "reprobados.com" -Name "@" -IPv4Address $direccionRed
Add-DnsServerResourceRecordA -ZoneName "reprobados.com" -Name "www" -IPv4Address $direccionRed

# Reiniciar el servicio DNS
Restart-Service DNS
Write-Host "[INFO] Terminado con éxito"
