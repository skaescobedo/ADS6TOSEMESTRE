#!/bin/bash
source ./librerianueva.sh

sudo apt-get update

# Instalar Docker en Ubuntu utilizando el script oficial
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh

# Preguntar al usuario el puerto a usar
preguntar_puerto
port=$puerto  # El valor queda almacenado en la variable global $puerto desde la función

# Habilitar el puerto en el firewall si es necesario
habilitar_puerto_firewall "$port"

# Descargar y ejecutar la imagen de Apache en Docker
sudo docker pull httpd:latest
sudo docker run -d --name apache-container -p $port:80 httpd:latest
sleep 5
echo "Contenedor de Apache iniciado."

# Modificar la página principal del contenedor de Apache
sudo docker exec apache-container bash -c 'cat > /usr/local/apache2/htdocs/index.html <<EOF
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>PERO QUE DISTINGUIDO PEDRI</title>
    <style>
        body {
            text-align: center;
            background-color: #004c98;
            color: white;
            font-family: Arial, sans-serif;
        }
        h1 {
            margin-top: 20px;
            font-size: 28px;
            font-weight: bold;
        }
        marquee {
            margin-top: 50px;
        }
        img {
            width: 300px;
            height: auto;
            border-radius: 10px;
            box-shadow: 0px 0px 10px rgba(255, 255, 255, 0.5);
            margin: 0 20px;
        }
    </style>
</head>
<body>
    <h1>PERO QUE DISTINGUIDO PEDRI</h1>
    <marquee behavior="scroll" direction="left" scrollamount="10">
        <img src="https://upload.wikimedia.org/wikipedia/en/4/47/FC_Barcelona_%28crest%29.svg" 
             alt="Escudo del FC Barcelona">
        <img src="https://pbs.twimg.com/media/E5ZP9L2X0Ak8gN2.jpg:large" 
             alt="Imagen del FC Barcelona">
        <img src="https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcSbFMCtfPdNYbLQL0fCGC_ntQuypliAFhJmcg&s" 
             alt="Pedri Distinguido">
    </marquee>
</body>
</html>
EOF'
echo "Página personalizada de Apache actualizada con éxito."


# Crear una imagen personalizada de Apache con el contenido modificado
sudo docker commit apache-container custom-apache:latest
echo "Imagen personalizada de Apache creada."

# Crear red para los contenedores de PostgreSQL
echo "Creando red Docker para PostgreSQL..."
sudo docker network create my_network

# Ejecutar dos contenedores PostgreSQL en la red creada
sudo docker run -d --name postgres-container1 --network my_network -e POSTGRES_PASSWORD=soyunreprobado postgres:latest
sudo docker run -d --name postgres-container2 --network my_network -e POSTGRES_PASSWORD=soyunreprobado postgres:latest
echo "Contenedores de PostgreSQL iniciados."
sleep 10

# Crear bases de datos en ambos contenedores
echo "Creando base de datos en postgres-container1..."
sudo docker exec postgres-container1 psql -U postgres -c "CREATE DATABASE reprobados;"
echo "Creando base de datos en postgres-container2..."
sudo docker exec postgres-container2 psql -U postgres -c "CREATE DATABASE reprobados2;"

# Instalar cliente de PostgreSQL en ambos contenedores
echo "Instalando cliente de PostgreSQL en postgres-container1..."
sudo docker exec postgres-container1 bash -c "apt-get update && apt-get install -y postgresql-client"
echo "Instalando cliente de PostgreSQL en postgres-container2..."
sudo docker exec postgres-container2 bash -c "apt-get update && apt-get install -y postgresql-client"

# Verificar la conectividad entre contenedores
echo "Verificando conexión de postgres-container1 a postgres-container2..."
sudo docker exec postgres-container1 bash -c 'PGPASSWORD=soyunreprobado psql -h postgres-container2 -U postgres -d reprobados2 -c "\l"'

echo "Verificando conexión de postgres-container2 a postgres-container1..."
sudo docker exec postgres-container2 bash -c 'PGPASSWORD=soyunreprobado psql -h postgres-container1 -U postgres -d reprobados -c "\l"'

# Mostrar URL para acceder a la página de Apache
echo "Puede acceder a la página web en el siguiente enlace:"
echo -e "http://$(hostname -I | awk '{print $1}'):$port"