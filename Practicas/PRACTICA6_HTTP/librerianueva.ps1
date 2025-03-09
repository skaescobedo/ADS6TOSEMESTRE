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

    # Si el servicio es IIS, no permitir selección de versión
    if ($global:servicio -eq "IIS") {
        Write-Host "IIS no tiene versiones seleccionables. Se instalará la versión predeterminada para Windows Server."
        $global:version = "IIS (Versión según sistema operativo)"
        return
    }

    # Extraer las versiones en variables locales asegurando que `$global:versions` es un array válido
    $versionLTS = if ($global:versions.Count -ge 1) { $global:versions[0] } else { "No disponible" }
    $versionDev = if ($global:versions.Count -ge 2) { $global:versions[1] } else { "No disponible" }

    Write-Host "Seleccione la versión de $global:servicio:"
    $global:version = $versionLTS
    Write-Host "1.- Versión Estable (LTS): $global:version"

    # Si el servicio seleccionado es Apache, deshabilitar la opción 2
    if ($global:servicio -eq "Apache") {
        Write-Host "2.- Versión de Desarrollo: No disponible (Apache solo permite LTS)"
    } else {
        $global:version = $versionDev
        Write-Host "2.- Versión de Desarrollo: $global:version"
    }

    $opcion = Read-Host "Opción"

    switch ($opcion) {
        "1" {
            $global:version = $versionLTS
            Write-Host "Versión seleccionada: $global:version"
        }
        "2" {
            if ($global:servicio -eq "Apache") {
                Write-Host "Opción no válida. Apache solo permite la versión LTS."
                return
            }
            $global:version = $versionDev
            Write-Host "Versión seleccionada: $global:version"
        }
        default {
            Write-Host "Opción no válida."
        }
    }
}
