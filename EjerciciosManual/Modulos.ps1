#MODULOS

Get-Module

Get-Module -ListAvailable

Get-Module
Get-Command -Module BitsTransfer
Get-Help BitsTransfer

$env:PSModulePath

Import-Module BitsTransfer
Get-Module
Remove-Module BitsTransfer
Write-Host "Este es otro Get-Module"
Get-Module
Get-Module -ListAvailable -All
