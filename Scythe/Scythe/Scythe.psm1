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
    Deploy = [int][char]'*'
    Build = [int][char]'e'
    Upgrade = [int][char]'#'
    Enlist = [int][char]'|'
    Mill
    Monument
    Mine
    Armory
    BottomRow = [int][char]'V'
}

function Save-Player($player, $fullpath)
{
    Export-Clixml -Path $fullpath -InputObject $player -Force
}

function Resolve-Cost($resources, $cost)
{
    $anyResource = 0
    $resourceAny = [Resources]::ResourceAny -as [string]
    if ($resources.ContainsKey($resourceAny) -and $resources[$resourceAny] -gt 0)
    {
        $anyResource = $resources[$resourceAny]
    }
    foreach ($resourceString in $cost.Keys)
    {
        $resourceName = [Resources]::$resourceString -as [string]
        $thisCost = $cost[$resourceName]
        if ($thisCost -gt 0)
        {
            $available = $resources[$resourceName]
            
            if ($anyResource -gt 0)
            {
                switch ($resourceName)
                {
                    ([Resources]::Food) { 
                        $available += $anyResource 
                    } 
                    ([Resources]::Metal) { 
                        $available += $anyResource 
                    }
                    ([Resources]::Oil) { 
                        $available += $anyResource 
                    }
                    ([Resources]::Wood) { 
                        $available += $anyResource 
                    }
                }
            }
            if ($available -lt $cost[$resourceName])
            {
                return $false
            }
        }
    }
    $anySubtract = 0
    foreach ($resourceString in $cost.Keys)
    {
        $resourceName = [Resources]::$resourceString -as [string]
        $thisCost = $cost[$resourceName]
        if ($thisCost -gt 0)
        {
            if ($resources[$resourceName] -ge $thisCost)
            {
                $resources[$resourceName] -= $thisCost
            }
            else {
                $takeAny += $thisCost - $resources[$resourceName]
                $resources[$resourceName] = 0
            }
        }
    }
    $resources[$resourceAny] -= $takeAny
    return $true
}

function Merge-ResourceList($list1, $list2)
{
    $resourceDict = @{}
    foreach ($resourceKey in [Resources].GetEnumNames())
    {
        $rn = [Resources]::$resourceKey -as [string]
        $resourceDict[$rn] = $list1[$rn] + $list2[$rn]
    }

    return $resourceDict
}

function Add-Resources($player, $resources)
{
    foreach ($resourceName in $resources.Keys)
    {
        $gainString = ($resourceName -as [string]) + ($resources[$resourceName] -as [string])
        $player["HistoryString"] += $gainString
    }
    $player.Resources = Merge-ResourceList $player.Resources $resources
}

function Add-ResourcesToHex($player, $hex, $resources)
{
    $player["HistoryString"] += $hex.Position
    foreach ($resourceName in $resources.Keys)
    {
        $gainString = ($resourceName -as [string]) + ($resources[$resourceName] -as [string])
        $player["HistoryString"] += $gainString
    }
    $hex.Resources = Merge-ResourceList $hex.Resources $resources
    $player.Resources = Merge-ResourceList $player.Resources $resources
}


function Resolve-Produce($player, $outPlayers)
{
    [System.Collections.ArrayList]$canProduce = @()
    [System.Collections.ArrayList]$willProduce = @()
    foreach ($hexPosition in $player.Faction.Map.Keys)
    {
        $hex = $player.Faction.Map[$hexPosition]
        if ($hex["Resources"][[Resources]::Mill -as [string]] -gt 0)
        {
            $unused = $willProduce.Add($hexPosition)
        }
        elseif ($hex["Resources"][[Resources]::Worker -as [string]] -gt 0)
        {
            $unused = $canProduce.Add($hexPosition)
        }
    }
    
    $outProduce = @{}
    
    if ($canProduce.Count -gt 2)
    {
        Write-Host "deal with multiple production hexes"
    }
    else {
        $thisWillProduce = $willProduce + $canProduce
        $outProduce[$player] = $thisWillProduce
    }
    
    foreach ($thisPlayer in $outProduce.Keys)
    {
        $thisWillProduce = $outProduce[$thisPlayer]
        foreach ($hexPosition in $thisWillProduce)
        {
            $hex = $thisPlayer.Faction.Map[$hexPosition]
            $resources = @{}
            $production = 0
            $production += $hex["Resources"][[Resources]::Worker -as [string]]
            $production += $hex["Resources"][[Resources]::Mill -as [string]]
            switch ($hex.Terrain)
            {
                "Village" {
                    $production = [math]::Min(8 - $thisPlayer.Resources[[Resources]::Worker -as [string]], $production)
                    $resources[[Resources]::Worker -as [string]] += $production
                }
                "Tundra" { $resources[[Resources]::Oil -as [string]] += $production }
                "Mountain" { $resources[[Resources]::Metal -as [string]] += $production }
                "Farm" { $resources[[Resources]::Food -as [string]] += $production }
                "Forest" { $resources[[Resources]::Wood -as [string]] += $production }
            }
            if ($hex.Terrain -eq "Village")
            {
                Add-ResourcesToHex $thisPlayer $hex $resources
            }
            else {
                Add-Resources $thisPlayer $resources
            }
        }
    }
}

function Get-PositioningHash($workerPositions)
{
    $positionString = ""
    foreach ($position in $workerPositions.Keys)
    {
        $count = $workerPositions[$position]
        $positionString = ("{0}[{1}:{2}]" -f $positionString, $position, $count)
    }
    return $positionString
}

function Resolve-Move($player, $resources, $outPlayers)
{
    #find all the individual workers that can move
    $workerPositions = [System.Collections.Specialized.OrderedDictionary]@{}
    [System.Collections.ArrayList]$workers = @()
    foreach ($hexPosition in $player.Faction.Map.Keys)
    {
        $hex = $player.Faction.Map[$hexPosition]
        $numWorkers = $hex["Resources"][[Resources]::Worker -as [string]]
        if ($numWorkers -gt 0)
        {
            $workerPositions[$hex.Position] = ($workerPositions[$hex.Position] -as [int]) + $numWorkers
            $unused = $workers.Add($hex.Position)
        }
    }
    $currentStateString = Get-PositioningHash $workerPositions
    #for each worker that can move, find out where it can move to
    [System.Collections.ArrayList]$possibleMoves = @()
    foreach($workerPosition in $workers)
    {
        $hex = $player.Faction.Map[$workerPosition]
        foreach ($linkToPosition in $hex.Links.Keys)
        {
            if ($hex.Links[$linkToPosition] -eq $false)
            {
                # not a river crossing, you can move here
                $unused = $possibleMoves.Add(@{"From"=$workerPosition; "To"=$linkToPosition})
            }
        }
    }
    $numberMoves = $resources[[Resources]::Movement -as [string]]

    #can make from zero up to $numberMoves changes
    $outputStates = @{}
    $outputStates[$currentStateString] = $player
    #Write-Host("<{0}> possible moves" -f $possibleMoves.Count)

    $outputStates.Remove($currentStateString)
    foreach ($outputStateString in $outputStates.Keys)
    {
        $outputPlayer = $outputStates[$outputStateString]
        $unused = $outPlayers.Add($outputPlayer)
        compile fail he3ere I am
    }
}

function Select-Action($player, $action, $outPlayers)
{
    $unused = $player.ActionHistory.Add($action.Name)
    $player["HistoryString"] += $action.Name
    
    switch ($action.Name)
    {
        "Gain" { Add-Resources $player $action.Gain}
        "TradeResources" { 
            Add-Resources $player $action.Gain
        }
        "TradePopularity" { Add-Resources $player $action.Gain}
        "BolsterPower" { Add-Resources $player $action.Gain}
        "BolsterCard" { Add-Resources $player $action.Gain}
        "Move" { Resolve-Move $player $action.Gain $outPlayers }
        "Produce" { Resolve-Produce $player $outPlayers}
        "Upgrade" { 
            #Resolve-Upgrade $player $outPlayers
            Add-Resources $player $action.Gain 
        }
        "Deploy" { 
            #Resolve-Deploy $player $outPlayers
            Add-Resources $player $action.Gain 
        }
        "Build" { 
            #Resolve-Build $player $outPlayers
            Add-Resources $player $action.Gain 
        }
        "Enlist" { 
            #Resolve-Enlist $player $outPlayers
            Add-Resources $player $action.Gain 
        }
    }
}

function Select-Column($player, $column, $outPlayers)
{
    $unused = $player.ColumnHistory.Add($column.Name)
    $player["HistoryString"] += $column.Name
}

function Step-Round($originalPlayer)
{
    $outputStates = @{}
    $playmat = $originalPlayer.Playmat
    $originalPlayer.Round++
    $md5 = New-Object -TypeName System.Security.Cryptography.MD5CryptoServiceProvider
    $utf8 = New-Object -TypeName System.Text.UTF8Encoding

    $lastColumn = $player.ColumnHistory[-1]
    if ($originalPlayer.Faction.Benefit -eq "Relentless")
    {
        $lastColumn = ""
    }
    foreach ($column in $playmat.Columns)
    {
        if ($column.Name -ne $lastColumn)
        {
            [System.Collections.ArrayList]$possibleChoices = @()
            $player = Deep-Copy2 $originalPlayer
            
            Select-Column $player $column

            if ($player.Resources[[Resources]::ResourceAny -as [string]] -gt 0)
            {
                $localVar = 1
                $localVar++
            }

            [System.Collections.ArrayList]$topPlayers = @($player)
            if (Resolve-Cost $player.Resources $column.Top.Cost)
            {
                Select-Action $player $column.Top $topPlayers
            }
            foreach ($topPlayer in $topPlayers)
            {
                [System.Collections.ArrayList]$bottomPlayers = @($topPlayer)
                
                if ($column.Name -eq "Gain Upgrade")
                {
                    $localVar = 1
                    $localVar++
                }
                

                if (Resolve-Cost $topPlayer.Resources $column.Bottom.Cost)
                {
                    Select-Action $topPlayer $column.Bottom $bottomPlayers
                }

                foreach ($bottomPlayer in $bottomPlayers)
                {   
                    $historyString = $bottomPlayer.HistoryString
                    
                    $hash = [System.BitConverter]::ToString($md5.ComputeHash($utf8.GetBytes($historyString)))
                    $choicename = ("{0}.{1}.{2}" -f $bottomPlayer.Name, $bottomPlayer.Round, $hash)
                    $bottomPlayer.CurrentName = $choicename
                    $outputStates[$choicename] = Deep-Copy2 $bottomPlayer
                }

            }
        }
    }

    return $outputStates
}

function Test-Player($player, $rounds, $pendingStatesPath, $returnValue)
{
    $returnValue["Output"] = ("Test Player {1} for {1} rounds" -f $player.Name, $rounds)

    $outputStates = @{}
    if ($player.Round -lt $rounds)
    {
        $outputStates = Step-Round $player
    }
    $returnValue["OutputStates"] = $outputStates
}

Export-ModuleMember -Function * -Alias * -Variable * -Cmdlet *
