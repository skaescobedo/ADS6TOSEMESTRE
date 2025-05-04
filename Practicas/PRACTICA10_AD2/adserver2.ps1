Import-Module "C:\Users\Administrator\Desktop\Windows2025lib.ps1"
Import-Module ActiveDirectory

$domain = Get-ADDomain
$domainDN = $domain.DistinguishedName

# Crear las OUs
$OUs = @("grupo1", "grupo2", "grupo3", "grupo4")
foreach ($ou in $OUs) {
    if (-not (Get-ADOrganizationalUnit -Filter "Name -eq '$ou'" -ErrorAction SilentlyContinue)) {
        New-ADOrganizationalUnit -Name $ou -Path $domainDN -ProtectedFromAccidentalDeletion $false
    }
}

# Obtener datos de los usuarios
$users = Get-UserData
$users | Format-Table -AutoSize

# Crear usuarios
foreach ($user in $users) {
    if (-not (Get-ADUser -Filter "SamAccountName -eq '$($user.Name)'" -ErrorAction SilentlyContinue)) {
        New-ADUser `
            -Name "$($user.GivenName) $($user.Surname)" `
            -GivenName $user.GivenName `
            -Surname $user.Surname `
            -SamAccountName $user.Name `
            -UserPrincipalName "$($user.Name)@$($domain.DNSRoot)" `
            -AccountPassword (ConvertTo-SecureString $user.Pass -AsPlainText -Force) `
            -Enabled $true `
            -Path "OU=$($user.OU),$domainDN" `
            -PasswordNeverExpires $true
    }
}

# Crear GPOs
$gpoGroup1 = New-GPO -Name "GPO_1"
$gpoGroup2 = New-GPO -Name "GPO_2"
$gpoGroup3 = New-GPO -Name "GPO_3"
$gpoGroup4 = New-GPO -Name "GPO_4"

# Vincular GPOs
New-GPLink -Name $gpoGroup1.DisplayName -Target "OU=grupo1,$domainDN"
New-GPLink -Name $gpoGroup2.DisplayName -Target "OU=grupo2,$domainDN"
New-GPLink -Name $gpoGroup3.DisplayName -Target "OU=grupo3,$domainDN"
New-GPLink -Name $gpoGroup4.DisplayName -Target "OU=grupo4,$domainDN"

# Crear carpeta de perfiles y compartirla
New-Item -Path "C:\Profiles" -ItemType Directory -Force
New-SmbShare -Path "C:\Profiles" -Name "Profiles" -FullAccess "Everyone"

# Crear carpeta por usuario y asignar perfil móvil
$machine = $env:COMPUTERNAME
foreach ($user in $users) {
    $ruta = "C:\Profiles\$($user.Name)"
    if (-not (Test-Path $ruta)) {
        New-Item -Path $ruta -ItemType Directory
    }
    Set-ADUser -Identity $user.Name -ProfilePath "\\$machine\Profiles\$($user.Name)"
}

# BLOQUEO REAL DE PERFIL (grupo1 → 5 MB)
Set-GPRegistryValue -Name $gpoGroup1.DisplayName -Key "Software\\Policies\\Microsoft\\Windows\\System" -ValueName "LimitProfileSize" -Type DWord -Value 1
Set-GPRegistryValue -Name $gpoGroup1.DisplayName -Key "Software\\Policies\\Microsoft\\Windows\\System" -ValueName "MaxProfileSize" -Type DWord -Value 5120
Set-GPRegistryValue -Name $gpoGroup1.DisplayName -Key "Software\\Policies\\Microsoft\\Windows\\System" -ValueName "IncludeRegInProQuota" -Type DWord -Value 1
Set-GPRegistryValue -Name $gpoGroup1.DisplayName -Key "Software\\Policies\\Microsoft\\Windows\\System" -ValueName "WarnUser" -Type DWord -Value 1

# BLOQUEO REAL DE PERFIL (grupo2 → 10 MB)
Set-GPRegistryValue -Name $gpoGroup2.DisplayName -Key "Software\\Policies\\Microsoft\\Windows\\System" -ValueName "LimitProfileSize" -Type DWord -Value 1
Set-GPRegistryValue -Name $gpoGroup2.DisplayName -Key "Software\\Policies\\Microsoft\\Windows\\System" -ValueName "MaxProfileSize" -Type DWord -Value 10240
Set-GPRegistryValue -Name $gpoGroup2.DisplayName -Key "Software\\Policies\\Microsoft\\Windows\\System" -ValueName "IncludeRegInProQuota" -Type DWord -Value 1
Set-GPRegistryValue -Name $gpoGroup2.DisplayName -Key "Software\\Policies\\Microsoft\\Windows\\System" -ValueName "WarnUser" -Type DWord -Value 1

# Grupo 1: solo notepad
Set-GPRegistryValue -Name $gpoGroup1.DisplayName -Key "HKCU\\Software\\Microsoft\\Windows\\CurrentVersion\\Policies\\Explorer" -ValueName "RestrictRun" -Type DWord -Value 1
Set-GPRegistryValue -Name $gpoGroup1.DisplayName -Key "HKCU\\Software\\Microsoft\\Windows\\CurrentVersion\\Policies\\Explorer\\RestrictRun" -ValueName "1" -Type String -Value "notepad.exe"

# Grupo 2: bloquear notepad
Set-GPRegistryValue -Name $gpoGroup2.DisplayName -Key "HKCU\\Software\\Microsoft\\Windows\\CurrentVersion\\Policies\\Explorer" -ValueName "DisallowRun" -Type DWord -Value 1
Set-GPRegistryValue -Name $gpoGroup2.DisplayName -Key "HKCU\\Software\\Microsoft\\Windows\\CurrentVersion\\Policies\\Explorer\\DisallowRun" -ValueName "1" -Type String -Value "notepad.exe"

# Grupo 4: forzar cambio de contraseña
foreach ($user in $users) {
    if ($user.OU -eq "grupo4") {
        Set-ADUser -Identity $user.Name -ChangePasswordAtLogon $true
    }
}
Set-ADDefaultDomainPasswordPolicy -Identity $domain.Name -MinPasswordAge 0.00:00:00

# Auditoría (grupo 4)
Set-GPRegistryValue -Name $gpoGroup4.DisplayName -Key "HKLM\\System\\CurrentControlSet\\Control\\Lsa" -ValueName "AuditBaseObjects" -Type DWord -Value 1

# Cuotas disco C
fsutil quota track C:
fsutil quota enforce C:

# Aplicar políticas
Invoke-GPUpdate -Force
gpupdate /force
