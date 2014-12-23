Function Get-SSTemplate
{
    <#
    .SYNOPSIS
        Get details on secret templates from secret server

    .DESCRIPTION
        Get details on secret templates from secret server

    .PARAMETER Name
        Name to search for.  Accepts wildcards as '*'.

    .PARAMETER Id
        Id to search for.  Accepts wildcards as '*'.

    .PARAMETER Raw
        If specified, return raw template object

    .PARAMETER WebServiceProxy
        An existing Web Service proxy to use.  Defaults to $SecretServerConfig.Proxy

    .PARAMETER Uri
        Uri for your win auth web service.  Defaults to $SecretServerConfig.Uri.  Overridden by WebServiceProxy parameter

    .EXAMPLE
        Get-SSTemplate -Name "Windows*"

    .EXAMPLE
        Get-SSTemplate -Id 6001

    .FUNCTIONALITY
        Secret Server
    #>
    [cmdletbinding()]
    param(
        [string[]]$Name = $null,
        [string]$Id = $null,
        [string]$Uri = $SecretServerConfig.Uri,
        [System.Web.Services.Protocols.SoapHttpClientProtocol]$WebServiceProxy = $SecretServerConfig.Proxy,
        [switch]$Raw
    )

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

    #Find all templates, filter on name
        $AllTemplates = @( $WebServiceProxy.GetSecretTemplates().SecretTemplates )

        if($Name)
        {
            $AllTemplates = $AllTemplates | Foreach-Object {
                $ThisName = $_.Name
                foreach($InputName in $Name)
                {
                    If($Thisname -like $InputName ) { $_ }
                }
            }
        }
        
        if($Id)
        {
            $AllTemplates  = $AllTemplates | Where-Object {$_.Id -like $Id}
        }
        
    #Extract the secrets
        if($Raw)
        {
            $AllTemplates
        }
        else
        {
            foreach($Template in $AllTemplates)
            {
                #Start building up output
                    [pscustomobject]@{
                        ID = $Template.Id
                        Name = $Template.Name
                        Fields = $Template.Fields.Displayname -Join ", "
                    }
            }
        }
}