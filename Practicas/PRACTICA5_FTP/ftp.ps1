# PowerShell script para Windows Server 2022 - Configuración de FTP con IIS

# Variables base
$FTP_ROOT = "C:\ftp"
$GENERAL_DIR = "$FTP_ROOT\general"
$GROUP_DIR = "$FTP_ROOT\grupos"
$REPROBADOS_DIR = "$GROUP_DIR\reprobados"
$RECURSADORES_DIR = "$GROUP_DIR\recursadores"

# Instalar el servicio FTP de IIS
Write-Output "Instalando el rol FTP..."
Install-WindowsFeature Web-FTP-Server -IncludeManagementTools

# Crear carpetas base
Write-Output "Creando estructura de directorios FTP..."
New-Item -ItemType Directory -Path $GENERAL_DIR -Force
New-Item -ItemType Directory -Path $REPROBADOS_DIR -Force
New-Item -ItemType Directory -Path $RECURSADORES_DIR -Force

# Crear grupos locales si no existen
Write-Output "Creando grupos de usuarios..."
if (-not (Get-LocalGroup -Name "reprobados" -ErrorAction SilentlyContinue)) {
    New-LocalGroup -Name "reprobados"
}
if (-not (Get-LocalGroup -Name "recursadores" -ErrorAction SilentlyContinue)) {
    New-LocalGroup -Name "recursadores"
}

# Asignar permisos NTFS iniciales
Write-Output "Configurando permisos NTFS..."

# Permitir solo lectura a IIS_IUSRS (usuarios anónimos)
icacls $GENERAL_DIR /grant "IIS_IUSRS:R" /T

# Permisos iniciales para grupos
icacls $REPROBADOS_DIR /grant "reprobados`:(OI)(CI)M" /T
icacls $RECURSADORES_DIR /grant "recursadores`:(OI)(CI)M" /T

# Permitir que ambos grupos escriban en general
icacls $GENERAL_DIR /grant "reprobados`:(OI)(CI)M" /T
icacls $GENERAL_DIR /grant "recursadores`:(OI)(CI)M" /T

# Crear sitio FTP en IIS
Write-Output "Creando sitio FTP en IIS..."
Import-Module WebAdministration

if (-not (Get-WebSite -Name "FTPServidor" -ErrorAction SilentlyContinue)) {
    New-WebFtpSite -Name "FTPServidor" -PhysicalPath $FTP_ROOT -Port 21 -Force
}

# Configurar autenticación y permisos FTP
Set-WebConfigurationProperty -Filter "/system.ftpServer/security/authentication/anonymousAuthentication" -Name "enabled" -Value true -PSPath "IIS:\"
Set-WebConfigurationProperty -Filter "/system.ftpServer/security/authentication/basicAuthentication" -Name "enabled" -Value true -PSPath "IIS:\"

Set-WebConfigurationProperty -Filter "/system.ftpServer/security/authorization" -Name "allowUnlisted" -Value false -PSPath "IIS:\"
Add-WebConfigurationProperty -Filter "/system.ftpServer/security/authorization" -PSPath "IIS:\" -Name "." -Value @{accessType='Allow';users='*';permissions='Read'}

# Función para crear usuarios de forma interactiva
function Crear-Usuario {
    while ($true) {
        $username = Read-Host "Ingrese el nombre del usuario (o 'salir' para finalizar)"
        if ($username -eq "salir") {
            Write-Output "Finalizando creación de usuarios."
            break
        }

        $group_option = Read-Host "Seleccione el grupo (1: reprobados, 2: recursadores)"
        if ($group_option -eq "1") {
            $group = "reprobados"
        } elseif ($group_option -eq "2") {
            $group = "recursadores"
        } else {
            Write-Output "Opción inválida. Inténtelo de nuevo."
            continue
        }

        # Crear usuario solo si no existe
        if (-not (Get-LocalUser -Name $username -ErrorAction SilentlyContinue)) {
            $password = Read-Host "Ingrese la contraseña para el usuario $username" -AsSecureString
            New-LocalUser -Name $username -Password $password -PasswordNeverExpires
            Add-LocalGroupMember -Group $group -Member $username
        } else {
            Write-Output "El usuario $username ya existe."
        }

        # Crear carpeta personal
        $userDir = "$FTP_ROOT\$username"
        if (-not (Test-Path $userDir)) {
            New-Item -ItemType Directory -Path $userDir
        }

        # Asignar permisos NTFS a la carpeta personal
        $aclRule = "$username`:(OI)(CI)M"

        icacls $userDir /grant $aclRule /T
        icacls $REPROBADOS_DIR /grant $aclRule /T
        icacls $RECURSADORES_DIR /grant $aclRule /T
        icacls $GENERAL_DIR /grant $aclRule /T

        Write-Output "Usuario $username creado y agregado al grupo $group."
    }
}

# Ejecutar la función para crear usuarios
Crear-Usuario

# Configurar Firewall (permitir puerto FTP)
Write-Output "Configurando Firewall..."
New-NetFirewallRule -DisplayName "FTPServer" -Direction Inbound -Action Allow -Protocol TCP -LocalPort 21

Write-Output "Configuración completada. Servidor FTP listo en Windows Server 2022."
