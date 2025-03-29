#!/bin/bash

# Función para instalar paquetes necesarios
instalar_dependencias_ftp() {
    echo "Instalando vsftpd, acl y ufw..."
    sudo apt update && sudo apt install -y vsftpd acl ufw
}

configurar_vsftpd() {
    local respuesta_ssl=$1  # Recibe la variable como argumento

    # Determinar el puerto según la elección del usuario
    if [[ "$respuesta_ssl" == "s" || "$respuesta_ssl" == "S" ]]; then
        ftp_port=990  # Puerto FTPS implícito
    else
        ftp_port=21   # Puerto FTP normal
    fi

    echo "Configurando vsftpd en el puerto $ftp_port..."
    sudo cp /etc/vsftpd.conf /etc/vsftpd.conf.bak

    sudo bash -c "cat > /etc/vsftpd.conf" <<EOF
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

listen_port=$ftp_port
EOF

    # Si el usuario eligió "s", configurar SSL
    if [[ "$respuesta_ssl" == "s" || "$respuesta_ssl" == "S" ]]; then
        configurar_ssl_vsftpd
        echo "FTPS habilitado en el puerto $ftp_port."
    else
        echo "SSL no ha sido configurado. El servidor FTP usará el puerto $ftp_port."
    fi

    # Llamar a la función para configurar firewall y reiniciar vsftpd
    configurar_firewall_y_vsftpd "$ftp_port"
}

# Configurar firewall y reiniciar vsftpd
configurar_firewall_y_vsftpd() {
    local ftp_port=$1  # Recibe el puerto como argumento
    echo "Configurando firewall para el puerto $ftp_port..."
    
    sudo ufw allow 20/tcp
    sudo ufw allow "$ftp_port"/tcp
    sudo ufw allow 40000:50000/tcp

    sudo systemctl restart vsftpd
    sudo ufw enable
    echo "Firewall configurado y vsftpd reiniciado."
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

configurar_ssl_vsftpd() {
    echo "Generando certificado SSL auto-firmado para FTPS..."
    
    sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout /etc/ssl/private/vsftpd.key \
        -out /etc/ssl/certs/vsftpd.crt \
        -subj "/C=MX/ST=Sinaloa/L=Los Mochis/O=FTP Secure/OU=IT/CN=localhost"

    echo "Configurando vsftpd para habilitar SSL..."
    sudo bash -c 'cat >> /etc/vsftpd.conf' <<EOF

# Configuración SSL habilitada
ssl_enable=YES
implicit_ssl=YES
rsa_cert_file=/etc/ssl/certs/vsftpd.crt
rsa_private_key_file=/etc/ssl/private/vsftpd.key
allow_anon_ssl=YES
force_local_logins_ssl=YES
force_local_data_ssl=YES
ssl_tlsv1=YES
ssl_sslv2=NO
ssl_sslv3=NO
require_ssl_reuse=NO
ssl_ciphers=HIGH
EOF

    echo "Reiniciando vsftpd..."
    sudo systemctl restart vsftpd

    echo "SSL ha sido configurado correctamente en el servidor FTP con FTPS en el puerto 990."
}

#--------------------------------------------------------------------------------
#HTTP
#--------------------------------------------------------------------------------

# Variables globales (compartidas entre las funciones)
servicio=""
version=""
puerto=""
versions=()

paquete_instalado() {
    dpkg -l | grep -qw "$1"
}

instalar_dependencias_https() {
    echo "Verificando e instalando dependencias necesarias para Apache, Tomcat y Nginx en Ubuntu..."

    sudo apt-get update -y

    # Dependencias generales
    for paquete in build-essential wget curl tar openssl; do
        if paquete_instalado "$paquete"; then
            echo "$paquete ya está instalado."
        else
            sudo apt-get install -y "$paquete"
        fi
    done

    # Dependencias específicas de Apache
    for paquete in libapr1-dev libaprutil1-dev libpcre3 libpcre3-dev; do
        if paquete_instalado "$paquete"; then
            echo "$paquete ya está instalado."
        else
            sudo apt-get install -y "$paquete"
        fi
    done

    # Dependencias específicas de NGINX
    for paquete in libssl-dev zlib1g-dev; do
        if paquete_instalado "$paquete"; then
            echo "$paquete ya está instalado."
        else
            sudo apt-get install -y "$paquete"
        fi
    done

    # Dependencia de Tomcat (Java)
    if paquete_instalado "default-jdk"; then
        echo "default-jdk ya está instalado."
    else
        sudo apt-get install -y default-jdk
    fi

    # Configurar JAVA_HOME automáticamente si no está en /etc/environment
    if ! grep -q "JAVA_HOME" /etc/environment; then
        java_home_path=$(readlink -f $(which java) | sed "s:/bin/java::")
        echo "JAVA_HOME=\"$java_home_path\"" | sudo tee -a /etc/environment > /dev/null
        source /etc/environment
        echo "JAVA_HOME configurado automáticamente como: $JAVA_HOME"
    else
        echo "JAVA_HOME ya está configurado."
    fi

    echo "Verificación e instalación de dependencias completada."
}


# Función para seleccionar el servicio
seleccionar_servicio() {
    local modo=$1  # Recibe el parámetro (puede ser "ftp" o vacío)

    echo "Seleccione el servicio que desea instalar:"
    echo "1.- Apache"
    echo "2.- Tomcat"
    echo "3.- Nginx"
    read -p "Opción: " opcion

    case $opcion in
        1)
            servicio="Apache"
            [[ "$modo" != "ftp" ]] && obtener_versiones_apache  # Solo si NO es FTP
            ;;
        2)
            servicio="Tomcat"
            [[ "$modo" != "ftp" ]] && obtener_versiones_tomcat  # Solo si NO es FTP
            ;;
        3)
            servicio="Nginx"
            [[ "$modo" != "ftp" ]] && obtener_versiones_nginx  # Solo si NO es FTP
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

# Función para verificar si un puerto está en la lista de restringidos
es_puerto_restringido() {
    local puerto=$1
    local puertos_restringidos=(1 7 9 11 13 15 17 19 20 21 22 23 25 37 42 43 53 69 77 79 87 95 101 102 103 104 109 110 111 113 115 117 118 119 123 135 137 139 143 161 177 179 389 427 445 465 512 513 514 515 526 530 531 532 540 548 554 556 563 587 601 636 989 990 993 995 1723 2049 6667)

    for p in "${puertos_restringidos[@]}"; do
        if [[ "$puerto" -eq "$p" ]]; then
            return 0  # El puerto está restringido
        fi
    done
    return 1  # El puerto no está en la lista de restringidos
}

# Función para verificar si un puerto está en uso
verificar_puerto_en_uso() {
    local puerto=$1
    if ss -tuln 2>/dev/null | grep -q "LISTEN.*:$puerto "; then
        return 0  # Puerto en uso
    else
        return 1  # Puerto libre
    fi
}

# Función para pedir un puerto y asegurarse de que esté libre y no restringido
preguntar_puerto() {
    while true; do
        read -p "Ingrese el puerto para el servicio (debe estar entre 1 y 65535): " puerto

        # Verificar si la entrada es un número y está dentro del rango válido
        if [[ "$puerto" =~ ^[0-9]+$ ]] && (( puerto >= 1 && puerto <= 65535 )); then
            # Verificar si el puerto está restringido
            if es_puerto_restringido "$puerto"; then
                echo "El puerto $puerto está en la lista de puertos restringidos. Intente con otro."
                continue
            fi

            # Verificar si el puerto está en uso
            if verificar_puerto_en_uso "$puerto"; then
                echo "El puerto $puerto está ocupado. Intente con otro."
            else
                echo "El puerto $puerto está disponible."
                break
            fi
        else
            echo "Entrada inválida. Ingrese un número de puerto entre 1 y 65535."
        fi
    done
}
# Función para habilitar un puerto en el firewall
habilitar_puerto_firewall() {
    local puerto=$1

    if [ -z "$puerto" ]; then
        echo "Error: No se proporcionó un puerto."
        return 1
    fi

    # Verificar si el firewall está activo
    if command -v ufw &> /dev/null; then
        if sudo ufw status | grep -q "$puerto"; then
            echo "El puerto $puerto ya está permitido en el firewall (UFW)."
        else
            sudo ufw allow "$puerto"/tcp
            echo "El puerto $puerto ha sido habilitado en el firewall (UFW)."
        fi
    elif command -v firewall-cmd &> /dev/null; then
        if sudo firewall-cmd --list-ports | grep -q "$puerto/tcp"; then
            echo "El puerto $puerto ya está permitido en el firewall (firewalld)."
        else
            sudo firewall-cmd --add-port="$puerto"/tcp --permanent
            sudo firewall-cmd --reload
            echo "El puerto $puerto ha sido habilitado en el firewall (firewalld)."
        fi
    else
        echo "No se encontró un gestor de firewall compatible (UFW o firewalld)."
        return 1
    fi
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

    # Limpiar variables globales
    unset servicio
    unset version
    unset puerto
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
    ./configure --prefix=/usr/local/apache2 --enable-so --enable-ssl > /dev/null
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

    # Configurar puerto y SSL si es necesario
    if [[ "$protocolo" == "HTTPS" ]]; then
        configurar_ssl "apache"
        sudo bash -c "cat >> /usr/local/apache2/conf/httpd.conf" <<EOF
LoadModule ssl_module modules/mod_ssl.so
Listen $puerto
<VirtualHost *:$puerto>
    DocumentRoot "/usr/local/apache2/htdocs"
    SSLEngine on
    SSLCertificateFile /etc/ssl/apache/server.crt
    SSLCertificateKeyFile /etc/ssl/apache/server.key
</VirtualHost>
EOF
    else
        sudo sed -i "s/Listen 80/Listen $puerto/" /usr/local/apache2/conf/httpd.conf
    fi

    # Iniciar Apache
    /usr/local/apache2/bin/apachectl start

    habilitar_puerto_firewall "$puerto"

    # Reemplazar el index.html de Apache con el código personalizado
    cat <<EOF | sudo tee /usr/local/apache2/htdocs/index.html > /dev/null
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>PERO QUE DISTINGUIDO PEDRI</title>
    <style>
        body {
            text-align: center;
            background-color: #004c98;
            color: white;
            font-family: Arial, sans-serif;
        }
        h1 {
            margin-top: 20px;
            font-size: 28px;
            font-weight: bold;
        }
        marquee {
            margin-top: 50px;
        }
        img {
            width: 300px;
            height: auto;
            border-radius: 10px;
            box-shadow: 0px 0px 10px rgba(255, 255, 255, 0.5);
            margin: 0 20px;
        }
    </style>
</head>
<body>
    <h1>PERO QUE DISTINGUIDO PEDRI</h1>
    <marquee behavior="scroll" direction="left" scrollamount="10">
        <img src="https://upload.wikimedia.org/wikipedia/en/4/47/FC_Barcelona_%28crest%29.svg" 
             alt="Escudo del FC Barcelona">
        <img src="https://pbs.twimg.com/media/E5ZP9L2X0Ak8gN2.jpg:large" 
             alt="Imagen del FC Barcelona">
        <img src="https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcSbFMCtfPdNYbLQL0fCGC_ntQuypliAFhJmcg&s" 
             alt="Pedri Distinguido">
    </marquee>
</body>
</html>
EOF
}

instalar_tomcat() {
    echo "Descargando e instalando Tomcat versión $version..."

    # Determinar la versión mayor para construir la URL correctamente
    mayor=$(echo "$version" | cut -d'.' -f1)
    url="https://dlcdn.apache.org/tomcat/tomcat-$mayor/v$version/bin/apache-tomcat-$version.tar.gz"

    # Verificar que la URL existe antes de descargar
    echo "Intentando descargar desde: $url"
    wget --spider "$url"
    if [[ $? -ne 0 ]]; then
        echo "Error: No se encontró el archivo en la URL proporcionada."
        return 1
    fi

    # Descargar Tomcat
    wget -q "$url" -O "/tmp/tomcat-$version.tar.gz"
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

    # Configurar solo HTTPS si el protocolo es HTTPS
    if [[ "$protocolo" == "HTTPS" ]]; then
        echo "Configurando solo HTTPS para Tomcat..."
        
        # Generar certificado y keystore usando las funciones
        configurar_ssl "tomcat"
        generar_keystore "tomcat"

        # Ruta del keystore generado
        keystore_file="/etc/ssl/tomcat/keystore.p12"

        # Configurar Tomcat para que solo tenga HTTPS en server.xml
        sudo sed -i "/<Connector port=\"8080\"/,+2d" /opt/tomcat/conf/server.xml  # Elimina el conector HTTP

        sudo sed -i "/<\/Service>/i\
        <Connector port=\"$puerto\" protocol=\"org.apache.coyote.http11.Http11NioProtocol\" SSLEnabled=\"true\">\n\
            <SSLHostConfig>\n\
                <Certificate certificateKeystoreFile=\"$keystore_file\"\n\
                             type=\"RSA\"\n\
                             certificateKeystorePassword=\"1234\" />\n\
            </SSLHostConfig>\n\
        </Connector>" /opt/tomcat/conf/server.xml

        echo "Tomcat ahora solo escuchará en HTTPS en el puerto $puerto."

    else
        # Configuración solo para HTTP (sin HTTPS)
        echo "Configurando Tomcat en HTTP..."
        sudo sed -i "s/Connector port=\"8080\"/Connector port=\"$puerto\"/" /opt/tomcat/conf/server.xml
    fi

    # Iniciar Tomcat
    /opt/tomcat/bin/startup.sh

    # Abrir el puerto en el firewall
    habilitar_puerto_firewall "$puerto"

    echo "Tomcat $version instalado y configurado en el puerto $puerto con protocolo $protocolo."
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

    # Descomprimir y compilar Nginx con SSL habilitado
    tar -xzf "/tmp/nginx-$version.tar.gz" -C /tmp
    cd "/tmp/nginx-$version" || exit 1

    echo "Compilando NGINX (esto puede tardar)..."
    ./configure --prefix=/usr/local/nginx --with-http_ssl_module > /dev/null
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

    # Configuración SSL y puerto
    if [[ "$protocolo" == "HTTPS" ]]; then
        # Generar el certificado SSL si no existe
        if [ ! -f "/etc/ssl/nginx/server.crt" ] || [ ! -f "/etc/ssl/nginx/server.key" ]; then
            echo "Generando certificado SSL/TLS autofirmado para Nginx..."
            configurar_ssl "nginx"
        fi

        # Configurar SSL en Nginx con la configuración proporcionada
        sudo bash -c "cat > /usr/local/nginx/conf/nginx.conf" <<EOF
worker_processes  1;

events {
    worker_connections  1024;
}

http {
    include       mime.types;
    default_type  application/octet-stream;

    sendfile        on;
    keepalive_timeout  65;

    server {
        listen       $puerto ssl;
        server_name  localhost;

        ssl_certificate /etc/ssl/nginx/server.crt;
        ssl_certificate_key /etc/ssl/nginx/server.key;

        location / {
            root   html;
            index  index.html index.htm;
        }

        error_page   500 502 503 504  /50x.html;
        location = /50x.html {
            root   html;
        }
    }
}
EOF
    else
        # Si no se requiere SSL, simplemente configura el puerto
        sudo sed -i "s/listen       80;/listen       $puerto;/g" /usr/local/nginx/conf/nginx.conf
    fi

    # Iniciar NGINX
    /usr/local/nginx/sbin/nginx

    habilitar_puerto_firewall "$puerto"

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

# Variables globales para almacenar las URLs dinámicas
tomcat_url_lts=""
tomcat_url_dev=""

# ========================
# Función para obtener las URLs de descarga de Tomcat
# ========================
obtener_urls_tomcat() {
    echo "Obteniendo URLs dinámicas de descarga desde el índice de Tomcat..."

    html=$(curl -s "https://tomcat.apache.org/index.html")

    # Extraer los enlaces de descarga de las versiones disponibles
    urls=$(echo "$html" | grep -oP 'https://tomcat.apache.org/download-\d+\.cgi')

    # Identificar la versión LTS y la versión de desarrollo
    tomcat_url_lts=""
    tomcat_url_dev=""

    while read -r url; do
        version_number=$(echo "$url" | grep -oP '\d+')

        # Consideramos que la versión estable (LTS) es la más baja numerada (actualmente Tomcat 10)
        if [[ "$version_number" -lt 11 ]]; then
            tomcat_url_lts="$url"
        fi

        # La versión de desarrollo (dev) es la más alta numerada (actualmente Tomcat 11)
        if [[ "$version_number" -eq 11 ]]; then
            tomcat_url_dev="$url"
        fi
    done <<< "$urls"

    echo "URL de la versión estable (LTS): $tomcat_url_lts"
    echo "URL de la versión de desarrollo: $tomcat_url_dev"
}

# ========================
# Función para obtener las últimas versiones de Tomcat (LTS y Dev)
# ========================
obtener_versiones_tomcat() {
    obtener_urls_tomcat  # Actualizamos las URLs dinámicamente antes de buscar versiones

    echo "Obteniendo versiones de Apache Tomcat desde las URLs detectadas..."

    # Obtener la última versión estable desde la página LTS
    html_lts=$(curl -s "$tomcat_url_lts")
    version_lts=$(echo "$html_lts" | grep -oP 'v\d+\.\d+\.\d+' | head -n 1 | sed 's/v//')

    # Obtener la última versión de desarrollo desde la página dev
    html_dev=$(curl -s "$tomcat_url_dev")
    version_dev=$(echo "$html_dev" | grep -oP 'v\d+\.\d+\.\d+' | head -n 1 | sed 's/v//')

    versions=("$version_lts" "$version_dev")

    echo "Versión estable (LTS): $version_lts"
    echo "Versión de desarrollo: $version_dev"
}


obtener_versiones_nginx() {
    echo "Obteniendo versiones de NGINX desde https://nginx.org/en/download.html"

    html=$(curl -s "https://nginx.org/en/download.html")

    # Extraer la versión Mainline
    version_mainline=$(echo "$html" | grep -A5 "Mainline version" | grep -oP 'nginx-\d+\.\d+\.\d+' | head -n1 | sed 's/nginx-//')

    # Extraer solo el major.minor de Mainline (por ejemplo, 1.27)
    mainline_major_minor=$(echo "$version_mainline" | cut -d '.' -f1,2)

    # Extraer la versión Stable, pero asegurando que no sea de la misma rama major.minor que la Mainline
    version_stable=$(echo "$html" | grep -A5 "Stable version" | grep -oP 'nginx-\d+\.\d+\.\d+' | grep -v "${mainline_major_minor}\." | head -n1 | sed 's/nginx-//')

    # Guardar en el array global versions
    versions=("$version_stable" "$version_mainline")

    echo "Versión estable (LTS): $version_stable"
    echo "Versión de desarrollo (Mainline): $version_mainline"
}

verificar_servicios() {
    echo -e "\n=================================="
    echo "   Verificando servicios HTTP    "
    echo "=================================="

    # Verificar Apache
    if [[ -f "/usr/local/apache2/bin/httpd" || -f "/usr/sbin/apache2" || -f "/usr/sbin/httpd" ]]; then
        echo "Apache está instalado"
        apache_version=$(/usr/local/apache2/bin/httpd -v 2>/dev/null | grep "Server version" | awk '{print $3}')
        [[ -z "$apache_version" ]] && apache_version=$(/usr/sbin/apache2 -v 2>/dev/null | grep "Server version" | awk '{print $3}')
        [[ -z "$apache_version" ]] && apache_version=$(/usr/sbin/httpd -v 2>/dev/null | grep "Server version" | awk '{print $3}')
        
        apache_puertos=$(sudo ss -tlnp | grep httpd | awk '{print $4}' | grep -oE '[0-9]+$' | tr '\n' ', ')
        [[ -z "$apache_puertos" ]] && apache_puertos="No encontrado"
        
        echo "   Versión: ${apache_version:-No encontrada}"
        echo "   Puertos: ${apache_puertos%, }"
        echo "----------------------------------"
    fi

    # Verificar Nginx
    if [[ -f "/usr/local/nginx/sbin/nginx" || -f "/usr/sbin/nginx" || -f "/usr/local/sbin/nginx" ]]; then
        echo "Nginx está instalado"
        nginx_version=$(/usr/local/nginx/sbin/nginx -v 2>&1 | awk -F/ '{print $2}')
        [[ -z "$nginx_version" ]] && nginx_version=$(/usr/sbin/nginx -v 2>&1 | awk -F/ '{print $2}')
        [[ -z "$nginx_version" ]] && nginx_version=$(/usr/local/sbin/nginx -v 2>&1 | awk -F/ '{print $2}')
        
        # Buscar Nginx en cualquier puerto
        nginx_puertos=$(sudo ss -tlnp | grep -E 'nginx|/usr/local/nginx/sbin/nginx' | awk '{print $4}' | grep -oE '[0-9]+$' | tr '\n' ', ')
        [[ -z "$nginx_puertos" ]] && nginx_puertos="No encontrado"
        
        echo "   Versión: ${nginx_version:-No encontrada}"
        echo "   Puertos: ${nginx_puertos%, }"
        echo "----------------------------------"
    fi

    # Verificar Tomcat
    if [[ -d "/opt/tomcat" || -d "/usr/local/tomcat" ]]; then
        echo "Tomcat está instalado"
        tomcat_version=$(/opt/tomcat/bin/version.sh 2>/dev/null | grep "Server number" | awk '{print $3}')
        [[ -z "$tomcat_version" ]] && tomcat_version=$(/usr/local/tomcat/bin/version.sh 2>/dev/null | grep "Server number" | awk '{print $3}')

        tomcat_puertos=$(sudo ss -tlnp | grep java | awk '{print $4}' | grep -oE '[0-9]+$' | tr '\n' ', ')
        [[ -z "$tomcat_puertos" ]] && tomcat_puertos="No encontrado"

        echo "   Versión: ${tomcat_version:-No encontrada}"
        echo "   Puertos: ${tomcat_puertos%, }"
        echo "----------------------------------"
    fi

    # Si no se encontró ningún servicio
    if [[ -z "$(ps aux | grep -E 'nginx|httpd|apache2|tomcat|java' | grep -v grep)" ]]; then
        echo "No se detectaron servicios HTTP en ejecución."
    fi
}


#------------------------------
# HTTPS
#-----------------------------
protocolo=""  # Nuevo: Guardará si el usuario elige HTTP o HTTPS


# Función para preguntar si se desea HTTP o HTTPS
seleccionar_protocolo() {
    echo "Seleccione el protocolo a utilizar:"
    echo "1.- HTTP"
    echo "2.- HTTPS (con certificado autofirmado)"
    read -p "Opción: " opcion

    case $opcion in
        1)
            protocolo="HTTP"
            ;;
        2)
            protocolo="HTTPS"
            ;;
        *)
            echo "Opción no válida. Intente de nuevo."
            seleccionar_protocolo
            ;;
    esac
}

configurar_ssl() {
    local servicio=$1
    local cert_dir="/etc/ssl/$servicio"
    
    echo "Generando certificado SSL/TLS autofirmado para $servicio..."
    
    sudo mkdir -p "$cert_dir"

    sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout "$cert_dir/server.key" \
        -out "$cert_dir/server.crt" \
        -subj "/C=US/ST=Example/L=City/O=Company/CN=localhost"

    echo "Certificado generado en: $cert_dir"
}

generar_keystore() {
    local servicio=$1
    local cert_dir="/etc/ssl/$servicio"
    local keystore_pass="1234"
    local keystore_file="$cert_dir/keystore.p12"

    echo "Convirtiendo certificado SSL a formato PKCS12 para $servicio..."

    sudo openssl pkcs12 -export -in "$cert_dir/server.crt" -inkey "$cert_dir/server.key" \
        -out "$keystore_file" -name tomcat -password pass:$keystore_pass

    # Ajustar permisos
    sudo chmod 644 "$keystore_file"
    sudo chown root:root "$keystore_file"

    echo "Keystore generado en: $keystore_file"
}

# Configuración del servidor FTP
FTP_SERVER="192.168.1.128"  # Cambia por la IP de tu servidor
FTP_USER="linux"            # O "windows" según corresponda
FTP_PASS="1234"              # Contraseña

seleccionar_version_ftp() {
    local carpeta_ftp

    # Ajustar la ruta del FTP según el servicio seleccionado
    case "$servicio" in
        "Apache") carpeta_ftp="apache" ;;
        "Tomcat") carpeta_ftp="tomcat" ;;
        "Nginx") carpeta_ftp="nginx" ;;
        *) echo "Servicio no válido."; return ;;
    esac

    echo "Conectando al servidor FTP para listar versiones de $servicio..."

    # Obtener la lista de versiones disponibles en la carpeta FTP
    versiones_disponibles=$(curl -s --user "$FTP_USER:$FTP_PASS" "ftp://$FTP_SERVER/linux/$carpeta_ftp/" | awk '{print $NF}' | grep -E '^(apache-tomcat-[0-9]+\.[0-9]+\.[0-9]+\.tar\.gz|nginx-[0-9]+\.[0-9]+\.[0-9]+\.tar\.gz|httpd-[0-9]+\.[0-9]+(\.[0-9]+)?\.tar\.gz)$')

    # Verificar si se encontraron archivos
    if [[ -z "$versiones_disponibles" ]]; then
        echo "No se encontraron versiones disponibles en el servidor FTP para $servicio."
        return
    fi

    echo "Seleccione la versión disponible:"
    select archivo in $versiones_disponibles; do
        if [[ -n "$archivo" ]]; then
            version="$archivo"  # Guardamos solo el nombre del archivo exacto
            echo "Versión seleccionada: $version"
            break
        else
            echo "Opción no válida, intente de nuevo."
        fi
    done
}

proceso_instalacion_ftp() {
    if [[ -z "$servicio" || -z "$version" || -z "$puerto" ]]; then
        echo "Debe seleccionar el servicio, la versión y el puerto antes de proceder con la instalación."
        return
    fi

    # Validar dependencias necesarias
    if ! comando_existente "gcc" || ! comando_existente "make" || ! comando_existente "wget" || ! comando_existente "curl"; then
        echo "Faltan dependencias esenciales para la instalación."
        echo "Por favor, ejecute la opción 1 del menú (Instalar dependencias necesarias) antes de continuar."
        return 1
    fi

    echo "Iniciando instalación desde FTP de $servicio versión $version en el puerto $puerto..."

    case $servicio in
        "Apache")
            instalar_apache_ftp
            ;;
        "Tomcat")
            instalar_tomcat_ftp
            ;;
        "Nginx")
            instalar_nginx_ftp
            ;;
        *)
            echo "Servicio desconocido. No se puede proceder con la instalación."
            return 1
            ;;
    esac

    echo "Instalación completada para $servicio versión $version en el puerto $puerto."

    # Limpiar variables globales
    unset servicio
    unset version
    unset puerto
}

instalar_apache_ftp() {
    echo "Descargando e instalando Apache versión $version desde el servidor FTP..."

    FTP_PATH="linux/apache"  # Se eliminó 'linux/'

    # Descargar Apache desde el FTP usando las constantes globales
    wget --ftp-user="$FTP_USER" --ftp-password="$FTP_PASS" "ftp://$FTP_SERVER/$FTP_PATH/$version" -O "/tmp/$version"
    if [[ $? -ne 0 ]]; then
        echo "Error al descargar Apache $version desde FTP."
        return 1
    fi

    # Extraer y compilar Apache
    tar -xzf "/tmp/$version" -C /tmp
    extracted_folder="/tmp/${version%.tar.gz}"  # Elimina la extensión .tar.gz para obtener la carpeta correcta

    if [[ ! -d "$extracted_folder" ]]; then
        echo "Error: No se pudo encontrar la carpeta extraída $extracted_folder."
        return 1
    fi

    cd "$extracted_folder" || exit 1

    echo "Compilando Apache (esto puede tardar)..."
    ./configure --prefix=/usr/local/apache2 --enable-so --enable-ssl > /dev/null
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

    # Configurar puerto y SSL si es necesario
    if [[ "$protocolo" == "HTTPS" ]]; then
        configurar_ssl "apache"
        sudo bash -c "cat >> /usr/local/apache2/conf/httpd.conf" <<EOF
LoadModule ssl_module modules/mod_ssl.so
Listen $puerto
<VirtualHost *:$puerto>
    DocumentRoot "/usr/local/apache2/htdocs"
    SSLEngine on
    SSLCertificateFile /etc/ssl/apache/server.crt
    SSLCertificateKeyFile /etc/ssl/apache/server.key
</VirtualHost>
EOF
    else
        sudo sed -i "s/Listen 80/Listen $puerto/" /usr/local/apache2/conf/httpd.conf
    fi

    # Iniciar Apache
    /usr/local/apache2/bin/apachectl start

    habilitar_puerto_firewall "$puerto"

    # Reemplazar el index.html de Apache con el código personalizado
    cat <<EOF | sudo tee /usr/local/apache2/htdocs/index.html > /dev/null
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>PERO QUE DISTINGUIDO PEDRI</title>
    <style>
        body {
            text-align: center;
            background-color: #004c98;
            color: white;
            font-family: Arial, sans-serif;
        }
        h1 {
            margin-top: 20px;
            font-size: 28px;
            font-weight: bold;
        }
        marquee {
            margin-top: 50px;
        }
        img {
            width: 300px;
            height: auto;
            border-radius: 10px;
            box-shadow: 0px 0px 10px rgba(255, 255, 255, 0.5);
            margin: 0 20px;
        }
    </style>
</head>
<body>
    <h1>PERO QUE DISTINGUIDO PEDRI</h1>
    <marquee behavior="scroll" direction="left" scrollamount="10">
        <img src="https://upload.wikimedia.org/wikipedia/en/4/47/FC_Barcelona_%28crest%29.svg" 
             alt="Escudo del FC Barcelona">
        <img src="https://pbs.twimg.com/media/E5ZP9L2X0Ak8gN2.jpg:large" 
             alt="Imagen del FC Barcelona">
        <img src="https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcSbFMCtfPdNYbLQL0fCGC_ntQuypliAFhJmcg&s" 
             alt="Pedri Distinguido">
    </marquee>
</body>
</html>
EOF
}


instalar_tomcat_ftp() {
    echo "Descargando e instalando Tomcat versión $version desde el servidor FTP..."

    FTP_PATH="linux/tomcat"  # Se eliminó 'linux/'

    # Descargar Tomcat desde el FTP usando las constantes globales
    wget --ftp-user="$FTP_USER" --ftp-password="$FTP_PASS" "ftp://$FTP_SERVER/$FTP_PATH/$version" -O "/tmp/$version"
    if [[ $? -ne 0 ]]; then
        echo "Error al descargar Tomcat $version desde FTP."
        return 1
    fi

    # Limpiar instalación previa (si existe)
    if [[ -d "/opt/tomcat" ]]; then
        echo "Eliminando instalación previa de Tomcat..."
        sudo rm -rf /opt/tomcat
    fi

    sudo mkdir -p /opt/tomcat
    sudo tar -xzf "/tmp/$version" -C /opt/tomcat --strip-components=1

    # Configurar solo HTTPS si el protocolo es HTTPS
    if [[ "$protocolo" == "HTTPS" ]]; then
        echo "Configurando solo HTTPS para Tomcat..."
        
        # Generar certificado y keystore usando las funciones
        configurar_ssl "tomcat"
        generar_keystore "tomcat"

        # Ruta del keystore generado
        keystore_file="/etc/ssl/tomcat/keystore.p12"

        # Configurar Tomcat para que solo tenga HTTPS en server.xml
        sudo sed -i "/<Connector port=\"8080\"/,+2d" /opt/tomcat/conf/server.xml  # Elimina el conector HTTP

        sudo sed -i "/<\/Service>/i\
        <Connector port=\"$puerto\" protocol=\"org.apache.coyote.http11.Http11NioProtocol\" SSLEnabled=\"true\">\n\
            <SSLHostConfig>\n\
                <Certificate certificateKeystoreFile=\"$keystore_file\"\n\
                             type=\"RSA\"\n\
                             certificateKeystorePassword=\"1234\" />\n\
            </SSLHostConfig>\n\
        </Connector>" /opt/tomcat/conf/server.xml

        echo "Tomcat ahora solo escuchará en HTTPS en el puerto $puerto."

    else
        # Configuración solo para HTTP (sin HTTPS)
        echo "Configurando Tomcat en HTTP..."
        sudo sed -i "s/Connector port=\"8080\"/Connector port=\"$puerto\"/" /opt/tomcat/conf/server.xml
    fi

    # Iniciar Tomcat
    /opt/tomcat/bin/startup.sh

    # Abrir el puerto en el firewall
    habilitar_puerto_firewall "$puerto"

    echo "Tomcat $version instalado y configurado en el puerto $puerto con protocolo $protocolo."
}

instalar_nginx_ftp() {
    echo "Descargando e instalando NGINX versión $version desde el servidor FTP..."

    FTP_PATH="linux/nginx"  # Se eliminó 'linux/'

    # Descargar NGINX desde el FTP usando las constantes globales
    wget --ftp-user="$FTP_USER" --ftp-password="$FTP_PASS" "ftp://$FTP_SERVER/$FTP_PATH/$version" -O "/tmp/$version"
    if [[ $? -ne 0 ]]; then
        echo "Error al descargar NGINX $version desde FTP."
        return 1
    fi

    # Limpiar instalación previa (si existe)
    if [[ -d "/usr/local/nginx" ]]; then
        echo "Eliminando instalación previa de NGINX..."
        sudo rm -rf /usr/local/nginx
    fi

    # Extraer y compilar Nginx con SSL habilitado
    tar -xzf "/tmp/$version" -C /tmp
    cd "/tmp/${version%.tar.gz}" || exit 1  # Elimina la extensión .tar.gz para obtener la carpeta correcta

    echo "Compilando NGINX (esto puede tardar)..."
    ./configure --prefix=/usr/local/nginx --with-http_ssl_module > /dev/null
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

    # Configuración SSL y puerto
    if [[ "$protocolo" == "HTTPS" ]]; then
        # Generar el certificado SSL si no existe
        if [ ! -f "/etc/ssl/nginx/server.crt" ] || [ ! -f "/etc/ssl/nginx/server.key" ]; then
            echo "Generando certificado SSL/TLS autofirmado para Nginx..."
            configurar_ssl "nginx"
        fi

        # Configurar SSL en Nginx con la configuración proporcionada
        sudo bash -c "cat > /usr/local/nginx/conf/nginx.conf" <<EOF
worker_processes  1;

events {
    worker_connections  1024;
}

http {
    include       mime.types;
    default_type  application/octet-stream;

    sendfile        on;
    keepalive_timeout  65;

    server {
        listen       $puerto ssl;
        server_name  localhost;

        ssl_certificate /etc/ssl/nginx/server.crt;
        ssl_certificate_key /etc/ssl/nginx/server.key;

        location / {
            root   html;
            index  index.html index.htm;
        }

        error_page   500 502 503 504  /50x.html;
        location = /50x.html {
            root   html;
        }
    }
}
EOF
    else
        # Si no se requiere SSL, simplemente configura el puerto
        sudo sed -i "s/listen       80;/listen       $puerto;/g" /usr/local/nginx/conf/nginx.conf
    fi

    # Iniciar NGINX
    /usr/local/nginx/sbin/nginx

    habilitar_puerto_firewall "$puerto"

    echo "NGINX $version instalado y configurado en el puerto $puerto."
}
