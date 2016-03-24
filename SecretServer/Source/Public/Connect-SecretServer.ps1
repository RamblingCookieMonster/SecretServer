function Connect-SecretServer {
    <#
    .SYNOPSIS
        Create a connection to secret server

    .DESCRIPTION
        Create a connection to secret server

        Default action updates $SecretServerConfig.Proxy which most functions use as a default

        If you specify a winauthwebservices endpoint, we remove any existing Token from your module configuration.

    .PARAMETER Uri
        Uri to connect to. Defaults to $SecretServerConfig.Uri

    .PARAMETER Credentials
        User credentials to authenticate to SecretServer. Defaults to Get-Credential

    .PARAMETER Radius
        Switch to connect with RADIUS credentials. Prompts for creditials 

    .PARAMETER Organization
        String for Organization, Default to ""

    .PARAMETER Domain
        String for Domain

    .EXAMPLE
        Connect-SecretServerRADIUS
        
        # Prompts for Domain credentials
        # Prompts for RADIUS token/password
        # Create a proxy to the Uri from $SecretServerConfig.Uri
        # Set the $SecretServerConfig.Proxy to this value
        # Set the $SecretServerConfig.Token to generated value

    .EXAMPLE
        $Proxy = New-SSConnection -Uri https://FQDN.TO.SECRETSERVER/winauthwebservices/sswinauthwebservice.asmx -Passthru

        # Create a proxy to the specified uri, pass this through to the $proxy variable
        # This still changes the SecretServerConfig proxy to the resulting proxy
    #>    
    param(
        $Uri="https://pwmanager.corp.athenahealth.com/SecretServer/webservices/SSWebservice.asmx",
        $Credentials=(Get-Credential -Message "Enter Domain Credentials"),
        [switch]$Radius,
        [string]$Organization="",
        [string]$Domain="corp"
    )


    Try
    {
        #Import the config.  Clear out any legacy references to Proxy in the config file.
        $SecretServerConfig = $null
        $SecretServerConfig = Get-SecretServerConfig -Source "ConfigFile" -ErrorAction Stop | Select -Property * -ExcludeProperty Proxy | Select -Property *, Proxy

        $SSUri = $SecretServerConfig.Uri

        #Connect to SSUri, if it exists
        If($SSUri)
        {
            try
            {
                $SecretServerConfig.Proxy = New-SSConnection -Uri $SSUri -ErrorAction stop -Passthru
            }
            catch
            {
                Write-Warning "Error creating proxy for '$SSUri': $_"
            }
        }
    }
    Catch
    {   
        Write-Warning "Error reading $PSScriptRoot\SecretServer_$($env:USERNAME).xml: $_"
    }
    
    $Proxy =  New-WebServiceProxy -Uri $Uri #(Get-SecretServerConfig | Select -ExpandProperty Uri)
    
    if($Radius){
        $RadiusCreds = (Get-Credential -UserName "Radius Password" -Message "Enter Radius Password")
        $Login = ($Proxy.AuthenticateRADIUS($Credentials.UserName,$Credentials.GetNetworkCredential().Password,$Organization,$Domain,"$([string]$RadiusCreds.GetNetworkCredential().Password)"))
        if($Login.Errors){
            Write-Error "Login Failure: $($Login.Errors)"
            break
        }
        else{
            Write-Verbose "Login Successful" -Verbose
        }
        $Token = $Login.Token
        $Credentials = $null
        Set-SecretServerConfig -Token $Token -Uri $Uri
    }
    else{
        $Login = $Proxy.Authenticate($Credentials.UserName, $Credentials.GetNetworkCredential().Password, $Organization, $Domain)
        if($Login.Errors){
            Write-Error "Login Failure: $($Login.Errors)"
            break
        }
        else{
            Write-Verbose "Login Successful" -Verbose
        }
        $Token = $Login.Token
        $Credentials = $null
        Set-SecretServerConfig -Token $Token -Uri $Uri        
    }
}

#publish
New-Alias -Name Connect-SSServer -Value Connect-SecretServer -Force
#endpublish