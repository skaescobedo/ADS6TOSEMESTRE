function Get-UserData {
    $users = @()
    $continue = $true

    while ($continue) {
        # Capturar y validar nombre de usuario
        $username = $null
        while ($null -eq $username) {
            $inputName = Read-Host "Coloque el nombre del usuario (o 'salir')"
            if ($inputName.ToLower() -eq 'salir') {
                $continue = $false
                break
            }
            if (Validar-NombreUsuario -nombreUsuario $inputName) {
                $username = $inputName
            } else {
                Write-Host "Por favor ingrese un nombre de usuario válido." -ForegroundColor Yellow
            }
        }
        if (-not $continue) { break }

        # Validar OU
        $ouChoice = $null
        while ($ouChoice -notin @('1', '2')) {
            $ouChoice = Read-Host "Selecciona su OU (1 para 'cuates', 2 para 'no cuates')"
        }
        $ouName = if ($ouChoice -eq '1') { "cuates" } else { "no cuates" }

        # Capturar y validar contraseña
        $pass = $null
        while ($null -eq $pass) {
            $inputPass = Read-Host "Coloca la contraseña (debe cumplir requisitos de seguridad)" -AsSecureString
            $plainPass = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
                            [Runtime.InteropServices.Marshal]::SecureStringToBSTR($inputPass)
                         )
            if (comprobarPassword -clave $plainPass) {
                $pass = $plainPass
            } else {
                Write-Host "La contraseña no cumple los requisitos. Debe tener entre 8-16 caracteres, incluyendo mayúscula, minúscula, número y símbolo." -ForegroundColor Yellow
            }
        }

        # Agregar usuario al array
        $users += [PSCustomObject]@{
            Name      = $username
            GivenName = "UsuarioAD"
            Surname   = $username
            OU        = $ouName
            Pass      = $pass
        }
    }

    return $users
}


function comprobarPassword {
    param (
        [string]$clave
    )
    $regex = "^(?=.*[A-Z])(?=.*[a-z])(?=.*[0-9])(?=.*[^A-Za-z0-9]).{8,16}$"

    if ($clave -match $regex) {
        return $true
    } else {
        return $false
    }
}

function Validar-NombreUsuario {
    param (
        [string]$nombreUsuario
    )

    # Lista de nombres reservados en Windows
    $nombresReservados = @(
        "CON", "PRN", "AUX", "NUL",
        "COM1", "COM2", "COM3", "COM4", "COM5", "COM6", "COM7", "COM8", "COM9",
        "LPT1", "LPT2", "LPT3", "LPT4", "LPT5", "LPT6", "LPT7", "LPT8", "LPT9"
    )

    # Caracteres inválidos
    $caracteresInvalidos = '[<>:"/\\|?*]'

    if ([string]::IsNullOrWhiteSpace($nombreUsuario)) {
        Write-Host "El nombre de usuario no puede estar vacío."
        return $false
    }

    if ($nombreUsuario.Length -gt 20) {
        Write-Host "El nombre de usuario no puede tener más de 20 caracteres."
        return $false
    }

    if ($nombreUsuario -match $caracteresInvalidos) {
        Write-Host "El nombre de usuario contiene caracteres no permitidos (< > : "" / \ | ? *)."
        return $false
    }

    if ($nombreUsuario -match '^\s|\s$') {
        Write-Host "El nombre de usuario no puede comenzar ni terminar con un espacio."
        return $false
    }

    if ($nombreUsuario -match '\.$') {
        Write-Host "El nombre de usuario no puede terminar con un punto."
        return $false
    }

    if ($nombreUsuario -in $nombresReservados) {
        Write-Host "El nombre de usuario '$nombreUsuario' es un nombre reservado por Windows."
        return $false
    }

    if (Get-LocalUser -Name $nombreUsuario -ErrorAction SilentlyContinue) {
        Write-Host "El usuario '$nombreUsuario' ya existe."
        return $false
    }

    if (Get-ADUser -Filter {SamAccountName -eq $nombreUsuario} -ErrorAction SilentlyContinue) {
        Write-Host "El usuario '$nombreUsuario' ya existe en Active Directory."
        return $false
    }

    return $true
}

Import-Module ActiveDirectory
$domain = Get-ADDomain
$domainDN = $domain.DistinguishedName

$OUs = @("cuates", "no cuates")
foreach ($ou in $OUs) {
    if (-not (Get-ADOrganizationalUnit -Filter "Name -eq '$ou'" -ErrorAction SilentlyContinue)) {
        New-ADOrganizationalUnit -Name $ou -Path $domainDN -ProtectedFromAccidentalDeletion $false
    }
}

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
            -PasswordNeverExpires $true
    }
}
