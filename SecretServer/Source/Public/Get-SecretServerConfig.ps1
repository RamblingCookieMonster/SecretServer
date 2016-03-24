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

    if(-not (Test-Path -Path "$PSScriptRoot\SecretServer_$($env:USERNAME).xml" -ErrorAction SilentlyContinue))
    {
        Try
        {
            Write-Verbose "Did not find config file $PSScriptRoot\SecretServer_$($env:USERNAME).xml attempting to create"
            [pscustomobject]@{
                Uri = $null
                Token = $null
                ServerInstance = $null
                Database = $null
            } | Export-Clixml -Path "$PSScriptRoot\SecretServer_$($env:USERNAME).xml" -Force -ErrorAction Stop
        }
        Catch
        {
            Write-Warning "Failed to create config file $PSScriptRoot\SecretServer_$($env:USERNAME).xml: $_"
        }
    }    

    if($Source -eq "Variable" -and $SecretServerConfig)
    {
        $SecretServerConfig
    }
    else
    {
        Import-Clixml -Path "P:\Scripts\SecretServer\SecretServer\SecretServer_$($env:USERNAME).xml"
    }

}

#publish
New-Alias -Name Get-SSServerConfig -Value Get-SecretServerConfig -Force
New-Alias -Name Get-SSConfig -Value Get-SecretServerConfig -Force
#endpublish