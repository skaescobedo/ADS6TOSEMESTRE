# Importar el módulo de utilidades externas
Import-Module "C:\Users\Administrator\Desktop\librerianueva.ps1"

# Instalar el servidor web y el servidor FTP con todas sus características
#Install-WindowsFeature Web-Server -IncludeAllSubFeature
#Install-WindowsFeature Web-FTP-Server -IncludeAllSubFeature

# Crear estructura base de carpetas FTP
New-Item -ItemType Directory -Path C:\FTP -Force
New-Item -ItemType Directory -Path C:\FTP\anon -Force
New-Item -ItemType Directory -Path C:\FTP\anon\general -Force
New-Item -ItemType Directory -Path C:\FTP\grupos -Force
New-Item -ItemType Directory -Path C:\FTP\grupos\reprobados -Force
New-Item -ItemType Directory -Path C:\FTP\grupos\recursadores -Force
New-Item -ItemType Directory -Path C:\FTP\usuarios -Force

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
        $claveUsuario = Read-Host "Introduce la contraseña (8 caracteres, una mayúscula, una minúscula, un dígito y un carácter especial)"
        
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
            $rutaGrupo = "C:\FTP\grupos\reprobados"
            break
        } elseif ($grupoSeleccionado -eq "2") {
            $grupoFTP = "recursadores"
            $rutaGrupo = "C:\FTP\grupos\recursadores"
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

    # Añadir el usuario al grupo correspondiente
    $grupoADS = [ADSI]"WinNT://$env:ComputerName/$grupoFTP,group"
    $grupoADS.Invoke("Add", "WinNT://$env:ComputerName/$nombreUsuario,user")

    # Crear estructura de carpetas por usuario
    $rutaUsuario = "C:\FTP\usuarios\$nombreUsuario"
    New-Item -ItemType Directory -Path $rutaUsuario -Force

    # Crear carpeta personal
    New-Item -ItemType Directory -Path "$rutaUsuario\personal" -Force

    # Crear symlink al general de anon
    $rutaGeneralUsuario = "$rutaUsuario\general"
    if (Test-Path $rutaGeneralUsuario) {
        Remove-Item $rutaGeneralUsuario -Force
    }
    cmd /c mklink /D $rutaGeneralUsuario "C:\FTP\anon\general"

    # Crear symlink al grupo (reprobados o recursadores)
    $rutaGrupoUsuario = "$rutaUsuario\$grupoFTP"
    if (Test-Path $rutaGrupoUsuario) {
        Remove-Item $rutaGrupoUsuario -Force
    }
    cmd /c mklink /D $rutaGrupoUsuario $rutaGrupo

    Write-Host "Usuario $nombreUsuario creado y vinculado correctamente a general y $grupoFTP."

} while ($true)

# Configurar autenticación FTP básica
Set-ItemProperty "IIS:\Sites\FTP" -Name ftpServer.Security.authentication.basicAuthentication.enabled -Value $true

# Desactivar SSL (opcional)
Set-ItemProperty "IIS:\Sites\FTP" -Name ftpServer.security.ssl.dataChannelPolicy -Value 0
Set-ItemProperty "IIS:\Sites\FTP" -Name ftpServer.security.ssl.controlChannelPolicy -Value 0

# Configurar acceso anónimo al FTP usando IUSR
Set-ItemProperty "IIS:\Sites\FTP" -Name ftpServer.Security.authentication.anonymousAuthentication.enabled -Value $true
Set-ItemProperty "IIS:\Sites\FTP" -Name ftpServer.Security.authentication.anonymousAuthentication.userName -Value "IUSR"
Set-ItemProperty "IIS:\Sites\FTP" -Name ftpServer.Security.authentication.anonymousAuthentication.password -Value ""

# Limpiar reglas existentes (si las hubiera)
Clear-WebConfiguration "/system.ftpServer/security/authorization" -PSPath "IIS:\"

# 1. Permitir acceso de solo lectura al usuario anónimo en /anon/general
Add-WebConfiguration "/system.ftpServer/security/authorization" -PSPath "IIS:\" -Value @{
    accessType = "Allow";
    users = "IUSR";
    permissions = 1  # Solo lectura
} -Location "FTP"

# 2. Permitir acceso de lectura y escritura a los grupos reprobados y recursadores en TODO el sitio FTP
Add-WebConfiguration "/system.ftpServer/security/authorization" -PSPath "IIS:\" -Value @{
    accessType = "Allow";
    roles = "reprobados,recursadores";
    permissions = 3  # Lectura y Escritura
} -Location "FTP"

# Reiniciar el sitio FTP para aplicar cambios
Restart-WebItem "IIS:\Sites\FTP"

Write-Host "¡Servidor FTP configurado correctamente con symlinks a general y grupos para cada usuario!"
