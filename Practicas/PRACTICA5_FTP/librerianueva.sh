#!/bin/bash

# Función para instalar paquetes necesarios
instalar_dependencias() {
    echo "Instalando vsftpd, acl y ufw..."
    sudo apt update && sudo apt install -y vsftpd acl ufw
}

# Función para configurar vsftpd
configurar_vsftpd() {
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
}

crear_estructura_directorios() {
    FTP_ROOT="/srv/ftp"
    echo "Creando estructura de directorios..."
    mkdir -p $FTP_ROOT/{anon,autenticados,grupos/general,grupos/reprobados,grupos/recursadores}

    sudo chmod 2775 $FTP_ROOT/grupos/general
    sudo chown root:ftp $FTP_ROOT/grupos/general

    sudo setfacl -d -m u::rwx $FTP_ROOT/grupos/general
    sudo setfacl -d -m g::r-x $FTP_ROOT/grupos/general
    sudo setfacl -d -m o::r-x $FTP_ROOT/grupos/general

    sudo chmod 770 $FTP_ROOT/grupos/reprobados
    sudo chmod 770 $FTP_ROOT/grupos/recursadores
    sudo chown root:reprobados $FTP_ROOT/grupos/reprobados
    sudo chown root:recursadores $FTP_ROOT/grupos/recursadores

    mkdir -p $FTP_ROOT/anon/general
    sudo mount --bind $FTP_ROOT/grupos/general $FTP_ROOT/anon/general

    echo "$FTP_ROOT/grupos/general $FTP_ROOT/anon/general none bind 0 0" | sudo tee -a /etc/fstab

    sudo groupadd -f reprobados
    sudo groupadd -f recursadores
}


# Función para crear un usuario autenticado y sus carpetas
crear_usuario() {
    FTP_ROOT="/srv/ftp"

    # Validar si los grupos existen
    if ! getent group "reprobados" > /dev/null 2>&1; then
        echo "No existe ningun grupo. No se puede terminar con la creación del usuario"
        return 1
    fi

    if ! getent group "recursadores" > /dev/null 2>&1; then
        echo "No existe ningun grupo. No se puede terminar con la creación del usuario"
        return 1
    fi

    while true; do
        while true; do
            echo -n "Ingrese el nombre del usuario (o 'salir' para terminar): "
            read username

            if [[ "$username" == "salir" ]]; then
                echo "Finalizando creación de usuarios."
                break 2
            fi

            # Validar nombre de usuario
            if ! validar_nombre_usuario "$username"; then
                continue
            fi

            break
        done

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

        sudo useradd -m -d $FTP_ROOT/autenticados/$username -s /bin/bash -G $group $username
        sudo passwd $username

        sudo mkdir -p $FTP_ROOT/autenticados/$username/{general,$group,$username}
        sudo chown $username:$username $FTP_ROOT/autenticados/$username
        sudo chown $username:$username $FTP_ROOT/autenticados/$username/$username
        sudo chmod 750 $FTP_ROOT/autenticados/$username
        sudo chmod 700 $FTP_ROOT/autenticados/$username/$username

        sudo mount --bind $FTP_ROOT/grupos/general $FTP_ROOT/autenticados/$username/general
        sudo mount --bind $FTP_ROOT/grupos/$group $FTP_ROOT/autenticados/$username/$group

        echo "$FTP_ROOT/grupos/general $FTP_ROOT/autenticados/$username/general none bind 0 0" | sudo tee -a /etc/fstab
        echo "$FTP_ROOT/grupos/$group $FTP_ROOT/autenticados/$username/$group none bind 0 0" | sudo tee -a /etc/fstab

        sudo setfacl -m u:$username:rwx $FTP_ROOT/autenticados/$username
        sudo setfacl -m u:$username:rwx $FTP_ROOT/grupos/general
        sudo setfacl -m u:$username:rwx $FTP_ROOT/grupos/$group

        echo "Usuario $username creado, carpeta personal '$username' creada, y asignado al grupo $group."

        sudo chmod 750 $FTP_ROOT/autenticados/$username
    done
}

# Configurar firewall y reiniciar vsftpd
configurar_firewall_y_vsftpd() {
    echo "Configurando firewall..."
    sudo ufw allow 20/tcp
    sudo ufw allow 21/tcp
    sudo ufw allow 40000:50000/tcp

    sudo systemctl restart vsftpd
    sudo ufw enable
}

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

    # Verificar caracteres permitidos (solo letras, números, guion bajo y guion)
    if [[ "$nombre_usuario" =~ [^a-zA-Z0-9_-] ]]; then
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

eliminar_usuario() {
    FTP_ROOT="/srv/ftp"

    echo -n "Ingrese el nombre del usuario a eliminar: "
    read username

    # Verificar si el usuario existe
    if ! id "$username" &>/dev/null; then
        echo "El usuario '$username' no existe. Saliendo..."
        return 1
    fi

    echo "Eliminando usuario '$username' y sus recursos..."

    # Desmontar directorios si están montados
    if mountpoint -q "$FTP_ROOT/autenticados/$username/general"; then
        sudo umount "$FTP_ROOT/autenticados/$username/general"
    fi

    if mountpoint -q "$FTP_ROOT/autenticados/$username/reprobados"; then
        sudo umount "$FTP_ROOT/autenticados/$username/reprobados"
    fi

    if mountpoint -q "$FTP_ROOT/autenticados/$username/recursadores"; then
        sudo umount "$FTP_ROOT/autenticados/$username/recursadores"
    fi

    # Eliminar el usuario
    sudo userdel -r "$username"

    # Eliminar el directorio del usuario si aún existe
    if [ -d "$FTP_ROOT/autenticados/$username" ]; then
        sudo rm -rf "$FTP_ROOT/autenticados/$username"
    fi

    echo "Usuario '$username' eliminado correctamente."
}
