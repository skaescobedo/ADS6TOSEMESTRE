# Variables
$ftpRoot = "C:\FTP"
$generalDir = "$ftpRoot\general"
$groupDir = "$ftpRoot\grupos"
$reprobadosDir = "$groupDir\reprobados"
$recursadoresDir = "$groupDir\recursadores"
$ftpSiteName = "FTP-Sitio"
$logFile = "C:\FTP\log_instalacion_ftp.txt"

# Crear Log
"Inicio de configuración FTP - $(Get-Date)`r`n" | Set-Content $logFile

function Write-Log($msg) {
    $msg = "$(Get-Date) - $msg"
    Write-Host $msg
    Add-Content $logFile $msg
}

# 1. Instalar rol FTP e IIS
Install-WindowsFeature -Name Web-FTP-Server -IncludeAllSubFeature -IncludeManagementTools
Write-Log "Rol FTP instalado."

# 2. Crear estructura de directorios
New-Item -ItemType Directory -Path $generalDir -Force
New-Item -ItemType Directory -Path $reprobadosDir -Force
New-Item -ItemType Directory -Path $recursadoresDir -Force
Write-Log "Estructura de carpetas creada."

# 3. Crear grupos locales
New-LocalGroup -Name "reprobados" -ErrorAction SilentlyContinue
New-LocalGroup -Name "recursadores" -ErrorAction SilentlyContinue
Write-Log "Grupos locales creados."

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
    Add-LocalGroupMember -Group $groupName -Member $username

    $userDir = "$ftpRoot\$username"
    New-Item -ItemType Directory -Path $userDir -Force

    icacls $userDir /inheritance:r
    icacls $userDir /grant "${username}:(OI)(CI)F"

    if ($groupName -eq "reprobados") {
        icacls "$groupDir\reprobados" /grant "${username}:(OI)(CI)M"
        icacls "$groupDir\recursadores" /deny "${username}:(OI)(CI)F"
    } elseif ($groupName -eq "recursadores") {
        icacls "$groupDir\recursadores" /grant "${username}:(OI)(CI)M"
        icacls "$groupDir\reprobados" /deny "${username}:(OI)(CI)F"
    }

    Write-Log "Usuario $username creado y agregado al grupo $groupName."
}

# 5. Permisos generales
icacls $generalDir /inheritance:r
icacls $generalDir /grant "Everyone:(OI)(CI)R"
icacls $generalDir /grant "Authenticated Users:(OI)(CI)M"
Write-Log "Permisos generales configurados."

# 6. Denegar acceso a IUSR
icacls "$groupDir\reprobados" /deny "IUSR:(OI)(CI)F"
icacls "$groupDir\recursadores" /deny "IUSR:(OI)(CI)F"
Write-Log "Acceso denegado a IUSR en carpetas de grupo."

# 7. Configurar firewall
New-NetFirewallRule -DisplayName "Allow FTP Port 21" -Direction Inbound -Action Allow -Protocol TCP -LocalPort 21
New-NetFirewallRule -DisplayName "Allow FTP Passive Ports" -Direction Inbound -Action Allow -Protocol TCP -LocalPort 40000-50000
Write-Log "Reglas de firewall configuradas."

# 8. Configurar sitio FTP
Import-Module WebAdministration

if (!(Get-WebSite -Name $ftpSiteName -ErrorAction SilentlyContinue)) {
    New-WebFtpSite -Name $ftpSiteName -PhysicalPath $ftpRoot -Port 21 -Force

    Set-ItemProperty "IIS:\Sites\$ftpSiteName" -Name ftpServer.security.authentication.basicAuthentication.enabled -Value $true
    Set-ItemProperty "IIS:\Sites\$ftpSiteName" -Name ftpServer.security.authentication.anonymousAuthentication.enabled -Value $true

    # Evitar error de passivePortRange si no existe
    try {
        Set-ItemProperty "IIS:\Sites\$ftpSiteName" -Name ftpServer.firewallSupport.passivePortRange -Value "40000-50000"
    } catch {
        Write-Log "Propiedad passivePortRange no disponible, se omite configuración."
    }

    Clear-WebConfiguration "/system.ftpServer/security/authorization"
    Add-WebConfigurationProperty -Filter "/system.ftpServer/security/authorization" -Name "." -Value @{accessType="Allow"; users="*"; permissions="Read,Write"}
    Add-WebConfigurationProperty -Filter "/system.ftpServer/security/authorization" -Name "." -Value @{accessType="Allow"; users=""; permissions="Read"}

    Write-Log "Sitio FTP creado."
}

# 9. Configurar User Isolation (solo si es necesario)
try {
    $currentMode = Get-WebConfigurationProperty -Filter "/system.ftpServer/userIsolation" -Name "mode" -PSPath "IIS:\Sites\$ftpSiteName"
    if ($currentMode.Value -ne "IsolateUsers") {
        Set-WebConfigurationProperty -Filter "/system.ftpServer/userIsolation" -Name "mode" -Value "IsolateUsers" -PSPath "IIS:\Sites\$ftpSiteName"
        Write-Log "User Isolation configurado a IsolateUsers."
    } else {
        Write-Log "User Isolation ya estaba configurado correctamente."
    }
} catch {
    Write-Log "Error al configurar User Isolation: $_"
}

# 10. Configurar Physical Path
Set-ItemProperty "IIS:\Sites\$ftpSiteName" -Name physicalPath -Value $ftpRoot
Write-Log "Physical Path configurado."

Write-Log "Configuración completa de FTP finalizada."
Write-Host "Configuración completa de FTP finalizada. Revisa el log en $logFile"
