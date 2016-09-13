function Get-SecretServerConfig {
    <#
        .SYNOPSIS
            Get Secret Server module configuration.

        .DESCRIPTION
            Get Secret Server module configuration

        .FUNCTIONALITY
            Secret Server
    #>
    [CmdletBinding()]
    param(
        [ValidateSet("Variable","ConfigFile")]$Source = "Variable"
    )

    if(-not (Test-Path -Path "$PSScriptRoot\SecretServer.xml" -ErrorAction SilentlyContinue)) {
        try {
            Write-Verbose "Did not find config file $PSScriptRoot\SecretServer.xml attempting to create"
            [pscustomobject]@{
                Uri = $null
                Token = $null
                ServerInstance = $null
                Database = $null
            } | Export-Clixml -Path "$PSScriptRoot\SecretServer.xml" -Force -ErrorAction Stop
        }
        catch {
            Write-Warning "Failed to create config file $PSScriptRoot\SecretServer.xml: $_"
        }
    }    

    if($Source -eq "Variable" -and $SecretServerConfig) {
        $SecretServerConfig
    }
    else {
        Import-Clixml -Path "$PSScriptRoot\SecretServer.xml"
    }
}

#publish
New-Alias -Name Get-SSServerConfig -Value Get-SecretServerConfig -Force
New-Alias -Name Get-SSConfig -Value Get-SecretServerConfig -Force
#endpublish