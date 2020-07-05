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

function Save-Fleet($fleet, $path)
{
    Write-Host("Save-Fleet({0}, {1}" -f $fleet, $path)
    $filename = Join-Path -Path $path -ChildPath ($fleet["Name"] + ".xml")
    Export-Clixml -Path $filename -InputObject $fleet -Force
}

function Xml-To-Ship($xmlShip)
{ 
    $thisShip = @{}
    $thisShip["Name"] = $xmlShip.Name -as [string]
    $thisShip["LightAttack"] = $xmlShip.LightAttack -as [double]
    $thisShip["LightPiercing"] = $xmlShip.LightPiercing -as [double]
    $thisShip["Armor"] = $xmlShip.Armor -as [double]
    $thisShip["Speed"] = $xmlShip.Speed -as [double]
    $thisShip["Visibility"] = $xmlShip.Visibility -as [double]
    $thisShip["HitPoints"] = $xmlShip.HitPoints -as [double]
    $thisShip["Organisation"] = $xmlShip.Organisation -as [double]
    $thisShip["Torpedo"] = $xmlShip.Torpedo -as [double]

    return $thisShip
}

function Create-Fleet($name)
{
    $thisFleet = @{}
    $thisFleet["Name"] = $name
    [System.Collections.ArrayList]$ships = @()
    $thisFleet["Ships"] = $ships

    return $thisFleet
}

function Add-To-Fleet($fleet, $ship)
{
    $fleet["Ships"].Add($ship)
}

function Create-Presets($xmlFile)
{
    Write-Host "Create Presets"
    foreach ($fleetXML in $xmlFile.Fleets.ChildNodes)
    {
        $fleet = Create-Fleet $fleetXML.Name
     
        foreach ($shipXML in $fleetXML.ChildNodes)
        {
            Write-Host("Add Ship")
            $thisShip = Xml-To-Ship $shipXML
            Add-To-Fleet $fleet $thisShip
        }

        Save-Fleet $fleet $PresetsPath
    }
}

Create-Presets $PresetsXML



