# Configuración inicial
Write-Host "Configurando servidor FTP en Windows Server..."

# Instalar rol de Servidor FTP en IIS
Write-Host "Instalando el rol de FTP..."
Install-WindowsFeature Web-FTP-Server -IncludeManagementTools

# Crear estructura de carpetas FTP
$FTP_ROOT = "C:\FTP"
$GENERAL_DIR = "$FTP_ROOT\general"
$GROUP_DIR = "$FTP_ROOT\grupos"
$REPROBADOS_DIR = "$GROUP_DIR\reprobados"
$RECURSADORES_DIR = "$GROUP_DIR\recursadores"

Write-Host "Creando directorios FTP..."
New-Item -ItemType Directory -Path $GENERAL_DIR -Force
New-Item -ItemType Directory -Path $REPROBADOS_DIR -Force
New-Item -ItemType Directory -Path $RECURSADORES_DIR -Force

# Crear el sitio FTP en IIS
Write-Host "Creando el sitio FTP en IIS..."
Import-Module WebAdministration

$siteName = "FTPServer"
if (!(Test-Path "IIS:\Sites\$siteName")) {
    New-WebFtpSite -Name $siteName -Port 21 -PhysicalPath $FTP_ROOT -Force
    Set-ItemProperty "IIS:\Sites\$siteName" -Name ftpServer.security.authentication.anonymousAuthentication.enabled -Value $true
    Set-ItemProperty "IIS:\Sites\$siteName" -Name ftpServer.security.authentication.basicAuthentication.enabled -Value $true
    Set-ItemProperty "IIS:\Sites\$siteName" -Name ftpServer.firewallSupport.passiveModeSettings.lowPort -Value 40000
    Set-ItemProperty "IIS:\Sites\$siteName" -Name ftpServer.firewallSupport.passiveModeSettings.highPort -Value 50000
    Set-ItemProperty "IIS:\Sites\$siteName" -Name ftpServer.userIsolation.mode -Value "IsolateRootDirectoryOnly"
}

Write-Host "Sitio FTP configurado."

# Crear grupos locales para usuarios
Write-Host "Creando grupos locales..."
$groups = @("reprobados", "recursadores")
foreach ($group in $groups) {
    if (-not (Get-LocalGroup -Name $group -ErrorAction SilentlyContinue)) {
        New-LocalGroup -Name $group
    }
}

# Configurar permisos generales
Write-Host "Configurando permisos generales..."

# Permitir lectura/escritura para todos en general
icacls $GENERAL_DIR /grant "*S-1-1-0:(OI)(CI)M" /T  # Todos los usuarios (S-1-1-0)

# Permisos para grupos (Control Total en sus carpetas)
icacls $REPROBADOS_DIR /grant "reprobados:(OI)(CI)F" /T
icacls $RECURSADORES_DIR /grant "recursadores:(OI)(CI)F" /T

# Función para crear usuario y asignar permisos
function Crear-Usuario {
    while ($true) {
        $username = Read-Host "Ingrese nombre de usuario (o 'salir' para finalizar)"

        if ($username -eq "salir") {
            break
        }

        $groupOption = Read-Host "Seleccione el grupo (1: reprobados, 2: recursadores)"

        if ($groupOption -eq "1") {
            $group = "reprobados"
        } elseif ($groupOption -eq "2") {
            $group = "recursadores"
        } else {
            Write-Host "Opción inválida. Intente de nuevo."
            continue
        }

        # Crear usuario local
        Write-Host "Creando usuario $username..."
        $password = Read-Host -AsSecureString "Ingrese la contraseña para $username"

        if (-not (Get-LocalUser -Name $username -ErrorAction SilentlyContinue)) {
            New-LocalUser -Name $username -Password $password -FullName $username -Description "Usuario FTP"
        }

        # Añadir al grupo
        Add-LocalGroupMember -Group $group -Member $username

        # Crear carpeta personal
        $userDir = "$FTP_ROOT\$username"
        New-Item -ItemType Directory -Path $userDir -Force

        # Permiso completo sobre su carpeta personal
        icacls $userDir /grant "$username`:(OI)(CI)F" /T

        # Permiso de modificación sobre el directorio general
        icacls $GENERAL_DIR /grant "$username`:(OI)(CI)M" /T

        # Permiso de modificación sobre la carpeta de su grupo
        if ($group -eq "reprobados") {
            icacls $REPROBADOS_DIR /grant "$username`:(OI)(CI)M" /T
        } elseif ($group -eq "recursadores") {
            icacls $RECURSADORES_DIR /grant "$username`:(OI)(CI)M" /T
        }

        Write-Host "Usuario $username creado y agregado al grupo $group."
    }
}

# Crear usuarios interactivos
Crear-Usuario

# Configurar reglas de firewall para FTP
Write-Host "Configurando firewall..."
netsh advfirewall firewall add rule name="FTP Port 21" protocol=TCP dir=in localport=21 action=allow
netsh advfirewall firewall add rule name="FTP Passive Ports" protocol=TCP dir=in localport=40000-50000 action=allow

Write-Host "Servidor FTP configurado correctamente en Windows Server."
