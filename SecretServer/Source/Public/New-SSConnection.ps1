Function New-SSConnection
{
    <#
    .SYNOPSIS
        Create a connection to secret server

    .DESCRIPTION
        Create a connection to secret server

        Default action updates $SecretServerConfig.Proxy which most functions use as a default

        If you specify a winauthwebservices endpoint, we remove any existing Token from your module configuration.

    .PARAMETER Uri
        Uri to connect to.  Defaults to $SecretServerConfig.Uri

    .PARAMETER Passthru
        Return the proxy object

    .PARAMETER UpdateSecretConfig
        Update the Proxy set in SecretServer.xml and $SecretServerConfig.Proxy

    .EXAMPLE
        New-SSConnection

        # Create a proxy to the Uri from $SecretServerConfig.Uri
        # Set the $SecretServerConfig.Proxy to this value
        # Set the Proxy property in SecretServer.xml to this value

    .EXAMPLE
        $Proxy = New-SSConnection -Uri https://FQDN.TO.SECRETSERVER/winauthwebservices/sswinauthwebservice.asmx -Passthru

        # Create a proxy to the specified uri, pass this through to the $proxy variable
        # This still changes the SecretServerConfig proxy to the resulting proxy
    #>
    [cmdletbinding()]
    param(       
        [string]$Uri = $SecretServerConfig.Uri,

        [switch]$Passthru,

        [bool]$UpdateSecretConfig = $true,

        [bool]$UseDefaultCredential = $True
    )

    #Windows Auth works.  Uses SOAP
        try
        {
            $Params = @{
                uri = $Uri
                ErrorAction = 'Stop'
            }
            If($UseDefaultCredential)
            {
                $Params.Add("UseDefaultCredential", $True)
            }
            $Proxy = New-WebServiceProxy @Params
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
            if(-not (Get-SecretServerConfig).Uri)
            {
                Set-SecretServerConfig -Uri $Uri
                $SecretServerConfig.Uri = $Uri
            }
            $SecretServerConfig.Proxy = $Proxy
            
            if($Uri -match "winauthwebservices")
            {
                Set-SecretServerConfig -Token ""
            }
        }
}