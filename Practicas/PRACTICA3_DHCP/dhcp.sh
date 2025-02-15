#!/bin/bash

# Instalar paquetes necesarios
sudo apt update && sudo apt install -y isc-dhcp-server

# Solicitar interfaz de red
read -p "Ingrese la interfaz de red para el servidor DHCP (ejemplo: eth0): " INTERFACE

# Verificar si la interfaz ingresada es válida
if ! ip link show | grep -q "$INTERFACE"; then
    echo "Error: La interfaz de red $INTERFACE no existe."
    exit 1
fi

# Solicitar la configuración de IP estática para la interfaz con validaciones
while true; do
    read -p "Ingrese la dirección IP estática para $INTERFACE (ejemplo: 192.168.1.10): " STATIC_IP
    if [[ $STATIC_IP =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
        break
    else
        echo "Error: Formato de IP inválido. Intente nuevamente."
    fi
done

while true; do
    read -p "Ingrese el prefijo de la máscara de subred (ejemplo: 24 para 255.255.255.0): " PREFIX
    if [[ $PREFIX =~ ^[0-9]{1,2}$ ]] && [ $PREFIX -ge 1 ] && [ $PREFIX -le 32 ]; then
        break
    else
        echo "Error: Prefijo inválido. Debe estar entre 1 y 32."
    fi
done

while true; do
    read -p "Ingrese la dirección del gateway (ejemplo: 192.168.1.1): " GATEWAY
    if [[ $GATEWAY =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
        break
    else
        echo "Error: Formato de IP inválido para el gateway. Intente nuevamente."
    fi
done

while true; do
    read -p "Ingrese la dirección del servidor DNS primario (ejemplo: 8.8.8.8): " DNS1
    if [[ $DNS1 =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
        break
    else
        echo "Error: Formato de IP inválido para el DNS. Intente nuevamente."
    fi
done

while true; do
    read -p "Ingrese la dirección del servidor DNS secundario (opcional, ejemplo: 8.8.4.4): " DNS2
    if [[ -z "$DNS2" || $DNS2 =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
        break
    else
        echo "Error: Formato de IP inválido para el DNS secundario. Intente nuevamente."
    fi
done

# Configurar la IP estática en Netplan con el formato 50-cloud-init.yaml
NETPLAN_FILE="/etc/netplan/50-cloud-init.yaml"
echo "Configurando IP estática en $INTERFACE..."
echo "network:
  ethernets:
    $INTERFACE:
      dhcp4: false
      addresses: [$STATIC_IP/$PREFIX]
      routes:
        - to: default
          via: $GATEWAY
      nameservers:
        addresses: [$DNS1, $DNS2]
  version: 2" | sudo tee $NETPLAN_FILE > /dev/null

# Aplicar configuración de Netplan
sudo netplan apply
