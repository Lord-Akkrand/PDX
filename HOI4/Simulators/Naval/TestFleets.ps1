param
(
    [String]$FleetsPath="Fleets",
    [String]$OutputFile="FleetCompare.csv"
)
$ErrorActionPreference = 'Stop'
$HomeLocation = $PWD

$UtilPath = $(Join-Path -Path $HomeLocation -ChildPath 'Util.ps1')
$NavalPath = $(Join-Path -Path $HomeLocation -ChildPath 'NavalCombat.ps1')
$OutputFile = $(Join-Path -Path $HomeLocation -ChildPath $OutputFile)

. $UtilPath
. $NavalPath

Clear-Host

function Test-Presets()
{
    $FleetsPath = Get-Path $FleetsPath
    $PresetFleets = @()

    Get-ChildItem $FleetsPath -Filter *.xml | 
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
            if ($fleetA.Name -ne $fleetB.Name)
            {
                $total = 0.0
                $count = 10
                for ($i = 0; $i -lt $count; $i++)
                {
                    $copyA = Deep-Copy $fleetA
                    $copyB = Deep-Copy $fleetB
                    $stats = Fleet-Engagement $copyA $copyB
                    $total += $stats
                }
                $avg = $total / [decimal]$count
                $row = ("{0}, {1}" -f $row, $avg)
            }
            else {
                $row = ("{0}, 0.5" -f $row)
            }
            
        }
        Add-Content -Path $OutputFile -Value $row
    }
    
}

Write-Host "Starting"
Test-Presets
Write-Host "Done"