#!/bin/bash

# Actualizar repositorios e instalar vsftpd
echo "Instalando vsftpd..."
sudo apt update && sudo apt install -y vsftpd acl ufw

# Configurar vsftpd
echo "Configurando vsftpd..."
sudo cp /etc/vsftpd.conf /etc/vsftpd.conf.bak  # Hacer copia de seguridad
sudo bash -c 'cat > /etc/vsftpd.conf' <<EOF
anonymous_enable=YES
anon_root=/srv/ftp
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

chroot_local_user=NO
allow_writeable_chroot=YES

pasv_enable=YES
pasv_min_port=40000
pasv_max_port=50000

ftpd_banner=Bienvenido al servidor FTP de Ubuntu.
EOF

# Crear directorios base
echo "Creando directorios FTP..."
FTP_ROOT="/srv/ftp"
mkdir -p $FTP_ROOT/general
mkdir -p $FTP_ROOT/grupos/reprobados
mkdir -p $FTP_ROOT/grupos/recursadores
mkdir -p $FTP_ROOT/usuarios

# Montar directorio FTP en /home/ftp
sudo mkdir -p /home/ftp
sudo mount --bind /srv/ftp /home/ftp
echo "/srv/ftp /home/ftp none bind 0 0" | sudo tee -a /etc/fstab

# Configurar permisos iniciales
sudo chmod 755 $FTP_ROOT/general
sudo chown ftp:nogroup $FTP_ROOT/general
sudo chmod 770 $FTP_ROOT/grupos/reprobados
sudo chmod 770 $FTP_ROOT/grupos/recursadores

# Ocultar grupos y usuarios por defecto (anónimos y no autorizados no ven nada)
sudo setfacl -m o::--- $FTP_ROOT/grupos
sudo setfacl -m o::--- $FTP_ROOT/usuarios

# Permitir acceso de grupo a sus respectivas carpetas
sudo groupadd reprobados
sudo groupadd recursadores

sudo chown root:reprobados $FTP_ROOT/grupos/reprobados
sudo chown root:recursadores $FTP_ROOT/grupos/recursadores

sudo chmod 755 $FTP_ROOT
sudo chmod 755 $FTP_ROOT/general
sudo chmod 750 $FTP_ROOT/grupos
sudo chmod 750 $FTP_ROOT/usuarios

# Permisos para anónimo (solo puede ver general)
sudo setfacl -m o::r-x $FTP_ROOT/general

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

        sudo useradd -m -d $FTP_ROOT/usuarios/$username -s /bin/bash -G $group $username
        echo "Ingrese la contraseña para el usuario $username:"
        sudo passwd $username

        # Crear carpeta personal del usuario
        sudo mkdir -p $FTP_ROOT/usuarios/$username
        sudo chown $username:$username $FTP_ROOT/usuarios/$username
        sudo chmod 700 $FTP_ROOT/usuarios/$username

        # Configurar ACLs para ocultar y mostrar lo necesario
        sudo setfacl -m u:$username:rwx $FTP_ROOT/usuarios/$username
        sudo setfacl -m g::--- $FTP_ROOT/usuarios/$username
        sudo setfacl -m o::--- $FTP_ROOT/usuarios/$username

        # Acceso a general
        sudo setfacl -m u:$username:rwx $FTP_ROOT/general

        # Acceso a carpeta de grupo
        sudo setfacl -m u:$username:rwx $FTP_ROOT/grupos/$group
        sudo setfacl -m g:$group:r-x $FTP_ROOT/grupos/$group

        # Ocultar carpeta del otro grupo
        if [ "$group" == "reprobados" ]; then
            sudo setfacl -m u:$username:--- $FTP_ROOT/grupos/recursadores
        else
            sudo setfacl -m u:$username:--- $FTP_ROOT/grupos/reprobados
        fi

        echo "Usuario $username creado y agregado al grupo $group."
    done
}

# Crear usuarios
crear_usuario

# Configurar firewall
echo "Configurando firewall para FTP..."
sudo ufw allow 20/tcp
sudo ufw allow 21/tcp
sudo ufw allow 40000:50000/tcp
sudo ufw enable

# Reiniciar vsftpd
echo "Reiniciando vsftpd..."
sudo systemctl restart vsftpd

echo "Configuración completada. Servidor FTP listo para usar."
