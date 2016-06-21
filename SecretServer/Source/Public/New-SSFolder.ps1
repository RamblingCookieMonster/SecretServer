Function New-SSFolder
{
    <#
    .SYNOPSIS
        Creates a new folder in Secret Server

    .DESCRIPTION
        Creates a new folder in Secret Server

    .PARAMETER FolderName
        The name of the new folder

    .PARAMETER ParentFolderId
        The ID of the parent folder

    .PARAMETER FolderType
        The type of folder. This is used to determine what icon is displayed in Secret Server.

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
        New-Folder -FolderName 'My Cool Folder'
        
        Creates a new folder with no parent and uses the default folder icon.
        
    .EXAMPLE
        New-Folder -FolderName 'My Cool Folder' -FolderType Computer
        
        Creates a new folder with no parent and uses the Computer icon.
        
    .EXAMPLE
        New-Folder -FolderName 'My Cool Folder' -FolderType Computer -ParentFolderId 7
        
        Creates a new folder using the Computer icon with a parent of 7

    .FUNCTIONALITY
        Secret Server

    #>
    [cmdletbinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$FolderName,
        
        [int]$ParentFolderId = -1,
        
        [validateset("Folder", "Customer", "Computer")]
        [string]$FolderType = "Folder",
        
        [switch]$Force,

        [string]$Uri = $SecretServerConfig.Uri,

        [System.Web.Services.Protocols.SoapHttpClientProtocol]$WebServiceProxy = $SecretServerConfig.Proxy,

        [string]$Token = $SecretServerConfig.Token
    )
    Begin
    {
        Write-Verbose "Working with PSBoundParameters $($PSBoundParameters | Out-String)"
        if(-not $WebServiceProxy.whoami)
        {
            Write-Warning "Your SecretServerConfig proxy does not appear connected.  Creating new connection to $uri"
            try
            {
                $WebServiceProxy = New-WebServiceProxy -uri $Uri -UseDefaultCredential -ErrorAction stop
            }
            catch
            {
                Throw "Error creating proxy for $Uri`: $_"
            }
        }
    }
    Process
    {
        switch ($FolderType) {
            "Folder" {$FolderTypeId = 1; break;}
            "Customer" {$FolderTypeId = 2; break;}
            "Computer" {$FolderTypeId = 3; break;}
        }
        #The FolderCreate SOAP method doesn't seem to follow conventions. Normally an "Errors" property contains errors from the server.
        #In this method, it just HTTP 500's with an exception.
        
        #Using windows auth, which lacks a token parameter.
        if ($Token -eq $null -or $Token -eq "")
        {
            $FolderResult = $WebServiceProxy.FolderCreate($FolderName, $ParentFolderId, $FolderTypeId)
        }
        #Else assume we are using token-based auth.
		else 
        {
            $FolderResult = $WebServiceProxy.FolderCreate($Token, $FolderName, $ParentFolderId, $FolderTypeId)
        }
        Return $FolderResult.FolderId
    }
}