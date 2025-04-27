# ============================================
# Script para unir automáticamente Windows 10 Pro al dominio reprobados.com
# ============================================

# --- Variables principales ---
$dominio = "reprobados.com"
$usuarioAD = "Administrator"  # Usuario con permisos para unir
$unidadOrganizativa = ""       # Puedes dejar vacío o especificar una OU en formato: "OU=cuates,DC=reprobados,DC=com"
$servidorDNS = "192.168.1.10"  # IP del servidor AD
$nombreEquipo = "cliente-windows"  # Cambia si quieres otro nombre de equipo
$password = Read-Host -Prompt "Introduce la contraseña de $usuarioAD" -AsSecureString

# --- Configurar el DNS manualmente ---
Write-Host "Configurando el DNS para que apunte al servidor AD..." -ForegroundColor Cyan
Get-NetAdapter | Set-DnsClientServerAddress -ServerAddresses $servidorDNS

# --- Cambiar el nombre del equipo (opcional) ---
Write-Host "Cambiando nombre del equipo a: $nombreEquipo..." -ForegroundColor Cyan
Rename-Computer -NewName $nombreEquipo -Force

# --- Unir al dominio ---
Write-Host "Uniendo el equipo al dominio $dominio..." -ForegroundColor Cyan

Add-Computer `
    -DomainName $dominio `
    -Credential (New-Object System.Management.Automation.PSCredential("$dominio\$usuarioAD", $password)) `
    -OUPath $unidadOrganizativa `
    -Restart

# --- Mensaje final ---
Write-Host "¡Equipo unido al dominio $dominio correctamente! Se reiniciará..." -ForegroundColor Green
