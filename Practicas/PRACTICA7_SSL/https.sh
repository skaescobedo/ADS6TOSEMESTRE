#!/bin/bash

# Cargar funciones desde librerianueva.sh
source ./librerianueva.sh

# ========================
# Menú Web (Descarga de la Web)
# ========================
menu_web() {
    while true; do
        clear
        echo "=================================="
        echo "        Instalador desde Web      "
        echo "=================================="
        echo "1. Seleccionar Protocolo (HTTP/HTTPS)"
        echo "2. Seleccionar Servicio"
        echo "3. Seleccionar Versión"
        echo "4. Configurar Puerto"
        echo "5. Proceder con la Instalación"
        echo "6. Verificar servicios instalados"
        echo "7. Volver al menú principal"
        echo "=================================="

        read -p "Seleccione una opción: " opcion_menu

        case $opcion_menu in
            1) seleccionar_protocolo ;;
            2) seleccionar_servicio ;;
            3) seleccionar_version ;;
            4) preguntar_puerto ;;
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
                    proceso_instalacion_web  # Llamada a función de instalación desde la web
                fi
                ;;
            6) verificar_servicios ;;
            7) return ;;  # Vuelve al menú principal
            *) echo "Opción no válida. Intente de nuevo." ;;
        esac
        read -p "Presione Enter para continuar..."
    done
}

# ========================
# Menú FTP (Descarga desde Servidor FTP)
# ========================
menu_ftp() {
    while true; do
        clear
        echo "=================================="
        echo "        Instalador desde FTP      "
        echo "=================================="
        echo "1. Seleccionar Protocolo (HTTP/HTTPS)"
        echo "2. Seleccionar Servicio"
        echo "3. Seleccionar Versión"
        echo "4. Configurar Puerto"
        echo "5. Proceder con la Instalación"
        echo "6. Verificar servicios instalados"
        echo "7. Volver al menú principal"
        echo "=================================="

        read -p "Seleccione una opción: " opcion_menu

        case $opcion_menu in
            1) seleccionar_protocolo ;;
            2) seleccionar_servicio "ftp" ;;
            3) seleccionar_version_ftp ;;
            4) preguntar_puerto ;;
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
                    proceso_instalacion_ftp  # Llamada a función de instalación desde FTP
                fi
                ;;
            6) verificar_servicios ;;
            7) return ;;  # Vuelve al menú principal
            *) echo "Opción no válida. Intente de nuevo." ;;
        esac
        read -p "Presione Enter para continuar..."
    done
}

# ========================
# Pantalla Inicial
# ========================
mostrar_menu_inicio() {
    clear
    echo "=================================="
    echo "  Seleccione el Método de Instalación"
    echo "=================================="
    echo "1. Instalar dependencias necesarias"
    echo "2. Descargar e instalar desde la Web"
    echo "3. Descargar e instalar desde un Servidor FTP"
    echo "4. Salir"
    echo "=================================="
}

while true; do
    mostrar_menu_inicio
    read -p "Seleccione una opción: " opcion_inicio

    case $opcion_inicio in
        1) instalar_dependencias_https ;;
        2) menu_web ;;
        3) menu_ftp ;;
        4) echo "Saliendo..."; exit 0 ;;
        *) echo "Opción no válida. Intente de nuevo." ;;
    esac
    read -p "Presione Enter para continuar..."
done
