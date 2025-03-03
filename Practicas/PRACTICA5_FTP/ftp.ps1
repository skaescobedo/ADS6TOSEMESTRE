# Importar el módulo de utilidades externas
Import-Module "C:\Users\Administrator\Desktop\librerianueva.ps1"

# Instalar el servidor web y el servidor FTP con todas sus características
#Install-WindowsFeature Web-Server -IncludeAllSubFeature
#Install-WindowsFeature Web-FTP-Server -IncludeAllSubFeature

# Crear carpetas base para el servidor FTP
New-Item -ItemType Directory -Path C:\FTP -Force
New-Item -ItemType Directory -Path C:\FTP\general -Force
New-Item -ItemType Directory -Path C:\FTP\recursadores -Force
New-Item -ItemType Directory -Path C:\FTP\reprobados -Force

# Configurar firewall para permitir el puerto FTP
New-NetFirewallRule -DisplayName "Permitir FTP" -Direction Inbound -Protocol TCP -LocalPort 21 -Action Allow

# Crear el sitio FTP
New-WebFtpSite -Name "FTP" -Port 21 -PhysicalPath "C:\FTP"

# Obtener objeto para manejar usuarios y grupos locales
$SistemaUsuarios = [ADSI]"WinNT://$env:ComputerName"

# Crear grupos de usuarios para el FTP
$GrupoReprobados = $SistemaUsuarios.Create("Group", "reprobados")
$GrupoReprobados.SetInfo()
$GrupoReprobados.Description = "Usuarios con acceso a reprobados"
$GrupoReprobados.SetInfo()

$GrupoRecursadores = $SistemaUsuarios.Create("Group", "recursadores")
$GrupoRecursadores.SetInfo()
$GrupoRecursadores.Description = "Usuarios con acceso a recursadores"
$GrupoRecursadores.SetInfo()

# Proceso para capturar usuarios y asignarlos a grupos
do {
    $nombreUsuario = Read-Host "Introduce el nombre del usuario (o escribe 'salir' para terminar)"

    if ($nombreUsuario -eq "salir") {
        break
    }

    # Pedir contraseña y validarla
    do {
        $claveUsuario = Read-Host "Introduce la contraseña (8 caracteres, una mayuscula, una minuscula, un digito y un caracter especial)"
        
        if (-not (comprobarPassword -clave $claveUsuario)) {
            Write-Host "La contraseña no cumple con los requisitos, intenta de nuevo."
        }
    } while (-not (comprobarPassword -clave $claveUsuario))

    # Selección de grupo
    do {
        Write-Host "Selecciona el grupo para el usuario:"
        Write-Host "1) Reprobados"
        Write-Host "2) Recursadores"
        $grupoSeleccionado = Read-Host "Elige 1 o 2"

        if ($grupoSeleccionado -eq "1") {
            $grupoFTP = "reprobados"
            break
        } elseif ($grupoSeleccionado -eq "2") {
            $grupoFTP = "recursadores"
            break
        } else {
            Write-Host "Opción inválida. Selecciona 1 o 2."
        }
    } while ($true)

    # Crear el usuario en el sistema
    $usuarioNuevo = $SistemaUsuarios.Create("User", $nombreUsuario)
    $usuarioNuevo.SetInfo()
    $usuarioNuevo.SetPassword($claveUsuario)
    $usuarioNuevo.SetInfo()

    # Añadir el usuario al grupo
    $grupoADS = [ADSI]"WinNT://$env:ComputerName/$grupoFTP,group"
    $grupoADS.Invoke("Add", "WinNT://$env:ComputerName/$nombreUsuario,user")

    # Crear carpeta personal y asignar permisos
    $rutaPersonal = "C:\FTP\$nombreUsuario"
    if (-not (Test-Path $rutaPersonal)) {
        New-Item -ItemType Directory -Path $rutaPersonal
    }
    icacls $rutaPersonal /inheritance:R
    icacls $rutaPersonal /grant "`"$nombreUsuario`":(OI)(CI)F"

    # Configurar permisos según el grupo seleccionado
    if ($grupoFTP -eq "recursadores") {
        icacls "C:\FTP\recursadores" /grant "`"$nombreUsuario`":(OI)(CI)F"
        icacls "C:\FTP\reprobados" /deny "`"$nombreUsuario`":(CI)(OI)(F)"
    } else {
        icacls "C:\FTP\reprobados" /grant "`"$nombreUsuario`":(OI)(CI)F"
        icacls "C:\FTP\recursadores" /deny "`"$nombreUsuario`":(CI)(OI)(F)"
    }

    # Permisos para la carpeta general
    icacls "C:\FTP\general" /grant "`"$nombreUsuario`":(OI)(CI)F"

} while ($true)

# Configurar permisos y reglas en IIS

# Permitir acceso general a todos en la carpeta 'general'
Add-WebConfiguration "/system.ftpServer/security/authorization" -Value @{
    accessType = "Allow";
    users = "*";
    permissions = 1
} -PsPath IIS:\ -Location "FTP/general"

Add-WebConfiguration "/system.ftpServer/security/authorization" -Value @{
    accessType = "Allow";
    roles = "reprobados,recursadores";
    permissions = 3
} -PsPath IIS:\ -Location "FTP/general"

# Permitir acceso a los grupos reprobados y recursadores al sitio FTP
Add-WebConfiguration "/system.ftpServer/security/authorization" -Value @{
    accessType = "Allow";
    roles = "reprobados,recursadores";
    permissions = 1
} -PsPath IIS:\ -Location "FTP"

# Configuración de autenticación FTP y desactivación de SSL
Set-ItemProperty "IIS:\Sites\FTP" -Name ftpServer.Security.authentication.basicAuthentication.enabled -Value $true
Set-ItemProperty "IIS:\Sites\FTP" -Name ftpServer.security.ssl.dataChannelPolicy -Value 0
Set-ItemProperty "IIS:\Sites\FTP" -Name ftpServer.security.ssl.controlChannelPolicy -Value 0

# Configurar acceso anónimo al FTP
Set-ItemProperty "IIS:\Sites\FTP" -Name ftpServer.Security.authentication.anonymousAuthentication.enabled -Value $true
Set-ItemProperty "IIS:\Sites\FTP" -Name ftpServer.Security.authentication.anonymousAuthentication.userName -Value "IUSR"
Set-ItemProperty "IIS:\Sites\FTP" -Name ftpServer.Security.authentication.anonymousAuthentication.password -Value ""

# Permitir acceso anónimo a la raíz FTP
Add-WebConfiguration "/system.ftpServer/security/authorization" -Value @{
    accessType = "Allow";
    users = "?";
    permissions = 1
} -PsPath IIS:\ -Location "FTP"

# Restringir acceso de IUSR a recursadores y reprobados
icacls "C:\FTP\recursadores" /deny "IUSR:(OI)(CI)(R,W)"
icacls "C:\FTP\reprobados" /deny "IUSR:(OI)(CI)(R,W)"

# Permisos: IUSR puede leer general, pero NO escribir
icacls "C:\FTP\general" /grant "IUSR:(OI)(CI)R"

# Usuarios autenticados (reprobados/recursadores) pueden leer y escribir
icacls "C:\FTP\general" /grant "reprobados:(OI)(CI)M"
icacls "C:\FTP\general" /grant "recursadores:(OI)(CI)M"

# Reiniciar el sitio FTP
Restart-WebItem "IIS:\Sites\FTP"

Write-Host "¡Servidor FTP configurado correctamente!"