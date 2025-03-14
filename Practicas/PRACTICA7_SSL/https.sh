#!/bin/bash

# Cargar funciones desde librerianueva.sh
source ./librerianueva.sh

# ========================
# Menú interactivo
# ========================

mostrar_menu() {
    clear  # Limpia la pantalla cada vez que se muestra el menú
    echo "=================================="
    echo "        Instalador HTTP           "
    echo "=================================="
    echo "0. Instalar dependencias necesarias"
    echo "1. Seleccionar Origen de Descarga (FTP o Web)"
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
        0) 
            instalar_dependencias
            read -p "Presione Enter para continuar..."
            ;;
        1) 
            seleccionar_origen
            read -p "Presione Enter para continuar..."
            ;;
        2) 
            seleccionar_servicio
            read -p "Presione Enter para continuar..."
            ;;
        3) 
            if [[ "$origen" == "Web" ]]; then
                seleccionar_version
            elif [[ "$origen" == "FTP" ]]; then
                seleccionar_version_ftp
            else
                echo "Debe seleccionar un origen de descarga antes de elegir la versión."
            fi
            read -p "Presione Enter para continuar..."
            ;;
        4) 
            preguntar_puerto
            read -p "Presione Enter para continuar..."
            ;;
        5) 
            # Mostrar resumen antes de proceder
            echo "=================================="
            echo "      Resumen de la instalación   "
            echo "=================================="
            echo "Origen de descarga: $origen"
            echo "Servicio seleccionado: $servicio"
            echo "Versión seleccionada: $version"
            echo "Puerto configurado: $puerto"
            echo "=================================="

            # Preguntar si se desea activar SSL antes de proceder con la instalación
            read -p "¿Desea activar SSL para este servicio? (s/n): " respuesta_ssl
            if [[ "$respuesta_ssl" == "s" ]]; then
                ssl_activo="Sí"
                generar_ssl
            else
                ssl_activo="No"
            fi

            echo "SSL Activado: $ssl_activo"
            echo "=================================="

            read -p "¿Desea proceder con la instalación? (s/n): " confirmacion
            if [[ "$confirmacion" != "s" ]]; then
                echo "Instalación cancelada."
            else
                proceso_instalacion
            fi
            read -p "Presione Enter para continuar..."
            ;;
        6) 
            verificar_servicios
            read -p "Presione Enter para continuar..."
            ;;
        7) 
            echo "Saliendo..."
            exit 0
            ;;
        *) 
            echo "Opción no válida. Intente de nuevo."
            read -p "Presione Enter para continuar..."
            ;;
    esac
done
