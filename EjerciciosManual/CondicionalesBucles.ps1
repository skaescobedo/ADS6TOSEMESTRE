$var1=200
$var2=200
if($var1 -eq $var2){
    $texto="Es el mismo número"
    $texto
}
elseif($var1 -ne $var2){ 
    $texto="No es el mismo número" 
    $texto
}

$condicion=$true
if($condicion){
    Write-Output "La condición es verdad"
}else{
    Write-Output "La condición es falsa"
}



[int]$number=1
if($number -ge 3){
    Write-Output "El numero $number es mayor que 3"
}
elseif ($number -lt 2){
    Write-Output "El numero $number es menor a 2"
}
else{
    Write-Output "El numero $number es igual a 2"
}



switch(1){
    1{"[$_] es uno."}
    2{"[$_] es dos."}
    3{"[$_] es tres."}
    4{"[$_] es cuatro."}
}


switch(3){
    1{"[$_] es uno."}
    2{"[$_] es dos."}
    3{"[$_] es tres."}
    4{"[$_] es cuatro."}
    3{"[$_] es tres de nuevo"}
}


switch(3){
    1{"[$_] es uno."}
    2{"primer [$_] es dos."}
    3{"[$_] es tres."; break}
    4{"[$_] es cuatro."}
    3{"[$_] es tres de nuevo"}
}


switch(1,5){
    1{"[$_] es uno."}
    2{"[$_] es dos."}
    3{"[$_] es tres."}
    4{"[$_] es cuatro."}
    5{"[$_] es cinco"}
}


switch("seis"){
    1{"[$_] es uno."}
    2{"[$_] es dos."}
    3{"[$_] es tres."}
    4{"[$_] es cuatro."}
    5{"[$_] es cinco"}
    "se*"{"[$_] coincide con se*"}
    default{
            "No coincide con $_"
            }
}


switch -Wildcard("seis"){
    1{"[$_] es uno."; break}
    2{"[$_] es dos."; break}
    3{"[$_] es tres."; break}
    4{"[$_] es cuatro."; break}
    5{"[$_] es cinco"; break}
    
    "se*"{"[$_] coincide con se*"}

    default{"No coincide con $_"}
}


$email="antonio.yanez@udc.es"
$email2="antonio.yanez@usc.gal"

$url="https://www.dc.fi.udc.es/~afyanez/Docencia/2023"

switch -Regex($url,$email,$email2){
    "^\w+\.\w+@(udc|usc|edu)\.es|gal$"{
       "[$_] Es una dirección de correo academica"
    }

    "^ftp\://.*$"{
       "[$_] Es una direccion FTP"
    }

    "^(http[s]?)\://.*$"{
        "[$_] Es una direccion web, que utiliza [$($matches[1])]"
    }

}


#Los valores a la derecha del operador serán transformados al tipo del valor de la izquierda
1 -eq "1.0" 

"1.0" -eq 1

#Bucle FOR
for(($i=0), ($j=0);$i -lt 5;($i++)){
    "`$i:$i"
    "`$j:$j"

}



for($($j = 0;$i = 0);$i -lt 5;$($i++;$j++)){
    "`$i:$i"
    "`$j:$j"
}


#Bucle FOR EACH
$ssoo="freebsd","openbsd", "solaris", "fedora", "ubuntu", "netbsd"
foreach($so in $ssoo)
{
    Write-Host $so
}


foreach($archivo in Get-childItem){
    if ($archivo.Length -ge 10KB){
        Write-Host $archivo -> [($archivo.length)]
    }
}

#WHILE
$num = 0
while ($num -ne 3)
{
    $num++
    Write-Host $num
}

$num = 0
while ($num -ne 5)
{
    if ($num -eq 1) { $num = $num + 3; Continue }
        $num++ 
        Write-Host $num
}

#DO-WHILE
$valor=5
$multiplicacion=1
do{
    $multiplicacion=$multiplicacion*$valor
    $valor--
}
while($valor -gt 0)
Write-Host $multiplicacion

#DO-UNTIL
$valor=5
$multiplicacion=1
do{
    $multiplicacion=$multiplicacion*$valor
    $valor--
}until($valor -eq 0)


Write-Host $multiplicacion

##BREAK Y CONTINUE
$num=10
for($i=2;$i -lt 10;$i++){
    $num=$num+$i
    if($i -eq 5){break}
}

Write-host $num
Write-Host $i


$cadena="Hola,buenas tardes"
$cadena2="Hola,buenas noches"

switch -Wildcard($cadena,$cadena2){
    "Hola,buenas*" {"$_ coincide con [Hola,buenas*]"}
    "Hola,bue*" {"$_ coincide con [Hola,bue*]"}
    "Hola,*" {"$_ coincide con [Hola,*]";break}
    "Hola,buenas tardes" {"$_ coincide con [Hola,buenas tardes]"}
}


$num=10
for($i=2;$i -lt 10; $i++){
    if($i -eq 5){Continue}
    $num=$num+$i
}

Write-Host $num
Write-host $i


$cadena="Hola,buenas tardes"
$cadena2="Hola,buenas noches"

switch -Wildcard($cadena,$cadena2){
    "Hola,buenas*" {"$_ coincide con [Hola,buenas*]"}
    "Hola,bue*" {"$_ coincide con [Hola,bue*]"; continue}
    "Hola,*" {"$_ coincide con [Hola,*]";}
    "Hola,buenas tardes" {"$_ coincide con [Hola,buenas tardes]"}
}
