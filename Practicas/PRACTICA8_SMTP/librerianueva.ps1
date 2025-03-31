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

# -------------------------------
# 1. INSTALAR IIS Y MÓDULOS PHP
# -------------------------------
Write-Host "`nInstalando IIS y módulos necesarios..."
Install-WindowsFeature Web-Server, Web-Scripting-Tools, Web-Mgmt-Console, Web-CGI -IncludeManagementTools

# -------------------------------
# 2. DESCARGAR Y CONFIGURAR PHP
# -------------------------------
$phpUrl = "https://windows.php.net/downloads/releases/php-7.4.33-Win32-vc15-x64.zip"
$phpZip = "$env:TEMP\php.zip"
$phpDir = "C:\PHP"

Write-Host "Descargando PHP..."
Invoke-WebRequest -Uri $phpUrl -OutFile $phpZip
Expand-Archive -Path $phpZip -DestinationPath $phpDir -Force

# Copiar archivo ini de desarrollo como base
Copy-Item "$phpDir\php.ini-development" "$phpDir\php.ini" -Force

# Habilitar extensiones necesarias en php.ini
(Get-Content "$phpDir\php.ini") |
    ForEach-Object {
        $_ -replace ';extension=mbstring', 'extension=mbstring' `
           -replace ';extension=imap', 'extension=imap' `
           -replace ';extension=gettext', 'extension=gettext' `
           -replace ';extension=openssl', 'extension=openssl'
    } | Set-Content "$phpDir\php.ini"

# -------------------------------
# 3. REGISTRAR PHP EN IIS (FastCGI)
# -------------------------------
$phpCgiPath = "$phpDir\php-cgi.exe"
& $env:windir\system32\inetsrv\appcmd.exe set config /section:system.webServer/fastCgi /+[fullPath='$phpCgiPath']

# Agregar handler para archivos .php
New-WebHandler -Name "PHP_via_FastCGI" -Path "*.php" -Verb "GET,HEAD,POST" -Modules "FastCgiModule" -ScriptProcessor $phpCgiPath -ResourceType File -PSPath "IIS:\"

# -------------------------------
# 4. DESCARGAR SQUIRRELMAIL
# -------------------------------
$sqUrl = "https://www.squirrelmail.org/countdl.php?fileurl=http%3A%2F%2Fprdownloads.sourceforge.net%2Fsquirrelmail%2Fsquirrelmail-webmail-1.4.22.zip"
$sqZip = "$env:TEMP\squirrelmail.zip"
$sqExtractRoot = "C:\inetpub\wwwroot"
$sqExtracted = Join-Path $sqExtractRoot "squirrelmail-webmail-1.4.22"
$sqDir = Join-Path $sqExtractRoot "squirrelmail"

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

Write-Host "Descargando SquirrelMail..."
$wc = New-Object System.Net.WebClient
$wc.Headers.Add("user-agent", "Mozilla/5.0")
$wc.DownloadFile($sqUrl, $sqZip)

if ((Get-Item $sqZip).Length -lt 1000000) {
    Write-Error "El archivo ZIP de SquirrelMail parece estar dañado o incompleto."
    exit
}

Write-Host "Descomprimiendo SquirrelMail..."
Expand-Archive -Path $sqZip -DestinationPath $sqExtractRoot -Force

if (Test-Path $sqDir) {
    Remove-Item $sqDir -Recurse -Force
}
Rename-Item -Path $sqExtracted -NewName "squirrelmail"

# -------------------------------
# 5. PERMISOS Y CONFIGURACIÓN BÁSICA
# -------------------------------
icacls $sqDir /grant "IIS_IUSRS:(OI)(CI)RX"

# Crear archivo básico config.php (puede ser sobrescrito luego por configure.php)
$configDir = "$sqDir\config"
$configFile = "$configDir\config.php"

if (!(Test-Path $configDir)) {
    New-Item -ItemType Directory -Path $configDir | Out-Null
}

Set-Content -Path $configFile -Value @'
<?php
$domain = "reprobados.local";
$imapServerAddress = "localhost";
$imapPort = 143;
$smtpServerAddress = "localhost";
$smtpPort = 25;
$useSendmail = false;
$sendmail_path = 'C:\\xampp\\sendmail\\sendmail.exe';
$sendmail_args = '-t';
?>
'@

# -------------------------------
# 6. MENSAJE FINAL
# -------------------------------
Write-Host "`nSquirrelMail instalado correctamente."
Write-Host "Accede desde: http://localhost/squirrelmail"
Write-Host "Recomendación: ejecuta el configurador de SquirrelMail con:"
Write-Host "  php config\\configure.php"
