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

instalar_y_verificar_postfix() {
    echo "Instalando Postfix..."
    sudo apt update && sudo apt install postfix -y

    if [[ $? -ne 0 ]]; then
        echo "Error al instalar Postfix."
        return 1
    fi

    echo "Verificando estado del servicio Postfix..."
    estado=$(systemctl is-active postfix)

    if [[ "$estado" == "active" ]]; then
        echo "Postfix está activo y funcionando correctamente."
        return 0
    else
        echo "Postfix no está activo. Intentando iniciarlo..."
        sudo systemctl start postfix
        sudo systemctl enable postfix

        estado_postfix=$(systemctl is-active postfix)
        if [[ "$estado_postfix" == "active" ]]; then
            echo "Postfix ha sido iniciado correctamente."
            return 0
        else
            echo "No se pudo iniciar Postfix."
            return 1
        fi
    fi
}

crear_usuario_sistema() {
    nombre_usuario=$1

    validar_nombre_usuario "$nombre_usuario"
    if [[ $? -ne 0 ]]; then
        echo "No se puede crear el usuario debido a errores en el nombre."
        return 1
    fi

    echo "Creando el usuario '$nombre_usuario'..."
    sudo adduser --gecos "" "$nombre_usuario"
    if [[ $? -eq 0 ]]; then
        echo "Usuario '$nombre_usuario' creado correctamente."
        return 0
    else
        echo "Ocurrió un error al crear el usuario."
        return 1
    fi
}
