#Get public and private function definition files.
$Public  = Get-ChildItem $PSScriptRoot\Source\Public\*.ps1 -ErrorAction SilentlyContinue 
$Private = Get-ChildItem $PSScriptRoot\Source\Private\*.ps1 -ErrorAction SilentlyContinue 

#Dot source the files
foreach($import in @($Public + $Private)) {
    try {
        . $import.fullname
    }
    catch {
        Write-Error "Failed to import function $($import.fullname)"
    }
}

#Create / Read config
if(-not (Test-Path -Path "$PSScriptRoot\SecretServer.xml" -ErrorAction SilentlyContinue)) {
    try {
        Write-Warning "Did not find config file $PSScriptRoot\SecretServer.xml, attempting to create"
        [pscustomobject]@{
            Uri = $null
            Token = $null
            ServerInstance = $null
            Database = $null
        } | Export-Clixml -Path "$PSScriptRoot\SecretServer.xml" -Force -ErrorAction Stop
    }
    catch {
        Write-Warning "Failed to create config file $PSScriptRoot\SecretServer.xml: $_"
    }
}
    
#The config contains a serialized proxy, if one exists, not live.  Reconnect it
try {
    #Import the config.  Clear out any legacy references to Proxy in the config file.
    $SecretServerConfig = $null
    $SecretServerConfig = Get-SecretServerConfig -Source "ConfigFile" -ErrorAction Stop | Select -Property * -ExcludeProperty Proxy | Select -Property *, Proxy

    $SSUri = $SecretServerConfig.Uri

    #Connect to SSUri, if it exists
    if($SSUri) {
        try{
            $SecretServerConfig.Proxy = New-SSConnection -Uri $SSUri -ErrorAction stop -Passthru
        }
        catch {
            Write-Warning "Error creating proxy for '$SSUri': $_"
        }
    }
}
catch {   
    Write-Warning "Error reading SecretServer.xml: $_"
}

#Create some aliases, export public functions and the SecretServerConfig variable
$PublicNames = $Public | Select -ExpandProperty BaseName

Export-ModuleMember -Function $PublicNames -Alias * -Variable SecretServerConfig