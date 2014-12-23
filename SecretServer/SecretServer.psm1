#Get public and private function definition files.
    $Public  = Get-ChildItem $PSScriptRoot\*.ps1 -ErrorAction SilentlyContinue 
    $Private = Get-ChildItem $PSScriptRoot\Private\*.ps1 -ErrorAction SilentlyContinue 

#Dot source the files
    Foreach($import in @($Public + $Private))
    {
        Try
        {
            . $import.fullname
        }
        Catch
        {
            Write-Error "Failed to import function $($import.fullname)"
        }
    }

#Create / Read config
    if(-not (Test-Path -Path "$PSScriptRoot\SecretServer.xml" -ErrorAction SilentlyContinue))
    {
        Try
        {
            Write-Warning "Did not find config file $PSScriptRoot\SecretServer.xml, attempting to create"
            [pscustomobject]@{Proxy = $null; Uri = $Null} | Export-Clixml -Path "$PSScriptRoot\SecretServer.xml" -Force -ErrorAction Stop
        }
        Catch
        {
            Write-Warning "Failed to create config file $PSScriptRoot\SecretServer.xml: $_"
        }
    }
    
#The config contains a serialized proxy, if one exists, not live.  Reconnect it
    Try
    {
        #Import the config
        $SecretServerConfig = $null
        $SecretServerConfig = Get-SSSecretServerConfig -ErrorAction Stop

        #If a proxy is defined, create the proxy
        $SSUri = $SecretServerConfig.Proxy.url
        
        #Rehydrate the proxy, if one existed...
        if($SSUri)
        {
            try
            {
                $SecretServerConfig.Proxy = New-SSConnection -Uri $SSUri -ErrorAction stop -Passthru
            }
            catch
            {
                Write-Warning "Error rehydrating proxy for '$SSUri': $_"
            }
        }
    }
    Catch
    {   
        Write-Warning "Error reading SecretServer.xml: $_"
    }

#Create some aliases, export public functions and the SecretServerConfig variable
    New-Alias -Name "Get-Secret" -Value "Get-SSSecret" -Force
    New-Alias -Name "Set-Secret" -Value "Set-SSSecret" -Force
    New-Alias -Name "New-Secret" -Value "New-Secret" -Force
    New-Alias -Name "Get-SecretServerConfig" -Value "Get-SSSecretServerConfig" -Force
    New-Alias -Name "Set-SecretServerConfig" -Value "Set-SSSecretServerConfig" -Force

    Export-ModuleMember -Function $($Public | Select -ExpandProperty BaseName) -Alias * -Variable SecretServerConfig