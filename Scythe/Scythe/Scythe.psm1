$ErrorActionPreference = 'Stop'

enum Resources {
    Gold = [int][char]'$'
    Popularity = [int][char]'@'
    Power = [int][char]'^'
    Cards = [int][char]'='
    Worker = [int][char]'!'
    Produce = [int][char]'%'
    Food = [int][char]'F'
    Metal = [int][char]'M'
    Oil = [int][char]'O'
    Wood = [int][char]'W'
    ResourceAny = [int][char]'?'
    Movement = [int][char]'>'
    Mech = [int][char]'*'
    Building = [int][char]'e'
    Upgrade = [int][char]'#'
    Recruit = [int][char]'|'
}

function Test-Combination($faction, $playmat, $rounds)
{
    $retValue = ("Test Combination {0} {1} for {2} rounds" -f $faction.Name, $playmat.Name, $rounds)
    return $retValue
}

Export-ModuleMember -Function * -Alias * -Variable * -Cmdlet *
