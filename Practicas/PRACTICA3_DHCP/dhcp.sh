#!/bin/bash

# Instalar paquetes necesarios
sudo apt update && sudo apt install -y isc-dhcp-server ipcalc

# Solicitar interfaz de red
read -p "Ingrese la interfaz de red para el servidor DHCP (ejemplo: eth0): " INTERFAZ

# Verificar si la interfaz ingresada es válida
if ! ip link show | grep -q "$INTERFAZ"; then
    echo "Error: La interfaz de red $INTERFAZ no existe."
    exit 1
fi

# Solicitar la configuración de IP estática para la interfaz con validaciones
while true; do
    read -p "Ingrese la dirección IP estática para $INTERFAZ (ejemplo: 192.168.1.10): " IP_ESTATICA
    if [[ $IP_ESTATICA =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
        break
    else
        echo "Error: Formato de IP inválido. Intente nuevamente."
    fi
done

while true; do
    read -p "Ingrese el prefijo de la máscara de subred (ejemplo: 24 para 255.255.255.0): " PREFIJO
    if [[ $PREFIJO =~ ^[0-9]{1,2}$ ]] && [ $PREFIJO -ge 1 ] && [ $PREFIJO -le 32 ]; then
        break
    else
        echo "Error: Prefijo inválido. Debe estar entre 1 y 32."
    fi
done

MASCARA_RED=$(ipcalc $IP_ESTATICA/$PREFIJO | grep -oP 'Netmask:\s+\K[0-9.]+')
RED=$(ipcalc $IP_ESTATICA/$PREFIJO | grep -oP 'Network:\s+\K[0-9.]+')
BROADCAST=$(ipcalc $IP_ESTATICA/$PREFIJO | grep -oP 'Broadcast:\s+\K[0-9.]+')

while true; do
    read -p "Ingrese la dirección del gateway (ejemplo: 192.168.1.1): " PUERTA_ENLACE
    if [[ $PUERTA_ENLACE =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
        break
    else
        echo "Error: Formato de IP inválido para el gateway. Intente nuevamente."
    fi
done

while true; do
    read -p "Ingrese la dirección del servidor DNS primario (ejemplo: 8.8.8.8): " DNS_PRIMARIO
    if [[ $DNS_PRIMARIO =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
        break
    else
        echo "Error: Formato de IP inválido para el DNS primario. Intente nuevamente."
    fi
done

while true; do
    read -p "Ingrese la dirección del servidor DNS secundario (opcional, ejemplo: 8.8.4.4): " DNS_SECUNDARIO
    if [[ -z "$DNS_SECUNDARIO" || $DNS_SECUNDARIO =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
        break
    else
        echo "Error: Formato de IP inválido para el DNS secundario. Intente nuevamente."
    fi
done

while true; do
    read -p "Ingrese la dirección de inicio del rango DHCP: " RANGO_INICIO
    if [[ $RANGO_INICIO =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] && [[ $(printf "%u" $(echo $RANGO_INICIO | awk -F. '{print ($1 * 256 ** 3) + ($2 * 256 ** 2) + ($3 * 256) + $4}')) -gt $(printf "%u" $(echo $RED | awk -F. '{print ($1 * 256 ** 3) + ($2 * 256 ** 2) + ($3 * 256) + $4}')) ]]; then
        break
    else
        echo "Error: Dirección de inicio fuera del rango válido de la red. Intente nuevamente."
    fi
done

while true; do
    read -p "Ingrese la dirección final del rango DHCP: " RANGO_FIN
    if [[ $RANGO_FIN =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] && [[ $(printf "%u" $(echo $RANGO_FIN | awk -F. '{print ($1 * 256 ** 3) + ($2 * 256 ** 2) + ($3 * 256) + $4}')) -lt $(printf "%u" $(echo $BROADCAST | awk -F. '{print ($1 * 256 ** 3) + ($2 * 256 ** 2) + ($3 * 256) + $4}')) ]] && [[ $(printf "%u" $(echo $RANGO_FIN | awk -F. '{print ($1 * 256 ** 3) + ($2 * 256 ** 2) + ($3 * 256) + $4}')) -ge $(printf "%u" $(echo $RANGO_INICIO | awk -F. '{print ($1 * 256 ** 3) + ($2 * 256 ** 2) + ($3 * 256) + $4}')) ]]; then
        break
    else
        echo "Error: Dirección final fuera del rango válido de la red o menor que la dirección inicial. Intente nuevamente."
    fi
done

# Configurar la IP estática en Netplan
ARCHIVO_NETPLAN="/etc/netplan/50-cloud-init.yaml"
echo "network:
  ethernets:
    $INTERFAZ:
      dhcp4: false
      addresses: [$IP_ESTATICA/$PREFIJO]
      routes:
        - to: default
          via: $PUERTA_ENLACE
      nameservers:
        addresses: [$DNS_PRIMARIO, $DNS_SECUNDARIO]
  version: 2" | sudo tee $ARCHIVO_NETPLAN > /dev/null

# Aplicar configuración de Netplan
sudo netplan apply

# Configurar la interfaz de red para el servidor DHCP
sudo sed -i "s/^INTERFACESv4=.*/INTERFACESv4=\"$INTERFAZ\"/" /etc/default/isc-dhcp-server

# Configurar el archivo DHCP
cat <<EOT | sudo tee /etc/dhcp/dhcpd.conf
option domain-name "localdomain";
option domain-name-servers $DNS_PRIMARIO, $DNS_SECUNDARIO;
default-lease-time 600;
max-lease-time 7200;

subnet $RED netmask $MASCARA_RED {
    range $RANGO_INICIO $RANGO_FIN;
    option routers $PUERTA_ENLACE;
    option subnet-mask $MASCARA_RED;
    option broadcast-address $BROADCAST;
    option domain-name-servers $DNS_PRIMARIO, $DNS_SECUNDARIO;
}
EOT

# Reiniciar y habilitar el servicio DHCP
sudo systemctl restart isc-dhcp-server

echo "Configuración del servidor DHCP completada. Verifique que el servicio esté corriendo con: systemctl status isc-dhcp-server"
