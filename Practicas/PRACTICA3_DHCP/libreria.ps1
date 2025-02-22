function Validar-IP {
    param (
        [string]$IP
    )
    if ($IP -match '^([0-9]{1,3}\.){3}[0-9]{1,3}$') {
        $octetos = $IP -split '\.'
        foreach ($octeto in $octetos) {
            if ([int]$octeto -lt 0 -or [int]$octeto -gt 255) {
                return $false
            }
        }
        return $true
    }
    return $false
}

function Leer-IPValidada {
    param ([string]$Mensaje)
    do {
        $IP = Read-Host $Mensaje
        if (-not (Validar-IP $IP)) {
            Write-Host "Error: Dirección IP inválida. Intente nuevamente." -ForegroundColor Red
        }
    } while (-not (Validar-IP $IP))
    return $IP
}

function Convertir-IPaEntero {
    param ([string]$IP)
    $octetos = $IP -split '\.'
    return ([int]$octetos[0] * 16777216) + ([int]$octetos[1] * 65536) + ([int]$octetos[2] * 256) + [int]$octetos[3]
}

function Obtener-DireccionRed {
    param ([string]$IP, [string]$MascaraSubred)
    $ipEntero = Convertir-IPaEntero $IP
    $mascaraEntero = Convertir-IPaEntero $MascaraSubred
    $redEntero = $ipEntero -band $mascaraEntero
    return ($redEntero -shr 24).ToString() + "." + (($redEntero -shr 16) -band 255).ToString() + "." + (($redEntero -shr 8) -band 255).ToString() + "." + ($redEntero -band 255).ToString()
}

function Obtener-DireccionBroadcast {
    param ([string]$DireccionRed, [string]$MascaraSubred)
    $redOctetos = $DireccionRed -split '\.'
    $maskOctetos = $MascaraSubred -split '\.'
    $broadcastOctetos = for ($i=0; $i -lt 4; $i++) { [int]$redOctetos[$i] -bor ([int]$maskOctetos[$i] -bxor 255) }
    return ($broadcastOctetos -join '.')
}
Export-ModuleMember -Function Validar-IP, Leer-IPValidada, Convertir-IPaEntero, Obtener-DireccionRed, Obtener-DireccionBroadcast

