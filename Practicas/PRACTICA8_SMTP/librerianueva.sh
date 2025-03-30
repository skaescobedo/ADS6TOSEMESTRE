#!/bin/bash

# Establece el nombre de host del sistema
sudo hostnamectl set-hostname reprobados.com

# Actualiza la lista de paquetes
sudo apt-get update -y

# Instala Postfix (SMTP)
sudo apt-get install postfix -y

# Instala Apache2 (necesario para SquirrelMail)
sudo apt-get install apache2 -y

# Muestra el nombre de correo del sistema
cat /etc/mailname

# Crea usuarios
read -p "Ingrese el número de usuarios que desea crear: " numeroUsuarios
for ((i = 1; i <= numeroUsuarios; i++)); do
    read -p "Ingrese el nombre de usuario $i: " nombreUsuario
    sudo adduser "${nombreUsuario}"
    sudo su - "${nombreUsuario}" -c "maildirmake Maildir"
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
sudo sed -i '/unix_listener \/var\/spool\/postfix\/private\/auth/,/^}/d' /etc/dovecot/conf.d/10-master.conf
sudo sed -i '/service auth {/a\
  unix_listener /var/spool/postfix/private/auth {\n\
    mode = 0660\n\
    user = postfix\n\
    group = postfix\n\
  }' /etc/dovecot/conf.d/10-master.conf

# Reinicia Dovecot y Postfix
sudo systemctl restart dovecot
sudo systemctl restart postfix

# Registros DNS (si tienes configurado bind9 y zona propia)
echo "reprobados.com   IN  MX  10  correo.reprobados.com." | sudo tee -a /etc/bind/zonas/db.reprobados.com
echo "pop3 IN  CNAME   servidor" | sudo tee -a /etc/bind/zonas/db.reprobados.com
echo "smtp IN  CNAME   servidor" | sudo tee -a /etc/bind/zonas/db.reprobados.com
echo "correo  IN   CNAME   servidor" | sudo tee -a /etc/bind/zonas/db.reprobados.com
sudo systemctl restart bind9

# Instala SquirrelMail y sus dependencias
sudo apt-get install squirrelmail -y

# Copia archivos al directorio público de Apache
sudo ln -s /usr/share/squirrelmail /var/www/html/squirrelmail

# Configura Apache para permitir acceso
echo "<Directory /var/www/html/squirrelmail>
    Require all granted
</Directory>" | sudo tee /etc/apache2/conf-available/squirrelmail.conf

sudo a2enconf squirrelmail
sudo systemctl reload apache2

# Abre puertos si UFW está habilitado
sudo ufw allow 25/tcp    # SMTP
sudo ufw allow 110/tcp   # POP3
sudo ufw allow 143/tcp   # IMAP
sudo ufw allow 80/tcp    # HTTP

echo ""
echo "INSTALACIÓN COMPLETA. ACCEDE A SQUIRRELMAIL EN:"
echo "http://$(hostname -I | awk '{print $1}')/squirrelmail"
