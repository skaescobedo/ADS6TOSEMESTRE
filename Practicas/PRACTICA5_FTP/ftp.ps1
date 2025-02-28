# PowerShell script para configurar FTP en Windows Server 2022

# Variables base
$FTP_ROOT = "C:\ftp"
$GENERAL_DIR = "$FTP_ROOT\general"
$GROUP_DIR = "$FTP_ROOT\grupos"
$REPROBADOS_DIR = "$GROUP_DIR\reprobados"
$RECURSADORES_DIR = "$GROUP_DIR\recursadores"

# Instalar roles necesarios
Write-Output "Instalando el rol FTP..."
Install-WindowsFeature Web-FTP-Server -IncludeManagementTools

# Crear carpetas base
New-Item -ItemType Directory -Path $GENERAL_DIR -Force
New-Item -ItemType Directory -Path $REPROBADOS_DIR -Force
New-Item -ItemType Directory -Path $RECURSADORES_DIR -Force

# Crear grupos si no existen
if (-not (Get-LocalGroup -Name "reprobados" -ErrorAction SilentlyContinue)) {
    New-LocalGroup -Name "reprobados"
}
if (-not (Get-LocalGroup -Name "recursadores" -ErrorAction SilentlyContinue)) {
    New-LocalGroup -Name "recursadores"
}

# Configurar permisos iniciales
icacls $GENERAL_DIR /grant "IIS_IUSRS:R" /T
icacls $REPROBADOS_DIR /grant "reprobados:(OI)(CI)M" /T
icacls $RECURSADORES_DIR /grant "recursadores:(OI)(CI)M" /T
icacls $GENERAL_DIR /grant "reprobados:(OI)(CI)M" /T
icacls $GENERAL_DIR /grant "recursadores:(OI)(CI)M" /T

# Crear sitio FTP desde cero usando AppCmd
& "$env:SystemRoot\System32\inetsrv\appcmd.exe" add site /name:"FTPServidor" /bindings:"ftp://*:21" /physicalPath:"$FTP_ROOT"

# Configurar autenticación y permisos (corregido para IIS real)
Set-WebConfigurationProperty -Filter "/system.ftpServer/security/authentication/anonymousAuthentication" -Name "enabled" -Value true -PSPath "IIS:\Sites\FTPServidor"
Set-WebConfigurationProperty -Filter "/system.ftpServer/security/authentication/basicAuthentication" -Name "enabled" -Value true -PSPath "IIS:\Sites\FTPServidor"

# Permisos de lectura anónimos
Add-WebConfigurationProperty -Filter "/system.ftpServer/security/authorization" -PSPath "IIS:\Sites\FTPServidor" -Name "." -Value @{accessType="Allow";users="*";permissions="Read"}

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

        # Crear usuario
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

        # Asignar permisos NTFS corregidos
        $aclRule = "${username}:(OI)(CI)M"
        icacls $userDir /grant $aclRule /T
        icacls $REPROBADOS_DIR /grant $aclRule /T
        icacls $RECURSADORES_DIR /grant $aclRule /T
        icacls $GENERAL_DIR /grant $aclRule /T

        Write-Output "Usuario $username creado y agregado al grupo $group."
    }
}

# Crear usuarios
Crear-Usuario

# Configurar Firewall
New-NetFirewallRule -DisplayName "FTPServidor" -Direction Inbound -Action Allow -Protocol TCP -LocalPort 21

Write-Output "Configuración completada. Servidor FTP listo."
