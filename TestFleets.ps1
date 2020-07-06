param
(
    [String]$PresetsPath="Presets",
    [String]$OutputFile="Compare.csv"
)
$ErrorActionPreference = 'Stop'
$HomeLocation = $PWD



$UtilPath = $(Join-Path -Path $HomeLocation -ChildPath 'Util.ps1')
$NavalPath = $(Join-Path -Path $HomeLocation -ChildPath 'NavalCombat.ps1')
$OutputFile = $(Join-Path -Path $HomeLocation -ChildPath $OutputFile)

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
    $outputHeader = ""
    
    foreach($fleetA in $PresetFleets)
    {
        $outputHeader = ("{0}, {1}" -f $outputHeader, $fleetA.Name)
    }
    Set-Content -Path $OutputFile -Value $outputHeader

    foreach($fleetA in $PresetFleets)
    {
        $row = $fleetA.Name
        foreach($fleetB in $PresetFleets)
        {
            $progressId++
            $copyA = Deep-Copy $fleetA
            $copyB = Deep-Copy $fleetB
            $stats = Fight $copyA $copyB
            $row = ("{0}, {1}" -f $row, $stats)
        }
        Add-Content -Path $OutputFile -Value $row
    }
    
}

Write-Host "Starting"
Test-Presets
Write-Host "Done"