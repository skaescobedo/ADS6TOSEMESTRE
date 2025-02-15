# Solicitar la configuración de la IP estática
$InterfaceAlias = Read-Host "Ingrese el nombre del adaptador de red (ejemplo: Ethernet2)"
$IpAddress = Read-Host "Ingrese la dirección IP estática del servidor (ejemplo: 192.168.1.10)"
$SubnetMask = Read-Host "Ingrese la máscara de subred (ejemplo: 255.255.255.0)"
$DefaultGateway = Read-Host "Ingrese la puerta de enlace predeterminada (ejemplo: 192.168.1.1)"
$DnsServer = Read-Host "Ingrese la dirección del servidor DNS (ejemplo: 8.8.8.8)"

# Convertir máscara de subred a prefijo de longitud
$MaskToPrefix = @{"255.255.255.0"=24; "255.255.254.0"=23; "255.255.252.0"=22; "255.255.248.0"=21;
                  "255.255.240.0"=20; "255.255.224.0"=19; "255.255.192.0"=18; "255.255.128.0"=17;
                  "255.255.0.0"=16; "255.254.0.0"=15; "255.252.0.0"=14; "255.248.0.0"=13;
                  "255.240.0.0"=12; "255.224.0.0"=11; "255.192.0.0"=10; "255.128.0.0"=9;
                  "255.0.0.0"=8; "254.0.0.0"=7; "252.0.0.0"=6; "248.0.0.0"=5;
                  "240.0.0.0"=4; "224.0.0.0"=3; "192.0.0.0"=2; "128.0.0.0"=1; "0.0.0.0"=0}

$PrefixLength = $MaskToPrefix[$SubnetMask]

# Configurar la IP estática
New-NetIPAddress -InterfaceAlias $InterfaceAlias -IPAddress $IpAddress -PrefixLength $PrefixLength -DefaultGateway $DefaultGateway
Set-DnsClientServerAddress -InterfaceAlias $InterfaceAlias -ServerAddresses $DnsServer

Write-Host "La IP estática ha sido configurada correctamente."

# Instalar el servicio DHCP
Install-WindowsFeature -Name DHCP -IncludeManagementTools

# Solicitar los parámetros del ámbito DHCP
$ScopeName = Read-Host "Ingrese el nombre del ámbito DHCP"
$StartRange = Read-Host "Ingrese la dirección IP de inicio del rango (ejemplo: 192.168.1.100)"
$EndRange = Read-Host "Ingrese la dirección IP de fin del rango (ejemplo: 192.168.1.200)"
$SubnetMask = Read-Host "Ingrese la máscara de subred del ámbito (ejemplo: 255.255.255.0)"

# Usar la misma puerta de enlace para DHCP
$Router = $DefaultGateway

Write-Host "Se utilizará la puerta de enlace predeterminada $Router para el DHCP."

# Crear el ámbito DHCP
Add-DhcpServerv4Scope -Name $ScopeName -StartRange $StartRange -EndRange $EndRange -SubnetMask $SubnetMask -State Active

# Configurar opciones del ámbito DHCP
Set-DhcpServerv4OptionValue -ScopeId $StartRange -Router $Router -DnsServer $DnsServer

# Habilitar y reiniciar el servicio DHCP
Restart-Service -Name DHCPServer -StartupType Automatic

Write-Host "El servidor DHCP ha sido configurado correctamente."
