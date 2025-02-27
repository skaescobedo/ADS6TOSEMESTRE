#!/bin/bash

# Actualizar repositorios e instalar vsftpd
echo "Instalando vsftpd..."
sudo apt update && sudo apt install -y vsftpd acl ufw

# Configurar vsftpd
echo "Configurando vsftpd..."
sudo cp /etc/vsftpd.conf /etc/vsftpd.conf.bak  # Hacer una copia de seguridad
sudo bash -c 'cat > /etc/vsftpd.conf' <<EOF
anonymous_enable=NO
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
ftpd_banner=Bienvenido al servidor FTP de Ubuntu.

# Configuración de modo pasivo
pasv_enable=YES
pasv_min_port=40000
pasv_max_port=50000
EOF

# Crear directorios base
echo "Creando directorios FTP..."
FTP_ROOT="/srv/ftp"
GENERAL_DIR="$FTP_ROOT/general"
GROUP_DIR="$FTP_ROOT/grupos"
mkdir -p $GENERAL_DIR
mkdir -p $GROUP_DIR/reprobados
mkdir -p $GROUP_DIR/recursadores

# Montar el directorio FTP en /home/ftp
echo "Montando el directorio FTP..."
sudo mkdir -p /home/ftp
sudo mount --bind /srv/ftp /home/ftp

# Hacer el montaje persistente
echo "/srv/ftp /home/ftp none bind 0 0" | sudo tee -a /etc/fstab

# Permisos para acceso anónimo solo lectura en "general"
sudo chmod 755 $GENERAL_DIR
sudo chown ftp:nogroup $GENERAL_DIR

# Crear grupos
echo "Creando grupos de usuarios..."
sudo groupadd reprobados
sudo groupadd recursadores

# Función para crear usuarios
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

        sudo useradd -m -d $FTP_ROOT/$username -s /bin/bash -G $group $username
        echo "Ingrese la contraseña para el usuario $username:"
        sudo passwd $username

        # Crear y configurar directorios de usuario
        sudo mkdir -p $FTP_ROOT/$username
        sudo chown $username:$username $FTP_ROOT/$username
        sudo chmod 755 $FTP_ROOT/$username

        # Permisos sobre las carpetas
        sudo setfacl -m u:$username:rwx $GENERAL_DIR
        sudo setfacl -m u:$username:rwx $FTP_ROOT/$username
        sudo setfacl -m u:$username:rwx $GROUP_DIR/$group

        echo "Usuario $username creado y agregado al grupo $group."
    done
}

# Agregar usuarios de forma interactiva
crear_usuario

# Configurar reglas de firewall
echo "Configurando firewall para permitir FTP..."
sudo ufw allow 20/tcp
sudo ufw allow 21/tcp
sudo ufw allow 40000:50000/tcp  # Puertos de modo pasivo

# Reiniciar vsftpd
echo "Reiniciando vsftpd..."
sudo systemctl restart vsftpd

# Habilitar firewall si aún no está activo
echo "Habilitando UFW si no está activo..."
sudo ufw enable

echo "Configuración completada. Servidor FTP listo para usar."
