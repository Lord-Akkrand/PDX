using module .\Scythe
param
(
)
$ErrorActionPreference = 'Stop'

Get-Job | Remove-Job
Get-PSSession | Remove-PSSession

$HomeLocation = $PWD

Import-Module ./Util -DisableNameChecking -Force
Import-Module ./Scythe -DisableNameChecking -Force

$RJQ = $(Join-Path -Path $HomeLocation -ChildPath 'RemoteJobQueue.ps1')
. $RJQ

Clear-Host

$FactionsXML = Get-Data (Join-Path -Path $PSScriptRoot -ChildPath "Factions.xml")
$PlaymatsXML = Get-Data (Join-Path -Path $PSScriptRoot -ChildPath "Playmats.xml")

function Import-Faction($xmlFaction)
{ 
    $thisFaction = @{}
    $thisFaction["Name"] = $xmlFaction.Name -as [string]
    $thisFaction["Map"] = @{}
    foreach ($hexXML in $xmlFaction.Hexes.ChildNodes)
    {
        $hex = @{}
        $hex["Terrain"] = $hexXML.Terrain -as [string]
        $hex["XPosition"] = $hexXML.XPosition -as [int]
        $hex["YPosition"] = $hexXML.YPosition -as [int]
        $hex["Workers"] = $hexXML.Workers -as [int]
        $hex["Position"] = ("{0}, {1}" -f $hex["XPosition"], $hex["YPosition"])
        $thisFaction.Map.Add($hex["Position"], $hex)    
    }
    return $thisFaction
}

function Import-ResourceList($xmlResourceList)
{
    [System.Collections.ArrayList]$resourceList = @()

    $resourcesString = $xmlResourceList -as [string]
    $resourcesChars = [char[]]$resourcesString
    
    foreach ($resourceChar in $resourcesChars)
    {
        $resourceEnum = [Enum]::ToObject([Resources], $resourceChar -as [int])
        $unused = $resourceList.Add($resourceEnum)
    }
    return $resourceList
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

Import-Factions $FactionsXML
Import-Playmats $PlaymatsXML


function Test-All()
{
    $piHost = @{"HostName"="pi@192.168.86.118"}
    $localhost = @{"HostName"="lorda@127.0.0.1"}

    $remoteList = @($localhost)
    $localData = @{}
    $modules = @("Scythe")
    Initialise-JobQueue "Test" $remoteList $localData $modules

    $rounds = 3
    foreach ($factionName in $AllFactions.Keys)
    {
        $faction = $AllFactions[$factionName]
        foreach ($playmatName in $AllPlaymats.Keys)
        {
            $playmat = $AllPlaymats[$playmatName]
            $testScriptBlock = { 
                param($faction, $playmat, $rounds)
                $returnValue = @{}
                $returnValue["TestReturn"] = Test-Combination $faction $playmat $rounds
                return $returnValue
            }
            $task = @{"ScriptBlock"=$testScriptBlock; "Arguments"=@($faction, $playmat, $rounds);}
            Add-JobToRemoteQueue $task
        }
    }
    $returnValues = Running-JobQueue
    foreach ($retValue in $returnValues.GetEnumerator())
    {
        $jobName = $retValue.Key
        $ret = $retValue.Value
        Write-Host("{0}:{1}" -f $jobName, $ret)
    }
}

Test-All