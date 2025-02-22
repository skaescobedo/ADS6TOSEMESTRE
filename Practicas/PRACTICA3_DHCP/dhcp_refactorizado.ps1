# Importar el módulo con las funciones
Import-Module .\libreria.ps1

$AdaptadorRed = Read-Host "Ingrese el nombre del adaptador de red (ejemplo: Ethernet2)"

# Validaciones en bucle para asegurar datos correctos
do { $DireccionIP = Leer-IPValidada "Ingrese la dirección IP estática del servidor (ejemplo: 192.168.1.10)" } while (-not $DireccionIP)
do { $MascaraSubred = Leer-IPValidada "Ingrese la máscara de subred (ejemplo: 255.255.255.0)" } while (-not $MascaraSubred)
do { $PuertaEnlace = Leer-IPValidada "Ingrese la puerta de enlace predeterminada (ejemplo: 192.168.1.1)" } while (-not $PuertaEnlace)
do { $ServidorDNS = Leer-IPValidada "Ingrese la dirección del servidor DNS (ejemplo: 8.8.8.8)" } while (-not $ServidorDNS)

$DireccionRed = Obtener-DireccionRed -IP $DireccionIP -MascaraSubred $MascaraSubred
$DireccionBroadcast = Obtener-DireccionBroadcast -DireccionRed $DireccionRed -MascaraSubred $MascaraSubred

# Convertir direcciones a enteros para comparación
$RedEntero = Convertir-IPaEntero $DireccionRed
$BroadcastEntero = Convertir-IPaEntero $DireccionBroadcast

# Configurar la IP estática
New-NetIPAddress -InterfaceAlias $AdaptadorRed -IPAddress $DireccionIP -PrefixLength 24 -DefaultGateway $PuertaEnlace
Set-DnsClientServerAddress -InterfaceAlias $AdaptadorRed -ServerAddresses $ServidorDNS

Write-Host "La IP estática ha sido configurada correctamente." -ForegroundColor Green

# Instalar el servicio DHCP
Install-WindowsFeature -Name DHCP -IncludeManagementTools

# Solicitar los parámetros del ámbito DHCP con validaciones
$NombreAmbito = Read-Host "Ingrese el nombre del ámbito DHCP"

# Solicitar rangos con validación en bucle
$RangoInicio = ""
do {
    $RangoInicio = Leer-IPValidada "Ingrese la dirección IP de inicio del rango (ejemplo: 192.168.1.100)"
    $InicioEntero = Convertir-IPaEntero $RangoInicio
    if ($InicioEntero -lt ($RedEntero + 1) -or $InicioEntero -gt ($BroadcastEntero - 1)) {
        Write-Host "Error: La IP de inicio no está dentro del rango permitido." -ForegroundColor Red
        $RangoInicio = ""
    }
} while (-not $RangoInicio)

$RangoFin = ""
do {
    $RangoFin = Leer-IPValidada "Ingrese la dirección IP de fin del rango (ejemplo: 192.168.1.200)"
    $FinEntero = Convertir-IPaEntero $RangoFin
    if ($FinEntero -lt $InicioEntero) {
        Write-Host "Error: La IP final del rango no puede ser menor que la IP inicial." -ForegroundColor Red
        $RangoFin = ""
    } elseif ($FinEntero -gt ($BroadcastEntero - 1)) {
        Write-Host "Error: La IP de fin no está dentro del rango permitido." -ForegroundColor Red
        $RangoFin = ""
    }
} while (-not $RangoFin)

$Router = $PuertaEnlace
Write-Host "Se utilizará la puerta de enlace predeterminada $Router para el DHCP."

# Crear el ámbito DHCP
Add-DhcpServerv4Scope -Name $NombreAmbito -StartRange $RangoInicio -EndRange $RangoFin -SubnetMask $MascaraSubred -State Active

# Configurar opciones del ámbito DHCP
Set-DhcpServerv4OptionValue -ScopeId $DireccionRed -Router $Router -DnsServer $ServidorDNS

# Habilitar y reiniciar el servicio DHCP
Set-Service -Name DHCPServer -StartupType Automatic
Restart-Service -Name DHCPServer

Write-Host "El servidor DHCP ha sido configurado correctamente." -ForegroundColor Green
