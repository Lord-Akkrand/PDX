param
(
)
$ErrorActionPreference = 'Stop'
$HomeLocation = $PWD



$UtilPath = $(Join-Path -Path $HomeLocation -ChildPath 'Util.ps1')
$NavalPath = $(Join-Path -Path $HomeLocation -ChildPath 'NavalCombat.ps1')

. $UtilPath
. $NavalPath

function Test-Presets
{
    $PresetsXML = Get-Data (Join-Path -Path $PSScriptRoot -ChildPath "Presets.xml")
    Write-Host $PresetsXML
    foreach ($aXML in $PresetsXML.Fleets.ChildNodes)
    {
        Write-Host "FleetA"
        foreach($bXML in $PresetsXML.Fleets.ChildNodes)
        {
            Write-Host "FleetB"
            $fleetA = Deep-Copy $aXML
            $fleetB = Deep-Copy $bXML
            Fight $fleetA $fleetB
        }
    }
}

Write-Host "Starting"
Test-Presets
Write-Host "Done"