# Función para instalar características necesarias
function Instalar-Caracteristicas {
    Write-Host "Instalando el servidor web y el servidor FTP con todas sus características..."
    Install-WindowsFeature Web-Server -IncludeAllSubFeature
    Install-WindowsFeature Web-FTP-Server -IncludeAllSubFeature
}

# Función para crear la estructura de carpetas
function Crear-Estructura-FTP {
    Write-Host "Creando estructura de carpetas base para FTP..."
    New-Item -ItemType Directory -Path C:\FTP -Force
    New-Item -ItemType Directory -Path C:\FTP\grupos -Force
    New-Item -ItemType Directory -Path C:\FTP\grupos\reprobados -Force
    New-Item -ItemType Directory -Path C:\FTP\grupos\recursadores -Force
    New-Item -ItemType Directory -Path C:\FTP\LocalUser -Force
    New-Item -ItemType Directory -Path C:\FTP\LocalUser\Public -Force
    New-Item -ItemType Directory -Path C:\FTP\LocalUser\Public\general -Force
}

function Crear-Sitio-FTP {
    param (
        [string]$habilitarSSL
    )

    Write-Host "Creando el sitio FTP en IIS..." -ForegroundColor Cyan

    # Definir el nombre del sitio y la ruta
    $ftpSiteName = "FTP"
    $ftpRootPath = "C:\FTP"

    # Determinar el puerto según si SSL está habilitado o no
    if ($habilitarSSL -eq "s") {
        $ftpPort = 990  # Puerto predeterminado para FTPS
    } else {
        $ftpPort = 21   # Puerto predeterminado para FTP
    }

    # Verificar si el sitio ya existe
    if (-not (Get-WebSite -Name $ftpSiteName)) {
        New-WebFtpSite -Name $ftpSiteName -Port $ftpPort -PhysicalPath $ftpRootPath -Force
        Write-Host "Sitio FTP creado exitosamente en IIS en el puerto $ftpPort." -ForegroundColor Green
    } else {
        Write-Host "El sitio FTP ya existe." -ForegroundColor Yellow
    }

    # Abrir los puertos necesarios en el firewall
    New-NetFirewallRule -DisplayName "FTP/FTPS ($ftpPort)" -Direction Inbound -Protocol TCP -LocalPort $ftpPort -Action Allow
    New-NetFirewallRule -DisplayName "FTP Passive Mode (49152-65535)" -Direction Inbound -Protocol TCP -LocalPort 49152-65535 -Action Allow

    # Si el usuario eligió habilitar SSL, configurar TLS
    if ($habilitarSSL -eq "s") {
        Configurar-TLS -ftpSiteName $ftpSiteName
    }
}

# Función para configurar la isolación de usuarios
function Configurar-UserIsolation {
    Write-Host "Configurando User Isolation..."
    Set-WebConfigurationProperty -Filter "/system.applicationHost/sites/siteDefaults/ftpServer/userIsolation" `
        -Name "mode" -Value "IsolateAllDirectories"
}

# Función para crear grupos de usuarios locales
function Crear-Grupos-Locales {
    Write-Host "Creando grupos locales..."
    $SistemaUsuarios = [ADSI]"WinNT://$env:ComputerName"

    $grupos = @("reprobados", "recursadores")
    foreach ($grupo in $grupos) {
        $grupoObj = $SistemaUsuarios.Create("Group", $grupo)
        $grupoObj.SetInfo()
        $grupoObj.Description = "Usuarios con acceso a $grupo"
        $grupoObj.SetInfo()
    }
}

function Crear-Usuario-FTP {
    $gruposRequeridos = @("reprobados", "recursadores")
    $gruposFaltantes = @()

    foreach ($grupo in $gruposRequeridos) {
        if (-not (Get-LocalGroup -Name $grupo -ErrorAction SilentlyContinue)) {
            $gruposFaltantes += $grupo
        }
    }

    if ($gruposFaltantes.Count -gt 0) {
        Write-Host "No se pueden crear usuarios porque faltan los siguientes grupos locales: $($gruposFaltantes -join ', ')"
        Write-Host "Ejecuta la opción 'Crear grupos locales' antes de crear usuarios." -ForegroundColor Red
        return
    }

    # --- Aquí sigue el flujo normal de crear usuario (sin cambios) ---
    do {
        do {
            $nombreUsuario = Read-Host "Introduce el nombre del usuario (máximo 20 caracteres, o escribe 'salir' para terminar)"

            if ($nombreUsuario -eq "salir") { return }

            if (-not (Validar-NombreUsuario -nombreUsuario $nombreUsuario)) {
                $nombreUsuario = $null  # Forzar que se repita el ciclo hasta que el nombre sea válido
                continue
            }

        } while (-not $nombreUsuario)

        do {
            $claveUsuario = Read-Host "Introduce la contraseña (8 caracteres, una mayúscula, una minúscula, un dígito y un carácter especial)"
            if (-not (comprobarPassword -clave $claveUsuario)) {
                Write-Host "La contraseña no cumple con los requisitos, intenta de nuevo."
            }
        } while (-not (comprobarPassword -clave $claveUsuario))

        do {
            Write-Host "Selecciona el grupo para el usuario:"
            Write-Host "1) Reprobados"
            Write-Host "2) Recursadores"
            $grupoSeleccionado = Read-Host "Elige 1 o 2"

            if ($grupoSeleccionado -eq "1") {
                $grupoFTP = "reprobados"
                $rutaGrupo = "C:\FTP\grupos\reprobados"
                break
            } elseif ($grupoSeleccionado -eq "2") {
                $grupoFTP = "recursadores"
                $rutaGrupo = "C:\FTP\grupos\recursadores"
                break
            } else {
                Write-Host "Opción inválida. Selecciona 1 o 2."
            }
        } while ($true)

        # Crear el usuario ya que pasó todas las validaciones
        $securePassword = ConvertTo-SecureString -String $claveUsuario -AsPlainText -Force
        New-LocalUser -Name $nombreUsuario -Password $securePassword -Description "Usuario FTP" -AccountNeverExpires

        # Validar que el grupo exista, si no lo crea (esto es redundante, podría eliminarse gracias a la validación inicial)
        if (-not (Get-LocalGroup -Name $grupoFTP -ErrorAction SilentlyContinue)) {
            Write-Host "El grupo $grupoFTP no existe. Creándolo..."
            New-LocalGroup -Name $grupoFTP
        }

        # Agregar usuario al grupo correspondiente
        Add-LocalGroupMember -Group $grupoFTP -Member $nombreUsuario

        # Crear carpetas de usuario
        $rutaUsuario = "C:\FTP\LocalUser\$nombreUsuario"
        New-Item -ItemType Directory -Path $rutaUsuario -Force
        New-Item -ItemType Directory -Path "$rutaUsuario\$nombreUsuario" -Force

        # Crear enlaces simbólicos (función existente)
        Crear-Symlink "$rutaUsuario\general" "C:\FTP\LocalUser\Public\general"
        Crear-Symlink "$rutaUsuario\$grupoFTP" $rutaGrupo

        Write-Host "Usuario $nombreUsuario creado y vinculado correctamente a general y $grupoFTP."
    } while ($true)
}

# Función para crear symlinks
function Crear-Symlink {
    param(
        [string]$target,
        [string]$destination
    )
    if (Test-Path $target) { Remove-Item $target -Force }
    cmd /c mklink /D $target $destination
}

# Función para configurar autenticación y permisos
function Configurar-Autenticacion-Permisos {
    Write-Host "Configurando autenticación y permisos FTP..."

    Set-ItemProperty -Path "IIS:\Sites\FTP" -Name ftpServer.Security.authentication.basicAuthentication.enabled -Value $true
    Set-ItemProperty -Path "IIS:\Sites\FTP" -Name ftpServer.Security.authentication.anonymousAuthentication.enabled -Value $true
    Set-ItemProperty -Path "IIS:\Sites\FTP" -Name ftpServer.Security.authentication.anonymousAuthentication.userName -Value "IUSR"
    Set-ItemProperty -Path "IIS:\Sites\FTP" -Name ftpServer.Security.authentication.anonymousAuthentication.password -Value ""

    Clear-WebConfiguration "/system.ftpServer/security/authorization" -PSPath "IIS:\"

    Add-WebConfiguration "/system.ftpServer/security/authorization" -PSPath "IIS:\" -Value @{
        accessType = "Allow";
        roles = "reprobados, recursadores";
        permissions = 3
    } -Location "FTP"

    Add-WebConfiguration "/system.ftpServer/security/authorization" -PSPath "IIS:\" -Value @{
        accessType = "Allow";
        users = "IUSR";
        permissions = 1
    } -Location "FTP"
}

function Configurar-TLS {
    param (
        [string]$ftpSiteName
    )

    Write-Host "Generando certificado SSL auto-firmado..." -ForegroundColor Cyan

    # Crear un certificado auto-firmado
    $cert = New-SelfSignedCertificate -DnsName "localhost" -CertStoreLocation "Cert:\LocalMachine\My"

    # Obtener el thumbprint del certificado
    $thumbprint = $cert.Thumbprint

    Write-Host "Certificado generado con Thumbprint: $thumbprint" -ForegroundColor Green

    # Configurar IIS para usar SSL/TLS en FTP
    Set-ItemProperty "IIS:\Sites\$ftpSiteName" -Name "ftpServer.security.ssl.controlChannelPolicy" -Value "SslAllow"
    Set-ItemProperty "IIS:\Sites\$ftpSiteName" -Name "ftpServer.security.ssl.dataChannelPolicy" -Value "SslAllow"
    Set-ItemProperty "IIS:\Sites\$ftpSiteName" -Name "ftpServer.security.ssl.serverCertHash" -Value $thumbprint

    Write-Host "SSL/TLS habilitado en el sitio FTP." -ForegroundColor Green
}


# Función para reiniciar el sitio FTP
function Reiniciar-FTP {
    Restart-WebItem "IIS:\Sites\FTP"
}

function comprobarPassword {
    param (
        [string]$clave
    )
    $regex = "^(?=.*[A-Z])(?=.*[a-z])(?=.*[0-9])(?=.*[^A-Za-z0-9]).{8,16}$"

    if ($clave -match $regex) {
        return $true
    } else {
        return $false
    }
}

function Validar-NombreUsuario {
    param (
        [string]$nombreUsuario
    )

    # Lista de nombres reservados en Windows
    $nombresReservados = @(
        "CON", "PRN", "AUX", "NUL",
        "COM1", "COM2", "COM3", "COM4", "COM5", "COM6", "COM7", "COM8", "COM9",
        "LPT1", "LPT2", "LPT3", "LPT4", "LPT5", "LPT6", "LPT7", "LPT8", "LPT9"
    )

    # Caracteres inválidos
    $caracteresInvalidos = '[<>:"/\\|?*]'

    if ([string]::IsNullOrWhiteSpace($nombreUsuario)) {
        Write-Host "El nombre de usuario no puede estar vacío."
        return $false
    }

    if ($nombreUsuario.Length -gt 20) {
        Write-Host "El nombre de usuario no puede tener más de 20 caracteres."
        return $false
    }

    if ($nombreUsuario -match $caracteresInvalidos) {
        Write-Host "El nombre de usuario contiene caracteres no permitidos (< > : "" / \ | ? *)."
        return $false
    }

    if ($nombreUsuario -match '^\s|\s$') {
        Write-Host "El nombre de usuario no puede comenzar ni terminar con un espacio."
        return $false
    }

    if ($nombreUsuario -match '\.$') {
        Write-Host "El nombre de usuario no puede terminar con un punto."
        return $false
    }

    if ($nombreUsuario -in $nombresReservados) {
        Write-Host "El nombre de usuario '$nombreUsuario' es un nombre reservado por Windows."
        return $false
    }

    if (Get-LocalUser -Name $nombreUsuario -ErrorAction SilentlyContinue) {
        Write-Host "El usuario '$nombreUsuario' ya existe."
        return $false
    }

    return $true
}

function Eliminar-Usuario-FTP {
    param (
        [string]$nombreUsuario,
        [switch]$Force
    )

    # Advertencia inicial
    Write-Host "ADVERTENCIA: Antes de ejecutar esta acción, asegúrate de que el usuario '$nombreUsuario' no esté conectado por FTP." -ForegroundColor Yellow

    # Validar que el nombre de usuario no esté vacío
    if ([string]::IsNullOrWhiteSpace($nombreUsuario)) {
        Write-Host "ERROR: Debes proporcionar un nombre de usuario válido." -ForegroundColor Red
        return
    }

    # Validar que el usuario exista
    $usuario = Get-LocalUser -Name $nombreUsuario -ErrorAction SilentlyContinue
    if (-not $usuario) {
        Write-Host "ERROR: El usuario '$nombreUsuario' no existe." -ForegroundColor Red
        return
    }

    # Confirmación interactiva si no se especifica -Force
    if (-not $Force) {
        $confirmacion = Read-Host "¿Estás seguro que deseas eliminar al usuario '$nombreUsuario' y su directorio? (S/N)"
        if ($confirmacion -ne 'S') {
            Write-Host "Operación cancelada por el usuario." -ForegroundColor Yellow
            return
        }
    }

    # Intentar eliminación del usuario
    try {
        Remove-LocalUser -Name $nombreUsuario -ErrorAction Stop
        Write-Host "Usuario '$nombreUsuario' eliminado correctamente." -ForegroundColor Green
    }
    catch {
        Write-Host "ERROR: No se pudo eliminar el usuario '$nombreUsuario'. Detalle: $($_.Exception.Message)" -ForegroundColor Red
        return
    }

    # Ruta base de la carpeta de usuario FTP
    $rutaUsuario = "C:\FTP\LocalUser\$nombreUsuario"

    if (Test-Path $rutaUsuario) {
        try {
            # Buscar y eliminar cualquier enlace simbólico dentro de la carpeta de usuario
            $items = Get-ChildItem -Path $rutaUsuario -Force -ErrorAction Stop

            foreach ($item in $items) {
                if ($item.LinkType -eq 'SymbolicLink') {
                    Write-Host "Eliminando enlace simbólico: $($item.FullName)"
                    Remove-Item -Path $item.FullName -Force -ErrorAction Stop
                }
            }

            # Eliminar la carpeta completa
            Remove-Item -Path $rutaUsuario -Recurse -Force -ErrorAction Stop
            Write-Host "Directorio '$rutaUsuario' eliminado correctamente." -ForegroundColor Green
        }
        catch {
            Write-Host "ERROR: No se pudo eliminar el directorio '$rutaUsuario'. Detalle: $($_.Exception.Message)" -ForegroundColor Red
            return
        }
    } else {
        Write-Host "AVISO: El directorio '$rutaUsuario' no existe. Continuando." -ForegroundColor Yellow
    }

    Write-Host "El usuario '$nombreUsuario' y sus datos fueron eliminados correctamente." -ForegroundColor Green
}

#--------------------------------------------------------------------------------
#HTTP
#--------------------------------------------------------------------------------

# Variables globales (compartidas entre las funciones)
$global:servicio = ""   # Almacena el servicio seleccionado (IIS, Apache, Tomcat)
$global:version = ""    # Almacena la versión seleccionada del servicio
$global:puerto = ""     # Almacena el puerto en el que se configurará el servicio
$global:versions = @()  # Almacena un array con las versiones disponibles del servicio seleccionado

function seleccionar_servicio {
    param (
        [string]$modo  # Parámetro opcional que indica si es "ftp"
    )

    Write-Host "Seleccione el servicio que desea instalar:"

    if ($modo -eq "ftp") {
        Write-Host "1.- IIS (solo se instala desde web, si quiere instalarlo regrese al instalador de web)"
    } else {
        Write-Host "1.- IIS"
    }

    Write-Host "2.- Apache"
    Write-Host "3.- Tomcat"
    $opcion = Read-Host "Opción"

    switch ($opcion) {
        "1" {
            if ($modo -eq "ftp") {
                Write-Host "IIS no es descargable desde FTP. Si desea instalarlo, regrese al instalador de Web."
                return
            }
            $global:servicio = "IIS"
            Write-Host "Servicio seleccionado: IIS"
            obtener_versiones_IIS
        }
        "2" {
            $global:servicio = "Apache"
            Write-Host "Servicio seleccionado: Apache"
            if ($modo -ne "ftp") {
                obtener_versiones_apache
            }
        }
        "3" {
            $global:servicio = "Tomcat"
            Write-Host "Servicio seleccionado: Tomcat"
            if ($modo -ne "ftp") {
                obtener_versiones_tomcat
            }
        }
        default {
            Write-Host "Opción no válida. Intente de nuevo."
            seleccionar_servicio -modo $modo
        }
    }
}

function obtener_versiones_IIS {
    # Verificar si IIS ya está instalado
    $iisVersion = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\InetStp" -ErrorAction SilentlyContinue).MajorVersion

    if ($iisVersion) {
        Write-Host "IIS ya está instalado. Versión detectada: $iisVersion"
        $global:version = "IIS $iisVersion.0"
    } else {
        Write-Host "IIS no está instalado. Determinando la versión predeterminada..."

        # Obtener la versión del sistema operativo
        $osBuild = (Get-ComputerInfo).WindowsBuildLabEx

        # Identificar la versión de Windows Server
        switch -Wildcard ($osBuild) {
            "*20348*" { $global:version = "IIS 10.0 (Windows Server 2022)" }
            "*22000*" { $global:version = "IIS 10.0 (Windows Server 2025 / Windows 11)" }
            "*22621*" { $global:version = "IIS 10.0 (Windows Server 2025 / Windows 11 22H2)" }
            default   { $global:version = "IIS 10.0 (Versión predeterminada para Windows)" }
        }

        Write-Host "La versión predeterminada de IIS que se instalará en su sistema es: $global:version"
    }
}

function obtener_versiones_apache {
    Write-Host "Obteniendo versiones de Apache HTTP Server desde https://httpd.apache.org/download.cgi"

    # Descargar el contenido HTML de la página oficial de Apache
    try {
        $html = Invoke-WebRequest -Uri "https://httpd.apache.org/download.cgi" -UseBasicParsing
    } catch {
        Write-Host "Error al descargar la página de Apache. Verifique su conexión a Internet."
        return
    }

    # Convertir el HTML en texto
    $htmlContent = $html.Content

    # Buscar versiones en formato httpd-X.Y.Z usando expresión regular
    $versionsRaw = [regex]::Matches($htmlContent, "httpd-(\d+\.\d+\.\d+)") | ForEach-Object { $_.Groups[1].Value }

    # Extraer la versión LTS (2.4.x) y la versión de desarrollo (2.5.x o superior si existe)
    $versionLTS = ($versionsRaw | Where-Object { $_ -match "^2\.4\.\d+$" } | Select-Object -First 1)
    $versionDev = ($versionsRaw | Where-Object { $_ -match "^2\.5\.\d+$" } | Select-Object -First 1)

    # Si no hay versión de desarrollo disponible
    if (-not $versionDev) {
        $versionDev = "No disponible"
    }

    # Asegurar que el array `$global:versions` tenga solo dos valores correctos
    $global:versions = @($versionLTS, $versionDev)

    Write-Host "Versión estable (LTS): $versionLTS"
    Write-Host "Versión de desarrollo: $versionDev"
}

function obtener_urls_tomcat {
    Write-Host "Obteniendo URLs dinámicas de descarga desde el índice de Tomcat..."

    # Intentar obtener el contenido de la página principal de Tomcat
    try {
        $html = Invoke-WebRequest -Uri "https://tomcat.apache.org/index.html" -UseBasicParsing
    } catch {
        Write-Host "Error al descargar la página de Tomcat. Verifique su conexión a Internet."
        return
    }

    # Convertir el contenido HTML en texto
    $htmlContent = $html.Content

    # Extraer los enlaces de descarga de Tomcat
    $urls = [regex]::Matches($htmlContent, "https://tomcat.apache.org/download-(\d+)\.cgi") | ForEach-Object { $_.Value }

    # Variables para almacenar las URLs de LTS y Dev
    $global:tomcat_url_lts = ""
    $global:tomcat_url_dev = ""

    # Identificar la versión LTS y la versión de desarrollo
    foreach ($url in $urls) {
        $versionNumber = [regex]::Match($url, "\d+").Value

        if ([int]$versionNumber -lt 11) {
            $global:tomcat_url_lts = $url
        }

        if ([int]$versionNumber -eq 11) {
            $global:tomcat_url_dev = $url
        }
    }

    Write-Host "URL de la versión estable (LTS): $global:tomcat_url_lts"
    Write-Host "URL de la versión de desarrollo: $global:tomcat_url_dev"
}

function obtener_versiones_tomcat {
    obtener_urls_tomcat  # Primero obtenemos las URLs de descarga

    Write-Host "Obteniendo versiones de Apache Tomcat desde las URLs detectadas..."

    # Obtener la versión estable desde la página LTS
    if ($global:tomcat_url_lts -ne "") {
        try {
            $htmlLTS = Invoke-WebRequest -Uri $global:tomcat_url_lts -UseBasicParsing
            $versionLTS = [regex]::Match($htmlLTS.Content, "v(\d+\.\d+\.\d+)").Groups[1].Value
        } catch {
            Write-Host "Error al obtener la versión LTS de Tomcat."
            $versionLTS = "No disponible"
        }
    } else {
        $versionLTS = "No disponible"
    }

    # Obtener la versión de desarrollo desde la página Dev
    if ($global:tomcat_url_dev -ne "") {
        try {
            $htmlDev = Invoke-WebRequest -Uri $global:tomcat_url_dev -UseBasicParsing
            $versionDev = [regex]::Match($htmlDev.Content, "v(\d+\.\d+\.\d+)").Groups[1].Value
        } catch {
            Write-Host "Error al obtener la versión de desarrollo de Tomcat."
            $versionDev = "No disponible"
        }
    } else {
        $versionDev = "No disponible"
    }

    # Guardar versiones en la variable global
    $global:versions = @($versionLTS, $versionDev)

    Write-Host "Versión estable (LTS): $versionLTS"
    Write-Host "Versión de desarrollo: $versionDev"
}

function seleccionar_version {
    if (-not $global:servicio) {
        Write-Host "Debe seleccionar un servicio antes de elegir la versión."
        return
    }
        # Mostrar el servicio antes de la selección de versión
    Write-Host "`n========================================"
    Write-Host "Seleccionando versión para: $global:servicio"
    Write-Host "========================================"

    # Si el servicio es IIS, no permitir selección de versión
    if ($global:servicio -eq "IIS") {
        Write-Host "IIS no tiene versiones seleccionables. Se instalará la versión predeterminada para Windows Server."
        $global:version = "IIS (Versión según sistema operativo)"
        return
    }

    if ($global:servicio -eq "Apache") {
        Write-Host "Apache solo cuenta con version stable. Se instalará la version 2.4.63"
        $global:version = "2.4.63"
        return
    }

    # Extraer las versiones en variables locales asegurando que `$global:versions` es un array válido
    $versionLTS = if ($global:versions.Count -ge 1) { $global:versions[0] } else { "No disponible" }
    $versionDev = if ($global:versions.Count -ge 2) { $global:versions[1] } else { "No disponible" }

    $global:version = $versionLTS
    Write-Host "1.- Versión Estable (LTS): $global:version"
    $global:version = $versionDev

    Write-Host "2.- Versión de Desarrollo: $global:version"
    $opcion = Read-Host "Opción"

    switch ($opcion) {
        "1" {
            $global:version = $versionLTS
            Write-Host "Versión seleccionada: $global:version"
        }
        "2" {
            $global:version = $versionDev
            Write-Host "Versión seleccionada: $global:version"
        }
        default {
            Write-Host "Opción no válida."
        }
    }
}

function verificar_puerto_en_uso {
    param (
        [int]$puerto
    )

    # Usar netstat para verificar si el puerto está en uso
    $ocupado = netstat -an | Select-String ":$puerto " | Where-Object { $_ -match "LISTENING" }

    if ($ocupado) {
        return $true  # Puerto en uso
    } else {
        return $false # Puerto disponible
    }
}

function verificar_puerto_restringido {
    param (
        [int]$puerto
    )
    # Lista de puertos restringidos por servicios comunes o navegadores
    $puertos_restringidos = @(21, 22, 23, 25, 53, 110, 143, 161, 162, 389, 465, 993, 995, 1433, 1434, 1521, 3306, 3389,
                              1, 7, 9, 11, 13, 15, 17, 19, 137, 138, 139, 2049, 3128, 6000)

    return $puerto -in $puertos_restringidos
}

function preguntar_puerto {
    while ($true) {
        $puerto = Read-Host "Ingrese el puerto para el servicio (debe estar entre 1 y 65535, excepto los restringidos)"

        # Validar que la entrada sea un número dentro del rango permitido
        if ($puerto -match "^\d+$") {
            $puerto = [int]$puerto  # Convertir a número
            if ($puerto -ge 1 -and $puerto -le 65535) {
                if (verificar_puerto_restringido -puerto $puerto) {
                    Write-Host "El puerto $puerto está restringido por otros servicios. Intente con otro."
                } elseif (-not (verificar_puerto_en_uso -puerto $puerto)) {
                    Write-Host "El puerto $puerto está disponible."
                    $global:puerto = $puerto
                    break
                } else {
                    Write-Host "El puerto $puerto está ocupado. Intente con otro."
                }
            } else {
                Write-Host "Número fuera de rango. Ingrese un puerto entre 1 y 65535."
            }
        } else {
            Write-Host "Entrada inválida. Ingrese un número de puerto válido."
        }
    }
}

function habilitar_puerto_firewall {
    if ($global:puerto) {
        # Verifica si ya existe una regla para el puerto
        $reglaExistente = Get-NetFirewallRule | Where-Object { $_.DisplayName -eq "Puerto $global:puerto" }
        
        if ($reglaExistente) {
            Write-Host "El puerto $global:puerto ya tiene una regla de firewall activa."
        } else {
            # Crear una nueva regla en el firewall
            New-NetFirewallRule -DisplayName "Puerto $global:puerto" -Direction Inbound -Protocol TCP -LocalPort $global:puerto -Action Allow | Out-Null
            Write-Host "Se ha habilitado el puerto $global:puerto en el firewall."
        }
    } else {
        Write-Host "No hay un puerto definido en la variable global `$global:puerto`."
    }
}


function proceso_instalacion {
    if (-not $global:servicio -or -not $global:version -or -not $global:puerto) {
        Write-Host "Debe seleccionar el servicio, la versión y el puerto antes de proceder con la instalación."
        return
    }

    Write-Host "Iniciando instalación silenciosa de $global:servicio versión $global:version en el puerto $global:puerto..."

    switch ($global:servicio) {
        "IIS" {
            instalar_iis
        }
        "Apache" {
            instalar_apache
        }
        "Tomcat" {
            instalar_tomcat
        }
        default {
            Write-Host "Servicio desconocido. No se puede proceder."
            return
        }
    }

    Write-Host "Instalación completada para $global:servicio versión $global:version en el puerto $global:puerto."

    # Limpiar variables globales después de la instalación
    $global:servicio = $null
    $global:version = $null
    $global:puerto = $null
}

function instalar_dependencias {
    Write-Host "`n============================================"
    Write-Host "   Verificando e instalando dependencias...   "
    Write-Host "============================================"

    # Verificar e instalar Visual C++ Redistributable 2015-2022 (VS17)
    Write-Host "`nVerificando Visual C++ Redistributable 2015-2022..."

    $vcInstalled = Get-ChildItem "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall" | 
                   Get-ItemProperty | 
                   Where-Object { $_.DisplayName -match "Visual C\+\+ (2015|2017|2019|2022) Redistributable" }

    if ($vcInstalled) {
        Write-Host "Visual C++ Redistributable 2015-2022 ya está instalado."
    } else {
        Write-Host "Falta Visual C++ 2015-2022. Descargando e instalando..."
        $vcUrl = "https://aka.ms/vs/17/release/vc_redist.x64.exe"
        $vcInstaller = "$env:TEMP\vc_redist.x64.exe"
        Invoke-WebRequest -Uri $vcUrl -OutFile $vcInstaller
        Start-Process -FilePath $vcInstaller -ArgumentList "/install /quiet /norestart" -NoNewWindow -Wait
        Write-Host "Visual C++ 2015-2022 instalado correctamente."
    }

    # Verificar e instalar Visual C++ 2012 Redistributable (VC11)
    Write-Host "`nVerificando Visual C++ Redistributable 2012 (VC11)..."

    $vc2012Installed = Get-ChildItem "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall" | 
                       Get-ItemProperty | 
                       Where-Object { $_.DisplayName -match "Visual C\+\+ 2012 Redistributable" }

    if ($vc2012Installed) {
        Write-Host "Visual C++ 2012 Redistributable ya está instalado."
    } else {
        Write-Host "Falta Visual C++ 2012. Descargando e instalando..."
        $vc2012Url = "https://download.microsoft.com/download/1/6/B/16B06F60-3B20-4FF2-B699-5E9B7962F9AE/VSU_4/vcredist_x64.exe"
        $vc2012Installer = "$env:TEMP\vcredist_x64_2012.exe"
        Invoke-WebRequest -Uri $vc2012Url -OutFile $vc2012Installer
        Start-Process -FilePath $vc2012Installer -ArgumentList "/install /quiet /norestart" -NoNewWindow -Wait
        Write-Host "Visual C++ 2012 Redistributable instalado correctamente."
    }
    
    # Verificar e instalar OpenSSL
    Write-Host "`nVerificando OpenSSL..."

    $opensslInstallPath = "C:\Program Files\OpenSSL-Win64"

    if (Test-Path "$opensslInstallPath\bin\openssl.exe") {
        Write-Host "OpenSSL ya está instalado en: $opensslInstallPath"
    } else {
        Write-Host "Falta OpenSSL. Descargando e instalando..."
        $opensslUrl = "https://slproweb.com/download/Win64OpenSSL_Light-3_4_1.exe"
        $opensslInstaller = "$env:TEMP\Win64OpenSSL_Light.exe"

        Invoke-WebRequest -Uri $opensslUrl -OutFile $opensslInstaller
        Start-Process -FilePath $opensslInstaller -ArgumentList "/silent" -NoNewWindow -Wait
        Write-Host "OpenSSL instalado correctamente."
    }

    # Configurar OPENSSL_HOME y agregar al PATH
    Write-Host "`nConfigurando OPENSSL_HOME y PATH..."

    [System.Environment]::SetEnvironmentVariable("OPENSSL_HOME", $opensslInstallPath, [System.EnvironmentVariableTarget]::Machine)

    # Obtener el PATH actual del sistema y asegurarse de que OpenSSL está en él
    $currentPath = [System.Environment]::GetEnvironmentVariable("Path", [System.EnvironmentVariableTarget]::Machine)
    if ($currentPath -notlike "*$opensslInstallPath\bin*") {
        $newPath = "$currentPath;$opensslInstallPath\bin"
        [System.Environment]::SetEnvironmentVariable("Path", $newPath, [System.EnvironmentVariableTarget]::Machine)
    }

    # Refrescar variables de entorno en la sesión actual
    $env:OPENSSL_HOME = $opensslInstallPath
    $env:Path = "$env:Path;$opensslInstallPath\bin"

    Write-Host "OPENSSL_HOME configurado correctamente en: $env:OPENSSL_HOME"

    # Verificar que OpenSSL funciona
    Write-Host "`nVerificando instalación de OpenSSL..."
    $opensslVersion = & "$opensslInstallPath\bin\openssl.exe" version 2>&1
    if ($opensslVersion -match "OpenSSL 3\.") {
        Write-Host "Configuración correcta: `n$opensslVersion"
    } else {
        Write-Host "Error: OpenSSL no está configurado correctamente."
    }

    # Verificar e instalar Amazon Corretto JDK 21
    Write-Host "`nVerificando Amazon Corretto JDK 21..."

    $jdkBasePath = "C:\Java"

    # Buscar la carpeta correcta del JDK (detecta la versión instalada automáticamente)
    $jdkInstallPath = Get-ChildItem -Path $jdkBasePath -Directory | Where-Object { $_.Name -match "^jdk21.*" } | Select-Object -ExpandProperty FullName -First 1

    if ($jdkInstallPath -and (Test-Path "$jdkInstallPath\bin\java.exe")) {
        Write-Host "Amazon Corretto JDK 21 ya está instalado en: $jdkInstallPath"
    } else {
        Write-Host "Falta JDK 21. Descargando e instalando..."
        $jdkUrl = "https://corretto.aws/downloads/latest/amazon-corretto-21-x64-windows-jdk.zip"
        $jdkZipPath = "$env:TEMP\Corretto21.zip"

        Invoke-WebRequest -Uri $jdkUrl -OutFile $jdkZipPath

        # Crear directorio de instalación si no existe
        if (-Not (Test-Path $jdkBasePath)) {
            New-Item -ItemType Directory -Path $jdkBasePath | Out-Null
        }

        # Extraer el archivo ZIP
        Write-Host "Extrayendo Amazon Corretto JDK 21..."
        Expand-Archive -Path $jdkZipPath -DestinationPath $jdkBasePath -Force
        Remove-Item -Path $jdkZipPath -Force

        # Detectar la carpeta real del JDK instalada
        $jdkInstallPath = Get-ChildItem -Path $jdkBasePath -Directory | Where-Object { $_.Name -match "^jdk21.*" } | Select-Object -ExpandProperty FullName -First 1

        if (-not $jdkInstallPath) {
            Write-Host "Error: No se encontró la carpeta del JDK después de la instalación."
            return
        }

        Write-Host "Amazon Corretto JDK 21 instalado en: $jdkInstallPath"
    }

    # Configurar JAVA_HOME y agregar al PATH
    Write-Host "`nConfigurando JAVA_HOME y PATH..."

    [System.Environment]::SetEnvironmentVariable("JAVA_HOME", $jdkInstallPath, [System.EnvironmentVariableTarget]::Machine)

    # Obtener el PATH actual del sistema y asegurarse de que la carpeta bin del JDK está en él
    $currentPath = [System.Environment]::GetEnvironmentVariable("Path", [System.EnvironmentVariableTarget]::Machine)
    if ($currentPath -notlike "*$jdkInstallPath\bin*") {
        $newPath = "$currentPath;$jdkInstallPath\bin"
        [System.Environment]::SetEnvironmentVariable("Path", $newPath, [System.EnvironmentVariableTarget]::Machine)
    }

    # Refrescar variables de entorno en la sesión actual
    $env:JAVA_HOME = $jdkInstallPath
    $env:Path = "$env:Path;$jdkInstallPath\bin"

    Write-Host "JAVA_HOME configurado correctamente en: $env:JAVA_HOME"

    # Verificar que JAVA_HOME está correctamente configurado
    Write-Host "`nVerificando configuración de Java..."
    $javaVersion = & "$jdkInstallPath\bin\java.exe" -version 2>&1
    if ($javaVersion -match "21\.") {
        Write-Host "Configuración correcta: `n$javaVersion"
    } else {
        Write-Host "Error: JAVA_HOME no está configurado correctamente."
    }

    Write-Host "`nVerificación e instalación de dependencias completada."
}

function instalar_iis {
    try {
        Write-Host "Instalando IIS y todas sus características..."
        Install-WindowsFeature -Name Web-Server -IncludeAllSubFeature -ErrorAction Stop
        Set-Service -Name W3SVC -StartupType Automatic

        Write-Host "IIS instalado correctamente."

        # Llamar automáticamente a la configuración después de la instalación
        configurar_iis
    } catch {
        Write-Host "Error durante la instalación de IIS: $_"
    }
}

function configurar_iis {
    if (-not $global:puerto -or $global:puerto -notmatch '^\d+$') {
        Write-Host "Error: No se ha definido un puerto válido. Ejecute 'preguntar_puerto' antes de configurar IIS."
        return
    }

    try {
        Write-Host "Configurando IIS en el puerto $global:puerto..."

        # Obtener y eliminar todas las vinculaciones existentes
        $bindings = Get-WebBinding -Name "Default Web Site"
        if ($bindings) {
            foreach ($binding in $bindings) {
                Remove-WebBinding -Name "Default Web Site" -IPAddress "*" -Port $binding.bindingInformation.Split(':')[1] -Protocol $binding.protocol
                Write-Host "Vinculación en el puerto $($binding.bindingInformation.Split(':')[1]) eliminada."
            }
        }

        # Configurar IIS con HTTP o HTTPS según la opción seleccionada
        if ($global:protocolo -eq "HTTPS") {
            Write-Host "Configurando IIS para HTTPS en el puerto $global:puerto..."

            # Llamar a la función para generar un certificado autofirmado
            $certThumbprint = generar_certificado_ssl

            if ($certThumbprint) {
                Write-Host "Asociando el certificado SSL a IIS..."
                New-WebBinding -Name "Default Web Site" -Protocol "https" -IPAddress "*" -Port $global:puerto
                netsh http add sslcert ipport=0.0.0.0:$global:puerto certhash=$certThumbprint appid="{00112233-4455-6677-8899-AABBCCDDEEFF}"
                Write-Host "Certificado SSL asociado a IIS correctamente."
            } else {
                Write-Host "Error: No se pudo generar el certificado SSL."
                return
            }
        } else {
            Write-Host "Configurando IIS para HTTP en el puerto $global:puerto..."
            New-WebBinding -Name "Default Web Site" -Protocol "http" -IPAddress "*" -Port $global:puerto
        }

        Write-Host "Nueva vinculación establecida en el puerto $global:puerto."

        # Reiniciar IIS
        Restart-Service W3SVC
        iisreset

        Write-Host "Configuración de IIS completada exitosamente."

        # Habilitar el puerto en el firewall
        habilitar_puerto_firewall
    } catch {
        Write-Host "Error durante la configuración de IIS: $_"
    }
}

function generar_certificado_ssl {
    Write-Host "Generando certificado SSL autofirmado para IIS..."

    # Definir el nombre del certificado y el puerto
    $certName = "IIS-SSL-Cert-$global:puerto"

    # Crear el certificado autofirmado
    $cert = New-SelfSignedCertificate -DnsName "localhost" -CertStoreLocation "Cert:\LocalMachine\My" `
        -FriendlyName $certName -NotAfter (Get-Date).AddYears(1) -KeyExportPolicy Exportable

    if ($cert) {
        Write-Host "Certificado SSL generado correctamente: $cert.Thumbprint"
        return $cert.Thumbprint
    } else {
        Write-Host "Error al generar el certificado SSL."
        return $null
    }
}

function instalar_apache {
    # Verificar que la versión de Apache está definida
    if (-not $global:version) {
        Write-Host "Error: No se ha seleccionado una versión de Apache. Ejecute 'seleccionar_version' antes de instalar Apache."
        return
    }

    # Verificar que el puerto está definido
    if (-not $global:puerto) {
        Write-Host "Error: No se ha definido un puerto válido. Ejecute 'preguntar_puerto' antes de instalar Apache."
        return
    }

    # Definir ruta de descarga con la versión seleccionada
    $url = "https://www.apachelounge.com/download/VS17/binaries/httpd-$global:version-250207-win64-VS17.zip"
    $destinoZip = "$env:USERPROFILE\Downloads\apache-$global:version.zip"
    $extraerdestino = "C:\Apache24"

    try {
        Write-Host "Iniciando instalación de Apache HTTP Server versión $global:version..."

        # Descargar Apache
        Write-Host "Descargando Apache desde: $url"
        $agente = "Mozilla/5.0 (Windows NT 10.0; Win64; x64)"
        Invoke-WebRequest -Uri $url -OutFile $destinoZip -MaximumRedirection 10 -UserAgent $agente -UseBasicParsing
        Write-Host "Apache descargado en: $destinoZip"

        # Extraer Apache en C:\Apache24
        Write-Host "Extrayendo archivos de Apache..."
        Expand-Archive -Path $destinoZip -DestinationPath "C:\" -Force
        Write-Host "Apache extraído en $extraerdestino"
        Remove-Item -Path $destinoZip -Force

        # Configurar SSL si el protocolo es HTTPS
        if ($global:protocolo -eq "HTTPS") {
            Write-Host "Configurando Apache para HTTPS..."

            # Crear carpeta SSL si no existe
            $sslDir = "$extraerdestino\conf\ssl"
            if (-not (Test-Path $sslDir)) {
                New-Item -ItemType Directory -Path $sslDir -Force | Out-Null
            }

            # Verificar si OpenSSL está instalado
            $opensslPath = "C:\Program Files\OpenSSL-Win64\bin\openssl.exe"
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

            if ($global:protocolo -eq "HTTPS") {
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
                $confContent = $confContent -replace "(?m)^Listen \d+", "Listen $global:puerto"
            }

            # Guardar cambios en httpd.conf
            $confContent | Set-Content $configFile
            Write-Host "Configuración actualizada para escuchar en el puerto $global:puerto"
        } else {
            Write-Host "Error: No se encontró el archivo de configuración en $configFile"
            return
        }

        # Configurar httpd-ssl.conf si HTTPS está activado
        if ($global:protocolo -eq "HTTPS") {
            $sslConfFile = Join-Path $extraerdestino "conf\extra\httpd-ssl.conf"
            if (Test-Path $sslConfFile) {
                $sslContent = Get-Content $sslConfFile

                # Asegurar que se usa el puerto correcto
                $sslContent = $sslContent -replace "Listen \d+", "Listen $global:puerto"
                $sslContent = $sslContent -replace "VirtualHost _default_:\d+", "VirtualHost _default_:$global:puerto"

                # Asegurar rutas absolutas a los certificados
                $sslContent = $sslContent -replace "SSLCertificateFile .*", "SSLCertificateFile `"$sslDir\server.crt`""
                $sslContent = $sslContent -replace "SSLCertificateKeyFile .*", "SSLCertificateKeyFile `"$sslDir\server.key`""

                # Guardar cambios en httpd-ssl.conf
                $sslContent | Set-Content $sslConfFile
                Write-Host "Configuración SSL actualizada en httpd-ssl.conf"
            } else {
                Write-Host "Error: No se encontró el archivo httpd-ssl.conf"
                return
            }
        }

        # Buscar el ejecutable de Apache
        $apacheExe = Get-ChildItem -Path $extraerdestino -Recurse -Filter httpd.exe -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($apacheExe) {
            $exeApache = $apacheExe.FullName
            Write-Host "Instalando Apache como servicio..."
            Start-Process -FilePath $exeApache -ArgumentList '-k', 'install', '-n', 'Apache24' -NoNewWindow -Wait

            # Verificar la sintaxis antes de iniciar
            Write-Host "Verificando sintaxis de Apache..."
            $syntaxCheck = & $exeApache -t 2>&1
            if ($syntaxCheck -match "Syntax OK") {
                Write-Host "Sintaxis correcta, iniciando Apache..."
                Start-Service -Name "Apache24"
                Write-Host "Apache instalado y ejecutándose en el puerto $global:puerto"

                # Habilitar el puerto en el firewall al final de la instalación
                habilitar_puerto_firewall
            } else {
                Write-Host "Error de configuración en Apache:"
                Write-Host $syntaxCheck
                return
            }
        } else {
            Write-Host "Error: No se encontró el ejecutable httpd.exe en $extraerdestino"
        }
    } catch {
        Write-Host "Error durante la instalación de Apache: $_"
    }
}

function instalar_tomcat {
    Write-Host "`n============================================"
    Write-Host "   Instalando Apache Tomcat...   "
    Write-Host "============================================"

    # Verificar que la versión de Tomcat está definida
    if (-not $global:version) {
        Write-Host "Error: No se ha seleccionado una versión de Tomcat. Ejecute 'seleccionar_version' antes de instalar Tomcat."
        return
    }

    # Verificar que el puerto está definido
    if (-not $global:puerto) {
        Write-Host "Error: No se ha definido un puerto válido. Ejecute 'preguntar_puerto' antes de instalar Tomcat."
        return
    }

    # Verificar y configurar JAVA_HOME
    $jdkBasePath = "C:\Java"
    $jdkInstallPath = Get-ChildItem -Path $jdkBasePath -Directory | Where-Object { $_.Name -match "^jdk21.*" } | Select-Object -ExpandProperty FullName -First 1

    if (-not $jdkInstallPath -or -not (Test-Path "$jdkInstallPath\bin\java.exe")) {
        Write-Host "Error: Amazon Corretto JDK 21 no está instalado correctamente. Ejecute 'instalar_dependencias' primero."
        return
    }

    # Configurar JAVA_HOME y agregarlo al Path
    Write-Host "Configurando JAVA_HOME..."
    [System.Environment]::SetEnvironmentVariable("JAVA_HOME", $jdkInstallPath, [System.EnvironmentVariableTarget]::Machine)
    $env:JAVA_HOME = $jdkInstallPath
    $env:Path += ";$jdkInstallPath\bin"

    Write-Host "JAVA_HOME configurado correctamente en: $env:JAVA_HOME"

    # Definir URLs y rutas
    $tomcatVersion = $global:version
    $majorVersion = ($tomcatVersion -split "\.")[0]
    $url = "https://dlcdn.apache.org/tomcat/tomcat-${majorVersion}/v$tomcatVersion/bin/apache-tomcat-$tomcatVersion-windows-x64.zip"
    $destinoZip = "$env:USERPROFILE\Downloads\tomcat-$tomcatVersion.zip"
    $extraerDestino = "C:\Tomcat"

    try {
        Write-Host "Descargando Tomcat desde: $url"
        Invoke-WebRequest -Uri $url -OutFile $destinoZip -MaximumRedirection 10 -UseBasicParsing
        Write-Host "Tomcat descargado en: $destinoZip"

        # Eliminar instalación previa si existe
        if (Test-Path $extraerDestino) {
            Write-Host "Eliminando instalación previa de Tomcat..."
            Remove-Item -Path $extraerDestino -Recurse -Force
        }

        # Extraer Tomcat
        Write-Host "Extrayendo archivos de Tomcat en $extraerDestino..."
        Expand-Archive -Path $destinoZip -DestinationPath "C:\" -Force
        Remove-Item -Path $destinoZip -Force

        # Detectar si los archivos están dentro de una subcarpeta
        $subcarpeta = Get-ChildItem -Path "C:\" | Where-Object { $_.PSIsContainer -and $_.Name -match "apache-tomcat-" }
        if ($subcarpeta) {
            Write-Host "Moviendo archivos de $($subcarpeta.FullName) a $extraerDestino..."
            Rename-Item -Path $subcarpeta.FullName -NewName "Tomcat"
        }

        # Verificar que server.xml exista en la ubicación correcta
        $configFile = "$extraerDestino\conf\server.xml"
        if (-not (Test-Path $configFile)) {
            Write-Host "Error: No se encontró el archivo de configuración en $configFile"
            return
        }

        # Configurar HTTPS si el protocolo es HTTPS
        if ($global:protocolo -eq "HTTPS") {
            Write-Host "Configurando SSL en Tomcat..."

            # Ruta para almacenar keystore
            $sslDir = "$extraerDestino\conf"
            $keystorePath = "$sslDir\keystore.jks"
            $keystorePass = "changeit"

            # Verificar si keytool existe
            $keytoolPath = "$jdkInstallPath\bin\keytool.exe"
            if (-not (Test-Path $keytoolPath)) {
                Write-Host "Error: No se encontró keytool.exe en $keytoolPath"
                return
            }

            Write-Host "Generando certificado SSL autofirmado..."
            $sslCommand = "& `"$keytoolPath`" -genkeypair -alias tomcat -keyalg RSA -keysize 2048 -validity 365 -keystore `"$keystorePath`" -storepass `"$keystorePass`" -dname `"CN=localhost, OU=IT, O=Empresa, L=LosMochis, ST=Sinaloa, C=MX`""

            # Ejecutar y capturar salida de keytool
            $sslOutput = Invoke-Expression $sslCommand 2>&1
            if ($sslOutput -match "Exception" -or $sslOutput -match "Error") {
                Write-Host "Error al generar el certificado SSL: $sslOutput"
                return
            }

            # Modificar server.xml para que solo use HTTPS
            Write-Host "Modificando server.xml para habilitar HTTPS..."
            $serverConfig = Get-Content $configFile

            # Eliminar conector HTTP si existe
            $serverConfig = $serverConfig -replace '<Connector port="8080".*?>', ""

            # Agregar conector HTTPS con keystore
            $sslConfig = @"
<Connector port="$global:puerto" protocol="org.apache.coyote.http11.Http11NioProtocol"
           SSLEnabled="true" maxThreads="200"
           scheme="https" secure="true"
           clientAuth="false" sslProtocol="TLS">
    <SSLHostConfig>
        <Certificate certificateKeystoreFile="$keystorePath"
                     type="RSA"
                     certificateKeystorePassword="$keystorePass" />
    </SSLHostConfig>
</Connector>
"@

            # Insertar configuración SSL antes de </Service>
            $serverConfig = $serverConfig -replace '(</Service>)', "$sslConfig`n`$1"
            $serverConfig | Set-Content $configFile
            Write-Host "SSL configurado correctamente en Tomcat."
        } else {
            Write-Host "Configurando Tomcat en HTTP..."
            (Get-Content $configFile) -replace 'Connector port="8080"', "Connector port=`"$global:puerto`"" | Set-Content $configFile
        }

        # Registrar Tomcat como servicio correctamente
        $tomcatService = "$extraerDestino\bin\service.bat"
        if (Test-Path $tomcatService) {
            Write-Host "Registrando Tomcat como servicio..."
            Start-Process -FilePath "cmd.exe" -ArgumentList "/c `"$tomcatService`" install" -WorkingDirectory "$extraerDestino\bin" -NoNewWindow -Wait

            # Iniciar el servicio de Tomcat
            $tomcatServiceName = "Tomcat$majorVersion"
            Start-Service -Name $tomcatServiceName -ErrorAction SilentlyContinue
            Start-Sleep -Seconds 5
            $serviceStatus = Get-Service -Name $tomcatServiceName
            if ($serviceStatus.Status -eq "Running") {
                Write-Host "Tomcat está corriendo en el puerto $global:puerto."
            } else {
                Write-Host "Error: El servicio $tomcatServiceName no se inició correctamente."
            }

            # Habilitar el puerto en el firewall
            habilitar_puerto_firewall
        } else {
            Write-Host "Error: No se encontró el archivo service.bat en $extraerDestino\bin"
        }
    } catch {
        Write-Host "Error durante la instalación de Tomcat: $_"
    }
}


# ------------------------------------------------
# HTTPS
# ------------------------------------------------

# Variable global para almacenar el protocolo seleccionado (HTTP o HTTPS)
$global:protocolo = ""

# Función para seleccionar el protocolo HTTP o HTTPS
function seleccionar_protocolo {
    Write-Host "Seleccione el protocolo a utilizar:"
    Write-Host "1.- HTTP"
    Write-Host "2.- HTTPS (con certificado autofirmado)"
    $opcion = Read-Host "Opción"

    switch ($opcion) {
        "1" {
            $global:protocolo = "HTTP"
        }
        "2" {
            $global:protocolo = "HTTPS"
        }
        default {
            Write-Host "Opción no válida. Intente de nuevo."
            seleccionar_protocolo
        }
    }
}

# Configuración del servidor FTP
$FTP_SERVER = "192.168.1.128"  # Cambia por la IP de tu servidor
$FTP_USER = "windows"          # Usuario para Windows
$FTP_PASS = "123"              # Contraseña

function seleccionar_version_ftp {
    # Si el servicio es IIS, no permitir selección de versión
    if ($global:servicio -eq "IIS") {
        Write-Host "IIS no tiene versiones seleccionables. Se instalará la versión predeterminada para Windows Server."
        $global:version = "IIS (Versión según sistema operativo)"
        return
    }

    # Ajustar la carpeta FTP según el servicio seleccionado
    $carpeta_ftp = switch ($global:servicio) {
        "Apache" { "apache" }
        "Tomcat" { "tomcat" }
        "Nginx" { "nginx" }
        default {
            Write-Host "Servicio no válido."
            return
        }
    }

    Write-Host "Conectando al servidor FTP para listar versiones de $global:servicio..."

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
            $_ -match '^(httpd-[0-9]+\.[0-9]+\.[0-9]+.*\.zip|apache-tomcat-[0-9]+\.[0-9]+\.[0-9]+.*\.zip|nginx-[0-9]+\.[0-9]+\.[0-9]+.*\.zip)$' 
        }

        if ($versionesDisponibles.Count -eq 0 -or -not $versionesDisponibles[0]) {
            Write-Host "No se encontraron versiones disponibles en el servidor FTP para $global:servicio."
            return
        }

        # Mostrar opciones y permitir selección
        Write-Host "Seleccione la versión disponible:"
        for ($i = 0; $i -lt $versionesDisponibles.Count; $i++) {
            Write-Host "$($i+1). $($versionesDisponibles[$i])"
        }

        $seleccion = Read-Host "Ingrese el número de la versión deseada"
        if ($seleccion -match "^\d+$" -and $seleccion -ge 1 -and $seleccion -le $versionesDisponibles.Count) {
            $global:version = $versionesDisponibles[$seleccion - 1]
            Write-Host "Versión seleccionada: $global:version"
        } else {
            Write-Host "Opción no válida, intente de nuevo."
            seleccionar_version_ftp  # Volver a ejecutar la función si la opción no es válida
        }
    } catch {
        Write-Host "Error al conectar al servidor FTP: $_"
    }
}

function proceso_instalacion_ftp {
    if (-not $global:servicio -or -not $global:version -or -not $global:puerto) {
        Write-Host "Debe seleccionar el servicio, la versión y el puerto antes de proceder con la instalación."
        return
    }

    Write-Host "Iniciando instalación desde FTP de $global:servicio versión $global:version en el puerto $global:puerto..."

    switch ($global:servicio) {
        "Apache" {
            instalar_apache_ftp
        }
        "Tomcat" {
            instalar_tomcat_ftp
        }
        "IIS" {
            Write-Host "Error: IIS no se puede instalar desde FTP. Use el instalador web en su lugar."
            return
        }
        default {
            Write-Host "Servicio desconocido o no soportado en FTP. No se puede proceder."
            return
        }
    }

    Write-Host "Instalación completada para $global:servicio versión $global:version en el puerto $global:puerto."

    # Limpiar variables globales después de la instalación
    $global:servicio = $null
    $global:version = $null
    $global:puerto = $null
}

function instalar_apache_ftp {
    # Verificar que la versión de Apache está definida
    if (-not $global:version) {
        Write-Host "Error: No se ha seleccionado una versión de Apache. Ejecute 'Seleccionar-Version-FTP' antes de instalar Apache."
        return
    }

    # Verificar que el puerto está definido
    if (-not $global:puerto) {
        Write-Host "Error: No se ha definido un puerto válido. Ejecute 'preguntar_puerto' antes de instalar Apache."
        return
    }

    # Definir ruta de descarga desde el FTP
    $ftpUri = "ftp://$FTP_SERVER/apache/$global:version"
    $destinoZip = "$env:USERPROFILE\Downloads\apache-$global:version.zip"
    $extraerdestino = "C:\Apache24"

    try {
        Write-Host "Iniciando instalación de Apache HTTP Server versión $global:version desde FTP..."

        # Descargar Apache desde el servidor FTP
        Write-Host "Descargando Apache desde: $ftpUri"
        $webClient = New-Object System.Net.WebClient
        $webClient.Credentials = New-Object System.Net.NetworkCredential($FTP_USER, $FTP_PASS)
        $webClient.DownloadFile($ftpUri, $destinoZip)
        Write-Host "Apache descargado en: $destinoZip"

        # Extraer Apache en C:\Apache24
        Write-Host "Extrayendo archivos de Apache..."
        Expand-Archive -Path $destinoZip -DestinationPath "C:\" -Force
        Write-Host "Apache extraído en $extraerdestino"
        Remove-Item -Path $destinoZip -Force

        # Configurar SSL si el protocolo es HTTPS
        if ($global:protocolo -eq "HTTPS") {
            Write-Host "Configurando Apache para HTTPS..."

            # Crear carpeta SSL si no existe
            $sslDir = "$extraerdestino\conf\ssl"
            if (-not (Test-Path $sslDir)) {
                New-Item -ItemType Directory -Path $sslDir -Force | Out-Null
            }

            # Verificar si OpenSSL está instalado
            $opensslPath = "C:\Program Files\OpenSSL-Win64\bin\openssl.exe"
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

            if ($global:protocolo -eq "HTTPS") {
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
                $confContent = $confContent -replace "(?m)^Listen \d+", "Listen $global:puerto"
            }

            # Guardar cambios en httpd.conf
            $confContent | Set-Content $configFile
            Write-Host "Configuración actualizada para escuchar en el puerto $global:puerto"
        } else {
            Write-Host "Error: No se encontró el archivo de configuración en $configFile"
            return
        }

        # Configurar httpd-ssl.conf si HTTPS está activado
        if ($global:protocolo -eq "HTTPS") {
            $sslConfFile = Join-Path $extraerdestino "conf\extra\httpd-ssl.conf"
            if (Test-Path $sslConfFile) {
                $sslContent = Get-Content $sslConfFile

                # Asegurar que se usa el puerto correcto
                $sslContent = $sslContent -replace "Listen \d+", "Listen $global:puerto"
                $sslContent = $sslContent -replace "VirtualHost _default_:\d+", "VirtualHost _default_:$global:puerto"

                # Asegurar rutas absolutas a los certificados
                $sslContent = $sslContent -replace "SSLCertificateFile .*", "SSLCertificateFile `"$sslDir\server.crt`""
                $sslContent = $sslContent -replace "SSLCertificateKeyFile .*", "SSLCertificateKeyFile `"$sslDir\server.key`""

                # Guardar cambios en httpd-ssl.conf
                $sslContent | Set-Content $sslConfFile
                Write-Host "Configuración SSL actualizada en httpd-ssl.conf"
            } else {
                Write-Host "Error: No se encontró el archivo httpd-ssl.conf"
                return
            }
        }

        # Buscar el ejecutable de Apache
        $apacheExe = Get-ChildItem -Path $extraerdestino -Recurse -Filter httpd.exe -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($apacheExe) {
            $exeApache = $apacheExe.FullName
            Write-Host "Instalando Apache como servicio..."
            Start-Process -FilePath $exeApache -ArgumentList '-k', 'install', '-n', 'Apache24' -NoNewWindow -Wait

            # Verificar la sintaxis antes de iniciar
            Write-Host "Verificando sintaxis de Apache..."
            $syntaxCheck = & $exeApache -t 2>&1
            if ($syntaxCheck -match "Syntax OK") {
                Write-Host "Sintaxis correcta, iniciando Apache..."
                Start-Service -Name "Apache24"
                Write-Host "Apache instalado y ejecutándose en el puerto $global:puerto"

                # Habilitar el puerto en el firewall al final de la instalación
                habilitar_puerto_firewall
            } else {
                Write-Host "Error de configuración en Apache:"
                Write-Host $syntaxCheck
                return
            }
        } else {
            Write-Host "Error: No se encontró el ejecutable httpd.exe en $extraerdestino"
        }
    } catch {
        Write-Host "Error durante la instalación de Apache desde FTP: $_"
    }
}



function instalar_tomcat_ftp {
    Write-Host "`n============================================"
    Write-Host "   Instalando Apache Tomcat desde FTP...   "
    Write-Host "============================================"

    # Verificar que la versión de Tomcat está definida
    if (-not $global:version) {
        Write-Host "Error: No se ha seleccionado una versión de Tomcat. Ejecute 'Seleccionar-Version-FTP' antes de instalar Tomcat."
        return
    }

    # Verificar que el puerto está definido
    if (-not $global:puerto) {
        Write-Host "Error: No se ha definido un puerto válido. Ejecute 'preguntar_puerto' antes de instalar Tomcat."
        return
    }

    # Verificar y configurar JAVA_HOME
    $jdkBasePath = "C:\Java"
    $jdkInstallPath = Get-ChildItem -Path $jdkBasePath -Directory | Where-Object { $_.Name -match "^jdk21.*" } | Select-Object -ExpandProperty FullName -First 1

    if (-not $jdkInstallPath -or -not (Test-Path "$jdkInstallPath\bin\java.exe")) {
        Write-Host "Error: Amazon Corretto JDK 21 no está instalado correctamente. Ejecute 'instalar_dependencias' primero."
        return
    }

    # Configurar JAVA_HOME y agregarlo al Path
    Write-Host "Configurando JAVA_HOME..."
    [System.Environment]::SetEnvironmentVariable("JAVA_HOME", $jdkInstallPath, [System.EnvironmentVariableTarget]::Machine)
    $env:JAVA_HOME = $jdkInstallPath
    $env:Path += ";$jdkInstallPath\bin"

    Write-Host "JAVA_HOME configurado correctamente en: $env:JAVA_HOME"

    # Definir ruta de descarga desde el FTP
    $ftpUri = "ftp://$FTP_SERVER/tomcat/$global:version"
    $destinoZip = "$env:USERPROFILE\Downloads\tomcat-$global:version.zip"
    $extraerDestino = "C:\Tomcat"

    try {
        Write-Host "Descargando Tomcat desde: $ftpUri"
        $webClient = New-Object System.Net.WebClient
        $webClient.Credentials = New-Object System.Net.NetworkCredential($FTP_USER, $FTP_PASS)
        $webClient.DownloadFile($ftpUri, $destinoZip)
        Write-Host "Tomcat descargado en: $destinoZip"

        # Eliminar instalación previa si existe
        if (Test-Path $extraerDestino) {
            Write-Host "Eliminando instalación previa de Tomcat..."
            Remove-Item -Path $extraerDestino -Recurse -Force
        }

        # Extraer Tomcat
        Write-Host "Extrayendo archivos de Tomcat en $extraerDestino..."
        Expand-Archive -Path $destinoZip -DestinationPath "C:\" -Force
        Remove-Item -Path $destinoZip -Force

        # Detectar si los archivos están dentro de una subcarpeta
        $subcarpeta = Get-ChildItem -Path "C:\" | Where-Object { $_.PSIsContainer -and $_.Name -match "apache-tomcat-" }
        if ($subcarpeta) {
            Write-Host "Moviendo archivos de $($subcarpeta.FullName) a $extraerDestino..."
            Rename-Item -Path $subcarpeta.FullName -NewName "Tomcat"
        }

        # Verificar que server.xml exista en la ubicación correcta
        $configFile = "$extraerDestino\conf\server.xml"
        if (-not (Test-Path $configFile)) {
            Write-Host "Error: No se encontró el archivo de configuración en $configFile"
            return
        }

        # Configurar HTTPS si el protocolo es HTTPS
        if ($global:protocolo -eq "HTTPS") {
            Write-Host "Configurando SSL en Tomcat..."

            # Si la versión es "apache-tomcat-9.0.102-windows-x64.zip", seguir un flujo especial
            if ($global:version -eq "apache-tomcat-9.0.102-windows-x64.zip") {
                Write-Host "Detectada versión 9.0.102, aplicando configuración especial para SSL..."

                # Ruta para almacenar keystore
                $sslDir = "$extraerDestino\conf"
                $keystorePath = "$sslDir\keystore.p12"
                $keystorePass = "changeit"

                # Verificar si keytool existe
                $keytoolPath = "$jdkInstallPath\bin\keytool.exe"
                if (-not (Test-Path $keytoolPath)) {
                    Write-Host "Error: No se encontró keytool.exe en $keytoolPath"
                    return
                }

                Write-Host "Generando certificado SSL en formato PKCS12..."
                Start-Process -FilePath $keytoolPath -ArgumentList `
                    "-genkeypair -alias tomcat -keyalg RSA -keysize 2048 -validity 365 -keystore `"$keystorePath`" -storepass `"$keystorePass`" -storetype PKCS12 -dname `"CN=localhost, OU=IT, O=Empresa, L=LosMochis, ST=Sinaloa, C=MX`"" `
                    -NoNewWindow -Wait

                # Modificar server.xml correctamente
                $serverConfig = Get-Content $configFile
                $serverConfig = $serverConfig -replace '<Connector port="8080".*?>', ""

                $sslConfig = @"
<Connector port="$global:puerto" protocol="org.apache.coyote.http11.Http11NioProtocol"
           SSLEnabled="true" maxThreads="200"
           scheme="https" secure="true"
           sslProtocol="TLS"
           keystoreFile="C:/Tomcat/conf/keystore.p12"
           keystorePass="$keystorePass"
           keystoreType="PKCS12"
           keyAlias="tomcat"/>
"@

                $serverConfig = $serverConfig -replace '(</Service>)', "$sslConfig`n`$1"
                $serverConfig | Set-Content $configFile
                Write-Host "SSL configurado correctamente en Tomcat 9.0.102."

            } else {
                # Ruta para almacenar keystore
                $sslDir = "$extraerDestino\conf"
                $keystorePath = "$sslDir\keystore.jks"
                $keystorePass = "changeit"

                # Verificar si keytool existe
                $keytoolPath = "$jdkInstallPath\bin\keytool.exe"
                if (-not (Test-Path $keytoolPath)) {
                    Write-Host "Error: No se encontró keytool.exe en $keytoolPath"
                    return
                }

                Write-Host "Generando certificado SSL autofirmado..."
                $sslCommand = "& `"$keytoolPath`" -genkeypair -alias tomcat -keyalg RSA -keysize 2048 -validity 365 -keystore `"$keystorePath`" -storepass `"$keystorePass`" -dname `"CN=localhost, OU=IT, O=Empresa, L=LosMochis, ST=Sinaloa, C=MX`"" 

                # Ejecutar y capturar salida de keytool
                $sslOutput = Invoke-Expression $sslCommand 2>&1
                if ($sslOutput -match "Exception" -or $sslOutput -match "Error") {
                    Write-Host "Error al generar el certificado SSL: $sslOutput"
                    return
                }
                # Modificar server.xml para que solo use HTTPS
                Write-Host "Modificando server.xml para habilitar HTTPS..."
                $serverConfig = Get-Content $configFile

                # Eliminar conector HTTP si existe
                $serverConfig = $serverConfig -replace '<Connector port="8080".*?>', ""

                # Agregar conector HTTPS con keystore
                $sslConfig = @"
<Connector port="$global:puerto" protocol="org.apache.coyote.http11.Http11NioProtocol"
           SSLEnabled="true" maxThreads="200"
           scheme="https" secure="true"
           clientAuth="false" sslProtocol="TLS">
    <SSLHostConfig>
        <Certificate certificateKeystoreFile="$keystorePath"
                     type="RSA"
                     certificateKeystorePassword="$keystorePass" />
    </SSLHostConfig>
</Connector>
"@

                # Insertar configuración SSL antes de </Service>
                $serverConfig = $serverConfig -replace '(</Service>)', "$sslConfig`n`$1"
                $serverConfig | Set-Content $configFile
                Write-Host "SSL configurado correctamente en Tomcat."
            }
        }

         # Registrar Tomcat como servicio correctamente
        $tomcatService = "$extraerDestino\bin\service.bat"
        if (Test-Path $tomcatService) {
            Write-Host "Registrando Tomcat como servicio..."
            Start-Process -FilePath "cmd.exe" -ArgumentList "/c `"$tomcatService`" install" -WorkingDirectory "$extraerDestino\bin" -NoNewWindow -Wait

            # Obtener el nombre correcto del servicio Tomcat instalado
            $serviceList = Get-Service | Where-Object { $_.Name -match "Tomcat" }
            if ($serviceList.Count -gt 1) {
                Write-Host "Se encontraron múltiples servicios de Tomcat, seleccionando el primero..."
            }
            $tomcatServiceName = $serviceList[0].Name

            if (-not $tomcatServiceName) {
                Write-Host "Error: No se pudo determinar el nombre del servicio de Tomcat."
                return
            }

            Write-Host "Nombre del servicio detectado: $tomcatServiceName"

            # Iniciar el servicio de Tomcat
            Start-Service -Name $tomcatServiceName -ErrorAction SilentlyContinue
            Start-Sleep -Seconds 5

            # Verificar si el servicio se inició correctamente
            $serviceStatus = Get-Service -Name $tomcatServiceName
            if ($serviceStatus.Status -eq "Running") {
                Write-Host "Tomcat está corriendo en el puerto $global:puerto."
            } else {
                Write-Host "Error: El servicio $tomcatServiceName no se inició correctamente."
            }

            # Habilitar el puerto en el firewall
            habilitar_puerto_firewall
        } else {
            Write-Host "Error: No se encontró el archivo service.bat en $extraerDestino\bin"
        }
    } catch {
        Write-Host "Error durante la instalación de Tomcat desde FTP: $_"
    }
}
