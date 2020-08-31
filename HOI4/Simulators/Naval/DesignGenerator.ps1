param
(
    [String]$ShipsBasePath="Ships",
    [String]$FleetsBasePath="Fleets"
)
$ErrorActionPreference = 'Stop'

$HomeLocation = $PWD

Clear-Host

$UtilPath = $(Join-Path -Path $HomeLocation -ChildPath 'Util.ps1')

. $UtilPath

$ShipsPath = Get-Path $ShipsBasePath
$FleetsPath = Get-Path $FleetsBasePath

$ShipsXML = Get-Data (Join-Path -Path $PSScriptRoot -ChildPath "Ships.xml")
$FleetsXML = Get-Data (Join-Path -Path $PSScriptRoot -ChildPath "Fleets.xml")

function Save-Ship($ship)
{
    $filename = ("{0}.xml" -f $ship["Name"])
    $fullpath = Join-Path -Path $ShipsPath -ChildPath $filename
    Write-Host("Save-Ship({0})" -f $ship["Name"])
    Export-Clixml -Path $fullpath -InputObject $ship -Force
}

function Save-Fleet($Fleet)
{
    $filename = ("{0}.xml" -f $fleet["Name"])
    $fullpath = Join-Path -Path $FleetsPath -ChildPath $filename
    Write-Host("Save-Fleet({0})" -f $fleet["Name"])
    Export-Clixml -Path $fullpath -InputObject $fleet -Force
}

function Set-Type($ship)
{
    $hull = $ship["Hull"]
    $screen = 0
    $capital = 0
    $carrier = 0
    $submarine = 0
    $convoy = 0
    
    $targetType = "Unknown"
    if ($hull -eq "DD" -or $hull -eq "CL")
    {
        $screen = 1
        $targetType = "Screen"
    }
    elseif ($hull -eq "CA" -or $hull -eq "BC" -or $hull -eq "BB") {
        $capital = 1
        $targetType = "Capital"
    }
    elseif ($hull -eq "CV") {
        $carrier = 1
        $targetType = "Carrier"
    }
    elseif ($hull -eq "SS") {
        $submarine = 1
        $targetType = "Submarine"
    }
    elseif ($hull -eq "Convoy") {
        $convoy = 1
        $targetType = "Convoy"
    }
    $ship.Screen = $screen
    $ship.Capital = $capital
    $ship.Carrier = $carrier
    $ship.Submarine = $submarine
    $ship.Convoy = $convoy
    $ship.TargetType = $targetType
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

$allShips = @{}

function Create-Presets($xmlFile)
{
    Write-Host "Create Presets"
    
    foreach ($shipXML in $xmlFile.Ships.ChildNodes)
    {
        $thisShip = Xml-To-Ship $shipXML
        Save-Ship $thisShip
        $allShips[$thisShip["Name"]] = $thisShip
    }
}

function Xml-To-Fleet($xmlFleet)
{
    $thisFleet = @{}
    $thisFleet['Name'] = $xmlFleet.name -as [string]
    $thisFleet['Ships'] = @()
    foreach ($shipXML in $xmlFleet.ChildNodes)
    {
        if ($shipXML.Ref)
        {
            $shipName = $shipXML.Ref -as [string]
            $thisShip = $allShips[$shipName]
            $thisFleet['Ships'] += Deep-Copy $thisShip
        }
        else {
            $thisShip = Xml-To-Ship $shipXML
            $thisFleet['Ships'] += $thisShip
        }
    }
    return $thisFleet
}

function Create-Fleets($xmlFile)
{
    Write-Host 'Create Fleets'

    foreach ($fleetXML in $xmlFile.Fleets.ChildNodes)
    {
        $thisFleet = Xml-To-Fleet $fleetXML

        Save-Fleet $thisFleet
    }
}

Create-Presets $ShipsXML

Create-Fleets $FleetsXML



