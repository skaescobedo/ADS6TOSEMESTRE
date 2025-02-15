#!/bin/bash

# Instalar paquetes necesarios
sudo apt update && sudo apt install -y isc-dhcp-server ipcalc

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

# Calcular la máscara de red a partir del prefijo
NETMASK=$(ipcalc $STATIC_IP/$PREFIX | grep -oP 'Netmask:\s+\K[0-9.]+')

# Mostrar la máscara de red antes de leer el rango de direcciones IP
echo "La máscara de red calculada es: $NETMASK"

# Solicitar el rango de direcciones IP para asignar
read -p "Ingrese la dirección de red (ejemplo: 192.168.1.0): " NETWORK
read -p "Ingrese el rango de IPs para asignar (ejemplo: 192.168.1.100 192.168.1.200): " RANGE

# Configurar la interfaz de red
sudo sed -i "s/^INTERFACESv4=.*/INTERFACESv4=\"$INTERFACE\"/" /etc/default/isc-dhcp-server

# Crear configuración DHCP
cat <<EOT | sudo tee /etc/dhcp/dhcpd.conf
option domain-name "localdomain";
option domain-name-servers $DNS1, $DNS2;
default-lease-time 600;
max-lease-time 7200;

subnet $NETWORK netmask $NETMASK {
    range $RANGE;
    option routers $GATEWAY;
    option subnet-mask $NETMASK;
    option broadcast-address $(echo $NETWORK | awk -F. '{print $1"."$2"."$3".255"}');
    option domain-name-servers $DNS1, $DNS2;
}
EOT

# Reiniciar y habilitar el servicio DHCP
sudo systemctl restart isc-dhcp-server

echo "Configuración del servidor DHCP completada. Verifique que el servicio esté corriendo con: systemctl status isc-dhcp-server"
