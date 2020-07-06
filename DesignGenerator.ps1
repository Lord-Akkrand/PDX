param
(
    [String]$PresetsPath="Presets"
)
$ErrorActionPreference = 'Stop'

$HomeLocation = $PWD

Clear-Host

$UtilPath = $(Join-Path -Path $HomeLocation -ChildPath 'Util.ps1')

. $UtilPath

$PresetsPath = Get-FleetPath $PresetsPath

$PresetsXML = Get-Data (Join-Path -Path $PSScriptRoot -ChildPath "Presets.xml")

function Save-Ship($ship, $path)
{
    Write-Host("Save-Ship({0}, {1}" -f $ship, $path)
    $filename = Join-Path -Path $path -ChildPath ($ship["Name"] + ".xml")
    Export-Clixml -Path $filename -InputObject $ship -Force
}

function Is-Screen($hull)
{
    return ($hull -eq "DD" -or $hull -eq "CL")
}

function Get-Profile($ship)
{
    # The hit profile of a ship is its surface/sub visibility multiplied by 100 and divided by its speed.
    if ($ship.Hull -eq "Convoy")
    {
        return 120
    }
    
    return ($ship.Visibility * 100.0) / $ship.Speed
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
    $thisShip["Screen"] = Is-Screen $thisShip["Hull"]

    $thisShip["Profile"] = Get-Profile $thisShip
    return $thisShip
}

function Create-Presets($xmlFile)
{
    Write-Host "Create Presets"
    foreach ($shipXML in $xmlFile.Ships.ChildNodes)
    {
        $thisShip = Xml-To-Ship $shipXML

        Save-Ship $thisShip $PresetsPath
    }
}

Create-Presets $PresetsXML



