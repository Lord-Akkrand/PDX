using module .\Scythe
param
(
)

$ErrorActionPreference = 'Stop'
Clear-Host

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

$LocalResolvedStatesPath = Join-Path -Path $PSScriptRoot -ChildPath "LocalResolvedStates"
New-Item -ItemType Directory -Force -Path $LocalResolvedStatesPath
$AllLocalResolvedStatesPath = Join-Path -Path $LocalResolvedStatesPath -ChildPath "*"
$AllLocalResolvedStatesPath | Remove-Item

$RemoteResolvedStatesPath = Join-Path -Path $PSScriptRoot -ChildPath "RemoteResolvedStates"
New-Item -ItemType Directory -Force -Path $RemoteResolvedStatesPath
$AllRemoteResolvedStatesPath = Join-Path -Path $RemoteResolvedStatesPath -ChildPath "*"
$AllRemoteResolvedStatesPath | Remove-Item

$LocalOutputFile = Join-Path -Path $PSScriptRoot -ChildPath "LocalOutput.csv"
$LocalOutputFile = Join-Path -Path $PSScriptRoot -ChildPath "RemoteOutputFile.csv"

$HomeLocation = $PWD

Import-Module -Verbose ./Scythe/Scythe.psm1 -DisableNameChecking -Force
Import-Module ./Util -DisableNameChecking -Force


$RJQ = $(Join-Path -Path $HomeLocation -ChildPath 'RemoteJobQueue.ps1')
. $RJQ



$FactionsXML = Get-Data (Join-Path -Path $PSScriptRoot -ChildPath "Factions.xml")
$PlaymatsXML = Get-Data (Join-Path -Path $PSScriptRoot -ChildPath "Playmats.xml")

function Import-ResourceList($xmlResourceList)
{
    $resourceDict = @{}

    $resourcesString = $xmlResourceList -as [string]
    $resourcesChars = [char[]]$resourcesString
    
    foreach ($resourceKey in [Resources].GetEnumNames())
    {
        $rn = [Resources]::$resourceKey -as [string]
        $resourceDict[$rn] = 0
    }
    
    foreach ($resourceChar in $resourcesChars)
    {
        $resourceEnum = [Enum]::ToObject([Resources], $resourceChar -as [int])
        $rn = [Resources]::$resourceEnum -as [string]
        if ($resourceDict.ContainsKey($rn))
        {
            $resourceDict[$rn] += 1
        }
        else {
            $resourceDict[$rn] = 1
        }
    }
    return $resourceDict
}

function Import-Faction($xmlFaction)
{ 
    $thisFaction = @{}
    $thisFaction["Name"] = $xmlFaction.Name -as [string]
    $thisFaction["Resources"] = Import-ResourceList $xmlFaction.Resources
    $thisFaction["Benefit"] = $xmlFaction.Benefit -as [string]
    $thisFaction["Map"] = @{}
    foreach ($hexXML in $xmlFaction.Hexes.ChildNodes)
    {
        $hex = @{}
        $hex["Terrain"] = $hexXML.Terrain -as [string]
        $hex["XPosition"] = $hexXML.XPosition -as [int]
        $hex["YPosition"] = $hexXML.YPosition -as [int]
        $hex["Resources"] = Import-ResourceList ($hexXML.Resources -as [string])
        $thisFaction.Resources = Merge-ResourceList $thisFaction.Resources $hex["Resources"]
        $hex["Position"] = ("{0}, {1}" -f $hex["XPosition"], $hex["YPosition"])
        [System.Collections.ArrayList]$hex["Workers"] = @()
        $workerString = $hexXML.Worker -as [string]
        if ($workerString -ne "")
        {
            $unused = $hex["Workers"].Add($workerString)
        }
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
        if ($factionXML.Name -as [string] -ne "#comment")
        {
            $thisFaction = Import-Faction $factionXML
            $AllFactions[$thisFaction["Name"]] = $thisFaction
        }
    }
}

$AllPlaymats = @{}
function Import-Playmats($xmlFile)
{
    Write-Host "Create Playmats"
    
    foreach ($playmatXML in $xmlFile.Playmats.ChildNodes)
    {
        if ($playmatXML.Name -as [string] -ne "#comment")
        {
            $thisPlaymat = Import-Playmat $playmatXML
            $AllPlaymats[$thisPlaymat["Name"]] = $thisPlaymat
        }
    }
}

function Build-Player($faction, $playmat)
{
    $player = @{}
    $player["Name"] = ("{0} {1}" -f $faction.Name, $playmat.Name)
    $player["CurrentName"] = $player["Name"]
    $player["Resources"] = Merge-ResourceList $faction.Resources $playmat.Resources
    $player["Faction"] = $faction
    $player["Playmat"] = $playmat
    $player["Round"] = 0
    [System.Collections.ArrayList]$player["ActionHistory"] = @()
    [System.Collections.ArrayList]$player["ColumnHistory"] = @()
    $player["HistoryString"] = ""
    return $player
}

Import-Factions $FactionsXML
Import-Playmats $PlaymatsXML

$TestPlayerScriptBlock = { 
    param($player, $rounds, $pendingStatesDirectoryName)
    $returnValue = @{"OutputName"=$player.CurrentName;}
    Test-Player $player $rounds $pendingStatesDirectoryName $returnValue
    return $returnValue
}

$LocalTotal = 0
$LocalFinished = 0
$LocalProgressID = 0
function Update-LocalProgress($state, $title, $id)
{
    $status = ("{0} {1}/{2}" -f $state, $LocalFinished, $LocalTotal)
    $percentComplete = (($LocalFinished) / $LocalTotal) * 100
    Write-Progress -Activity $title -Status $status -Id $id -PercentComplete $percentComplete
}

function Build-CSV($filePath, $outputPath)
{
    [System.Collections.ArrayList]$csvOutputs = @()
    $headerString = "Faction, Playmat, "
    foreach ($resourceKey in [Resources].GetEnumNames())
    {
        $rn = $resourceKey -as [string]
        $unused = $csvOutputs.Add($resourceKey)
        $headerString = $headerString + $rn + ", "
    }
    Set-Content -Path $outputPath -Value $headerString
    
    $matchingFiles = Get-ChildItem $filePath
    $LocalTotal = $matchingFiles.Count
    $LocalFinished = 0
    $LocalProgressID++
    Update-LocalProgress "Output Finished/Complete" "Writing File" $LocalProgressID
    
    $matchingFiles | Foreach-Object {
        $finalPlayerState = Import-Clixml -Path $_.FullName
        if ($finalPlayerState.Round -eq $rounds)
        {
            $outputString = ("{0}, {1}" -f $finalPlayerState.Faction.Name, $finalPlayerState.Playmat.Name)
            foreach ($resourceKey in $csvOutputs)
            {
                $value = 0
                if ($finalPlayerState.Resources.Contains([Resources]::$resourceKey -as [string]))
                {
                    $value = $finalPlayerState.Resources[[Resources]::$resourceKey -as [string]]
                }
                $outputString = ("{0}, {1}" -f $outputString, $value -as [string])
            }
            Add-Content -Path $outputPath -Value $outputString
        }
        $LocalFinished++
        Update-LocalProgress "Output Finished/Complete" "Writing File" $LocalProgressID
    }
}
function Test-All()
{
    $InitialPlayers = @{}
    foreach ($factionName in $AllFactions.Keys)
    {
        $faction = Deep-Copy2 $AllFactions[$factionName]
        foreach ($playmatName in $AllPlaymats.Keys)
        {
            $playmat = Deep-Copy2 $AllPlaymats[$playmatName]
            $player = Build-Player $faction $playmat
            $InitialPlayers[$player.Name] = $player
        }
    }

    $rounds = 1

    $testLocal = $true
    if ($testLocal)
    {
        # Test Locally
        Write-Host("Test Locally")
        $startLocal = Get-Date
        $PendingPlayers = @{}
        foreach ($playerName in $InitialPlayers.Keys)
        {
            $player = $InitialPlayers[$playerName]
            $PendingPlayers[$playerName] = Deep-Copy2 $InitialPlayers[$playerName]
        }
        $returnCount = 0
        $jobsCount = 0
        $LocalTotal = $PendingPlayers.Count
        $trueLocal = $true
        do
        {
            #Write-Host("{0} pending players" -f $PendingPlayers.Count)
            $localReturnValues = @{}
            [System.Collections.ArrayList]$removePending = @()
            foreach ($playerName in $PendingPlayers.Keys)
            {
                $player = $PendingPlayers[$playerName]
                
                $unused = $removePending.Add($playerName)

                $task = @{"ScriptBlock"=$TestPlayerScriptBlock; "ArgumentList"=@(Deep-Copy2 $player, $rounds, $PendingStatesDirectoryName); "HomeLocation"=$HomeLocation;}

                if ($trueLocal)
                {
                    $returnValue = @{"OutputName"=$player.CurrentName;}
                    Test-Player $player $rounds $PendingStatesDirectoryName $returnValue
                }
                else {
                    $returnValue = Invoke-Locally $task   
                }

                $localReturnValues[$player.CurrentName] = $returnValue    
                $jobsCount++
                $LocalFinished++
                Update-LocalProgress "Jobs Finished/Complete" "Local Execution" $LocalProgressID
            }
            foreach ($playerName in $removePending)
            {
                $PendingPlayers.Remove($playerName)
            }
            
            foreach ($outPlayerName in $localReturnValues.Keys)
            {
                $outPlayerStates = $localReturnValues[$outPlayerName]["OutputStates"]
                foreach ($outPlayerStateName in $outPlayerStates.Keys)
                {
                    $outPlayerState = $outPlayerStates[$outPlayerStateName]
                    $PendingPlayers[$outPlayerStateName] = $outPlayerState
                    $fullpath = Join-Path -Path $LocalResolvedStatesPath -ChildPath ("{0}.xml" -f $outPlayerStateName)
                    Save-Player $outPlayerState $fullpath
                    $returnCount++
                    $LocalTotal++
                }
                Update-LocalProgress "Jobs Finished/Complete" "Local Execution" $LocalProgressID
            }
            Update-LocalProgress "Jobs Finished/Complete" "Local Execution" $LocalProgressID
            #Write-Host("Return count is {0}, jobs count is {1}" -f $returnCount, $jobsCount)
        } while ($PendingPlayers.Count -gt 0)
        $endLocal = Get-Date
        $localTime = New-TimeSpan -Start $startLocal -End $endLocal
        $localTimeString = Get-FormattedTime $localTime
        Write-Host("Local Computation took {0}" -f $localTimeString)
        Build-CSV $LocalResolvedStatesPath $LocalOutputFile
    }

    
    $testRemote = $false
    if ($testRemote)
    {
        $piHost = @{"HostName"="pi@192.168.86.118"}
        $localhost = @{"HostName"="lorda@127.0.0.1"}

        $remoteList = @($localhost, $localhost, $localhost, $localhost, $localhost, $localhost, $localhost, $localhost)
        $localData = @{}
        $modules = @("Scythe")
        Initialise-JobQueue "Test" $remoteList $localData $modules

        # Test Remotely
        Write-Host("Clean Up Local Files")
        $AllResolvedStatesPath | Remove-Item

        Write-Host("Test Remotely")
        $startRemote = Get-Date
        $PendingPlayers = @{}
        foreach ($playerName in $InitialPlayers.Keys)
        {
            $player = $InitialPlayers[$playerName]
            $PendingPlayers[$playerName] = Deep-Copy2 $InitialPlayers[$playerName]
        }
        $returnCount = 0
        $jobsCount = 0
        do
        {
            #Write-Host("{0} pending players" -f $PendingPlayers.Count)
            foreach ($playerName in $PendingPlayers.Keys)
            {
                $player = $PendingPlayers[$playerName]

                $task = @{"ScriptBlock"=$TestPlayerScriptBlock; "ArgumentList"=@($player, $rounds, $PendingStatesDirectoryName); "HomeLocation"=$HomeLocation}
                Add-JobToRemoteQueue $task
                $jobsCount++
            }
            $PendingPlayers = @{}
            $remoteReturnValues = @{}
            do
            {
                if (Step-JobQueue $remoteReturnValues)
                {
                    break
                }
            } while (Jobs-Left)
            foreach ($outPlayerName in $remoteReturnValues.Keys)
            {
                $outPlayerStates = $remoteReturnValues[$outPlayerName]["OutputStates"]
                foreach ($outPlayerStateName in $outPlayerStates.Keys)
                {
                    $outPlayerState = $outPlayerStates[$outPlayerStateName]
                    $PendingPlayers[$outPlayerStateName] = $outPlayerState
                    $fullpath = Join-Path -Path $RemoteResolvedStatesPath -ChildPath ("{0}.xml" -f $outPlayerStateName)
                    Save-Player $outPlayerState $fullpath
                    $returnCount++
                }
            }
            #Write-Host("Return count is {0}, jobs count is {1}" -f $returnCount, $jobsCount)
            $workLeft = $PendingPlayers.Count -gt 0
            $workInProgress = Jobs-Left
        } while ($workLeft -or $workInProgress)
        $endRemote = Get-Date
        $remoteTime = New-TimeSpan -Start $startRemote -End $endRemote
        $remoteTimeString = Get-FormattedTime $remoteTime
        Write-Host("Remote Computation took {0}" -f $remoteTimeString)
        Complete-JobQueue
        Build-CSV $RemoteResolvedStatesPath $RemoteOutputFile
    }
}

Test-All