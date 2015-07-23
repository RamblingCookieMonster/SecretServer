Function Get-SSVersion
{
    <#
    .SYNOPSIS
        Gets the version of Secret Server.

    .DESCRIPTION
        Gets the version of Secret Server.

    .EXAMPLE
        #Compares the version of Secret Server against a known version.
        
        $Version = Get-SSVersion
        if ($Version -lt [Version]"8.0.0") 
    
    .FUNCTIONALITY
        Secret Server

    #>
    [cmdletbinding()]
    param(
        [string]$Uri = $SecretServerConfig.Uri,
        [System.Web.Services.Protocols.SoapHttpClientProtocol]$WebServiceProxy = $SecretServerConfig.Proxy
    )
    Begin
    {
        Write-Verbose "Working with PSBoundParameters $($PSBoundParameters | Out-String)"
        if(-not $WebServiceProxy.whoami)
        {
            Write-Warning "Your SecretServerConfig proxy does not appear connected.  Creating new connection to $uri"
            try
            {
                $WebServiceProxy = New-WebServiceProxy -uri $Uri -UseDefaultCredential -ErrorAction stop
            }
            catch
            {
                Throw "Error creating proxy for $Uri`: $_"
            }
        }
    }
    Process
    {
        $VersionResult = $WebServiceProxy.VersionGet()
        if ($VersionResult.Errors.Length -gt 0)
        {
            Throw "Secret Server reported an error while calling VersionGet."
        }
        Return [Version]$VersionResult.Version
    }
}