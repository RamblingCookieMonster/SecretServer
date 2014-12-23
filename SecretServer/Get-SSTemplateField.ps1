Function Get-SSTemplateField
{
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
    [cmdletbinding()]
    param(
        [Parameter( Mandatory=$false, 
                    ValueFromPipelineByPropertyName=$true, 
                    ValueFromRemainingArguments=$false, 
                    Position=0)]
        [String]$Id = '*',

        [string[]]$Name = $null,

        [string]$Uri = $SecretServerConfig.Uri,

        [System.Web.Services.Protocols.SoapHttpClientProtocol]$WebServiceProxy = $SecretServerConfig.Proxy

    )
    Begin
    {

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
    }
    Process
    {
        Write-Verbose "Working on ID $ID"
        foreach($TemplateID in $ID)
        {
            $AllTemplates | where {$_.Id -like $TemplateID} | ForEach-Object {
                foreach($Field in $_.Fields)
                {
                    [pscustomobject]@{
                        TemplateId = $_.ID
                        TemplateName = $_.Name
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
}