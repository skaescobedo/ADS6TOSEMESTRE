Write-Output "Administración de Servicios"
Get-Service

Get-Service -Name Spooler

Get-Service -DisplayName Ho*

Get-Service | Where-Object {$_.Status -eq "Running"}

Get-Service | Where-Object {$_.StartType -eq "Automatic"} | Select-Object Name,StartType

Get-Service -DependentServices httpd

Get-Service -RequiredServices Spooler

Stop-Service -Name Spooler -Confirm -PassThru

Start-Service -Name Spooler -Confirm -PassThru

Start-Service -Name stisvc -Confirm -PassThru

Suspend-Service -Name stisvc -Confirm -PassThru

Get-Service | Where-Object CanPauseAndContinue -eq True

Suspend-Service -Name Spooler

Restart-Service -Name WSearch -Confirm -PassThru
