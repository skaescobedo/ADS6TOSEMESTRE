#!/bin/bash

# Importar funciones
source ./librerianueva.sh

# Función para mostrar el menú
mostrar_menu() {
    clear
    echo "==========================================="
    echo "   Menú de Configuración del Servidor FTP   "
    echo "==========================================="
    echo "1) Instalar FTP COMPLETO"
    echo "2) Crear usuario"
    echo "3) Eliminar usuario"                
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
            instalar_dependencias_ftp

           # Preguntar si se desea habilitar SSL antes de configurar vsftpd
            while true; do
                read -p "¿Desea habilitar SSL para FTPS? (s/n): " respuesta_ssl
                respuesta_ssl=$(echo "$respuesta_ssl" | tr '[:upper:]' '[:lower:]')  # Convertir a minúsculas

                if [[ "$respuesta_ssl" == "s" || "$respuesta_ssl" == "n" ]]; then
                    break  # Salir del bucle si la respuesta es válida
                else
                    echo "Por favor, ingrese 's' para sí o 'n' para no."
                fi
            done

            configurar_vsftpd "$respuesta_ssl"
            crear_estructura_directorios

            read -p "Presione cualquier tecla para continuar..." -n 1 -s
            ;;
        2)
            echo "Creando usuario..."
            crear_usuario
            read -p "Presione cualquier tecla para continuar..." -n 1 -s
            ;;
        3)
            echo "Eliminando usuario..."
            eliminar_usuario    
            read -p "Presione cualquier tecla para continuar..." -n 1 -s
            ;;
        4)
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
