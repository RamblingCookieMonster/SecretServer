Function Get-Secret
{
    <#
    .SYNOPSIS
        Get details on secrets from secret server

    .DESCRIPTION
        Get details on secrets from secret server.

        Depending on your configuration, the search will generally include other fields (e.g. Notes).
        For this reason, we do not strip out results based on the search term, we leave this to the end user.

    .PARAMETER SearchTerm
        String to search for.  Accepts wildcards as '*'.

    .PARAMETER SecretId
        SecretId to search for.

    .PARAMETER As
        Summary (Default)  Do not return secret details, only return the secret summary.  No audit event triggered
        Credential         Build credential from stored domain (optional), username, password
        PlainText          Return password in ***plain text***
        Raw                Return raw 'secret' object, with settings and permiss
        
    .PARAMETER LoadSettingsAndPermissions
        Load permissions and settings for each secret.  Only applicable for Raw output.
    
    .PARAMETER IncludeDeleted
        Include deleted secrets

    .PARAMETER IncludeRestricted
        Include restricted secrets

    .PARAMETER WebServiceProxy
        An existing Web Service proxy to use.  Defaults to $SecretServerConfig.Proxy

    .PARAMETER Uri
        Uri for your win auth web service.  Defaults to $SecretServerConfig.Uri.  Overridden by WebServiceProxy parameter

    .PARAMETER Token
        Token for your query.  If you do not use Windows authentication, you must request a token.

        See Get-Help Get-SSToken

    .EXAMPLE
        Get-Secret

        #View a summary of all secrets your session account has access to

    .EXAMPLE
        $Credential = ( Get-Secret -SearchTerm "SVC-RemedyProd" -As Credential ).Credential

        # Get secret data for SVC-RemedyProd as a credential object, store it for later use

    .FUNCTIONALITY
        Secret Server

    #>
    [cmdletbinding()]
    param(
        [Parameter( Mandatory=$false,
                    ValueFromPipelineByPropertyName=$true,
                    ValueFromRemainingArguments=$false,
                    Position=0)]
        [string]$SearchTerm = $null,

        [Parameter( Mandatory=$false,
                    ValueFromPipelineByPropertyName=$true,
                    ValueFromRemainingArguments=$false,
                    Position=1)]
        [int]$SecretId = $null,

        [validateset("Credential", "PlainText", "Raw", "Summary")]
        [string]$As = "Summary",

        [switch]$LoadSettingsAndPermissions,

        [switch]$IncludeDeleted,

        [switch]$IncludeRestricted,

        [string]$Uri = $SecretServerConfig.Uri,

        [System.Web.Services.Protocols.SoapHttpClientProtocol]$WebServiceProxy = $SecretServerConfig.Proxy,

        [string]$Token = $SecretServerConfig.Token

    )
    Begin
    {
        Write-Verbose "Working with PSBoundParameters $($PSBoundParameters | Out-String)"
        $WebServiceProxy = Verify-SecretConnection -Proxy $WebServiceProxy -Token $Token


        #If the ID was specified, we need a way to go from secret template ID to secret template name...
        if($SecretId -and $As -ne "Raw")
        {
            $TemplateTable = Get-TemplateTable
        }
    }
    Process
    {

        if(-not $SecretId)
        {
            #Find all passwords we have visibility to
                if($Token)
                {
                    $AllSecrets = @( $WebServiceProxy.SearchSecrets($Token,$SearchTerm,$IncludeDeleted,$IncludeRestricted).SecretSummaries )
                }
                else
                {
                    $AllSecrets = @( $WebServiceProxy.SearchSecrets($SearchTerm,$IncludeDeleted,$IncludeRestricted).SecretSummaries )
                }
        }
        else
        {
            #If IDs were specified, create objects with a SecretId we will pull
                $AllSecrets = $SecretId | ForEach-Object {[pscustomobject]@{SecretId = $_}}
        }

        #Return summaries, if we didn't request more...
        if($As -like "Summary")
        {
            if($SecretId)
            {
                Write-Warning "To see more than the SecretId, use -As Raw, Credential, or Plaintext when getting a secret based on SecretId"
            }
            $AllSecrets
        }
        else
        {
            #Extract the secrets
                foreach($Secret in $AllSecrets)
                {

                    Try
                    {
                        if($Token)
                        {
                            $SecretOutput = $WebServiceProxy.GetSecret($Secret.SecretId,$LoadSettingsAndPermissions, $null)
                        }
                        else
                        {
                            $SecretOutput = $WebServiceProxy.GetSecret($Secret.SecretId,$LoadSettingsAndPermissions, $null)
                        }

                        if($SecretOutput.Errors -and $SecretOutput.Errors.Count -gt 0)
                        {
                            Write-Error "Secret server returned error $($Secret.Errors | Out-String)"
                            continue
                        }
                        $SecretDetail = $SecretOutput.Secret
                    }
                    Catch
                    {
                        Write-Error "Error retrieving secret $($Secret | Out-String)"
                        continue
                    }

                    if($As -like "Raw")
                    {
                        $SecretDetail
                    }
                    else
                    {
                        #Start building up output
                        $Hash = [ordered]@{
                            SecretId = $Secret.SecretId
                            SecretType = $Secret.SecretTypeName
                            SecretName = $Secret.SecretName
                            SecretErrors = $SecretOutput.SecretErrors
                        }

                        #If we obtained by Id, we don't have the same fields above... get them from SecretDetail
                        if($SecretId)
                        {
                            $SecretTypeId = $SecretDetail.SecretTypeId
                            $Hash.SecretId = $SecretDetail.Id
                            $Hash.SecretType = $TemplateTable.$SecretTypeId
                            $Hash.SecretName = $SecretDetail.Name
                        }

                        #Items contains a collection of properties about the secret that can change based on the type of secret
                            foreach($Item in $SecretDetail.Items)
                            {
                                #If they want the credential, we convert to a secure string
                                if($Item.FieldName -like "Password" -and $As -notlike "PlainText")
                                {
                                    if($Item.Value.Length -and $Item.Value.Length -notlike 0)
                                    {
                                        $password = $Item.Value | ConvertTo-SecureString -asPlainText -Force
                                    }
                                    else
                                    {
                                        $password = "Could not access password"
                                    }
                                    $Hash.Add($Item.FieldName, $password)
                                }
                                else
                                {
                                    $Hash.Add($Item.FieldName, $Item.Value)
                                }
                            }

                        #If they want a credential, compose the username, create the credential
                        if($As -like "Credential" -and $Hash.Contains("Password") -and $Hash.Contains("Username"))
                        {
                            if($Hash.Domain)
                            {
                                $User = $Hash.Domain, $Hash.Username -join "\"
                            }
                            elseif($Hash.Machine)
                            {
                                $User = $Hash.Machine, $Hash.Username -join "\"
                            }
                            else
                            {
                                if($Hash.Username -notlike "")
                                {
                                    $User = $Hash.Username
                                }
                                else
                                {
                                    $User = "NONE"
                                }
                            }

                            if($Password -notlike "Could not access password")
                            {
                                $Hash.Credential = New-Object System.Management.Automation.PSCredential($user,$password)
                            }
                            else
                            {
                                $Hash.Credential = $password
                            }
                        }

                        #Output
                            [pscustomobject]$Hash
                    }
                }
        }
    }
}