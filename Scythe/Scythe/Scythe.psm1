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

function Step-Round($player)
{

}

function Test-Player($player, $rounds, $returnValue)
{
    $returnValue["Output"] = ("Test Player {1} for {1} rounds" -f $player.Name, $rounds)
    $TempFile = New-TemporaryFile
    Set-Content $TempFile.FullName -Value "Test"
    Add-Content $TempFile.FullName -Value "Twice"
    $returnValue["OutputFiles"] = @{}
    $returnValue["OutputFiles"]["test.xml"] = $TempFile.FullName
}

Export-ModuleMember -Function * -Alias * -Variable * -Cmdlet *
