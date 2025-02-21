#!/bin/bash

# Función para solicitar la interfaz de red
solicitar_interfaz() {
    read -p "Ingrese la interfaz de red para el servidor DHCP (ejemplo: eth0): " INTERFAZ
    if ! ip link show | grep -q "$INTERFAZ"; then
        echo "Error: La interfaz de red $INTERFAZ no existe."
        exit 1
    fi
}

# Función para validar una dirección IP
validar_ip() {
    local ip="$1"
    local regex="^([0-9]{1,3}\.){3}[0-9]{1,3}$"
    
    if [[ $ip =~ $regex ]]; then
        IFS='.' read -r -a octetos <<< "$ip"
        for octeto in "${octetos[@]}"; do
            if (( octeto < 0 || octeto > 255 )); then
                return 1
            fi
        done
        return 0
    else
        return 1
    fi
}

# Función para solicitar y validar una dirección IP
solicitar_ip() {
    local mensaje="$1"
    local var="$2"
    while true; do
        read -p "$mensaje" valor
        if validar_ip "$valor"; then
            eval "$var='$valor'"
            break
        else
            echo "Error: Formato de IP inválido. Intente nuevamente."
        fi
    done
}

# Función para solicitar prefijo de máscara de subred
solicitar_prefijo() {
    while true; do
        read -p "Ingrese el prefijo de la máscara de subred (ejemplo: 24 para 255.255.255.0): " PREFIJO
        if [[ $PREFIJO =~ ^[0-9]{1,2}$ ]] && [ $PREFIJO -ge 1 ] && [ $PREFIJO -le 32 ]; then
            break
        else
            echo "Error: Prefijo inválido. Debe estar entre 1 y 32."
        fi
    done
}

# Función para calcular datos de red
calcular_datos_red() {
    MASCARA_RED=$(ipcalc $IP_ESTATICA/$PREFIJO | grep -oP 'Netmask:\s+\K[0-9.]+')
    RED=$(ipcalc $IP_ESTATICA/$PREFIJO | grep -oP 'Network:\s+\K[0-9.]+')
    BROADCAST=$(ipcalc $IP_ESTATICA/$PREFIJO | grep -oP 'Broadcast:\s+\K[0-9.]+')
}

# Función para configurar Netplan
configurar_netplan() {
    local archivo="/etc/netplan/50-cloud-init.yaml"
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
  version: 2" | sudo tee $archivo > /dev/null
    sudo netplan apply
}

# Función para configurar el servidor DHCP
configurar_dhcp() {
    sudo sed -i "s/^INTERFACESv4=.*/INTERFACESv4="$INTERFAZ"/" /etc/default/isc-dhcp-server
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
    sudo systemctl restart isc-dhcp-server
}
