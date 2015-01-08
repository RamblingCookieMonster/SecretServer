Function Get-SSFolderPermission
{
    <#
    .SYNOPSIS
        Get secret folder permissions from secret server database

    .DESCRIPTION
        Get secret folder permissions from secret server database

        This command requires privileges on the Secret Server database.
        Given the sensitivity of this data, consider exposing this command through delegated constrained endpoints, perhaps through JitJea
    
    .PARAMETER FolderPath
        FolderPath to search for.  Accepts wildcards as * or %

    .PARAMETER InheritPermissions
        Whether permissions are inherited.  Yes or no.

    .PARAMETER Principal
        User or group to search for.  Accepts wildcards as * or %

    .PARAMETER Permissions
        Specific access to search for.  View, Edit, or Owner.

    .PARAMETER Credential
        Credential for SQL authentication to Secret Server database.  If this is not specified, integrated Windows Authentication is used.

    .PARAMETER ServerInstance
        SQL Instance hosting the Secret Server database.  Defaults to $SecretServerConfig.ServerInstance

    .PARAMETER Database
        SQL Database for Secret Server.  Defaults to $SecretServerConfig.Database

    .EXAMPLE
        Get-SSFolderPermission -Principal '*support* -Permissions View

        #Get Secret Server folder permissions for groups or users matching 'Support', with view or greater permissions.  Use database and ServerInstance configured in $SecretServerConfig via Set-SecretServerConfig

    .EXAMPLE 
        Get-SSFolderPermission '*High Privilege*' -Credential $SQLCred -ServerInstance SecretServerSQL -Database SecretServer
        
        #Connect to SecretServer database on SecretServerSQL instance, using SQL account credentials in $SQLCred.
        #Show Folder Permissions to any folder with path matching 'High Privilege'

    .FUNCTIONALITY
        Secret Server
    #>
    [cmdletbinding()]
    Param(
        [string]$FolderPath,
        [validateset("yes","no")][string]$InheritPermissions,
        [string]$Principal,
        [validateset("View","Edit","Owner")]
        [string[]]$Permissions,
        [string]$UserId,

        [System.Management.Automation.PSCredential]$Credential,
        [string]$ServerInstance = $SecretServerConfig.ServerInstance,
        [string]$Database = $SecretServerConfig.Database
    )

    #Build up the query
    $JoinQuery = @()
    $SQLParameters = @{}
    $SQLParamKeys = echo FolderPath, InheritPermissions, Principal, Permissions

    foreach($SQLParamKey in $SQLParamKeys)
    {
        if($PSBoundParameters.ContainsKey($SQLParamKey))
        {
            $val = $PSBoundParameters.$SQLParamKey
            switch($SQLParamKey)
            {
                'InheritPermissions'
                {
                    $JoinQuery += "[Inherit Permissions] LIKE @$SQLParamKey"
                    $SQLParameters.$SQLParamKey = $PSBoundParameters.$SQLParamKey
                }
                'Principal'
                {
                    $JoinQuery += "[DisplayName] LIKE @$SQLParamKey"
                    $SQLParameters.$SQLParamKey = $PSBoundParameters.$SQLParamKey.Replace('*','%')
                }
                'Permissions'
                {
                    $count = 0
                    foreach($Perm in $Permissions)
                    {
                        $JoinQuery += "[$SQLParamKey] LIKE @$SQLParamKey$Count"
                        $SQLParameters."$SQLParamKey$Count" = "%$($val[$count])%"
                        $Count++
                    }
                }
                'FolderPath'
                {
                    $JoinQuery += "[$SQLParamKey] LIKE @$SQLParamKey"
                    $SQLParameters.$SQLParamKey = $PSBoundParameters.$SQLParamKey.Replace('*','%')
                }
            }
        }
    }

    $Where = $null
    if($JoinQuery.count -gt 0)
    {
        $Where = " AND $($JoinQuery -join " AND ")"
    }

    $Query = "
        SELECT	
	        fp.FolderPath,
	        gfp.[Inherit Permissions] AS [InheritPermissions],
	        gdn.[DisplayName] AS [Principal],
	        gfp.[Permissions],
            gdn.[GroupId]
        FROM  vGroupFolderPermissions gfp WITH (NOLOCK)
	        INNER JOIN vFolderPath fp WITH (NOLOCK)
		        ON fp.FolderId = gfp.FolderId
	        INNER JOIN vGroupDisplayName gdn WITH (NOLOCK)
		        ON gdn.GroupId = gfp.GroupId
        WHERE
	        gfp.OrganizationId = 1 $Where
        ORDER BY 1,2,3,4
        OPTION (HASH JOIN)"

    Write-Verbose "Query:`n$($Query | Out-String)`n`nSQLParams:`n$($SQLParameters | Out-String)"


#common parameters for SQL queries
    $SqlCmdParams = @{
        ServerInstance = $ServerInstance
        Database = $Database
        As = 'PSObject'
        Query = $Query
    }

    If($Credential)
    {
        $SqlCmdParams.Credential = $Credential
    }
    If($SQLParameters.Keys.Count -gt 0)
    {
        $SqlCmdParams.SQLParameters = $SQLParameters
    }

    Invoke-Sqlcmd2 @SqlCmdParams | Foreach {
        $Permissions = $_.Permissions -split "/"
        [pscustomobject]@{
            FolderPath = $_.FolderPath
            InheritPermissions = $_.InheritPermissions
            Principal = $_.Principal
            View = $Permissions -contains "View"
            Edit = $Permissions -contains "Edit"
            Owner = $Permissions -contains "Owner"
            Permissions = $_.Permissions
            GroupId = $_.GroupId
        }
    }

}