# ============================================
# Script para unir automáticamente Windows 10 Pro al dominio reprobados.com
# Ahora también desactiva IPv6 automáticamente
# ============================================

# --- Variables principales ---
$dominio = "reprobados.com"
$usuarioAD = "Administrator"   # Usuario que usará para unir
$unidadOrganizativa = ""        # Dejar vacío si no quieres OU específica
$servidorDNS = "192.168.1.10"   # IP de tu servidor AD
$nombreEquipo = "cliente-windows"  # Cambia si quieres otro nombre
$password = Read-Host -Prompt "Introduce la contraseña de $usuarioAD" -AsSecureString

# --- Desactivar IPv6 ---
Write-Host "Desactivando IPv6 en el adaptador de red principal..." -ForegroundColor Cyan
Get-NetAdapter | ForEach-Object {
    Disable-NetAdapterBinding -Name $_.Name -ComponentID ms_tcpip6 -Confirm:$false
}

# --- Configurar DNS manualmente ---
Write-Host "Configurando el DNS para que apunte al servidor AD..." -ForegroundColor Cyan
Get-NetAdapter | Set-DnsClientServerAddress -ServerAddresses $servidorDNS

# --- Cambiar el nombre del equipo (opcional) ---
Write-Host "Cambiando nombre del equipo a: $nombreEquipo..." -ForegroundColor Cyan
Rename-Computer -NewName $nombreEquipo -Force

# --- Unir al dominio ---
Write-Host "Uniendo el equipo al dominio $dominio..." -ForegroundColor Cyan

if ($unidadOrganizativa) {
    # Si hay OU definida
    Add-Computer `
        -DomainName $dominio `
        -Credential (New-Object System.Management.Automation.PSCredential("$dominio\$usuarioAD", $password)) `
        -OUPath $unidadOrganizativa `
        -Restart
} else {
    # Si NO hay OU definida
    Add-Computer `
        -DomainName $dominio `
        -Credential (New-Object System.Management.Automation.PSCredential("$dominio\$usuarioAD", $password)) `
        -Restart
}

# --- Mensaje final ---
Write-Host "¡Equipo unido al dominio $dominio correctamente! Se reiniciará..." -ForegroundColor Green
