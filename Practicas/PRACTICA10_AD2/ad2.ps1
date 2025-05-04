Import-Module "C:\Users\Administrator\Desktop\Windows2025lib.ps1"

function Get-UserData {
    $users = @()
    $continue = $true
    
    while ($continue) {
        # Solicitar nombre de usuario
        $username = capturarUsuarioFTPValido "Coloque el nombre del usuario (o 'salir')"
        if ($username.ToLower() -eq 'salir') {
            $continue = $false
            break
        }
        
        # Validar OU
        $ouChoice = $null
        while ($ouChoice -notin @('1', '2', '3', '4')) {
            $ouChoice = Read-Host "Selecciona su OU (1, 2, 3, 4)"
        }
        
        if ($ouChoice -eq '1') {
            $ouName = "grupo1"
        } elseif ($ouChoice -eq '2') {
            $ouName = "grupo2"
        } elseif ($ouChoice -eq '3') {
            $ouName = "grupo3"
        } else {
            $ouName = "grupo4"
        }
        
        $pass = capturarContra

        # Agregar usuario al array
        $users += @{
            Name      = $username
            GivenName = "Usuario"
            Surname   = $username
            OU        = $ouName
            Pass      = $pass
        }
    }
    
    return $users
}

Function Set-LogonHours {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $True)]
        [ValidateRange(0, 23)]
        [int[]]$TimeIn24Format,

        [Parameter(Mandatory = $True, ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True, Position = 0)]
        [string]$Identity,

        [Parameter(Mandatory = $False)]
        [ValidateSet("WorkingDays", "NonWorkingDays")]
        [string]$NonSelectedDaysare = "NonWorkingDays",

        [Parameter(Mandatory = $False)][switch]$Sunday,
        [Parameter(Mandatory = $False)][switch]$Monday,
        [Parameter(Mandatory = $False)][switch]$Tuesday,
        [Parameter(Mandatory = $False)][switch]$Wednesday,
        [Parameter(Mandatory = $False)][switch]$Thursday,
        [Parameter(Mandatory = $False)][switch]$Friday,
        [Parameter(Mandatory = $False)][switch]$Saturday
    )

    Process {
        $FullByte = New-Object "byte[]" 21
        $FullDay = [ordered]@{}
        0..23 | ForEach-Object { $FullDay.Add($_, "0") }

        $TimeIn24Format.ForEach({ $FullDay[$_] = "1" })
        $Working = -join ($FullDay.Values)

        switch ($NonSelectedDaysare) {
            'NonWorkingDays' {
                $SundayValue = $MondayValue = $TuesdayValue = $WednesdayValue = `
                    $ThursdayValue = $FridayValue = $SaturdayValue = "000000000000000000000000"
            }
            'WorkingDays' {
                $SundayValue = $MondayValue = $TuesdayValue = $WednesdayValue = `
                    $ThursdayValue = $FridayValue = $SaturdayValue = "111111111111111111111111"
            }
        }

        switch ($PSBoundParameters.Keys) {
            'Sunday'    { $SundayValue = $Working }
            'Monday'    { $MondayValue = $Working }
            'Tuesday'   { $TuesdayValue = $Working }
            'Wednesday' { $WednesdayValue = $Working }
            'Thursday'  { $ThursdayValue = $Working }
            'Friday'    { $FridayValue = $Working }
            'Saturday'  { $SaturdayValue = $Working }
        }

        $AllTheWeek = "{0}{1}{2}{3}{4}{5}{6}" -f `
            $SundayValue, $MondayValue, $TuesdayValue, $WednesdayValue, `
            $ThursdayValue, $FridayValue, $SaturdayValue

        # Ajustar zona horaria si es necesario
        $offset = (Get-TimeZone).BaseUtcOffset.Hours

        if ($offset -lt 0) {
            $TimeZoneOffset = $AllTheWeek.Substring(0, 168 + $offset)
            $TimeZoneOffset1 = $AllTheWeek.Substring(168 + $offset)
            $FixedTimeZoneOffSet = "$TimeZoneOffset1$TimeZoneOffset"
        }
        elseif ($offset -gt 0) {
            $TimeZoneOffset = $AllTheWeek.Substring(0, $offset)
            $TimeZoneOffset1 = $AllTheWeek.Substring($offset)
            $FixedTimeZoneOffSet = "$TimeZoneOffset1$TimeZoneOffset"
        }
        else {
            $FixedTimeZoneOffSet = $AllTheWeek
        }

        # Convertir binario a bytes (logonHours espera 21 bytes)
        $i = 0
        $BinaryResult = $FixedTimeZoneOffSet -split '(\d{8})' | Where-Object { $_ -match '(\d{8})' }

        foreach ($singleByte in $BinaryResult) {
            $Tempvar = $singleByte.ToCharArray()
            [array]::Reverse($Tempvar)
            $Tempvar = -join $Tempvar
            $Byte = [Convert]::ToByte($Tempvar, 2)
            $FullByte[$i] = $Byte
            $i++
        }

        Set-ADUser -Identity $Identity -Replace @{logonhours = $FullByte}
    }

    End {
        Write-Output "Todo hecho =P"
    }
}


Import-Module ActiveDirectory
$domain = Get-ADDomain
$domainDN = $domain.DistinguishedName

# Crear carpeta principal para perfiles móviles
New-Item -Path "C:\Profiles" -ItemType Directory -Force
If (-not (Get-SmbShare -Name "Profiles" -ErrorAction SilentlyContinue)) {
    New-SmbShare -Path "C:\Profiles" -Name "Profiles" -FullAccess "Everyone"
}

# Crear OUs
$OUs = @("grupo1", "grupo2", "grupo3", "grupo4")
foreach ($ou in $OUs) {
    if (-not (Get-ADOrganizationalUnit -Filter "Name -eq '$ou'" -ErrorAction SilentlyContinue)) {
        New-ADOrganizationalUnit -Name $ou -Path $domainDN -ProtectedFromAccidentalDeletion $false
    }
}

# Obtener usuarios
$users = Get-UserData
$users | Format-Table -AutoSize

foreach ($user in $users) {
    $username = $user.Name
    $ouPath = "OU=$($user.OU),$domainDN"
    $profileFolder = "C:\Profiles\$username"

    # Crear carpeta de perfil individual
    if (-not (Test-Path $profileFolder)) {
        New-Item -Path $profileFolder -ItemType Directory -Force
    }

    # Asignar permisos NTFS al usuario
    $acl = Get-Acl $profileFolder
    $rule = New-Object System.Security.AccessControl.FileSystemAccessRule("REPROBADOS\\$username", "FullControl", "ContainerInherit,ObjectInherit", "None", "Allow")
    $acl.SetAccessRule($rule)
    Set-Acl $profileFolder $acl

    # Crear usuario
    if (-not (Get-ADUser -Filter "SamAccountName -eq '$username'" -ErrorAction SilentlyContinue)) {
        $params = @{
            Name              = "$($user.GivenName) $($user.Surname)"
            GivenName         = $user.GivenName
            Surname           = $user.Surname
            SamAccountName    = $username
            UserPrincipalName = "$username@$($domain.DNSRoot)"
            AccountPassword   = (ConvertTo-SecureString $user.Pass -AsPlainText -Force)
            Enabled           = $true
            Path              = $ouPath
            ProfilePath       = "\\$env:COMPUTERNAME\Profiles\$username"
        }

        # Contraseña expira solo para grupo4
        $params["PasswordNeverExpires"] = if ($user.OU -eq "grupo4") { $false } else { $true }

        New-ADUser @params
    } else {
        Set-ADUser -Identity $username -ProfilePath "\\$env:COMPUTERNAME\Profiles\$username"
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

# --- Límite de perfil (Group Policy Registry) ---
# Grupo 1: 5 MB
Set-GPRegistryValue -Name $gpoGroup1.DisplayName -Key "HKCU\\Software\\Microsoft\\Windows\\CurrentVersion\\Policies\\System" -ValueName "EnableProfileQuota" -Type DWord -Value 1
Set-GPRegistryValue -Name $gpoGroup1.DisplayName -Key "HKCU\\Software\\Microsoft\\Windows\\CurrentVersion\\Policies\\System" -ValueName "MaxProfileSize" -Type DWord -Value 5120
Set-GPRegistryValue -Name $gpoGroup1.DisplayName -Key "HKCU\\Software\\Microsoft\\Windows\\CurrentVersion\\Policies\\System" -ValueName "WarnUser" -Type DWord -Value 1
Set-GPRegistryValue -Name $gpoGroup1.DisplayName -Key "HKCU\\Software\\Microsoft\\Windows\\CurrentVersion\\Policies\\System" -ValueName "WarnUserTimeout" -Type DWord -Value 10
Set-GPRegistryValue -Name $gpoGroup1.DisplayName -Key "HKCU\\Software\\Microsoft\\Windows\\CurrentVersion\\Policies\\System" -ValueName "ProfileQuotaMessage" -Type String -Value "Has superado tu límite de 5 MB de perfil. Libera espacio."

# Grupo 2: 10 MB
Set-GPRegistryValue -Name $gpoGroup2.DisplayName -Key "HKCU\\Software\\Microsoft\\Windows\\CurrentVersion\\Policies\\System" -ValueName "EnableProfileQuota" -Type DWord -Value 1
Set-GPRegistryValue -Name $gpoGroup2.DisplayName -Key "HKCU\\Software\\Microsoft\\Windows\\CurrentVersion\\Policies\\System" -ValueName "MaxProfileSize" -Type DWord -Value 10240
Set-GPRegistryValue -Name $gpoGroup2.DisplayName -Key "HKCU\\Software\\Microsoft\\Windows\\CurrentVersion\\Policies\\System" -ValueName "WarnUser" -Type DWord -Value 1
Set-GPRegistryValue -Name $gpoGroup2.DisplayName -Key "HKCU\\Software\\Microsoft\\Windows\\CurrentVersion\\Policies\\System" -ValueName "WarnUserTimeout" -Type DWord -Value 10
Set-GPRegistryValue -Name $gpoGroup2.DisplayName -Key "HKCU\\Software\\Microsoft\\Windows\\CurrentVersion\\Policies\\System" -ValueName "ProfileQuotaMessage" -Type String -Value "Has superado tu límite de 10 MB de perfil. Libera espacio."

# Grupo 1: permitir solo notepad
Set-GPRegistryValue -Name $gpoGroup1.DisplayName -Key "HKCU\\Software\\Microsoft\\Windows\\CurrentVersion\\Policies\\Explorer" -ValueName "RestrictRun" -Type DWord -Value 1
Set-GPRegistryValue -Name $gpoGroup1.DisplayName -Key "HKCU\\Software\\Microsoft\\Windows\\CurrentVersion\\Policies\\Explorer\\RestrictRun" -ValueName "1" -Type String -Value "notepad.exe"

# Grupo 2: bloquear notepad
Set-GPRegistryValue -Name $gpoGroup2.DisplayName -Key "HKCU\\Software\\Microsoft\\Windows\\CurrentVersion\\Policies\\Explorer" -ValueName "DisallowRun" -Type DWord -Value 1
Set-GPRegistryValue -Name $gpoGroup2.DisplayName -Key "HKCU\\Software\\Microsoft\\Windows\\CurrentVersion\\Policies\\Explorer\\DisallowRun" -ValueName "1" -Type String -Value "notepad.exe"

# Horarios por grupo
foreach ($user in $users) {
    if ($user.OU -eq "grupo1") {
        Set-LogonHours -Identity $user.Name -TimeIn24Format (8..15) -Monday -Tuesday -Wednesday -Thursday -Friday -NonSelectedDaysare NonWorkingDays
    } elseif ($user.OU -eq "grupo2") {
        Set-LogonHours -Identity $user.Name -TimeIn24Format (15..23 + 0..2) -Monday -Tuesday -Wednesday -Thursday -Friday -NonSelectedDaysare NonWorkingDays
    } elseif ($user.OU -eq "grupo4") {
        Set-ADUser -Identity $user.Name -ChangePasswordAtLogon $true
    }
}

# Política de contraseña para grupo4
Set-ADDefaultDomainPasswordPolicy -Identity "reprobados.com" -MinPasswordAge 0.00:00:00

# Auditoría (grupo 4)
Set-GPRegistryValue -Name $gpoGroup4.DisplayName -Key "HKLM\\System\\CurrentControlSet\\Control\\Lsa" -ValueName "AuditBaseObjects" -Type DWord -Value 1

# Actualizar políticas
Invoke-GPUpdate -Force
gpupdate /force
