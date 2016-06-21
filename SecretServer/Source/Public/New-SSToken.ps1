Function New-SSToken
{
    <#
    .SYNOPSIS
        Create a token for secret server

    .DESCRIPTION
        Create a token for secret server

        Default action updates $SecretServerConfig.Token

    .PARAMETER WebServiceProxy
        Proxy to use.  Defaults to $SecretServerConfig.Proxy

    .PARAMETER Passthru
        Return the token object

    .PARAMETER UpdateSecretConfig
        Update the token set in SecretServer.xml and $SecretServerConfig.token

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
        [System.Management.Automation.PSCredential]$Credential,

        [String]$Domain,
        
        [System.Web.Services.Protocols.SoapHttpClientProtocol]$WebServiceProxy = $SecretServerConfig.Proxy,

        [string]$Uri = $SecretServerConfig.Uri,

        [switch]$Passthru,

        [bool]$UpdateSecretConfig = $true
    )

    if(-not $WebServiceProxy.whoami)
    {
        Write-Warning "Your SecretServer proxy does not appear connected.  Creating new connection to $uri"
        try
        {
            $WebServiceProxy = New-WebServiceProxy -uri $Uri -UseDefaultCredential -ErrorAction stop
        }
        catch
        {
            Throw "Error creating proxy for $Uri`: $_"
        }
    }

    if($Credential.UserName -match "\\")
    {
        $UserName = $Credential.UserName.Split("\")[1]
        $Domain = $Credential.UserName.Split("\")[0]
    }
    Else
    {
        $UserName = $Credential.UserName
    }

    $tokenResult = $WebServiceProxy.Authenticate($UserName, $Credential.GetNetworkCredential().password, '', $Domain)
    
    if($tokenResult.Errors.Count -gt 0)
    {
        Throw "Authentication Error: $($tokenResult.Errors[0])"
    }

    $token = $tokenResult.Token

    if($passthru)
    {
        $Token
    }

    if($UpdateSecretConfig)
    {
        Set-SecretServerConfig -Token $Token
        $SecretServerConfig.Token = $Token
    }


}
