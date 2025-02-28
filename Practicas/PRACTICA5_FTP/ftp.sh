# Crear función para validar contraseñas
function Validar-Contraseña {
    param ([string]$password)
    if ($password.Length -lt 8) { Write-Host "❌ La contraseña debe tener al menos 8 caracteres."; return $false }
    if ($password -notmatch "[A-Z]") { Write-Host "❌ La contraseña debe contener al menos una mayúscula."; return $false }
    if ($password -notmatch "[a-z]") { Write-Host "❌ La contraseña debe contener al menos una minúscula."; return $false }
    if ($password -notmatch "[0-9]") { Write-Host "❌ La contraseña debe contener al menos un número."; return $false }
    if ($password -notmatch "[\!\@\#\$\%\^\&\*\(\)\_\+\.\,\;\:]") { Write-Host "❌ La contraseña debe contener al menos un carácter especial."; return $false }
    return $true
}

# Crear carpetas base
$ftpRoot = "C:\FTP"
$generalDir = "$ftpRoot\general"
$groupDir = "$ftpRoot\grupos"
$reprobadosDir = "$groupDir\reprobados"
$recursadoresDir = "$groupDir\recursadores"

New-Item -ItemType Directory -Path $generalDir -Force
New-Item -ItemType Directory -Path $reprobadosDir -Force
New-Item -ItemType Directory -Path $recursadoresDir -Force

# Crear grupos locales
New-LocalGroup -Name "reprobados" -ErrorAction SilentlyContinue
New-LocalGroup -Name "recursadores" -ErrorAction SilentlyContinue

# Crear usuarios
while ($true) {
    $username = Read-Host "Ingrese nombre de usuario (o 'salir' para terminar)"
    if ($username -eq 'salir') { break }

    $passwordOK = $false
    while (-not $passwordOK) {
        $plainPassword = Read-Host "Contraseña para $username"
        $passwordOK = Validar-Contraseña -password $plainPassword
    }
    $securePassword = ConvertTo-SecureString -String $plainPassword -AsPlainText -Force

    $groupOption = Read-Host "Grupo (1: reprobados, 2: recursadores)"
    $groupName = if ($groupOption -eq "1") { "reprobados" } elseif ($groupOption -eq "2") { "recursadores" } else { continue }

    Remove-LocalUser -Name $username -ErrorAction SilentlyContinue
    New-LocalUser -Name $username -Password $securePassword -FullName $username -Description "Usuario FTP"
    Add-LocalGroupMember -Group $groupName -Member $username

    $userDir = "$ftpRoot\$username"
    New-Item -ItemType Directory -Path $userDir -Force

    & icacls $userDir "/inheritance:r"
    & icacls $userDir "/grant", "${username}:(OI)(CI)F"
    & icacls $generalDir "/grant", "${username}:(OI)(CI)M"
    & icacls "$groupDir\$groupName" "/grant", "${username}:(OI)(CI)M"

    Write-Host "✅ Usuario $username creado y agregado al grupo $groupName."
}

# Permisos anónimos en /general
& icacls $generalDir "/inheritance:r"
& icacls $generalDir "/grant", "Everyone:(OI)(CI)R"
& icacls $generalDir "/grant", "Authenticated Users:(OI)(CI)M"

# Configurar reglas de firewall
New-NetFirewallRule -DisplayName "Allow FTP Port 21" -Direction Inbound -Action Allow -Protocol TCP -LocalPort 21
New-NetFirewallRule -DisplayName "Allow FTP Passive Ports" -Direction Inbound -Action Allow -Protocol TCP -LocalPort 40000-50000

# Configurar IIS FTP
Import-Module WebAdministration

if (!(Test-Path "IIS:\Sites\FTP-Sitio")) {
    New-WebFtpSite -Name "FTP-Sitio" -PhysicalPath $ftpRoot -Port 21 -Force
    Set-ItemProperty "IIS:\Sites\FTP-Sitio" -Name ftpServer.security.authentication.basicAuthentication.enabled -Value $true
    Set-ItemProperty "IIS:\Sites\FTP-Sitio" -Name ftpServer.security.authentication.anonymousAuthentication.enabled -Value $true
    Set-ItemProperty "IIS:\Sites\FTP-Sitio" -Name ftpServer.firewallSupport.passivePortRange -Value "40000-50000"

    Set-ItemProperty "IIS:\Sites\FTP-Sitio" -Name ftpServer.userIsolation.mode -Value 3  # User name directory (disable global virtual directories)

    Add-WebConfigurationProperty -Filter "/system.ftpServer/security/authorization" -Name "." -Value @{
        accessType="Allow"; users="*"; roles=""; permissions="Read"
    }

    Add-WebConfigurationProperty -Filter "/system.ftpServer/security/authorization" -Name "." -Value @{
        accessType="Allow"; users=""; roles=""; permissions="Read,Write"
    }

    Write-Host "✅ Sitio FTP configurado con aislamiento por usuario y acceso anónimo."
} else {
    Write-Host "ℹ️ El sitio FTP ya existe, solo se actualizaron usuarios."
}

Write-Host "🎉 Configuración completada."
