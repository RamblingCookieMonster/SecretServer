function New-Secret {
    <#
        .SYNOPSIS
            Create a new secret in secret server, using the specified template.

        .DESCRIPTION
            Create a new secret in secret server

            This code only handles a pre-specified set of Secret templates defined in SecretType.

            Any fields not included in the parameters here are set to null

        .PARAMETER SecretType
            Secret Template to use

        .PARAMETER SecretName
            Secret Name

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
    [CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact="Medium")]
    param(
        [parameter( Mandatory = $True )]
        [Alias("TemplateName")]
        [string]$SecretType,

        [int]$FolderID,

        [string]$FolderPath,

        [parameter(Mandatory = $True)]
        [string]$SecretName,

        [string]$Uri = $SecretServerConfig.Uri,
        [System.Web.Services.Protocols.SoapHttpClientProtocol]$WebServiceProxy = $SecretServerConfig.Proxy,
        [string]$Token = $SecretServerConfig.Token
    )
    dynamicparam {
        if(!$Script:SecretTemplates) { 
            $Script:SecretTemplates = Get-SSTemplate
        }
        $Template = $Script:SecretTemplates | Where Name -eq $SecretType
        if(!$Template) {
            throw "Template not found, cannot create a '$SecretType'"
        }
        Write-Verbose "Found Template for '$SecretName' with $($Template.Fields.Count) parameters"
        $ParameterDictionary = new-object System.Management.Automation.RuntimeDefinedParameterDictionary

        foreach($Field in $Template.Fields) {
            $Type = if($Field.IsPassword) 
            { 
                [securestring] }
            else 
            { 
                [string] 
            }
            $Attribute =  if($Field.IsPassword) 
            { 
                [System.Management.Automation.ParameterAttribute]::new() 
            } 
            else 
            { 
                [System.Management.Automation.ParameterAttribute]::new(), [System.Management.Automation.ValidateNotNullOrEmptyAttribute]::new() 
            }
            $Parameter = new-object System.Management.Automation.RuntimeDefinedParameter( $Field.DisplayName, $Type, $Attribute)
            $ParameterDictionary.Add($Field.DisplayName, $Parameter)
        }
        return $ParameterDictionary
    }

    end {
        $RejectAll = $false
        $ConfirmAll = $false

        $WebServiceProxy = Verify-SecretConnection -Proxy $WebServiceProxy -Token $Token

        $Fields = $Template.Fields 
        $InputValues = @{}
        foreach($Field in $Fields) {
            $Value = ""
            if($PSBoundParameters.ContainsKey($Field.DisplayName)) {
                if($Field.IsPassword){
                    try {
                        $Value = Convert-SecStrToStr -secstr ($PSBoundParameters[$Field.DisplayName]) -ErrorAction stop
                    }
                    catch {
                        Throw "$_"
                    }
                } else {
                    $Value = $PSBoundParameters[$Field.DisplayName]
                }
            }

            if($Field.IsPassword -and ($Field.Value -eq $null)){
                if($Token) {
                    $Value = $WebServiceProxy.GeneratePassword($token,$Field.id).GeneratedPassword
                }
                else {
                    $Value = $WebServiceProxy.GeneratePassword($Field.id).GeneratedPassword
                }
            }

            $Field | Add-Member NoteProperty Value $Value -Force
        }

        #Verify the template and get the ID
        $SecretTypeId = $Template.ID

        #Verify the folder and get the ID
        $FolderHash = @{}
        if($FolderID) {
            $FolderHash.ID = $FolderID
        }
        if($FolderPath) {
            $FolderHash.FolderPath = $FolderPath
        }

        $Folder = @( Get-SSFolder @FolderHash )
        if($Folder.Count -ne 1) {
            Throw "Error finding folder for $FolderHash.  Folder results:`n$( $Folder | Format-List -Property * -Force | Out-String ).  Valid folders: $(Get-SSFolder | ft -AutoSize | Out-String)"
        }
        $FolderId = $Folder.ID

        $VerboseString = "InputHash:`n$($Fields | Format-Table DisplayName, Value | Out-String)`nSecretTypeId: $SecretTypeId`nSecretTemplateName: $($SecretTypeParams.($PSCmdlet.ParameterSetName))`nSecretName: $SecretName`nFolderPath: $($Folder.FolderPath)"

        # We have everything, add the secret
        if($PSCmdlet.ShouldProcess( "Added the Secret $VerboseString",
                                    "Add the Secret $VerboseString?",
                                    "Adding Secret" )) {
            try {
                if($Token) {
                    $Output = $WebServiceProxy.AddSecret($Token,$SecretTypeId, $SecretName, $Fields.Id, $Fields.Value, $FolderId)
                }
                else {
                    $Output = $WebServiceProxy.AddSecret($SecretTypeId, $SecretName, $Fields.Id, $Fields.Value, $FolderId)
                }
            }
            catch {
                throw "Error adding secret: $_"
            }

            if($Output.Secret) {
                $Output.Secret
            }

            if($Output.Errors) {
                throw "Error adding secret: $($Output.Errors | Out-string)"
            }
        }
    }
}

$Script:SecretTemplates = @()


#publish
New-Alias -Name New-SSSecret -Value New-Secret -Force
#endpublish