Function Get-SecretActivity
{
    <#
    .SYNOPSIS
        Get secret activity from secret server database

    .DESCRIPTION
        Get secret activity from secret server database

        This command requires privileges on the Secret Server database.
        Given the sensitivity of this data, consider exposing this command through delegated constrained endpoints, perhaps through JitJea
    
    .PARAMETER UserName
        UserName to search for.  Accepts wildcards as * or %

    .PARAMETER UserId
        UserId to search for.  Accepts wildcards as * or %

    .PARAMETER SecretName
        SecretName to search for.  Accepts wildcards as * or %

    .PARAMETER Action
        Action to search for.  Accepts wildcards as * or %

    .PARAMETER IPAddress
        IPAddress to search for.  Accepts wildcards as * or %

    .PARAMETER StartDate
        Search for activity after this start date

    .PARAMETER EndDate
        Search for activity before this end date

    .PARAMETER Credential
        Credential for SQL authentication to Secret Server database.  If this is not specified, integrated Windows Authentication is used.

    .PARAMETER ServerInstance
        SQL Instance hosting the Secret Server database.  Defaults to $SecretServerConfig.ServerInstance

    .PARAMETER Database
        SQL Database for Secret Server.  Defaults to $SecretServerConfig.Database

    .EXAMPLE
        Get-SecretActivity -SecretName SQL-DB-2014* -Action WebServiceView

        #Get Secret activity for secrets with name like SQL-DB-2014*, Showing only WebServiceView actions.  Use database and ServerInstance configured in $SecretServerConfig via Set-SecretServerConfig

    .EXAMPLE 
        Get-SecretActivity -UserName cmonster -StartDate $(get-date).adddays(-1) -Credential $SQLCred -ServerInstance SecretServerSQL -Database SecretServer
        
        #Connect to SecretServer database on SecretServerSQL instance, using SQL account credentials in $SQLCred.
        #Show secret activity for cmonster over the past day

    .FUNCTIONALITY
        Secret Server
    #>
    [cmdletbinding()]
    Param(
        [string]$UserName,
        [string]$UserId,
        [string]$SecretName,
        [datetime]$StartDate = (Get-Date).AddDays(-7),
        [datetime]$EndDate,
        [string[]]$Action,
        [string]$IPAddress,

        [System.Management.Automation.PSCredential]$Credential,
        [string]$ServerInstance = $SecretServerConfig.ServerInstance,
        [string]$Database = $SecretServerConfig.Database
    )

    #Set up the where statement and sql parameters
        $JoinQuery = @("1=1")
        $SQLParameters = @{}
        $SQLParamKeys = echo UserName, UserId, SecretName, IPAddress, StartDate, EndDate

        if($PSBoundParameters.ContainsKey('StartDate'))
        {
                $JoinQuery += "[DateRecorded] >= @StartDate"
        }
        if($PSBoundParameters.ContainsKey('EndDate'))
        {
                $JoinQuery += "[DateRecorded] <= @EndDate"
        }
        if($PSBoundParameters.ContainsKey('Action'))
        {
            $Count = 0
            $PartialWhere = "("
            $PartialWhere += $(
                foreach($Act in $Action)
                {
                    "[Action] LIKE @Action$Count"
                    $SQLParameters."Action$Count" = $Action[$Count].Replace('*','%')
                    $Count++
                }
            ) -join " OR "
            $JoinQuery += "$PartialWhere)"
        }

        foreach($SQLParamKey in $SQLParamKeys)
        {
            if($PSBoundParameters.ContainsKey($SQLParamKey))
            {
                $Val = $PSBoundParameters.$SQLParamKey
                If($Val -is [string])
                {
                    $Val = $Val.Replace('*','%')
                    $JoinQuery += "[$SQLParamKey] LIKE @$SQLParamKey"
                }

                $SQLParameters.$SQLParamKey = $Val
            }
        }

        $Where = $JoinQuery -join " AND "

    #The query
        $Query = "
		    SELECT 
			    a.DateRecorded,
			    upn.DisplayName,
                u.UserId,
                u.UserName,
			    fp.FolderPath,
			    s.SecretName,
			    a.Action,
			    a.Notes,
			    a.IPAddress
		    FROM tbauditsecret a WITH (NOLOCK)
			    INNER JOIN tbuser u WITH (NOLOCK)
				    ON u.userid = a.userid
				    AND u.OrganizationId = 1
			    INNER JOIN vUserDisplayName upn WITH (NOLOCK)
				    ON u.UserId = upn.UserId
			    INNER JOIN tbsecret s WITH (NOLOCK)
				    ON s.secretid = a.secretid 
			    LEFT JOIN vFolderPath fp WITH (NOLOCK)
				    ON s.FolderId = fp.FolderId
		    WHERE $Where
		    ORDER BY 
			    1 DESC, 2, 3, 4, 5, 6, 7
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