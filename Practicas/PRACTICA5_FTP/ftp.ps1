# Configuración FTP en Windows Server 2022 (versión mejorada)

$FTP_ROOT = "C:\ftp"
$GENERAL_DIR = "$FTP_ROOT\general"
$GROUP_DIR = "$FTP_ROOT\grupos"
$REPROBADOS_DIR = "$GROUP_DIR\reprobados"
$RECURSADORES_DIR = "$GROUP_DIR\recursadores"

# Instalar componentes necesarios
Write-Output "Instalando roles y herramientas necesarias..."
Install-WindowsFeature -Name Web-FTP-Service, Web-Mgmt-Console, Web-Mgmt-Service, Web-Scripting-Tools -IncludeManagementTools

# Crear carpetas
Write-Output "Creando estructura de carpetas..."
New-Item -ItemType Directory -Path $GENERAL_DIR -Force
New-Item -ItemType Directory -Path $REPROBADOS_DIR -Force
New-Item -ItemType Directory -Path $RECURSADORES_DIR -Force

# Crear grupos
if (-not (Get-LocalGroup -Name "reprobados" -ErrorAction SilentlyContinue)) { New-LocalGroup -Name "reprobados" }
if (-not (Get-LocalGroup -Name "recursadores" -ErrorAction SilentlyContinue)) { New-LocalGroup -Name "recursadores" }

# Permisos NTFS iniciales
icacls $GENERAL_DIR /grant "IIS_IUSRS:R" /T
icacls $REPROBADOS_DIR /grant "reprobados:(OI)(CI)M" /T
icacls $RECURSADORES_DIR /grant "recursadores:(OI)(CI)M" /T
icacls $GENERAL_DIR /grant "reprobados:(OI)(CI)M" /T
icacls $GENERAL_DIR /grant "recursadores:(OI)(CI)M" /T

# Crear sitio FTP
Write-Output "Creando sitio FTP..."
& "$env:SystemRoot\System32\inetsrv\appcmd.exe" add site /name:"FTPServidor" /bindings:"ftp://*:21" /physicalPath:"$FTP_ROOT"

# Configurar autenticación y permisos FTP (usando appcmd para evitar problemas de PowerShell)
Write-Output "Configurando autenticación y permisos de FTP..."

& "$env:SystemRoot\System32\inetsrv\appcmd.exe" set config /section:system.ftpServer/security.authentication /anonymousAuthentication.enabled:true /basicAuthentication.enabled:true

& "$env:SystemRoot\System32\inetsrv\appcmd.exe" set config "FTPServidor" /section:system.ftpServer/security/authorization /+"[accessType='Allow',users='*',permissions='Read']"

# Función para crear usuarios
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
            Write-Output "Opción inválida."
            continue
        }

        if (-not (Get-LocalUser -Name $username -ErrorAction SilentlyContinue)) {
            $password = Read-Host "Ingrese la contraseña para el usuario $username" -AsSecureString
            New-LocalUser -Name $username -Password $password -PasswordNeverExpires
            Add-LocalGroupMember -Group $group -Member $username
        }

        $userDir = "$FTP_ROOT\$username"
        if (-not (Test-Path $userDir)) { New-Item -ItemType Directory -Path $userDir -Force }

        # Asignar permisos NTFS específicos
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
