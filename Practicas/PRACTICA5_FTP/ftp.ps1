# Script Completo: Configuración FTP IIS con User Isolation

# Variables
$ftpRoot = "C:\FTP"
$generalDir = "$ftpRoot\general"
$groupDir = "$ftpRoot\grupos"
$reprobadosDir = "$groupDir\reprobados"
$recursadoresDir = "$groupDir\recursadores"
$ftpSiteName = "FTP-Sitio"

# 1. Instalar rol FTP e IIS
Install-WindowsFeature -Name Web-FTP-Server -IncludeAllSubFeature -IncludeManagementTools

# 2. Crear estructura de directorios
New-Item -ItemType Directory -Path $generalDir -Force
New-Item -ItemType Directory -Path $reprobadosDir -Force
New-Item -ItemType Directory -Path $recursadoresDir -Force

# 3. Crear grupos locales
New-LocalGroup -Name "reprobados" -ErrorAction SilentlyContinue
New-LocalGroup -Name "recursadores" -ErrorAction SilentlyContinue

# 4. Crear usuarios y asignar a grupos
while ($true) {
    $username = Read-Host "Ingrese nombre de usuario (o 'salir' para terminar)"
    if ($username -eq 'salir') { break }

    $plainPassword = Read-Host "Ingrese contraseña para $username"
    $securePassword = ConvertTo-SecureString -String $plainPassword -AsPlainText -Force

    $groupOption = Read-Host "Seleccione grupo (1: reprobados, 2: recursadores)"
    if ($groupOption -eq "1") { $groupName = "reprobados" }
    elseif ($groupOption -eq "2") { $groupName = "recursadores" }
    else { Write-Host "Opción inválida"; continue }

    Remove-LocalUser -Name $username -ErrorAction SilentlyContinue
    New-LocalUser -Name $username -Password $securePassword -FullName $username -Description "Usuario FTP"

    if (!(Get-LocalUser -Name $username -ErrorAction SilentlyContinue)) {
        Write-Host "Error: El usuario $username no pudo ser creado."
        continue
    }

    Add-LocalGroupMember -Group $groupName -Member $username

    # Crear carpeta personal y asignar permisos
    $userDir = "$ftpRoot\$username"
    New-Item -ItemType Directory -Path $userDir -Force

    & icacls $userDir "/inheritance:r"
    & icacls $userDir "/grant", "${username}:(OI)(CI)F"
    & icacls "$groupDir\$groupName" "/grant", "${username}:(OI)(CI)M"

    Write-Host "Usuario $username creado y agregado al grupo $groupName."
}

# 5. Configurar permisos generales
& icacls $generalDir "/inheritance:r"
& icacls $generalDir "/grant", "Everyone:(OI)(CI)R"
& icacls $generalDir "/grant", "Authenticated Users:(OI)(CI)M"

# 6. Configurar reglas de firewall
New-NetFirewallRule -DisplayName "Allow FTP Port 21" -Direction Inbound -Action Allow -Protocol TCP -LocalPort 21
New-NetFirewallRule -DisplayName "Allow FTP Passive Ports" -Direction Inbound -Action Allow -Protocol TCP -LocalPort 40000-50000

# 7. Configurar y crear el sitio FTP
Import-Module WebAdministration

if (!(Get-WebSite -Name $ftpSiteName -ErrorAction SilentlyContinue)) {
    New-WebFtpSite -Name $ftpSiteName -PhysicalPath $ftpRoot -Port 21 -Force

    Set-ItemProperty "IIS:\Sites\$ftpSiteName" -Name ftpServer.security.authentication.basicAuthentication.enabled -Value $true
    Set-ItemProperty "IIS:\Sites\$ftpSiteName" -Name ftpServer.security.authentication.anonymousAuthentication.enabled -Value $false
    Set-ItemProperty "IIS:\Sites\$ftpSiteName" -Name ftpServer.firewallSupport.passivePortRange -Value "40000-50000"
    Set-ItemProperty "IIS:\Sites\$ftpSiteName" -Name ftpServer.security.ssl.controlChannelPolicy -Value "SslAllow"
    Set-ItemProperty "IIS:\Sites\$ftpSiteName" -Name ftpServer.security.ssl.dataChannelPolicy -Value "SslAllow"

    Clear-WebConfiguration "/system.ftpServer/security/authorization"
    Add-WebConfigurationProperty -Filter "/system.ftpServer/security/authorization" -Name "." -Value @{
        accessType = "Allow"; users = "*"; roles = ""; permissions = "Read"
    }
    Add-WebConfigurationProperty -Filter "/system.ftpServer/security/authorization" -Name "." -Value @{
        accessType = "Allow"; users = ""; roles = ""; permissions = "Read,Write"
    }

    Write-Host "Sitio FTP creado correctamente."
} else {
    Write-Host "El sitio FTP ya existe."
}

# 8. Configurar User Isolation (Aislamiento de Usuarios)
Set-WebConfigurationProperty -Filter "/system.ftpServer/userIsolation" -Name "mode" -Value "IsolateUsers" -PSPath "IIS:\Sites\$ftpSiteName"
Write-Host "User Isolation configurado correctamente."

# 9. Configurar Physical Path (Ruta física raíz) en Advanced Settings
Set-ItemProperty "IIS:\Sites\$ftpSiteName" -Name physicalPath -Value $ftpRoot
Write-Host "Physical Path configurado a $ftpRoot."

Write-Host "Configuración completa de FTP finalizada correctamente."
