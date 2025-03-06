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


crear_usuario() {
    FTP_ROOT="/srv/ftp"

    if ! getent group "reprobados" > /dev/null 2>&1; then
        echo "No existe ningún grupo. No se puede terminar con la creación del usuario"
        return 1
    fi

    if ! getent group "recursadores" > /dev/null 2>&1; then
        echo "No existe ningún grupo. No se puede terminar con la creación del usuario"
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

        # Llamada a la función validar_contraseña
        validar_contraseña
        local password="$CONTRASENA_VALIDADA"

        echo "$username:$password" | sudo chpasswd

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

# Función para eliminar un usuario FTP y limpiar sus recursos
eliminar_usuario() {
    FTP_ROOT="/srv/ftp"

    echo -n "Ingrese el nombre del usuario a eliminar: "
    read username

    # Verificar si el usuario existe
    if ! id "$username" &>/dev/null; then
        echo "El usuario '$username' no existe. Saliendo..."
        return 1
    fi

    echo "Eliminando usuario '$username'..."

    # Determinar el grupo al que pertenece (reprobados o recursadores)
    group=$(id -nG "$username" | grep -Eo "reprobados|recursadores")

    echo "Matando procesos activos de '$username' (incluyendo sesiones FTP)..."
    sudo pkill -u "$username" 2>/dev/null

    # Eliminar carpeta personal del usuario (donde sólo él tiene acceso)
    personal_folder="$FTP_ROOT/autenticados/$username/$username"
    if [ -d "$personal_folder" ]; then
        echo "Eliminando carpeta personal: $personal_folder"
        sudo rm -rf "$personal_folder"
        if [ $? -ne 0 ]; then
            echo "Advertencia: No se pudo eliminar la carpeta personal $personal_folder."
        else
            echo "Carpeta personal eliminada correctamente."
        fi
    fi

    echo "Desmontando directorios bind..."

    # Desmontar general con fallback a lazy unmount
    if mountpoint -q "$FTP_ROOT/autenticados/$username/general"; then
        sudo umount "$FTP_ROOT/autenticados/$username/general"
        if [ $? -ne 0 ]; then
            echo "Desmontaje normal falló, aplicando lazy unmount en general."
            sudo umount -l "$FTP_ROOT/autenticados/$username/general"
        fi
    fi

    # Desmontar directorio de grupo con fallback a lazy unmount
    if [ -n "$group" ] && mountpoint -q "$FTP_ROOT/autenticados/$username/$group"; then
        sudo umount "$FTP_ROOT/autenticados/$username/$group"
        if [ $? -ne 0 ]; then
            echo "Desmontaje normal falló, aplicando lazy unmount en $group."
            sudo umount -l "$FTP_ROOT/autenticados/$username/$group"
        fi
    fi

    # Limpiar el /etc/fstab (quitar entradas del usuario)
    sudo sed -i "\|$FTP_ROOT/autenticados/$username|d" /etc/fstab
    if [ $? -ne 0 ]; then
        echo "Error al limpiar /etc/fstab para el usuario '$username'."
        return 1
    fi

    # Eliminar el usuario
    sudo userdel -r "$username"
    if [ $? -ne 0 ]; then
        echo "Advertencia: No se pudo eliminar completamente al usuario '$username'."
    else
        echo "Usuario '$username' eliminado correctamente del sistema."
    fi

    # Eliminar el directorio raíz del usuario
    if [ -d "$FTP_ROOT/autenticados/$username" ]; then
        echo "Eliminando directorio raíz del usuario: $FTP_ROOT/autenticados/$username"
        sudo rm -rf "$FTP_ROOT/autenticados/$username"
        if [ $? -ne 0 ]; then
            echo "Advertencia: No se pudo eliminar el directorio raíz $FTP_ROOT/autenticados/$username."
        else
            echo "Directorio raíz eliminado correctamente."
        fi
    fi

    echo "Eliminación de usuario '$username' completada."
    return 0
}
