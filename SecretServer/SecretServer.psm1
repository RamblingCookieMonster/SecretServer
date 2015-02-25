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
            [pscustomobject]@{
                Uri = $null
                Token = $null
                ServerInstance = $null
                Database = $null
            } | Export-Clixml -Path "$PSScriptRoot\SecretServer.xml" -Force -ErrorAction Stop
        }
        Catch
        {
            Write-Warning "Failed to create config file $PSScriptRoot\SecretServer.xml: $_"
        }
    }
    
#The config contains a serialized proxy, if one exists, not live.  Reconnect it
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
        Write-Warning "Error reading SecretServer.xml: $_"
    }

#Create some aliases, export public functions and the SecretServerConfig variable
    $PublicNames = $Public | Select -ExpandProperty BaseName
    
    #We create aliases for functions starting with 'Secret', prepending SS for consistency.  Other functions already start with SS
    foreach($Func in $PublicNames)
    {
        if($Func -match "-Secret")
        {
            $FuncNew = $Func.Replace("-", "-SS")
            New-Alias -Name $FuncNew -Value $Func -Force
        }
    }

    Export-ModuleMember -Function $PublicNames -Alias * -Variable SecretServerConfig