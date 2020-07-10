$ErrorActionPreference = 'Stop'

$HomeLocation = $PWD

Import-Module $(Join-Path -Path $HomeLocation -ChildPath 'Util.ps1') -WarningAction SilentlyContinue

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

function Fire-Light($ship, $target)
{
    if ($ship.LightAttack -gt 0)
    {
        Fire-Weapon $ship.LightAttack $ship.LightPiercing 45.0 $target
    }
}

function Fire-Torpedo($ship, $target)
{
    if ($ship.TorpedoAttack -gt 0)
    {
        Fire-Weapon $ship.TorpedoAttack -1 145.0 $target
    }
}

function Ship-FireAll($ship, $target)
{
    Fire-Heavy $ship $target
    Fire-Light $ship $target
    Fire-Torpedo $ship $target
}

function Exchange-Fire($shipA, $shipB)
{
    Ship-FireAll $shipA $shipB
    Ship-FireAll $shipB $shipA
}

function Engage-Heavy($ship, $targetFleet)
{

}

function Ship-Fire($ship, $targetFleet)
{
    Engage-Heavy $ship $targetFleet
    Engage-Light $ship $targetFleet
    Engage-Torpedo $ship $targetFleet
}

function Fleet-Fire($fleet, $targetFleet)
{
    foreach ($ship in $fleet)
    {
        if ($ship.Alive)
        {
            Ship-Fire $ship $targetFleet
        }
    }
}

function Fleets-Fire($fleetA, $fleetB)
{
    Fleet-Fire $fleetA $fleetB
    Fleet-Fire $fleetB $fleetA
}

function Fight($shipA, $shipB)
{
    Write-Host("Fight {0} vs {1}" -F $shipA.Name, $shipB.Name)
 
    Update-Damage $shipA
    Update-Damage $shipB
    while ($true)
    {
        Exchange-Fire $shipA $shipB

        Update-Damage $shipA
        Update-Damage $shipB

        if ($shipA.Alive -eq $false -or $shipB.Alive -eq $false)
        {
            $shipADamage = $shipB.HP - $shipB.HitPoints
            $shipBDamage = $shipA.HP - $shipA.HitPoints
            return ($shipADamage / ($shipADamage + $shipBDamage))
        }
    }
}

function Update-Fleet($fleet)
{
    $alive = $false
    $hitPoints = 0
    $screens = 0
    $capitals = 0
    $carriers = 0
    $submarines = 0
    $convoys = 0
    foreach ($ship in $fleet)
    {
        Update-Damage $ship
        $alive = $alive -or $ship.Alive
        $hitPoints += $ship.HitPoints
        if ($ship.Alive)
        {
            $screens += $ship.Screen
            $capitals += $ship.Capitals
            $carriers += $ship.Carriers
            $submarines += $ship.Submarines
            $convoys += $ship.Convoys
        }
    }
    $fleet.Alive = $alive
    $fleet.HitPoints = $hitPoints
    $fleet.Screens = $screens
    $fleet.Capitals = $capitals
    $fleet.Carriers = $carriers
    $fleet.Submarines = $submarines
    $fleet.Convoys = $convoys

    $requiredScreens = ($capitals + $carriers) * 4.0
    if ($requiredScreens -gt 0)
    {
        $fleet.ScreeningEfficiency = Clamp ($screens / $requiredScreens) 0.0 1.0
    }
    else
    {
        $fleet.ScreeningEfficiency = 1
    }

    if ($carriers -gt 0)
    {
        $fleet.CarrierScreeningEfficiency = Clamp ($capitals / $carriers) 0.0 1.0
    }
    else
    {
        $fleet.CarrierScreeningEfficiency = 1
    }
}

function Fleet-Engagement($fleetA, $fleetB)
{
    Write-Host("Fleet Engagement {0} vs {1}" -F $fleetA.Name, $fleetB.Name)
    Update-Fleet $fleetA
    Update-Fleet $fleetB

    while ($true)
    {
        Fleets-Fire $fleetA $fleetA

        Update-Damage $shipA
        Update-Damage $shipB
        if ($fleetA.Alive -eq $false -or $fleetB.Alive -eq $false)
        {
            $fleetADamage = $fleetB.HP - $fleetB.HitPoints
            $fleetBDamage = $fleetA.HP - $fleetA.HitPoints
            return ($fleetADamage / ($fleetADamage + $fleetBDamage))
        }
    }
}