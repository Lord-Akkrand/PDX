using module .\Scythe
param
(
)
$ErrorActionPreference = 'Stop'

Get-Job | Remove-Job
Get-PSSession | Remove-PSSession
$PendingStatesDirectoryName = "PendingStates"
$PendingStatesPath = Join-Path -Path $PSScriptRoot -ChildPath $PendingStatesDirectoryName
New-Item -ItemType Directory -Force -Path $PendingStatesPath
$AllPendingStatesPath = Join-Path -Path $PendingStatesPath -ChildPath "*"
$AllPendingStatesPath | Remove-Item

$ResolvedStatesPath = Join-Path -Path $PSScriptRoot -ChildPath "ResolvedStates"
New-Item -ItemType Directory -Force -Path $ResolvedStatesPath
$AllResolvedStatesPath = Join-Path -Path $ResolvedStatesPath -ChildPath "*"
$AllResolvedStatesPath | Remove-Item


$HomeLocation = $PWD

Import-Module ./Util -DisableNameChecking -Force
Import-Module ./Scythe -DisableNameChecking -Force

$RJQ = $(Join-Path -Path $HomeLocation -ChildPath 'RemoteJobQueue.ps1')
. $RJQ

Clear-Host

$FactionsXML = Get-Data (Join-Path -Path $PSScriptRoot -ChildPath "Factions.xml")
$PlaymatsXML = Get-Data (Join-Path -Path $PSScriptRoot -ChildPath "Playmats.xml")

function Import-ResourceList($xmlResourceList)
{
    $resourceDict = @{}

    $resourcesString = $xmlResourceList -as [string]
    $resourcesChars = [char[]]$resourcesString
    
    foreach ($resourceChar in $resourcesChars)
    {
        $resourceEnum = [Enum]::ToObject([Resources], $resourceChar -as [int])
        if ($resourceDict.ContainsKey($resourceEnum))
        {
            $resourceDict[$resourceEnum] += 1
        }
        else {
            $resourceDict[$resourceEnum] = 1
        }
    }
    return $resourceDict
}

function Merge-ResourceList($list1, $list2)
{
    $resourceDict = @{}

    foreach ($resourceKey in $list1.Keys)
    {
        $resourceDict[$resourceKey] += $list1[$resourceKey]
    }
    foreach ($resourceKey in $list2.Keys)
    {
        $resourceDict[$resourceKey] += $list2[$resourceKey]
    }
    return $resourceDict
}

function Import-Faction($xmlFaction)
{ 
    $thisFaction = @{}
    $thisFaction["Name"] = $xmlFaction.Name -as [string]
    $thisFaction["Resources"] = Import-ResourceList $xmlFaction.Resources
    $thisFaction["Map"] = @{}
    foreach ($hexXML in $xmlFaction.Hexes.ChildNodes)
    {
        $hex = @{}
        $hex["Terrain"] = $hexXML.Terrain -as [string]
        $hex["XPosition"] = $hexXML.XPosition -as [int]
        $hex["YPosition"] = $hexXML.YPosition -as [int]
        $hex["Resources"] = Import-ResourceList ($hexXML.Resources -as [string])
        $hex["Position"] = ("{0}, {1}" -f $hex["XPosition"], $hex["YPosition"])
        $thisFaction.Map[$hex["Position"]] = $hex
    }
    return $thisFaction
}

function Import-Action($xmlAction)
{
    $action = @{}
    $action["Name"] = $xmlAction.Name -as [string]
    
    $action["Cost"] = Import-ResourceList $xmlAction.Cost
    $action["Gain"] = Import-ResourceList $xmlAction.Gain
    $action["ReduceCost"] = Import-ResourceList $xmlAction.ReduceCost
    $action["UnlockGain"] = Import-ResourceList $xmlAction.UnlockGain
    
    return $action
}

function Import-Playmat($xmlPlaymat)
{ 
    $thisPlaymat = @{}
    $thisPlaymat["Name"] = $xmlPlaymat.Name -as [string]
    $thisPlaymat["Resources"] = Import-ResourceList $xmlPlaymat.Resources
    [System.Collections.ArrayList]$thisPlaymat["Columns"] = @()
    foreach ($columnXml in $xmlPlaymat.ChildNodes)
    {
        foreach ($topActionXML in $columnXml.Top.ChildNodes)
        {
            $column = @{}
            $column["Top"] = Import-Action $topActionXML
            $column["Bottom"] = Import-Action $columnXml.Bottom
            $column["Name"] = ("{0} {1}" -f $column["Top"].Name, $column["Bottom"].Name)
            $unused = $thisPlaymat.Columns.Add($column)    
        }
    }
    return $thisPlaymat
}

$AllFactions = @{}
function Import-Factions($xmlFile)
{
    Write-Host "Create Factions"
    
    foreach ($factionXML in $xmlFile.Factions.ChildNodes)
    {
        $thisFaction = Import-Faction $factionXML
        $AllFactions[$thisFaction["Name"]] = $thisFaction
    }
}

$AllPlaymats = @{}
function Import-Playmats($xmlFile)
{
    Write-Host "Create Playmats"
    
    foreach ($playmatXML in $xmlFile.Playmats.ChildNodes)
    {
        $thisPlaymat = Import-Playmat $playmatXML
        $AllPlaymats[$thisPlaymat["Name"]] = $thisPlaymat
    }
}

function Build-Player($faction, $playmat)
{
    $player = @{}
    $player["Name"] = ("{0} {1}" -f $faction.Name, $playmat.Name)
    $player["Resources"] = Merge-ResourceList $faction.Resources $playmat.Resources
    $player["Faction"] = $faction
    $player["Playmat"] = $playmat
    $player["Round"] = 0
    [System.Collections.ArrayList]$player["ActionHistory"] = @()
    return $player
}

Import-Factions $FactionsXML
Import-Playmats $PlaymatsXML

$TestPlayerScriptBlock = { 
    param($player, $rounds, $pendingStatesDirectoryName)
    $returnValue = @{"OutputName"=$player.Name;}
    Test-Player $player $rounds $pendingStatesDirectoryName $returnValue
    return $returnValue
}
function Test-All()
{
    $piHost = @{"HostName"="pi@192.168.86.118"}
    $localhost = @{"HostName"="lorda@127.0.0.1"}

    $remoteList = @($localhost, $localhost, $localhost, $localhost, $piHost)
    $localData = @{}
    $modules = @("Scythe")
    Initialise-JobQueue "Test" $remoteList $localData $modules

    $AllPlayers = @{}
    foreach ($factionName in $AllFactions.Keys)
    {
        $faction = $AllFactions[$factionName]
        foreach ($playmatName in $AllPlaymats.Keys)
        {
            $playmat = $AllPlaymats[$playmatName]
            $player = Build-Player $faction $playmat
            $fullpath = Join-Path -Path $PendingStatesPath -ChildPath ("{0}.{1}.xml" -f $player.Name, $player.Round)
            Save-Player $player $fullpath
            $AllPlayers[$player.Name] = $player
        }
    }

    $rounds = 3

    # Test Locally
    Write-Host("Test Locally")
    do
    {
        $playerStates = Get-Item $AllPendingStatesPath | Select-Object -exp FullName
        Write-Host("{0} pending states" -f $playerStates.Count)
        $localReturnValues = @{}
        foreach ($playerState in $playerStates)
        {
            $player = Import-Clixml -Path $playerState
            Move-Item -Path $playerState -Destination $ResolvedStatesPath
            $task = @{"ScriptBlock"=$TestPlayerScriptBlock; "ArgumentList"=@(Deep-Copy2 $player, $rounds, $PendingStatesDirectoryName); "HomeLocation"=$HomeLocation;}
            $returnValue = Invoke-Locally $task
            $localReturnValues[$returnValue.OutputName] = $returnValue    
        }
    } while ($playerStates.Count -gt 0)

    # Test Remotely
    Write-Host("Clean Up Local Files")
    foreach ($playerName in $AllPlayers.Keys)
    {
        $player = $AllPlayers[$playerName]
        $fullpath = Join-Path -Path $PendingStatesPath -ChildPath ("{0}.{1}.xml" -f $player.Name, $player.Round)
        Save-Player $player $fullpath
    }
    $AllResolvedStatesPath | Remove-Item

    Write-Host("Test Remotely")
    do
    {
        $playerStates = Get-Item $AllPendingStatesPath | Select-Object -exp FullName
        foreach ($playerState in $playerStates)
        {
            $player = Import-Clixml -Path $playerState
            Move-Item -Path $playerState -Destination $ResolvedStatesPath
            $task = @{"ScriptBlock"=$TestPlayerScriptBlock; "ArgumentList"=@($player, $rounds, $PendingStatesDirectoryName); "HomeLocation"=$HomeLocation}
            Add-JobToRemoteQueue $task
        }
        $remoteReturnValues = @{}
        do
        {
            if (Step-JobQueue $remoteReturnValues)
            {
                break
            }
        } while (Jobs-Left)
    } while ($playerStates.Count -gt 0)
    Complete-JobQueue
}

Test-All