$ErrorActionPreference = 'Stop'

$HomeLocation = $PWD

Import-Module $(Join-Path -Path $HomeLocation -ChildPath 'Util.ps1') -WarningAction SilentlyContinue

$global:ShipA = $null
$global:ShipB = $null
$global:Round = 0

function Update-Damage($ship)
{
    $ship.Alive = ($ship.HitPoints -gt 0)
}

function Fire-Weapon($shots, $piercing, $hitProfile, $target)
{
    # This profile is divided by the gun's hit profile (light: 45, heavy: 80, torpedo: 145, depth charge: 100) and then squared. It factors into the hit chance but can not increase it.
    $hitModifier = ($target.Profile / $hitProfile)
    $hitModifier = $hitModifier * $hitModifier
    $hitChance = Clamp ($hitModifier * 0.1) 0.05 0.1
    $hits = $shots * $hitChance

    $damage = $hits
    if ($target.Armor -gt $piercing)
    {
        $pierced = ($piercing / $target.Armor)
        $damage = Lerp $pierced ($damage * 0.1) $damage
    }
    $hitPoints = $target.HitPoints -as [double]
    $target.HitPoints = [Math]::Max(0.0, $hitPoints - $damage)
}

function Fire-Heavy($ship, $target)
{
    if ($ship.HeavyAttack -gt 0)
    {
        Fire-Weapon $ship.HeavyAttack $ship.HeavyPiercing 80.0 $target
    }
}

function Fire-Light($ship, $targetFleet)
{
    if ($ship.LightAttack -gt 0)
    {
        Fire-Weapon $ship.LightAttack $ship.LightPiercing 45.0 $target
    }
}

function Fire-Torpedo($ship, $targetFleet)
{
    if ($ship.TorpedoAttack -gt 0)
    {
        Fire-Weapon $ship.TorpedoAttack -1 145.0 $target
    }
}

function Ship-Fire($ship, $target)
{
    Fire-Heavy $ship $target
    Fire-Light $ship $target
    Fire-Torpedo $ship $target
}

function Exchange-Fire($shipA, $shipB)
{
    Ship-Fire $shipA $shipB
    Ship-Fire $shipB $shipA
}

function Fight($aShip, $bShip)
{
    $global:ShipA = $aShip
    $global:ShipB = $bShip
    Write-Host("Fight {0} vs {1}" -F $aShip.Name, $bShip.Name)
 
    Update-Damage $global:ShipA
    Update-Damage $global:ShipB
    while ($true)
    {
        Exchange-Fire $global:ShipA $global:ShipB

        Update-Damage $global:ShipA
        Update-Damage $global:ShipB

        if ($global:ShipA.Alive -eq $false -or $global:ShipB.Alive -eq $false)
        {
            $shipADamage = $global:ShipB.HP - $global:ShipB.HitPoints
            $shipBDamage = $global:ShipA.HP - $global:ShipA.HitPoints
            return ($shipADamage / ($shipADamage + $shipBDamage))
        }
    }
}