#!/bin/bash
#FTPPPP
#-----------------------------------------------------------------------------
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

#--------------------------------------------------------------------------------
#HTTP
#--------------------------------------------------------------------------------

# Variables globales (compartidas entre las funciones)
servicio=""
version=""
puerto=""
versions=()

instalar_dependencias() {
    echo "Instalando dependencias necesarias para Apache, Tomcat y Nginx en Ubuntu..."

    sudo apt-get update -y

    # Dependencias generales para compilación y descarga
    sudo apt-get install -y build-essential wget curl tar

    # Dependencias específicas para Apache
    sudo apt-get install -y libapr1-dev libaprutil1-dev libpcre3 libpcre3-dev

    # Dependencias específicas para Nginx (compilación desde fuente)
    sudo apt-get install -y libssl-dev zlib1g-dev

    echo "Todas las dependencias fueron instaladas correctamente."
}

# Función para seleccionar el servicio
seleccionar_servicio() {
    echo "Seleccione el servicio que desea instalar:"
    echo "1.- Apache"
    echo "2.- Tomcat"
    echo "3.- Nginx"
    read -p "Opción: " opcion

    case $opcion in
        1)
            servicio="Apache"
            obtener_versiones_apache
            ;;
        2)
            servicio="Tomcat"
            obtener_versiones_tomcat
            ;;
        3)
            servicio="Nginx"
            obtener_versiones_nginx
            ;;
        *)
            echo "Opción no válida. Intente de nuevo."
            ;;
    esac
}

# Función para seleccionar la versión de un servicio ya seleccionado
seleccionar_version() {
    if [[ -z "$servicio" ]]; then
        echo "Debe seleccionar un servicio antes de elegir la versión."
        return
    fi

    echo "Seleccione la versión de $servicio:"
    echo "1.- Versión Estable (LTS): ${versions[0]}"
    echo "2.- Versión de Desarrollo: ${versions[1]}"
    read -p "Opción: " opcion

    case $opcion in
        1)
            version=${versions[0]}
            echo "Versión seleccionada: $version"
            ;;
        2)
            version=${versions[1]}
            echo "Versión seleccionada: $version"
            ;;
        *)
            echo "Opción no válida."
            ;;
    esac
}

# Función para verificar si un puerto está en uso
verificar_puerto_en_uso() {
    local puerto=$1
    if ss -tuln | grep -q ":$puerto\b"; then
        return 1
    else
        return 0
    fi
}

# Función para pedir un puerto y asegurarse de que esté libre
preguntar_puerto() {
    while true; do
        read -p "Ingrese el puerto para el servicio: " puerto
        if verificar_puerto_en_uso "$puerto"; then
            echo "El puerto $puerto está disponible."
            break
        else
            echo "El puerto $puerto está ocupado. Intente con otro."
        fi
    done
}

comando_existente() {
    command -v "$1" > /dev/null 2>&1
}

proceso_instalacion() {
    if [[ -z "$servicio" || -z "$version" || -z "$puerto" ]]; then
        echo "Debe seleccionar el servicio, la versión y el puerto antes de proceder con la instalación."
        return
    fi

    # Validar dependencias
    if ! comando_existente "gcc" || ! comando_existente "make" || ! comando_existente "wget" || ! comando_existente "curl"; then
        echo "Faltan dependencias esenciales para la instalación."
        echo "Por favor, ejecute la opción 0 del menú (Instalar dependencias necesarias) antes de continuar."
        return 1
    fi

    echo "Iniciando instalación silenciosa de $servicio versión $version en el puerto $puerto..."

    case $servicio in
        "Apache")
            instalar_apache
            ;;
        "Tomcat")
            instalar_tomcat
            ;;
        "Nginx")
            instalar_nginx
            ;;
        *)
            echo "Servicio desconocido. No se puede proceder."
            return 1
            ;;
    esac

    echo "Instalación completada para $servicio versión $version en el puerto $puerto."
}

instalar_apache() {
    echo "Descargando e instalando Apache versión $version..."

    wget -q "https://downloads.apache.org/httpd/httpd-$version.tar.gz" -O "/tmp/httpd-$version.tar.gz"
    if [[ $? -ne 0 ]]; then
        echo "Error al descargar Apache $version."
        return 1
    fi

    tar -xzf "/tmp/httpd-$version.tar.gz" -C /tmp
    cd "/tmp/httpd-$version" || exit 1

    echo "Compilando Apache (esto puede tardar)..."
    ./configure --prefix=/usr/local/apache2 --enable-so > /dev/null
    if [[ $? -ne 0 ]]; then
        echo "Error al ejecutar ./configure para Apache."
        return 1
    fi

    make > /dev/null
    if [[ $? -ne 0 ]]; then
        echo "Error al ejecutar make para Apache."
        return 1
    fi

    sudo make install > /dev/null
    if [[ $? -ne 0 ]]; then
        echo "Error al ejecutar make install para Apache."
        return 1
    fi

    # Configurar puerto sin preguntar
    sudo sed -i "s/Listen 80/Listen $puerto/" /usr/local/apache2/conf/httpd.conf

    # Iniciar Apache
    /usr/local/apache2/bin/apachectl start

    echo "Apache $version instalado y configurado en el puerto $puerto."
}

instalar_tomcat() {
    echo "Descargando e instalando Tomcat versión $version..."

    wget -q "https://dlcdn.apache.org/tomcat/tomcat-10/v$version/bin/apache-tomcat-$version.tar.gz" -O "/tmp/tomcat-$version.tar.gz"
    if [[ $? -ne 0 ]]; then
        echo "Error al descargar Tomcat $version."
        return 1
    fi

    # Limpiar instalación previa (si existe)
    if [[ -d "/opt/tomcat" ]]; then
        echo "Eliminando instalación previa de Tomcat..."
        sudo rm -rf /opt/tomcat
    fi

    sudo mkdir -p /opt/tomcat
    sudo tar -xzf "/tmp/tomcat-$version.tar.gz" -C /opt/tomcat --strip-components=1

    # Configurar puerto sin preguntar (usa la variable global $puerto)
    sudo sed -i "s/Connector port=\"8080\"/Connector port=\"$puerto\"/" /opt/tomcat/conf/server.xml

    # Iniciar Tomcat
    /opt/tomcat/bin/startup.sh

    echo "Tomcat $version instalado y configurado en el puerto $puerto."
}

instalar_nginx() {
    echo "Descargando e instalando NGINX versión $version..."

    # Descargar el paquete
    wget -q "https://nginx.org/download/nginx-$version.tar.gz" -O "/tmp/nginx-$version.tar.gz"
    if [[ $? -ne 0 ]]; then
        echo "Error al descargar NGINX $version."
        return 1
    fi

    # Limpiar instalación previa (si existe)
    if [[ -d "/usr/local/nginx" ]]; then
        echo "Eliminando instalación previa de NGINX..."
        sudo rm -rf /usr/local/nginx
    fi

    # Descomprimir y compilar
    tar -xzf "/tmp/nginx-$version.tar.gz" -C /tmp
    cd "/tmp/nginx-$version" || exit 1

    echo "Compilando NGINX (esto puede tardar)..."
    ./configure --prefix=/usr/local/nginx > /dev/null
    if [[ $? -ne 0 ]]; then
        echo "Error al ejecutar ./configure para NGINX."
        return 1
    fi

    make > /dev/null
    if [[ $? -ne 0 ]]; then
        echo "Error al ejecutar make para NGINX."
        return 1
    fi

    sudo make install > /dev/null
    if [[ $? -ne 0 ]]; then
        echo "Error al ejecutar make install para NGINX."
        return 1
    fi

    # Configurar puerto sin preguntar (usa la variable global $puerto)
    sudo sed -i "s/listen       80;/listen       $puerto;/" /usr/local/nginx/conf/nginx.conf

    # Iniciar NGINX
    /usr/local/nginx/sbin/nginx

    echo "NGINX $version instalado y configurado en el puerto $puerto."
}

# Función para obtener versiones de Apache HTTP Server
obtener_versiones_apache() {
    echo "Obteniendo versiones de Apache HTTP Server desde https://httpd.apache.org/download.cgi"

    # Descargar HTML de la página
    html=$(curl -s "https://httpd.apache.org/download.cgi")

    # Buscar versiones en formato httpd-X.Y.Z
    versions_raw=$(echo "$html" | grep -oP 'httpd-\d+\.\d+\.\d+' | sed 's/httpd-//')

    # Extraer la versión LTS (2.4.x) y la versión de desarrollo (2.5.x o superior si existe)
    version_lts=$(echo "$versions_raw" | grep '^2\.4' | head -n 1)
    version_dev=$(echo "$versions_raw" | grep '^2\.5' | head -n 1)

    # Si no encuentra desarrollo (no siempre hay), lo dejamos vacío o avisamos
    if [[ -z "$version_dev" ]]; then
        version_dev="No disponible"
    fi

    versions=("$version_lts" "$version_dev")

    echo "Versión estable (LTS): $version_lts"
    echo "Versión de desarrollo: $version_dev"
}

# Función para obtener versiones de Apache Tomcat (focalizado en Tomcat 10 y 11)
obtener_versiones_tomcat() {
    echo "Obteniendo versiones de Apache Tomcat desde https://tomcat.apache.org/download-10.cgi"

    # Descargar HTML de la página de Tomcat 10
    html=$(curl -s "https://tomcat.apache.org/download-10.cgi")

    # Buscar versiones en formato vX.Y.Z
    versions_raw=$(echo "$html" | grep -oP 'v\d+\.\d+\.\d+' | sed 's/v//')

    # Tomcat 10.1 es LTS (última estable), Tomcat 11 es la de desarrollo
    version_lts=$(echo "$versions_raw" | head -n 1)
    version_dev="11.0.1"  # Puedes automatizar esto si Tomcat 11 tiene su propia página

    versions=("$version_lts" "$version_dev")

    echo "Versión estable (LTS): $version_lts"
    echo "Versión de desarrollo: $version_dev"
}

# Función para obtener versiones de NGINX
obtener_versiones_nginx() {
    echo "Obteniendo versiones de NGINX desde https://nginx.org/en/download.html"

    # Descargar HTML de la página
    html=$(curl -s "https://nginx.org/en/download.html")

    # Buscar versiones en formato nginx-X.Y.Z
    versions_raw=($(echo "$html" | grep -oP 'nginx-\d+\.\d+\.\d+' | sed 's/nginx-//'))

    # La primera es la versión de desarrollo (mainline), la segunda es la versión estable (LTS)
    version_dev="${versions_raw[0]}"
    version_lts="${versions_raw[1]}"

    versions=("$version_lts" "$version_dev")

    echo "Versión estable (LTS): $version_lts"
    echo "Versión de desarrollo (mainline): $version_dev"
}
