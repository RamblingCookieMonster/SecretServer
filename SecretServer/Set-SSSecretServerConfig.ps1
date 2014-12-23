Function Set-SSSecretServerConfig {
    <#
    .SYNOPSIS
        Set Secret Server module configuration.

    .DESCRIPTION
        Set Secret Server module configuration, and live $SecretServerConfig global variable.

        This data is used as the default for most commands.

    .PARAMETER Proxy
        Specify a proxy to use

    .PARAMETER Uri
        Specify a Uri to use

    .Example
        $Uri = 'https://SecretServer.Example/winauthwebservices/sswinauthwebservice.asmx'

        $Proxy = New-WebServiceProxy -Uri $uri -UseDefaultCredential

        Set-SSSecretServerConfig -Proxy $Proxy -Uri $Uri

    .Example
        Set-SSSecretServerConfig -Uri 'https://SecretServer.Example/winauthwebservices/sswinauthwebservice.asmx'

    .FUNCTIONALITY
        Secret Server
    #>
    [cmdletbinding()]
    param(
        [System.Web.Services.Protocols.SoapHttpClientProtocol]$Proxy,
        [string]$Uri
    )

    Try
    {
        $Existing = Get-SSSecretServerConfig -ErrorAction stop
    }
    Catch
    {
        Throw "Error getting Secret Server config: $_"
    }

    if($Proxy)
    {
        $Existing.Proxy = $Proxy
    }
    If($Uri)
    {
        $Existing.Uri = $Uri
    }

    #Write the global variable and the xml
    $Global:SecretServerConfig = $Existing
    $Existing | Export-Clixml -Path "$PSScriptRoot\SecretServer.xml" -force

}