Function Set-SSSecret
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
        If specified, update to this Password

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

    .PARAMETER WebServiceProxy
        An existing Web Service proxy to use.  Defaults to $SecretServerConfig.Proxy

    .PARAMETER Uri
        Uri for your win auth web service.  Defaults to $SecretServerConfig.Uri.  Overridden by WebServiceProxy parameter
    
    .EXAMPLE
        Get-Secret webcommander | Set-Secret -Notes "Nothing to see here"

        #Get the secret for webcommander, set the notes field to 'nothing to see here'.
        #If multiple results matched webcommander, we would get an error.

    .FUNCTIONALITY
        Secret Server

    #>
    [cmdletbinding()]
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
        [string]$Password,
        [string]$Notes,
        
        [string]$Server,
        [string]$URL,
        [string]$Resource,
        [string]$Machine,
        [string]$Domain,

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

        #Update the properties.  We can loop over some common field names we offer as parameters
            if($SecretName)
            {
                $Secret.Name = $SecretName
            }

            $CommonProps = Echo Username, Password, Notes, Server, URL, Resource, Machine, Domain
            foreach($CommonProp in $CommonProps)
            {
                if($PSBoundParameters.ContainsKey($CommonProp))
                {
                    $Val = $PSBoundParameters[$CommonProp]
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