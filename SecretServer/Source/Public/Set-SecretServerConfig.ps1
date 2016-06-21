Function Set-SecretServerConfig {
    <#
    .SYNOPSIS
        Set Secret Server module configuration.

    .DESCRIPTION
        Set Secret Server module configuration, and live $SecretServerConfig global variable.

        This data is used as the default for most commands.

    .PARAMETER Proxy
        Specify a proxy to use

        This is not stored in the XML

    .PARAMETER Uri
        Specify a Uri to use

    .PARAMETER ServerInstance
        SQL Instance to query for commands that hit Secret Server database

    .PARAMETER Database
        SQL database to query for commands that hit Secret Server database

    .PARAMETER Token
        Specify a Token to use

    .Example
        $Uri = 'https://SecretServer.Example/winauthwebservices/sswinauthwebservice.asmx'

        $Proxy = New-WebServiceProxy -Uri $uri -UseDefaultCredential

        Set-SecretServerConfig -Proxy $Proxy -Uri $Uri

    .Example
        Set-SecretServerConfig -Uri 'https://SecretServer.Example/winauthwebservices/sswinauthwebservice.asmx'

    .FUNCTIONALITY
        Secret Server
    #>
    [cmdletbinding()]
    param(
        [System.Web.Services.Protocols.SoapHttpClientProtocol]$Proxy,
        [string]$Uri,
        [string]$Token,
        [string]$ServerInstance,
        [string]$Database
    )

    Try
    {
        $Existing = Get-SecretServerConfig -ErrorAction stop
    }
    Catch
    {
        Throw "Error getting Secret Server config: $_"
    }

    foreach($Key in $PSBoundParameters.Keys)
    {
        if(Get-Variable -name $Key)
        {
            #We use add-member force to cover cases where we add props to this config...
            $Existing | Add-Member -MemberType NoteProperty -Name $Key -Value $PSBoundParameters.$Key -Force
        }
    }

    #Write the global variable and the xml
    $Global:SecretServerConfig = $Existing
    $Existing | Select -Property * -ExcludeProperty Proxy | Export-Clixml -Path "$PSScriptRoot\SecretServer.xml" -force

}