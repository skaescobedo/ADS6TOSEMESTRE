#!/bin/bash

# Importar el módulo con las funciones
source dhcp_modulo.sh

# Instalación de Bind9
echo "[INFO] Instalando Bind9..."
sudo apt update && sudo apt install -y bind9 bind9utils
if [ $? -ne 0 ]; then
    echo "[ERROR] No se pudo instalar Bind9."
    exit 1
fi

# Solicitar configuración estática
solicitar_interfaz
solicitar_ip "Ingrese la dirección IP estática para $INTERFAZ: " IP_ESTATICA
solicitar_prefijo
calcular_datos_red
solicitar_ip "Ingrese la dirección del gateway: " PUERTA_ENLACE
solicitar_ip "Ingrese la dirección del servidor DNS primario: " DNS_PRIMARIO
solicitar_ip "Ingrese la dirección del servidor DNS secundario (opcional): " DNS_SECUNDARIO

# Aplicar configuración de red estática
configurar_netplan

# Configurar Bind9 con las direcciones DNS ingresadas
configurar_bind9

echo "[INFO] Configuración de Bind9 completada. Verifique con: nslookup reprobados.com $DNS_PRIMARIO"
