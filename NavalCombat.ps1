$ErrorActionPreference = 'Stop'

$HomeLocation = $PWD

Import-Module $(Join-Path -Path $HomeLocation -ChildPath 'Util.ps1') -WarningAction SilentlyContinue

$global:FleetA = $null
$global:FleetB = $null
$global:Round = 0

$PresetFleets = @()

$PresetsXML = Get-Data (Join-Path -Path $PSScriptRoot -ChildPath "Presets.xml")

function Fight($aFleet, $bFleet)
{
    $global:FleetA = $aFleet
    $global:FleetB = $bFleet
    Write-Host "Fight"
}