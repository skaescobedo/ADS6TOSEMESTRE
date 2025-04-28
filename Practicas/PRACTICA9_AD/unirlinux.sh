# ===============================================
# Script para unir Ubuntu Server 22.04 al dominio reprobados.com
# Configura Kerberos, IP fija, asegura SSSD activo, configura resolv.conf,
# configura correctamente pam_mkhomedir y permite login en consola
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
# Configurar /etc/pam.d/common-session exactamente como debe ser
# --------------------------
echo "Configurando /etc/pam.d/common-session..."

sudo bash -c "cat > /etc/pam.d/common-session" << 'EOF'
# /etc/pam.d/common-session - session-related modules common to all services
#
# This file is included from other service-specific PAM config files,
# and should contain a list of modules that define tasks to be performed
# at the start and end of interactive sessions.
#
# As of pam 1.0.1-6, this file is managed by pam-auth-update by default.
# To take advantage of this, it is recommended that you configure any
# local modules either before or after the default block, and use
# pam-auth-update to manage selection of other modules. See
# pam-auth-update(8) for details.

# here are the per-package modules (the "Primary" block)
session    [default=1]    pam_permit.so
# here's the fallback if no module succeeds
session    requisite    pam_deny.so
# prime the stack with a positive return value if there isn't one already;
# this avoids us returning an error just because nothing sets a success code
# since the modules above will each just jump around
session    required    pam_permit.so
# The pam_umask module will set the umask according to the system default in
# /etc/login.defs and user settings, solving the problem of different
# umask settings with different shells, display managers, remote sessions etc.
# See "man pam_umask".
session    optional    pam_umask.so

# and here are more per-package modules (the "Additional" block)
session    required    pam_unix.so
session    required    pam_sss.so
session    required    pam_mkhomedir.so skel=/etc/skel/ umask=0022
session    optional    pam_systemd.so
# end of pam-auth-update config
EOF

echo "Archivo /etc/pam.d/common-session configurado correctamente."

# --------------------------
# Reiniciar servicios críticos
# --------------------------
echo "Reiniciando servicios sssd y systemd-logind..."
sudo systemctl restart sssd
sudo systemctl restart systemd-logind

echo "Servicios reiniciados correctamente."
# --------------------------


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
echo "\n¡Listo! El servidor está unido al dominio $DOMINIO.\n"
echo "Ahora puedes iniciar sesión en consola como:"
echo "  - usuarioCuate@$DOMINIO"
echo "  - usuarioNoCuate@$DOMINIO"
echo "\nEjemplo en consola (en la pantalla negra del server):"
echo "  Login: usuarioCuate@reprobados.com"
echo "  Password: P@ssw0rd123"
echo "\nAl iniciar sesión, se creará automáticamente su directorio /home." 
echo "====================================================="
