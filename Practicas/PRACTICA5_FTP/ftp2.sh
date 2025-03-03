#!/bin/bash

# Importar funciones
source ./librerianueva.sh

# Flujo principal
instalar_dependencias
configurar_vsftpd
crear_estructura_directorios
crear_usuario
configurar_firewall_y_vsftpd

echo "Servidor FTP configurado correctamente."
