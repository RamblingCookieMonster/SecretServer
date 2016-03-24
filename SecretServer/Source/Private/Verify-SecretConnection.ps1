#Return proxy if it is connected.  Test with whoami method
function Verify-SecretConnection {
    [cmdletbinding()]
    param(
        $Proxy,
        $Token
    )
    
    if($Token -notlike "")
    {
        $Result = $Proxy.whoami($Token)
        if(@($Result.Errors).count -gt 0)
        {
            throw "Not connected: $($Result.errors | out-string)`nuse New-SSToken to generate a token"
        }
        else
        {
            Write-Verbose "Proxy with token"
            $Proxy
        }
    }
    else
    {

        if(-not $Proxy.whoami)
        {
            Write-Warning "Your proxy does not appear connected.  Creating new connection to $($Proxy.url)"
            try
            {
                New-WebServiceProxy -uri $Proxy.url -UseDefaultCredential -ErrorAction stop
            }
            catch
            {
                Throw "Error creating proxy for $Uri`: $_"
            }
        }
        else
        {
            Write-Verbose "Proxy without token"
            $Proxy
        }
    }
}