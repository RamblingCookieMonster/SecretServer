Function New-SSConnection
{
    <#
    .SYNOPSIS
        Create a connection to secret server

    .DESCRIPTION
        Create a connection to secret server

        Default action updates $SecretServerConfig.Proxy which most functions use as a default

    .PARAMETER Uri
        Uri to connect to.  Defaults to $SecretServerConfig.Uri

    .PARAMETER Passthru
        Return the proxy object

    .PARAMETER UpdateSecretConfig
        Update the Proxy set in SecretServerConfig.xml and $SecretServerConfig.Proxy

    .EXAMPLE
        New-SSConnection

        # Create a proxy to the Uri from $SecretServerConfig.Uri
        # Set the $SecretServerConfig.Proxy to this value
        # Set the Proxy property in SecretServerConfig.xml to this value

    .EXAMPLE
        $Proxy = New-SSConnection -Uri https://FQDN.TO.SECRETSERVER/winauthwebservices/sswinauthwebservice.asmx -Passthru

        # Create a proxy to the specified uri, pass this through to the $proxy variable
        # This still changes the SecretServerConfig proxy to the resulting proxy
    #>
    [cmdletbinding()]
    param(       
        [string]$Uri = $SecretServerConfig.Uri,

        [switch]$Passthru,

        [bool]$UpdateSecretConfig = $true
    )

    #Windows Auth works.  Uses SOAP
        try
        {
            $Proxy = New-WebServiceProxy -uri $Uri -UseDefaultCredential -ErrorAction stop
        }
        catch
        {
            Throw "Error creating proxy for $Uri`: $_"
        }
            
        if($passthru)
        {
            $Proxy
        }

        if($UpdateSecretConfig)
        {
            Set-SSSecretServerConfig -Proxy $Proxy
        }


}