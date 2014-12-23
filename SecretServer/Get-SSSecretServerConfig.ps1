Function Get-SSSecretServerConfig {
    <#
    .SYNOPSIS
        Get Secret Server module configuration.

    .DESCRIPTION
        Get Secret Server module configuration

    .FUNCTIONALITY
        Secret Server
    #>
    [cmdletbinding()]
    param()

    Import-Clixml -Path "$PSScriptRoot\SecretServer.xml"

}