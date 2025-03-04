# Cargar el módulo donde están definidas todas las funciones
. "C:\ruta\a\FTP-Modulo.ps1"  # Asegúrate de ajustar la ruta al módulo

# Función principal que ejecuta todo el flujo
function Configurar-FTP-Completo {
    #Instalar-Caracteristicas
    Crear-Estructura-FTP
    Crear-Sitio-FTP
    Configurar-UserIsolation
    Crear-Grupos-Locales
    Crear-Usuario-FTP
    Configurar-Autenticacion-Permisos
    Configurar-TLS
    Reiniciar-FTP

    Write-Host "¡Servidor FTP configurado correctamente!"
}

# Ejecutar el flujo principal
Configurar-FTP-Completo
