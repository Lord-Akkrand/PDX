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

function Get-FormattedTime($timeInfo)
{
    $timeString = ""
    $needMilliseconds = $True
    if ([int]$timeInfo.Hours -gt 0)
    {
        $timeString = (' Hours="{0}"' -f $timeInfo.Hours)
        $needMilliseconds = $False
    }
    if ([int]$timeInfo.Minutes -gt 0)
    {
        $timeString += (' Minutes="{0}"' -f $timeInfo.Minutes)
        $needMilliseconds = $False
    }
    if ([int]$timeInfo.Seconds -gt 0)
    {
        $timeString += (' Seconds="{0}"' -f $timeInfo.Seconds)
    }
    if ($needMilliseconds)
    {
        $timeString += (' Milliseconds="{0}"' -f $timeInfo.Milliseconds)
    }
    return $timeString
}


function Deep-Copy2($obj)
{
    $_TempCliXMLString  =   [System.Management.Automation.PSSerializer]::Serialize($obj, [int32]::MaxValue)
    $ret          =   [System.Management.Automation.PSSerializer]::Deserialize($_TempCliXMLString)
    return $ret
}


function Lerp($x, $min, $max)
{
    return (($max - $min) * $x) + $min
}

function Clamp($val, $min, $max)
{
    $val = [Math]::Max($val, $min)
    $val = [Math]::Min($val, $max)
    return $val
}

function Get-Data($path)
{
    [xml]$readXML = Get-Content -Path $path
    Write-Host("Get-Data({0}) = {1}" -f $path, $readXML)
    return $readXML
}

function Get-Path($originalPath)
{
    $path = Join-Path -Path $PSScriptRoot -ChildPath $originalPath
    If(!(Test-Path $path))
    {
        Write-Host("Creating {0} in {1}..." -f $originalPath, $PSScriptRoot)
        return New-Item -ItemType "Directory" -Path $PSScriptRoot -Name $originalPath
    }
    return $path
}

function Weighted-Selection($listOfItems)
{
    $totalWeight = 0

    foreach ($item in $listOfItems)
    {
        $weight = $item.Weight
        $totalWeight += $weight
    }

    $randomRoll = Get-Random -Minimum 0.0 -Maximum $totalWeight

    $runningWeight = 0
    $chosenItem = $null
    if ($listOfItems.Count -gt 0)
    {
        $chosenItem = $listOfItems[0]
    }
    foreach ($item in $listOfItems)
    {
        $weight = $item.Weight
        $runningWeight += $weight
        $chosenItem = $item
        if ($runningWeight -ge $randomRoll)
        {
            break
        }
    }
    return $chosenItem
}

Export-ModuleMember -Function *