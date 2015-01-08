Function Get-SSUser
{
    <#
    .SYNOPSIS
        Get secret users from secret server database

    .DESCRIPTION
        Get secret users from secret server database

        This command requires privileges on the Secret Server database.
        Given the sensitivity of this data, consider exposing this command through delegated constrained endpoints, perhaps through JitJea
        Some properties are hidden by default, use Select-Object or Get-Member to explore.
    
    .PARAMETER Username
        Username to search for.  Accepts wildcards as * or %

    .PARAMETER UserId
        UserId to search for.  Accepts wildcards as * or %

    .PARAMETER DisplayName
        DisplayName to search for.  Accepts wildcards as * or %

    .PARAMETER EmailAddress
        EmailAddress to search for.  Accepts wildcards as * or %

    .PARAMETER Credential
        Credential for SQL authentication to Secret Server database.  If this is not specified, integrated Windows Authentication is used.

    .PARAMETER LogicalJoin
        Parameters will be joined with AND or OR

    .PARAMETER DefaultProperties
        Properties to display in the default output

        Default: "UserId", "UserName", "DisplayName", "LastLogin", "Created", "Enabled", "EmailAddress"

    .PARAMETER ServerInstance
        SQL Instance hosting the Secret Server database.  Defaults to $SecretServerConfig.ServerInstance

    .PARAMETER Database
        SQL Database for Secret Server.  Defaults to $SecretServerConfig.Database

    .EXAMPLE
        Get-SSUser -UserName cookie*

        #Get Secret Server users with name starting 'cookie'.  Use database and ServerInstance configured in $SecretServerConfig via Set-SecretServerConfig

    .EXAMPLE 
        Get-SSUser -DisplayName *monster* -DefaultProperties UserId, DisplayName -Credential $SQLCred -ServerInstance SecretServerSQL -Database SecretServer
        
        #Connect to SecretServer database on SecretServerSQL instance, using SQL account credentials in $SQLCred.
        #Show UserId and DisplayName for users with a displayname like %monster%

    .FUNCTIONALITY
        Secret Server
    #>
    [cmdletbinding()]
    Param(
        [string]$UserName,
        [string]$UserId,
        [string]$DisplayName,
        [string]$EmailAddress,

        [string][validateset("OR","AND")]$LogicalJoin = "AND",
        [string[]]$DefaultProperties = @("UserId", "UserName", "DisplayName", "LastLogin", "Created", "Enabled", "EmailAddress"),
        [System.Management.Automation.PSCredential]$Credential,
        [string]$ServerInstance = $SecretServerConfig.ServerInstance,
        [string]$Database = $SecretServerConfig.Database
    )

    #Give a friendly type name, set default properties
    $TypeName = "SecretServer.User"
    Update-TypeData -TypeName $TypeName -DefaultDisplayPropertySet $DefaultProperties -Force

    #common parameters for SQL queries
    $params = @{
        ServerInstance = $ServerInstance
        Database = $Database
        Credential = $Credential
    }

    $UserQuery = "SELECT * FROM tbUser WHERE 1=1 "
    $JoinQuery = @()
    $SQLParameters = @{}
    $SQLParamKeys = echo UserName, UserId, DisplayName, EmailAddress

    foreach($SQLParamKey in $SQLParamKeys)
    {
        if($PSBoundParameters.ContainsKey($SQLParamKey))
        {
            $JoinQuery += "$SQLParamKey LIKE @$SQLParamKey"
            $SQLParameters.$SQLParamKey = $PSBoundParameters.$SQLParamKey.Replace('*','%')
        }
    }

    if($JoinQuery.count -gt 0)
    {
        $UserQuery = "$UserQuery AND ( $($JoinQuery -join " $LogicalJoin ") )"
    }

    Write-Verbose "Query:`n$($UserQuery | Out-String)`n`nSQLParams:`n$($SQLParameters | Out-String)"
    
    Try
    {
        $Results = @( Invoke-Sqlcmd2 @params -Query $UserQuery -SqlParameters $SQLParameters -as PSObject)
        Foreach($Result in $Results)
        {
            #Provide a friendly type name that will inherit the default properties
            $Result.PSTypeNames.Insert(0,$TypeName)
            $Result
        }
    }
    Catch
    {
        Throw $_
    }
}