#!/bin/bash

# Cargar funciones desde librerianueva.sh
source ./librerianueva.sh

# ========================
# Menú interactivo
# ========================

mostrar_menu() {
    echo "=================================="
    echo "        Instalador HTTP           "
    echo "=================================="
    echo "1. Seleccionar Servicio"
    echo "2. Seleccionar Versión"
    echo "3. Configurar Puerto"
    echo "4. Proceder con la Instalación"
    echo "5. Salir"
    echo "=================================="
}

# ========================
# Bucle principal del menú
# ========================

while true; do
    mostrar_menu
    read -p "Seleccione una opción: " opcion_menu

    case $opcion_menu in
        1) seleccionar_servicio ;;
        2) seleccionar_version ;;
        3) preguntar_puerto ;;
        4) proceso_instalacion ;;
        5) 
            echo "Saliendo..."
            exit 0
            ;;
        *) 
            echo "Opción no válida. Intente de nuevo."
            ;;
    esac
done
