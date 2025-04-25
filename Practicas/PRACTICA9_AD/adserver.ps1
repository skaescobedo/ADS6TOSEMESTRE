# ==========================================
# Script de Configuración AD - Windows Server 2025
# ==========================================

# --- CONFIGURACIÓN DE RED ---
Get-NetIPConfiguration

$Index = Read-Host -Prompt "Ingrese el InterfaceIndex del equipo"
$ServerIP = Read-Host -Prompt "Ingrese la dirección IP del equipo"
$Length = Read-Host -Prompt "Ingrese los Bits de la Máscara"
$Gateway = Read-Host -Prompt "Ingrese la dirección IP del Gateway predeterminado"

New-NetIPAddress -InterfaceIndex $Index -IPAddress $ServerIP -PrefixLength $Length
route add 0.0.0.0 mask 0.0.0.0 $Gateway -p

Get-NetIPConfiguration
$RemoveLastIP = Read-Host -Prompt "Ingrese la direccion IPv4 sobrante (si aplica, o deje vacío)"
$InterfaceAlias = Read-Host -Prompt "Ingrese el Alias de la interfaz"

if ($RemoveLastIP) {
    Remove-NetIPAddress -IPAddress $RemoveLastIP -InterfaceAlias $InterfaceAlias -Confirm:$false
}

$DNSHostIP = Read-Host -Prompt "Ingrese la direccion IP del host DNS"
Set-DnsClientServerAddress -InterfaceAlias $InterfaceAlias -ServerAddresses $DNSHostIP

# --- INSTALACIÓN DE ACTIVE DIRECTORY ---
Install-WindowsFeature -Name 'AD-Domain-Services' -IncludeManagementTools
Import-Module ADDSDeployment

$DomainName = Read-Host -Prompt "Ingrese el Dominio (ejemplo: miempresa.local)"
$NetbiosName = ($DomainName.Split('.')[0]).ToUpper()

Install-ADDSForest `
    -DomainName $DomainName `
    -DomainNetbiosName $NetbiosName `
    -InstallDNS:$true `
    -CreateDNSDelegation:$false `
    -DatabasePath "C:\NTDS" `
    -SysvolPath "C:\SYSVOL" `
    -LogPath "C:\NTDS" `
    -Force:$true

exit  # El sistema se reiniciará tras promoción. Ejecute de nuevo luego.

# --- CREACIÓN DE UOs Y USUARIOS ---
Import-Module ActiveDirectory
$domain = Get-ADDomain
$domainDN = $domain.DistinguishedName

$OUs = @("cuates", "no cuates")
foreach ($ou in $OUs) {
    if (-not (Get-ADOrganizationalUnit -Filter "Name -eq '$ou'" -ErrorAction SilentlyContinue)) {
        New-ADOrganizationalUnit -Name $ou -Path $domainDN -ProtectedFromAccidentalDeletion $false
    }
}

$users = @(
    @{ Name = "usuarioCuate"; GivenName = "Usuario"; Surname = "Cuate"; OU = "cuates" },
    @{ Name = "usuarioNoCuate"; GivenName = "Usuario"; Surname = "NoCuate"; OU = "no cuates" }
)

foreach ($user in $users) {
    if (-not (Get-ADUser -Filter "SamAccountName -eq '$($user.Name)'" -ErrorAction SilentlyContinue)) {
        New-ADUser `
            -Name "$($user.GivenName) $($user.Surname)" `
            -GivenName $user.GivenName `
            -Surname $user.Surname `
            -SamAccountName $user.Name `
            -UserPrincipalName "$($user.Name)@$($domain.DNSRoot)" `
            -AccountPassword (ConvertTo-SecureString "P@ssw0rd123" -AsPlainText -Force) `
            -Enabled $true `
            -Path "OU=$($user.OU),$domainDN" `
            -PasswordNeverExpires $true
    }
}

Write-Host "Configuración del servidor AD completada correctamente."
