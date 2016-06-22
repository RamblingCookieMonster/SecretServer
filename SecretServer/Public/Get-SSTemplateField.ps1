function Get-SSTemplateField {
    <#
        .SYNOPSIS
            Get fields on secret templates from secret server

        .DESCRIPTION
            Get fields on secret templates from secret server

        .PARAMETER Name
            Template Name to search for.  Accepts wildcards as '*'.

        .PARAMETER ID
            Template ID to search for.

        .PARAMETER WebServiceProxy
            An existing Web Service proxy to use.  Defaults to $SecretServerConfig.Proxy

        .PARAMETER Uri
            Uri for your win auth web service.  Defaults to $SecretServerConfig.Uri.  Overridden by WebServiceProxy parameter

        .EXAMPLE
            Get-SSTemplateField -name "Active Directory*"

        .EXAMPLE
            Get-SSTemplateField -Id 6001

        .EXAMPLE
            Get-SSTemplate -Name Wind* | Get-SSTemplateField

            # Find templates starting with Wind, get fields for these templates

        .FUNCTIONALITY
            Secret Server
    #>
    [CmdletBinding()]
    param(
        [Parameter( Mandatory=$false, 
                    ValueFromPipelineByPropertyName=$true, 
                    ValueFromRemainingArguments=$false, 
                    Position=0)]
        [String]$Id = $null,

        [string[]]$Name = $null,

        [string]$Uri = $SecretServerConfig.Uri,

        [System.Web.Services.Protocols.SoapHttpClientProtocol]$WebServiceProxy = $SecretServerConfig.Proxy,

        [string]$Token = $SecretServerConfig.Token        
    )
    begin {
        if(-not $WebServiceProxy.whoami) {
            Write-Warning "Your SecretServerConfig proxy does not appear connected.  Creating new connection to $uri"
            try {
                $WebServiceProxy = New-WebServiceProxy -uri $Uri -UseDefaultCredential -ErrorAction stop
            }
            catch {
                throw "Error creating proxy for $Uri`: $_"
            }
        }

        #Find all templates, filter on name
        if($Token) {
            $AllTemplates = @( $WebServiceProxy.GetSecretTemplates($Token) )
        }
        else {
            $AllTemplates = @( $WebServiceProxy.GetSecretTemplates() )
        }
        Write-Verbose "Found $($AllTemplates.Count) templates"

        if($AllTemplates.Errors -and $AllTemplates.Errors.Count -gt 0) {
            Write-Error "Secret server returned error $($AllTemplates.Errors | Out-String)"
            return
        }
        $AllTemplates = $AllTemplates.SecretTemplates

        if($Name) {
            $AllTemplates = $AllTemplates | ForEach-Object {
                $ThisName = $_.Name
                foreach($InputName in $Name) {
                    if($Thisname -like $InputName ) { $_ }
                }
            }
        }
        Write-Verbose "Filtered for name to $($AllTemplates.Count) templates"

        if($Id) {
            $AllTemplates  = $AllTemplates | Where-Object {$_.Id -like $Id}
        }
        Write-Verbose "Filtered for id to $($AllTemplates.Count) templates"        
    }
    process {
        Write-Verbose "Searching for Name='$Name', ID='$ID' found $($AllTemplates.Count) templates"
        foreach($Template in $AllTemplates) {
            Write-Verbose "Working on ID $($Template.ID)"
            foreach($Field in $Template.Fields) {
                [pscustomobject]@{
                    PSTypeName = "SecretServer.TemplateField"
                    TemplateId = $Template.ID
                    TemplateName = $Template.Name
                    DisplayName = $Field.DisplayName
                    Id = $Field.Id
                    IsPassword = $Field.IsPassword
                    IsUrl = $Field.IsUrl
                    IsNotes = $Field.IsNotes
                    IsFile = $Field.IsFile
                }
            }
        }
    }
}