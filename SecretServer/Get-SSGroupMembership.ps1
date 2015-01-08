Function Get-SSGroupMembership
{
    <#
    .SYNOPSIS
        Get secret server group membership from database

    .DESCRIPTION
        Get secret server group membership from database

        This command requires privileges on the Secret Server database.
        Given the sensitivity of this data, consider exposing this command through delegated constrained endpoints, perhaps through JitJea
    
    .PARAMETER UserName
        UserName to search for.  Accepts wildcards as * or %

    .PARAMETER UserId
        UserId to search for.  Accepts wildcards as * or %

    .PARAMETER GroupName
        GroupName to search for.  Accepts wildcards as * or %

    .PARAMETER GroupId
        GroupId to search for.  Accepts wildcards as * or %

    .PARAMETER Credential
        Credential for SQL authentication to Secret Server database.  If this is not specified, integrated Windows Authentication is used.

    .PARAMETER ServerInstance
        SQL Instance hosting the Secret Server database.  Defaults to $SecretServerConfig.ServerInstance

    .PARAMETER Database
        SQL Database for Secret Server.  Defaults to $SecretServerConfig.Database

    .EXAMPLE
        Get-SSGroupMembership -UserName cmonster -GroupName *server*

        #Get group membership for cmonster, where the group is like *server*.  Use database and ServerInstance configured in $SecretServerConfig via Set-SecretServerConfig

    .EXAMPLE
        Get-SSGroupMembership -UserName cmonster | Select -ExpandProperty GroupName

        #Get all group membership for cmonster, expand the group name.  Use database and ServerInstance configured in $SecretServerConfig via Set-SecretServerConfig

    .EXAMPLE 
        Get-SSGroupMembership -GroupId 3 -Credential $SQLCred -ServerInstance SecretServerSQL -Database SecretServer |
            Select -ExpandProperty UserName
        
        #Connect to SecretServer database on SecretServerSQL instance, using SQL account credentials in $SQLCred.
        #Get users in group 3, list the UserName only

    .FUNCTIONALITY
        Secret Server
    #>
    [cmdletbinding()]
    Param(
        [string]$UserName,
        [string]$UserId,
        [string]$GroupName,
        [string]$GroupId,

        [System.Management.Automation.PSCredential]$Credential,
        [string]$ServerInstance = $SecretServerConfig.ServerInstance,
        [string]$Database = $SecretServerConfig.Database
    )

    #Set up the where statement and sql parameters
        $JoinQuery = @()
        $SQLParameters = @{}
        $SQLParamKeys = echo UserName, UserId, GroupName, GroupId

        foreach($SQLParamKey in $SQLParamKeys)
        {
            if($PSBoundParameters.ContainsKey($SQLParamKey))
            {
                $col = $SQLParamKey
                if($col -like 'GroupId'){$col = 'g.GroupId'}
                $JoinQuery += "$col LIKE @$SQLParamKey"
                $SQLParameters.$SQLParamKey = $PSBoundParameters.$SQLParamKey.Replace('*','%')
            }
        }

        if($JoinQuery.count -gt 0)
        {
            $Where = " AND ( $($JoinQuery -join " AND ") )"
        }

    $Query = "
		SELECT	
			gdn.DisplayName AS [GroupName],
            gdn.GroupId,
            u.UserName,
            u.UserId,
			CASE g.Active 
			WHEN 1 THEN 'Yes'
			WHEN 0 THEN 'No'
			END AS [IsGroupActive]
		FROM tbGroup g WITH (NOLOCK)
			INNER JOIN vGroupDisplayName gdn WITH (NOLOCK)
				ON g.GroupId = gdn.GroupId
			LEFT JOIN tbUserGroup ug WITH (NOLOCK)
				ON g.GroupId = ug.GroupId
			LEFT JOIN tbUser u WITH (NOLOCK)
				ON ug.UserId = u.UserId 
				AND u.OrganizationId = 1
			LEFT JOIN vUserDisplayName udn WITH (NOLOCK)
				ON u.UserId = udn.UserId 
		WHERE
			(u.[Enabled] = 1 OR u.UserId IS NULL)
			AND
			g.IsPersonal = 0
			AND
			g.OrganizationId = 1
			AND
			g.SystemGroup = 0
            $WHERE
		ORDER BY
			[GroupName] ASC ,2 
    "

    #Define Invoke-SqlCmd2 params
        $SqlCmdParams = @{
            ServerInstance = $ServerInstance
            Database = $Database
            Query = $Query
            As = 'PSObject'
        }
        if($Credential){
            $SqlCmdParams.Credential = $Credential
        }
        
        if($SQLParameters.Keys.Count -gt 0)
        {
            $SqlCmdParams.SQLParameters = $SQLParameters
        }
    
    #Give some final verbose output
    Write-Verbose "Query:`n$($Query | Out-String)`n`SQlParameters:`n$($SQlParameters | Out-String)"

    Invoke-Sqlcmd2 @SqlCmdParams
}