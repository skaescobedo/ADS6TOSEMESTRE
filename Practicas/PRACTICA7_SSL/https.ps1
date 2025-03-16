# Importar funciones desde el módulo externo
Import-Module "C:\Users\Administrator\Desktop\librerianueva.ps1"

function Menu-Web {
    while ($true) {
        Clear-Host
        Write-Host "=================================="
        Write-Host "        Instalador desde Web      "
        Write-Host "=================================="
        Write-Host "1. Seleccionar Protocolo (HTTP/HTTPS)"
        Write-Host "2. Seleccionar Servicio"
        Write-Host "3. Seleccionar Versión"
        Write-Host "4. Configurar Puerto"
        Write-Host "5. Proceder con la Instalación"
        Write-Host "6. Volver al menú principal"
        Write-Host "=================================="

        $opcion_menu = Read-Host "Seleccione una opción"

        switch ($opcion_menu) {
            "1" { seleccionar_protocolo }
            "2" { seleccionar_servicio }
            "3" { seleccionar_version }
            "4" { preguntar_puerto }
            "5" { 
                Write-Host "=================================="
                Write-Host "      Resumen de la instalación   "
                Write-Host "=================================="
                Write-Host "Protocolo seleccionado: $global:protocolo"
                Write-Host "Servicio seleccionado: $global:servicio"
                Write-Host "Versión seleccionada: $global:version"
                Write-Host "Puerto configurado: $global:puerto"
                Write-Host "=================================="
                $confirmacion = Read-Host "¿Desea proceder con la instalación? (s/n)"
                if ($confirmacion -eq "s") {
                    proceso_instalacion
                } else {
                    Write-Host "Instalación cancelada."
                }
            }
            "6" { return }  # Vuelve al menú principal
            default { Write-Host "Opción no válida. Intente de nuevo." }
        }
        Read-Host "Presione Enter para continuar..."
    }
}

function Menu-FTP {
    while ($true) {
        Clear-Host
        Write-Host "=================================="
        Write-Host "        Instalador desde FTP      "
        Write-Host "=================================="
        Write-Host "1. Seleccionar Protocolo (HTTP/HTTPS)"
        Write-Host "2. Seleccionar Servicio"
        Write-Host "3. Seleccionar Versión"
        Write-Host "4. Configurar Puerto"
        Write-Host "5. Proceder con la Instalación"
        Write-Host "6. Volver al menú principal"
        Write-Host "=================================="

        $opcion_menu = Read-Host "Seleccione una opción"

        switch ($opcion_menu) {
            "1" { seleccionar_protocolo }
            "2" { seleccionar_servicio -modo "ftp" }
            "3" { seleccionar_version_ftp }
            "4" { preguntar_puerto }
            "5" { 
                Write-Host "=================================="
                Write-Host "      Resumen de la instalación   "
                Write-Host "=================================="
                Write-Host "Protocolo seleccionado: $global:protocolo"
                Write-Host "Servicio seleccionado: $global:servicio"
                Write-Host "Versión seleccionada: $global:version"
                Write-Host "Puerto configurado: $global:puerto"
                Write-Host "=================================="
                $confirmacion = Read-Host "¿Desea proceder con la instalación? (s/n)"
                if ($confirmacion -eq "s") {
                    proceso_instalacion_ftp
                } else {
                    Write-Host "Instalación cancelada."
                }
            }
            "6" { return }  # Vuelve al menú principal
            default { Write-Host "Opción no válida. Intente de nuevo." }
        }
        Read-Host "Presione Enter para continuar..."
    }
}

function Mostrar-Menu-Inicio {
    Clear-Host
    Write-Host "=================================="
    Write-Host "  Seleccione el Método de Instalación"
    Write-Host "=================================="
    Write-Host "1. Instalar dependencias necesarias"
    Write-Host "2. Descargar e instalar desde la Web"
    Write-Host "3. Descargar e instalar desde un Servidor FTP"
    Write-Host "4. Salir"
    Write-Host "=================================="
}

while ($true) {
    Mostrar-Menu-Inicio
    $opcion_inicio = Read-Host "Seleccione una opción"

    switch ($opcion_inicio) {
        "1" { instalar_dependencias }
        "2" { Menu-Web }
        "3" { Menu-FTP }
        "4" { Write-Host "Saliendo..."; exit }
        default { Write-Host "Opción no válida. Intente de nuevo." }
    }
    Read-Host "Presione Enter para continuar..."
}
