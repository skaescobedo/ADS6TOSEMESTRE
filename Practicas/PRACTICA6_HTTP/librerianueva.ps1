#FTPPPP
#-----------------------------------------------------------------------------
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

# Función para crear el sitio FTP
function Crear-Sitio-FTP {
    Write-Host "Creando el sitio FTP si no existe..."
    if (-not (Get-WebSite -Name "FTP")) {
        New-WebFtpSite -Name "FTP" -Port 21 -PhysicalPath "C:\FTP"
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

# Función para configurar TLS/SSL
function Configurar-TLS {
    Set-ItemProperty -Path "IIS:\Sites\FTP" -Name "ftpServer.security.ssl.controlChannelPolicy" -Value 0
    Set-ItemProperty -Path "IIS:\Sites\FTP" -Name "ftpServer.security.ssl.dataChannelPolicy" -Value 0
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
    Write-Host "Seleccione el servicio que desea instalar:"
    Write-Host "1.- IIS"
    Write-Host "2.- Apache"
    Write-Host "3.- Tomcat"
    $opcion = Read-Host "Opción"

    switch ($opcion) {
        "1" {
            $global:servicio = "IIS"
            Write-Host "Servicio seleccionado: IIS"
            obtener_versiones_IIS
        }
        "2" {
            $global:servicio = "Apache"
            Write-Host "Servicio seleccionado: Apache"
            obtener_versiones_apache
        }
        "3" {
            $global:servicio = "Tomcat"
            Write-Host "Servicio seleccionado: Tomcat"
            obtener_versiones_tomcat
        }
        default {
            Write-Host "Opción no válida. Intente de nuevo."
            seleccionar_servicio
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

function preguntar_puerto {
    while ($true) {
        $puerto = Read-Host "Ingrese el puerto para el servicio"

        # Validar que la entrada sea un número
        if ($puerto -match "^\d+$") {
            $puerto = [int]$puerto  # Convertir a número
            if (-not (verificar_puerto_en_uso -puerto $puerto)) {
                Write-Host "El puerto $puerto está disponible."
                $global:puerto = $puerto
                break
            } else {
                Write-Host "El puerto $puerto está ocupado. Intente con otro."
            }
        } else {
            Write-Host "Entrada inválida. Ingrese un número de puerto válido."
        }
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

function instalar_apache {
    Write-Host "Obteniendo la última versión de Apache disponible en Apache Lounge..."

    # Descargar la página de Apache Lounge
    $paginaApache = Invoke-WebRequest -Uri "https://www.apachelounge.com/download/" -UseBasicParsing

    # Buscar la URL de descarga más reciente (busca archivos con httpd-x.y.z-win64-VS17.zip)
    $regexApache = "httpd-(\d+\.\d+\.\d+)-win64-VS17.zip"
    $ultimaVersion = ($paginaApache.Links | Where-Object { $_.href -match $regexApache } | Select-Object -First 1).href

    if (-not $ultimaVersion) {
        Write-Host "No se pudo encontrar la versión más reciente de Apache en Apache Lounge. Verifique la página manualmente."
        return
    }

    # Construir la URL de descarga
    $apacheDownloadURL = "https://www.apachelounge.com/download/" + $ultimaVersion
    $global:version = $ultimaVersion -replace "httpd-|win64-VS17.zip", ""  # Extraer solo el número de versión

    Write-Host "Última versión detectada: Apache $global:version"
    Write-Host "Descargando Apache desde: $apacheDownloadURL"

    # Definir directorios de instalación
    $apacheZipPath = "$env:TEMP\httpd-$global:version.zip"
    $apacheExtractPath = "C:\Apache24"

    # Descargar Apache
    Invoke-WebRequest -Uri $apacheDownloadURL -OutFile $apacheZipPath

    if (-not (Test-Path $apacheZipPath)) {
        Write-Host "Error al descargar Apache. Verifique la URL y su conexión a Internet."
        return
    }

    # Extraer el archivo ZIP
    Write-Host "Extrayendo Apache en $apacheExtractPath..."
    Expand-Archive -Path $apacheZipPath -DestinationPath C:\ -Force

    if (-not (Test-Path $apacheExtractPath)) {
        Write-Host "Error al extraer Apache. Verifique los permisos de administrador."
        return
    }

    # Modificar el puerto en httpd.conf
    $httpdConf = "$apacheExtractPath\conf\httpd.conf"
    if (Test-Path $httpdConf) {
        (Get-Content $httpdConf) -replace "Listen 80", "Listen $global:puerto" | Set-Content $httpdConf
        Write-Host "Puerto configurado en httpd.conf: $global:puerto"
    } else {
        Write-Host "No se encontró httpd.conf. La configuración del puerto no se realizó."
    }

    # Registrar Apache como servicio en Windows
    Write-Host "Registrando Apache como servicio en Windows..."
    Start-Process -FilePath "$apacheExtractPath\bin\httpd.exe" -ArgumentList "-k install" -NoNewWindow -Wait

    # Iniciar el servicio de Apache
    Write-Host "Iniciando el servicio Apache..."
    Start-Service -Name "Apache2.4"

    Write-Host "Apache $global:version instalado y configurado en el puerto $global:puerto."
}

function instalar_tomcat {
    Write-Host "Obteniendo la última versión de Tomcat disponible..."

    # Descargar la página de Tomcat para obtener la última versión estable
    $paginaTomcat = Invoke-WebRequest -Uri "https://tomcat.apache.org/download-10.cgi" -UseBasicParsing

    # Buscar la última versión disponible de Tomcat 10 (cambiar a otra versión si es necesario)
    $regexTomcat = "apache-tomcat-(\d+\.\d+\.\d+).zip"
    $ultimaVersion = ($paginaTomcat.Links | Where-Object { $_.href -match $regexTomcat } | Select-Object -First 1).href

    if (-not $ultimaVersion) {
        Write-Host "No se pudo encontrar la versión más reciente de Tomcat en la página oficial. Verifique manualmente."
        return
    }

    # Construir la URL de descarga
    $tomcatDownloadURL = "https://downloads.apache.org/tomcat/tomcat-10/v" + ($ultimaVersion -replace "apache-tomcat-|.zip", "") + "/bin/" + $ultimaVersion
    $global:version = $ultimaVersion -replace "apache-tomcat-|.zip", ""

    Write-Host "Última versión detectada: Tomcat $global:version"
    Write-Host "Descargando Tomcat desde: $tomcatDownloadURL"

    # Definir rutas de instalación
    $tomcatZipPath = "$env:TEMP\apache-tomcat-$global:version.zip"
    $tomcatExtractPath = "C:\Tomcat"

    # Descargar Tomcat
    Invoke-WebRequest -Uri $tomcatDownloadURL -OutFile $tomcatZipPath

    if (-not (Test-Path $tomcatZipPath)) {
        Write-Host "Error al descargar Tomcat. Verifique la URL y su conexión a Internet."
        return
    }

    # Extraer el archivo ZIP
    Write-Host "Extrayendo Tomcat en $tomcatExtractPath..."
    Expand-Archive -Path $tomcatZipPath -DestinationPath C:\ -Force
    Rename-Item -Path "C:\apache-tomcat-$global:version" -NewName "C:\Tomcat"

    if (-not (Test-Path $tomcatExtractPath)) {
        Write-Host "Error al extraer Tomcat. Verifique los permisos de administrador."
        return
    }

    # Modificar el puerto en server.xml
    $serverXml = "$tomcatExtractPath\conf\server.xml"
    if (Test-Path $serverXml) {
        (Get-Content $serverXml) -replace 'Connector port="8080"', "Connector port=`"$global:puerto`"" | Set-Content $serverXml
        Write-Host "Puerto configurado en server.xml: $global:puerto"
    } else {
        Write-Host "No se encontró server.xml. La configuración del puerto no se realizó."
    }

    # Registrar Tomcat como servicio en Windows
    Write-Host "Registrando Tomcat como servicio en Windows..."
    Start-Process -FilePath "$tomcatExtractPath\bin\service.bat" -ArgumentList "install" -NoNewWindow -Wait

    # Iniciar el servicio de Tomcat
    Write-Host "Iniciando el servicio Tomcat..."
    Start-Service -Name "Tomcat10"

    Write-Host "Tomcat $global:version instalado y configurado en el puerto $global:puerto."
}

function instalar_iis {
    Write-Host "Instalando IIS en Windows..."

    # Verificar si IIS ya está instalado
    $iisStatus = Get-WindowsFeature -Name Web-Server
    if ($iisStatus.Installed) {
        Write-Host "IIS ya está instalado en el sistema."
    } else {
        # Instalar IIS
        Write-Host "Habilitando IIS, por favor espere..."
        Install-WindowsFeature -Name Web-Server -IncludeManagementTools

        # Verificar si la instalación fue exitosa
        $iisStatus = Get-WindowsFeature -Name Web-Server
        if ($iisStatus.Installed) {
            Write-Host "IIS se instaló correctamente."
        } else {
            Write-Host "Hubo un error al instalar IIS."
            return
        }
    }

    # Configurar el puerto en el que IIS escuchará
    $global:puerto = if ($global:puerto) { $global:puerto } else { 80 }  # Si el usuario no seleccionó un puerto, usar 80
    Write-Host "Configurando IIS para que escuche en el puerto $global:puerto..."

    # Modificar la configuración de IIS para cambiar el puerto del sitio por defecto
    Import-Module WebAdministration
    Set-ItemProperty 'IIS:\Sites\Default Web Site' -Name bindings -Value @{protocol="http";bindingInformation="*:$global:puerto:"}

    # Reiniciar IIS para aplicar cambios
    Write-Host "Reiniciando IIS..."
    Restart-Service W3SVC

    Write-Host "IIS ha sido instalado y configurado en el puerto $global:puerto."
}

function verificar_servicios {
    Write-Host "`n=================================="
    Write-Host "   Verificando servicios HTTP    "
    Write-Host "=================================="

    # Verificar Apache
    $apacheServicio = Get-Service -Name "Apache2.4" -ErrorAction SilentlyContinue
    if ($apacheServicio) {
        Write-Host "Apache está instalado y su estado es: $($apacheServicio.Status)"

        # Obtener versión de Apache
        $apacheVersion = & "C:\Apache24\bin\httpd.exe" -v 2>$null | Select-String "Server version"
        if ($apacheVersion) {
            $apacheVersion = $apacheVersion -replace "Server version: Apache/", ""
        } else {
            $apacheVersion = "No encontrada"
        }

        # Obtener puerto de Apache desde httpd.conf
        $apacheConfig = Get-Content "C:\Apache24\conf\httpd.conf" | Select-String "Listen "
        $apachePuerto = ($apacheConfig -split "Listen ")[-1] -replace "\D", ""
        if (-not $apachePuerto) { $apachePuerto = "No encontrado" }

        Write-Host "   Versión: $apacheVersion"
        Write-Host "   Puertos: $apachePuerto"
        Write-Host "----------------------------------"
    }

    # Verificar IIS
    $iisStatus = Get-WindowsFeature -Name Web-Server
    if ($iisStatus.Installed) {
        Write-Host "IIS está instalado y ejecutándose."

        # Obtener versión de IIS
        $iisVersion = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\InetStp").VersionString
        if (-not $iisVersion) { $iisVersion = "No encontrada" }

        # Obtener puerto de IIS
        Import-Module WebAdministration
        $iisPuerto = (Get-ItemProperty "IIS:\Sites\Default Web Site").bindings.Collection | ForEach-Object { $_.bindingInformation }
        $iisPuerto = ($iisPuerto -split ':')[-2]
        if (-not $iisPuerto) { $iisPuerto = "No encontrado" }

        Write-Host "   Versión: $iisVersion"
        Write-Host "   Puertos: $iisPuerto"
        Write-Host "----------------------------------"
    }

    # Verificar Tomcat
    $tomcatServicio = Get-Service -Name "Tomcat10" -ErrorAction SilentlyContinue
    if ($tomcatServicio) {
        Write-Host "Tomcat está instalado y su estado es: $($tomcatServicio.Status)"

        # Obtener versión de Tomcat desde catalina.jar
        $tomcatVersionFile = "C:\Tomcat\RELEASE-NOTES"
        if (Test-Path $tomcatVersionFile) {
            $tomcatVersion = (Select-String -Path $tomcatVersionFile -Pattern "Apache Tomcat Version") -replace "Apache Tomcat Version ", ""
        } else {
            $tomcatVersion = "No encontrada"
        }

        # Obtener puerto de Tomcat desde server.xml
        $serverXml = "C:\Tomcat\conf\server.xml"
        if (Test-Path $serverXml) {
            $tomcatPuerto = (Select-String -Path $serverXml -Pattern 'Connector port="(\d+)"') -replace 'Connector port="', '' -replace '"', ''
        } else {
            $tomcatPuerto = "No encontrado"
        }

        Write-Host "   Versión: $tomcatVersion"
        Write-Host "   Puertos: $tomcatPuerto"
        Write-Host "----------------------------------"
    }

    # Si no se encontró ningún servicio
    if (-not $apacheServicio -and -not $iisStatus.Installed -and -not $tomcatServicio) {
        Write-Host "No se detectaron servicios HTTP en ejecución."
    }
}

function instalar_dependencias {
    Write-Host "`n============================================"
    Write-Host "   Verificando e instalando dependencias...   "
    Write-Host "============================================"

    # Verificar e instalar Visual C++ Redistributable (necesario para Apache)
    $vc = Get-WmiObject -Query "SELECT * FROM Win32_Product WHERE Name LIKE '%Visual C++%'" | Select-Object Name
    if ($vc -match "Visual C++ 2017" -or $vc -match "Visual C++ 2022") {
        Write-Host "Visual C++ Redistributable está instalado."
    } else {
        Write-Host "Falta Visual C++ Redistributable. Descargando e instalando..."
        $vcUrl = "https://aka.ms/vs/17/release/vc_redist.x64.exe"
        $vcInstaller = "$env:TEMP\vc_redist.x64.exe"
        Invoke-WebRequest -Uri $vcUrl -OutFile $vcInstaller
        Start-Process -FilePath $vcInstaller -ArgumentList "/install /quiet /norestart" -NoNewWindow -Wait
        Write-Host "Visual C++ Redistributable instalado."
    }

    # Verificar e instalar Java JDK (necesario para Tomcat)
    $java = java -version 2>&1
    if ($java -match "version") {
        Write-Host "Java JDK está instalado."
    } else {
        Write-Host "Falta Java JDK. Descargando e instalando OpenJDK 11..."
        $jdkUrl = "https://github.com/adoptium/temurin11-binaries/releases/latest/download/OpenJDK11U-jdk_x64_windows_hotspot.zip"
        $jdkZip = "$env:TEMP\OpenJDK11.zip"
        $jdkPath = "C:\Java\OpenJDK11"

        # Descargar OpenJDK
        Invoke-WebRequest -Uri $jdkUrl -OutFile $jdkZip
        Expand-Archive -Path $jdkZip -DestinationPath "C:\Java" -Force
        Rename-Item -Path "C:\Java\jdk-11*" -NewName "OpenJDK11"

        # Configurar JAVA_HOME
        [System.Environment]::SetEnvironmentVariable("JAVA_HOME", $jdkPath, [System.EnvironmentVariableTarget]::Machine)
        Write-Host "Java JDK instalado y configurado en JAVA_HOME."
    }

    Write-Host "Verificación e instalación de dependencias completada."
}
