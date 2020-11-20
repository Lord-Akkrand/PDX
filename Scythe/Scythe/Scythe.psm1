$ErrorActionPreference = 'Stop'

enum Resources {
    Gold = [int][char]'$'
    Popularity = [int][char]'@'
    Power = [int][char]'^'
    Cards = [int][char]'='
    Worker = [int][char]'!'
    Produce = [int][char]'%'
    Food = [int][char]'F'
    Metal = [int][char]'M'
    Oil = [int][char]'O'
    Wood = [int][char]'W'
    ResourceAny = [int][char]'?'
    Movement = [int][char]'>'
    Mech = [int][char]'*'
    Building = [int][char]'e'
    Upgrade = [int][char]'#'
    Recruit = [int][char]'|'
}

function Save-Player($player, $fullpath)
{
    Export-Clixml -Path $fullpath -InputObject $player -Force
}

function Resolve-Cost($resources, $cost)
{
    foreach ($resourceName in $cost.Keys)
    {
        if ($resources[$resourceName] -lt $cost[$resourceName])
        {
            return $false
        }
    }
    foreach ($resourceName in $cost.Keys)
    {
        $resources[$resourceName] -= $cost[$resourceName]
    }
    return $true
}

function Resolve-Resources($map, $cost)
{
    $costCopy = Deep-Copy2 $cost
    $mapCopy = Deep-Copy2 $map
    foreach ($resourceName in $cost.Keys)
    {
        foreach ($hexName in $mapCopy.Keys)
        {
            $hex = $mapCopy[$hexName]
            if ($hex.Resources[$resourceName] -gt 0)
            {
                $amountToPay = [math]::min($costCopy[$resourceName], $hex.Resources[$resourceName])
                $costCopy[$resourceName] -= $amountToPay
                $hex.Resources[$resourceName] -= $amountToPay
            }
        }
    }

    foreach ($resourceName in $cost.Keys)
    {
        if ($costCopy[$resourceName] -gt 0)
        {
            return $false
        }
    }
    $map = $mapCopy
    return $true
}


function Select-Action($player, $action)
{
    $unused = $player.ActionHistory.Add($action.Name)
}
function Step-Round($originalPlayer, $pendingStatesPath)
{
    $outputFiles = @{}
    $playmat = $originalPlayer.Playmat
    $originalPlayer.Round++
    foreach ($column in $playmat.Columns)
    {
        $player = Deep-Copy2 $originalPlayer
        $TempFile = New-TemporaryFile
        if (Resolve-Cost $player.Resources $column.Top.Cost)
        {
            Select-Action $player $column.Top
        }
        if (Resolve-Resources $player.Faction.Map $column.Bottom.Cost)
        {
            Select-Action $player $column.Bottom
        }
        $tempName = Split-Path $TempFile.FullName -leaf
        $choicename = ("{0}.{1}.{2}.xml" -f $player.Name, $player.Round, $tempName)
        Export-Clixml -Path $TempFile.FullName -InputObject $player
        $outputFile = Join-Path -Path $pendingStatesPath -ChildPath $choiceName
        $outputFiles[$outputFile] = $TempFile.FullName
    }

    return $outputFiles
}

function Test-Player($player, $rounds, $pendingStatesPath, $returnValue)
{
    $returnValue["Output"] = ("Test Player {1} for {1} rounds" -f $player.Name, $rounds)
    
    $outputFiles = @{}
    if ($player.Round -lt $rounds)
    {
        $outputFiles = Step-Round $player $pendingStatesPath
    }
    $returnValue["OutputFiles"] = $outputFiles
}

Export-ModuleMember -Function * -Alias * -Variable * -Cmdlet *
