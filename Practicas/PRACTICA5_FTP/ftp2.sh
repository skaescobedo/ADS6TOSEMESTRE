#!/bin/bash

# Importar funciones
source ./librerianueva.sh

# Función para mostrar el menú
mostrar_menu() {
    echo "==========================================="
    echo "   Menú de Configuración del Servidor FTP   "
    echo "==========================================="
    echo "1) Instalar dependencias, configurar vsftpd y firewall"
    echo "2) Crear estructura de directorios"
    echo "3) Crear usuario"
    echo "4) Salir"
    echo "==========================================="
    echo -n "Seleccione una opción [1-4]: "
}

# Flujo principal
while true; do
    mostrar_menu
    read opcion

    case $opcion in
        1)
            echo "Instalando dependencias, configurando vsftpd y configurando firewall..."
            instalar_dependencias
            configurar_vsftpd
            configurar_firewall_y_vsftpd
            ;;
        2)
            echo "Creando estructura de directorios..."
            crear_estructura_directorios
            ;;
        3)
            echo "Creando usuario..."
            crear_usuario
            ;;
        4)
            echo "Saliendo..."
            break
            ;;
        *)
            echo "Opción no válida, por favor seleccione entre 1 y 4."
            ;;
    esac
done

echo "Servidor FTP configurado correctamente."
