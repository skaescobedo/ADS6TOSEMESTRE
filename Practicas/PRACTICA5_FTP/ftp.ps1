# Importar el módulo de utilidades externas
Import-Module "C:\Users\Administrator\Desktop\librerianueva.ps1"

# Instalar el servidor web y el servidor FTP con todas sus características
#Install-WindowsFeature Web-Server -IncludeAllSubFeature
#Install-WindowsFeature Web-FTP-Server -IncludeAllSubFeature

# Crear estructura base de carpetas FTP (Autenticados)
New-Item -ItemType Directory -Path C:\FTP -Force
New-Item -ItemType Directory -Path C:\FTP\grupos -Force
New-Item -ItemType Directory -Path C:\FTP\grupos\reprobados -Force
New-Item -ItemType Directory -Path C:\FTP\grupos\recursadores -Force
New-Item -ItemType Directory -Path C:\FTP\LocalUser -Force

# Crear estructura base para el sitio anónimo
New-Item -ItemType Directory -Path C:\FTP_Anon -Force
New-Item -ItemType Directory -Path C:\FTP_Anon\general -Force

# Crear el sitio FTP (Autenticados)
if (-not (Get-WebSite -Name "FTP")) {
    New-WebFtpSite -Name "FTP" -Port 21 -PhysicalPath "C:\FTP"
}

# Crear el sitio FTP_Anon (Solo anónimos)
if (-not (Get-WebSite -Name "FTP_Anon")) {
    New-WebFtpSite -Name "FTP_Anon" -Port 2121 -PhysicalPath "C:\FTP_Anon"
}

# Configurar User Isolation para el sitio FTP autenticado
Set-WebConfigurationProperty -Filter "/system.applicationHost/sites/site[@name='FTP']/ftpServer/userIsolation" `
    -Name "mode" -Value "IsolateAllDirectories"

# Obtener objeto para manejar usuarios y grupos locales
$SistemaUsuarios = [ADSI]"WinNT://$env:ComputerName"

# Crear grupos de usuarios
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
        $claveUsuario = Read-Host "Introduce la contraseña (8 caracteres, mayúscula, minúscula, dígito, especial)"
        if (-not (comprobarPassword -clave $claveUsuario)) {
            Write-Host "La contraseña no cumple con los requisitos."
        }
    } while (-not (comprobarPassword -clave $claveUsuario))

    # Selección de grupo
    do {
        Write-Host "Selecciona el grupo:"
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
            Write-Host "Opción inválida."
        }
    } while ($true)

    # Crear el usuario si no existe
    $usuarioObj = [ADSI]"WinNT://$env:ComputerName/$nombreUsuario"
    if (-not $usuarioObj.Path) {
        $usuarioNuevo = $SistemaUsuarios.Create("User", $nombreUsuario)
        $usuarioNuevo.SetPassword($claveUsuario)
        $usuarioNuevo.SetInfo()
    }

    # Añadir al grupo
    $grupoADS = [ADSI]"WinNT://$env:ComputerName/$grupoFTP,group"
    $grupoADS.Invoke("Add", "WinNT://$env:ComputerName/$nombreUsuario,user")

    # Crear carpeta personal del usuario en LocalUser
    $rutaUsuario = "C:\FTP\LocalUser\$nombreUsuario"
    New-Item -ItemType Directory -Path $rutaUsuario -Force

    # Subcarpeta personal que lleva el mismo nombre del usuario
    New-Item -ItemType Directory -Path "$rutaUsuario\$nombreUsuario" -Force

    # Crear symlink al general (que apunta a FTP_Anon\general)
    $rutaGeneralUsuario = "$rutaUsuario\general"
    if (Test-Path $rutaGeneralUsuario) { Remove-Item $rutaGeneralUsuario -Force }
    cmd /c mklink /D $rutaGeneralUsuario "C:\FTP_Anon\general"

    # Crear symlink al grupo correspondiente
    $rutaGrupoUsuario = "$rutaUsuario\$grupoFTP"
    if (Test-Path $rutaGrupoUsuario) { Remove-Item $rutaGrupoUsuario -Force }
    cmd /c mklink /D $rutaGrupoUsuario $rutaGrupo

    Write-Host "Usuario $nombreUsuario creado y configurado."
} while ($true)

# Configurar autenticación FTP básica en el sitio autenticado
Set-ItemProperty "IIS:\Sites\FTP" -Name ftpServer.Security.authentication.basicAuthentication.enabled -Value $true

# Configurar autenticación anónima en el sitio anónimo
Set-ItemProperty "IIS:\Sites\FTP_Anon" -Name ftpServer.Security.authentication.anonymousAuthentication.enabled -Value $true
Set-ItemProperty "IIS:\Sites\FTP_Anon" -Name ftpServer.Security.authentication.anonymousAuthentication.userName -Value "IUSR"
Set-ItemProperty "IIS:\Sites\FTP_Anon" -Name ftpServer.Security.authentication.anonymousAuthentication.password -Value ""

# Configurar reglas de autorización en sitio autenticado
Clear-WebConfiguration "/system.ftpServer/security/authorization" -PSPath "IIS:\"

Add-WebConfiguration "/system.ftpServer/security/authorization" -PSPath "IIS:\" -Value @{
    accessType = "Allow";
    roles = "reprobados, recursadores";
    permissions = 3
} -Location "FTP"

# Configurar reglas de autorización en sitio anónimo
Clear-WebConfiguration "/system.ftpServer/security/authorization" -PSPath "IIS:\"

Add-WebConfiguration "/system.ftpServer/security/authorization" -PSPath "IIS:\" -Value @{
    accessType = "Allow";
    users = "IUSR";
    permissions = 1
} -Location "FTP_Anon"

# Permitir FTP sin TLS
Set-ItemProperty "IIS:\Sites\FTP" -Name "ftpServer.security.ssl.controlChannelPolicy" -Value 0
Set-ItemProperty "IIS:\Sites\FTP" -Name "ftpServer.security.ssl.dataChannelPolicy" -Value 0

Set-ItemProperty "IIS:\Sites\FTP_Anon" -Name "ftpServer.security.ssl.controlChannelPolicy" -Value 0
Set-ItemProperty "IIS:\Sites\FTP_Anon" -Name "ftpServer.security.ssl.dataChannelPolicy" -Value 0

# Reiniciar ambos sitios
Restart-WebItem "IIS:\Sites\FTP"
Restart-WebItem "IIS:\Sites\FTP_Anon"

Write-Host "FTP autenticado y FTP anónimo configurados correctamente."
