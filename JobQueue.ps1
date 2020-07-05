$ErrorActionPreference = 'Stop'

function Deep-Copy($obj)
{
    $ms = New-Object System.IO.MemoryStream
    $bf = New-Object System.Runtime.Serialization.Formatters.Binary.BinaryFormatter
    $bf.Serialize($ms, $obj)
    $ms.Position = 0
    $ret = $bf.Deserialize($ms)
    $ms.Close()
    return $ret
}

$RunningJobs = @{}
$JobQueue = New-Object System.Collections.Queue 
$global:Title = ''
$global:Running = 0
$global:Finished = 0
$global:Total = 0
$global:ThreadCount = 1

function Jobs-Left()
{
    return $RunningJobs.Count -gt 0 -or $JobQueue.Count -gt 0
}

function Add-JobToQueue($task)
{
    $JobQueue.Enqueue($task)
    $global:Total += $task.BatchSize
    Update-JobQueueProgress
}

function Update-JobQueueProgress
{
    $status = ("Batches Started/Complete [Total] {0}/{1} [{2}]" -f $global:Running, $global:Finished, $global:Total)
    $percentComplete = (($global:Finished) / $global:Total) * 100
    Write-Progress -Activity $global:Title -Status $status -Id $global:ProgressID -PercentComplete $percentComplete
}

function Get-CPUCount
{
    $LogicalCPU = 0
    $PhysicalCPU = 0
    $Core = 0
 
    # Get the Processor information from the WMI object
    $Proc = [object[]]$(Get-CimInstance -Class Win32_Processor)
 
    #Perform the calculations
    $Core = $Proc.count
    $LogicalCPU = $($Proc | Measure-Object -Property NumberOfLogicalProcessors -sum).Sum
    $PhysicalCPU = $($Proc | Measure-Object -Property NumberOfCores -sum).Sum

    return [math]::max($LogicalCPU, $PhysicalCPU)
}

function Initialise-JobQueue($title)
{
    $global:Title = $title
    $global:ProgressID = $BatchID++
    $global:Running = 0
    $global:Finished = 0
    $global:Total = 0
    $cpuCount = Get-CPUCount
    $global:ThreadCount = [Math]::Max(1, $cpuCount-1)
}

function Running-JobQueue()
{
    $returnValues = @{}
    $jobsToRemove = @()
    foreach ($jobInfo in $RunningJobs.GetEnumerator())
    {
        $jobName = $jobInfo.key
        $task = $jobInfo.value
        $job = $task.Job
        
        $jobCompleted = $job.State -eq "Completed"

        $arrayOutput = Receive-Job $job
        
        if ($jobCompleted)
        {
            Remove-Job -Job $job
            $jobsToRemove += $jobName
            Update-JobQueueProgress
        }

        foreach ($jobReturn in $arrayOutput)
        {
            $global:Finished++
            $global:Running--
            $jobName = $jobReturn.Name
            $returnValues[$jobName] = $jobReturn

            Update-JobQueueProgress
        }
    }
    foreach ($jobName in $jobsToRemove)
    {
        $RunningJobs.Remove($jobName)
    }
    
    if ($RunningJobs.Count -lt $global:ThreadCount -and $JobQueue.Count -gt 0)
    {
        #Write-Host "Starting job"
        $task = $JobQueue.DeQueue()
        $job = Start-Job -ScriptBlock $task.ScriptBlock -ArgumentList $task.Arguments
        $jobName = $job.Name
        $RunningJobs[$jobName] = @{
            Job = $job
        }
        $global:Running += $task.BatchSize
        
        Update-JobQueueProgress
    }
    return $returnValues
}

$BatchID = 0

$SmashFleetScriptBlock = {
    param($homeLocation, $batch, $count)

    Import-Module $(Join-Path -Path $homeLocation -ChildPath 'SmashFleets.ps1') -WarningAction SilentlyContinue

    #$batchReturn = @{}
    foreach ($abbreviation in $batch.Keys) 
    {
        $values = $batch[$abbreviation]
        $originalFleetA = $values[0]
        $originalFleetB = $values[1]

        $percentages = @(0, 0)
        $countAsDouble = $count -as [double]
        $p0 = $percentages[0] / $countAsDouble
        $p1 = $percentages[1] / $countAsDouble

        $outputFilename = Join-Path -Path $homeLocation -ChildPath ("Tests") |  Join-Path -ChildPath ("{0}.xml" -f $abbreviation)
        $fALost = ("{0} Lost" -f $originalFleetA["Name"])
        $fBLost = ("{0} Lost" -f $originalFleetB["Name"])
        $fALostPC = ("{0} Lost PC" -f $originalFleetA["Name"])
        $fBLostPC = ("{0} Lost PC" -f $originalFleetB["Name"])
        $outputInfo = ("{0}, {1}, {2}, {3}, Round" -f $fALost, $fALostPC, $fBLost, $fBLostPC)
        Set-Content -Path $outputFilename -Value $outputInfo

        for ($i = 0; $i -lt $count; $i++)
        {
            $fleetA = Deep-Copy $originalFleetA
            $fleetB = Deep-Copy $originalFleetB

            $retVal = Smash-Fleets $fleetA $fleetB
            $percentages[0] += $retVal[0]
            $percentages[1] += $retVal[1]

            $iAsDouble = ($i + 1) -as [double]
            $p0 = [math]::round($percentages[0] / $iAsDouble, 2)
            $p1 = [math]::round($percentages[1] / $iAsDouble, 2)
        }
        $returnValue = @{}
        $returnValue.Name = $abbreviation
        $returnvalue.FleetALosses = $p0
        #$returnvalue.FleetAName = $originalFleetA["Name"]
        $returnvalue.FleetBLosses = $p1
        #$returnvalue.FleetBName = $originalFleetB["Name"]
        Export-Clixml -Path $outputFilename -InputObject $returnValue -Force
        Write-Output $returnValue
    }
    #return $batchReturn
}

function Test-Presets()
{
    $progressId = 0
    foreach($presetFleet in $PresetFleets)
    {
        foreach($private:pirateFleet in $PirateFleets)
        {
            $progressId++

            $task = @{
                ScriptBlock = $SmashFleetScriptBlock
                Arguments = @($HomeLocation, $presetFleet, $private:pirateFleet, 10)
            }
            Add-JobToQueue $task
        }
    }
    $returnValues = Submit-JobQueue "Batch" 8
    $keys = $returnValues.Keys | Sort-Object
    foreach ($key in $keys)
    {
        $val = $returnValues[$key]
        Write-Host("{0}: {1} -> {2}" -f $key, $val["FleetA"], $val["FleetB"])
    }
}

Write-Host "Starting"
#Test-Presets
TestAll
Write-Host "Done"