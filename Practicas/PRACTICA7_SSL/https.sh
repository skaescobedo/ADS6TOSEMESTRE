#!/bin/bash

# Cargar funciones desde librerianueva.sh
source ./librerianueva.sh

# ========================
# Menú interactivo
# ========================

mostrar_menu() {
    clear  # Limpia la pantalla cada vez que se muestra el menú
    echo "=================================="
    echo "        Instalador HTTP/HTTPS      "
    echo "=================================="
    echo "0. Instalar dependencias necesarias"
    echo "1. Seleccionar Protocolo (HTTP/HTTPS)"
    echo "2. Seleccionar Servicio"
    echo "3. Seleccionar Versión"
    echo "4. Configurar Puerto"
    echo "5. Proceder con la Instalación"
    echo "6. Verificar servicios instalados"
    echo "7. Salir"
    echo "=================================="
}

# ========================
# Bucle principal del menú
# ========================

while true; do
    mostrar_menu
    read -p "Seleccione una opción: " opcion_menu

    case $opcion_menu in
        0) instalar_dependencias_https;;
        1) seleccionar_protocolo;;
        2) seleccionar_servicio;;
        3) seleccionar_version;;
        4) preguntar_puerto;;
        5) 
            echo "=================================="
            echo "      Resumen de la instalación   "
            echo "=================================="
            echo "Protocolo seleccionado: $protocolo"
            echo "Servicio seleccionado: $servicio"
            echo "Versión seleccionada: $version"
            echo "Puerto configurado: $puerto"
            echo "=================================="
            read -p "¿Desea proceder con la instalación? (s/n): " confirmacion
            if [[ "$confirmacion" != "s" ]]; then
                echo "Instalación cancelada."
            else
                proceso_instalacion
            fi
            ;;
        6) verificar_servicios;;
        7) echo "Saliendo..."; exit 0;;
        *) echo "Opción no válida. Intente de nuevo.";;
    esac
    read -p "Presione Enter para continuar..."
done
