# CONFIGURACIÓN INICIAL

$dnsName = "WINSERVER2025.reprobados.com"
$subject = "CN=$dnsName"
$storeMy = "Cert:\LocalMachine\My"
$storeRoot = "Cert:\LocalMachine\Root"

# 1. ELIMINAR CERTIFICADOS EXISTENTES CON EL MISMO SUBJECT

Get-ChildItem -Path $storeMy | Where-Object {
    $_.Subject -eq $subject
} | ForEach-Object {
    Write-Host "Eliminando certificado anterior: $($_.Thumbprint)"
    Remove-Item -Path "$storeMy\$($_.Thumbprint)" -Force
}

# 2. CREAR NUEVO CERTIFICADO BÁSICO

$cert = New-SelfSignedCertificate -DnsName $dnsName -CertStoreLocation $storeMy

Write-Host "Certificado creado:"
Write-Host "Subject: $($cert.Subject)"
Write-Host "Thumbprint: $($cert.Thumbprint)"

# 3. COPIAR A 'TRUSTED ROOT CERTIFICATION AUTHORITIES'

$certPath = "$storeMy\$($cert.Thumbprint)"
$certObject = Get-Item -Path $certPath
$rootStore = New-Object System.Security.Cryptography.X509Certificates.X509Store("Root","LocalMachine")
$rootStore.Open("ReadWrite")
$rootStore.Add($certObject)
$rootStore.Close()

Write-Host "Certificado copiado a Trusted Root Certification Authorities"

# 4. ABRIR PUERTO 636 EN EL FIREWALL

$ruleName = "Abrir puerto 636 para LDAPS"
if (-not (Get-NetFirewallRule -DisplayName $ruleName -ErrorAction SilentlyContinue)) {
    New-NetFirewallRule -DisplayName $ruleName `
        -Direction Inbound `
        -Protocol TCP `
        -LocalPort 636 `
        -Action Allow `
        -Profile Domain,Private `
        -Description "Permitir tráfico LDAPS (TCP 636)"
    Write-Host "Regla de firewall creada para puerto 636"
} else {
    Write-Host "La regla de firewall para el puerto 636 ya existe"
}


# RUTAS Y URLS
$downloads = "$env:USERPROFILE\Downloads"

# multiOTP
$multiotpZipUrl = "https://github.com/multiOTP/multiotp/releases/download/5.9.5.1/multiotp_5.9.5.1.zip"
$multiotpZipName = "multiotp_5.9.5.1.zip"
$multiotpZipPath = Join-Path $downloads $multiotpZipName
$multiotpExtractPath = "$env:TEMP\multiotp_extract"
$multiotpFinalPath = "C:\multiotp"

# Visual C++
$vcRedistX86Url = "https://aka.ms/vs/17/release/vc_redist.x86.exe"
$vcRedistX64Url = "https://aka.ms/vs/17/release/vc_redist.x64.exe"
$vcRedistX86Name = "vc_redist.x86.exe"
$vcRedistX64Name = "vc_redist.x64.exe"
$vcRedistX86Path = Join-Path $downloads $vcRedistX86Name
$vcRedistX64Path = Join-Path $downloads $vcRedistX64Name

# Verificar y descargar multiOTP
if (-Not (Test-Path $multiotpZipPath)) {
    Write-Host "Descargando multiOTP..."
    Invoke-WebRequest -Uri $multiotpZipUrl -OutFile $multiotpZipPath
} else {
    Write-Host "multiOTP ya está en Descargas"
}

# Verificar y descargar VC Redist x86
if (-Not (Test-Path $vcRedistX86Path)) {
    Write-Host "Descargando Visual C++ x86..."
    Invoke-WebRequest -Uri $vcRedistX86Url -OutFile $vcRedistX86Path
} else {
    Write-Host "vc_redist.x86.exe ya está en Descargas"
}

# Verificar y descargar VC Redist x64
if (-Not (Test-Path $vcRedistX64Path)) {
    Write-Host "Descargando Visual C++ x64..."
    Invoke-WebRequest -Uri $vcRedistX64Url -OutFile $vcRedistX64Path
} else {
    Write-Host "vc_redist.x64.exe ya está en Descargas"
}

# Extraer multiOTP
Write-Host "Extrayendo multiOTP..."
if (Test-Path $multiotpExtractPath) {
    Remove-Item $multiotpExtractPath -Recurse -Force
}
Expand-Archive -Path $multiotpZipPath -DestinationPath $multiotpExtractPath -Force

$sourceWindowsFolder = Join-Path $multiotpExtractPath "windows"

if (-Not (Test-Path $sourceWindowsFolder)) {
    Write-Host "Error: no se encontró la carpeta 'windows'"
    Get-ChildItem $multiotpExtractPath | Format-List FullName
    exit 1
}

# Limpiar C:\multiotp si ya existe
if (Test-Path $multiotpFinalPath) {
    Write-Host "Eliminando C:\multiotp anterior..."
    Remove-Item -Path $multiotpFinalPath -Recurse -Force
}

# Mover carpeta a C:\multiotp
Move-Item -Path $sourceWindowsFolder -Destination $multiotpFinalPath
Write-Host "multiOTP listo en C:\multiotp"

# Instalar Visual C++ Redistributables
Write-Host "Instalando Visual C++ Redistributables..."
Start-Process -FilePath $vcRedistX86Path -ArgumentList "/install", "/quiet", "/norestart" -Wait
Start-Process -FilePath $vcRedistX64Path -ArgumentList "/install", "/quiet", "/norestart" -Wait

# Ejecutar los instaladores de multiOTP
$radiusScript = Join-Path $multiotpFinalPath "radius_install.cmd"
$webserviceScript = Join-Path $multiotpFinalPath "webservice_install.cmd"

if (Test-Path $radiusScript) {
    Write-Host "Ejecutando radius_install.cmd..."
    Start-Process -FilePath $radiusScript -Verb RunAs -Wait
}

if (Test-Path $webserviceScript) {
    Write-Host "Ejecutando webservice_install.cmd..."
    Start-Process -FilePath $webserviceScript -Verb RunAs -Wait
}

Write-Host "Proceso finalizado"


# RUTA DE DESTINO
$multiotpConfigPath = "C:\multiotp\config"
$multiotpIniFile = "multiotp.ini"

# CONTENIDO CONFIGURADO DEL INI
$multiotpIniContent = @"
multiotp-database-format-v3
; If backend is set to something different than files,
; and backend_type_validated is set to 1,
; only the specific information needed for the backend
; is used from this config file.

encryption_hash=99CCFC0D033729754B6BB4832FE786A1
actual_version=5.9.5.1
admin_password_hash:=RGAzPSxXYhR9KVE5dScSKCcpNTxNbCIZCHM3NSpnGn0=
anonymous_stat=1
anonymous_stat_last_update=1746206193
anonymous_stat_random_id=36edf4ea9c8defeb29de1b0572776e3253276dbe
attributes_to_encrypt=
auto_resync=1
backend_encoding=UTF-8
backend_type=files
backend_type_validated=0
cache_data=0
cache_ldap_hash=1
case_sensitive_users=0
challenge_response_enabled=0
clear_otp_attribute=
console_authentication=0
create_host=WINSERVER2025
create_time=1746206193
debug=0
default_algorithm=totp
default_dialin_ip_mask=
default_user_group=
default_request_ldap_pwd=0
default_request_prefix_pin=0
demo_mode=0
developer_mode=0
display_log=0
domain_name=
email_admin_address=
email_code_allowed=0
email_code_timeout=600
email_digits=6
encode_file_id=0
encryption_key_full_path=
failure_delayed_time=300
group_attribute=Filter-Id
hash_salt_full_path=
issuer=multiOTP
language=en
last_failed_white_delay=60
last_sync_update=0
last_sync_update_host=
last_update=1746206525
last_update_host=WINSERVER2025
ldap_expired_password_valid=1
ldap_account_suffix=
ldap_activated=1
ldap_base_dn=DC=reprobados,DC=com
ldap_bind_dn=CN=Administrator,CN=Users,DC=reprobados,DC=com
ldap_cache_folder=
ldap_cache_on=1
ldap_cn_identifier=sAMAccountName
ldap_default_algorithm=totp
ldap_domain_controllers=reprobados.com,ldaps://192.168.1.10:636
ldap_group_attribute=memberof
ldap_group_cn_identifier=sAMAccountName
ldap_users_dn=
ldap_hash_cache_time=604800
ldap_in_group=
ldap_language_attribute=preferredLanguage
ldap_network_timeout=10
ldap_port=636
ldap_recursive_cache_only=0
ldap_recursive_groups=1
ldap_server_password:=e2piY1hmIwEqOGg=
ldap_server_type=1
ldap_ssl=0
ldap_synced_user_attribute=
ldap_time_limit=30
ldap_without2fa_in_group=
ldaptls_reqcert=
ldaptls_cipher_suite=
log=0
max_block_failures=6
max_delayed_failures=3
max_event_resync_window=10000
max_event_window=100
max_time_resync_window=90000
max_time_window=600
multiple_groups=0
ntp_server=pool.ntp.org
overwrite_request_ldap_pwd=1
radius_error_reply_message=1
radius_reply_attributor= += 
radius_reply_separator_hex=2c
radius_tag_prefix=
scratch_passwords_digits=6
scratch_passwords_amount=10
self_registration=1
server_cache_level=1
server_cache_lifetime=15552000
server_secret:=VGx1YXU=
server_timeout=5
server_type=
server_url=
sms_api_id:=
sms_basic_auth=0
sms_code_allowed=1
sms_content_encoding=
sms_content_success=
sms_digits=6
sms_encoding=
sms_header=
sms_international_format=0
sms_ip=
sms_message_prefix=
sms_method=
sms_no_double_zero=0
sms_originator=multiOTP
sms_password:=
sms_port=
sms_provider=
sms_send_template=
sms_status_success=
sms_timeout=180
sms_url=
sms_userkey:=
smtp_auth=0
smtp_password:=
smtp_port=25
smtp_sender=
smtp_sender_name=
smtp_server=
smtp_ssl=0
smtp_username=
sql_server=
sql_username=
sql_password:=
sql_database=
sql_schema=
sql_config_table=multiotp_config
sql_cache_table=multiotp_cache
sql_ddns_table=multiotp_ddns
sql_devices_table=multiotp_devices
sql_groups_table=multiotp_groups
sql_log_table=multiotp_log
sql_stat_table=multiotp_stat
sql_tokens_table=multiotp_tokens
sql_users_table=multiotp_users
sync_delete_retention_days=30
syslog_facility=7
syslog_level=5
syslog_port=514
syslog_server=
tel_default_country_code=
timezone=Europe/Zurich
token_serial_number_length=12
token_otp_list_of_length=6
verbose_log_prefix=
sms_challenge_enabled=0
text_sms_challenge=
text_token_challenge=
"@

# Crear la carpeta si no existe
if (-Not (Test-Path $multiotpConfigPath)) {
    New-Item -Path $multiotpConfigPath -ItemType Directory -Force
}

# Escribir el archivo .ini
$multiotpIniFullPath = Join-Path $multiotpConfigPath $multiotpIniFile
$multiotpIniContent | Set-Content -Path $multiotpIniFullPath -Encoding UTF8

Write-Host "`nArchivo multiotp.ini aplicado correctamente en: $multiotpIniFullPath"
