#!/bin/bash

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

# Crea usuarios
read -p "Ingrese el número de usuarios que desea crear: " numeroUsuarios
for ((i = 1; i <= numeroUsuarios; i++)); do
    read -p "Ingrese el nombre de usuario $i: " nombreUsuario
    sudo adduser "${nombreUsuario}"
    sudo mkdir -p /home/${nombreUsuario}/Maildir/{new,cur,tmp}
    sudo chown -R ${nombreUsuario}:${nombreUsuario} /home/${nombreUsuario}/Maildir
done

# Instala cliente BSD Mailx (opcional para pruebas en terminal)
sudo apt-get install bsd-mailx -y

# Instala Dovecot para POP3 e IMAP
sudo apt-get install dovecot-pop3d dovecot-imapd -y

# Muestra configuración de red
ip a

# Configura subred permitida en Postfix
echo 'Ingrese la familia de la subred (ej. 192.168.10.0):'
read SubnetIP
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
echo "reprobados.com   IN  MX  10  correo.reprobados.com." | sudo tee -a /etc/bind/zonas/db.reprobados.com
echo "pop3 IN  CNAME   servidor" | sudo tee -a /etc/bind/zonas/db.reprobados.com
echo "smtp IN  CNAME   servidor" | sudo tee -a /etc/bind/zonas/db.reprobados.com
echo "correo  IN   CNAME   servidor" | sudo tee -a /etc/bind/zonas/db.reprobados.com
sudo systemctl restart bind9

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

# Cambiar dominio en el archivo de configuración
sudo sed -i "s/^\$domain.*/\$domain = 'reprobados.com';/" /usr/share/squirrelmail/config/config.php

# Abre puertos si UFW está habilitado
sudo ufw allow 25/tcp    # SMTP
sudo ufw allow 110/tcp   # POP3
sudo ufw allow 143/tcp   # IMAP
sudo ufw allow 80/tcp    # HTTP

echo ""
echo "INSTALACIÓN COMPLETA."
echo "Accede a SquirrelMail en:"
echo "http://$(hostname -I | awk '{print $1}')/squirrelmail"
