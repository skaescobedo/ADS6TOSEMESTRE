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

# 4. Instalar IIS + PHP para SquirrelMail
Install-WindowsFeature Web-Server, Web-Scripting-Tools, Web-Mgmt-Console

# Descargar PHP
$phpUrl = "https://windows.php.net/downloads/releases/php-7.4.33-Win32-vc15-x64.zip"
$phpZip = "$env:TEMP\php.zip"
$phpDir = "C:\PHP"

Invoke-WebRequest -Uri $phpUrl -OutFile $phpZip
Expand-Archive -Path $phpZip -DestinationPath $phpDir

# Configurar PHP en IIS (asume FastCGI)
Import-Module WebAdministration
Set-ItemProperty "IIS:\Sites\Default Web Site" -Name enabledProtocols -Value "http,net.pipe"

# 5. Descargar y configurar SquirrelMail
$sqUrl = "https://sourceforge.net/projects/squirrelmail/files/squirrelmail-stable/1.4.22/squirrelmail-webmail-1.4.22.zip"
$sqZip = "$env:TEMP\squirrelmail.zip"
$sqDir = "C:\inetpub\wwwroot\squirrelmail"

Invoke-WebRequest -Uri $sqUrl -OutFile $sqZip
Expand-Archive -Path $sqZip -DestinationPath $sqDir

# Establecer permisos
icacls $sqDir /grant "IIS_IUSRS:(OI)(CI)RX"

# Crear archivo de configuracion basico para SquirrelMail
$configFile = "$sqDir\config\config.php"

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

Write-Host "\nServidor de correo configurado exitosamente.\n"
Write-Host "Puedes acceder a SquirrelMail desde: http://localhost/squirrelmail"
