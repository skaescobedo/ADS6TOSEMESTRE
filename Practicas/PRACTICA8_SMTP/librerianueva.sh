#!/bin/bash

# Función para validar el nombre de usuario
validar_nombre_usuario() {
    nombre_usuario=$1

    # Verificar que no esté vacío
    if [[ -z "$nombre_usuario" ]]; then
        echo "El nombre de usuario está vacío."
        return 1
    fi

    # Verificar longitud máxima
    if [[ ${#nombre_usuario} -gt 32 ]]; then
        echo "El nombre de usuario es demasiado largo (máximo 32 caracteres)."
        return 1
    fi

    # Verificar que no empiece con un número
    if [[ "$nombre_usuario" =~ ^[0-9] ]]; then
        echo "El nombre de usuario no puede comenzar con un número."
        return 1
    fi

    # Verificar que no empiece con un guion
    if [[ "$nombre_usuario" =~ ^- ]]; then
        echo "El nombre de usuario no puede comenzar con un guion ('-')."
        return 1
    fi

    # Verificar que no empiece con un punto
    if [[ "$nombre_usuario" =~ ^\. ]]; then
        echo "El nombre de usuario no puede comenzar con un punto ('.')."
        return 1
    fi

    # Verificar caracteres permitidos (solo letras, números, guion bajo, guion, y punto en medio o al final)
    if [[ "$nombre_usuario" =~ [^a-zA-Z0-9._-] ]]; then
        echo "El nombre de usuario contiene caracteres no permitidos."
        return 1
    fi

    # Verificar que no contenga espacios
    if [[ "$nombre_usuario" =~ [[:space:]] ]]; then
        echo "El nombre de usuario no puede contener espacios."
        return 1
    fi

    # Verificar que no sea un nombre reservado
    nombres_reservados=("root" "admin" "bin" "daemon" "www-data" "ftp" "syslog" "messagebus")
    for nombre_reservado in "${nombres_reservados[@]}"; do
        if [[ "$nombre_usuario" == "$nombre_reservado" ]]; then
            echo "El nombre de usuario '$nombre_usuario' es un nombre reservado del sistema."
            return 1
        fi
    done

    # Verificar si el nombre de usuario ya existe
    if getent passwd "$nombre_usuario" > /dev/null 2>&1; then
        echo "El nombre de usuario '$nombre_usuario' ya existe en el sistema."
        return 1
    fi

    echo "El nombre de usuario '$nombre_usuario' es válido."
    return 0
}

validar_contraseña() {
    local password1 password2

    while true; do
        echo "Ingrese la contraseña para el usuario $username (máximo 20 caracteres):"
        read password1
        echo "Confirme la contraseña:"
        read password2

        if [ -z "$password1" ]; then
            echo "La contraseña no puede estar vacía. Intente de nuevo."
            continue
        fi

        if [ "$password1" != "$password2" ]; then
            echo "Las contraseñas no coinciden. Intente de nuevo."
            continue
        fi

        if [ ${#password1} -gt 20 ]; then
            echo "La contraseña es demasiado larga (máximo 20 caracteres). Intente de nuevo."
            continue
        fi

        # Si pasa todas las validaciones, retornamos la contraseña
        CONTRASENA_VALIDADA="$password1"
        return 0
    done
}

# Establece el nombre de host del sistema
sudo hostnamectl set-hostname reprobados.com

# Actualiza la lista de paquetes
sudo apt-get update -y

# Agrega repositorio para PHP 7.4 (si no está disponible)
sudo add-apt-repository ppa:ondrej/php -y
sudo apt-get update -y

# Instala PHP 7.4 y módulos necesarios
sudo apt-get install php7.4 php7.4-cli php7.4-common php7.4-imap php7.4-mbstring php7.4-xml php7.4-cgi php7.4-mysql libapache2-mod-php7.4 -y

# Instala Apache2
sudo apt-get install apache2 -y

# Configura PHP 7.4 como predeterminado en Apache
sudo a2dismod php8.1 2>/dev/null
sudo a2enmod php7.4
sudo update-alternatives --set php /usr/bin/php7.4
sudo systemctl restart apache2

# Instala Postfix (SMTP)
sudo apt-get install postfix -y

# Muestra el nombre de correo del sistema
cat /etc/mailname

# Crea usuarios con validación
read -p "Ingrese el número de usuarios que desea crear: " numeroUsuarios

for ((i = 1; i <= numeroUsuarios; i++)); do
    # Validar nombre de usuario
    while true; do
        read -p "Ingrese el nombre de usuario $i: " username
        validar_nombre_usuario "$username"
        if [ $? -eq 0 ]; then
            break
        fi
    done

    # Validar contraseña
    validar_contraseña  # Usa directamente $username internamente

    # Crear usuario sin contraseña interactiva
    sudo adduser --quiet --disabled-password --gecos "" "$username"

    # Asignar contraseña
    echo "$username:$CONTRASENA_VALIDADA" | sudo chpasswd

    # Crear estructura Maildir
    sudo mkdir -p /home/${username}/Maildir/{new,cur,tmp}
    sudo chown -R ${username}:${username} /home/${username}/Maildir
done


# Instala cliente BSD Mailx (opcional para pruebas en terminal)
sudo apt-get install bsd-mailx -y

# Instala Dovecot para POP3 e IMAP
sudo apt-get install dovecot-pop3d dovecot-imapd -y

# Muestra configuración de red
ip a

# Configura subred permitida en Postfix automáticamente
SubnetIP=$(ip -o -f inet addr show enp0s3 | awk '{print $4}' | cut -d'/' -f1 | awk -F. '{print $1"."$2"."$3".0"}')
sudo sed -i "s/^mynetworks = .*/mynetworks = 127.0.0.0\/8 [::ffff:127.0.0.0]\/104 [::1]\/128 ${SubnetIP}\/24/" /etc/postfix/main.cf

# Entrega de correo en formato Maildir
echo "home_mailbox = Maildir/" | sudo tee -a /etc/postfix/main.cf
echo "mailbox_command =" | sudo tee -a /etc/postfix/main.cf

# Reinicia Postfix
sudo systemctl reload postfix
sudo systemctl restart postfix

# Habilita autenticación en texto plano en Dovecot (solo para pruebas internas)
sudo sed -i 's/^#disable_plaintext_auth = yes/disable_plaintext_auth = no/' /etc/dovecot/conf.d/10-auth.conf

# Configura almacenamiento Maildir
sudo sed -i 's/^#   mail_location = maildir:~\/Maildir/    mail_location = maildir:~\/Maildir/' /etc/dovecot/conf.d/10-mail.conf
sudo sed -i 's/^mail_location = mbox:~\/mail:INBOX=\/var\/mail\/%u/#mail_location = mbox:~\/mail:INBOX=\/var\/mail\/%u/' /etc/dovecot/conf.d/10-mail.conf

# Configura integración Dovecot-SASL para Postfix (envío autenticado)
sudo sed -i '/^smtpd_sasl_auth_enable/ d' /etc/postfix/main.cf
echo "smtpd_sasl_auth_enable = yes" | sudo tee -a /etc/postfix/main.cf
echo "smtpd_sasl_type = dovecot" | sudo tee -a /etc/postfix/main.cf
echo "smtpd_sasl_path = private/auth" | sudo tee -a /etc/postfix/main.cf
echo "smtpd_tls_auth_only = no" | sudo tee -a /etc/postfix/main.cf
echo "smtpd_recipient_restrictions = permit_sasl_authenticated, permit_mynetworks, reject_unauth_destination" | sudo tee -a /etc/postfix/main.cf

# Configura el socket de autenticación en Dovecot
sudo sed -i '/service auth {/,/^}/d' /etc/dovecot/conf.d/10-master.conf
echo "service auth {
  unix_listener /var/spool/postfix/private/auth {
    mode = 0660
    user = postfix
    group = postfix
  }

  unix_listener auth-userdb {
    #mode = 0666
    #user =
    #group =
  }
}

service auth-worker {
}" | sudo tee -a /etc/dovecot/conf.d/10-master.conf

# Reinicia Dovecot y Postfix
sudo systemctl restart dovecot
sudo systemctl restart postfix

# Registros DNS (si tienes bind9)
#echo "reprobados.com   IN  MX  10  correo.reprobados.com." | sudo tee -a /etc/bind/zonas/db.reprobados.com
#echo "pop3 IN  CNAME   servidor" | sudo tee -a /etc/bind/zonas/db.reprobados.com
#echo "smtp IN  CNAME   servidor" | sudo tee -a /etc/bind/zonas/db.reprobados.com
#echo "correo  IN   CNAME   servidor" | sudo tee -a /etc/bind/zonas/db.reprobados.com
#sudo systemctl restart bind9

# INSTALACIÓN MANUAL DE SQUIRRELMAIL
cd /usr/share
sudo wget -O squirrelmail-webmail-1.4.22.tar.gz "https://www.squirrelmail.org/countdl.php?fileurl=http%3A%2F%2Fprdownloads.sourceforge.net%2Fsquirrelmail%2Fsquirrelmail-webmail-1.4.22.tar.gz"
sudo tar -xzvf squirrelmail-webmail-1.4.22.tar.gz
sudo mv squirrelmail-webmail-1.4.22 squirrelmail
sudo chown -R www-data:www-data /usr/share/squirrelmail
sudo chmod -R 755 /usr/share/squirrelmail

# Crear enlace simbólico para Apache
sudo ln -s /usr/share/squirrelmail /var/www/html/squirrelmail

# Configura Apache para permitir acceso a SquirrelMail
echo "<Directory /usr/share/squirrelmail>
    Options Indexes FollowSymLinks
    AllowOverride All
    Require all granted
</Directory>" | sudo tee /etc/apache2/conf-available/squirrelmail.conf

sudo a2enconf squirrelmail
sudo systemctl restart apache2

# Crear carpeta de preferencias de usuarios
sudo mkdir -p /var/local/squirrelmail/data/
sudo chown -R www-data:www-data /var/local/squirrelmail/data/
sudo chmod -R 730 /var/local/squirrelmail/data/

# Ruta del archivo de configuración
CONFIG_PATH="/usr/share/squirrelmail/config/config.php"

# Crear archivo con el contenido completo
sudo tee "$CONFIG_PATH" > /dev/null << 'EOF'
<?php

/**
 * SquirrelMail Configuration File
 * Created using the configure script, conf.pl
 */

global $version;
$config_version = '1.4.0';
$config_use_color = 2;

$org_name      = "SquirrelMail";
$org_logo      = SM_PATH . 'images/sm_logo.png';
$org_logo_width  = '308';
$org_logo_height = '111';
$org_title     = "SquirrelMail $version";
$signout_page  = '';
$frame_top     = '_top';

$provider_uri     = 'http://squirrelmail.org/';
$provider_name     = 'SquirrelMail';

$motd = "";

$squirrelmail_default_language = 'en_US';
$default_charset       = 'iso-8859-1';
$lossy_encoding        = false;

$domain                 = 'reprobados.com';
$imapServerAddress      = 'localhost';
$imapPort               = 143;
$useSendmail            = false;
$smtpServerAddress      = 'localhost';
$smtpPort               = 25;
$sendmail_path          = '/usr/sbin/sendmail';
$sendmail_args          = '-i -t';
$pop_before_smtp        = false;
$pop_before_smtp_host   = '';
$imap_server_type       = 'other';
$invert_time            = false;
$optional_delimiter     = 'detect';
$encode_header_key      = '';

$default_folder_prefix          = '';
$trash_folder                   = 'INBOX.Trash';
$sent_folder                    = 'INBOX.Sent';
$draft_folder                   = 'INBOX.Drafts';
$default_move_to_trash          = true;
$default_move_to_sent           = true;
$default_save_as_draft          = true;
$show_prefix_option             = false;
$list_special_folders_first     = true;
$use_special_folder_color       = true;
$auto_expunge                   = true;
$default_sub_of_inbox           = true;
$show_contain_subfolders_option = false;
$default_unseen_notify          = 2;
$default_unseen_type            = 1;
$auto_create_special            = true;
$delete_folder                  = false;
$noselect_fix_enable            = false;

$data_dir                 = '/var/local/squirrelmail/data/';
$attachment_dir           = '/var/local/squirrelmail/attach/';
$dir_hash_level           = 0;
$default_left_size        = '150';
$force_username_lowercase = false;
$default_use_priority     = true;
$hide_sm_attributions     = false;
$default_use_mdn          = true;
$edit_identity            = true;
$edit_name                = true;
$hide_auth_header         = false;
$allow_thread_sort        = false;
$allow_server_sort        = false;
$allow_charset_search     = true;
$uid_support              = true;

$theme_css = '';
$theme_default = 0;
$theme[0]['PATH'] = SM_PATH . 'themes/default_theme.php';
$theme[0]['NAME'] = 'Default';
$theme[1]['PATH'] = SM_PATH . 'themes/plain_blue_theme.php';
$theme[1]['NAME'] = 'Plain Blue';
$theme[2]['PATH'] = SM_PATH . 'themes/sandstorm_theme.php';
$theme[2]['NAME'] = 'Sand Storm';
$theme[3]['PATH'] = SM_PATH . 'themes/deepocean_theme.php';
$theme[3]['NAME'] = 'Deep Ocean';
$theme[4]['PATH'] = SM_PATH . 'themes/slashdot_theme.php';
$theme[4]['NAME'] = 'Slashdot';
$theme[5]['PATH'] = SM_PATH . 'themes/purple_theme.php';
$theme[5]['NAME'] = 'Purple';
$theme[6]['PATH'] = SM_PATH . 'themes/forest_theme.php';
$theme[6]['NAME'] = 'Forest';
$theme[7]['PATH'] = SM_PATH . 'themes/ice_theme.php';
$theme[7]['NAME'] = 'Ice';
$theme[8]['PATH'] = SM_PATH . 'themes/seaspray_theme.php';
$theme[8]['NAME'] = 'Sea Spray';
$theme[9]['PATH'] = SM_PATH . 'themes/bluesteel_theme.php';
$theme[9]['NAME'] = 'Blue Steel';
$theme[10]['PATH'] = SM_PATH . 'themes/dark_grey_theme.php';
$theme[10]['NAME'] = 'Dark Grey';
$theme[11]['PATH'] = SM_PATH . 'themes/high_contrast_theme.php';
$theme[11]['NAME'] = 'High Contrast';
$theme[12]['PATH'] = SM_PATH . 'themes/black_bean_burrito_theme.php';
$theme[12]['NAME'] = 'Black Bean Burrito';
$theme[13]['PATH'] = SM_PATH . 'themes/servery_theme.php';
$theme[13]['NAME'] = 'Servery';
$theme[14]['PATH'] = SM_PATH . 'themes/maize_theme.php';
$theme[14]['NAME'] = 'Maize';
$theme[15]['PATH'] = SM_PATH . 'themes/bluesnews_theme.php';
$theme[15]['NAME'] = 'BluesNews';
$theme[16]['PATH'] = SM_PATH . 'themes/deepocean2_theme.php';
$theme[16]['NAME'] = 'Deep Ocean 2';
$theme[17]['PATH'] = SM_PATH . 'themes/blue_grey_theme.php';
$theme[17]['NAME'] = 'Blue Grey';
$theme[18]['PATH'] = SM_PATH . 'themes/dompie_theme.php';
$theme[18]['NAME'] = 'Dompie';
$theme[19]['PATH'] = SM_PATH . 'themes/methodical_theme.php';
$theme[19]['NAME'] = 'Methodical';
$theme[20]['PATH'] = SM_PATH . 'themes/greenhouse_effect.php';
$theme[20]['NAME'] = 'Greenhouse Effect (Changes)';
$theme[21]['PATH'] = SM_PATH . 'themes/in_the_pink.php';
$theme[21]['NAME'] = 'In The Pink (Changes)';
$theme[22]['PATH'] = SM_PATH . 'themes/kind_of_blue.php';
$theme[22]['NAME'] = 'Kind of Blue (Changes)';
$theme[23]['PATH'] = SM_PATH . 'themes/monostochastic.php';
$theme[23]['NAME'] = 'Monostochastic (Changes)';
$theme[24]['PATH'] = SM_PATH . 'themes/shades_of_grey.php';
$theme[24]['NAME'] = 'Shades of Grey (Changes)';
$theme[25]['PATH'] = SM_PATH . 'themes/spice_of_life.php';
$theme[25]['NAME'] = 'Spice of Life (Changes)';
$theme[26]['PATH'] = SM_PATH . 'themes/spice_of_life_lite.php';
$theme[26]['NAME'] = 'Spice of Life - Lite (Changes)';
$theme[27]['PATH'] = SM_PATH . 'themes/spice_of_life_dark.php';
$theme[27]['NAME'] = 'Spice of Life - Dark (Changes)';
$theme[28]['PATH'] = SM_PATH . 'themes/christmas.php';
$theme[28]['NAME'] = 'Holiday - Christmas';
$theme[29]['PATH'] = SM_PATH . 'themes/darkness.php';
$theme[29]['NAME'] = 'Darkness (Changes)';
$theme[30]['PATH'] = SM_PATH . 'themes/random.php';
$theme[30]['NAME'] = 'Random (Changes every login)';
$theme[31]['PATH'] = SM_PATH . 'themes/midnight.php';
$theme[31]['NAME'] = 'Midnight';
$theme[32]['PATH'] = SM_PATH . 'themes/alien_glow.php';
$theme[32]['NAME'] = 'Alien Glow';
$theme[33]['PATH'] = SM_PATH . 'themes/dark_green.php';
$theme[33]['NAME'] = 'Dark Green';
$theme[34]['PATH'] = SM_PATH . 'themes/penguin.php';
$theme[34]['NAME'] = 'Penguin';
$theme[35]['PATH'] = SM_PATH . 'themes/minimal_bw.php';
$theme[35]['NAME'] = 'Minimal BW';
$theme[36]['PATH'] = SM_PATH . 'themes/redmond.php';
$theme[36]['NAME'] = 'Redmond';
$theme[37]['PATH'] = SM_PATH . 'themes/netstyle_theme.php';
$theme[37]['NAME'] = 'Net Style';
$theme[38]['PATH'] = SM_PATH . 'themes/silver_steel_theme.php';
$theme[38]['NAME'] = 'Silver Steel';
$theme[39]['PATH'] = SM_PATH . 'themes/simple_green_theme.php';
$theme[39]['NAME'] = 'Simple Green';
$theme[40]['PATH'] = SM_PATH . 'themes/wood_theme.php';
$theme[40]['NAME'] = 'Wood';
$theme[41]['PATH'] = SM_PATH . 'themes/bluesome.php';
$theme[41]['NAME'] = 'Bluesome';
$theme[42]['PATH'] = SM_PATH . 'themes/simple_green2.php';
$theme[42]['NAME'] = 'Simple Green 2';
$theme[43]['PATH'] = SM_PATH . 'themes/simple_purple.php';
$theme[43]['NAME'] = 'Simple Purple';
$theme[44]['PATH'] = SM_PATH . 'themes/autumn.php';
$theme[44]['NAME'] = 'Autumn';
$theme[45]['PATH'] = SM_PATH . 'themes/autumn2.php';
$theme[45]['NAME'] = 'Autumn 2';
$theme[46]['PATH'] = SM_PATH . 'themes/blue_on_blue.php';
$theme[46]['NAME'] = 'Blue on Blue';
$theme[47]['PATH'] = SM_PATH . 'themes/classic_blue.php';
$theme[47]['NAME'] = 'Classic Blue';
$theme[48]['PATH'] = SM_PATH . 'themes/classic_blue2.php';
$theme[48]['NAME'] = 'Classic Blue 2';
$theme[49]['PATH'] = SM_PATH . 'themes/powder_blue.php';
$theme[49]['NAME'] = 'Powder Blue';
$theme[50]['PATH'] = SM_PATH . 'themes/techno_blue.php';
$theme[50]['NAME'] = 'Techno Blue';
$theme[51]['PATH'] = SM_PATH . 'themes/turquoise.php';
$theme[51]['NAME'] = 'Turquoise';

$default_use_javascript_addr_book = false;
$abook_global_file = '';
$abook_global_file_writeable = false;
$abook_global_file_listing = true;
$abook_file_line_length = 2048;

$addrbook_dsn = '';
$addrbook_table = 'address';

$prefs_dsn = '';
$prefs_table = 'userprefs';
$prefs_user_field = 'user';
$prefs_key_field = 'prefkey';
$prefs_val_field = 'prefval';
$addrbook_global_dsn = '';
$addrbook_global_table = 'global_abook';
$addrbook_global_writeable = false;
$addrbook_global_listing = false;

$no_list_for_subscribe = false;
$smtp_auth_mech = 'none';
$imap_auth_mech = 'login';
$smtp_sitewide_user = '';
$smtp_sitewide_pass = '';
$use_imap_tls = false;
$use_smtp_tls = false;
$session_name = 'SQMSESSID';
$only_secure_cookies     = true;
$disable_security_tokens = false;
$check_referrer          = '';

$config_location_base    = '';

@include SM_PATH . 'config/config_local.php';
EOF

echo "Archivo $CONFIG_PATH creado correctamente."

# Abre puertos si UFW está habilitado
sudo ufw allow 25/tcp    # SMTP
sudo ufw allow 110/tcp   # POP3
sudo ufw allow 143/tcp   # IMAP
sudo ufw allow 80/tcp    # HTTP

echo ""
echo "INSTALACIÓN COMPLETA."
echo "Accede a SquirrelMail en:"
echo "http://$(hostname -I | awk '{print $1}')/squirrelmail"


