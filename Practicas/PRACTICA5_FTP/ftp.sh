#!/bin/bash

# Instalación de vsftpd, ACL y UFW
echo "Instalando vsftpd, acl y ufw..."
sudo apt update && sudo apt install -y vsftpd acl ufw

# Configuración base de vsftpd
echo "Configurando vsftpd..."
sudo cp /etc/vsftpd.conf /etc/vsftpd.conf.bak

sudo bash -c 'cat > /etc/vsftpd.conf' <<EOF
anonymous_enable=YES
anon_root=/srv/ftp/anon
anon_upload_enable=NO
anon_mkdir_write_enable=NO
anon_other_write_enable=NO

local_enable=YES
write_enable=YES
local_umask=022
file_open_mode=0644
anon_umask=022

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
local_root=/srv/ftp/autenticados/\$USER

pasv_enable=YES
pasv_min_port=40000
pasv_max_port=50000

ftpd_banner=Bienvenido al servidor FTP.
EOF

# Crear estructura de directorios
echo "Creando estructura de directorios..."

FTP_ROOT="/srv/ftp"
mkdir -p $FTP_ROOT/{anon,autenticados,grupos/general,grupos/reprobados,grupos/recursadores}

# Permisos generales y dueño para 'general'
sudo chmod 775 $FTP_ROOT/grupos/general
sudo chown root:ftp $FTP_ROOT/grupos/general

# Permisos de carpetas de grupos
sudo chmod 770 $FTP_ROOT/grupos/reprobados
sudo chmod 770 $FTP_ROOT/grupos/recursadores
sudo chown root:reprobados $FTP_ROOT/grupos/reprobados
sudo chown root:recursadores $FTP_ROOT/grupos/recursadores

# Permitir que cualquier archivo nuevo en 'general' sea visible por todos
sudo setfacl -d -m o::r $FTP_ROOT/grupos/general

# Montar carpeta general para anónimos
mkdir -p $FTP_ROOT/anon/general
sudo mount --bind $FTP_ROOT/grupos/general $FTP_ROOT/anon/general

# Hacer el montaje persistente
echo "$FTP_ROOT/grupos/general $FTP_ROOT/anon/general none bind 0 0" | sudo tee -a /etc/fstab

# Crear grupos de usuarios
sudo groupadd -f reprobados
sudo groupadd -f recursadores

# Función para crear un usuario autenticado
crear_usuario() {
    while true; do
        echo -n "Ingrese el nombre del usuario (o 'salir' para terminar): "
        read username
        if [[ "$username" == "salir" ]]; then
            echo "Finalizando creación de usuarios."
            break
        fi

        echo "Seleccione el grupo: (1) reprobados (2) recursadores"
        read group_option

        if [ "$group_option" == "1" ]; then
            group="reprobados"
        elif [ "$group_option" == "2" ]; then
            group="recursadores"
        else
            echo "Opción inválida."
            continue
        fi

        # Crear usuario con home en /srv/ftp/autenticados/username
        sudo useradd -m -d $FTP_ROOT/autenticados/$username -s /bin/bash -G $group $username
        sudo passwd $username

        # Crear carpetas personalizadas y bind mounts
        sudo mkdir -p $FTP_ROOT/autenticados/$username/{general,$group}
        sudo chown $username:$username $FTP_ROOT/autenticados/$username
        sudo chmod 750 $FTP_ROOT/autenticados/$username

        # Bind general y grupo a la carpeta del usuario
        sudo mount --bind $FTP_ROOT/grupos/general $FTP_ROOT/autenticados/$username/general
        sudo mount --bind $FTP_ROOT/grupos/$group $FTP_ROOT/autenticados/$username/$group

        # Añadir a /etc/fstab para que persista
        echo "$FTP_ROOT/grupos/general $FTP_ROOT/autenticados/$username/general none bind 0 0" | sudo tee -a /etc/fstab
        echo "$FTP_ROOT/grupos/$group $FTP_ROOT/autenticados/$username/$group none bind 0 0" | sudo tee -a /etc/fstab

        # Permisos ACL para asegurar acceso
        sudo setfacl -m u:$username:rwx $FTP_ROOT/autenticados/$username
        sudo setfacl -m u:$username:rwx $FTP_ROOT/grupos/general
        sudo setfacl -m u:$username:rwx $FTP_ROOT/grupos/$group

        echo "Usuario $username creado y asignado al grupo $group."
    done
}

# Crear usuarios interactivamente
crear_usuario

# Configurar firewall
echo "Configurando firewall..."
sudo ufw allow 20/tcp
sudo ufw allow 21/tcp
sudo ufw allow 40000:50000/tcp

# Reiniciar vsftpd
echo "Reiniciando vsftpd..."
sudo systemctl restart vsftpd

# Habilitar UFW
sudo ufw enable

echo "Servidor FTP configurado correctamente."
