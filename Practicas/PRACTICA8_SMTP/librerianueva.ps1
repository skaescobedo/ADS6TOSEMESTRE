# Script PowerShell para instalar y configurar un servidor de correo (SMTP/POP3/IMAP) en Windows Server
# con hMailServer y SquirrelMail, siguiendo una lógica similar al script de Linux proporcionado.

# 1. Descargar e instalar hMailServer en modo silencioso
$installerPath = "$env:TEMP\hMailServer.exe"
$hMailUrl = "https://www.hmailserver.com/files/hMailServer-5.6.8-B2574.exe"
$config = "C:\Program Files (x86)\hMailServer\Bin\hMailServer.ini"

if (-Not (Test-Path $installerPath)) {
    # Forzar uso de TLS 1.2 para evitar errores de conexión
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

    # Omitir validación de certificados SSL
    Add-Type @"
    using System.Net;
    using System.Security.Cryptography.X509Certificates;
    public class TrustAllCertsPolicy : ICertificatePolicy {
        public bool CheckValidationResult(ServicePoint srvPoint, X509Certificate certificate, WebRequest request, int certificateProblem) {
            return true;
        }
    }
"@
    [System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy

    Invoke-WebRequest -Uri $hMailUrl -OutFile $installerPath

    Write-Output "Instalando el hMailServer"
    Start-Process -FilePath $installerPath -ArgumentList "/SILENT" -Wait

    Stop-Service -name *hmail* -force
    (Get-Content $config) -replace 'AdministratorPassword=.*', "AdministratorPassword=" | Set-Content $config
    Start-Service -name *hmail*
}

# 2. Configurar hMailServer: crear dominio, usuarios, habilitar servicios
# Requiere que la COM API de hMailServer esté registrada
$hMail = New-Object -ComObject hMailServer.Application
$hMail.Authenticate("Administrator", "")  # Asume sin contraseña tras instalación

# Crear dominio
$domain = $hMail.Domains.Add()
$domain.Name = "reprobados.local"
$domain.Active = $true
$domain.Save()

# Crear usuarios
[int]$numeroUsuarios = Read-Host "Ingrese el número de usuarios a crear"

for ($i = 1; $i -le $numeroUsuarios; $i++) {
    $usuario = Read-Host "Ingrese el nombre del usuario $i"
    $contra = Read-Host "Ingrese la contraseña para $usuario"

    $cuenta = $domain.Accounts.Add()
    $cuenta.Address = "$usuario@reprobados.local"
    $cuenta.Password = $contra
    $cuenta.Active = $true
    $cuenta.Save()
}

# 3. Configurar reglas de firewall
New-NetFirewallRule -DisplayName "SMTP (25)" -Direction Inbound -Protocol TCP -LocalPort 25 -Action Allow
New-NetFirewallRule -DisplayName "POP3 (110)" -Direction Inbound -Protocol TCP -LocalPort 110 -Action Allow
New-NetFirewallRule -DisplayName "IMAP (143)" -Direction Inbound -Protocol TCP -LocalPort 143 -Action Allow
New-NetFirewallRule -DisplayName "HTTP (80)" -Direction Inbound -Protocol TCP -LocalPort 80 -Action Allow

# === CONFIGURACIONES ===

# PHP
$phpZipUrl = "https://windows.php.net/downloads/releases/archives/php-7.4.33-Win32-vc15-x64.zip"
$phpZipPath = "$env:TEMP\php-7.4.33-Win32-vc15-x64.zip"
$phpTargetPath = "C:\PHP"
$phpIniPath = "$phpTargetPath\php.ini"

# SquirrelMail
$squirrelUrl = "https://gigenet.dl.sourceforge.net/project/squirrelmail/stable/1.4.22/squirrelmail-webmail-1.4.22.zip?viasf=1"
$squirrelZipPath = "$env:TEMP\squirrelmail-1.4.22.zip"
$squirrelTempExtract = "$env:TEMP\squirrelmail"
$squirrelTargetPath = "C:\inetpub\wwwroot\squirrelmail"
$squirrelDefaultConfig = "$squirrelTargetPath\config\config_default.php"
$squirrelConfig = "$squirrelTargetPath\config\config.php"

# === DESCARGAR E INSTALAR PHP ===

if (-Not (Test-Path $phpTargetPath)) {
    Write-Host "Descargando PHP 7.4.33..."
    Invoke-WebRequest -Uri $phpZipUrl -OutFile $phpZipPath

    Write-Host "Extrayendo PHP..."
    Expand-Archive -Path $phpZipPath -DestinationPath $phpTargetPath -Force
} else {
    Write-Host "PHP ya está instalado en $phpTargetPath"
}

# Crear php.ini si no existe
if (-Not (Test-Path $phpIniPath)) {
    Copy-Item "$phpTargetPath\php.ini-development" $phpIniPath
    Write-Host "php.ini creado desde php.ini-development"
}

# Activar extensiones y zona horaria
Write-Host "Configurando php.ini..."
(Get-Content $phpIniPath) |
ForEach-Object {
    $_ -replace '^;extension=mbstring', 'extension=mbstring' `
       -replace '^;extension=imap', 'extension=imap' `
       -replace '^;extension=sockets', 'extension=sockets' `
       -replace '^;extension=openssl', 'extension=openssl' `
       -replace '^;extension=fileinfo', 'extension=fileinfo' `
       -replace ';date.timezone =', 'date.timezone = America/Mexico_City'
} | Set-Content $phpIniPath

# === VERIFICAR E INSTALAR VISUAL C++ REDISTRIBUTABLE 2015–2022 ===
Write-Host "`nVerificando Visual C++ Redistributable 2015-2022..."

$vcInstalled = Get-ChildItem "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall" |
               Get-ItemProperty |
               Where-Object { $_.DisplayName -match "Visual C\+\+ (2015|2017|2019|2022) Redistributable" -and $_.DisplayName -match "x64" }

if ($vcInstalled) {
    Write-Host "Visual C++ Redistributable 2015-2022 ya está instalado."
} else {
    Write-Host "No se encontró Visual C++ 2015-2022. Descargando e instalando..."

    $vcUrl = "https://aka.ms/vs/17/release/vc_redist.x64.exe"
    $vcInstaller = "$env:TEMP\vc_redist.x64.exe"

    Invoke-WebRequest -Uri $vcUrl -OutFile $vcInstaller
    Start-Process -FilePath $vcInstaller -ArgumentList "/install /quiet /norestart" -Wait

    Write-Host "Visual C++ 2015-2022 instalado correctamente.`n"
}

# === DESCARGAR E INSTALAR SQUIRRELMAIL ===
if (-Not (Test-Path $squirrelTargetPath)) {
    Write-Host "Descargando SquirrelMail 1.4.22..."
    Invoke-WebRequest -Uri $squirrelUrl -OutFile $squirrelZipPath

    Write-Host "Extrayendo SquirrelMail..."
    Expand-Archive -Path $squirrelZipPath -DestinationPath $squirrelTempExtract -Force

    Move-Item -Path "$squirrelTempExtract\squirrelmail-webmail-1.4.22" -Destination $squirrelTargetPath
} else {
    Write-Host "SquirrelMail ya está instalado en $squirrelTargetPath"
}

# Copiar configuración por defecto si no existe
if (-Not (Test-Path $squirrelConfig)) {
    Copy-Item $squirrelDefaultConfig $squirrelConfig
    Write-Host "Archivo config.php creado desde config_default.php"
}

# Asignar permisos a IIS_IUSRS para evitar errores 403
$sid = New-Object System.Security.Principal.SecurityIdentifier("S-1-5-32-568")  # SID para IIS_IUSRS
$account = $sid.Translate([System.Security.Principal.NTAccount])
icacls $squirrelTargetPath /grant ($account + ":(OI)(CI)(RX)") /T | Out-Null
Write-Host "Permisos asignados a IIS_IUSRS sobre la carpeta SquirrelMail.`n"

Write-Host "PHP y SquirrelMail instalados correctamente."
Write-Host "Accede a SquirrelMail en: http://localhost/squirrelmail"
Write-Host "Verifica que PHP esté registrado en IIS como FastCGI si no lo has hecho."

# Ruta a php-cgi.exe
$phpCgiPath = "C:\PHP\php-cgi.exe"

# Verificar si FastCGI ya está registrado
$fcgiList = & "$env:windir\system32\inetsrv\appcmd.exe" list config -section:system.webServer/fastCgi
if ($fcgiList -notmatch [regex]::Escape($phpCgiPath)) {
    Write-Host "Registrando PHP como aplicación FastCGI en IIS..."
    & "$env:windir\system32\inetsrv\appcmd.exe" set config /section:system.webServer/fastCgi /+"[fullPath='$phpCgiPath']"
} else {
    Write-Host "PHP ya está registrado como FastCGI."
}

# Registrar el handler mapping para .php (con resourceType = File para evitar 'No input file specified')
Write-Host "Agregando handler mapping para .php..."
& "$env:windir\system32\inetsrv\appcmd.exe" set config -section:handlers `
    /+"[name='PHP_via_FastCGI',path='*.php',verb='GET,POST,HEAD',modules='FastCgiModule',scriptProcessor='$phpCgiPath',resourceType='File']" `
    /commit:apphost

# Reiniciar IIS para aplicar los cambios
iisreset
