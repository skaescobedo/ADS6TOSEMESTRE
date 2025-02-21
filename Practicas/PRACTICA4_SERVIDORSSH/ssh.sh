#!/bin/bash

# Instalar OpenSSH Server
echo "Instalando OpenSSH Server"
sudo apt update && sudo apt install openssh-server -y

# Habilitar y arrancar el servicio SSH
echo "Habilitando y arrancando SSH"
sudo systemctl enable ssh
sudo systemctl start ssh

# Permitir el puerto 22 en el firewall
echo "Configurando firewall para permitir SSH"
sudo ufw allow 22/tcp
sudo ufw reload

# Verificar el estado del servicio SSH
echo "Verificando estado de SSH"
sudo systemctl status ssh --no-pager

echo "Configuración completada. Ahora puedes conectarte a este servidor vía SSH."
