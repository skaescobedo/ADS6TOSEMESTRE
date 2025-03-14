#!/bin/bash

# Importar funciones
source ./librerianueva.sh

# Función para mostrar el menú
mostrar_menu() {
    clear
    echo "==========================================="
    echo "   Menú de Configuración del Servidor FTP   "
    echo "==========================================="
    echo "1) Instalar dependencias, configurar vsftpd y firewall"
    echo "2) Crear estructura de directorios"
    echo "3) Crear usuario"
    echo "4) Eliminar usuario"                
    echo "5) Salir"
    echo "==========================================="
    echo -n "Seleccione una opción [1-5]: "
}

# Flujo principal
while true; do
    mostrar_menu
    read opcion

    case $opcion in
        1)
            echo "Instalando dependencias, configurando vsftpd y configurando firewall..."
            instalar_dependencias

            # Preguntar si se desea habilitar SSL antes de configurar vsftpd
            read -p "¿Desea habilitar SSL para FTPS? (s/n): " respuesta_ssl

            configurar_vsftpd "$respuesta_ssl"
            configurar_firewall_y_vsftpd

            read -p "Presione cualquier tecla para continuar..." -n 1 -s
            ;;
        2)
            echo "Creando estructura de directorios..."
            crear_estructura_directorios
            read -p "Presione cualquier tecla para continuar..." -n 1 -s
            ;;
        3)
            echo "Creando usuario..."
            crear_usuario
            read -p "Presione cualquier tecla para continuar..." -n 1 -s
            ;;
        4)
            echo "Eliminando usuario..."
            eliminar_usuario    
            read -p "Presione cualquier tecla para continuar..." -n 1 -s
            ;;
        5)
            echo "Saliendo..."
            break
            ;;
        *)
            echo "Opción no válida, por favor seleccione entre 1 y 5."
            read -p "Presione cualquier tecla para continuar..." -n 1 -s
            ;;
    esac
done

echo "Servidor FTP configurado correctamente."
