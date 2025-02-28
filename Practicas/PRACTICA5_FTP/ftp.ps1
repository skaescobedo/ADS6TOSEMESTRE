# Función para validar contraseña
function Validar-Contraseña {
    param (
        [string]$password
    )

    if ($password.Length -lt 8) {
        Write-Host "La contraseña debe tener al menos 8 caracteres."
        return $false
    }
    if ($password -notmatch "[A-Z]") {
        Write-Host "La contraseña debe contener al menos una letra mayúscula."
        return $false
    }
    if ($password -notmatch "[a-z]") {
        Write-Host "La contraseña debe contener al menos una letra minúscula."
        return $false
    }
    if ($password -notmatch "[0-9]") {
        Write-Host "La contraseña debe contener al menos un número."
        return $false
    }
    if ($password -notmatch "[\!\@\#\$\%\^\&\*\(\)\_\+\.\,\;\:]") {
        Write-Host "La contraseña debe contener al menos un carácter especial (!@#$%^&*()_+.,;:)"
        return $false
    }
    return $true
}

# Instalar rol FTP en IIS
Install-WindowsFeature -Name Web-FTP-Server -IncludeAllSubFeature -IncludeManagementTools

# Crear estructura de directorios
$ftpRoot = "C:\FTP"
$generalDir = "$ftpRoot\general"
$groupDir = "$ftpRoot\grupos"
$reprobadosDir = "$groupDir\reprobados"
$recursadoresDir = "$groupDir\recursadores"

New-Item -ItemType Directory -Path $generalDir -Force
New-Item -ItemType Directory -Path $reprobadosDir -Force
New-Item -ItemType Directory -Path $recursadoresDir -Force

# Crear grupos locales (silenciosamente si ya existen)
New-LocalGroup -Name "reprobados" -ErrorAction SilentlyContinue
New-LocalGroup -Name "recursadores" -ErrorAction SilentlyContinue

# Crear usuarios y asignar a grupos
while ($true) {
    $username = Read-Host "Ingrese nombre de usuario (o 'salir' para terminar)"
    if ($username -eq 'salir') { break }

    # Validar contraseña
    $validPassword = $false
    while (-not $validPassword) {
        $plainPassword = Read-Host "Ingrese contraseña para $username"
        $validPassword = Validar-Contraseña -password $plainPassword
    }
    $securePassword = ConvertTo-SecureString -String $plainPassword -AsPlainText -Force

    $groupOption = Read-Host "Seleccione grupo (1: reprobados, 2: recursadores)"
    if ($groupOption -eq "1") { $groupName = "reprobados" }
    elseif ($groupOption -eq "2") { $groupName = "recursadores" }
    else { Write-Host "Opción inválida"; continue }

    # Crear usuario local
    Remove-LocalUser -Name $username -ErrorAction SilentlyContinue  # Por si ya existe
    New-LocalUser -Name $username -Password $securePassword -FullName $username -Description "Usuario FTP"

    if (!(Get-LocalUser -Name $username -ErrorAction SilentlyContinue)) {
        Write-Host "Error: No se pudo crear el usuario $username."
        continue
    }

    # Asignar usuario al grupo
    Add-LocalGroupMember -Group $groupName -Member $username

    # Crear carpeta personal y asignar permisos
    $userDir = "$ftpRoot\$username"
    New-Item -ItemType Directory -Path $userDir -Force

    # Asignar permisos usando &
    & icacls $userDir "/inheritance:r"
    & icacls $userDir "/grant", "${username}:(OI)(CI)F"
    & icacls "$groupDir\$groupName" "/grant", "${username}:(OI)(CI)M"

    Write-Host "Usuario $username creado y agregado al grupo $groupName."
}

# Configurar permisos generales
& icacls $generalDir "/inheritance:r"
& icacls $generalDir "/grant", "Everyone:(OI)(CI)R"
& icacls $generalDir "/grant", "Authenticated Users:(OI)(CI)M"

# Configurar reglas de firewall
New-NetFirewallRule -DisplayName "Allow FTP Port 21" -Direction Inbound -Action Allow -Protocol TCP -LocalPort 21
New-NetFirewallRule -DisplayName "Allow FTP Passive Ports" -Direction Inbound -Action Allow -Protocol TCP -LocalPort 40000-50000

# Configurar sitio FTP en IIS
Import-Module WebAdministration

if (!(Test-Path "IIS:\Sites\FTP-Sitio")) {
    New-WebFtpSite -Name "FTP-Sitio" -PhysicalPath $ftpRoot -Port 21 -Force

    Set-ItemProperty "IIS:\Sites\FTP-Sitio" -Name ftpServer.security.authentication.basicAuthentication.enabled -Value $true
    Set-ItemProperty "IIS:\Sites\FTP-Sitio" -Name ftpServer.security.authentication.anonymousAuthentication.enabled -Value $true
    Set-ItemProperty "IIS:\Sites\FTP-Sitio" -Name ftpServer.firewallSupport.passivePortRange -Value "40000-50000"
    Set-ItemProperty "IIS:\Sites\FTP-Sitio" -Name ftpServer.security.ssl.controlChannelPolicy -Value "SslAllow"
    Set-ItemProperty "IIS:\Sites\FTP-Sitio" -Name ftpServer.security.ssl.dataChannelPolicy -Value "SslAllow"

    # Permitir acceso anónimo solo lectura a /general
    Add-WebConfigurationProperty -Filter "/system.ftpServer/security/authorization" -Name "." -Value @{
        accessType="Allow"; users="*"; roles=""; permissions="Read"
    }

    # Permitir acceso completo a usuarios autenticados
    Add-WebConfigurationProperty -Filter "/system.ftpServer/security/authorization" -Name "." -Value @{
        accessType="Allow"; users=""; roles=""; permissions="Read,Write"
    }

    Write-Host "Sitio FTP 'FTP-Sitio' creado correctamente."
} else {
    Write-Host "El sitio FTP 'FTP-Sitio' ya existe."
}

Write-Host "Configuración completada. Revisa el Administrador de IIS."
