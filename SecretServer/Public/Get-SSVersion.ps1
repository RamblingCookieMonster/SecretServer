function Get-SSVersion {
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
    [CmdletBinding()]
    param(
        [string]$Uri = $SecretServerConfig.Uri,
        [System.Web.Services.Protocols.SoapHttpClientProtocol]$WebServiceProxy = $SecretServerConfig.Proxy,
        [string]$Token = $SecretServerConfig.Token        
    )
    begin {
        Write-Verbose "Working with PSBoundParameters $($PSBoundParameters | Out-String)"
        if(-not $WebServiceProxy.whoami) {
            Write-Warning "Your SecretServerConfig proxy does not appear connected.  Creating new connection to $uri"
            try {
                $WebServiceProxy = New-WebServiceProxy -uri $Uri -UseDefaultCredential -ErrorAction stop
            }
            catch {
                throw "Error creating proxy for $Uri`: $_"
            }
        }
    }
    process {
        if($Token) {
            $VersionResult = $WebServiceProxy.VersionGet($Token)
        }
        else {
            $VersionResult = $WebServiceProxy.VersionGet()
        }
        if ($VersionResult.Errors.Length -gt 0) {
            throw "Secret Server reported an error while calling VersionGet."
        }
        return [Version]$VersionResult.Version
    }
}