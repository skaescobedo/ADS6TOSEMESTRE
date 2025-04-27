#!/bin/bash

# ===============================================
# Script para unir Ubuntu Server 22.04 al dominio reprobados.com
# Configura Kerberos, IP fija, asegura SSSD activo, configura resolv.conf y permite login en consola
# ===============================================

# --------------------------
# Variables principales
# --------------------------
DOMINIO="reprobados.com"
REALM="REPROBADOS.COM"
IP_SERVIDOR_AD="192.168.1.10"
NOMBRE_SERVIDOR_AD="winserver2025"
IP_CLIENTE="192.168.1.75"
GATEWAY="192.168.1.254"
INTERFAZ="enp0s3"

# --------------------------
# Actualizar e instalar dependencias
# --------------------------
echo "Actualizando paquetes..."
sudo apt update

echo "Instalando dependencias necesarias..."
sudo apt install realmd sssd sssd-tools libnss-sss libpam-sss adcli samba-common-bin oddjob oddjob-mkhomedir packagekit krb5-user -y

# --------------------------
# Configurar el archivo /etc/krb5.conf
# --------------------------
echo "Configurando /etc/krb5.conf para el dominio $REALM..."

sudo bash -c "cat > /etc/krb5.conf <<EOF
[libdefaults]
  default_realm = $REALM
  dns_lookup_realm = true
  dns_lookup_kdc = true
  rdns = false

[realms]
  $REALM = {
    kdc = $NOMBRE_SERVIDOR_AD.$DOMINIO
    admin_server = $NOMBRE_SERVIDOR_AD.$DOMINIO
  }

[domain_realm]
  .$DOMINIO = $REALM
  $DOMINIO = $REALM
EOF"

echo "Archivo /etc/krb5.conf configurado correctamente."

# --------------------------
# Configurar IP estática en Netplan
# --------------------------
echo "Configurando IP estática en Netplan..."
sudo bash -c "cat > /etc/netplan/50-cloud-init.yaml <<EOF
network:
  version: 2
  ethernets:
    $INTERFAZ:
      dhcp4: false
      addresses:
        - $IP_CLIENTE/24
      routes:
        - to: default
          via: $GATEWAY
      nameservers:
        addresses:
          - $IP_SERVIDOR_AD
EOF"

echo "Aplicando configuración de red..."
sudo netplan apply

# --------------------------
# Configurar resolv.conf manualmente
# --------------------------
echo "Configurando resolv.conf manualmente para usar el DNS del servidor AD..."

# Borrar symlink si existe
sudo rm -f /etc/resolv.conf

# Crear nuevo resolv.conf fijo
sudo bash -c "cat > /etc/resolv.conf <<EOF
nameserver $IP_SERVIDOR_AD
options edns0 trust-ad
search $DOMINIO
EOF"

echo "Archivo /etc/resolv.conf configurado correctamente."

# --------------------------
# Activar y asegurar servicio SSSD
# --------------------------
echo "Habilitando y arrancando el servicio sssd..."
sudo systemctl enable sssd
sudo systemctl start sssd

# --------------------------
# Configurar creación automática de directorios HOME
# --------------------------
echo "Configurando creación automática de directorios /home..."
sudo sed -i '/pam_mkhomedir.so/ s/^#//' /etc/pam.d/common-session || echo "session required pam_mkhomedir.so skel=/etc/skel umask=0022" | sudo tee -a /etc/pam.d/common-session

# --------------------------
# Unirse al dominio
# --------------------------
echo "Uniéndose al dominio $DOMINIO usando la cuenta Administrator..."
sudo realm join --user=Administrator --membership-software=samba --client-software=sssd $DOMINIO

# --------------------------
# Permitir login a todos los usuarios del dominio
# --------------------------
echo "Permitiremos el login a todos los usuarios de $DOMINIO..."
sudo realm permit --all

# --------------------------
# Confirmación de la unión
# --------------------------
echo "Verificando la configuración del dominio..."
realm list

# --------------------------
# Mensaje final
# --------------------------
echo "====================================================="
echo "¡Listo! El servidor está unido al dominio $DOMINIO."
echo ""
echo "Ahora puedes iniciar sesión en consola como:"
echo "  - usuarioCuate@$DOMINIO"
echo "  - usuarioNoCuate@$DOMINIO"
echo ""
echo "Ejemplo en consola (en la pantalla negra del server):"
echo "  Login: usuarioCuate@reprobados.com"
echo "  Password: P@ssw0rd123"
echo ""
echo "Al iniciar sesión, se creará automáticamente su directorio /home."
echo "====================================================="
