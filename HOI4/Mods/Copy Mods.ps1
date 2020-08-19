param
(
    [String]$RelativeModsPath="Paradox Interactive\Hearts of Iron IV\mod"
)
$ErrorActionPreference = 'Stop'

$DocumentsPath = [Environment]::GetFolderPath("MyDocuments")
$ModsPath = Join-Path $DocumentsPath -ChildPath $RelativeModsPath

function Get-Tree($Path,$Include='*') { 
    @(Get-Item $Path -Include $Include -Force) + 
        (Get-ChildItem $Path -Recurse -Include $Include -Force) | 
        sort pspath -Descending -unique
} 

function Remove-Tree($Path,$Include='*') { 
    Get-Tree $Path $Include | Remove-Item -force -recurse
} 

$HomeLocation = $PWD

Clear-Host

$existing_mods = Get-ChildItem $ModsPath | ? {$_.PSIsContainer}

$mod_folders = Get-ChildItem $PSScriptRoot | ? {$_.PSIsContainer}

$mod_folders | ForEach-Object {
    $mod_name = $_.Name
    $mod_path = $_.FullName
    $existing_mods | ForEach-Object {
        if ($_.Name -eq $mod_name) {
            Write-Host ("Removing existing test mod {0}" -f $mod_name)
            Remove-Tree $_.FullName
            Remove-Item -Force ($_.FullName + ".mod")
        }
    }
    New-Item -Path $ModsPath -Name $mod_name -ItemType "directory"
    $new_base = Join-Path $ModsPath -ChildPath $mod_name
    Copy-Item -Path (Join-Path $mod_path -ChildPath ("{0}.mod" -f $mod_name)) -Destination $ModsPath
    Copy-Item -Path (Join-Path $mod_path -ChildPath "thumbnail.png") -Destination $new_base
    Copy-Item -Path (Join-Path $mod_path -ChildPath "new\*") -Destination $new_base -Recurse
}
