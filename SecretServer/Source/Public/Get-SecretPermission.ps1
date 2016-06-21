Function Get-SecretPermission
{
    <#
    .SYNOPSIS
        Get secret permissions from secret server

    .DESCRIPTION
        Get secret permissions from secret server.

        We return one object per access control entry.
        Some properties are hidden by default, use Select-Object or Get-Member to explore.
    
    .PARAMETER SecretId
        SecretId to search for.

    .PARAMETER IncludeDeleted
        Include deleted secrets

    .PARAMETER IncludeRestricted
        Include restricted secrets

    .PARAMETER WebServiceProxy
        An existing Web Service proxy to use.  Defaults to $SecretServerConfig.Proxy

    .PARAMETER Uri
        Uri for your win auth web service.  Defaults to $SecretServerConfig.Uri.  Overridden by WebServiceProxy parameter

    .EXAMPLE
        Get-SecretPermission -Id 5

        #Get Secret permissions for Secret ID 5

    .EXAMPLE
        Get-Secret -SearchTerm "SVC-Webcommander" | Get-SecretPermission

        # Get secret permissions for any results found by the SearchTerm 'SVC-WebCommander'

    .EXAMPLE
        Get-SecretPermission -Id 5 | Select -Property *

        #Get Secret permissions for Secret ID 5, include all properties

    .FUNCTIONALITY
        Secret Server

    #>
    [cmdletbinding()]
    param(

        [Parameter( Mandatory=$false,
                    ValueFromPipelineByPropertyName=$true,
                    ValueFromRemainingArguments=$false,
                    Position=0)]
        [int[]]$SecretId = $null,

        [switch]$IncludeDeleted,

        [switch]$IncludeRestricted,

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

        #Set up a type name an default properties
        #This should be in the module def, but for simplicity of updates, here for now...
            $TypeName = "SecretServer.SecretPermissions"
            $defaultDisplaySet = echo SecretName Name DomainName View Edit Owner
            Update-TypeData -TypeName $TypeName -DefaultDisplayPropertySet $defaultDisplaySet -Force

    }
    Process
    {
        foreach($Id in $SecretId)
        {
            Try
            {
                #If we don't remove this key, it is bound to Get-Secret below...
                if($PSBoundParameters.ContainsKey('SecretId'))
                {
                    $PSBoundParameters.Remove('SecretId') | Out-Null
                }

                $Raw = Get-Secret @PSBoundParameters -As Raw -LoadSettingsAndPermissions -ErrorAction Stop -SecretId $Id
            }
            Catch
            {
                Write-Error "Error obtaining permissions for secret id '$id':`n$_"
                Continue
            }

            if($Raw)
            {

                #Get some initial data...
                $init = [pscustomobject]@{
                    SecretName = $Raw.Name
                    SecretId = $Raw.Id
                    SecretTypeId = $Raw.SecretTypeId
                    CurrentUserHasView = $Raw.SecretPermissions.CurrentUserHasView
                    CurrentUserHasEdit = $Raw.SecretPermissions.CurrentUserHasEdit
                    CurrentUserHasOwner = $Raw.SecretPermissions.CurrentUserHasOwner
                    InheritPermissionsEnabled = $Raw.SecretPermissions.InheritPermissionsEnabled
                    IsChangeToPermissions = $Raw.SecretPermissions.IsChangeToPermissions
                }

                #Now loop through each ACE, merge initial data with ACE data
                $Permissions = $Raw.SecretPermissions.Permissions
                foreach($Permission in $Permissions)
                {
                    $Output = $init | Select -Property *, 
                        @{ label = "Name";       expression = {$Permission.UserOrGroup.Name} },
                        @{ label = "DomainName"; expression = {$Permission.UserOrGroup.DomainName} },
                        @{ label = "IsUser";     expression = {$Permission.UserOrGroup.IsUser} },
                        @{ label = "GroupId";    expression = {$Permission.UserOrGroup.GroupId} },
                        @{ label = "UserId";     expression = {$Permission.UserOrGroup.UserId} },
                        @{ label = "View";       expression = {$Permission.View} },
                        @{ label = "Edit";       expression = {$Permission.Edit} },
                        @{ label = "Owner";      expression = {$Permission.Owner} }

                    #Provide a friendly type name that will inherit the default properties
                        $Output.PSTypeNames.Insert(0,$TypeName)
                        $Output
                } 
            }
        }

    }
}