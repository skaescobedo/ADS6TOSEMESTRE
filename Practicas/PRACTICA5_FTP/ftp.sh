#!/bin/bash

# Actualizar repositorios e instalar vsftpd, acl y ufw
echo "Instalando vsftpd..."
sudo apt update && sudo apt install -y vsftpd acl ufw

# Configurar vsftpd
echo "Configurando vsftpd..."
sudo cp /etc/vsftpd.conf /etc/vsftpd.conf.bak  # Copia de seguridad

sudo bash -c 'cat > /etc/vsftpd.conf' <<EOF
anonymous_enable=YES
anon_root=/srv/ftp/general
anon_upload_enable=NO
anon_mkdir_write_enable=NO
anon_other_write_enable=NO

local_enable=YES
write_enable=YES
local_umask=022
dirmessage_enable=YES
use_localtime=YES
xferlog_enable=YES
connect_from_port_20=YES
listen=YES
listen_ipv6=NO
pam_service_name=vsftpd
user_sub_token=\$USER

chroot_local_user=YES
allow_writeable_chroot=YES
local_root=/srv/ftp/\$USER

# Refuerzo: limitar a todos a /srv/ftp
secure_chroot_dir=/var/run/vsftpd/empty

pasv_enable=YES
pasv_min_port=40000
pasv_max_port=50000

ftpd_banner=Bienvenido al servidor FTP de Ubuntu.
EOF

# Crear directorios base
FTP_ROOT="/srv/ftp"
GENERAL_DIR="$FTP_ROOT/general"
GROUP_DIR="$FTP_ROOT/grupos"

mkdir -p $GENERAL_DIR
mkdir -p $GROUP_DIR/reprobados
mkdir -p $GROUP_DIR/recursadores

# Montar el directorio FTP en /home/ftp
sudo mkdir -p /home/ftp
grep -qxF '/srv/ftp /home/ftp none bind 0 0' /etc/fstab || echo "/srv/ftp /home/ftp none bind 0 0" | sudo tee -a /etc/fstab
sudo mount --bind /srv/ftp /home/ftp

# Configurar permisos y propietarios iniciales
sudo chmod 755 $FTP_ROOT
sudo chmod 755 $GENERAL_DIR
sudo chmod 750 $GROUP_DIR
sudo chmod 770 $GROUP_DIR/reprobados
sudo chmod 770 $GROUP_DIR/recursadores

sudo chown root:root $FTP_ROOT
sudo chown ftp:nogroup $GENERAL_DIR
sudo chown root:root $GROUP_DIR
sudo chown root:reprobados $GROUP_DIR/reprobados
sudo chown root:recursadores $GROUP_DIR/recursadores

# Extra: reforzar permisos de /srv para evitar escapes
sudo chown root:root /srv
sudo chmod 755 /srv

# (Opcional) si quieres máxima seguridad, restringe aún más /srv/ftp
sudo chmod 555 /srv/ftp

# Crear grupos
echo "Creando grupos de usuarios..."
sudo groupadd -f reprobados
sudo groupadd -f recursadores

# Función para crear usuarios con permisos controlados
crear_usuario() {
    while true; do
        echo -n "Ingrese el nombre del usuario (o 'salir' para finalizar): "
        read username

        if [[ "$username" == "salir" ]]; then
            echo "Finalizando creación de usuarios."
            break
        fi

        echo -n "Seleccione el grupo (1: reprobados, 2: recursadores): "
        read group_option

        if [ "$group_option" == "1" ]; then
            group="reprobados"
        elif [ "$group_option" == "2" ]; then
            group="recursadores"
        else
            echo "Opción inválida. Inténtelo de nuevo."
            continue
        fi

        # Crear usuario con acceso restringido (sin shell interactivo)
        sudo useradd -m -d $FTP_ROOT/$username -s /usr/sbin/nologin -G $group $username
        echo "Ingrese la contraseña para el usuario $username:"
        sudo passwd $username

        sudo mkdir -p $FTP_ROOT/$username
        sudo chown $username:$username $FTP_ROOT/$username
        sudo chmod 700 $FTP_ROOT/$username  # Solo el dueño puede entrar

        # Configurar ACLs de acceso
        setfacl -m u:$username:rx $GENERAL_DIR  # Acceso a general
        setfacl -m u:$username:rwx $FTP_ROOT/$username  # Acceso completo a su carpeta
        setfacl -m u:$username:rx $GROUP_DIR  # Puede ver el directorio grupos, pero no entrar a otros grupos
        setfacl -m u:$username:rx $GROUP_DIR/$group  # Puede ver su carpeta de grupo

        echo "✅ Usuario $username creado y agregado al grupo $group."
    done
}

# Llamar a la función para crear usuarios
crear_usuario

# Configurar firewall
echo "Configurando firewall para permitir FTP..."
sudo ufw allow 20/tcp
sudo ufw allow 21/tcp
sudo ufw allow 40000:50000/tcp

# Reiniciar vsftpd con chequeo
echo "Reiniciando vsftpd..."
sudo systemctl restart vsftpd
if ! sudo systemctl is-active --quiet vsftpd; then
    echo "Error al reiniciar vsftpd. Revisa la configuración."
    exit 1
fi

# Habilitar firewall si no está activo
if ! sudo ufw status | grep -q "Status: active"; then
    sudo ufw enable
fi

echo "Configuración completada. Servidor FTP listo para usar."
