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