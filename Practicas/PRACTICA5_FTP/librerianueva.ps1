function comprobarPassword {
    param (
        [string]$clave
    )

    if ($clave.Length -lt 8) { return $false }
    if ($clave -notmatch "[A-Z]") { return $false }
    if ($clave -notmatch "[a-z]") { return $false }
    if ($clave -notmatch "\d") { return $false }
    if ($clave -notmatch "[!@#\$%\^&\*]") { return $false }

    return $true
}