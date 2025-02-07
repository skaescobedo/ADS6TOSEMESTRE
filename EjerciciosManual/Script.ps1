#TRY CATCH
try{
    Write-Output "Todo esta bien"
}catch{
    Write-Output "Algo lanzo una excepcion"
    Write-Output $_
}

try{
    Start-Something -ErrorAction Stop
}catch{
    Write-Output "Algo genero una excepcion o uso Write-Error"
    Write-Output $_
}

Write-Output "   "


#Try finally
$comando = [System.Data.SqlClient.SqlCommand]::New(queryString, connection)
try{
    $comando.Connection.Open()
    $comando.ExecuteNonQuery()
}
finally{
    Write-Error "Ha habido un problema con la ejecucion de la query.Cerrando la conexion"
    $comando.Connection.Close()

}


$path="a"
try{
   Start-Something -Path $path -ErrorAction Stop
}
catch [System.IO.DirectoryNotFoundException],[System.IO.FileNotFoundException]
{
    Write-Output "El directorio o fichero no ha sido encontrado: [$path]"
}
catch [System.IO.IOException]{
    Write-Output "Error de IO con el archivo [$path]"
}


throw "No se puede encontrar la ruta: [$path]"
throw [System.IO.FileNotFoundException]"No se puede encontrar la ruta: [$path]"
throw [System.IO.FileNotFoundException]::new()
throw [System.IO.FileNotFoundException]::new("No se puede encontrar la ruta [$path]")
throw (New-Object -TypeName System.IO.FileNotFoundException)
throw (New-Object -TypeName System.IO.FileNotFoundException -ArgumentList "No se puede encontrar la ruta [$path]")


trap{
    Write-Output $PSItem.ToString()
}
throw [System.Exception]::new('primero')
throw [System.Exception]::new('segundo')
throw [System.Exception]::new('tercero')


function Backup-Registry {
    Param(
    [Parameter(Mandatory = $true)]
    [String]$rutaBackup
    )
    
    if (!(Test-Path -Path $rutaBackup)){
        New-Item -ItemType Directory -Path $rutaBackup | Out-Null
    }

    
    $logDirectory = "$env:C:\Users\Administrador\AppData\RegistryBackup"    
    $logFIle = Join-Path $logDirectory "backup-registry_log.txt"
    $logEntry = "$(Get-Date) -$env:USERNAME - Backup - $backupPath"
    
    if (!(Test-Path -Path $logDirectory)){
        New-Item -ItemType Directory -Path $logDirectory | Out-Null
    }

    Add-Content -Path $logFIle -Value $logEntry

    $nombreArchivo = "Backup-Registry_" + (Get-Date -Format "yyyy-MM-dd_HH-mm-ss")+".reg"
    $rutaArchivo = Join-Path -Path $rutaBackup -ChildPath $nombreArchivo


    $backupCount = 10 
    $backups = Get-ChildItem $backupDirectory -Filter *.reg | Sort-Object LastWriteTime -Descending
    if($backups.Count -gt $backupCount) {
        $backupsToDelete = $backups[$backupCount..($backups.Count -1)]
        $backupsToDelete | Remove Item -Force
    }       
    
    try{
        Write-Host "Realizando backup del registro del sistema en  $rutaArchivo...."
        reg export HKLM $rutaArchivo
        Write-Host "El backup del registro del sistema se ha realizado con éxito."
    }
    catch
    {
        Write-Host "Se ha producido un error al intentantar realizar el backup del registro del sistema: $_"

    }


}

Backup-Registry



@{
    ModuleVersion='1.0.0'
    PowerShellVersion='5.1'
    RootModule='Backup-Registry.ps1'
    Description = 'Modulo para realizar backups del registro del sistema de Windows'
    Author='Luis'
    FunctionsToExport=@('Backup-Registry')
}



#Importar modulo
Import-Module BackupRegistry


Get-Help Backup-Registry

Backup-Registry -rutaBackup 'C:\'





$Time = New-ScheduledTaskTrigger -At 02:00 -Daily 
$PS = New-ScheduledTaskAction -Execute "Powershell.exe" -Argument "-Command `"Import-Module BackupRegistry -Force; Backup-Registry rutaBackup 'C:\'`"" 
Register-ScheduledTask -TaskName "Ejecutar Backup del Registro del Sistema" -Trigger $Time -Action $PS 



Get-ScheduledTask -TaskName "Ejecutar Backup del Registro del Sistema"

Unregister-ScheduledTask "Ejecutar Backup del Registro del Sistema"