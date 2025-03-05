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
    do {
        $nombreUsuario = ""
        $usuarioValido = $false  # Bandera de validación de existencia

        do {
            $nombreUsuario = Read-Host "Introduce el nombre del usuario (o escribe 'salir' para terminar)"

            if ($nombreUsuario -eq "salir") { 
                return  # Salir del proceso
            }

            if ([string]::IsNullOrWhiteSpace($nombreUsuario)) {
                Write-Host "El nombre de usuario no puede estar vacío. Intenta de nuevo."
                continue
            }

            if ($nombreUsuario.Length -gt 20) {
                Write-Host "El nombre de usuario no puede tener más de 20 caracteres. Intenta de nuevo."
                continue
            }

            # Validar si el usuario existe usando Get-LocalUser
            try {
                Get-LocalUser -Name $nombreUsuario | Out-Null
                Write-Host "El usuario '$nombreUsuario' ya existe. Intenta con otro nombre."
            } catch {
                # Si lanza error, el usuario no existe, lo consideramos válido.
                $usuarioValido = $true
            }

        } while (-not $usuarioValido)

        # Validar contraseña
        do {
            $claveUsuario = Read-Host "Introduce la contraseña (mínimo 8 caracteres, una mayúscula, una minúscula, un dígito y un carácter especial)"
            if (-not (comprobarPassword -clave $claveUsuario)) {
                Write-Host "La contraseña no cumple con los requisitos. Intenta de nuevo."
            }
        } while (-not (comprobarPassword -clave $claveUsuario))

        # Seleccionar grupo
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

        # Crear el usuario usando New-LocalUser
        $securePassword = ConvertTo-SecureString -String $claveUsuario -AsPlainText -Force
        New-LocalUser -Name $nombreUsuario -Password $securePassword -FullName $nombreUsuario -Description "Usuario FTP"

        # Agregar al grupo
        Add-LocalGroupMember -Group $grupoFTP -Member $nombreUsuario

        # Crear carpetas y symlinks
        $rutaUsuario = "C:\FTP\LocalUser\$nombreUsuario"
        New-Item -ItemType Directory -Path $rutaUsuario -Force
        New-Item -ItemType Directory -Path "$rutaUsuario\$nombreUsuario" -Force

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
