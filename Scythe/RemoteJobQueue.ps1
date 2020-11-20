$ErrorActionPreference = 'Stop'

$HomeLocation = $PWD

Import-Module ./Util -DisableNameChecking 

$IMRP = $(Join-Path -Path $HomeLocation -ChildPath 'Import-ModuleRemotely.ps1')
. $IMRP

$RunningJobs = @{}
$JobQueue = New-Object System.Collections.Queue
[System.Collections.ArrayList]$RemoteHosts = @()
$global:RemoteSessions = @{} #(session:(job/false))
$global:Title = ''
$global:Running = 0
$global:Finished = 0
$global:Total = 0
$global:ThreadCount = 1

function Jobs-Left()
{
    return $RunningJobs.Count -gt 0 -or $JobQueue.Count -gt 0
}

function Add-JobToRemoteQueue($task)
{
    $JobQueue.Enqueue($task)
    $global:Total += 1
    Update-JobQueueProgress
}

function Update-JobQueueProgress
{
    $status = ("Jobs Finished/Complete [Running] {0}/{1} [{2}]" -f $global:Finished, $global:Total, $global:Running)
    $percentComplete = (($global:Finished) / $global:Total) * 100
    Write-Progress -Activity $global:Title -Status $status -Id $global:ProgressID -PercentComplete $percentComplete
}

$BatchID = 0

function Initialise-JobQueue($title, $remoteHostList, $localJobData, $modules)
{
    $global:Title = $title
    $global:ProgressID = $BatchID++
    $global:Running = 0
    $global:Finished = 0
    $global:Total = 0
    $global:RemoteHosts = $remoteHostList

    Write-Host "Initialise Remote Sessions"
    $sessions = New-PSSession -SSHConnection $global:RemoteHosts
    foreach ($session in $sessions)
    {
        Invoke-Command $session -ScriptBlock { param($data); $SessionJobData = $data; } -ArgumentList $localJobData
        $global:RemoteSessions.Add($session, $false)
        Import-ModuleRemotely "Util" $session
        foreach ($mod in $modules)
        {
            Import-ModuleRemotely $mod $session
        }
    }
    
    Write-Host "Remote Sessions Initialised"
}

function Step-JobQueue($returnValues)
{
    $jobsToRemove = @()
    foreach ($jobInfo in $RunningJobs.GetEnumerator())
    {
        $jobName = $jobInfo.Key
        $task = $jobInfo.Value
        $job = $task.Job
        
        $jobCompleted = $job.State -eq "Completed"

        if ($jobCompleted)
        {
            $jobOutput = Receive-Job $job
            $outputName = $jobOutput.OutputName
            $returnValues[$outputName] = $jobOutput
            if ($jobOutput.OutputFiles)
            {
                foreach ($localFileName in $jobOutput.OutputFiles.Keys)
                {
                    $remoteFileName = $jobOutput.OutputFiles[$localFileName]
                    $localDestination = Join-Path -Path $task.HomeLocation -ChildPath $localFileName
                    Copy-Item -Path $remoteFilename -Destination $localDestination -FromSession $task.Session -Force
                    Invoke-Command -Session $task.Session -Command { param($filename); Remove-Item $filename} -ArgumentList @($remoteFileName)
                }
            }
            Remove-Job -Job $job
            $global:RemoteSessions[$task.Session] = $false
            $jobsToRemove += $jobName
            $global:Finished++
            $global:Running--
            Update-JobQueueProgress
        }
    }
    foreach ($jobName in $jobsToRemove)
    {
        $RunningJobs.Remove($jobName)
    }
    
    if ($JobQueue.Count -gt 0)
    {
        $addedJobs = @{}
        foreach ($remoteSessionInfo in $global:RemoteSessions.GetEnumerator()) 
        {
            $session = $remoteSessionInfo.Key
            $status = $remoteSessionInfo.Value

            if ($status -eq $false)
            {
                $task = $JobQueue.DeQueue()
                $job = Invoke-Command $session -ScriptBlock $task.ScriptBlock -ArgumentList $task.ArgumentList -AsJob
                $jobName = $job.Name
                $RunningJobs[$jobName] = @{
                    'Job'=$job;
                    "Session"=$session;
                    "HomeLocation"=$task.HomeLocation;
                }
                $addedJobs[$session] = $job
                
                $global:Running += 1
                
                Update-JobQueueProgress
                if ($JobQueue.Count -eq 0)
                {
                    break
                }
            }
        }
        foreach ($sessionJobs in $addedJobs.GetEnumerator())
        {
            $global:RemoteSessions[$sessionJobs.Key] = $sessionJobs.Value
        }
    }

    Update-JobQueueProgress
    return $jobsToRemove.Count -gt 0
}

function Complete-JobQueue()
{
    Write-Host "Close Remote Sessions"
    foreach ($remoteSession in $global:RemoteSessions.GetEnumerator())
    {
        $session = $remoteSession.Key
        $status = $remoteSession.Value
        Remove-PSSession $session
        $global:RemoteSessions = @{}
    }
    Write-Host "Remote Sessions Closed"
}

function Test-Running()
{
    return $global:Running -gt 0 -or $JobQueue.Count -gt 0
}

function Running-JobQueue()
{
    Write-Host("Running-JobQueue with {0} tasks" -f $JobQueue.Count)
    $returnValues = @{}
    do
    {
        Step-JobQueue $returnValues
    } while (Test-Running)

    Update-JobQueueProgress

    Complete-JobQueue

    return $returnValues
}

function Invoke-Locally($jobInfo)
{
    $returnValue = Invoke-Command -ScriptBlock $jobInfo.ScriptBlock -ArgumentList $jobInfo.ArgumentList
    if ($returnValue.OutputFiles)
    {
        foreach ($localFileName in $returnValue.OutputFiles.Keys)
        {
            $remoteFileName = $returnValue.OutputFiles[$localFileName]
            $localDestination = Join-Path -Path $jobInfo.HomeLocation -ChildPath $localFileName
            Copy-Item -Path $remoteFilename -Destination $localDestination -Force
            Remove-Item -Path $remoteFilename
        }
    }
    return $returnValue
}

function Test-RemoteQueue()
{
    Get-Job | Remove-Job
    Get-PSSession | Remove-PSSession

    $piHost = @{"HostName"="pi@192.168.86.118"}
    $localhost = @{"HostName"="lorda@127.0.0.1"}

    $remoteList = @($piHost, $piHost, $piHost, $piHost, $localhost, $localhost, $localhost, $localhost)
    $localData = @{"Values"=@(1, 3, 5, 7, 11)}
    Initialise-JobQueue "Test" $remoteList $localData @()
    $testScriptBlock = { 
        param($funcType)
        $values = $SessionJobData.Values
        $total = 0
        if ($funcType -eq "Multiply")
        {
            $total = 1
            foreach ($value in $values)
            {
                $total *= $value
            }
        }
        elseif ($funcType -eq "Add") 
        {
            foreach ($value in $values)
            {
                $total += $value
            }
        }
        elseif ($funcType -eq "Lerp") 
        {
            foreach ($value in $values)
            {
                $total = Lerp 0.5 $total ($total + $value)
            }
        }
        
        return $total
    }

    $task = @{"ScriptBlock"=$testScriptBlock; "ArgumentList"=@("Multiply")}
    $task2 = @{"ScriptBlock"=$testScriptBlock; "ArgumentList"=@("Add")}
    $task3 = @{"ScriptBlock"=$testScriptBlock; "ArgumentList"=@("Lerp")}
    
    for ($i = 0; $i -lt 1000; $i++)
    {
        Add-JobToRemoteQueue $task
        Add-JobToRemoteQueue $task2
        Add-JobToRemoteQueue $task3
    }

    $returnValues = Running-JobQueue
    foreach ($retValue in $returnValues.GetEnumerator())
    {
        $jobName = $retValue.Key
        $ret = $retValue.Value
        #Write-Host("{0}:{1}" -f $jobName, $ret)
    }
}
