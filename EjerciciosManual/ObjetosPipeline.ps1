#GetMember

Get-Service -Name "LSM" | Get-Member

Get-Service -Name "LSM" | Get-Member -MemberType Property

Get-Item .\test.txt | Get-Member -MemberType Method

#Get-Object

Get-Item .\test.txt | Select-Object Name, Length

Get-Service | Select-Object -Last 5

Get-Service | Select-Object -First 5

#Where-Object

Get-Service | Where-Object {$_.Status -eq "Running"}

(Get-Item .\test.txt).IsReadOnly

(Get-Item .\test.txt).IsReadOnly=1

(Get-Item .\test.txt).IsReadOnly

Get-ChildItem *.txt

(Get-Item .\test.txt).CopyTo("C:\Users\luuis\OneDrive\Escritorio\prueba.txt")

(Get-Item .\test.txt).Delete()

$miObjeto = New-Object PSObject
$miObjeto | Add-Member -MemberType NoteProperty -Name Nombre -Value "Miguel"
$miObjeto | Add-Member -MemberType NoteProperty -Name Edad -Value 23
$miObjeto | Add-Member -MemberType ScriptMethod -Name Saludar -Value { Write-Host "¡Hola Mundo!" }

$m10bjeto = New-Object -TypeName PSObject -Property @{
Nombre = "Miguel"
Edad = 23
}

$m10bjeto | Add-Member -MemberType ScriptMethod -Name Saludar -Value { Write-Host "¡Hola Mundo!" }

$m10bjeto | Get-Member

$miObjecto = [PSCustomObject] @{
    Nombre = "Miguel"
    Edad = 23
}

$miObjecto | Add-Member -MemberType ScriptMethod -Name Saludar -Value { Write-Host "¡Hola Mundo!" }

$miObjecto | Get-Member

#Pipeline
Get-Process -Name msedge | Stop-Process

Get-Help -Full Get-Process

Get-Help -Full Stop-Process

Get-Help -Full Get-ChildItem

Get-Help -Full Get-Clipboard

Get-ChildItem *.txt | Get-Clipboard

Get-Help -Full Stop-Service

Get-Service

Get-Service Spooler | Stop-Service

Get-Service Spooler | Start-Service

"Spooler" | Stop-Service

Get-Service

Get-Service Spooler | Start-Service

$miObjeto = [PSCustomObject] @{
Name="Spooler"
}

$miObjeto | Stop-Service

Get-Service