param
(
    [String]$ShipsPath="Ships",
    [String]$OutputFile="ShipCompare.csv"
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
    $ShipsPath = Get-Path $ShipsPath
    $PresetShips = @()

    Get-ChildItem $ShipsPath -Filter *.xml | 
    Foreach-Object {
        Write-Host("Found <{0}>" -f $_.FullName)
        $fleet = Import-Clixml -Path $_.FullName
        $PresetShips += $fleet
    }

    $progressId = 0
    $outputHeader = ""
    
    foreach($shipA in $PresetShips)
    {
        $outputHeader = ("{0}, {1}" -f $outputHeader, $shipA.Name)
    }
    Set-Content -Path $OutputFile -Value $outputHeader

    foreach($shipA in $PresetShips)
    {
        $row = $shipA.Name
        foreach($shipB in $PresetShips)
        {
            $progressId++
            if ($shipA.Name -ne $shipB.Name)
            {
                $copyA = Deep-Copy $shipA
                $copyB = Deep-Copy $shipB
                $stats = Fight $copyA $copyB
                $row = ("{0}, {1}" -f $row, $stats)
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