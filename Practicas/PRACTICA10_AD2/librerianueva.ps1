# Funcion para validar una IP
function validarIP {
    param ([string]$ip)
    if ($ip -match '^([0-9]{1,3}\.){3}[0-9]{1,3}$') {
        $octetos = $ip -split '\.'
        foreach ($octeto in $octetos) {
            if ([int]$octeto -lt 0 -or [int]$octeto -gt 255) {
                return $false
            }
        }
        return $true
    }
    return $false
}

# Funcion para solicitar una IP valida
function solicitarIP {
    param ([string]$mensaje)
    do {
        $ip = Read-Host $mensaje
    } while (-not (validarIP $ip))
    return $ip
}

# Funcion para convertir una máscara de subred en CIDR
function convertirMascaraCidr {
    param ([string]$mascara)
    $octetos = $mascara -split '\.'
    $cidr = 0

    foreach ($octeto in $octetos) {
        $binario = [Convert]::ToString([int]$octeto, 2).PadLeft(8, '0')
        $cidr += ($binario -split '1').Length - 1
    }

    return $cidr
}

# Funcion para configurar una IP estática en Windows Server
function configurarIPestatica {
    param (
        [string]$interfaz,
        [string]$servidorIP,
        [string]$mascara,
        [string]$puertaEnlace,
        [string]$DNS
    )

    # Convertir la mascara a CIDR
    $cidr = convertirMascaraCidr $mascara

    # Configurar la IP estatica
    New-NetIPAddress -InterfaceAlias $interfaz -IPAddress $servidorIP -PrefixLength $cidr -DefaultGateway $puertaEnlace | Out-Null

    # Configurar el DNS
    Set-DnsClientServerAddress -InterfaceAlias $interfaz -ServerAddresses $DNS | Out-Null
}

# Funcion para configurar DHCP en una interfaz
function configurarDHCP {
    param ([string]$interfaz)

    # Habilitar DHCP en la interfaz
    Set-NetIPInterface -InterfaceAlias $interfaz -Dhcp Enabled
}

# Funcion para capturar un número válido
function capturarNumeroValido {
    param ([string]$mensaje)
    do {
        $numero = Read-Host $mensaje
    } while (-not ($numero -match '^\d+$'))
    return $numero
}
function validarContra {
    param (
        [string]$contra
    )

    # Verificar longitud mínima
    if ($contra.Length -lt 8) {
        Write-Host "La password debe tener al menos 8 caracteres."
        return $false
    }

    # Verificar longitud máxima
    if ($contra.Length -gt 15) {
        Write-Host "La password no puede tener mas de 15 caracteres."
        return $false
    }

    # Verificar al menos una letra mayúscula
    if ($contra -notmatch "[A-Z]") {
        Write-Host "La password debe contener al menos una letra mayuscula."
        return $false
    }

    # Verificar al menos una letra minúscula
    if ($contra -notmatch "[a-z]") {
        Write-Host "La password debe contener al menos una letra minuscula."
        return $false
    }

    # Verificar al menos un dígito
    if ($contra -notmatch "\d") {
        Write-Host "La password debe contener al menos un numero."
        return $false
    }

    # Verificar al menos un carácter especial
    if ($contra -notmatch "[^a-zA-Z0-9]") {
        Write-Host "La password debe contener al menos un caracter especial."
        return $false
    }

    # Si pasa todas las validaciones, la password es válida
    return $true
}


# Funcion para capturar una contrasena
function capturarContra {
    do {
        $contra = Read-Host "Ingrese la password (min. 8 caracteres, mayuscula, minuscula, numero, especial)"

        if (-not (validarContra -contra $contra)) {
            Write-Host "La password no cumple con los requisitos. Intentelo de nuevo."
        }
    } while (-not (validarContra -contra $contra))
    return $contra
}

# Funcion para capturar y validar un usuario FTP valido
function capturarUsuarioFTPValido {
    param (
        [string]$mensaje
    )

    $caracteresPermitidos = '^[a-zA-Z0-9]+$'

    $longitudMaxima = 15

    do {
        # Solicitar la cadena al usuario
        $cadena = Read-Host $mensaje

        # Validar que la cadena no esté vacía
        if (-not $cadena) {
            Write-Host "La cadena no puede estar vacia. Intentalo de nuevo." 
        }
        # Validar que la cadena no contenga caracteres no permitidos
        elseif ($cadena -notmatch $caracteresPermitidos) {
            Write-Host "El nombre de usuario solo puede contener letras y números."
        }
        elseif ($cadena -match '^[0-9]') {
            Write-Host "El nombre de usuario no puede comenzar con un numero."
        }
        # Validar que la cadena no exceda la longitud máxima
        elseif ($cadena.Length -gt $longitudMaxima) {
            Write-Host "La cadena no puede exceder los $longitudMaxima caracteres. Intentalo de nuevo." 
        }
        # Validar que el usuario no exista ya en el sistema
        elseif (UsuarioExiste -nombreUsuario $cadena) {
            Write-Host "El usuario '$cadena' ya existe. Por favor, elija otro nombre de usuario."
        }
    } while (-not $cadena -or $cadena -match '^[0-9]' -or $cadena -notmatch $caracteresPermitidos -or $cadena.Length -gt $longitudMaxima -or (UsuarioExiste -nombreUsuario $cadena))

    return $cadena
}

# Funcion para verificar si un usuario ya existe
function UsuarioExiste {
    param (
        [string]$nombreUsuario
    )

    # Obtener el objeto ADSI para buscar el usuario
    $ADSI = [ADSI]"WinNT://$env:ComputerName"
    $usuario = $ADSI.Children | Where-Object { $_.SchemaClassName -eq 'User' -and $_.Name -eq $nombreUsuario }

    # Si el usuario existe, devolver true
    if ($usuario) {
        return $true
    } else {
        return $false
    }
}

# Funcion para capturar y validar la seleccion del grupo
function capturarGrupoFTP {
    do {
        Write-Host "Ingrese el grupo del usuario 1)Reprobados  2)Recursadores: "
        $grupo = Read-Host

        if ($grupo -eq "1") {
            return "reprobados"
        } elseif ($grupo -eq "2") {
            return "recursadores"
        } else {
            Write-Host "Opcion no válida. Por favor, ingrese 1 o 2."
        }
    } while ($true)
}

# Funcion para crear usuarios FTP
function CrearUsuarioFTP {
    param (
        [string]$FTPUserName,
        [string]$FTPPassword,
        [string]$FTPUserGroupName
    )

    # Crear el usuario
    $CreateUserFTPUser = $ADSI.Create("User", "$FTPUserName")
    $CreateUserFTPUser.SetInfo()    
    $CreateUserFTPUser.SetPassword("$FTPPassword")    
    $CreateUserFTPUser.SetInfo()    

    # Asignar el usuario al grupo
    $group = [ADSI]"WinNT://$env:ComputerName/$FTPUserGroupName,group"
    $group.Invoke("Add", "WinNT://$env:ComputerName/$FTPUserName,user")

    # Crear carpeta personal para el usuario
    mkdir "C:\FTP\LocalUser\$FTPUserName"
    # Crear subcarpeta personal 
    mkdir "C:\FTP\LocalUser\$FTPUserName\$FTPUserName"
    if (Test-Path "C:\FTP\LocalUser\$FTPUserName\general") {
        Remove-Item "C:\FTP\LocalUser\$FTPUserName\general" -Force
    }
    # Crear symlink al general Public
    cmd /c mklink /D "C:\FTP\LocalUser\$FTPUserName\general" "C:\FTP\LocalUser\Public\general"
    if (Test-Path "C:\FTP\LocalUser\$FTPUserName\$FTPUserGroupName") {
        Remove-Item "C:\FTP\LocalUser\$FTPUserName\$FTPUserGroupName" -Force
    }
    # Crear symlink al grupo del usuario
    cmd /c mklink /D "C:\FTP\LocalUser\$FTPUserName\$FTPUserGroupName" "C:\FTP\grupos\$FTPUserGroupName"
}



#FTPS



function configurarSSL {
    Write-Host "Generando certificado SSL..."
    # Crear un certificado auto-firmado
    $cert = New-SelfSignedCertificate -DnsName "localhost" -CertStoreLocation "Cert:\LocalMachine\My"
    # Obtener el thumbprint del certificado
    $thumbprint = $cert.Thumbprint
    # Configurar IIS con el SSL generado
    Set-ItemProperty "IIS:\Sites\FTP" -Name "ftpServer.security.ssl.controlChannelPolicy" -Value "SslAllow"
    Set-ItemProperty "IIS:\Sites\FTP" -Name "ftpServer.security.ssl.dataChannelPolicy" -Value "SslAllow"
    Set-ItemProperty "IIS:\Sites\FTP" -Name "ftpServer.security.ssl.serverCertHash" -Value $thumbprint
    Write-Host "SSL habilitado en el sitio FTP."
}

function capturarSSL {
    do {
        $option = Read-Host "Desea habilitar SSL? (s/n)"
    } while ($option -notmatch '^[sn]$')  # Repetir hasta que se ingrese "s" o "n"
    return $option  # Devolver la opción seleccionada
}



# Configuración del servidor FTP
$FTP_SERVER = "192.168.1.14"  # Cambia por la IP de tu servidor
$FTP_USER = "windows"          # Usuario para Windows
$FTP_PASS = "1234"              # Contraseña



# HTTP



# Función para que el usuario seleccione un servicio
function Select-Service {
    Write-Host "Que servicio desea instalar?"
    Write-Host "1. IIS (Solo desde web)"
    Write-Host "2. Apache (Web y FTP)"
    Write-Host "3. Nginx (Web y FTP)"
    do {
        # Solicitar al usuario que seleccione una opción válida (1, 2 o 3)
        $option = Read-Host "Seleccione una opcion (1-3)"
    } while ($option -notmatch '^[1-3]$')  # Repetir hasta que se ingrese una opción válida
    return [int]$option  # Devolver la opción seleccionada como un número entero
}

function Select-Protocol {
    Write-Host "Que protocolo desea usar?"
    Write-Host "1. HTTP"
    Write-Host "2. HTTPS"
    do {
        $option = Read-Host "Seleccione una opcion (1-2)"
    } while ($option -notmatch '^[1-2]$')  # Repetir hasta que se ingrese una opción válida
    return [int]$option  # Devolver la opción seleccionada como un número entero
}

function Select-WebFtp {
    Write-Host "Desde donde desea hacer la instalacion?"
    Write-Host "1. Web"
    Write-Host "2. FTP"
    do {
        $option = Read-Host "Seleccione una opcion (1-2)"
    } while ($option -notmatch '^[1-2]$')  # Repetir hasta que se ingrese una opción válida
    return [int]$option  # Devolver la opción seleccionada como un número entero
}

# Función para que el usuario seleccione una versión de un servicio
function Select-Version($versions) {
    Write-Host "Seleccione la version:"
    # Asegurar que $versions es un array
    if ($versions -isnot [array]) {
        $versions = @($versions)
    }
    # Mostrar las versiones disponibles
    for ($i = 0; $i -lt $versions.Length; $i++) {
        Write-Host "$($i+1). $($versions[$i])"
    }
    do {
        # Solicitar al usuario que seleccione una versión válida
        $index = Read-Host "Seleccione una opcion (1-$($versions.Length))"
    } while ($index -notmatch "^[1-$($versions.Length)]$")  # Repetir hasta que se ingrese una opción válida
    return $versions[[int]$index - 1]  # Devolver la versión seleccionada
}

# Función para que el usuario seleccione un puerto válido
function Select-Port($protocolo){
    
    if ($protocolo -eq 1){
        $reservedPorts = @(1,7,9,11,13,15,17,19,20,21,22,23,25,37,42,43,53,69,77,79,87,95,101,102,103,104,109,110,111,113,115,117,118,119,123,135,137,139,143,161,177,179,389,427,443,445,465,512,513,514,515,526,530,531,532,540,548,554,556,563,587,601,636,989,990,993,995,1723,2049,6667,8443)
    } else {
        $reservedPorts = @(1,7,9,11,13,15,17,19,20,21,22,23,25,37,42,43,53,69,77,79,80,87,95,101,102,103,104,109,110,111,113,115,117,118,119,123,135,137,139,143,161,177,179,389,427,445,465,512,513,514,515,526,530,531,532,540,548,554,556,563,587,601,636,989,990,993,995,1723,2049,6667,8080)
    }

    do {
        # Solicitar al usuario que ingrese un puerto
        $inputValue = Read-Host "Ingrese el puerto para asignar al servicio (1-65535)"
        if ($inputValue -match '^\d+$') {
            $port = [int]$inputValue  
            if ($port -ge 1 -and $port -le 65535) {
                if ($reservedPorts -contains $port) {
                    Write-Host "El puerto $port esta reservado para servicios conocidos. Seleccione otro puerto."
                } else {
                    # Verificar si el puerto está en uso
                    $puertoValido = (Test-NetConnection -ComputerName localhost -Port $port).TcpTestSucceeded    
                    if (-not $puertoValido) {
                        return $port  # Devolver el puerto si está libre
                    } else {
                        Write-Host "Puerto en uso. Seleccione otro puerto."
                    }
                }
            } else {
                Write-Host "El puerto no se encuentra entre 1024 y 65535. Seleccione otro puerto."
            }
        } else {
            Write-Host "El puerto debe de ser un numero"
        }
    } while ($true)  # Repetir hasta que se ingrese un puerto válido
}

# Función para agregar una regla de firewall
function Add-FirewallRule($port) {
    Write-Host "Agregando regla de firewall para permitir el acceso al puerto $port..."
    # Crear una nueva regla de firewall para permitir tráfico en el puerto especificado
    New-NetFirewallRule -DisplayName "Servicio HTTP $port" -Direction Inbound -Protocol TCP -LocalPort $port -Action Allow
    Write-Host "Regla de firewall agregada para el puerto $port."
}

# Función para instalar IIS
function Install-IIS($port, $protocolo) {
    # Verificar si IIS ya está instalado
    $iisInstalled = Get-WindowsFeature -Name Web-Server | Where-Object { $_.Installed -eq $true }
    if (-not $iisInstalled) {
        Write-Host "Instalando IIS..."
        # Instalar IIS si no está instalado
        Install-WindowsFeature -Name Web-Server -IncludeManagementTools
        Write-Host "IIS instalado correctamente."
    } else {
        Write-Host "IIS ya esta instalado. Se configurara el puerto."
    }
    # Importar el módulo para administrar IIS
    Import-Module WebAdministration
    # Detener el sitio web predeterminado antes de cambiar la configuración
    Stop-WebSite -Name "Default Web Site"
    # Remover enlaces existentes en el sitio
    $sitePath = "IIS:\Sites\Default Web Site"
    $existingBindings = Get-ItemProperty -Path $sitePath -Name Bindings
    $existingBindings.Collection.Clear()

    if ($protocolo -eq 1) {
        # Agregar un nuevo enlace con el puerto especificado
        New-WebBinding -Name "Default Web Site" -Protocol "http" -Port $port -IPAddress "*"
    } else {
        # Llamar a la función para generar un certificado autofirmado
        $certThumbprint = generar_certificado_ssl $port
        New-WebBinding -Name "Default Web Site" -Protocol "https" -IPAddress "*" -Port $port
        netsh http add sslcert ipport=0.0.0.0:$port certhash=$certThumbprint appid="{00112233-4455-6677-8899-AABBCCDDEEFF}"
    }

    # Reiniciar el sitio web para aplicar los cambios
    Start-WebSite -Name "Default Web Site"
    # Agregar una regla de firewall para permitir tráfico en el puerto
    Add-FirewallRule -port $port

    Write-Host "IIS instalado y listo para la revision del profe Herman!!!"
}

function generar_certificado_ssl ($puerto){
    Write-Host "Generando certificado SSL autofirmado para IIS..."

    # Definir el nombre del certificado y el puerto
    $certName = "IIS-SSL-Cert-$puerto"

    # Crear el certificado autofirmado
    $cert = New-SelfSignedCertificate -DnsName "localhost" -CertStoreLocation "Cert:\LocalMachine\My" `
        -FriendlyName $certName -NotAfter (Get-Date).AddYears(1) -KeyExportPolicy Exportable

    if ($cert) {
        Write-Host "Certificado SSL generado correctamente: $cert.Thumbprint"
        return $cert.Thumbprint
    } else {
        Write-Host "Error al generar el certificado SSL."
    }
}

# Función para instalar Apache
function Install-Apache {
    param(
        [string] $version,
        [int] $puerto,
        [string] $protocolo,
        [int] $web_ftp
    )

    # Definir ruta de extracción
    $extraerdestino = "C:\Apache24"

    try {
        Write-Host "Iniciando instalación de Apache HTTP Server versión $version..."

        # Descargar Apache desde la web o FTP según la opción seleccionada
        if ($web_ftp -eq 2) {
            # Descargar desde FTP
            $ftpUri = "ftp://$FTP_SERVER/Apache/$version"
            $destinoZip = "$env:USERPROFILE\Downloads\apache-$version.zip"
            Write-Host "Descargando Apache desde FTP: $ftpUri"
            $webClient = New-Object System.Net.WebClient
            $webClient.Credentials = New-Object System.Net.NetworkCredential($FTP_USER, $FTP_PASS)
            $webClient.DownloadFile($ftpUri, $destinoZip)
        } else {
            # Descargar desde la web
            $url = "https://www.apachelounge.com/download/VS17/binaries/httpd-$version-250207-win64-VS17.zip"
            $destinoZip = "$env:USERPROFILE\Downloads\apache-$version.zip"
            Write-Host "Descargando Apache desde: $url"
            $agente = "Mozilla/5.0 (Windows NT 10.0; Win64; x64)"
            Invoke-WebRequest -Uri $url -OutFile $destinoZip -MaximumRedirection 10 -UserAgent $agente -UseBasicParsing
        }

        # Extraer Apache en C:\Apache24
        Write-Host "Extrayendo archivos de Apache..."
        Expand-Archive -Path $destinoZip -DestinationPath "C:\" -Force
        Remove-Item -Path $destinoZip -Force

        # Configurar SSL si el protocolo es HTTPS
        if ($protocolo -eq 2) {
            Write-Host "Configurando Apache para HTTPS..."

            # Crear carpeta SSL si no existe
            $sslDir = "$extraerdestino\conf\ssl"
            if (-not (Test-Path $sslDir)) {
                New-Item -ItemType Directory -Path $sslDir -Force | Out-Null
            }

            # Verificar si OpenSSL está instalado
            $opensslPath = "C:\OpenSSL-Win64\bin\openssl.exe"
            if (-Not (Test-Path $opensslPath)) {
                Write-Host "Error: OpenSSL no está instalado en la ruta esperada."
                return
            }

            # Generar clave privada y certificado
            Write-Host "Generando certificado SSL con OpenSSL..."
            & $opensslPath req -x509 -nodes -days 365 -newkey rsa:2048 `
                -keyout "$sslDir\server.key" -out "$sslDir\server.crt" `
                -subj "/C=MX/ST=Sinaloa/L=LosMochis/O=Empresa/OU=IT/CN=localhost" 2>&1 | Out-Null

            Write-Host "Certificado generado correctamente en $sslDir"
        }

        # Configurar httpd.conf
        $configFile = Join-Path $extraerdestino "conf\httpd.conf"
        if (Test-Path $configFile) {
            $confContent = Get-Content $configFile

            # Descomentar módulos necesarios para SSL
            $confContent = $confContent -replace "#\s*LoadModule ssl_module modules/mod_ssl.so", "LoadModule ssl_module modules/mod_ssl.so"
            $confContent = $confContent -replace "#\s*LoadModule socache_shmcb_module modules/mod_socache_shmcb.so", "LoadModule socache_shmcb_module modules/mod_socache_shmcb.so"
            $confContent = $confContent -replace "#\s*LoadModule headers_module modules/mod_headers.so", "LoadModule headers_module modules/mod_headers.so"

            if ($protocolo -eq 2) {
                # Si HTTPS está activado, eliminar cualquier "Listen" de httpd.conf
                $confContent = $confContent -replace "(?m)^Listen \d+", ""

                # Descomentar o agregar la línea para incluir httpd-ssl.conf
                if ($confContent -match "#\s*Include conf/extra/httpd-ssl.conf") {
                    $confContent = $confContent -replace "#\s*Include conf/extra/httpd-ssl.conf", "Include conf/extra/httpd-ssl.conf"
                } elseif (-not ($confContent -match "Include conf/extra/httpd-ssl.conf")) {
                    Add-Content -Path $configFile -Value "`nInclude conf/extra/httpd-ssl.conf"
                }
            } else {
                # Si HTTPS no está activado, asegurarse de que Listen solo está en httpd.conf
                $confContent = $confContent -replace "(?m)^Listen \d+", "Listen $puerto"
            }

            # Guardar cambios en httpd.conf
            $confContent | Set-Content $configFile
        } else {
            Write-Host "Error: No se encontró el archivo de configuración en $configFile"
            return
        }

        # Configurar httpd-ssl.conf si HTTPS está activado
        if ($protocolo -eq 2) {
            $sslConfFile = Join-Path $extraerdestino "conf\extra\httpd-ssl.conf"
            if (Test-Path $sslConfFile) {
                $sslContent = Get-Content $sslConfFile

                # Asegurar que se usa el puerto correcto
                $sslContent = $sslContent -replace "Listen \d+", "Listen $puerto"
                $sslContent = $sslContent -replace "VirtualHost _default_:\d+", "VirtualHost _default_:$puerto"

                # Asegurar rutas absolutas a los certificados
                $sslContent = $sslContent -replace "SSLCertificateFile .*", "SSLCertificateFile `"$sslDir\server.crt`""
                $sslContent = $sslContent -replace "SSLCertificateKeyFile .*", "SSLCertificateKeyFile `"$sslDir\server.key`""

                # Guardar cambios en httpd-ssl.conf
                $sslContent | Set-Content $sslConfFile
            } else {
                Write-Host "Error: No se encontró el archivo httpd-ssl.conf"
                return
            }
        }

        # Buscar el ejecutable de Apache
        $apacheExe = Get-ChildItem -Path $extraerdestino -Recurse -Filter httpd.exe -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($apacheExe) {
            $exeApache = $apacheExe.FullName
            Start-Process -FilePath $exeApache -ArgumentList '-k', 'install', '-n', 'Apache24' -NoNewWindow -Wait

            Start-Service -Name "Apache24"
            Write-Host "Apache instalado y ejecutándose en el puerto $puerto"

            # Habilitar el puerto en el firewall
            Add-FirewallRule -port $port
        } else {
            Write-Host "Error: No se encontró el ejecutable httpd.exe en $extraerdestino"
        }
    } catch {
        Write-Host "Error: $_"
    }
}

# Función para instalar VC++ Redistributable
function Install-VC {
    # Verificar si VC++ Redistributable ya está instalado
    if ((Test-Path "C:\Windows\System32\VCRUNTIME140.dll") -or (Test-Path "C:\Windows\SysWOW64\VCRUNTIME140.dll")) {
        Write-Output "VC++ Redistributable ya instalado."
        Return
    } else {
        Write-Output "Instalando VC++..."
        # URL de descarga de VC++ Redistributable
        $vcUrl = "https://aka.ms/vs/16/release/vc_redist.x64.exe"
        $tempDir = "C:\temp"
        if (!(Test-Path $tempDir)) {
            New-Item -Path $tempDir -ItemType Directory | Out-Null
        }
        $vcInstaller = "$tempDir\vc_redist.x64.exe"
        # Descargar VC++ Redistributable
        Invoke-WebRequest -Uri $vcUrl -OutFile $vcInstaller -UseBasicParsing
        # Instalar VC++ Redistributable en modo silencioso
        Start-Process -FilePath $vcInstaller -ArgumentList "/install", "/quiet", "/norestart" -NoNewWindow -Wait
        Start-Sleep -Seconds 4
        Remove-Item $vcInstaller -Force
        # Verificar si la instalación fue exitosa
        if ((Test-Path "C:\Windows\System32\VCRUNTIME140.dll") -or (Test-Path "C:\Windows\SysWOW64\VCRUNTIME140.dll")) {
            Write-Output "VC++ instalado correctamente."
        } else {
            Write-Output "Error: La instalacion de VC++ fallo."
        }
        Return
    }
}

# Función para instalar Nginx
function Install-Nginx($ver,$puerto,$protocolo,$web_ftp){
    Write-Host "$puerto"
    # Extraer solo la versión (10.9.2) de la cadena (nginx-10.9.2.zip)
    $version = $ver -replace '^nginx-|\.zip$', ''

    # Descargar Nginx desde la web o FTP según la opción seleccionada
    if ($web_ftp -eq 2) {
        # Descargar desde FTP
        $ftpUri = "ftp://$FTP_SERVER/Nginx/$ver"
        $destino = "$env:USERPROFILE\Downloads\$ver"
        Write-Host "Descargando Nginx desde FTP: $ftpUri"
        $webClient = New-Object System.Net.WebClient
        $webClient.Credentials = New-Object System.Net.NetworkCredential($FTP_USER, $FTP_PASS)
        $webClient.DownloadFile($ftpUri, $destino)
    } else {
        $destino = "$env:USERPROFILE\Downloads\nginx.zip"
        Write-Host "Descargando Nginx desde la web..."
        # Descargar Nginx desde la URL oficial
        Invoke-WebRequest -Uri "https://nginx.org/download/nginx-$version.zip" -OutFile $destino
    }

    # Extraer el archivo descargado
    $extraerRuta = "C:\nginx-$version"
    Expand-Archive -Path $destino -DestinationPath "C:\" -Force
    Remove-Item -Path $destino -Force

    # Configurar el archivo nginx.conf
    $conf = "$extraerRuta\conf\nginx.conf"
    if (Test-Path $conf) {
        (Get-Content $conf) -replace "#error_log  logs/error.log;", "error_log  logs/error.log;" | Set-Content $conf
        (Get-Content $conf) -replace "#access_log  logs/access.log  main;", "access_log  logs/access.log;" | Set-Content $conf
    } else {
        Write-Host "Error: No se encontró el archivo de configuración nginx.conf."
        return
    }

    # Configurar SSL si el protocolo es HTTPS
    if ($protocolo -eq 2) {
        Write-Host "Configurando Nginx para HTTPS..."

        # Crear carpeta SSL si no existe
        $sslDir = "$extraerRuta\conf\ssl"
        if (-not (Test-Path $sslDir)) {
            New-Item -ItemType Directory -Path $sslDir -Force | Out-Null
        }

        # Generar certificado autofirmado
        $cert = New-SelfSignedCertificate -Subject "CN=localhost" -CertStoreLocation Cert:\LocalMachine\My -KeyExportPolicy Exportable -KeySpec Signature -NotAfter (Get-Date).AddYears(1)
        $certcontra = ConvertTo-SecureString -String "P@ssw0rd" -Force -AsPlainText
        $certPath = "$sslDir\localhost.pfx"
        Export-PfxCertificate -Cert $cert -FilePath $certPath -Password $certcontra

        # Convertir certificado a formato PEM
        $certPem = "$sslDir\localhost.crt"
        $keyPem = "$sslDir\localhost.key"
        Invoke-Expression "openssl pkcs12 -in $certPath -out $certPem -nodes -nokeys -password pass:P@ssw0rd"
        Invoke-Expression "openssl pkcs12 -in $certPath -out $keyPem -nodes -nocerts -password pass:P@ssw0rd"
        (Get-Content $conf) -replace "listen       80;", "listen       61234;" | Set-Content $conf
        
        # Definir el bloque HTTPS descomentado
        $nginxsincom = @"
server { # HTTPS server
    listen       $puerto ssl;
    server_name  localhost;

    ssl_certificate      ssl/localhost.crt;
    ssl_certificate_key  ssl/localhost.key;

    ssl_session_cache    shared:SSL:1m;
    ssl_session_timeout  5m;

    ssl_ciphers  HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers  on;

    location / {
        root   html;
        index  index.html index.htm;
    }
}
"@

        # Leer el contenido del archivo de configuración
        $contenido = Get-Content -Path $conf -Raw

        # Expresión regular para buscar la sección comentada como HTTPS
        $nginxcomentado = '#\s*HTTPS server'

        # Reemplazar la sección comentada como HTTPS por el bloque descomentado
        if ($contenido -match $nginxcomentado) {
            $cambioconf = $contenido -replace $nginxcomentado, $nginxsincom
            $cambioconf | Set-Content -Path $conf
            Write-Host "Configuración HTTPS aplicada."
        }
    } else {
        # Configurar el puerto para HTTP
        (Get-Content $conf) -replace "listen       80;", "listen       $puerto;" | Set-Content $conf
    }

    # Iniciar Nginx
    Start-Process -FilePath "$extraerRuta\nginx.exe" -WorkingDirectory $extraerRuta -NoNewWindow

    # Agregar una regla de firewall para el puerto
    Add-FirewallRule -port $puerto

    Write-Host "Nginx instalado y listo para la revisión del profe Herman!!!"
}

# Función para verificar si Apache está instalado
function Is-ApacheInstalled {
    return (Get-Service -Name "Apache24" -ErrorAction SilentlyContinue) -ne $null
}

# Función para verificar si Nginx está instalado
function Is-NginxInstalled {
    return (Get-Process -Name "nginx" -ErrorAction SilentlyContinue) -ne $null
}

function Get-NginxVersions {
    Invoke-WebRequest -Uri "https://nginx.org/en/download.html" -OutFile "nginx.html"

        $paginanginx = Get-Content -Path "nginx.html" -Raw
        $links = [regex]::Matches($paginanginx, '<a href="(/download/nginx-\d+\.\d+\.\d+\.zip)">nginx/Windows-\d+\.\d+\.\d+</a>') | ForEach-Object {
            [PSCustomObject]@{
                Url = "https://nginx.org" + $_.Groups[1].Value
                Version = ($_.Groups[1].Value -replace '/download/nginx-', '') -replace '\.zip', ''
            }
        }
    
    $Versionesarray = $links | Sort-Object { [version]$_.Version } -Descending    
    $dev = $Versionesarray[0].Version
    $lts = $Versionesarray[1].version
    return @($dev,$lts)
}

function Get-ApacheVersions {
    Invoke-WebRequest -Uri "https://httpd.apache.org/download.cgi" -OutFile "apache.html"
    $PaginaApache = Get-Content -Path "apache.html" -Raw
    $lts = [regex]::Match($PaginaApache, '<h1 id="apache24">Apache HTTP Server ([\d.]+)').Groups[1].Value
    return @($lts)
}

function seleccionar_version_ftp($servicio){

    # Ajustar la carpeta FTP según el servicio seleccionado
    $carpeta_ftp = switch ($servicio) {
        2 { "Apache" }
        3 { "Nginx" }
        default {
            return
        }
    }

    # Definir la URL del FTP
    $ftpUri = "ftp://$FTP_SERVER/$carpeta_ftp/"

    # Crear la solicitud FTP para obtener la lista de archivos
    try {
        $request = [System.Net.FtpWebRequest]::Create($ftpUri)
        $request.Method = [System.Net.WebRequestMethods+Ftp]::ListDirectory
        $request.Credentials = New-Object System.Net.NetworkCredential($FTP_USER, $FTP_PASS)
        $request.UseBinary = $true
        $request.UsePassive = $true

        $response = $request.GetResponse()
        $stream = $response.GetResponseStream()
        $reader = New-Object System.IO.StreamReader($stream)
        $versionesDisponibles = $reader.ReadToEnd() -split "`r`n"

        $reader.Close()
        $response.Close()

        # Filtrar solo archivos válidos según el servicio
        $versionesDisponibles = $versionesDisponibles | Where-Object { 
            $_ -match '^(httpd-[0-9]+\.[0-9]+\.[0-9]+.*\.zip|nginx-[0-9]+\.[0-9]+\.[0-9]+.*\.zip)$' 
        }

        if ($versionesDisponibles.Count -eq 0 -or -not $versionesDisponibles[0]) {
            Write-Host "No se encontraron versiones disponibles en el servidor FTP para $global:servicio."
            return
        }

        return $versionesDisponibles
    } catch {
        Write-Host "Error al conectar al servidor FTP: $_"
    }
}


function Install-Openssl {
    $opensslPath = "C:\OpenSSL-Win64\bin"    
    if(Test-Path $opensslPath){
        Write-Host "Openssl instalado"
    }else{
        $Url = "https://slproweb.com/download/Win64OpenSSL-3_4_1.exe"  # Cambia la URL si necesitas otra versión

        $instalacion = "$env:TEMP\OpenSSL_Installer.exe"
        Write-Host "Descargando OpenSSL..."
        Invoke-WebRequest -Uri $Url -OutFile $instalacion

        Write-Host "Instalando OpenSSL..."
        Start-Process -FilePath $instalacion -ArgumentList "/silent /verysilent /sp- /suppressmsgboxes /DIR=C:\OpenSSL-Win64" -Wait

        if (-not ($env:Path -split ';' -contains $opensslPath)) {
            [Environment]::SetEnvironmentVariable("Path", "$env:Path;$opensslPath", [EnvironmentVariableTarget]::Machine)
            $env:Path += ";$opensslPath"
        }

        # Verificar la instalación
        Write-Host "Verificando la instalación de OpenSSL..."
        try {
            # Verificar si OpenSSL realmente existe en la ruta esperada
            if (-Not (Test-Path "$opensslPath\openssl.exe")) {
                throw "El archivo OpenSSL.exe no se encontró en $opensslPath. La instalación puede haber fallado."
            }
        
            # Ejecutar OpenSSL para obtener la versión
            $opensslVersion = & "$opensslPath\openssl.exe" version 2>&1
        
            # Si OpenSSL devuelve un error, forzar la excepción
            if ($opensslVersion -match "error|failed|not recognized") {
                throw "Error al ejecutar OpenSSL: $opensslVersion"
            }
        
            Write-Host "OpenSSL instalado correctamente. Versión: $opensslVersion"
        } catch {
            Write-Host "Error al verificar la instalación de OpenSSL: $_"
        }

        Remove-Item -Path $instalacion -Force
    }
}



# CORREOS



function Install-VC2012 {
    # Verificar si VC++ Redistributable ya está instalado
    if ((Test-Path "C:\Windows\System32\VCRUNTIME110.dll") -or (Test-Path "C:\Windows\SysWOW64\VCRUNTIME110.dll")) {
        Write-Output "VC++ Redistributable ya instalado."
        Return
    } else {
        Write-Output "Instalando VC++ 2012..."
        # URL de descarga de VC++ Redistributable
        $vcUrl = "https://wampserver.aviatechno.net/files/vcpackages/vcredist_2012_upd4_x64.exe"
        $tempDir = "C:\temp"
        if (!(Test-Path $tempDir)) {
            New-Item -Path $tempDir -ItemType Directory | Out-Null
        }
        $vcInstaller = "$tempDir\vcredist_2012_upd4_x64.exe"
        # Descargar VC++ Redistributable
        Invoke-WebRequest -Uri $vcUrl -OutFile $vcInstaller -UseBasicParsing
        # Instalar VC++ Redistributable en modo silencioso
        Start-Process -FilePath $vcInstaller -ArgumentList "/install", "/quiet", "/norestart" -NoNewWindow -Wait
        Start-Sleep -Seconds 4
        Remove-Item $vcInstaller -Force
        Return
    }
}

function Install-ApacheCorreo {
    Install-VC
    $extraerdestino = "C:\Apache24"
    $Url = "https://www.apachelounge.com/download/VS17/binaries/httpd-2.4.63-250207-win64-VS17.zip"
    $destino = "$env:USERPROFILE\Downloads\apache-2.4.63-250207-win64.zip"      
    # Descargar Apache
    $Agente = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36"
    Invoke-WebRequest -Uri $Url -OutFile $destino -MaximumRedirection 10 -UserAgent $Agente -UseBasicParsing
    Expand-Archive -Path $destino -DestinationPath "C:\" -Force
    Remove-Item -Path $destino
    # Configurar el puerto en httpd.conf
    Join-Path $extraerdestino "conf\httpd.conf"
    # Buscar el ejecutable de Apache
    $apacheexe = Get-ChildItem -Path $extraerdestino -Recurse -Filter httpd.exe -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($apacheexe) {
        $exeapache = $apacheexe.FullName
        Write-Host "Instalando Apache desde $exeapache"
        Start-Process -FilePath $exeapache -ArgumentList '-k', 'install', '-n', 'Apache24' -NoNewWindow -Wait
        Write-Host "Iniciando Apache"
        Start-Service -Name "Apache24"
        Write-Host "Apache instalado y ejecutándose en el puerto $puerto"
    } else {
        Write-Host "No se encontró httpd.exe en $extraerdestino"
    }

}




function Install-PHP{
    Install-VC2012

    $url="https://windows.php.net/downloads/releases/archives/php-5.6.9-Win32-VC11-x64.zip"
    $destino = "$env:USERPROFILE\Downloads\php.zip"      
    $phpDir = "C:\php"
    if(Test-Path "C:\php"){
        New-Item -ItemType Directory -Name "C:\php"
    }
    # Descargar Apache
    $Agente = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36"
    Invoke-WebRequest -Uri $Url -OutFile $destino -MaximumRedirection 10 -UserAgent $Agente -UseBasicParsing
    Expand-Archive -Path $destino -DestinationPath "C:\php" -Force
    
    Remove-Item -Path $destino

    $currentPath = [Environment]::GetEnvironmentVariable("PATH", "Machine")
    if (-not ($currentPath -split ';' -contains $phpDir)) {
        [Environment]::SetEnvironmentVariable(
            "PATH",
            $currentPath + ";$phpDir",
            "Machine"
        )
    }
$apacheConf = @"
LoadModule php5_module "C:/php/php5apache2_4.dll"
AddHandler application/x-httpd-php .php
PHPIniDir "C:/php"
"@
    
Add-Content -Path "C:\Apache24\conf\httpd.conf" -Value $apacheConf
Copy-Item -Path "$phpDir\php.ini-development" -Destination "$phpDir\php.ini" -Force
# Reiniciar Apache 
Restart-Service -Name "Apache24" -Force
}   

function Install-Squirrel{
    param($ip,$dominio)
    #Instalar apache *
    Install-ApacheCorreo
    #instalar php menor a 7, los 7 una trolleada de manual pipippipi *
    Install-PHP
    #descargar squirrelmail y dejarlo en htdocs 

    $Headers = @{
        "Accept" = "text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8"
        "Accept-Language" = "en-US,en;q=0.5"
    }
    $Url = "https://drive.usercontent.google.com/u/0/uc?id=1WDRT2DlR4g64XHuwMfXkj9X-RQAoPPcB&export=download"
    $destino = "$env:USERPROFILE\Downloads\squirrelmail.zip"      
    if(-not(Test-Path "C:\Apache24\htdocs\squirrelmail")){

        $Agente = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36"
        Invoke-WebRequest -Uri $Url -OutFile $destino -MaximumRedirection 10 -UserAgent $Agente -Headers $Headers -UseBasicParsing
        Expand-Archive -Path $destino -DestinationPath "C:\Apache24\htdocs\" -Force
        Rename-Item -Path "C:\Apache24\htdocs\squirrelmail-webmail-1.4.22" -NewName "squirrelmail"

        New-Item -Path "C:\Apache24\htdocs\squirrelmail\config\" -name "config.php" -ItemType File
@"

<?php

/**
 * SquirrelMail Configuration File
 * Created using the configure script, conf.pl
 */

global `$version;
`$config_version = '1.4.0';
`$config_use_color = 2;

`$org_name      = "$dominio";
`$org_logo      = SM_PATH . 'images/sm_logo.png';
`$org_logo_width  = '308';
`$org_logo_height = '111';
`$org_title     = "SquirrelMail `$version";
`$signout_page  = '';
`$frame_top     = '_top';

`$provider_uri     = 'http://squirrelmail.org/';

`$provider_name     = 'SquirrelMail';

`$motd = "";

`$squirrelmail_default_language = 'en_US';
`$default_charset       = 'iso-8859-1';
`$lossy_encoding        = false;

`$domain                 = '$dominio';
`$imapServerAddress      = '$ip';
`$imapPort               = 143;
`$useSendmail            = false;
`$smtpServerAddress      = '$ip';
`$smtpPort               = 25;
`$sendmail_path          = '/usr/sbin/sendmail';
`$sendmail_args          = '-i -t';
`$pop_before_smtp        = true;
`$pop_before_smtp_host   = '$ip';
`$imap_server_type       = 'other';
`$invert_time            = false;
`$optional_delimiter     = 'detect';
`$encode_header_key      = '';

`$default_folder_prefix          = '';
`$trash_folder                   = 'INBOX.Trash';
`$sent_folder                    = 'INBOX.Sent';
`$draft_folder                   = 'INBOX.Drafts';
`$default_move_to_trash          = true;
`$default_move_to_sent           = true;
`$default_save_as_draft          = true;
`$show_prefix_option             = false;
`$list_special_folders_first     = true;
`$use_special_folder_color       = true;
`$auto_expunge                   = true;
`$default_sub_of_inbox           = true;
`$show_contain_subfolders_option = false;
`$default_unseen_notify          = 2;
`$default_unseen_type            = 1;
`$auto_create_special            = true;
`$delete_folder                  = false;
`$noselect_fix_enable            = false;

`$data_dir                 = 'C:\Apache24\htdocs\squirrelmail\data';
`$attachment_dir           = 'C:\Apache24\htdocs\squirrelmail\attach';
`$dir_hash_level           = 0;
`$default_left_size        = '150';
`$force_username_lowercase = false;
`$default_use_priority     = true;
`$hide_sm_attributions     = false;
`$default_use_mdn          = true;
`$edit_identity            = true;
`$edit_name                = true;
`$hide_auth_header         = false;
`$allow_thread_sort        = false;
`$allow_server_sort        = false;
`$allow_charset_search     = true;
`$uid_support              = true;


`$theme_css = '';
`$theme_default = 0;
`$theme[0]['PATH'] = SM_PATH . 'themes/default_theme.php';
`$theme[0]['NAME'] = 'Default';
`$theme[1]['PATH'] = SM_PATH . 'themes/plain_blue_theme.php';
`$theme[1]['NAME'] = 'Plain Blue';
`$theme[2]['PATH'] = SM_PATH . 'themes/sandstorm_theme.php';
`$theme[2]['NAME'] = 'Sand Storm';
`$theme[3]['PATH'] = SM_PATH . 'themes/deepocean_theme.php';
`$theme[3]['NAME'] = 'Deep Ocean';
`$theme[4]['PATH'] = SM_PATH . 'themes/slashdot_theme.php';
`$theme[4]['NAME'] = 'Slashdot';
`$theme[5]['PATH'] = SM_PATH . 'themes/purple_theme.php';
`$theme[5]['NAME'] = 'Purple';
`$theme[6]['PATH'] = SM_PATH . 'themes/forest_theme.php';
`$theme[6]['NAME'] = 'Forest';
`$theme[7]['PATH'] = SM_PATH . 'themes/ice_theme.php';
`$theme[7]['NAME'] = 'Ice';
`$theme[8]['PATH'] = SM_PATH . 'themes/seaspray_theme.php';
`$theme[8]['NAME'] = 'Sea Spray';
`$theme[9]['PATH'] = SM_PATH . 'themes/bluesteel_theme.php';
`$theme[9]['NAME'] = 'Blue Steel';
`$theme[10]['PATH'] = SM_PATH . 'themes/dark_grey_theme.php';
`$theme[10]['NAME'] = 'Dark Grey';
`$theme[11]['PATH'] = SM_PATH . 'themes/high_contrast_theme.php';
`$theme[11]['NAME'] = 'High Contrast';
`$theme[12]['PATH'] = SM_PATH . 'themes/black_bean_burrito_theme.php';
`$theme[12]['NAME'] = 'Black Bean Burrito';
`$theme[13]['PATH'] = SM_PATH . 'themes/servery_theme.php';
`$theme[13]['NAME'] = 'Servery';
`$theme[14]['PATH'] = SM_PATH . 'themes/maize_theme.php';
`$theme[14]['NAME'] = 'Maize';
`$theme[15]['PATH'] = SM_PATH . 'themes/bluesnews_theme.php';
`$theme[15]['NAME'] = 'BluesNews';
`$theme[16]['PATH'] = SM_PATH . 'themes/deepocean2_theme.php';
`$theme[16]['NAME'] = 'Deep Ocean 2';
`$theme[17]['PATH'] = SM_PATH . 'themes/blue_grey_theme.php';
`$theme[17]['NAME'] = 'Blue Grey';
`$theme[18]['PATH'] = SM_PATH . 'themes/dompie_theme.php';
`$theme[18]['NAME'] = 'Dompie';
`$theme[19]['PATH'] = SM_PATH . 'themes/methodical_theme.php';
`$theme[19]['NAME'] = 'Methodical';
`$theme[20]['PATH'] = SM_PATH . 'themes/greenhouse_effect.php';
`$theme[20]['NAME'] = 'Greenhouse Effect (Changes)';
`$theme[21]['PATH'] = SM_PATH . 'themes/in_the_pink.php';
`$theme[21]['NAME'] = 'In The Pink (Changes)';
`$theme[22]['PATH'] = SM_PATH . 'themes/kind_of_blue.php';
`$theme[22]['NAME'] = 'Kind of Blue (Changes)';
`$theme[23]['PATH'] = SM_PATH . 'themes/monostochastic.php';
`$theme[23]['NAME'] = 'Monostochastic (Changes)';
`$theme[24]['PATH'] = SM_PATH . 'themes/shades_of_grey.php';
`$theme[24]['NAME'] = 'Shades of Grey (Changes)';
`$theme[25]['PATH'] = SM_PATH . 'themes/spice_of_life.php';
`$theme[25]['NAME'] = 'Spice of Life (Changes)';
`$theme[26]['PATH'] = SM_PATH . 'themes/spice_of_life_lite.php';
`$theme[26]['NAME'] = 'Spice of Life - Lite (Changes)';
`$theme[27]['PATH'] = SM_PATH . 'themes/spice_of_life_dark.php';
`$theme[27]['NAME'] = 'Spice of Life - Dark (Changes)';
`$theme[28]['PATH'] = SM_PATH . 'themes/christmas.php';
`$theme[28]['NAME'] = 'Holiday - Christmas';
`$theme[29]['PATH'] = SM_PATH . 'themes/darkness.php';
`$theme[29]['NAME'] = 'Darkness (Changes)';
`$theme[30]['PATH'] = SM_PATH . 'themes/random.php';
`$theme[30]['NAME'] = 'Random (Changes every login)';
`$theme[31]['PATH'] = SM_PATH . 'themes/midnight.php';
`$theme[31]['NAME'] = 'Midnight';
`$theme[32]['PATH'] = SM_PATH . 'themes/alien_glow.php';
`$theme[32]['NAME'] = 'Alien Glow';
`$theme[33]['PATH'] = SM_PATH . 'themes/dark_green.php';
`$theme[33]['NAME'] = 'Dark Green';
`$theme[34]['PATH'] = SM_PATH . 'themes/penguin.php';
`$theme[34]['NAME'] = 'Penguin';
`$theme[35]['PATH'] = SM_PATH . 'themes/minimal_bw.php';
`$theme[35]['NAME'] = 'Minimal BW';
`$theme[36]['PATH'] = SM_PATH . 'themes/redmond.php';
`$theme[36]['NAME'] = 'Redmond';
`$theme[37]['PATH'] = SM_PATH . 'themes/netstyle_theme.php';
`$theme[37]['NAME'] = 'Net Style';
`$theme[38]['PATH'] = SM_PATH . 'themes/silver_steel_theme.php';
`$theme[38]['NAME'] = 'Silver Steel';
`$theme[39]['PATH'] = SM_PATH . 'themes/simple_green_theme.php';
`$theme[39]['NAME'] = 'Simple Green';
`$theme[40]['PATH'] = SM_PATH . 'themes/wood_theme.php';
`$theme[40]['NAME'] = 'Wood';
`$theme[41]['PATH'] = SM_PATH . 'themes/bluesome.php';
`$theme[41]['NAME'] = 'Bluesome';
`$theme[42]['PATH'] = SM_PATH . 'themes/simple_green2.php';
`$theme[42]['NAME'] = 'Simple Green 2';
`$theme[43]['PATH'] = SM_PATH . 'themes/simple_purple.php';
`$theme[43]['NAME'] = 'Simple Purple';
`$theme[44]['PATH'] = SM_PATH . 'themes/autumn.php';
`$theme[44]['NAME'] = 'Autumn';
`$theme[45]['PATH'] = SM_PATH . 'themes/autumn2.php';
`$theme[45]['NAME'] = 'Autumn 2';
`$theme[46]['PATH'] = SM_PATH . 'themes/blue_on_blue.php';
`$theme[46]['NAME'] = 'Blue on Blue';
`$theme[47]['PATH'] = SM_PATH . 'themes/classic_blue.php';
`$theme[47]['NAME'] = 'Classic Blue';
`$theme[48]['PATH'] = SM_PATH . 'themes/classic_blue2.php';
`$theme[48]['NAME'] = 'Classic Blue 2';
`$theme[49]['PATH'] = SM_PATH . 'themes/powder_blue.php';
`$theme[49]['NAME'] = 'Powder Blue';
`$theme[50]['PATH'] = SM_PATH . 'themes/techno_blue.php';
`$theme[50]['NAME'] = 'Techno Blue';
`$theme[51]['PATH'] = SM_PATH . 'themes/turquoise.php';
`$theme[51]['NAME'] = 'Turquoise';

`$default_use_javascript_addr_book = false;
`$abook_global_file = '';
`$abook_global_file_writeable = false;
`$abook_global_file_listing = true;
`$abook_file_line_length = 2048;

`$addrbook_dsn = '';
`$addrbook_table = 'address';

`$prefs_dsn = '';
`$prefs_table = 'userprefs';
`$prefs_user_field = 'user';
`$prefs_key_field = 'prefkey';
`$prefs_val_field = 'prefval';
`$addrbook_global_dsn = '';
`$addrbook_global_table = 'global_abook';
`$addrbook_global_writeable = false;
`$addrbook_global_listing = false;

`$no_list_for_subscribe = false;
`$smtp_auth_mech = 'none';
`$imap_auth_mech = 'login';
`$smtp_sitewide_user = '';
`$smtp_sitewide_pass = '';
`$use_imap_tls = false;
`$use_smtp_tls = false;
`$session_name = 'SQMSESSID';
`$only_secure_cookies     = true;
`$disable_security_tokens = false;
`$check_referrer          = '';

`$config_location_base    = '';

@include SM_PATH . 'C:\Apache24\htdocs\squirrelmail\config\config_local.php';
?>
"@ | Out-File -FilePath "C:\Apache24\htdocs\squirrelmail\config\config.php" -Encoding UTF8
    
    # Permisos al usuario que ejecuta apache
        icacls "C:\Apache24\htdocs\squirrelmail\data\" /grant "IUSR:(OI)(CI)(M)"
        icacls "C:\Apache24\htdocs\squirrelmail\data\" /grant "IIS_IUSRS:(OI)(CI)(M)"
        New-Item -ItemType Directory -Path "C:\Apache24\htdocs\squirrelmail" -Name "attach"
        icacls "C:\Apache24\htdocs\squirrelmail\attach\" /grant "IUSR:(OI)(CI)(M)"
        icacls "C:\Apache24\htdocs\squirrelmail\attach\" /grant "IIS_IUSRS:(OI)(CI)(M)"
    }
}       



### ACTIVE DIRECTORY



function Get-UserData {
    $users = @()
    $continue = $true
    
    while ($continue) {
        # Solicitar nombre de usuario
        $username = capturarUsuarioFTPValido "Coloque el nombre del usuario (o 'salir')"
        if ($username.ToLower() -eq 'salir') {
            $continue = $false
            break
        }
        
        # Validar OU
        $ouChoice = $null
        while ($ouChoice -notin @('1', '2')) {
            $ouChoice = Read-Host "A que OU pertenece? (1 para 'cuates', 2 para 'no cuates')"
        }
        $ouName = if ($ouChoice -eq '1') { "cuates" } else { "nocuates" }
        
        $pass = capturarContra

        # Agregar usuario al array
        $users += @{
            Name      = $username
            GivenName = "Usuario"
            Surname   = $username
            OU        = $ouName
            Pass      = $pass
        }
    }
    
    return $users
}

Function Set-LogonHours {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $True)]
        [ValidateRange(0, 23)]
        [int[]]$TimeIn24Format,

        [Parameter(Mandatory = $True, ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True, Position = 0)]
        [string]$Identity,

        [Parameter(Mandatory = $False)]
        [ValidateSet("WorkingDays", "NonWorkingDays")]
        [string]$NonSelectedDaysare = "NonWorkingDays",

        [Parameter(Mandatory = $False)][switch]$Sunday,
        [Parameter(Mandatory = $False)][switch]$Monday,
        [Parameter(Mandatory = $False)][switch]$Tuesday,
        [Parameter(Mandatory = $False)][switch]$Wednesday,
        [Parameter(Mandatory = $False)][switch]$Thursday,
        [Parameter(Mandatory = $False)][switch]$Friday,
        [Parameter(Mandatory = $False)][switch]$Saturday
    )

    Process {
        $FullByte = New-Object "byte[]" 21
        $FullDay = [ordered]@{}
        0..23 | ForEach-Object { $FullDay.Add($_, "0") }

        $TimeIn24Format.ForEach({ $FullDay[$_] = "1" })
        $Working = -join ($FullDay.Values)

        switch ($NonSelectedDaysare) {
            'NonWorkingDays' {
                $SundayValue = $MondayValue = $TuesdayValue = $WednesdayValue = `
                    $ThursdayValue = $FridayValue = $SaturdayValue = "000000000000000000000000"
            }
            'WorkingDays' {
                $SundayValue = $MondayValue = $TuesdayValue = $WednesdayValue = `
                    $ThursdayValue = $FridayValue = $SaturdayValue = "111111111111111111111111"
            }
        }

        switch ($PSBoundParameters.Keys) {
            'Sunday'    { $SundayValue = $Working }
            'Monday'    { $MondayValue = $Working }
            'Tuesday'   { $TuesdayValue = $Working }
            'Wednesday' { $WednesdayValue = $Working }
            'Thursday'  { $ThursdayValue = $Working }
            'Friday'    { $FridayValue = $Working }
            'Saturday'  { $SaturdayValue = $Working }
        }

        $AllTheWeek = "{0}{1}{2}{3}{4}{5}{6}" -f `
            $SundayValue, $MondayValue, $TuesdayValue, $WednesdayValue, `
            $ThursdayValue, $FridayValue, $SaturdayValue

        # Ajustar zona horaria si es necesario
        $offset = (Get-TimeZone).BaseUtcOffset.Hours

        if ($offset -lt 0) {
            $TimeZoneOffset = $AllTheWeek.Substring(0, 168 + $offset)
            $TimeZoneOffset1 = $AllTheWeek.Substring(168 + $offset)
            $FixedTimeZoneOffSet = "$TimeZoneOffset1$TimeZoneOffset"
        }
        elseif ($offset -gt 0) {
            $TimeZoneOffset = $AllTheWeek.Substring(0, $offset)
            $TimeZoneOffset1 = $AllTheWeek.Substring($offset)
            $FixedTimeZoneOffSet = "$TimeZoneOffset1$TimeZoneOffset"
        }
        else {
            $FixedTimeZoneOffSet = $AllTheWeek
        }

        # Convertir binario a bytes (logonHours espera 21 bytes)
        $i = 0
        $BinaryResult = $FixedTimeZoneOffSet -split '(\d{8})' | Where-Object { $_ -match '(\d{8})' }

        foreach ($singleByte in $BinaryResult) {
            $Tempvar = $singleByte.ToCharArray()
            [array]::Reverse($Tempvar)
            $Tempvar = -join $Tempvar
            $Byte = [Convert]::ToByte($Tempvar, 2)
            $FullByte[$i] = $Byte
            $i++
        }

        Set-ADUser -Identity $Identity -Replace @{logonhours = $FullByte}
    }

    End {
    }
}

function Get-LogonsUser {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$user  # SamAccountName del usuario
    )

    # Obtener DN del usuario y nombre de dominio
    $userData = Get-ADUser -Identity $user -Properties DistinguishedName -ErrorAction SilentlyContinue
    if (-not $userData) {
        Write-Host "Usuario '$user' no encontrado."
        return
    }
    
    $userDN = $userData.DistinguishedName
    $domain = (Get-ADDomain).DNSRoot

    # Event IDs a buscar
    $userEvents = @(4624,4625,4648,4720,4722,4725,4738,4662,5136)

    try {
        $events = Get-WinEvent -LogName Security -FilterXPath "*[System[EventID=$($userEvents -join ' or EventID=')]]" -MaxEvents 100 -ErrorAction Stop |
                  Where-Object { 
                      # Para eventos de logon (4624,4625,4648)
                      if ($_.Id -in (4624,4625,4648)) {
                          $_.Properties[5].Value -like "*\$user" -or  # DOMINIO\usuario
                          $_.Properties[5].Value -eq $user             # usuario solo
                      }
                      # Para otros eventos de AD
                      else {
                          $_.Properties[4].Value -eq $userDN -or 
                          $_.Properties[5].Value -eq $user
                      }
                  }

        if (-not $events) {
            Write-Host "No hay inicios de sesion registrados del usuario '$user'."
            return
        }

        $report = $events | ForEach-Object {
            [PSCustomObject]@{
                Fecha      = $_.TimeCreated
                EventoID   = $_.Id
                Accion     = switch ($_.Id) {
                    4624 { "Inicio de sesion exitoso" }
                    4625 { "Inicio de sesion fallido" }
                    4648 { "Logon con credenciales explícitas" }
                    4720 { "Usuario creado" }
                    4722 { "Contraseña cambiada" }
                    4725 { "Usuario deshabilitado" }
                    4738 { "Membresía de grupo modificada" }
                    4662 { "Acceso a objeto AD" }
                    5136 { "Atributo modificado" }
                    default { "Otro" }
                }
                # Mapeo correcto según tipo de evento
                Usuario    = if ($_.Id -in (4624,4625,4648)) { $_.Properties[5].Value } else { $_.Properties[5].Value }
                IP_Origen  = if ($_.Id -in (4624,4625,4648)) { $_.Properties[18].Value } else { "N/A" }
                Objetivo   = if ($_.Id -in (4624,4625,4648)) { $_.Properties[6].Value } else { $_.Properties[4].Value }
            }
        }

        # Ordenamos por fecha descendente y mostramos
        $report | Sort-Object Fecha -Descending -Unique | Format-Table -AutoSize
    }
    catch {
        Write-Host "Error al leer eventos: $_" -ForegroundColor Red
    }
}

# Función para auditoría general de AD (equivalente a Get-ADAuditEvents)
function Get-ADEvents {
    [CmdletBinding()]
    param ()

    # Event IDs clave para AD (personalizable)
    $targetEvents = @(4662, 4738, 4720, 4726, 4767)

    try {
        $events = Get-WinEvent -LogName Security -FilterXPath "*[System[EventID=$($targetEvents -join ' or EventID=')]]" -MaxEvents 1000 -ErrorAction Stop

        $report = $events | ForEach-Object {
            [PSCustomObject]@{
                Fecha      = $_.TimeCreated
                EventoID   = $_.Id
                Accion     = switch ($_.Id) {
                    4662 { "Acceso a objeto AD" }
                    4738 { "Cambio en grupo (membresia)" }
                    4720 { "Usuario creado" }
                    4726 { "Usuario eliminado" }
                    4767 { "Cambio en cuenta de servicio" }
                    default { "Otro" }
                }
                Usuario    = $_.Properties[5].Value
                Objetivo   = $_.Properties[4].Value
            }
        }

        $report | Sort-Object Fecha -Descending -Unique | Format-Table -AutoSize
    }
    catch {
        Write-Host "Error al leer eventos: $_" -ForegroundColor Red
    }
}

