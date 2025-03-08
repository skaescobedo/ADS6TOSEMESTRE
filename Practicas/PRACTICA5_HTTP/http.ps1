# ========================
# Menú interactivo para la instalación de servicios HTTP en Windows
# ========================

# Cargar funciones desde libreriawindows.ps1
Import-Module "C:\Users\Administrator\Desktop\librerianueva.ps1"

function Mostrar-Menu {
    Clear-Host
    Write-Host "=================================="
    Write-Host "        Instalador HTTP           "
    Write-Host "=================================="
    Write-Host "0. Instalar dependencias necesarias"
    Write-Host "1. Seleccionar Servicio"
    Write-Host "2. Seleccionar Versión"
    Write-Host "3. Configurar Puerto"
    Write-Host "4. Proceder con la Instalación"
    Write-Host "5. Verificar servicios instalados"
    Write-Host "6. Salir"
    Write-Host "=================================="
}

# ========================
# Bucle principal del menú
# ========================
while ($true) {
    Mostrar-Menu
    $opcion_menu = Read-Host "Seleccione una opción"

    switch ($opcion_menu) {
        "0" {
            Instalar-Dependencias
            Read-Host "Presione Enter para continuar..."
        }
        "1" {
            Seleccionar-Servicio
            Read-Host "Presione Enter para continuar..."
        }
        "2" {
            Seleccionar-Version
            Read-Host "Presione Enter para continuar..."
        }
        "3" {
            Preguntar-Puerto
            Read-Host "Presione Enter para continuar..."
        }
        "4" {
            Write-Host "=================================="
            Write-Host "      Resumen de la instalación   "
            Write-Host "=================================="
            Write-Host "Servicio seleccionado: $servicio"
            Write-Host "Versión seleccionada: $version"
            Write-Host "Puerto configurado: $puerto"
            Write-Host "=================================="
            $confirmacion = Read-Host "¿Desea proceder con la instalación? (s/n)"
            if ($confirmacion -eq "s") {
                Instalar-Servicio
            } else {
                Write-Host "Instalación cancelada."
            }
            Read-Host "Presione Enter para continuar..."
        }
        "5" {
            Verificar-Servicios
            Read-Host "Presione Enter para continuar..."
        }
        "6" {
            Write-Host "Saliendo..."
            exit
        }
        default {
            Write-Host "Opción no válida. Intente de nuevo."
            Read-Host "Presione Enter para continuar..."
        }
    }
}
