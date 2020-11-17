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

function Add-JobToQueue($task)
{
    $JobQueue.Enqueue($task)
    $global:Total += 1
    Update-JobQueueProgress
}

function Update-JobQueueProgress
{
    $status = ("Batches Started/Complete [Total] {0}/{1} [{2}]" -f $global:Running, $global:Finished, $global:Total)
    $percentComplete = (($global:Finished) / $global:Total) * 100
    Write-Progress -Activity $global:Title -Status $status -Id $global:ProgressID -PercentComplete $percentComplete
}

$BatchID = 0

function Initialise-JobQueue($title, $remoteHostList, $localJobData)
{
    $global:Title = $title
    $global:ProgressID = $BatchID++
    $global:Running = 0
    $global:Finished = 0
    $global:Total = 0
    $global:RemoteHosts = $remoteHostList

    Write-Host "Initialise Remote Sessions"
    foreach ($remoteHost in $global:RemoteHosts)
    {
        $userName = $remoteHost.UserName
        $hostName = $remoteHost.HostName
        $session = New-PSSession -HostName $hostName -UserName $userName
        Invoke-Command $session -ScriptBlock { param($data); $SessionJobData = $data; } -ArgumentList $localJobData
        $global:RemoteSessions.Add($session, $false)
        Write-Host "added session"
    }
    Write-Host "Remote Sessions Initialised"
}

function Running-JobQueue()
{
    $returnValues = @{}
    do
    {
        $jobsToRemove = @()
        foreach ($jobInfo in $RunningJobs.GetEnumerator())
        {
            $jobName = $jobInfo.Key
            $task = $jobInfo.Value
            $job = $task.Job
            
            $jobCompleted = $job.State -eq "Completed"

            $arrayOutput = Receive-Job $job
            
            if ($jobCompleted)
            {
                Remove-Job -Job $job
                $global:RemoteSessions[$task.Session] = $false
                $jobsToRemove += $jobName
                Update-JobQueueProgress
            }

            foreach ($jobReturn in $arrayOutput)
            {
                $global:Finished++
                $global:Running--
                $returnValues[$jobName] = $jobReturn

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
                    $job = Invoke-Command $session -ScriptBlock $task.ScriptBlock -ArgumentList $task.Arguments -AsJob
                    $jobName = $job.Name
                    $RunningJobs[$jobName] = @{
                        'Job'=$job;
                        "Session"=$session
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
    } while ($global:Running -gt 0 -or $JobQueue.Count -gt 0)

    Write-Host "Close Remote Sessions"
    foreach ($remoteSession in $global:RemoteSessions.GetEnumerator())
    {
        $session = $remoteSession.Key
        $status = $remoteSession.Value
        Remove-PSSession $session
        $global:RemoteSessions = @{}
    }
    Write-Host "Remote Sessions Closed"

    return $returnValues
}

function Test-RemoteQueue()
{
    $piHost = @{"UserName"="pi"; "HostName"="192.168.86.118"}
    $localhost = @{"UserName"="lorda"; "HostName"="127.0.0.1"}
    $remoteList = @($piHost, $piHost, $piHost, $piHost)
    $localData = @{"Values"=@(1, 3, 5, 7, 11)}
    Initialise-JobQueue "Test" $remoteList $localData
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
        
        return $total
    }

    $task = @{"ScriptBlock"=$testScriptBlock; "Arguments"=@("Multiply")}
    $task2 = @{"ScriptBlock"=$testScriptBlock; "Arguments"=@("Add")}
    
    for ($i = 0; $i -lt 100; $i++)
    {
        Add-JobToQueue $task
        Add-JobToQueue $task2    
    }

    $returnValues = Running-JobQueue
    foreach ($retValue in $returnValues.GetEnumerator())
    {
        $jobName = $retValue.Key
        $ret = $retValue.Value
        Write-Host("{0}:{1}" -f $jobName, $ret)
    }
}

Write-Host "Starting"
Test-RemoteQueue
Write-Host "Done"