Function Set-Secret
{
    <#
    .SYNOPSIS
        Set details on secrets from secret server.

    .DESCRIPTION
        Set details on secrets from secret server.

        If the specified SearchTerm and SearchID find more than a single Secret, we throw an error

    .PARAMETER SearchTerm
        String to search for.  Accepts wildcards as '*'.

    .PARAMETER SecretId
        SecretId to search for.

    .PARAMETER SecretName
        If specified, update to this Secret Name

    .PARAMETER Username
        If specified, update to this username

    .PARAMETER Password
        If specified, update to this Password.

        This takes a secure string, not a string

    .PARAMETER Notes
        If specified, update to this Notes

    .PARAMETER Server
        If specified, update to this Server

    .PARAMETER URL
        If specified, update to this URL

    .PARAMETER Resource
        If specified, update to this Resource

    .PARAMETER Machine
        If specified, update to this Machine

    .PARAMETER Domain
        If specified, update to this Domain

    .PARAMETER Force
        If specified, suppress prompt for confirmation

    .PARAMETER WebServiceProxy
        An existing Web Service proxy to use.  Defaults to $SecretServerConfig.Proxy

    .PARAMETER Uri
        Uri for your win auth web service.  Defaults to $SecretServerConfig.Uri.  Overridden by WebServiceProxy parameter

    .EXAMPLE
        Get-Secret webcommander | Set-Secret -Notes "Nothing to see here"

        #Get the secret for webcommander, set the notes field to 'nothing to see here'.
        #If multiple results matched webcommander, we would get an error.

    .EXAMPLE
        
        #Get the password we will pass in.  We need a secure string.  There are many ways to do this...
        $Credential = Get-Credential -username none -message 'Enter a password'
        
        #Change the secret password for secret 5
        Set-Secret -SecretId 5 -Password $Credential.Password

    .FUNCTIONALITY
        Secret Server

    #>
    [cmdletbinding(SupportsShouldProcess=$true, ConfirmImpact="Medium")]
    param(
        [Parameter( Mandatory=$false, 
                    ValueFromPipelineByPropertyName=$true, 
                    ValueFromRemainingArguments=$false, 
                    Position=0)]
        [int]$SecretId,

        [Parameter( Mandatory=$false, 
                    ValueFromPipelineByPropertyName=$true, 
                    ValueFromRemainingArguments=$false, 
                    Position=1)]
        [string]$SearchTerm = $null,

        [String]$SecretName,
        [string]$Username,
        [System.Security.SecureString]$Password,
        [string]$Notes,
        
        [string]$Server,
        [string]$URL,
        [string]$Resource,
        [string]$Machine,
        [string]$Domain,

        [switch]$Force,

        [string]$Uri = $SecretServerConfig.Uri,
        [System.Web.Services.Protocols.SoapHttpClientProtocol]$WebServiceProxy = $SecretServerConfig.Proxy
    )
    Begin
    {
        $RejectAll = $false
        $ConfirmAll = $false

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

        #Find all passwords we have visibility to
            $SecretSummary = @( $WebServiceProxy.SearchSecrets($SearchTerm,$false,$false).SecretSummaries)

            if($SecretId)
            {
                $SecretSummary = @( $SecretSummary | Where-Object {$_.SecretId -like $SecretId} )
            }
    
            if($SecretSummary.count -ne 1)
            {
                Throw "To edit a secret, you must specify a searchterm or secret ID that returns only a single secret to modify: $($AllSecrets.count) secrets found"
            }

        #Get the secret
            try
            {
                $Secret = $WebServiceProxy.GetSecret($SecretSummary.SecretId,$false, $null) | Select -ExpandProperty Secret -ErrorAction stop
            }
            catch
            {
                Throw "Error obtaining secret: $_"
            }
            
            #These are properties that might be set...
            $CommonProps = Echo Username, Password, Notes, Server, URL, Resource, Machine, Domain
            
            #Update the properties.  We can loop over some common field names we offer as parameters
            if($PSCmdlet.ShouldProcess( "Processed the Secret '$($Secret | Out-String)'",
                                        "Process the Secret '$($Secret | Out-String)'?",
                                        "Processing Secret" ))
            {
                $NewSecretPropsString = $PSBoundParameters.GetEnumerator() | Where-Object {$CommonProps -contains $_.Key} | Format-Table -AutoSize | Out-String

                if($Force -Or $PSCmdlet.ShouldContinue("Are you REALLY sure you want to change existing`n'$($Secret | Out-String)`n with changes:`n$NewSecretPropsString'?", "Processing '$($Secret | Out-String)'", [ref]$ConfirmAll, [ref]$RejectAll)) {
                    if($SecretName)
                    {
                        $Secret.Name = $SecretName
                    }

                    foreach($CommonProp in $CommonProps)
                    {
                        if($PSBoundParameters.ContainsKey($CommonProp))
                        {
                            #Get value for this field... convert password to string
                            if($CommonProp -eq "Password")
                            {
                                Try
                                {
                                    $Val = Convert-SecStrToStr -secstr $PSBoundParameters[$CommonProp] -ErrorAction stop
                                }
                                Catch
                                {
                                    Throw "$_"
                                }
                            }
                            else
                            {
                                $Val = $PSBoundParameters[$CommonProp]
                            }

                            if($Secret.Items.FieldName -contains $CommonProp)
                            {
                                $Secret.Items | ForEach-Object {
                                    if($_.FieldName -like $CommonProp)
                                    {
                                        Write-Verbose "Changing $CommonProp from '$($_.Value)' to '$Val'"
                                        $_.Value = $Val
                                    }
                                }
                            }
                            else
                            {
                                Write-Error "You specified parameter '$CommonProp'='$Val'. This property does not exist on this secret."
                            }
                        }

                    }
        
                    $WebServiceProxy.UpdateSecret($Secret)
                }
            }
    }
}