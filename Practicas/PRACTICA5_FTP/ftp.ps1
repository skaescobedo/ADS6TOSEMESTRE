# Importar el módulo de utilidades externas
Import-Module "C:\Users\Administrator\Desktop\librerianueva.ps1"

# Instalar el servidor web y el servidor FTP con todas sus características
#Install-WindowsFeature Web-Server -IncludeAllSubFeature
#Install-WindowsFeature Web-FTP-Server -IncludeAllSubFeature

# Crear estructura base de carpetas FTP
New-Item -ItemType Directory -Path C:\FTP -Force
New-Item -ItemType Directory -Path C:\FTP\grupos -Force
New-Item -ItemType Directory -Path C:\FTP\grupos\reprobados -Force
New-Item -ItemType Directory -Path C:\FTP\grupos\recursadores -Force
New-Item -ItemType Directory -Path C:\FTP\LocalUser -Force  # Aquí se almacenan los usuarios
New-Item -ItemType Directory -Path C:\FTP\LocalUser\Public -Force
New-Item -ItemType Directory -Path C:\FTP\LocalUser\Public\general -Force # Aqui se logearan los usuarios anonimos

# Crear el sitio FTP (si no existe)
if (-not (Get-WebSite -Name "FTP")) {
    New-WebFtpSite -Name "FTP" -Port 21 -PhysicalPath "C:\FTP"
}

# Configurar User Isolation (IsolateAllDirectories - REQUERIDO para que cada usuario solo vea su carpeta)
Set-WebConfigurationProperty -Filter "/system.applicationHost/sites/siteDefaults/ftpServer/userIsolation" `
    -Name "mode" -Value "IsolateAllDirectories"

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

    # Crear el usuario en el sistema (si no existe)
    $usuarioObj = [ADSI]"WinNT://$env:ComputerName/$nombreUsuario"
    if (-not $usuarioObj.Path) {
        $usuarioNuevo = $SistemaUsuarios.Create("User", $nombreUsuario)
        $usuarioNuevo.SetPassword($claveUsuario)
        $usuarioNuevo.SetInfo()
    } else {
        Write-Host "El usuario $nombreUsuario ya existe."
    }

    # Añadir el usuario al grupo correspondiente
    $grupoADS = [ADSI]"WinNT://$env:ComputerName/$grupoFTP,group"
    $grupoADS.Invoke("Add", "WinNT://$env:ComputerName/$nombreUsuario,user")

    # Crear carpeta personal del usuario en LocalUser (requerido por User Isolation)
    $rutaUsuario = "C:\FTP\LocalUser\$nombreUsuario"
    New-Item -ItemType Directory -Path $rutaUsuario -Force

    # Crear subcarpeta personal que lleva el mismo nombre que el usuario
    New-Item -ItemType Directory -Path "$rutaUsuario\$nombreUsuario" -Force

    # Crear symlink al general dentro de Public
    $rutaGeneralUsuario = "$rutaUsuario\general"
    if (Test-Path $rutaGeneralUsuario) {
        Remove-Item $rutaGeneralUsuario -Force
    }
    cmd /c mklink /D $rutaGeneralUsuario "C:\FTP\LocalUser\Public\general"

    # Crear symlink al grupo correspondiente (reprobados o recursadores)
    $rutaGrupoUsuario = "$rutaUsuario\$grupoFTP"
    if (Test-Path $rutaGrupoUsuario) {
        Remove-Item $rutaGrupoUsuario -Force
    }
    cmd /c mklink /D $rutaGrupoUsuario $rutaGrupo

    Write-Host "Usuario $nombreUsuario creado y vinculado correctamente a general y $grupoFTP."
} while ($true)

# Configurar autenticación FTP básica
Set-ItemProperty -Path "IIS:\Sites\FTP" -Name ftpServer.Security.authentication.basicAuthentication.enabled -Value $true

# Configurar autenticación anónima
Set-ItemProperty -Path "IIS:\Sites\FTP" -Name ftpServer.Security.authentication.anonymousAuthentication.enabled -Value $true
Set-ItemProperty -Path "IIS:\Sites\FTP" -Name ftpServer.Security.authentication.anonymousAuthentication.userName -Value "IUSR"
Set-ItemProperty -Path "IIS:\Sites\FTP" -Name ftpServer.Security.authentication.anonymousAuthentication.password -Value ""

# Configurar reglas de autorización FTP
Clear-WebConfiguration "/system.ftpServer/security/authorization" -PSPath "IIS:\"

# Permitir acceso completo a usuarios autenticados (control granular lo puedes ajustar después)
Add-WebConfiguration "/system.ftpServer/security/authorization" -PSPath "IIS:\" -Value @{
    accessType = "Allow";
    roles = "*";
    permissions = 3
} -Location "FTP"

# Permitir solo lectura para anónimos en /anon/general
Add-WebConfiguration "/system.ftpServer/security/authorization" -PSPath "IIS:\" -Value @{
    accessType = "Allow";
    users = "IUSR";
    permissions = 1
} -Location "FTP"

# Permitir conexión sin SSL (desactivar TLS obligatorio)
Set-ItemProperty -Path "IIS:\Sites\FTP" -Name "ftpServer.security.ssl.controlChannelPolicy" -Value 0
Set-ItemProperty -Path "IIS:\Sites\FTP" -Name "ftpServer.security.ssl.dataChannelPolicy" -Value 0

# Reiniciar el sitio FTP para aplicar cambios
Restart-WebItem "IIS:\Sites\FTP"

Write-Host "¡Servidor FTP configurado correctamente con User Isolation (IsolateAllDirectories)!"