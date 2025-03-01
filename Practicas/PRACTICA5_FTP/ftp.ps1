# =============================
# Configuración FTP IIS con Isolación y Control de Visibilidad de Carpetas
# =============================

# Variables
$ftpRoot = "C:\FTP"
$generalDir = "$ftpRoot\general"
$usersDir = "$ftpRoot\usuarios"
$groupDir = "$ftpRoot\grupos"
$reprobadosDir = "$groupDir\reprobados"
$recursadoresDir = "$groupDir\recursadores"
$ftpSiteName = "FTP-Sitio"

# 1. Instalar rol FTP e IIS
Install-WindowsFeature -Name Web-FTP-Server -IncludeAllSubFeature -IncludeManagementTools

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
    icacls $usersDir "/deny", "${username}:(OI)(CI)S"

    # Acceso a su carpeta de grupo y denegación a la otra
    if ($groupName -eq "reprobados") {
        icacls "$groupDir\reprobados" "/grant", "${username}:(OI)(CI)M"
        icacls "$groupDir\recursadores" "/deny", "${username}:(OI)(CI)S"
    } elseif ($groupName -eq "recursadores") {
        icacls "$groupDir\recursadores" "/grant", "${username}:(OI)(CI)M"
        icacls "$groupDir\reprobados" "/deny", "${username}:(OI)(CI)S"
    }

    Write-Host "Usuario $username creado y agregado al grupo $groupName."
}

# 5. Permisos generales (acceso anónimo solo lectura a /general)
icacls $generalDir "/inheritance:r"
icacls $generalDir "/grant", "Everyone:(OI)(CI)R"
icacls $generalDir "/grant", "Authenticated Users:(OI)(CI)M"

# 6. Denegar acceso a carpetas de grupos para usuarios anónimos (IUSR)
icacls "$groupDir\reprobados" "/deny", "IUSR:(OI)(CI)S"
icacls "$groupDir\recursadores" "/deny", "IUSR:(OI)(CI)S"

# 7. Configurar User Isolation (Aislamiento de Usuarios)
Set-WebConfigurationProperty -Filter "/system.ftpServer/userIsolation" -Name "mode" -Value "IsolateUsers" -PSPath "IIS:\Sites\$ftpSiteName"

# 8. Configurar Physical Path (Ruta física raíz)
Set-ItemProperty "IIS:\Sites\$ftpSiteName" -Name physicalPath -Value $ftpRoot

Write-Host "Configuración completa de FTP finalizada correctamente."
