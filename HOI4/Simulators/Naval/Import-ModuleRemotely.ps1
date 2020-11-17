function Import-ModuleRemotely([string] $moduleName,[System.Management.Automation.Runspaces.PSSession] $session)
{
    $localModule = get-module $moduleName;
    if (! $localModule) 
    { 
        write-warning "No local module by that name exists"; 
        return; 
    }
    function Exports([string] $paramName, $dictionary) 
    { 
        if ($dictionary.Keys.Count -gt 0)
        {
            $keys = $dictionary.Keys -join ",";
            return " -$paramName $keys"
        }
    }
    $fns = Exports "Function" $localModule.ExportedFunctions;
    $aliases = Exports "Alias" $localModule.ExportedAliases;
    $cmdlets = Exports "Cmdlet" $localModule.ExportedCmdlets;
    $vars = Exports "Variable" $localModule.ExportedVariables;
    $exports = "Export-ModuleMember $fns $aliases $cmdlets $vars;";

    $moduleString= @"
if (get-module $moduleName)
{
    remove-module $moduleName;
}
New-Module -name $moduleName {
$($localModule.Definition)
$exports;
}  | import-module
"@
    $script = [ScriptBlock]::Create($moduleString);
    invoke-command -session $session -scriptblock $script;
}