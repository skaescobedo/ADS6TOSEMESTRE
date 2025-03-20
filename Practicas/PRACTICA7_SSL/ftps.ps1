# Importar el módulo de utilidades externas
Import-Module "C:\Users\Administrator\Desktop\librerianueva.ps1"

function Mostrar-Menu {
    Clear-Host
    Write-Host "=================================="
    Write-Host "     Administrador de FTP"
    Write-Host "=================================="
    Write-Host "1. Instalar y Configurar FTP Completo"
    Write-Host "2. Crear grupos locales"
    Write-Host "3. Crear usuario FTP"
    Write-Host "4. Eliminar usuario FTP"
    Write-Host "5. Configurar autenticación y permisos"
    Write-Host "6. Reiniciar sitio FTP"
    Write-Host "7. Salir"
    Write-Host "=================================="
}

function Menu-Principal {
    do {
        Mostrar-Menu
        $opcion = Read-Host "Seleccione una opción"

        switch ($opcion) {
            1 {
                Write-Host "Iniciando instalación y configuración completa de FTP..." -ForegroundColor Cyan

                Instalar-Caracteristicas
                Crear-Estructura-FTP

                do {
                    $respuestaSSL = Read-Host "¿Desea habilitar SSL para FTPS? (s/n)"
                    $respuestaSSL = $respuestaSSL.ToLower()
                } while ($respuestaSSL -ne "s" -and $respuestaSSL -ne "n")

                Crear-Sitio-FTP -habilitarSSL $respuestaSSL
                Configurar-UserIsolation
                Configurar-Autenticacion-Permisos

                Write-Host "Configuración completa de FTP finalizada." -ForegroundColor Green
            }
            2 { 
                Crear-Grupos-Locales 
            }
            3 { 
                Crear-Usuario-FTP 
            }
            4 { 
                $nombreUsuario = Read-Host "Ingrese el nombre de usuario a eliminar"
                Eliminar-Usuario-FTP -nombreUsuario $nombreUsuario
            }
            5 { 
                Configurar-Autenticacion-Permisos 
            }
            6 { 
                Reiniciar-FTP 
            }
            7 { 
                Write-Host "Saliendo del programa..." 
                break
            }
            default {
                Write-Host "Opción no válida. Por favor, seleccione una opción entre 1 y 7." -ForegroundColor Red
            }
        }
        Pause
    } while ($opcion -ne 7)
}

# Ejecutar menú al correr el script
Menu-Principal
