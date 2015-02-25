Function Get-SecretServerConfig {
    <#
    .SYNOPSIS
        Get Secret Server module configuration.

    .DESCRIPTION
        Get Secret Server module configuration

    .FUNCTIONALITY
        Secret Server
    #>
    [cmdletbinding()]
    param(
        [ValidateSet("Variable","ConfigFile")]$Source = "Variable"
    )

    if($Source -eq "Variable")
    {
        $SecretServerConfig
    }
    else
    {
        Import-Clixml -Path "$PSScriptRoot\SecretServer.xml"
    }

}