$variable1="Hola"
$variable2=" Que tal?"
$variable3=1000
${VAR iable4}=200

New-Variable -Name var5 -Value 300
$var5

$variable1
$variable2
$variable3
${VAR iable4}

$variable1+$variable2
$variable3+${VAR iable4}
$variable3-${VAR iable4}

$variable1+$variable2
$$

$variable1+' poni' +$variable2
$^

$variable1+$variable2
$?

$Error

Get-Help about_automatic_variables

Get-Help about_preference_variables