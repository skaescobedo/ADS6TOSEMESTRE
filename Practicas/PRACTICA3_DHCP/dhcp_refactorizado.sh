#!/bin/bash

# Importar el módulo con las funciones
source dhcp_modulo.sh

# Instalar paquetes necesarios
sudo apt update && sudo apt install -y isc-dhcp-server ipcalc

# Solicitar datos al usuario
solicitar_interfaz
solicitar_ip "Ingrese la dirección IP estática para $INTERFAZ: " IP_ESTATICA
solicitar_prefijo
calcular_datos_red
solicitar_ip "Ingrese la dirección del gateway: " PUERTA_ENLACE
solicitar_ip "Ingrese la dirección del servidor DNS primario: " DNS_PRIMARIO
solicitar_ip "Ingrese la dirección del servidor DNS secundario (opcional): " DNS_SECUNDARIO
solicitar_ip "Ingrese la dirección de inicio del rango DHCP: " RANGO_INICIO
solicitar_ip "Ingrese la dirección final del rango DHCP: " RANGO_FIN

# Configurar la red y el servidor DHCP
configurar_netplan
configurar_dhcp

echo "Configuración del servidor DHCP completada. Verifique el estado con: systemctl status isc-dhcp-server"
