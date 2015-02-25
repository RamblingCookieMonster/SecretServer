Function New-Secret
{
    <#
    .SYNOPSIS
        Create a new secret in secret server

    .DESCRIPTION
        Create a new secret in secret server

        This code only handles a pre-specified set of Secret templates defined in SecretType.

        Any fields not included in the parameters here are set to null

    .PARAMETER SecretType
        Secret Template to use

    .PARAMETER SecretName
        Secret Name

    .PARAMETER Domain
        For AD template, domain

    .PARAMETER Resource
        For Password template, resource
    
    .PARAMETER Server
        For SQL account template, Server

    .PARAMETER URL
        For Web template, URL

    .PARAMETER Machine
        For Windows template, Machine

    .PARAMETER Username
        Username

    .PARAMETER Password
        Password

        This takes a secure string, not a string

    .PARAMETER Notes
        Notes

    .PARAMETER FolderID
        Specific ID for the folder to create the secret within

    .PARAMETER FolderPath
        Folder path for the folder to create the secret within.  Accepts '*' as wildcards, but must return a single folder. 

    .PARAMETER Force
        If specified, suppress prompt for confirmation

    .PARAMETER WebServiceProxy
        An existing Web Service proxy to use.  Defaults to $SecretServerConfig.Proxy

    .PARAMETER Uri
        Uri for your win auth web service.  Defaults to $SecretServerConfig.Uri.  Overridden by WebServiceProxy parameter

    .PARAMETER Token
        Token for your query.  If you do not use Windows authentication, you must request a token.

        See Get-Help Get-SSToken

    .EXAMPLE
        New-Secret -SecretType 'Active Directory Account' -Domain Contoso.com -Username SQLServiceX -password $Credential.Password -notes "SQL Service account for SQLServerX\Instance" -FolderPath "*SQL Service"

        Create an active directory account for Contoso.com, user SQLServiceX, include notes that point to the SQL instance running it, specify a folder path matching SQL Service. 

    .EXAMPLE
        
        $SecureString = Read-Host -AsSecureString -Prompt "Enter password"
        New-Secret -SecretType 'SQL Server Account' -Server ServerNameX -Username sa -Password $SecureString -FolderID 25

        Create a secure string we will pass in for the password.
        Create a SQL account secret for the sa login on instance ServerNameX, put it in folder 25 (DBA).

    .FUNCTIONALITY
        Secret Server

    #>
    [cmdletbinding(DefaultParameterSetName = "AD", SupportsShouldProcess=$true, ConfirmImpact="Medium")]
    param(
        [parameter( Mandatory = $True )]
        [validateset("Active Directory Account", "SQL Server Account", "Web Password", "Windows Account", "Password")]
        [string]$SecretType,

        [parameter( ParameterSetName = "AD",
                    Mandatory = $True )]
        [string]$Domain,

        [parameter( ParameterSetName = "PW",
                    Mandatory = $True )]
        [string]$Resource,

        [parameter( ParameterSetName = "SQL",
                    Mandatory = $True )]
        [string]$Server,

        [parameter( ParameterSetName = "WEB",
                    Mandatory = $True )]
        [string]$URL,
              
        [parameter( ParameterSetName = "WIN",
                    Mandatory = $True )]
        [string]$Machine,       

        [parameter(ParameterSetName = "AD", Mandatory = $True )]
        [parameter(ParameterSetName = "PW", Mandatory = $False)]
        [parameter(ParameterSetName = "SQL", Mandatory = $True )]
        [parameter(ParameterSetName = "WEB", Mandatory = $True )]
        [parameter(ParameterSetName = "WIN", Mandatory = $True )]
        [string]$Username,

        [System.Security.SecureString]$Password = (Read-Host -AsSecureString -Prompt "Password for this secret:"),
        
        [string]$Notes,

        [int]$FolderID,

        [string]$FolderPath,

        [parameter(ParameterSetName = "PW", Mandatory = $True)]
        [parameter(ParameterSetName = "WEB", Mandatory = $True )]
        [parameter(ParameterSetName = "AD", Mandatory = $False )]
        [parameter(ParameterSetName = "SQL", Mandatory = $False )]
        [parameter(ParameterSetName = "WIN", Mandatory = $False )]
        [string]$SecretName,
        
        [switch]$Force,

        [string]$Uri = $SecretServerConfig.Uri,

        [System.Web.Services.Protocols.SoapHttpClientProtocol]$WebServiceProxy = $SecretServerConfig.Proxy,

        [string]$Token = $SecretServerConfig.Token
    )

    $RejectAll = $false
    $ConfirmAll = $false

    $WebServiceProxy = Verify-SecretConnection -Proxy $WebServiceProxy -Token $Token

    Write-Verbose "PSBoundParameters:`n$($PSBoundParameters | Out-String)`nParameterSetName: $($PSCmdlet.ParameterSetName)"

    $InputHash = @{
        Username = $Username
        Password = $Password
        Notes = $Notes
    }

    $SecretTypeParams = @{
        AD = "Active Directory Account"
        SQL = "SQL Server Account"
        WEB = "Web Password"
        WIN = "Windows Account"
        PW = "Password"
    }

    if($SecretType -notlike $SecretTypeParams.$($PSCmdlet.ParameterSetName))
    {
        Throw "Invalid secret type.  For more information, run   Get-Help New-Secret -Full"
    }
    
    #Verify the template and get the ID
        $Template = @( Get-SSTemplate -Name $SecretType )
        if($Template.Count -ne 1)
        {
            Throw "Error finding template for $SecretType.  Template results:`n$( $Template | Format-List -Property * -Force | Out-String )"
        }
        $SecretTypeId = $Template.ID

    #Verify the folder and get the ID
        $FolderHash = @{}
        if($FolderID)
        {
            $FolderHash.ID = $FolderID
        }
        if($FolderPath)
        {
            $FolderHash.FolderPath = $FolderPath
        }

        $Folder = @( Get-SSFolder @FolderHash )
        if($Folder.Count -ne 1)
        {
            Throw "Error finding folder for $FolderHash.  Folder results:`n$( $Folder | Format-List -Property * -Force | Out-String ).  Valid folders: $(Get-SSFolder | ft -AutoSize | Out-String)"
        }
        $FolderId = $Folder.ID

    try
    {

        switch($PSCmdlet.ParameterSetName)
        {
            'AD'
            {
                $InputHash.Domain = $Domain.ToLower()
            
                #Format is domain\user
                $ShortDomain = $InputHash.Domain.split(".")[0].ToLower()
                $SecretName = "$ShortDomain\$($InputHash.Username)"
            }

            'PW'
            {
                $InputHash.Resource = $Resource
            }

            'SQL'
            {
                $Server = $Server.ToLower()

                #format is instance::user.  We use :: as instances may have a \ and would look odd.
                $InputHash.Server = $Server
                $SecretName = "$Server`::$($Username.tolower())"
            }

            'WEB'
            {
                $InputHash.URL = $URL
            }

            'WIN'
            {
                $Machine = $Machine.ToLower()
                $InputHash.Machine = $Machine

                #Format is machine\user
                $SecretName = "$Machine\$UserName"
            }
        }
    }
    catch
    {
        Throw "Error creating InputHash: $_"
    }


    #We control the order of fields, ensure all are present, by retrieving them and pulling user specified values from fields that exist.
    #TODO - Down the road we can provide a parameter for some sort of hash that allows ad hoc user specified fields, use this same methodology to ensure they are correct.
        $Fields = $Template | Get-SSTemplateField -erroraction stop

        $VerboseString = "InputHash:`n$($InputHash | Out-String)`n`nFields:`n$($Fields.DisplayName | Out-String)`nSecretTypeId: $SecretTypeId`nSecretTemplateName: $($SecretTypeParams.($PSCmdlet.ParameterSetName))`nSecretName: $SecretName`nFolderPath: $($Folder.FolderPath)"

        $FieldValues = Foreach($FieldName in $Fields.DisplayName)
        {
            if($FieldName -eq "Password")
            {
                try
                {
                    Convert-SecStrToStr -secstr ($InputHash.$FieldName) -ErrorAction stop
                }
                catch
                {
                    Throw "$_"
                }
            }
            else
            {
                $InputHash.$FieldName
            }
        }
    
        #We have everything, add the secret
        if($PSCmdlet.ShouldProcess( "Added the Secret $VerboseString",
                                    "Add the Secret $VerboseString?",
                                    "Adding Secret" ))
        {

            if($Force -Or $PSCmdlet.ShouldContinue("Are you REALLY sure you want to add the secret $VerboseString ?", "Adding $VerboseString", [ref]$ConfirmAll, [ref]$RejectAll)) {


                try
                {
                    $Output = $WebServiceProxy.AddSecret($SecretTypeId, $SecretName, $Fields.Id, $FieldValues, $FolderId)

                    if($Output.Secret)
                    {
                        $Output.Secret
                    }

                    if($Output.Error)
                    {
                        Throw "Error adding secret: $($Output.Error | Out-string)"
                    }
                }
                catch
                {
                    Throw "Error adding secret: $_"
                }
            }
        }
}