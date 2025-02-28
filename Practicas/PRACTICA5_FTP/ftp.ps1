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

    $password = Read-Host "Ingrese contraseña para $username" -AsSecureString
    $groupOption = Read-Host "Seleccione grupo (1: reprobados, 2: recursadores)"
    if ($groupOption -eq "1") { $groupName = "reprobados" }
    elseif ($groupOption -eq "2") { $groupName = "recursadores" }
    else { Write-Host "Opción inválida"; continue }

    # Crear usuario y agregar al grupo
    New-LocalUser -Name $username -Password $password -FullName $username -Description "Usuario FTP" -ErrorAction SilentlyContinue
    Add-LocalGroupMember -Group $groupName -Member $username

    # Crear carpeta personal
    $userDir = "$ftpRoot\$username"
    New-Item -ItemType Directory -Path $userDir -Force

    # Asignar permisos con formato seguro usando ${}
    icacls $userDir /inheritance:r
    icacls $userDir /grant "${username}:(OI)(CI)F"
    icacls "$groupDir\$groupName" /grant "${username}:(OI)(CI)M"

    Write-Host "Usuario $username creado y agregado al grupo $groupName."
}

# Permisos generales para carpeta "general" (solo lectura para todos, escritura para autenticados)
icacls $generalDir /inheritance:r
icacls $generalDir /grant "Everyone:(OI)(CI)R"
icacls $generalDir /grant "Authenticated Users:(OI)(CI)M"

# Configurar reglas de firewall para FTP y modo pasivo
New-NetFirewallRule -DisplayName "Allow FTP Port 21" -Direction Inbound -Action Allow -Protocol TCP -LocalPort 21
New-NetFirewallRule -DisplayName "Allow FTP Passive Ports" -Direction Inbound -Action Allow -Protocol TCP -LocalPort 40000-50000

# Crear el sitio FTP en IIS
Import-Module WebAdministration

if (!(Test-Path "IIS:\Sites\FTP-Sitio")) {
    New-WebFtpSite -Name "FTP-Sitio" -PhysicalPath $ftpRoot -Port 21 -Force
    Set-ItemProperty "IIS:\Sites\FTP-Sitio" -Name ftpServer.security.authentication.basicAuthentication.enabled -Value $true
    Set-ItemProperty "IIS:\Sites\FTP-Sitio" -Name ftpServer.security.authentication.anonymousAuthentication.enabled -Value $true
    Set-ItemProperty "IIS:\Sites\FTP-Sitio" -Name ftpServer.security.ssl.controlChannelPolicy -Value "SslAllow"
    Set-ItemProperty "IIS:\Sites\FTP-Sitio" -Name ftpServer.security.ssl.dataChannelPolicy -Value "SslAllow"

    # Configurar modo pasivo
    Set-ItemProperty "IIS:\Sites\FTP-Sitio" -Name ftpServer.firewallSupport.passivePortRange -Value "40000-50000"

    # Permitir acceso anónimo a /general
    Add-WebConfigurationProperty -Filter "/system.ftpServer/security/authorization" -Name "." -Value @{
        accessType="Allow"; 
        users="*"; 
        roles=""; 
        permissions="Read"
    }

    # Permitir acceso completo a usuarios autenticados
    Add-WebConfigurationProperty -Filter "/system.ftpServer/security/authorization" -Name "." -Value @{
        accessType="Allow"; 
        users=""; 
        roles=""; 
        permissions="Read,Write"
    }

    Write-Host "Sitio FTP 'FTP-Sitio' creado y configurado en IIS."
} else {
    Write-Host "El sitio FTP ya existe. No se creó uno nuevo."
}

Write-Host "Configuración completada. Revisa IIS para confirmar que el sitio esté en funcionamiento."
