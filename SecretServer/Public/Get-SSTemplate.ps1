function Get-SSTemplate {
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
    [CmdletBinding()]
    param(
        [string[]]$Name = $null,
        [string]$Id = $null,
        [switch]$Raw,        
        [string]$Uri = $SecretServerConfig.Uri,
        [System.Web.Services.Protocols.SoapHttpClientProtocol]$WebServiceProxy = $SecretServerConfig.Proxy,
        [string]$Token = $SecretServerConfig.Token        
    )

    if(-not $WebServiceProxy.whoami) {
        Write-Warning "Your SecretServerConfig proxy does not appear connected.  Creating new connection to $uri"
        try {
            $WebServiceProxy = New-WebServiceProxy -uri $Uri -UseDefaultCredential -ErrorAction stop
        }
        catch {
            Throw "Error creating proxy for $Uri`: $_"
        }
    }

    #Find all templates, filter on name
    if($Token) {
        $AllTemplates = @( $WebServiceProxy.GetSecretTemplates($Token) )
    }
    else {
        $AllTemplates = @( $WebServiceProxy.GetSecretTemplates() )
    }

    if($AllTemplates.Errors -and $AllTemplates.Errors.Count -gt 0) {
        Write-Error "Secret server returned error $($AllTemplates.Errors | Out-String)"
        return
    }
    $AllTemplates = $AllTemplates.SecretTemplates
    Write-Verbose "Found $($AllTemplates.Count) templates"

    if($Name) {
        $AllTemplates = $AllTemplates | Foreach-Object {
            $ThisName = $_.Name
            foreach($InputName in $Name)
            {
                If($Thisname -like $InputName ) { $_ }
            }
        }
    }
    Write-Verbose "Filtered for name to $($AllTemplates.Count) templates"
    
    if($Id) {
        $AllTemplates  = $AllTemplates | Where-Object {$_.Id -like $Id}
    }
    Write-Verbose "Filtered for id to $($AllTemplates.Count) templates"
        
    #Extract the secrets
    if($Raw) {
        $AllTemplates
    }
    else {
        foreach($Template in $AllTemplates) {
            #Start building up output
            [pscustomobject]@{
                PSTypeName = "SecretServer.Template"
                ID = $Template.Id
                Name = $Template.Name
                Fields = $Template.Fields
            }
        }
    }
}