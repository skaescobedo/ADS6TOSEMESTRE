function descargar_archivo_zip {
    $url = "https://drive.usercontent.google.com/download?id=1CnUiT2iaO82O5lJmKJ2qQ3WuAOwKvZG0&export=download&authuser=0&confirm=t&uuid=2b4630c6-37d5-4462-b0c7-d6375e21d417&at=APcmpoxRv2L8WspEM64p3RWg6HN0:1743790563494"
    $ruta_salida = "MERCURY.zip"

    Write-Host "Descargando MERCURY.zip desde Google Drive..."
    Invoke-WebRequest -Uri $url -OutFile $ruta_salida

    if (-Not (Test-Path $ruta_salida)) {
        Write-Host "No se pudo descargar el archivo ZIP." -ForegroundColor Red
        exit
    }
}

function extraer_archivo_zip {
    $ruta_zip = "MERCURY.zip"
    $ruta_destino = "C:\"

    Write-Host "Extrayendo Mercury/32 en $ruta_destino..."
    Expand-Archive -Path $ruta_zip -DestinationPath $ruta_destino -Force
}

function obtener_dominio {
    do {
        $global:dominio = Read-Host "¿Qué dominio quieres usar? (ej. miempresa.com)"
    } while ($global:dominio -notmatch '^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$')

    $global:nombre_corto_dominio = $global:dominio.Split('.')[0]
}

function generar_archivo_ini {
    $iniTemplate = @"
#  MERCURY.INI generated by Mercury Setup
#
#
#  Sample Bindery Mode / Standalone Mode MERCURY.INI file.
#  This sample file implements most of the possible switches for each
#  module, but you can edit it to do less if you wish.
#
#  Anything after a '#' to the end of the line is a comment and
#  is stripped out before parsing. Trailing and leading whitespace
#  is also stripped before parsing. Many sample commands have been
#  left in this file commented out for reference purposes.
#
#  Note that in general, manual modification of this file is NOT
#  RECOMMENDED - use the Mercury "Configuration" menu to change the
#  program's settings wherever possible.
#

[General]
myname:          {{DOMINIO_CANONICO}}    # Canonical name for this server
timezone:        +0000    # Time Zone to add to date fields
file_api:        1    # Use the file api instead of queues
mailqueue:       C:\MERCURY\QUEUE    # Where mail should be put for delivery
smtpqueue:       C:\MERCURY\QUEUE    # Where the SMTP client should look for mail
newmail_path:    C:\MERCURY\MAIL\~N    # Where to find the users' WinPMail mailboxes.

[Protocols]
MERCURYS.DLL
MERCURYP.DLL
# MERCURYE.DLL
# MERCURYC.DLL
# MERCURYD.DLL
# MERCURYH.DLL
# MERCURYF.DLL
# MERCURYW.DLL
# MERCURYX.DLL
MERCURYI.DLL
# MERCURYB.DLL

[Mercury]
failfile:      C:\MERCURY\Mercury\FAILURE.MER
confirmfile:   C:\MERCURY\Mercury\CONFIRM.MER
aliasfile:     C:\MERCURY\Mercury\ALIAS.MER
synfile:       C:\MERCURY\Mercury\SYNONYM.MER
listfile:      C:\MERCURY\Mercury\LISTS.MER
logfile:       C:\MERCURY\Logs\Core\~y-~m-~d.log
logwidth:      30
retpath:       1
maxhops:       30
gullible:      0
poll:          10
scratch:       C:\MERCURY\Scratch
returnlines:   15
postmaster:    Admin
broadcast:     1
receipts:      0
PM_notify:     1
change_owner:  1
auto_tzone:    1
LogLevel:      15
LogMax:        100
RetryPeriod:   30
MaxRetries:    16
TwoPasses:     1
Autoaddress:   0
Daily_exit:    0
No_Areply:     0
Alt_Forward:   0
Maint_hour:    2
Maint_min:     0
Retry_Mode:    0
Local_DSNs:    1
DSN_time1:     10800
DSN_time2:     86400
DSN_time3:     259200
Host_in_title: 0
Lingering:     0
Linger_Timeout: 60
Alert_Host:    notify.pmail.com
Alert_Interval: 720
Alert_Flags:   3
Fast_First_Retry: 0
Fast_First_Retry_Secs: 60

[MercuryC]
logfile : C:\MERCURY\Logs\MercuryC\~y-~m-~d.log
Session_logging : C:\MERCURY\Sessions\MercuryC\
host:
scratch:     C:\MERCURY\scratch
poll:        30
returnlines: 15
failfile:    C:\MERCURY\Mercury\FAILURE.MER
esmtp:       1

[MercuryE]
logfile : C:\MERCURY\Logs\MercuryE\~y-~m-~d.log
Session_logging : C:\MERCURY\Sessions\MercuryE\

[MercuryD]
Session_logging : C:\MERCURY\Sessions\MercuryD\
Scratch : C:\MERCURY\Scratch\MercuryD

[MercuryS]
logfile : C:\MERCURY\Logs\MercuryS\~y-~m-~d.log
Session_logging : C:\MERCURY\Sessions\MercuryS\
debug:       1
timeout : 30
Relay : 0

[MercuryP]
logfile : C:\MERCURY\Logs\MercuryP\~y-~m-~d.log
Session_logging : C:\MERCURY\Sessions\MercuryP\
Scratch : C:\MERCURY\Scratch\MercuryP

[MercuryX]

[Domains]
{{NOMBRE_CORTO_DOMINIO}}: {{NOMBRE_CORTO_DOMINIO}}
{{NOMBRE_CORTO_DOMINIO}}: {{DOMINIO_CANONICO}}

[Maiser]
Helpfile:        C:\MERCURY\Mercury\MAISER.HLP
Lookupfile:      C:\MERCURY\Mercury\MAISER.LKP
Send_dir:        C:\MERCURY\Mercury\SENDABLE
Logfile:         C:\MERCURY\Logs\Maiser\~y-~m-~d.LOG
Notify:          C:\MERCURY\Mercury\TMP
NoList:          N
Local_only:      Y

[MercuryH]
logfile : C:\MERCURY\Logs\MercuryH\~y-~m-~d.log

[MercuryI]
Scratch : C:\MERCURY\Scratch\MercuryI
logfile : C:\MERCURY\Logs\MercuryI\~y-~m-~d.log
Session_logging : C:\MERCURY\Sessions\MercuryI\

[MercuryB]
Scratch : C:\MERCURY\Scratch\MercuryB
logfile : C:\MERCURY\Logs\MercuryB\~y-~m-~d.log
Session_logging : C:\MERCURY\Sessions\MercuryB\

[Groups]

[Rewrite]

[Statistics]
StatFlags:    0
STF_Hours:    24
STM_Hours:    24
"@

    # Reemplazar variables
    $iniFinal = $iniTemplate -replace "{{DOMINIO_CANONICO}}", $global:dominio
    $iniFinal = $iniFinal -replace "{{NOMBRE_CORTO_DOMINIO}}", $global:nombre_corto_dominio

    # Guardar archivo INI con codificación UTF8 sin BOM
    $iniPath = "C:\MERCURY\MERCURY.INI"
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($iniPath, $iniFinal, $utf8NoBom)

    Write-Host "Mercury/32 instalado correctamente con dominio $global:dominio"
}

function configurar_firewall_mercury {
    Write-Host "Configurando reglas de firewall..."
    New-NetFirewallRule -DisplayName "Mercury SMTP (25)" -Direction Inbound -Protocol TCP -LocalPort 25 -Action Allow -Profile Any
    New-NetFirewallRule -DisplayName "Mercury POP3 (110)" -Direction Inbound -Protocol TCP -LocalPort 110 -Action Allow -Profile Any
    New-NetFirewallRule -DisplayName "Mercury IMAP (143)" -Direction Inbound -Protocol TCP -LocalPort 143 -Action Allow -Profile Any
}

function crear_usuarios_mercury {
    # Rutas
    $mercuryPath = "C:\Mercury"
    $mailDir = "$mercuryPath\Mail"
    $pMailUsrPath = "$mailDir\PMAIL.USR"
    $mercuryExe = "$mercuryPath\Mercury.exe"

    # Preguntar cuántos usuarios
    do {
        $inputCantidad = Read-Host "¿Cuántos usuarios deseas crear?"
    } while (-not ($inputCantidad -as [int]) -or [int]$inputCantidad -lt 1)

    $cantidadUsuarios = [int]$inputCantidad

    # Detener Mercury si está abierto
    Stop-Process -Name "Mercury" -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 3

    for ($i = 1; $i -le $cantidadUsuarios; $i++) {
        Write-Host "`n[$i de $cantidadUsuarios] Crear nuevo usuario:"

        # Validar nombre del buzón
        do {
            $newUser = Read-Host "Nombre del buzón (ej. juan)"
            $nombreInvalido = ($newUser -match '[^a-zA-Z0-9_-]') -or ($newUser -eq "")
            $rutaUsuario = "$mailDir\$newUser"
            $usuarioExiste = (Test-Path $rutaUsuario) -or (Select-String -Path $pMailUsrPath -Pattern "^U;$newUser;" -Quiet)

            if ($nombreInvalido) {
                Write-Host "El nombre no puede estar vacío y solo debe contener letras, números, guiones o guiones bajos." -ForegroundColor Yellow
            } elseif ($usuarioExiste) {
                Write-Host "El usuario '$newUser' ya existe." -ForegroundColor Yellow
            }
        } while ($nombreInvalido -or $usuarioExiste)

        # Descripción libre
        $userDescription = Read-Host "Descripción (nombre completo o alias)"

        # Validar contraseña
        do {
            $password = Read-Host "Contraseña para $newUser"
            $passInvalida = ($password -eq "") -or ($password -match "\s")
            if ($passInvalida) {
                Write-Host "La contraseña no puede estar vacía ni contener espacios." -ForegroundColor Yellow
            }
        } while ($passInvalida)

        # Directorio del usuario
        $userDir = "$mailDir\$newUser"

        # 1. Agregar entrada a PMAIL.USR
        Add-Content -Path $pMailUsrPath -Value "U;$newUser;$userDescription"

        # 2. Crear carpeta del usuario si no existe
        if (-not (Test-Path $userDir)) {
            New-Item -Path $userDir -ItemType Directory | Out-Null
        }

        # 3. Crear PASSWD.PM
        $passwdContent = @"
# Mercury/32 User Information File
POP3_access: $password
APOP_secret: $password
"@
        Set-Content -Path "$userDir\PASSWD.PM" -Value $passwdContent -Encoding ASCII

        # 4. Dar permisos NTFS
        icacls $userDir /grant "$env:USERNAME`:(OI)(CI)F" | Out-Null

        Write-Host "Usuario '$newUser' creado correctamente."
    }

    # Reiniciar Mercury
    Start-Process -FilePath $mercuryExe
    Write-Host "`nMercury reiniciado. Todos los usuarios fueron creados correctamente."
}

function instalar_vc_redist {
    Write-Host "`nVerificando Visual C++ Redistributables necesarios..."

    # Verificar VC++ 2012
    $vc2012Instalado = Get-ChildItem "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall" |
                       Get-ItemProperty |
                       Where-Object { $_.DisplayName -match "Visual C\+\+ 2012 Redistributable" }

    if ($vc2012Instalado) {
        Write-Host "Visual C++ 2012 Redistributable ya está instalado."
    } else {
        Write-Host "Falta Visual C++ 2012. Descargando e instalando..."
        $vc2012Url = "https://download.microsoft.com/download/1/6/B/16B06F60-3B20-4FF2-B699-5E9B7962F9AE/VSU_4/vcredist_x64.exe"
        $vc2012Installer = "$env:TEMP\vcredist_x64_2012.exe"

        try {
            Invoke-WebRequest -Uri $vc2012Url -OutFile $vc2012Installer -UseBasicParsing
            Start-Process -FilePath $vc2012Installer -ArgumentList "/install", "/quiet", "/norestart" -NoNewWindow -Wait
            Write-Host "Visual C++ 2012 instalado correctamente."
        } catch {
            Write-Host "Error al instalar Visual C++ 2012." -ForegroundColor Red
        }
    }

    # Verificar VC++ 2015-2022
    $vcInstalled = Get-ChildItem "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall" |
                   Get-ItemProperty |
                   Where-Object { $_.DisplayName -match "Visual C\+\+ (2015|2017|2019|2022) Redistributable" }

    if ($vcInstalled) {
        Write-Host "Visual C++ 2015-2022 Redistributable ya está instalado."
    } else {
        Write-Host "Falta Visual C++ 2015-2022. Descargando e instalando..."
        $vcUrl = "https://aka.ms/vs/17/release/vc_redist.x64.exe"
        $vcInstaller = "$env:TEMP\vc_redist.x64.exe"

        try {
            Invoke-WebRequest -Uri $vcUrl -OutFile $vcInstaller -UseBasicParsing
            Start-Process -FilePath $vcInstaller -ArgumentList "/install", "/quiet", "/norestart" -NoNewWindow -Wait
            Write-Host "Visual C++ 2015-2022 instalado correctamente."
        } catch {
            Write-Host "Error al instalar Visual C++ 2015-2022." -ForegroundColor Red
        }
    }
}

function instalar_apache_smtp {
    $extraerdestino = "C:\Apache24"
    $url = "https://www.apachelounge.com/download/VS17/binaries/httpd-2.4.63-250207-win64-VS17.zip"
    $destino = "$env:USERPROFILE\Downloads\apache.zip"

    Write-Host "Descargando Apache para entorno SMTP..."
    $agente = "Mozilla/5.0 (Windows NT 10.0; Win64; x64)"
    Invoke-WebRequest -Uri $url -OutFile $destino -UserAgent $agente -UseBasicParsing

    Write-Host "Extrayendo Apache en C:\..."
    Expand-Archive -Path $destino -DestinationPath "C:\" -Force
    Remove-Item -Path $destino

    # Aquí puedes modificar el archivo httpd.conf si quisieras ajustar el puerto
    $config = Join-Path $extraerdestino "conf\httpd.conf"

    # Buscar el ejecutable httpd.exe
    $apacheexe = Get-ChildItem -Path $extraerdestino -Recurse -Filter httpd.exe -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($apacheexe) {
        $exeapache = $apacheexe.FullName
        Write-Host "Instalando Apache desde $exeapache"
        Start-Process -FilePath $exeapache -ArgumentList '-k', 'install', '-n', 'Apache24' -NoNewWindow -Wait
        Start-Service -Name "Apache24"
        Write-Host "Apache instalado y ejecutándose."
    } else {
        Write-Host "No se encontró httpd.exe en $extraerdestino"
    }
}

function instalar_php {
    $url = "https://windows.php.net/downloads/releases/archives/php-5.6.9-Win32-VC11-x64.zip"
    $destino = "$env:USERPROFILE\Downloads\php.zip"
    $phpDir = "C:\php"

    if (-not (Test-Path $phpDir)) {
        New-Item -ItemType Directory -Path $phpDir | Out-Null
    }

    Write-Host "Descargando PHP..."
    $agente = "Mozilla/5.0 (Windows NT 10.0; Win64; x64)"
    Invoke-WebRequest -Uri $url -OutFile $destino -UserAgent $agente -UseBasicParsing
    Expand-Archive -Path $destino -DestinationPath $phpDir -Force
    Remove-Item -Path $destino

    # Agregar PHP al PATH del sistema
    $currentPath = [Environment]::GetEnvironmentVariable("PATH", "Machine")
    if (-not ($currentPath -split ';' -contains $phpDir)) {
        [Environment]::SetEnvironmentVariable("PATH", "$currentPath;$phpDir", "Machine")
    }

    # Configurar Apache para PHP
    $apacheConf = @"
LoadModule php5_module "C:/php/php5apache2_4.dll"
AddHandler application/x-httpd-php .php
PHPIniDir "C:/php"
"@
    Add-Content -Path "C:\Apache24\conf\httpd.conf" -Value $apacheConf
    Copy-Item -Path "$phpDir\php.ini-development" -Destination "$phpDir\php.ini" -Force

    Restart-Service -Name "Apache24" -Force
    Write-Host "PHP instalado y configurado."
}

function instalar_squirrelmail {
    param(
        [string]$ip,
        [string]$dominio
    )

    instalar_apache_smtp
    instalar_php

    $Headers = @{
        "Accept" = "text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8"
        "Accept-Language" = "en-US,en;q=0.5"
    }
    $Url = "https://drive.usercontent.google.com/u/0/uc?id=1WDRT2DlR4g64XHuwMfXkj9X-RQAoPPcB&export=download"
    $destino = "$env:USERPROFILE\Downloads\squirrelmail.zip"      
    $rutaDestino = "C:\Apache24\htdocs\squirrelmail"

    if (-not(Test-Path $rutaDestino)){
        $Agente = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36"
        Invoke-WebRequest -Uri $Url -OutFile $destino -MaximumRedirection 10 -UserAgent $Agente -Headers $Headers -UseBasicParsing
        Expand-Archive -Path $destino -DestinationPath "C:\Apache24\htdocs\" -Force
        Rename-Item -Path "C:\Apache24\htdocs\squirrelmail-webmail-1.4.22" -NewName "squirrelmail"

        New-Item -Path "$rutaDestino\config" -name "config.php" -ItemType File

@"

<?php

/**
 * SquirrelMail Configuration File
 * Created using the configure script, conf.pl
 */

global `$version;
`$config_version = '1.4.0';
`$config_use_color = 2;

`$org_name      = "$dominio";
`$org_logo      = SM_PATH . 'images/sm_logo.png';
`$org_logo_width  = '308';
`$org_logo_height = '111';
`$org_title     = "SquirrelMail `$version";
`$signout_page  = '';
`$frame_top     = '_top';

`$provider_uri     = 'http://squirrelmail.org/';

`$provider_name     = 'SquirrelMail';

`$motd = "";

`$squirrelmail_default_language = 'en_US';
`$default_charset       = 'iso-8859-1';
`$lossy_encoding        = false;

`$domain                 = '$dominio';
`$imapServerAddress      = '$ip';
`$imapPort               = 143;
`$useSendmail            = false;
`$smtpServerAddress      = '$ip';
`$smtpPort               = 25;
`$sendmail_path          = '/usr/sbin/sendmail';
`$sendmail_args          = '-i -t';
`$pop_before_smtp        = true;
`$pop_before_smtp_host   = '$ip';
`$imap_server_type       = 'other';
`$invert_time            = false;
`$optional_delimiter     = 'detect';
`$encode_header_key      = '';

`$default_folder_prefix          = '';
`$trash_folder                   = 'INBOX.Trash';
`$sent_folder                    = 'INBOX.Sent';
`$draft_folder                   = 'INBOX.Drafts';
`$default_move_to_trash          = true;
`$default_move_to_sent           = true;
`$default_save_as_draft          = true;
`$show_prefix_option             = false;
`$list_special_folders_first     = true;
`$use_special_folder_color       = true;
`$auto_expunge                   = true;
`$default_sub_of_inbox           = true;
`$show_contain_subfolders_option = false;
`$default_unseen_notify          = 2;
`$default_unseen_type            = 1;
`$auto_create_special            = true;
`$delete_folder                  = false;
`$noselect_fix_enable            = false;

`$data_dir                 = 'C:\Apache24\htdocs\squirrelmail\data';
`$attachment_dir           = 'C:\Apache24\htdocs\squirrelmail\attach';
`$dir_hash_level           = 0;
`$default_left_size        = '150';
`$force_username_lowercase = false;
`$default_use_priority     = true;
`$hide_sm_attributions     = false;
`$default_use_mdn          = true;
`$edit_identity            = true;
`$edit_name                = true;
`$hide_auth_header         = false;
`$allow_thread_sort        = false;
`$allow_server_sort        = false;
`$allow_charset_search     = true;
`$uid_support              = true;


`$theme_css = '';
`$theme_default = 0;
`$theme[0]['PATH'] = SM_PATH . 'themes/default_theme.php';
`$theme[0]['NAME'] = 'Default';
`$theme[1]['PATH'] = SM_PATH . 'themes/plain_blue_theme.php';
`$theme[1]['NAME'] = 'Plain Blue';
`$theme[2]['PATH'] = SM_PATH . 'themes/sandstorm_theme.php';
`$theme[2]['NAME'] = 'Sand Storm';
`$theme[3]['PATH'] = SM_PATH . 'themes/deepocean_theme.php';
`$theme[3]['NAME'] = 'Deep Ocean';
`$theme[4]['PATH'] = SM_PATH . 'themes/slashdot_theme.php';
`$theme[4]['NAME'] = 'Slashdot';
`$theme[5]['PATH'] = SM_PATH . 'themes/purple_theme.php';
`$theme[5]['NAME'] = 'Purple';
`$theme[6]['PATH'] = SM_PATH . 'themes/forest_theme.php';
`$theme[6]['NAME'] = 'Forest';
`$theme[7]['PATH'] = SM_PATH . 'themes/ice_theme.php';
`$theme[7]['NAME'] = 'Ice';
`$theme[8]['PATH'] = SM_PATH . 'themes/seaspray_theme.php';
`$theme[8]['NAME'] = 'Sea Spray';
`$theme[9]['PATH'] = SM_PATH . 'themes/bluesteel_theme.php';
`$theme[9]['NAME'] = 'Blue Steel';
`$theme[10]['PATH'] = SM_PATH . 'themes/dark_grey_theme.php';
`$theme[10]['NAME'] = 'Dark Grey';
`$theme[11]['PATH'] = SM_PATH . 'themes/high_contrast_theme.php';
`$theme[11]['NAME'] = 'High Contrast';
`$theme[12]['PATH'] = SM_PATH . 'themes/black_bean_burrito_theme.php';
`$theme[12]['NAME'] = 'Black Bean Burrito';
`$theme[13]['PATH'] = SM_PATH . 'themes/servery_theme.php';
`$theme[13]['NAME'] = 'Servery';
`$theme[14]['PATH'] = SM_PATH . 'themes/maize_theme.php';
`$theme[14]['NAME'] = 'Maize';
`$theme[15]['PATH'] = SM_PATH . 'themes/bluesnews_theme.php';
`$theme[15]['NAME'] = 'BluesNews';
`$theme[16]['PATH'] = SM_PATH . 'themes/deepocean2_theme.php';
`$theme[16]['NAME'] = 'Deep Ocean 2';
`$theme[17]['PATH'] = SM_PATH . 'themes/blue_grey_theme.php';
`$theme[17]['NAME'] = 'Blue Grey';
`$theme[18]['PATH'] = SM_PATH . 'themes/dompie_theme.php';
`$theme[18]['NAME'] = 'Dompie';
`$theme[19]['PATH'] = SM_PATH . 'themes/methodical_theme.php';
`$theme[19]['NAME'] = 'Methodical';
`$theme[20]['PATH'] = SM_PATH . 'themes/greenhouse_effect.php';
`$theme[20]['NAME'] = 'Greenhouse Effect (Changes)';
`$theme[21]['PATH'] = SM_PATH . 'themes/in_the_pink.php';
`$theme[21]['NAME'] = 'In The Pink (Changes)';
`$theme[22]['PATH'] = SM_PATH . 'themes/kind_of_blue.php';
`$theme[22]['NAME'] = 'Kind of Blue (Changes)';
`$theme[23]['PATH'] = SM_PATH . 'themes/monostochastic.php';
`$theme[23]['NAME'] = 'Monostochastic (Changes)';
`$theme[24]['PATH'] = SM_PATH . 'themes/shades_of_grey.php';
`$theme[24]['NAME'] = 'Shades of Grey (Changes)';
`$theme[25]['PATH'] = SM_PATH . 'themes/spice_of_life.php';
`$theme[25]['NAME'] = 'Spice of Life (Changes)';
`$theme[26]['PATH'] = SM_PATH . 'themes/spice_of_life_lite.php';
`$theme[26]['NAME'] = 'Spice of Life - Lite (Changes)';
`$theme[27]['PATH'] = SM_PATH . 'themes/spice_of_life_dark.php';
`$theme[27]['NAME'] = 'Spice of Life - Dark (Changes)';
`$theme[28]['PATH'] = SM_PATH . 'themes/christmas.php';
`$theme[28]['NAME'] = 'Holiday - Christmas';
`$theme[29]['PATH'] = SM_PATH . 'themes/darkness.php';
`$theme[29]['NAME'] = 'Darkness (Changes)';
`$theme[30]['PATH'] = SM_PATH . 'themes/random.php';
`$theme[30]['NAME'] = 'Random (Changes every login)';
`$theme[31]['PATH'] = SM_PATH . 'themes/midnight.php';
`$theme[31]['NAME'] = 'Midnight';
`$theme[32]['PATH'] = SM_PATH . 'themes/alien_glow.php';
`$theme[32]['NAME'] = 'Alien Glow';
`$theme[33]['PATH'] = SM_PATH . 'themes/dark_green.php';
`$theme[33]['NAME'] = 'Dark Green';
`$theme[34]['PATH'] = SM_PATH . 'themes/penguin.php';
`$theme[34]['NAME'] = 'Penguin';
`$theme[35]['PATH'] = SM_PATH . 'themes/minimal_bw.php';
`$theme[35]['NAME'] = 'Minimal BW';
`$theme[36]['PATH'] = SM_PATH . 'themes/redmond.php';
`$theme[36]['NAME'] = 'Redmond';
`$theme[37]['PATH'] = SM_PATH . 'themes/netstyle_theme.php';
`$theme[37]['NAME'] = 'Net Style';
`$theme[38]['PATH'] = SM_PATH . 'themes/silver_steel_theme.php';
`$theme[38]['NAME'] = 'Silver Steel';
`$theme[39]['PATH'] = SM_PATH . 'themes/simple_green_theme.php';
`$theme[39]['NAME'] = 'Simple Green';
`$theme[40]['PATH'] = SM_PATH . 'themes/wood_theme.php';
`$theme[40]['NAME'] = 'Wood';
`$theme[41]['PATH'] = SM_PATH . 'themes/bluesome.php';
`$theme[41]['NAME'] = 'Bluesome';
`$theme[42]['PATH'] = SM_PATH . 'themes/simple_green2.php';
`$theme[42]['NAME'] = 'Simple Green 2';
`$theme[43]['PATH'] = SM_PATH . 'themes/simple_purple.php';
`$theme[43]['NAME'] = 'Simple Purple';
`$theme[44]['PATH'] = SM_PATH . 'themes/autumn.php';
`$theme[44]['NAME'] = 'Autumn';
`$theme[45]['PATH'] = SM_PATH . 'themes/autumn2.php';
`$theme[45]['NAME'] = 'Autumn 2';
`$theme[46]['PATH'] = SM_PATH . 'themes/blue_on_blue.php';
`$theme[46]['NAME'] = 'Blue on Blue';
`$theme[47]['PATH'] = SM_PATH . 'themes/classic_blue.php';
`$theme[47]['NAME'] = 'Classic Blue';
`$theme[48]['PATH'] = SM_PATH . 'themes/classic_blue2.php';
`$theme[48]['NAME'] = 'Classic Blue 2';
`$theme[49]['PATH'] = SM_PATH . 'themes/powder_blue.php';
`$theme[49]['NAME'] = 'Powder Blue';
`$theme[50]['PATH'] = SM_PATH . 'themes/techno_blue.php';
`$theme[50]['NAME'] = 'Techno Blue';
`$theme[51]['PATH'] = SM_PATH . 'themes/turquoise.php';
`$theme[51]['NAME'] = 'Turquoise';

`$default_use_javascript_addr_book = false;
`$abook_global_file = '';
`$abook_global_file_writeable = false;
`$abook_global_file_listing = true;
`$abook_file_line_length = 2048;

`$addrbook_dsn = '';
`$addrbook_table = 'address';

`$prefs_dsn = '';
`$prefs_table = 'userprefs';
`$prefs_user_field = 'user';
`$prefs_key_field = 'prefkey';
`$prefs_val_field = 'prefval';
`$addrbook_global_dsn = '';
`$addrbook_global_table = 'global_abook';
`$addrbook_global_writeable = false;
`$addrbook_global_listing = false;

`$no_list_for_subscribe = false;
`$smtp_auth_mech = 'none';
`$imap_auth_mech = 'login';
`$smtp_sitewide_user = '';
`$smtp_sitewide_pass = '';
`$use_imap_tls = false;
`$use_smtp_tls = false;
`$session_name = 'SQMSESSID';
`$only_secure_cookies     = true;
`$disable_security_tokens = false;
`$check_referrer          = '';

`$config_location_base    = '';

@include SM_PATH . 'C:\Apache24\htdocs\squirrelmail\config\config_local.php';
?>
"@ | Out-File -FilePath "$rutaDestino\config\config.php" -Encoding UTF8

        icacls "$rutaDestino\data" /grant "IUSR:(OI)(CI)(M)"
        icacls "$rutaDestino\data" /grant "IIS_IUSRS:(OI)(CI)(M)"
        New-Item -ItemType Directory -Path "$rutaDestino" -Name "attach" -Force | Out-Null
        icacls "$rutaDestino\attach" /grant "IUSR:(OI)(CI)(M)"
        icacls "$rutaDestino\attach" /grant "IIS_IUSRS:(OI)(CI)(M)"
    }
}

function instalar_dns_local {
    # Obtener dominio desde variable global
    if (-not $global:dominio) {
        Write-Host "No se ha definido el dominio en una variable global (`$global:dominio)." -ForegroundColor Red
        return
    }

    # Obtener la IP automáticamente
    $ip = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object {
        $_.InterfaceAlias -notlike "*Loopback*" -and $_.PrefixOrigin -ne "WellKnown"
    }).IPAddress | Select-Object -First 1

    if (-not $ip) {
        Write-Host "No se pudo obtener una dirección IP válida." -ForegroundColor Red
        return
    }

    Write-Host "Instalando características DNS..."
    Install-WindowsFeature -Name DNS
    Install-WindowsFeature -Name RSAT-DNS-Server

    Write-Host "Configurando zona DNS para $global:dominio con IP $ip..."

    # Crear zona primaria
    Add-DnsServerPrimaryZone -Name $global:dominio -ZoneFile "$($global:dominio).dns"

    # Registros A y MX
    Add-DnsServerResourceRecordA -Name "@" -ZoneName $global:dominio -IPv4Address $ip
    Add-DnsServerResourceRecordA -Name "mail" -ZoneName $global:dominio -IPv4Address $ip
    Add-DnsServerResourceRecordMX -Name "@" -ZoneName $global:dominio -MailExchange "mail.$global:dominio" -Preference 10

    # Registros SRV
    Add-DnsServerResourceRecord -Srv -Name "_smtp._tcp" -ZoneName $global:dominio -DomainName "mail.$global:dominio" -Priority 0 -Weight 5 -Port 25
    Add-DnsServerResourceRecord -Srv -Name "_pop3._tcp" -ZoneName $global:dominio -DomainName "mail.$global:dominio" -Priority 0 -Weight 5 -Port 110

    Restart-Service -Name DNS

    Write-Host "Zona DNS '$global:dominio' configurada correctamente."
}

function configurar_firewall_mail {
    Write-Host "Configurando reglas clásicas del firewall para servicios web y DNS..."

    # HTTP (80)
    New-NetFirewallRule -DisplayName "HTTP (80)" -Direction Inbound -Protocol TCP -LocalPort 80 -Action Allow

    # DNS (53)
    New-NetFirewallRule -DisplayName "DNS (53)" -Direction Inbound -Protocol TCP -LocalPort 53 -Action Allow

    # SMTP Submission (587)
    New-NetFirewallRule -DisplayName "SMTP (587)" -Direction Inbound -Protocol TCP -LocalPort 587 -Action Allow

    Write-Host "Reglas de firewall configuradas correctamente (sin incluir puertos Mercury)."
}

# 1. Si es la primera vez, instalar y configurar todo
if (-not (Test-Path "C:\Mercury\MERCURY.INI")) {
    Write-Host "Primera vez: se instalará y configurará Mercury/32."

    # Instalación base
    descargar_archivo_zip
    extraer_archivo_zip
    obtener_dominio
    generar_archivo_ini
    configurar_firewall_mercury

    # Crear usuarios justo después de configurar Mercury
    crear_usuarios_mercury

    # Instalar lo demás (resto del stack)
    instalar_vc_redist

    # Obtener IP antes de instalar SquirrelMail
    $ipActual = (Get-NetIPAddress -AddressFamily IPv4 |
                 Where-Object { $_.InterfaceAlias -notlike "*Loopback*" -and $_.PrefixOrigin -ne "WellKnown" }).IPAddress | Select-Object -First 1

    instalar_squirrelmail -ip $ipActual -dominio $global:dominio
    instalar_dns_local
    configurar_firewall_mail
}
else {
    Write-Host "Mercury ya está instalado. Omitiendo descarga y configuración inicial."

    # Si no es la primera vez, solo permitimos crear nuevos usuarios
    crear_usuarios_mercury
}
