Import-Module "C:\Users\Administrator\Desktop\Windows2025lib.ps1"

Import-Module ActiveDirectory
$domain = Get-ADDomain
$domainDN = $domain.DistinguishedName


# Registrar Logins y Cambios 
if(-not (Get-GPO -Name "auditoria_AD" -ErrorAction SilentlyContinue)){
    New-GPO -Name "auditoria_AD" | New-GPLink -Target $domainDN -LinkEnabled Yes

    Set-GPRegistryValue -Name "auditoria_AD" `
        -Key "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System\Audit" `
        -ValueName "AuditAccountLogon" -Type DWord -Value 3
    
    Set-GPRegistryValue -Name "auditoria_AD" `
        -Key "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System\Audit" `
        -ValueName "AuditAccountManage" -Type DWord -Value 3
    
    Set-GPRegistryValue -Name "auditoria_AD" `
        -Key "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System\Audit" `
        -ValueName "AuditLogonEvents" -Type DWord -Value 3

    $subcategories = @(
        "Directory Service Changes",
        "Directory Service Access",
        "Logon",
        "Logoff",
        "Account Lockout",
        "User Account Management",
        "Computer Account Management", 
        "Security Group Management",   
        "Authorization Policy Change"
    )

    foreach ($subcategory in $subcategories) {
        try {
            & AuditPol.exe /set /subcategory:"$subcategory" /success:enable /failure:enable
        }
        catch {
            Write-Host "Subcategoria configurada erroneamente $subcategory :$_" -ForegroundColor Red
        }
    }
    wevtutil set-log Security /ms:504857600 /rt:false /q:true  # 100MB máximo
    Set-GPRegistryValue -Name "auditoria_AD" `
        -Key "HKLM\SOFTWARE\Policies\Microsoft\Windows\EventLog\Security" `
        -ValueName "MaxSize" `
        -Type DWord `
        -Value 504857600
}

if ((Get-ADDomainController).HostName -eq $env:COMPUTERNAME) {
    wecutil qc /q | Out-Null
    $subscription = @"
<Subscription>
    <Query>
        <![CDATA[
            <QueryList>
                <Query Id="0" Path="Security">
                    <Select Path="Security">
                        *[System[(EventID=5136 or EventID=4662 or EventID=4720 or 
                        EventID=4722 or EventID=4738 or EventID=4767)]]
                    </Select>
                </Query>
            </QueryList>
        ]]>
    </Query>
    <ReadExistingEvents>true</ReadExistingEvents>
    <TransportName>HTTP</TransportName>
</Subscription>
"@
    $subscription | Out-File -FilePath "$env:TEMP\ADAuditSub.xml" -Force
    wecutil cs "$env:TEMP\ADAuditSub.xml" | Out-Null
}

# Forzar actualización de políticas
Invoke-GPUpdate -Force
gpupdate /force

# Añadir Unidades organizativas

$OUs = @("cuates", "nocuates")
foreach ($ou in $OUs) {
    if (-not (Get-ADOrganizationalUnit -Filter "Name -eq '$ou'" -ErrorAction SilentlyContinue)) {
        New-ADOrganizationalUnit -Name $ou -Path $domainDN -ProtectedFromAccidentalDeletion $false
    }
}

# Añadir usuarios
$users = Get-UserData
$users | Format-Table -AutoSize

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
            -PasswordNeverExpires $false
            # -ChangePasswordAtLogon $true
    }

}

# Crear GPOs
if(-not (Get-GPO -Name "GPO_Cuates" -ErrorAction SilentlyContinue)){
    $gpoGroup1 = New-GPO -Name "GPO_Cuates"
    New-GPLink -Name $gpoGroup1.DisplayName -Target "OU=cuates,$domainDN"
    
    # Configurar políticas para "cuates"
    # Permitir solo abrir notepad.exe  (Grupo 1)
    Set-GPRegistryValue -Name $gpoGroup1.DisplayName -Key "HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer" -ValueName "RestrictRun" -Type DWord -Value 1
    Set-GPRegistryValue -Name $gpoGroup1.DisplayName -Key "HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer\RestrictRun" -ValueName "1" -Type String -Value "notepad.exe"
    # Limitar perfil de usuario a 5 MB para Grupo 1
    Set-GPRegistryValue -Name $gpoGroup1.DisplayName -Key "HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\System" -ValueName "EnableProfileQuota" -Type DWord -Value 1
    Set-GPRegistryValue -Name $gpoGroup1.DisplayName -Key "HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\System" -ValueName "MaxProfileSize" -Type DWord -Value 5120
    Set-GPRegistryValue -Name $gpoGroup1.DisplayName -Key "HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\System" -ValueName "WarnUser" -Type DWord -Value 1
    Set-GPRegistryValue -Name $gpoGroup1.DisplayName -Key "HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\System" -ValueName "WarnUserTimeout" -Type DWord -Value 10
    Set-GPRegistryValue -Name $gpoGroup1.DisplayName -Key "HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\System" -ValueName "ProfileQuotaMessage" -Type String -Value "Has superado tu limite de 5 MB de perfil. Libera espacio."
}

if(-not (Get-GPO -Name "GPO_NoCuates" -ErrorAction SilentlyContinue)){
    $gpoGroup2 = New-GPO -Name "GPO_NoCuates"
    New-GPLink -Name $gpoGroup2.DisplayName -Target "OU=nocuates,$domainDN"

    # Configurar políticas para "nocuates"
    # Bloquear notepad.exe (Grupo 2)
    Set-GPRegistryValue -Name $gpoGroup2.DisplayName -Key "HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer" -ValueName "DisallowRun" -Type DWord -Value 1
    Set-GPRegistryValue -Name $gpoGroup2.DisplayName -Key "HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer\DisallowRun" -ValueName "1" -Type String -Value "notepad.exe"
    # Limitar perfil de usuario a 10 MB para Grupo 2
    Set-GPRegistryValue -Name $gpoGroup2.DisplayName -Key "HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\System" -ValueName "EnableProfileQuota" -Type DWord -Value 1
    Set-GPRegistryValue -Name $gpoGroup2.DisplayName -Key "HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\System" -ValueName "MaxProfileSize" -Type DWord -Value 10240
    Set-GPRegistryValue -Name $gpoGroup2.DisplayName -Key "HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\System" -ValueName "WarnUser" -Type DWord -Value 1
    Set-GPRegistryValue -Name $gpoGroup2.DisplayName -Key "HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\System" -ValueName "WarnUserTimeout" -Type DWord -Value 10
    Set-GPRegistryValue -Name $gpoGroup2.DisplayName -Key "HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\System" -ValueName "ProfileQuotaMessage" -Type String -Value "Has superado tu limite de 10 MB de perfil. Libera espacio."
}

#  Configurar el grupo 1 con horario de acceso de 8am a 3pm
foreach ($user in $users) {
    if ($user.OU -eq "cuates") {
        Set-LogonHours -Identity $user.Name -TimeIn24Format (8..15) -Monday -Tuesday -Wednesday -Thursday -Friday -NonSelectedDaysare NonWorkingDays 
    }
}

#  Configurar el grupo 2 con horario de acceso de 3pm a 2am
foreach ($user in $users) {
    if ($user.OU -eq "nocuates") {
        Set-LogonHours -Identity $user.Name -TimeIn24Format (15..23 + 0..2) -Monday -Tuesday -Wednesday -Thursday -Friday -NonSelectedDaysare NonWorkingDays 
    }
}

# Crear carpetas de los usuarios en Profiles
if (-not (Test-Path "C:\Profiles")) {
    New-Item -Path "C:\" -Name "Profiles" -ItemType "directory"
}
New-SmbShare -Path "C:\Profiles" -Name "Profiles"
Grant-SmbShareAccess -Name "Profiles" -AccountName "Everyone" -AccessRight Full -Confirm:$false

$machine = $env:COMPUTERNAME
foreach ($user in $users) {
    Set-ADUser -Identity $user.Name -ProfilePath "\\$machine\Profiles\$($user.Name)"
}

# Para que pueda cambiarla
Set-ADDefaultDomainPasswordPolicy -Identity "reprobados.com" -MinPasswordAge 0.00:00:00

# Forzar actualización de políticas
Invoke-GPUpdate -Force
gpupdate /force

do {
    Write-Host "1. Ver inicios de sesion de un usuario"
    Write-Host "2. Ver cambios dentro de Active Directory"
    Write-Host "3. Salir"
    
    # Bucle interno para validar la entrada
    do {
        $opc = Read-Host "Seleccione una opcion (1-3)"
    } while ($opc -notmatch '^[1-3]$')  # Solo acepta 1, 2 o 3

    switch ($opc) {
        "1" {
            $userOpc = Read-Host "Ingrese el nombre de usuario a auditar"
            Get-LogonsUser -user $userOpc
        }
        "2" {
            Get-ADEvents
        }
        "3" {
            break
        }
    }
} while ($opc -ne "3")
