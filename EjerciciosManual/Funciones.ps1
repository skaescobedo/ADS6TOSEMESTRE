#FUNCIONES
function Get-Fecha{
    Get-Date
}

Get-Fecha

Get-ChildItem -Path Function:\Get-*

Get-ChildItem -Path Function:\Get-Fecha | Remove-Item

Get-ChildItem -Path Function:\Get-*

#FUNCIONES CON PARAMETROS

function Get-Resta {
    Param([int]$num1, [int]$num2)
    $resta = $num1-$num2
    Write-Host "La resta de los parametros es $resta"
}

Get-Resta 2 1  #Devolveria 1 por el orden de los parametros
Get-Resta -num2 2 -num1 1 #Devolveria -1 ya que estamos especificando el valor de cada parametro
Get-Resta -num2 2 #Devolveria -2

function Get-Resta {
    Param ([Parameter(Mandatory)][int]$num1, [int]$num2)
    $resta = $num1 - $num2
    Write-Host "La resta de los parametros es $resta"
}
 Get-Resta -num2 10

function Get-Resta {
    [CmdletBinding()]
    Param([int]$num1, [int]$num2)
    $resta = $num1 - $num2
    Write-Host "La resta de los parametros es $resta"
}

Get-Resta 10 20

(Get-Command -Name Get-Resta).Parameters.Keys


function Get-Resta {
    [CmdletBinding()]
    Param([int]$num1, [int]$num2)
    $resta = $num1 - $num2
    Write-Verbose -Message "Operacion que va a realizar una resta de $num1 y $num2"
    Write-Host "La resta de los parametros es $resta"
}

Get-Resta 10 5 -Verbose
Get-Verb