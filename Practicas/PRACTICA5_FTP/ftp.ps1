# =============================
# Configuración FTP IIS con Isolación y Restricción de Visibilidad de Carpetas
# =============================

# Variables
$ftpRoot = "C:\FTP"
$generalDir = "$ftpRoot\general"
$usersDir = "$ftpRoot\usuarios"
$groupDir = "$ftpRoot\grupos"
$reprobadosDir = "$groupDir\reprobados"
$recursadoresDir = "$groupDir\recursadores"
$ftpSiteName = "FTP-Sitio"

# 1. Asegurar que IIS tiene el módulo FTP instalado
$ftpFeature = Get-WindowsFeature Web-FTP-Server
if ($ftpFeature.InstallState -ne "Installed") {
    Write-Host "Instalando el módulo FTP en IIS..."
    Install-WindowsFeature Web-FTP-Server -IncludeAllSubFeature -IncludeManagementTools
    Write-Host "Módulo FTP instalado correctamente."
}

# 2. Crear estructura de directorios
New-Item -ItemType Directory -Path $generalDir -Force
New-Item -ItemType Directory -Path $usersDir -Force
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
    $userDir = "$usersDir\$username"
    New-Item -ItemType Directory -Path $userDir -Force

    # Asignar permisos NTFS para que solo el usuario vea su carpeta
    icacls $userDir "/inheritance:r"
    icacls $userDir "/grant", "${username}:(OI)(CI)F"

    # Restringir visibilidad de directorios no permitidos
    icacls "$usersDir" /deny "${username}:(RX)"
    icacls "$groupDir\reprobados" /deny "${username}:(RX)"
    icacls "$groupDir\recursadores" /deny "${username}:(RX)"

    # Acceso a su carpeta de grupo y denegación a la otra
    if ($groupName -eq "reprobados") {
        icacls "$groupDir\reprobados" "/grant", "${username}:(OI)(CI)M"
        icacls "$groupDir\recursadores" "/deny", "${username}:(RX)"
    } elseif ($groupName -eq "recursadores") {
        icacls "$groupDir\recursadores" "/grant", "${username}:(OI)(CI)M"
        icacls "$groupDir\reprobados" "/deny", "${username}:(RX)"
    }

    Write-Host "Usuario $username creado y agregado al grupo $groupName."
}

# 5. Permisos generales (acceso anónimo solo lectura a /general)
icacls $generalDir "/inheritance:r"
icacls $generalDir "/grant", "Everyone:(OI)(CI)R"
icacls $generalDir "/grant", "Authenticated Users:(OI)(CI)M"

# 6. Denegar acceso a carpetas de grupos para usuarios anónimos (IUSR)
icacls "$groupDir\reprobados" /deny "IUSR:(RX)"
icacls "$groupDir\recursadores" /deny "IUSR:(RX)"

# 7. Verificar si el sitio FTP ya existe antes de configurarlo
Import-Module WebAdministration
if (!(Get-WebSite -Name $ftpSiteName -ErrorAction SilentlyContinue)) {
    Write-Host "El sitio FTP no existe. Creándolo..."
    New-WebFtpSite -Name $ftpSiteName -PhysicalPath $ftpRoot -Port 21 -Force
} else {
    Write-Host "El sitio FTP ya existe."
}

# 8. Configurar User Isolation (Aislamiento de Usuarios)
$ftpPath = "MACHINE/WEBROOT/APPHOST/$ftpSiteName"
if (Test-Path "IIS:\Sites\$ftpSiteName") {
    Set-WebConfigurationProperty -Filter "/system.applicationHost/sites/site[@name='$ftpSiteName']/ftpServer/userIsolation" -Name "mode" -Value "IsolateUsers"
    Write-Host "User Isolation configurado correctamente."
} else {
    Write-Host "Advertencia: No se encontró la configuración de User Isolation. Verifica que el sitio FTP esté activo en IIS."
}

# 9. Configurar Physical Path (Ruta física raíz)
if (Test-Path "IIS:\Sites\$ftpSiteName") {
    Set-ItemProperty "IIS:\Sites\$ftpSiteName" -Name physicalPath -Value $ftpRoot
    Write-Host "Physical Path configurado a $ftpRoot."
} else {
    Write-Host "Advertencia: No se pudo configurar el Physical Path porque el sitio FTP no está disponible en IIS."
}

# 10. Reiniciar IIS para aplicar los cambios
iisreset

Write-Host "Configuración completa de FTP finalizada correctamente."
