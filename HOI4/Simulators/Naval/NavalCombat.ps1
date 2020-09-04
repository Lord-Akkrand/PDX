$ErrorActionPreference = 'Stop'

$HomeLocation = $PWD

Import-Module $(Join-Path -Path $HomeLocation -ChildPath 'Util.ps1') -WarningAction SilentlyContinue

$global:Round = 0

function Update-Damage($ship)
{
    $ship.Alive = ($ship.HitPoints -gt 0)
}

function Fire-Weapon($shots, $piercing, $hitProfile, $target, $screenModifier)
{
    # This profile is divided by the gun's hit profile (light: 45, heavy: 80, torpedo: 145, depth charge: 100) and then squared. It factors into the hit chance but can not increase it.
    $hitModifier = ($target.Profile / $hitProfile)
    $hitModifier = $hitModifier * $hitModifier
    $hitChance = Clamp ($hitModifier * 0.1) 0.05 0.1
    $hitChance *= $screenModifier
    $hitRoll = Get-Random -Minimum 0.0 -Maximum 1.0
    
    if ($hitRoll -le $hitChance)
    {
        $damage = $shots
        $critChance = 0.1
        if ($target.Armor -gt $piercing)
        {
            $pierced = ($piercing / $target.Armor)
            $damage = Lerp $pierced ($damage * 0.1) $damage
        }
        else 
        {
            $critChance = 0.2
        }
        $reliabilityCritMod = 1.0 / $ship.Reliability
        if ($weaponType -ne "Torpedo")
        {
            $critChance *= $reliabilityCritMod
        }
        $damageRandom = Get-Random -Minimum 0.85 -Maximum 1.15
        $damage = $damage * $damageRandom
        
        $critRoll = Get-Random -Minimum 0.0 -Maximum 1.0
        if ($critRoll -le $critChance)
        {
            $oldDamage = $damage
            if ($weaponType -eq "Torpedo")
            {
                $damage *= 2.0
            }
            else 
            {
                $reliailityDamageMod = 1 - $ship.Reliability
                $damageMod = Lerp $reliailityDamageMod 5.0 1.0
                $damage *= ($damageMod + 1.0)
            }
            
            Write-Host("Critical Hit! {0}->{1}" -f [int]$oldDamage, [int]$damage)
        }

        
        $orgDamage = $damage * 1.6 * (1 - ($target.HitPoints / $target.HP))
        $strDamage = $damage * 1.0
        $hitPoints = $target.HitPoints -as [double]
        $target.Org = [Math]::Max(0.0, $target.Org - $orgDamage)
        $target.HitPoints = [Math]::Max(0.0, $hitPoints - $strDamage)
    }
}

function Fire-Heavy($ship, $target)
{
    Fire-Weapon $ship.HeavyAttack $ship.HeavyPiercing 80.0 $target $ship.ScreenModifier
}

function Fire-Light($ship, $target)
{
    
    Fire-Weapon $ship.LightAttack $ship.LightPiercing 45.0 $target $ship.ScreenModifier
}

function Fire-Torpedo($ship, $target)
{
    Fire-Weapon $ship.Torpedo 666.0 145.0 $target $ship.ScreenModifier
}

function Ship-FireAll($ship, $target)
{
    if ($ship.HeavyAttack -gt 0)
    {
        Fire-Heavy $ship $target
    }
    if ($ship.LightAttack -gt 0)
    {
        Fire-Light $ship $target
    }
    if ($ship.Torpedo -gt 0)
    {
        Fire-Torpedo $ship $target
    }
}

function Exchange-Fire($shipA, $shipB)
{
    Ship-FireAll $shipA $shipB
    Ship-FireAll $shipB $shipA
}

$TargetWeighting = @{
    "Heavy"=@{
        "Capital"=30;
        "Screen"=3;
        "Submarine"=4;
        "Carrier"=1;
        "Convoy"=60;
    };
    "Light"=@{
        "Capital"=2;
        "Screen"=6;
        "Submarine"=4;
        "Carrier"=1;
        "Convoy"=4;
    };
}
$TargetWeighting["Torpedo"] = Deep-Copy $TargetWeighting["Heavy"]


function Available-Targets($weaponType, $targetFleet, $viableTargets)
{
    $screenViable = $TRUE
    $capitalViable = $FALSE
    $carrierViable = $FALSE
    if ($weapontype -eq "Light")
    {
        $capitalViable = $targetFleet.Screens -le 0
        $carrierViable = $capitalViable
    }
    elseif ($weapontype -eq "Torpedo") 
    {
        $randomRoll = Get-Random -Minimum 0.0 -Maximum 1.0
        $capitalViable = $randomRoll -gt $targetFleet.ScreeningEfficiency
        $randomRoll = Get-Random -Minimum 0.0 -Maximum 1.0
        $carrierViable = $randomRoll -gt $targetFleet.CarrierScreeningEfficiency
    }
    elseif ($weapontype -eq "Heavy")
    {
        $capitalViable = $TRUE
        $carrierViable = $TRUE
    }
    
    foreach ($ship in $targetFleet.Ships) 
    {
        if ($ship.Alive)
        {
            if ($ship.Screen -gt 0 -and $screenViable)    
            {
                $viableTargets.Add($ship) | Out-Null
            }
            if ($ship.Capital -gt 0 -and $capitalViable)
            {
                $viableTargets.Add($ship) | Out-Null
            }
            if ($ship.Carrier -gt 0 -and $carrierViable)
            {
                $viableTargets.Add($ship) | Out-Null
            }
        }
    }
}

function Find-Target($shipType, $weaponType, $targetFleet)
{
    [System.Collections.ArrayList]$availableTargets = @()
    Available-Targets $weaponType $targetFleet $availableTargets

    [System.Collections.ArrayList]$weightedItems = @()

    foreach ($ship in $availableTargets)
    {
        $weighting = $TargetWeighting[$weaponType][$ship["TargetType"]]
        $weightedItems.Add(@{
            "Weight"=$weighting;
            "Ship"=$ship;
        }) | Out-Null
    }

    $chosenItem = Weighted-Selection $weightedItems
    if ($chosenItem -ne $null)
    {
        $ship = $chosenItem["Ship"]
        return $ship
    }
    if ($availableTargets.Count -gt 0)
    {
        $chosenItem = Weighted-Selection $weightedItems
    }

    Write-Host("No target found for {0} from {1}" -f $weaponType, $availableTargets.Count)
    return $null
}

# submarine vs convoy: 600 (40)
# non-sub vs convoy: 60 (4)

function Engage-Heavy($ship, $targetFleet)
{
    # Pick a target then fire at it
    $target = Find-Target $ship.Hull "Heavy" $targetFleet
    if ($target)
    {
        Fire-Heavy $ship $target
    }
}

function Engage-Light($ship, $targetFleet)
{
    # Pick a target then fire at it
    $target = Find-Target $ship.Hull "Light" $targetFleet
    if ($target)
    {
        Fire-Light $ship $target
    }

}

function Engage-Torpedo($ship, $targetFleet)
{
    # Pick a target then fire at it
    $target = Find-Target $ship.Hull "Torpedo" $targetFleet
    if ($target)
    {
        Fire-Torpedo $ship $target
    }
}

function Ship-Fire($ship, $targetFleet, $round)
{
    if ($ship.HeavyAttack -gt 0)
    {
        Engage-Heavy $ship $targetFleet
    }
    if ($ship.LightAttack -gt 0)
    {
        Engage-Light $ship $targetFleet
    }
    if ($ship.Torpedo -gt 0)
    {
        $torpRound = $round % 4
        if ($torpRound -eq 0)
        {
            Engage-Torpedo $ship $targetFleet
        }
    }
}

function Fleet-Fire($fleet, $targetFleet, $round)
{
    foreach ($ship in $fleet.Ships)
    {
        if ($ship.Alive)
        {
            Ship-Fire $ship $targetFleet $round
        }
    }
}

function Fleets-Fire($fleetA, $fleetB, $round)
{
    Fleet-Fire $fleetA $fleetB $round
    Fleet-Fire $fleetB $fleetA $round
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
    $hp = 0
    $screens = 0
    $capitals = 0
    $carriers = 0
    $submarines = 0
    $convoys = 0
    foreach ($ship in $fleet.Ships)
    {
        Update-Damage $ship
        $alive = $alive -or $ship.Alive
        $hitPoints += $ship.HitPoints
        $hp += $ship.HP
        if ($ship.Alive)
        {
            $screens += $ship.Screen
            $capitals += $ship.Capital
            $carriers += $ship.Carrier
            $submarines += $ship.Submarine
            $convoys += $ship.Convoy
        }
    }
    $fleet.TotalShips = $screens + $capitals + $submarines + $convoys
    if ($fleet.TotalShips -eq 0 -and $alive)
    {
        Write-Host ("HEY!")
    }
    $fleet.HP = $hp
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

    foreach ($ship in $fleet.Ships)
    {
        $screenModifier = 1.0
        if ($ship.Capital -gt 0 -or $ship.Carrier -gt 0)
        {
            $screenModifier = Lerp $fleet.ScreeningEfficiency 1.0 1.4
        }
        $ship.ScreenModifier = $screenModifier
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

function Get-FleetString($fleet)
{
    $outString = ""
    foreach ($ship in $fleet.Ships)
    {
        #$shipPC = ($ship.HitPoints / $ship.HP) * 100
        $shipPC = [Math]::Max(0, $ship.HitPoints)
        if ($ship.Capital -gt 0 -or $ship.Carrier -gt 0)
        {
            $outString = ("{0}[{1}]" -f $outString, [int]$shipPC)
        }
        else 
        {
            $outString = ("{0}({1})" -f $outString, [int]$shipPC)    
        }
    }
    return $outString
}

function Fleet-Engagement($fleetA, $fleetB)
{
    Write-Host("Fleet Engagement {0} vs {1}" -F $fleetA.Name, $fleetB.Name)
    Update-Fleet $fleetA
    Update-Fleet $fleetB

    $round = 0
    while ($true)
    {
        Fleets-Fire $fleetA $fleetB $round
        $round++

        Update-Fleet $fleetA
        Update-Fleet $fleetB

        #Write-Host("Round {0}, {1}/{2} vs {3}/{4}" -f $round, $fleetA.HitPoints, $fleetA.HP, $fleetB.HitPoints, $fleetB.HP)
        $fleetAString = Get-FleetString $fleetA
        $fleetBString = Get-FleetString $fleetB
        Write-Host("Round {0}, {1} vs {2}" -f $round, $fleetAString, $fleetBString)
        if ($fleetA.Alive -eq $false -or $fleetB.Alive -eq $false)
        {
            $fleetADamage = $fleetB.HP - $fleetB.HitPoints
            $fleetBDamage = $fleetA.HP - $fleetA.HitPoints
            return ($fleetADamage / ($fleetADamage + $fleetBDamage))
        }
    }
}