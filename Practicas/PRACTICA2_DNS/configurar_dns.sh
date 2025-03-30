#!/bin/bash

# Variables de Netplan
NETPLAN_DIR="/etc/netplan"
STATIC_CONFIG="$NETPLAN_DIR/static.bak"
ORIGINAL_CONFIG="$NETPLAN_DIR/original.bak"
ACTIVE_CONFIG="$NETPLAN_DIR/50-cloud-init.yaml"

# Variables de Bind9
DNS_ZONE_FILE="/etc/bind/db.reprobados.com"
NAMED_CONF="/etc/bind/named.conf"
NAMED_OPTIONS="/etc/bind/named.conf.options"

echo "[INFO] Restaurando configuración de red para tener acceso a Internet..."
if [ -f "$ORIGINAL_CONFIG" ]; then
    sudo cp "$ORIGINAL_CONFIG" "$ACTIVE_CONFIG"
    sudo netplan apply
    echo "[INFO] Red restaurada temporalmente para descargar paquetes."
else
    echo "[ERROR] No se encontró el archivo original.bak. Revisa la configuración de Netplan."
    exit 1
fi

# Instalando Bind9
echo "[INFO] Instalando Bind9..."
sudo apt update && sudo apt install -y bind9 bind9utils

if [ $? -ne 0 ]; then
    echo "[ERROR] No se pudo instalar Bind9. Revisa la conexión a Internet."
    exit 1
fi

echo "[INFO] Restaurando configuración de IP estática..."
if [ -f "$STATIC_CONFIG" ]; then
    sudo cp "$STATIC_CONFIG" "$ACTIVE_CONFIG"
    sudo netplan apply
    echo "[INFO] Configuración de IP estática aplicada."
else
    echo "[ERROR] No se encontró el archivo static.bak. Revisa la configuración de Netplan."
    exit 1
fi

echo "[INFO] Configurando Bind9 para la zona reprobados.com..."

# Crear archivo named.conf
sudo bash -c "cat > $NAMED_CONF" <<EOF
// Archivo de configuración principal de BIND9
include "/etc/bind/named.conf.options";
include "/etc/bind/named.conf.local";
include "/etc/bind/named.conf.default-zones";

zone "reprobados.com" IN {
    type master;
    file "/etc/bind/db.reprobados.com";
};
EOF

echo "[INFO] Archivo named.conf configurado correctamente."

# Crear el archivo de zona DNS
echo "[INFO] Creando archivo de zona para reprobados.com en $DNS_ZONE_FILE..."

sudo bash -c "cat > $DNS_ZONE_FILE" <<EOF
\$TTL 604800
@   IN  SOA luis.local. root.localhost. (
        3   ; Serial
        604800  ; Refresh
        86400   ; Retry
        2419200 ; Expire
        604800  ; Negative Cache TTL
)

@       IN  NS  localhost.
@       IN  A   192.168.1.10
www     IN  A   192.168.1.10
EOF

echo "[INFO] Archivo de zona creado correctamente."

# Configurar named.conf.options
echo "[INFO] Configurando named.conf.options..."

sudo bash -c "cat > $NAMED_OPTIONS" <<EOF
options {
    directory "/var/cache/bind";

    allow-query { any; };
    recursion yes;
    listen-on { any; };
    listen-on-v6 { any; };

    forwarders {
        0.0.0.0;
        0.0.4.4;
    };

    dnssec-validation auto;
};
EOF

echo "[INFO] Archivo named.conf.options configurado correctamente."

# Verificar la configuración de Bind9
echo "[INFO] Verificando configuración de Bind9..."
if sudo named-checkconf; then
    echo "[INFO] named.conf sin errores."
else
    echo "[ERROR] ERROR en named.conf. Revisa la configuración."
    exit 1
fi

if sudo named-checkzone reprobados.com $DNS_ZONE_FILE; then
    echo "[INFO] Archivo de zona correcto."
else
    echo "[ERROR] ERROR en el archivo de zona. Revisa la configuración."
    exit 1
fi

# Reiniciar Bind9 para aplicar cambios
echo "[INFO] Reiniciando Bind9..."
sudo systemctl restart bind9

# Verificar si el servicio está activo
if sudo systemctl status bind9 | grep "active (running)"; then
    echo "[INFO] Bind9 está corriendo correctamente."
else
    echo "[ERROR] ERROR al iniciar Bind9. Revisa logs con: sudo journalctl -xe"
    exit 1
fi

echo "[INFO] Configuración completada. Prueba con: nslookup reprobados.com 192.168.1.10"