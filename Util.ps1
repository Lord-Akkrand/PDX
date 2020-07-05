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

function Get-Data($path)
{
    [xml]$readXML = Get-Content -Path $path
    Write-Host("Get-Data({0}) = {1}" -f $path, $readXML)
    return $readXML
}

function Get-FleetPath($path)
{
    $path = Join-Path -Path $PSScriptRoot -ChildPath $path
    If(!(Test-Path $path))
    {
        New-Item -ItemType Directory -Force -Path $path
    }
    return $path
}