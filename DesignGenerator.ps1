param
(
    [String]$ShipsBasePath="Ships"
)
$ErrorActionPreference = 'Stop'

$HomeLocation = $PWD

Clear-Host

$UtilPath = $(Join-Path -Path $HomeLocation -ChildPath 'Util.ps1')

. $UtilPath

$ShipsPath = Get-Path $ShipsBasePath

$ShipsXML = Get-Data (Join-Path -Path $PSScriptRoot -ChildPath "Ships.xml")

function Save-Ship($ship)
{
    $filename = ("{0}.xml" -f $ship["Name"])
    $fullpath = Join-Path -Path $ShipsPath -ChildPath $filename
    Write-Host("Save-Ship({0})" -f $ship["Name"])
    Export-Clixml -Path $fullpath -InputObject $ship -Force
}

function Set-Type($ship)
{
    $hull = $ship["Hull"]
    $screen = 0
    $capital = 0
    $carrier = 0
    $submarine = 0
    $convoy = 0
    
    if ($hull -eq "DD" -or $hull -eq "CL")
    {
        $screen = 1
    }
    elseif ($hull -eq "CA" -or $hull -eq "BC" -or $hull -eq "BB") {
        $capital = 1
    }
    elseif ($hull -eq "CV") {
        $carrier = 1
    }
    elseif ($hull -eq "SS") {
        $submarine = 1
    }
    elseif ($hull -eq "Convoy") {
        $convoy = 1
    }
    $ship.Screen = $screen
    $ship.Capital = $capital
    $ship.Carrier = $carrier
    $ship.Submarine = $submarine
    $ship.Convoy = $convoy
}

function Get-Profile($ship)
{
    # The hit profile of a ship is its surface/sub visibility multiplied by 100 and divided by its speed.
    if ($ship.Hull -eq "Convoy")
    {
        return 120
    }
    $retVal = ($ship.Visibility / $ship.Speed) * 100.0
    return $retVal
}

function Xml-To-Ship($xmlShip)
{ 
    $thisShip = @{}
    $thisShip["Name"] = $xmlShip.Name -as [string]
    $thisShip["Hull"] = $xmlShip.Hull -as [string]
    $thisShip["LightAttack"] = $xmlShip.LightAttack -as [double]
    $thisShip["LightPiercing"] = $xmlShip.LightPiercing -as [double]
    $thisShip["Armor"] = $xmlShip.Armor -as [double]
    $thisShip["Speed"] = $xmlShip.Speed -as [double]
    $thisShip["Visibility"] = $xmlShip.Visibility -as [double]
    $thisShip["HitPoints"] = $xmlShip.HitPoints -as [double]
    $thisShip["HP"] = $thisShip["HitPoints"]
    $thisShip["Organisation"] = $xmlShip.Organisation -as [double]
    $thisShip["Torpedo"] = $xmlShip.Torpedo -as [double]
    Set-Type($thisShip)
    

    $thisShip["Profile"] = Get-Profile $thisShip
    return $thisShip
}

function Create-Presets($xmlFile)
{
    Write-Host "Create Presets"
    
    foreach ($shipXML in $xmlFile.Ships.ChildNodes)
    {
        $thisShip = Xml-To-Ship $shipXML
        Save-Ship $thisShip
    }
}

Create-Presets $ShipsXML



