param
(
    [String]$PresetsPath="Presets"
)
$ErrorActionPreference = 'Stop'
$HomeLocation = $PWD



$UtilPath = $(Join-Path -Path $HomeLocation -ChildPath 'Util.ps1')
$NavalPath = $(Join-Path -Path $HomeLocation -ChildPath 'NavalCombat.ps1')

. $UtilPath
. $NavalPath


function Test-Presets()
{
    $PresetsPath = Get-FleetPath $PresetsPath
    $PresetFleets = @()

    Get-ChildItem $PresetsPath -Filter *.xml | 
    Foreach-Object {
        Write-Host("Found <{0}>" -f $_.FullName)
        $fleet = Import-Clixml -Path $_.FullName
        $PresetFleets += $fleet
    }

    $progressId = 0
    foreach($fleetA in $PresetFleets)
    {
        foreach($fleetB in $PresetFleets)
        {
            $progressId++
            Fight $fleetA $fleetB
        }
    }
    
}

Write-Host "Starting"
Test-Presets
Write-Host "Done"